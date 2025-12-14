#!/usr/bin/env bash
set -euo pipefail

HOST="${PROXMOX_HOST:?PROXMOX_HOST is required}"

ssh -o StrictHostKeyChecking=no "root@${HOST}" \
  "rm -f /etc/dnsmasq.d/sdn-dhcp.conf && systemctl restart dnsmasq"