#!/bin/bash
# setup.sh — Prepara o Mac para servir Arch Linux via PXE
# Roda uma vez antes da primeira utilização

set -e

PXE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ISO_FILE="${1:-}"
ETH_SERVICE="USB 10/100/1000 LAN"
SERVER_IP="192.168.99.1"
NETMASK="255.255.255.0"

echo "=== PXE Arch Linux setup ==="
echo "Diretório base: $PXE_DIR"

# 1. Dependências
echo
echo "[1/6] Instalando dependências (dnsmasq, pv)..."
if ! command -v brew >/dev/null 2>&1; then
  echo "ERRO: Homebrew não está instalado. Instale primeiro: https://brew.sh"
  exit 1
fi
brew list dnsmasq >/dev/null 2>&1 || brew install dnsmasq
brew list pv >/dev/null 2>&1 || brew install pv

# 2. Extrai ISO do Arch (se fornecida e ainda não extraída)
if [ -n "$ISO_FILE" ] && [ -f "$ISO_FILE" ]; then
  if [ ! -d "$PXE_DIR/iso/arch" ]; then
    echo
    echo "[2/6] Extraindo $ISO_FILE..."
    mkdir -p "$PXE_DIR/iso"
    bsdtar -xf "$ISO_FILE" -C "$PXE_DIR/iso/"
  else
    echo
    echo "[2/6] ISO já extraída em $PXE_DIR/iso (pulando)"
  fi
else
  if [ ! -d "$PXE_DIR/iso/arch" ]; then
    echo
    echo "ERRO: passe a ISO como argumento na primeira execução."
    echo "Uso: $0 /caminho/para/archlinux-xxxx.iso"
    exit 1
  fi
  echo
  echo "[2/6] ISO já extraída (pulando)"
fi

# 3. Monta TFTP root
echo
echo "[3/6] Montando estrutura TFTP..."
mkdir -p "$PXE_DIR/tftp/EFI/BOOT"
mkdir -p "$PXE_DIR/tftp/arch/boot/x86_64"
mkdir -p "$PXE_DIR/tftp/loader/entries"
cp -f "$PXE_DIR/iso/EFI/BOOT/BOOTx64.EFI" "$PXE_DIR/tftp/EFI/BOOT/"
cp -f "$PXE_DIR/iso/arch/boot/x86_64/vmlinuz-linux" "$PXE_DIR/tftp/arch/boot/x86_64/"
cp -f "$PXE_DIR/iso/arch/boot/x86_64/initramfs-linux.img" "$PXE_DIR/tftp/arch/boot/x86_64/"

# 4. Baixa iPXE vanilla
echo
echo "[4/6] Baixando iPXE (vanilla, sem script embutido)..."
if [ ! -s "$PXE_DIR/tftp/ipxe.efi" ] || [ "$(stat -f%z "$PXE_DIR/tftp/ipxe.efi" 2>/dev/null || echo 0)" -lt 100000 ]; then
  curl -fL -o "$PXE_DIR/tftp/ipxe.efi" https://boot.ipxe.org/x86_64-efi/ipxe.efi
fi
if ! file "$PXE_DIR/tftp/ipxe.efi" | grep -q "PE32"; then
  echo "ERRO: ipxe.efi inválido (não é PE32). Confira conectividade."
  exit 1
fi

# 5. Gera boot.ipxe servido via HTTP
echo
echo "[5/6] Gerando boot.ipxe..."
cat > "$PXE_DIR/iso/boot.ipxe" <<EOF
#!ipxe
echo === Arch Linux Netboot ===
dhcp || goto failed
echo IP: \${ip}
kernel http://$\{SERVER_IP\}:8000/arch/boot/x86_64/vmlinuz-linux archisobasedir=arch archiso_http_srv=http://${SERVER_IP}:8000/ ip=dhcp verify=n rd.retry=60 rd.timeout=120 rd.net.timeout.carrier=30 rd.net.timeout.dhcp=60 BOOTIF=01-\${netX/mac:hexhyp}
initrd http://$\{SERVER_IP\}:8000/arch/boot/x86_64/initramfs-linux.img
boot
:failed
echo Falhou.
shell
EOF

# 6. Gera dnsmasq.conf
echo
echo "[6/6] Gerando dnsmasq.conf..."
sudo tee /opt/homebrew/etc/dnsmasq.conf >/dev/null <<EOF
port=0
interface=en5
bind-interfaces
dhcp-range=192.168.99.50,192.168.99.150,12h
dhcp-option=3
dhcp-option=6
dhcp-match=set:ipxe,175
dhcp-match=set:efi64,option:client-arch,7
dhcp-boot=tag:efi64,tag:!ipxe,ipxe.efi
dhcp-boot=tag:ipxe,http://${SERVER_IP}:8000/boot.ipxe
enable-tftp
tftp-root=${PXE_DIR}/tftp
log-dhcp
log-queries
EOF

echo
echo "=== Setup concluído ==="
echo
echo "Próximos passos pra bootar a Avell:"
echo "  1. Conecte o adaptador USB-Ethernet (Baseus) e cabo direto na Avell"
echo "  2. Configure IP estático no en5:"
echo "       sudo networksetup -setmanual \"$ETH_SERVICE\" $SERVER_IP $NETMASK \"\""
echo "  3. Em terminais separados, rode:"
echo "       ./start-dnsmasq.sh"
echo "       ./start-http.sh"
echo "  4. Liga a Avell, F7 -> IPv4 PXE Boot"
echo
echo "Pra restaurar o Mac ao normal depois:"
echo "  sudo networksetup -setdhcp \"$ETH_SERVICE\""
