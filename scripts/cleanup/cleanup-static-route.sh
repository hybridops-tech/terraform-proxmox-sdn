#!/usr/bin/env bash
# purpose: Remove a HybridOps-managed static route from the Proxmox host
# architecture decision: ADR-0102
# maintainer: HybridOps

set -euo pipefail

LOG_PREFIX="hybridops-sdn-route"
STATE_DIR="/var/lib/hybridops-sdn/route"

if [[ "${EUID}" -ne 0 ]]; then
  echo "${LOG_PREFIX}: must be run as root" >&2
  exit 1
fi

MODE="${1:-}"
ZONE_NAME="${2:-}"

usage() {
  echo "Usage:" >&2
  echo "  $0 single <zone_name> <destination_cidr> <next_hop>" >&2
  echo "  $0 zone   <zone_name>" >&2
}

remove_one() {
  local zone_name="$1"
  local destination_cidr="$2"
  local next_hop="$3"
  local service_name="hybridops-sdn-route-${zone_name}-${destination_cidr//[.\/]/-}-via-${next_hop//./-}"
  local state_file="${STATE_DIR}/${service_name}.env"

  ip route del "${destination_cidr}" via "${next_hop}" >/dev/null 2>&1 || ip route del "${destination_cidr}" >/dev/null 2>&1 || true
  rm -f "${state_file}"
  echo "${LOG_PREFIX}: route removed dest=${destination_cidr} via=${next_hop}"
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
    DESTINATION_CIDR="${3:-}"
    NEXT_HOP="${4:-}"
    if [[ -z "${DESTINATION_CIDR}" || -z "${NEXT_HOP}" ]]; then
      usage
      exit 1
    fi
    remove_one "${ZONE_NAME}" "${DESTINATION_CIDR}" "${NEXT_HOP}"
    ;;

  zone)
    shopt -s nullglob
    for f in "${STATE_DIR}"/hybridops-sdn-route-"${ZONE_NAME}"-*.env; do
      destination_cidr="$(read_kv "${f}" "DESTINATION_CIDR")"
      next_hop="$(read_kv "${f}" "NEXT_HOP")"

      if [[ -n "${destination_cidr}" && -n "${next_hop}" ]]; then
        remove_one "${ZONE_NAME}" "${destination_cidr}" "${next_hop}" || true
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
