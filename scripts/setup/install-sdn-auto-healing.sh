#!/usr/bin/env bash
# purpose: Install SDN status self-healing (config patch + status refresh) on Proxmox
# architecture decision: ADR-0102
# maintainer: HybridOps.Studio

set -euo pipefail

echo "sdn_auto_healing: installing SDN auto-healing components"

cat > /usr/local/bin/fix-sdn-status.sh << 'FIXSCRIPT'
#!/usr/bin/env bash
# purpose: Patch SDN interface config, ensure VNet gateways, and refresh SDN status in Proxmox UI
# architecture decision: ADR-0102
# maintainer: HybridOps.Studio

set -euo pipefail

log() {
  echo "fix-sdn-status: $*"
}

if ! command -v pvesh >/dev/null 2>&1; then
  log "pvesh not found; this helper is intended for Proxmox VE nodes only"
  exit 0
fi

SDN_FILE="/etc/network/interfaces.d/sdn"

log "normalising ${SDN_FILE}"
if [ ! -f "${SDN_FILE}" ]; then
  touch "${SDN_FILE}"
fi

# HybridOps reference layout: VLANs 10/11/20/30/40/50 -> 10.10/11/20/30/40/50.0.0/24.
declare -A GW_CIDR=(
  ["vnetmgmt"]="10.10.0.1/24"
  ["vnetobs"]="10.11.0.1/24"
  ["vnetdev"]="10.20.0.1/24"
  ["vnetstag"]="10.30.0.1/24"
  ["vnetprod"]="10.40.0.1/24"
  ["vnetlab"]="10.50.0.1/24"
)

cidr_to_netmask() {
  case "$1" in
    24) echo "255.255.255.0" ;;
    16) echo "255.255.0.0" ;;
    8)  echo "255.0.0.0" ;;
    *)  echo "" ;;
  esac
}

for IFACE in "${!GW_CIDR[@]}"; do
  if ! ip link show "${IFACE}" >/dev/null 2>&1; then
    continue
  fi

  CIDR="${GW_CIDR[${IFACE}]}"
  IP="${CIDR%/*}"
  PREFIX="${CIDR#*/}"
  NETMASK="$(cidr_to_netmask "${PREFIX}")"

  if [ -n "${NETMASK}" ] && ! grep -qE "^iface ${IFACE} inet " "${SDN_FILE}"; then
    log "adding ${IFACE} stanza to ${SDN_FILE}"
    {
      echo ""
      echo "auto ${IFACE}"
      echo "iface ${IFACE} inet static"
      echo "  address ${IP}"
      echo "  netmask ${NETMASK}"
    } >> "${SDN_FILE}"
  fi

  if ! ip -4 addr show dev "${IFACE}" | grep -q " ${IP}/${PREFIX}"; then
    log "ensuring ${IP}/${PREFIX} on ${IFACE}"
    ip addr flush dev "${IFACE}" || true
    ip addr add "${IP}/${PREFIX}" dev "${IFACE}"
    ip link set "${IFACE}" up
  fi
done

if pvesh ls /cluster/sdn >/dev/null 2>&1; then
  if pvesh set /cluster/sdn >/dev/null 2>&1; then
    log "pvesh set /cluster/sdn succeeded"
  elif pvesh set /cluster/sdn/reload >/dev/null 2>&1; then
    log "pvesh set /cluster/sdn/reload succeeded"
  else
    log "could not refresh /cluster/sdn via pvesh"
  fi
else
  log "/cluster/sdn endpoint not available"
fi

UNITS=$(systemctl list-unit-files 'dnsmasq@hybridops-sdn-dhcp-*' --no-legend 2>/dev/null | awk '{print $1}' || true)

if [ -n "${UNITS}" ]; then
  log "restarting HybridOps SDN DHCP units"
  echo "${UNITS}" | while read -r UNIT; do
    [ -n "${UNIT}" ] || continue
    log " -> ${UNIT}"
    systemctl enable "${UNIT}" >/dev/null 2>&1 || true
    systemctl restart "${UNIT}" || true
  done
else
  log "no dnsmasq@hybridops-sdn-dhcp-* units found; skipping DHCP restart"
fi

log "completed SDN status fix"
FIXSCRIPT

chmod +x /usr/local/bin/fix-sdn-status.sh

cat > /etc/systemd/system/sdn-status-fix.service << 'SERVICED'
[Unit]
Description=HybridOps SDN status auto-fix
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/fix-sdn-status.sh
User=root
Group=root

[Install]
WantedBy=multi-user.target
SERVICED

cat > /etc/systemd/system/sdn-config-watcher.path << 'PATHUNIT'
[Unit]
Description=Watch Proxmox SDN config and trigger status auto-fix

[Path]
Unit=sdn-status-fix.service
PathModified=/etc/pve/sdn
PathModified=/etc/network/interfaces.d/sdn

[Install]
WantedBy=multi-user.target
PATHUNIT

echo "sdn_auto_healing: enabling systemd units"
systemctl daemon-reload
systemctl enable sdn-status-fix.service
systemctl enable sdn-config-watcher.path
systemctl start sdn-config-watcher.path

echo "sdn_auto_healing: running initial fix"
/usr/local/bin/fix-sdn-status.sh || true

echo "sdn_auto_healing: installation complete"
