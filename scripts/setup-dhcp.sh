#!/bin/bash
set -euo pipefail

PROXMOX_HOST="${PROXMOX_HOST:-}"
VNETS_JSON="${VNETS_JSON:-}"

if [ -z "$PROXMOX_HOST" ] || [ -z "$VNETS_JSON" ]; then
    echo "ERROR:  PROXMOX_HOST and VNETS_JSON must be set"
    exit 1
fi

echo "Configuring DHCP for Proxmox SDN on host: $PROXMOX_HOST"

# Parse JSON
VNET_CONFIGS=$(echo "$VNETS_JSON" | jq -r '
to_entries[] |
.key as $vnet_name |
.value.subnets | to_entries[] |
select(.value.dhcp_enabled == true) |
{
  vnet: $vnet_name,
  gateway: .value.gateway,
  start: .value.dhcp_range_start,
  end: .value.dhcp_range_end,
  dns: .value.dhcp_dns_server
} |
"\(.vnet)|\(.gateway)|\(.start)|\(.end)|\(.dns)"
')

echo "Parsed DHCP configurations:"
echo "$VNET_CONFIGS"

if [ -z "$VNET_CONFIGS" ]; then
    echo "ERROR: No DHCP-enabled vnets found"
    exit 1
fi

# Build commands
IP_COMMANDS=""
DNSMASQ_CONFIG=""

while IFS='|' read -r vnet gateway start end dns; do
    [ -z "$vnet" ] && continue
    
    IP_COMMANDS+="ip addr add ${gateway}/24 dev ${vnet} 2>&1 || echo '  ${vnet} IP already exists'"$'\n'
    
    DNSMASQ_CONFIG+="
interface=${vnet}
dhcp-range=${start},${end},24h
dhcp-option=option:router,${gateway}
dhcp-option=option:dns-server,${dns}
"
done <<< "$VNET_CONFIGS"

# Execute EVERYTHING in ONE SSH session to avoid race conditions
ssh root@${PROXMOX_HOST} bash <<REMOTE_SCRIPT
set -euo pipefail

echo "=== Phase 1: Cleanup ==="
pkill -9 dhcpd 2>/dev/null || true
systemctl stop isc-dhcp-server 2>/dev/null || true
systemctl disable isc-dhcp-server 2>/dev/null || true
systemctl stop dnsmasq 2>/dev/null || true
rm -f /etc/dnsmasq.d/*.conf 2>/dev/null || true

echo "=== Phase 2: Install dnsmasq ==="
if !  command -v dnsmasq &>/dev/null; then
    apt-get update -qq
    apt-get install -y dnsmasq
fi

echo "=== Phase 3: Wait for vnets ==="
sleep 10

echo "=== Phase 4: Create dnsmasq config ==="
mkdir -p /etc/dnsmasq.d
cat > /etc/dnsmasq.d/sdn-dhcp.conf <<'DNSMASQ_EOF'
bind-interfaces
domain=hybridops.local
log-dhcp
${DNSMASQ_CONFIG}
DNSMASQ_EOF

echo ""
echo "Generated config:"
cat /etc/dnsmasq.d/sdn-dhcp.conf

if grep -q "interface=null" /etc/dnsmasq.d/sdn-dhcp.conf; then
    echo "ERROR: Config contains 'interface=null'"
    exit 1
fi

echo "=== Phase 5: Configure systemd ==="
mkdir -p /etc/systemd/system/dnsmasq.service.d
cat > /etc/systemd/system/dnsmasq.service.d/sdn-wait.conf <<'SYSTEMD_EOF'
[Unit]
After=pve-cluster.service pvedaemon.service

[Service]
ExecStartPre=/bin/sleep 10
SYSTEMD_EOF

systemctl daemon-reload

echo "=== Phase 6: Reload SDN FIRST (before adding IPs) ==="
pvesh set /cluster/sdn
ifreload -a
sleep 5

echo "=== Phase 7: Add IPs to vnet bridges ==="
set +e  # Don't exit on error
${IP_COMMANDS}
set -e

echo ""
echo "IP verification:"
for vnet in vnetmgmt vnetobs vnetdev vnetstag vnetprod vnetlab; do
    if ip addr show \$vnet 2>/dev/null | grep -q "inet "; then
        IP=\$(ip addr show \$vnet | grep "inet " | awk '{print \$2}')
        echo "  ✓ \$vnet: \$IP"
    else
        echo "  ✗ \$vnet: NO IP"
    fi
done

echo "=== Phase 8: Start dnsmasq ==="
systemctl enable dnsmasq
systemctl restart dnsmasq
sleep 3

if systemctl is-active dnsmasq >/dev/null 2>&1; then
    echo ""
    echo "✓ dnsmasq is running"
    systemctl status dnsmasq --no-pager | head -10
else
    echo "✗ dnsmasq failed"
    journalctl -u dnsmasq --no-pager -n 20
    exit 1
fi

echo ""
echo "=== Final verification ==="
for vnet in vnetmgmt vnetobs vnetdev vnetstag vnetprod vnetlab; do
    if ip addr show \$vnet 2>/dev/null | grep -q "inet "; then
        IP=\$(ip addr show \$vnet | grep "inet " | awk '{print \$2}')
        echo "  ✓ \$vnet: \$IP"
    else
        echo "  ✗ \$vnet: NO IP"
    fi
done

REMOTE_SCRIPT

echo ""
echo "✓ DHCP setup complete!"

exit 0exit 0
