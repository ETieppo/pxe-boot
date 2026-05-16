#!/bin/bash
# Sobe dnsmasq como proxy DHCP + TFTP server na interface en5
# Necessário pra Avell descobrir o servidor PXE

set -e
PXE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVER_IP="192.168.99.1"
DNSMASQ_BIN="/opt/homebrew/opt/dnsmasq/sbin/dnsmasq"
CONF_FILE="/opt/homebrew/etc/dnsmasq.conf"

if [ ! -x "$DNSMASQ_BIN" ]; then
  echo "ERRO: dnsmasq não encontrado em $DNSMASQ_BIN"
  echo "Rode ./setup.sh primeiro."
  exit 1
fi

if [ ! -f "$CONF_FILE" ]; then
  echo "ERRO: $CONF_FILE não existe. Rode ./setup.sh primeiro."
  exit 1
fi

# Confere se en5 tá com o IP esperado
if ! ifconfig en5 2>/dev/null | grep -q "inet $SERVER_IP"; then
  echo "AVISO: en5 não está com IP $SERVER_IP."
  echo "Configure com:"
  echo "  sudo networksetup -setmanual \"USB 10/100/1000 LAN\" $SERVER_IP 255.255.255.0 \"\""
  exit 1
fi

# Mata instâncias anteriores
sudo killall dnsmasq 2>/dev/null || true
sleep 1

echo "Sobindo dnsmasq (DHCP+TFTP) em en5..."
echo "Ctrl+C pra parar"
exec sudo "$DNSMASQ_BIN" -d --log-debug --log-dhcp --conf-file="$CONF_FILE"
