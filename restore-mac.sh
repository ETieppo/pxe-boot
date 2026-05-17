#!/bin/bash
# restore MacOS at this default network settings, load daemons

set -euo pipefail

sudo killall dnsmasq 2>/dev/null || true
sudo killall python3 2>/dev/null || true
sudo networksetup -setdhcp "USB 10/100/1000 LAN" 2>/dev/null || true
sudo route delete -net 192.168.99.0/24 2>/dev/null || true
sudo launchctl load -w /System/Library/LaunchDaemons/bootps.plist 2>/dev/null || true
sudo launchctl load -w /System/Library/LaunchDaemons/tftp.plist 2>/dev/null || true
sudo launchctl enable system/com.apple.bootpd
sudo launchctl enable system/com.apple.tftpd

echo "successfully restored."

