#!/usr/bin/env bash
# file: control/tools/helper/proxmox/create-sdn-auto-fix.sh
# purpose: Install SDN status self-healing (config patch + status refresh) on Proxmox
# maintainer: HybridOps.Studio
# date: 2025-12-26

set -euo pipefail

echo "sdn_auto_fix: installing SDN auto-fix components"

cat > /usr/local/bin/fix-sdn-status.sh << 'FIXSCRIPT'
#!/usr/bin/env bash
# file: /usr/local/bin/fix-sdn-status.sh
# purpose: Patch SDN interface config, apply network, and refresh SDN status in Proxmox UI
# maintainer: HybridOps.Studio
# date: 2025-12-26

set -euo pipefail

max_wait=60
waited=0

# Wait for SDN config to be generated
while [ ! -f /etc/network/interfaces.d/sdn ] && [ "${waited}" -lt "${max_wait}" ]; do
    sleep 1
    waited=$((waited + 1))
done

if [ ! -f /etc/network/interfaces.d/sdn ]; then
    echo "fix_sdn_status: SDN config not found, skipping"
    exit 0
fi

# Wait for any running ifreload to finish
max_wait=30
waited=0
while pgrep -x ifreload >/dev/null 2>&1 && [ "${waited}" -lt "${max_wait}" ]; do
    echo "fix_sdn_status: waiting for existing ifreload"
    sleep 2
    waited=$((waited + 2))
done

if grep -q "address 10.10.0.1/24" /etc/network/interfaces.d/sdn; then
    echo "fix_sdn_status: SDN config already patched"
else
    echo "fix_sdn_status: patching SDN config"

    cp /etc/network/interfaces.d/sdn /etc/network/interfaces.d/sdn.pre-patch

    sed -i "/^iface vnetmgmt$/a\        address 10.10.0.1/24" /etc/network/interfaces.d/sdn
    sed -i "/^iface vnetobs$/a\        address 10.11.0.1/24" /etc/network/interfaces.d/sdn
    sed -i "/^iface vnetdev$/a\        address 10.20.0.1/24" /etc/network/interfaces.d/sdn
    sed -i "/^iface vnetstag$/a\        address 10.30.0.1/24" /etc/network/interfaces.d/sdn
    sed -i "/^iface vnetprod$/a\        address 10.40.0.1/24" /etc/network/interfaces.d/sdn
    sed -i "/^iface vnetlab$/a\        address 10.50.0.1/24" /etc/network/interfaces.d/sdn

    echo "fix_sdn_status: SDN config patched"
fi

sleep 3

max_retries=3
retry=0
while [ "${retry}" -lt "${max_retries}" ]; do
    if ifreload -a 2>&1; then
        echo "fix_sdn_status: network config applied"
        break
    else
        retry=$((retry + 1))
        if [ "${retry}" -lt "${max_retries}" ]; then
            echo "fix_sdn_status: ifreload failed, retry ${retry}/${max_retries}"
            sleep 5
        else
            echo "fix_sdn_status: ifreload failed after ${max_retries} attempts"
        fi
    fi
done

sleep 2

if [ -x /usr/local/bin/assign-sdn-gateway-ips.sh ]; then
    /usr/local/bin/assign-sdn-gateway-ips.sh
fi

mkdir -p /run/pve
if [ -f /etc/pve/sdn/.running-config ]; then
    cat /etc/pve/sdn/.running-config \
        | jq -r .version \
        > /run/pve/.sdn_version 2>/dev/null || true
    version_value="$(cat /run/pve/.sdn_version 2>/dev/null || echo 'N/A')"
    echo "fix_sdn_status: SDN version synced: ${version_value}"
fi

systemctl restart pve-cluster 2>&1 || echo "fix_sdn_status: warning: pve-cluster restart failed"

echo "fix_sdn_status: completed"
FIXSCRIPT

chmod +x /usr/local/bin/fix-sdn-status.sh

cat > /etc/systemd/system/sdn-status-fix.service << 'SERVICE'
[Unit]
Description=Fix Proxmox SDN status display
After=pve-cluster.service networking.service
Requires=pve-cluster.service

[Service]
Type=oneshot
ExecStartPre=/bin/sleep 5
ExecStart=/usr/local/bin/fix-sdn-status.sh
RemainAfterExit=yes
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
SERVICE

cat > /etc/systemd/system/sdn-config-watcher.path << 'PATHUNIT'
[Unit]
Description=Watch for SDN config changes
After=pve-cluster.service

[Path]
PathChanged=/etc/network/interfaces.d/sdn
Unit=sdn-status-fix.service

[Install]
WantedBy=multi-user.target
PATHUNIT

echo "sdn_auto_fix: enabling systemd units"
systemctl daemon-reload
systemctl enable sdn-status-fix.service
systemctl enable sdn-config-watcher.path
systemctl start sdn-config-watcher.path

echo "sdn_auto_fix: running initial fix"
/usr/local/bin/fix-sdn-status.sh

echo "sdn_auto_fix: installation complete"
