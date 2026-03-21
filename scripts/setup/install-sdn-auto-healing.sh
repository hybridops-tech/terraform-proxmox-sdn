#!/usr/bin/env bash
# purpose: Install SDN status self-healing (config patch + status refresh) on Proxmox
# architecture decision: ADR-0102
# maintainer: HybridOps

set -euo pipefail

echo "sdn_auto_healing: installing SDN auto-healing components"

cat > /usr/local/bin/fix-sdn-status.sh << 'FIXSCRIPT'
#!/usr/bin/env bash
# purpose: Patch SDN interface config, ensure VNet gateways, and refresh SDN status in Proxmox UI
# architecture decision: ADR-0102
# maintainer: HybridOps

set -euo pipefail

log() {
  echo "fix-sdn-status: $*"
}

if ! command -v pvesh >/dev/null 2>&1; then
  log "pvesh not found; this helper is intended for Proxmox VE nodes only"
  exit 0
fi

SDN_FILE="/etc/network/interfaces.d/sdn"

STATE_DIR="/var/lib/hybridops-sdn/gateway"
ROUTE_STATE_DIR="/var/lib/hybridops-sdn/route"

read_kv() {
  local file="$1" key="$2"
  grep -E "^${key}=" "${file}" | head -n1 | cut -d= -f2- || true
}

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

log "normalising ${SDN_FILE}"
if [ ! -f "${SDN_FILE}" ]; then
  touch "${SDN_FILE}"
fi

shopt -s nullglob
STATE_FILES=("${STATE_DIR}"/hybridops-sdn-gateway-*.env)
DHCP_UNITS=()
ROUTE_STATE_FILES=("${ROUTE_STATE_DIR}"/hybridops-sdn-route-*.env)
if [ "${#STATE_FILES[@]}" -eq 0 ]; then
  log "no gateway state files found under ${STATE_DIR}; skipping gateway/interface reconciliation"
else
  python3 - "${SDN_FILE}" "${STATE_FILES[@]}" <<'PY'
import re
import sys
from pathlib import Path

sdn_path = Path(sys.argv[1])
state_files = [Path(p) for p in sys.argv[2:]]

addr_map = {}
for state_file in state_files:
    values = {}
    for line in state_file.read_text().splitlines():
        if "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key.strip()] = value.strip()
    iface = values.get("VNET_ID")
    gateway = values.get("GATEWAY")
    prefix = values.get("PREFIX")
    if not prefix:
        subnet_cidr = values.get("SUBNET_CIDR", "")
        if "/" in subnet_cidr:
            prefix = subnet_cidr.split("/", 1)[1]
    if iface and gateway and prefix:
        addr_map[iface] = f"{gateway}/{prefix}"

if not addr_map:
    raise SystemExit(0)

lines = sdn_path.read_text().splitlines()
out = []
current_iface = None
address_written = set()

def flush_address_for_iface(iface: str | None) -> None:
    if iface and iface in addr_map and iface not in address_written:
        out.append(f"\taddress {addr_map[iface]}")
        address_written.add(iface)

for line in lines:
    iface_match = re.match(r"^iface\s+(\S+)(?:\s+.*)?$", line)
    auto_match = re.match(r"^auto\s+(\S+)$", line)

    if iface_match:
        flush_address_for_iface(current_iface)
        current_iface = iface_match.group(1)
        if current_iface in addr_map:
            line = f"iface {current_iface} inet static"
    elif auto_match:
        flush_address_for_iface(current_iface)
        current_iface = None
    elif current_iface in addr_map and re.match(r"^\s*address\s+", line):
        # Replace any previously injected or stale address line with the current derived gateway.
        continue

    out.append(line)

flush_address_for_iface(current_iface)
sdn_path.write_text("\n".join(out) + "\n")
PY
fi

for STATE_FILE in "${STATE_FILES[@]}"; do
  IFACE="$(read_kv "${STATE_FILE}" "VNET_ID")"
  ZONE_NAME="$(read_kv "${STATE_FILE}" "ZONE_NAME")"
  SUBNET_CIDR="$(read_kv "${STATE_FILE}" "SUBNET_CIDR")"
  GATEWAY="$(read_kv "${STATE_FILE}" "GATEWAY")"
  PREFIX="$(read_kv "${STATE_FILE}" "PREFIX")"
  if [ -z "${PREFIX}" ]; then
    PREFIX="${SUBNET_CIDR#*/}"
  fi
  if [ -z "${IFACE}" ] || [ -z "${ZONE_NAME}" ] || [ -z "${SUBNET_CIDR}" ] || [ -z "${GATEWAY}" ] || [ -z "${PREFIX}" ]; then
    log "skipping malformed state file ${STATE_FILE}"
    continue
  fi
  if ! ip link show "${IFACE}" >/dev/null 2>&1; then
    continue
  fi

  IP="${GATEWAY}"

  if ! ip -4 addr show dev "${IFACE}" | grep -q " ${IP}/${PREFIX}"; then
    log "ensuring ${IP}/${PREFIX} on ${IFACE}"
    ip addr flush dev "${IFACE}" || true
    ip addr add "${IP}/${PREFIX}" dev "${IFACE}"
    ip link set "${IFACE}" up
  fi

  NETWORK="${SUBNET_CIDR%/*}"
  DHCP_SERVICE="dnsmasq@hybridops-sdn-dhcp-${IFACE}-${ZONE_NAME}-${NETWORK//./-}-${PREFIX}.service"
  if systemctl list-unit-files "${DHCP_SERVICE}" --no-legend >/dev/null 2>&1; then
    DHCP_UNITS+=("${DHCP_SERVICE}")
  fi
done

if [ "${#ROUTE_STATE_FILES[@]}" -eq 0 ]; then
  log "no managed static route state files found under ${ROUTE_STATE_DIR}; skipping route reconciliation"
else
  for ROUTE_STATE_FILE in "${ROUTE_STATE_FILES[@]}"; do
    DESTINATION_CIDR="$(read_kv "${ROUTE_STATE_FILE}" "DESTINATION_CIDR")"
    NEXT_HOP="$(read_kv "${ROUTE_STATE_FILE}" "NEXT_HOP")"
    if [ -z "${DESTINATION_CIDR}" ] || [ -z "${NEXT_HOP}" ]; then
      log "skipping malformed route state file ${ROUTE_STATE_FILE}"
      continue
    fi

    if ! ip route get "${NEXT_HOP}" >/dev/null 2>&1; then
      log "cannot reach next-hop ${NEXT_HOP} for ${DESTINATION_CIDR}; leaving route untouched"
      continue
    fi

    log "ensuring static route ${DESTINATION_CIDR} via ${NEXT_HOP}"
    ip route replace "${DESTINATION_CIDR}" via "${NEXT_HOP}"
  done
fi

if [ "${#DHCP_UNITS[@]}" -gt 0 ]; then
  log "restarting HybridOps SDN DHCP units"
  printf '%s\n' "${DHCP_UNITS[@]}" | sort -u | while read -r UNIT; do
    [ -n "${UNIT}" ] || continue
    log " -> ${UNIT}"
    systemctl enable "${UNIT}" >/dev/null 2>&1 || true
    systemctl restart "${UNIT}" || true
  done
else
  log "no matching HybridOps SDN DHCP units found for managed VNets; skipping DHCP restart"
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
