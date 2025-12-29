#!/usr/bin/env bash
# file: setup-dhcp.sh
# purpose: Configure dnsmasq DHCP service for a Proxmox SDN VNet interface
# architecture decision: ADR-0101
# maintainer: HybridOps.Studio
# date: 2025-12-27

set -euo pipefail

LOG_PREFIX="hybridops-sdn-dhcp"

ZONE_NAME="${1:-}"
VNET_ID="${2:-}"
SUBNET_CIDR="${3:-}"
GATEWAY="${4:-}"
RANGE_START="${5:-}"
RANGE_END="${6:-}"
DNS_SERVER="${7:-}"
DNS_DOMAIN="${8:-}"
LEASE_TIME="${9:-}"

if [[ -z "${ZONE_NAME}" || -z "${VNET_ID}" || -z "${SUBNET_CIDR}" || -z "${GATEWAY}" || -z "${RANGE_START}" || -z "${RANGE_END}" || -z "${DNS_SERVER}" || -z "${DNS_DOMAIN}" || -z "${LEASE_TIME}" ]]; then
  echo "Usage: $0 <zone_name> <vnet_id> <subnet_cidr> <gateway> <range_start> <range_end> <dns_server> <dns_domain> <lease_time>" >&2
  exit 2
fi

if [[ "${EUID}" -ne 0 ]]; then
  echo "${LOG_PREFIX}: must be run as root" >&2
  exit 1
fi

if ! command -v dnsmasq >/dev/null 2>&1; then
  echo "${LOG_PREFIX}: dnsmasq is not installed" >&2
  exit 1
fi

RETRY=0
MAX_RETRIES=60
while (( RETRY < MAX_RETRIES )); do
  if ip link show "${VNET_ID}" >/dev/null 2>&1; then
    break
  fi
  sleep 1
  RETRY=$((RETRY + 1))
done

if ! ip link show "${VNET_ID}" >/dev/null 2>&1; then
  echo "${LOG_PREFIX}: interface '${VNET_ID}' not found" >&2
  exit 1
fi

ip link set "${VNET_ID}" up >/dev/null 2>&1 || true

RETRY=0
MAX_RETRIES=60
while (( RETRY < MAX_RETRIES )); do
  if ip -4 addr show dev "${VNET_ID}" | grep -Eq "\\b${GATEWAY}(/|\\b)"; then
    break
  fi
  sleep 1
  RETRY=$((RETRY + 1))
done

if ! ip -4 addr show dev "${VNET_ID}" | grep -Eq "\\b${GATEWAY}(/|\\b)"; then
  echo "${LOG_PREFIX}: gateway '${GATEWAY}' not present on '${VNET_ID}' (SDN gateway not ready)" >&2
  exit 1
fi

IFS=/ read -r NETWORK MASK <<< "${SUBNET_CIDR}"
NETWORK_ID="${NETWORK//./-}"
SERVICE_NAME="hybridops-sdn-dhcp-${VNET_ID}-${ZONE_NAME}-${NETWORK_ID}-${MASK}"

CONF_FILE="/etc/dnsmasq.d/dhcp-${SERVICE_NAME}.conf"
LEASE_FILE="/var/lib/misc/dnsmasq-${SERVICE_NAME}.leases"
PID_FILE="/run/dnsmasq-${SERVICE_NAME}.pid"
UNIT_FILE="/etc/systemd/system/dnsmasq@${SERVICE_NAME}.service"

mkdir -p /etc/dnsmasq.d /var/lib/misc

cat > "${CONF_FILE}" <<EOF
port=0
interface=${VNET_ID}
bind-interfaces
dhcp-authoritative
dhcp-leasefile=${LEASE_FILE}
dhcp-range=${RANGE_START},${RANGE_END},${LEASE_TIME}
dhcp-option=option:router,${GATEWAY}
dhcp-option=option:dns-server,${DNS_SERVER}
dhcp-option=option:domain-name,${DNS_DOMAIN}
EOF

cat > "${UNIT_FILE}" <<EOF
[Unit]
Description=dnsmasq DHCP for ${VNET_ID} (${SUBNET_CIDR})
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/sbin/dnsmasq --keep-in-foreground --conf-file=${CONF_FILE} --pid-file=${PID_FILE}
Restart=on-failure
RestartSec=2

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload

if systemctl is-enabled "dnsmasq@${SERVICE_NAME}.service" >/dev/null 2>&1; then
  systemctl restart "dnsmasq@${SERVICE_NAME}.service" >/dev/null
else
  systemctl enable --now "dnsmasq@${SERVICE_NAME}.service" >/dev/null
fi

echo "${LOG_PREFIX}: configured service=${SERVICE_NAME} vnet=${VNET_ID} cidr=${SUBNET_CIDR}"