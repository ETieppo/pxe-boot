#!/bin/bash
# Run dnsmasq as DHCP proxy + TFTP server at en5 interface
# target will seek for this server port and endpoints to download files into

set -euo pipefail

PXE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVER_IP="192.168.99.1"
DNSMASQ_BIN="/opt/homebrew/opt/dnsmasq/sbin/dnsmasq"
CONF_FILE="/opt/homebrew/etc/dnsmasq.conf"

if [ ! -x "$DNSMASQ_BIN" ]; then
  echo "[ERROR]: dnsmasq was not found at $DNSMASQ_BIN"
  echo "Run ./setup.sh first."
  exit 1
fi

if [ ! -f "$CONF_FILE" ]; then
  echo "[ERROR]: $CONF_FILE do not exist. Run ./setup.sh first."
  exit 1
fi

# Ensure right en5 IP
if ! ifconfig en5 2>/dev/null | grep -q "inet $SERVER_IP"; then
  echo "[WARN]: en5 IP need to be $SERVER_IP."
  echo "configure with:"
  echo "  sudo networksetup -setmanual \"USB 10/100/1000 LAN\" $SERVER_IP 255.255.255.0 \"\""
  exit 1
fi

# kill last instance
sudo killall dnsmasq 2>/dev/null || true
sleep 1

echo "Starting dnsmasq (DHCP+TFTP) at en5..."
exec sudo "$DNSMASQ_BIN" -d --log-debug --log-dhcp --conf-file="$CONF_FILE"
