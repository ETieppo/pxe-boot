#!/bin/bash
# prepare macos for serve pxe

set -e

PXE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ISO_FILE="${1:-}"
ETH_SERVICE="USB 10/100/1000 LAN"
SERVER_IP="192.168.99.1"
NETMASK="255.255.255.0"

echo "=== PXE Arch Linux setup ==="
echo "Diretório base: $PXE_DIR"

# 1. Mac dependencies
echo
echo "[1/6] installing dependencies (dnsmasq, pv)..."
if ! command -v brew >/dev/null 2>&1; then
  echo "[ERROR]: brew command not found, install it https://brew.sh"
  exit 1
fi
brew list dnsmasq >/dev/null 2>&1 || brew install dnsmasq
brew list pv >/dev/null 2>&1 || brew install pv

sudo networksetup -setmanual "USB 10/100/1000 LAN" 192.168.99.1 255.255.255.0 ""
sudo launchctl unload -w /System/Library/LaunchDaemons/bootps.plist
sudo launchctl kickstart -k system/com.apple.bootpd
sudo launchctl disable system/com.apple.tftpd
sudo launchctl disable system/com.apple.bootpd

# 2. Extract Arch ISO
if [ -n "$ISO_FILE" ] && [ -f "$ISO_FILE" ]; then
  if [ ! -d "$PXE_DIR/iso/arch" ]; then
    echo
    echo "[2/6] extracting $ISO_FILE..."
    mkdir -p "$PXE_DIR/iso"
    bsdtar -xf "$ISO_FILE" -C "$PXE_DIR/iso/"
  else
    echo
    echo "[2/6] ISO already extracted $PXE_DIR/iso (skip)"
  fi
else
  if [ ! -d "$PXE_DIR/iso/arch" ]; then
    echo
    echo "[ERROR]: run with ISO path args."
    echo "use: $0 /caminho/para/archlinux-xxxx.iso"
    exit 1
  fi
  echo
  echo "[2/6] ISO already extracted (skip)"
fi

# 3. mount tftp root
echo
echo "[3/6] Mounting TFTP..."
mkdir -p "$PXE_DIR/tftp/EFI/BOOT"
mkdir -p "$PXE_DIR/tftp/arch/boot/x86_64"
mkdir -p "$PXE_DIR/tftp/loader/entries"
cp -f "$PXE_DIR/iso/EFI/BOOT/BOOTx64.EFI" "$PXE_DIR/tftp/EFI/BOOT/"
cp -f "$PXE_DIR/iso/arch/boot/x86_64/vmlinuz-linux" "$PXE_DIR/tftp/arch/boot/x86_64/"
cp -f "$PXE_DIR/iso/arch/boot/x86_64/initramfs-linux.img" "$PXE_DIR/tftp/arch/boot/x86_64/"

# 4. download vanilla ipxe
echo
echo "[4/6] Downloading vanilla IPXE..."
if [ ! -s "$PXE_DIR/tftp/ipxe.efi" ] || [ "$(stat -f%z "$PXE_DIR/tftp/ipxe.efi" 2>/dev/null || echo 0)" -lt 100000 ]; then
  curl -fL -o "$PXE_DIR/tftp/ipxe.efi" https://boot.ipxe.org/x86_64-efi/ipxe.efi
fi
if ! file "$PXE_DIR/tftp/ipxe.efi" | grep -q "PE32"; then
  echo "[ERROR]: invalid ipxe.efi (is not PE32). ensure connectivity."
  exit 1
fi

# 5. generate boot.ipxe via HTTP serve
echo
echo "[5/6] generating boot.ipxe..."
cat > "$PXE_DIR/iso/boot.ipxe" <<EOF
#!ipxe
echo === Arch Linux Netboot ===
dhcp || goto failed
echo IP: \${ip}
kernel http://$\{SERVER_IP\}:8000/arch/boot/x86_64/vmlinuz-linux archisobasedir=arch archiso_http_srv=http://${SERVER_IP}:8000/ ip=dhcp verify=n rd.retry=60 rd.timeout=120 rd.net.timeout.carrier=30 rd.net.timeout.dhcp=60 BOOTIF=01-\${netX/mac:hexhyp}
initrd http://$\{SERVER_IP\}:8000/arch/boot/x86_64/initramfs-linux.img
boot
:failed
echo failed.
shell
EOF

# 6. gen dnsmasq.conf
echo
echo "[6/6] generating dnsmasq.conf..."
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
echo "=== END SETUP ==="
echo
echo "NEXT STEPS:"
echo "  1. Connect USB-Ethernet between Mac and target computer"
echo "  2. If something went wrong, run manually: "
echo "        sudo networksetup -setmanual \"$ETH_SERVICE\" $SERVER_IP $NETMASK \"\""
echo "        sudo launchctl unload -w /System/Library/LaunchDaemons/bootps.plist "
echo "        sudo launchctl kickstart -k system/com.apple.bootpd                 "
echo "        sudo launchctl disable system/com.apple.tftpd                       "
echo "        sudo launchctl disable system/com.apple.bootpd                      "
echo "  3. Open two different terminals and run one line at each:"
echo "      r ./start-dnsmasq.sh"
echo "       ./start-http.sh"
echo "  4. Turn on target, open bios -> IPv4 PXE Boot"
echo
echo "To reconfigure default Mac runs:"
echo "  sudo networksetup -setdhcp \"$ETH_SERVICE\""
