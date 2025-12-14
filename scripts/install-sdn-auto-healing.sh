#!/bin/bash
# create-sdn-auto-fix.sh - Install self-healing SDN status fix on Proxmox

set -e

echo "=== Installing SDN Auto-Fix ==="

# 1.Create the fix script
cat > /usr/local/bin/fix-sdn-status.sh << 'FIXSCRIPT'
#!/bin/bash
# Auto-fix SDN status display after Proxmox regenerates config

set -e

# Wait for SDN config to be generated
max_wait=60
waited=0
while [ !  -f /etc/network/interfaces.d/sdn ] && [ $waited -lt $max_wait ]; do
    sleep 1
    waited=$((waited + 1))
done

if [ ! -f /etc/network/interfaces.d/sdn ]; then
    echo "SDN config not found, skipping fix"
    exit 0
fi

# Wait for any running ifreload to finish
max_wait=30
waited=0
while pgrep -x ifreload > /dev/null && [ $waited -lt $max_wait ]; do
    echo "Waiting for existing ifreload to complete..."
    sleep 2
    waited=$((waited + 2))
done

# Check if already patched
if grep -q "address 10.10.0.1/24" /etc/network/interfaces.d/sdn; then
    echo "SDN config already patched"
else
    echo "Patching SDN config with gateway IPs..."
    
    # Backup original
    cp /etc/network/interfaces.d/sdn /etc/network/interfaces.d/sdn.pre-patch
    
    # Add gateway IPs to each vnet interface
    sed -i "/^iface vnetmgmt$/a\        address 10.10.0.1/24" /etc/network/interfaces.d/sdn
    sed -i "/^iface vnetobs$/a\        address 10.11.0.1/24" /etc/network/interfaces.d/sdn
    sed -i "/^iface vnetdev$/a\        address 10.20.0.1/24" /etc/network/interfaces.d/sdn
    sed -i "/^iface vnetstag$/a\        address 10.30.0.1/24" /etc/network/interfaces.d/sdn
    sed -i "/^iface vnetprod$/a\        address 10.40.0.1/24" /etc/network/interfaces.d/sdn
    sed -i "/^iface vnetlab$/a\        address 10.50.0.1/24" /etc/network/interfaces.d/sdn
    
    echo "SDN config patched successfully"
fi

# Wait a bit more for Proxmox's ifreload to settle
sleep 3

# Apply network config (with retry logic)
max_retries=3
retry=0
while [ $retry -lt $max_retries ]; do
    if ifreload -a 2>&1; then
        echo "Network config applied successfully"
        break
    else
        retry=$((retry + 1))
        if [ $retry -lt $max_retries ]; then
            echo "ifreload failed, retry $retry/$max_retries in 5s..."
            sleep 5
        else
            echo "Warning: ifreload failed after $max_retries attempts"
        fi
    fi
done

# Give interfaces time to come up
sleep 2

# Ensure gateway IPs are assigned (belt and suspenders)
if [ -x /usr/local/bin/assign-sdn-gateway-ips.sh ]; then
    /usr/local/bin/assign-sdn-gateway-ips.sh
fi

# Sync version file for Proxmox status check
mkdir -p /run/pve
if [ -f /etc/pve/sdn/.running-config ]; then
    cat /etc/pve/sdn/.running-config | jq -r .version > /run/pve/.sdn_version 2>/dev/null || true
    echo "Version synced:  $(cat /run/pve/.sdn_version 2>/dev/null || echo 'N/A')"
fi

# Restart pve-cluster to refresh UI status
systemctl restart pve-cluster 2>&1 || echo "Warning: Could not restart pve-cluster"

echo "✅ SDN status fix complete"
FIXSCRIPT

chmod +x /usr/local/bin/fix-sdn-status.sh

# 2.Create systemd service with delays
cat > /etc/systemd/system/sdn-status-fix.service << 'SERVICE'
[Unit]
Description=Fix Proxmox SDN Status Display
After=pve-cluster.service networking.service
Requires=pve-cluster.service

[Service]
Type=oneshot
# Add delay to let Proxmox finish its own ifreload
ExecStartPre=/bin/sleep 5
ExecStart=/usr/local/bin/fix-sdn-status.sh
RemainAfterExit=yes
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
SERVICE

# 3.Create path watcher
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

# 4.Enable and start services
echo "Enabling systemd services..."
systemctl daemon-reload
systemctl enable sdn-status-fix.service
systemctl enable sdn-config-watcher.path
systemctl start sdn-config-watcher.path

# 5.Run fix now
echo "Running initial fix..."
/usr/local/bin/fix-sdn-status.sh

echo ""
echo "✅ SDN auto-fix installed successfully!"
