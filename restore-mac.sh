#!/bin/bash
# Restaura o Mac ao estado normal (depois de usar a infra PXE)

echo "Matando dnsmasq e HTTP server..."
sudo killall dnsmasq 2>/dev/null || true
sudo killall python3 2>/dev/null || true

echo "Voltando en5 para DHCP automático..."
sudo networksetup -setdhcp "USB 10/100/1000 LAN" 2>/dev/null || true

echo "Removendo rota estática..."
sudo route delete -net 192.168.99.0/24 2>/dev/null || true

echo "Reativando daemons do macOS..."
sudo launchctl load -w /System/Library/LaunchDaemons/bootps.plist 2>/dev/null || true
sudo launchctl load -w /System/Library/LaunchDaemons/tftp.plist 2>/dev/null || true

echo "Concluído. Você pode plugar a Baseus em qualquer rede normalmente."
