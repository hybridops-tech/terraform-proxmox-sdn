#!/bin/bash
set -euo pipefail

PROXMOX_HOST="${PROXMOX_HOST:-}"
VNETS_JSON="${VNETS_JSON:-}"

if [ -z "$PROXMOX_HOST" ] || [ -z "$VNETS_JSON" ]; then
    echo "ERROR: PROXMOX_HOST and VNETS_JSON must be set"
    exit 1
fi

echo "Configuring DHCP for Proxmox SDN on host: $PROXMOX_HOST"

# Parse JSON - vnet name comes from the key, not from subnet data
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
    
    IP_COMMANDS+="ip addr add ${gateway}/24 dev ${vnet} 2>/dev/null || echo '  ${vnet} IP already set'"$'\n'
    
    DNSMASQ_CONFIG+="
interface=${vnet}
dhcp-range=${start},${end},24h
dhcp-option=option:router,${gateway}
dhcp-option=option:dns-server,${dns}
"
done <<< "$VNET_CONFIGS"

# Execute on Proxmox
ssh root@${PROXMOX_HOST} bash <<REMOTE_SCRIPT
set -euo pipefail

echo "Cleaning up old services..."
pkill -9 dhcpd 2>/dev/null || true
systemctl stop isc-dhcp-server 2>/dev/null || true
systemctl disable isc-dhcp-server 2>/dev/null || true
systemctl stop dnsmasq 2>/dev/null || true
rm -f /etc/dnsmasq.d/*.conf 2>/dev/null || true

echo "Installing dnsmasq..."
if !  command -v dnsmasq &>/dev/null; then
    apt-get update -qq
    apt-get install -y dnsmasq
fi

echo "Waiting for vnet bridges..."
sleep 5

echo "Configuring IPs on vnet bridges..."
${IP_COMMANDS}

echo "Verifying IPs..."
for vnet in vnetmgmt vnetobs vnetdev vnetstag vnetprod vnetlab; do
    if ip addr show \$vnet 2>/dev/null | grep -q "inet "; then
        echo "  \$vnet: OK"
    else
        echo "  \$vnet: Missing IP (may not be in this config)"
    fi
done

echo "Creating dnsmasq configuration..."
mkdir -p /etc/dnsmasq.d
cat > /etc/dnsmasq.d/sdn-dhcp.conf <<'DNSMASQ_EOF'
bind-interfaces
domain=hybridops.local
log-dhcp
${DNSMASQ_CONFIG}
DNSMASQ_EOF

echo "Generated config:"
cat /etc/dnsmasq.d/sdn-dhcp.conf

if grep -q "interface=null" /etc/dnsmasq.d/sdn-dhcp.conf; then
    echo "ERROR: Config contains 'interface=null' - parsing failed!"
    exit 1
fi

echo "Testing dnsmasq configuration..."
if ! dnsmasq --test; then
    echo "ERROR: dnsmasq config test failed"
    exit 1
fi

echo "Configuring systemd..."
mkdir -p /etc/systemd/system/dnsmasq.service.d
cat > /etc/systemd/system/dnsmasq.service.d/sdn-wait.conf <<'SYSTEMD_EOF'
[Unit]
After=pve-cluster.service pvedaemon.service

[Service]
ExecStartPre=/bin/sleep 5
SYSTEMD_EOF

systemctl daemon-reload
systemctl enable dnsmasq
systemctl restart dnsmasq

sleep 3

if systemctl is-active dnsmasq >/dev/null 2>&1; then
    echo ""
    echo "SUCCESS: dnsmasq is running with DHCP"
    systemctl status dnsmasq --no-pager | head -10
else
    echo ""
    echo "ERROR: dnsmasq failed to start"
    journalctl -u dnsmasq --no-pager -n 30
    exit 1
fi

echo ""
echo "Reloading SDN configuration to clear UI errors..."
pvesh set /cluster/sdn
ifreload -a
echo "SDN configuration reloaded"

REMOTE_SCRIPT

echo "DHCP setup complete!"
