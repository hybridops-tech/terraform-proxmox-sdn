#!/usr/bin/env bash
# purpose: Configure a persistent HybridOps-managed static route on the Proxmox host
# architecture decision: ADR-0102
# maintainer: HybridOps

set -euo pipefail

LOG_PREFIX="hybridops-sdn-route"

if [[ "${EUID}" -ne 0 ]]; then
  echo "${LOG_PREFIX}: must be run as root" >&2
  exit 1
fi

ZONE_NAME="${1:-}"
DESTINATION_CIDR="${2:-}"
NEXT_HOP="${3:-}"

if [[ -z "${ZONE_NAME}" || -z "${DESTINATION_CIDR}" || -z "${NEXT_HOP}" ]]; then
  echo "Usage: $0 <zone_name> <destination_cidr> <next_hop>" >&2
  exit 1
fi

STATE_DIR="/var/lib/hybridops-sdn/route"
SERVICE_NAME="hybridops-sdn-route-${ZONE_NAME}-${DESTINATION_CIDR//[.\/]/-}-via-${NEXT_HOP//./-}"
STATE_FILE="${STATE_DIR}/${SERVICE_NAME}.env"

if ! ip route get "${NEXT_HOP}" >/dev/null 2>&1; then
  echo "${LOG_PREFIX}: next-hop '${NEXT_HOP}' is not reachable from this host" >&2
  exit 1
fi

ip route replace "${DESTINATION_CIDR}" via "${NEXT_HOP}"

mkdir -p "${STATE_DIR}"
cat > "${STATE_FILE}" <<EOF
ZONE_NAME=${ZONE_NAME}
DESTINATION_CIDR=${DESTINATION_CIDR}
NEXT_HOP=${NEXT_HOP}
SERVICE_NAME=${SERVICE_NAME}
EOF

echo "${LOG_PREFIX}: route configured dest=${DESTINATION_CIDR} via=${NEXT_HOP}"
