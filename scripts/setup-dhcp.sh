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
.value. subnets | to_entries[] |
select(.value.dhcp_enabled == true) |
{
  vnet: $vnet_name,
  gateway: . value.gateway,
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

# Build commands - FIX:  Escape dollar signs properly for remote execution
IP_COMMANDS=""
DNSMASQ_CONFIG=""

while IFS='|' read -r vnet gateway start end dns; do
    [ -z "$vnet" ] && continue
    
    # FIX: Use proper escaping and remove the silent failure
    IP_COMMANDS+="ip addr add ${gateway}/24 dev ${vnet} 2>&1 || echo '  ${vnet} IP already exists (exit code: \$?)'"$'\n'
    
    DNSMASQ_CONFIG+="
interface=${vnet}
dhcp-range=${start},${end},24h
dhcp-option=option:router,${gateway}
dhcp-option=option: dns-server,${dns}
"
done <<< "$VNET_CONFIGS"

# Execute on Proxmox
ssh root@${PROXMOX_HOST} bash <<'REMOTE_SCRIPT'
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

echo "Waiting for vnet bridges to be ready..."
sleep 10

echo "Checking which vnet bridges exist..."
for vnet in vnetmgmt vnetobs vnetdev vnetstag vnetprod vnetlab; do
    if ip link show $vnet &>/dev/null; then
        echo "  ✓ $vnet exists"
    else
        echo "  ✗ $vnet does NOT exist - skipping"
    fi
done

echo ""
echo "Configuring IPs on vnet bridges..."
REMOTE_SCRIPT

# FIX: Insert IP commands WITHOUT set -e so they don't fail the entire script
ssh root@${PROXMOX_HOST} bash <<REMOTE_SCRIPT2
set +e  # Don't exit on error for IP commands
${IP_COMMANDS}
set -e  # Re-enable exit on error

echo ""
echo "Verifying IPs were assigned..."
for vnet in vnetmgmt vnetobs vnetdev vnetstag vnetprod vnetlab; do
    if ip addr show \$vnet 2>/dev/null | grep -q "inet "; then
        IP=\$(ip addr show \$vnet | grep "inet " | awk '{print \$2}')
        echo "  ✓ \$vnet: \$IP"
    else
        echo "  ✗ \$vnet: NO IP ADDRESS"
    fi
done
REMOTE_SCRIPT2

# Continue with dnsmasq configuration
ssh root@${PROXMOX_HOST} bash <<'REMOTE_SCRIPT3'
set -euo pipefail

echo ""
echo "Creating dnsmasq configuration..."
mkdir -p /etc/dnsmasq.d
cat > /etc/dnsmasq.d/sdn-dhcp.conf <<'DNSMASQ_EOF'
bind-interfaces
domain=hybridops.local
log-dhcp
DNSMASQ_EOF

REMOTE_SCRIPT3

# Add dnsmasq config
ssh root@${PROXMOX_HOST} "cat >> /etc/dnsmasq. d/sdn-dhcp. conf" <<DNSMASQ_EOF
${DNSMASQ_CONFIG}
DNSMASQ_EOF

ssh root@${PROXMOX_HOST} bash <<'REMOTE_SCRIPT4'
set -euo pipefail

echo ""
echo "Generated dnsmasq config:"
cat /etc/dnsmasq. d/sdn-dhcp.conf

if grep -q "interface=null" /etc/dnsmasq.d/sdn-dhcp.conf; then
    echo "ERROR: Config contains 'interface=null' - parsing failed!"
    exit 1
fi

echo ""
echo "Testing dnsmasq configuration..."
if ! dnsmasq --test 2>&1; then
    echo "ERROR: dnsmasq config test failed"
    exit 1
fi

echo "Configuring systemd..."
mkdir -p /etc/systemd/system/dnsmasq.service.d
cat > /etc/systemd/system/dnsmasq.service. d/sdn-wait.conf <<'SYSTEMD_EOF'
[Unit]
After=pve-cluster.service pvedaemon.service

[Service]
ExecStartPre=/bin/sleep 10
SYSTEMD_EOF

systemctl daemon-reload
systemctl enable dnsmasq
systemctl restart dnsmasq

sleep 3

if systemctl is-active dnsmasq >/dev/null 2>&1; then
    echo ""
    echo "✓ SUCCESS: dnsmasq is running with DHCP"
    systemctl status dnsmasq --no-pager | head -10
else
    echo ""
    echo "✗ ERROR: dnsmasq failed to start"
    journalctl -u dnsmasq --no-pager -n 30
    exit 1
fi

echo ""
echo "Reloading SDN configuration..."
pvesh set /cluster/sdn
ifreload -a
echo "SDN configuration reloaded"

echo ""
echo "Final IP verification:"
for vnet in vnetmgmt vnetobs vnetdev vnetstag vnetprod vnetlab; do
    if ip addr show $vnet 2>/dev/null | grep -q "inet "; then
        IP=$(ip addr show $vnet | grep "inet " | awk '{print $2}')
        echo "  ✓ $vnet: $IP"
    else
        echo "  ✗ $vnet: NO IP"
    fi
done

REMOTE_SCRIPT4

echo ""
echo "✓ DHCP setup complete!"