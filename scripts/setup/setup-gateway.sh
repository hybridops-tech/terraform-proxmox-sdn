#!/usr/bin/env bash
# file: setup-gateway.sh
# purpose: Assign subnet gateway IP to a Proxmox SDN VNet interface (L3 gateway only)
# architecture decision: ADR-0101
# maintainer: HybridOps.Studio
# date: 2025-12-27

set -euo pipefail

LOG_PREFIX="hybridops-sdn-gateway"

if [[ "${EUID}" -ne 0 ]]; then
  echo "${LOG_PREFIX}: must be run as root" >&2
  exit 1
fi

ZONE_NAME="${1:-}"
VNET_ID="${2:-}"
SUBNET_CIDR="${3:-}"
GATEWAY="${4:-}"

if [[ -z "${ZONE_NAME}" || -z "${VNET_ID}" || -z "${SUBNET_CIDR}" || -z "${GATEWAY}" ]]; then
  echo "Usage: $0 <zone_name> <vnet_id> <subnet_cidr> <gateway>" >&2
  exit 1
fi

NETWORK="${SUBNET_CIDR%/*}"
PREFIX="${SUBNET_CIDR#*/}"
SERVICE_NAME="hybridops-sdn-gateway-${VNET_ID}-${ZONE_NAME}-${NETWORK//./-}-${PREFIX}"

STATE_DIR="/var/lib/hybridops-sdn/gateway"
STATE_FILE="${STATE_DIR}/${SERVICE_NAME}.env"

MAX_RETRIES=60
for ((i=0; i<MAX_RETRIES; i++)); do
  if ip link show "${VNET_ID}" &>/dev/null; then
    break
  fi
  sleep 1
done

if ! ip link show "${VNET_ID}" &>/dev/null; then
  echo "${LOG_PREFIX}: interface '${VNET_ID}' not found" >&2
  exit 1
fi

ip link set "${VNET_ID}" up >/dev/null 2>&1 || true
ip addr replace "${GATEWAY}/${PREFIX}" dev "${VNET_ID}"

mkdir -p "${STATE_DIR}"
cat > "${STATE_FILE}" <<EOF
ZONE_NAME=${ZONE_NAME}
VNET_ID=${VNET_ID}
SUBNET_CIDR=${SUBNET_CIDR}
GATEWAY=${GATEWAY}
PREFIX=${PREFIX}
SERVICE_NAME=${SERVICE_NAME}
EOF

echo "${LOG_PREFIX}: gateway configured vnet=${VNET_ID} cidr=${SUBNET_CIDR} gw=${GATEWAY}"