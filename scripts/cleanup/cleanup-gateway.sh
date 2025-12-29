#!/usr/bin/env bash
# file: cleanup-gateway.sh
# purpose: Remove subnet gateway IP from a Proxmox SDN VNet interface (L3 gateway only)
# architecture decision: ADR-0101
# maintainer: HybridOps.Studio
# date: 2025-12-27

set -euo pipefail

LOG_PREFIX="hybridops-sdn-gateway"
STATE_DIR="/var/lib/hybridops-sdn/gateway"

if [[ "${EUID}" -ne 0 ]]; then
  echo "${LOG_PREFIX}: must be run as root" >&2
  exit 1
fi

MODE="${1:-}"
ZONE_NAME="${2:-}"

usage() {
  echo "Usage:" >&2
  echo "  $0 single <zone_name> <vnet_id> <subnet_cidr> <gateway>" >&2
  echo "  $0 zone   <zone_name>" >&2
}

remove_one() {
  local zone_name="$1"
  local vnet_id="$2"
  local subnet_cidr="$3"
  local gateway="$4"

  local network="${subnet_cidr%/*}"
  local prefix="${subnet_cidr#*/}"
  local service_name="hybridops-sdn-gateway-${vnet_id}-${zone_name}-${network//./-}-${prefix}"
  local state_file="${STATE_DIR}/${service_name}.env"

  if ip link show "${vnet_id}" &>/dev/null; then
    if ip -4 addr show dev "${vnet_id}" | grep -qE "inet ${gateway}/${prefix}\b"; then
      ip addr del "${gateway}/${prefix}" dev "${vnet_id}" || true
    fi
  fi

  rm -f "${state_file}"
  echo "${LOG_PREFIX}: gateway removed vnet=${vnet_id} cidr=${subnet_cidr} gw=${gateway}"
}

read_kv() {
  local file="$1" key="$2"
  grep -E "^${key}=" "${file}" | head -n1 | cut -d= -f2- || true
}

if [[ -z "${MODE}" || -z "${ZONE_NAME}" ]]; then
  usage
  exit 1
fi

case "${MODE}" in
  single)
    VNET_ID="${3:-}"
    SUBNET_CIDR="${4:-}"
    GATEWAY="${5:-}"
    if [[ -z "${VNET_ID}" || -z "${SUBNET_CIDR}" || -z "${GATEWAY}" ]]; then
      usage
      exit 1
    fi
    remove_one "${ZONE_NAME}" "${VNET_ID}" "${SUBNET_CIDR}" "${GATEWAY}"
    ;;

  zone)
    shopt -s nullglob
    for f in "${STATE_DIR}"/hybridops-sdn-gateway-*"${ZONE_NAME}"-*.env; do
      vnet_id="$(read_kv "${f}" "VNET_ID")"
      subnet_cidr="$(read_kv "${f}" "SUBNET_CIDR")"
      gateway="$(read_kv "${f}" "GATEWAY")"

      if [[ -n "${vnet_id}" && -n "${subnet_cidr}" && -n "${gateway}" ]]; then
        remove_one "${ZONE_NAME}" "${vnet_id}" "${subnet_cidr}" "${gateway}" || true
      else
        rm -f "${f}" || true
      fi
    done
    ;;

  *)
    usage
    exit 1
    ;;
esac