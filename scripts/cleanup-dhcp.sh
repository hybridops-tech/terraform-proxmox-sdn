#!/usr/bin/env bash
set -euo pipefail

HOST="${PROXMOX_HOST:?PROXMOX_HOST is required}"

ssh -o StrictHostKeyChecking=no "root@${HOST}" << 'REMOTE'
systemctl stop dnsmasq 2>/dev/null || true
rm -f /etc/dnsmasq.d/sdn-dhcp.conf
> /var/lib/misc/dnsmasq.leases
rm -f /etc/systemd/system/dnsmasq.service.d/sdn-wait.conf
rmdir /etc/systemd/system/dnsmasq.service.d 2>/dev/null || true

for vnet in vnetdev vnetlab vnetmgmt vnetobs vnetprod vnetstag; do
  ip link set "$vnet" down 2>/dev/null || true
  ip link delete "$vnet" 2>/dev/null || true
done

rm -f /etc/network/interfaces.d/sdn
rm -rf /etc/pve/sdn/*

ifreload -a
pvesh set /cluster/sdn

systemctl daemon-reload
systemctl restart dnsmasq
REMOTE