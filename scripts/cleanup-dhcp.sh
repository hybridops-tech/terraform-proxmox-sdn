#!/usr/bin/env bash
set -euo pipefail

HOST="${PROXMOX_HOST: ? PROXMOX_HOST is required}"

ssh -o StrictHostKeyChecking=no "root@${HOST}" << 'REMOTE'
systemctl stop dnsmasq 2>/dev/null || true
rm -f /etc/dnsmasq.d/sdn-dhcp.conf
> /var/lib/misc/dnsmasq.leases
rm -f /etc/systemd/system/dnsmasq.service.d/sdn-wait.conf
rmdir /etc/systemd/system/dnsmasq.service.d 2>/dev/null || true

for vnet in vnetmgmt vnetobs vnetdev vnetstag vnetprod vnetlab; do
  if ip link show $vnet 2>/dev/null; then
    ip addr flush dev $vnet 2>/dev/null || true
  fi
done

systemctl daemon-reload
systemctl restart dnsmasq
REMOTE
