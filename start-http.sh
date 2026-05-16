#!/bin/bash
# Serve a árvore ~/pxe/iso via HTTP em 192.168.99.1:8000
# Necessário pro iPXE + initramfs do Arch baixar kernel/initrd/airootfs.sfs

set -e
PXE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVER_IP="192.168.99.1"

# Confere se en5 tá com o IP esperado
if ! ifconfig en5 2>/dev/null | grep -q "inet $SERVER_IP"; then
  echo "AVISO: en5 não está com IP $SERVER_IP."
  echo "Configure com:"
  echo "  sudo networksetup -setmanual \"USB 10/100/1000 LAN\" $SERVER_IP 255.255.255.0 \"\""
  exit 1
fi

cd "$PXE_DIR/iso"
echo "Servindo $PXE_DIR/iso em http://$SERVER_IP:8000"
echo "Ctrl+C pra parar"
exec python3 -m http.server 8000 --bind "$SERVER_IP"
