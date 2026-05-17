#!/bin/bash
# serve ~/pxe/iso tree via HTTP at 192.168.99.1:8000
# needed by Arch iPXE + initramfs for download kernel/initrd/airootfs.sfs

set -euo pipefail
PXE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVER_IP="192.168.99.1"

# ensure en5 IP
if ! ifconfig en5 2>/dev/null | grep -q "inet $SERVER_IP"; then
  echo "[WARN]: en5 IP need to be $SERVER_IP."
  echo "Configure with:"
  echo "  sudo networksetup -setmanual \"USB 10/100/1000 LAN\" $SERVER_IP 255.255.255.0 \"\""
  exit 1
fi

cd "$PXE_DIR/iso"
echo "Running $PXE_DIR/iso at http://$SERVER_IP:8000"
exec python3 -m http.server 8000 --bind "$SERVER_IP"
