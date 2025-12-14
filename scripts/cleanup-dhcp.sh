#!/usr/bin/env bash
set -euo pipefail

HOST="${PROXMOX_HOST:? PROXMOX_HOST is required}"

echo "=== Full SDN/DHCP cleanup ==="

ssh -o StrictHostKeyChecking=no "root@${HOST}" << 'REMOTE'
# Stop dnsmasq (legacy)
systemctl stop dnsmasq 2>/dev/null || true
systemctl disable dnsmasq 2>/dev/null || true
rm -f /etc/dnsmasq.d/sdn-dhcp.conf
> /var/lib/misc/dnsmasq.leases 2>/dev/null || true
rm -f /etc/systemd/system/dnsmasq.service.d/sdn-wait.conf
rmdir /etc/systemd/system/dnsmasq.service.d 2>/dev/null || true

# Delete vnet interfaces
for vnet in vnetdev vnetlab vnetmgmt vnetobs vnetprod vnetstag; do
  ip link set "$vnet" down 2>/dev/null || true
  ip link delete "$vnet" 2>/dev/null || true
done

# Nuclear option - clear SDN config
rm -f /etc/network/interfaces.d/sdn
rm -rf /etc/pve/sdn/*

# Reload
ifreload -a 2>/dev/null || true
pvesh set /cluster/sdn 2>/dev/null || true

systemctl daemon-reload

echo "✓ Full cleanup complete"
REMOTE