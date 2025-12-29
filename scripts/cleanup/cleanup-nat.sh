#!/usr/bin/env bash
# file: cleanup-nat.sh
# purpose: Remove SNAT and forwarding rules created for Proxmox SDN VNets using iptables comment tags
# architecture decision: ADR-0102
# maintainer: HybridOps.Studio
# date: 2025-12-27

set -euo pipefail

LOG_PREFIX="hybridops-sdn-nat-cleanup"
RULE_TAG_PREFIX="${RULE_TAG_PREFIX:-proxmox-sdn-nat}"
PERSIST_RULES="${PERSIST_RULES:-true}" # true|false

if [[ "${EUID}" -ne 0 ]]; then
  echo "${LOG_PREFIX}: must be run as root" >&2
  exit 1
fi

if ! command -v iptables >/dev/null 2>&1; then
  echo "${LOG_PREFIX}: iptables is required" >&2
  exit 1
fi

MODE="${1:-}"
ZONE_NAME="${2:-}"

if [[ -z "${MODE}" || -z "${ZONE_NAME}" ]]; then
  echo "Usage: $0 single <zone_name> <vnet_id> <subnet_cidr> [uplink_if] | $0 zone <zone_name>" >&2
  exit 2
fi

ipt() { iptables -w 5 "$@"; }

delete_while_present() {
  local table="$1"; shift
  while ipt -t "${table}" -C "$@" 2>/dev/null; do
    ipt -t "${table}" -D "$@" || true
  done
}

cleanup_single() {
  local vnet_id="$1"
  local subnet_cidr="$2"
  local uplink_if="$3"
  local comment="${RULE_TAG_PREFIX}:${ZONE_NAME}:${vnet_id}:${subnet_cidr}"

  delete_while_present nat POSTROUTING \
    -s "${subnet_cidr}" -o "${uplink_if}" \
    -m comment --comment "${comment}" \
    -j MASQUERADE

  delete_while_present filter FORWARD \
    -i "${vnet_id}" -o "${uplink_if}" \
    -s "${subnet_cidr}" \
    -m comment --comment "${comment}" \
    -j ACCEPT

  delete_while_present filter FORWARD \
    -i "${uplink_if}" -o "${vnet_id}" \
    -d "${subnet_cidr}" \
    -m conntrack --ctstate ESTABLISHED,RELATED \
    -m comment --comment "${comment}" \
    -j ACCEPT
}

cleanup_zone_chain() {
  local table="$1"
  local chain="$2"
  local match="${RULE_TAG_PREFIX}:${ZONE_NAME}:"

  while IFS= read -r line; do
    [[ -z "${line}" ]] && continue
    read -r -a args <<< "${line}"
    [[ "${#args[@]}" -lt 2 ]] && continue
    [[ "${args[0]}" != "-A" ]] && continue
    args[0]="-D"
    ipt -t "${table}" "${args[@]}" 2>/dev/null || true
  done < <(ipt -t "${table}" -S "${chain}" | grep -F "${match}" || true)
}

persist_rules() {
  if [[ "${PERSIST_RULES}" != "true" ]]; then
    return 0
  fi

  if command -v netfilter-persistent >/dev/null 2>&1; then
    netfilter-persistent save >/dev/null 2>&1 || true
    return 0
  fi

  if [[ -d /etc/iptables ]]; then
    iptables-save > /etc/iptables/rules.v4
  fi
}

case "${MODE}" in
  single)
    VNET_ID="${3:-}"
    SUBNET_CIDR="${4:-}"
    UPLINK_IF="${5:-vmbr0}"
    if [[ -z "${VNET_ID}" || -z "${SUBNET_CIDR}" ]]; then
      echo "Usage: $0 single <zone_name> <vnet_id> <subnet_cidr> [uplink_if]" >&2
      exit 2
    fi
    cleanup_single "${VNET_ID}" "${SUBNET_CIDR}" "${UPLINK_IF}"
    ;;
  zone)
    cleanup_zone_chain nat POSTROUTING
    cleanup_zone_chain filter FORWARD
    ;;
  *)
    echo "Invalid mode: ${MODE}" >&2
    exit 2
    ;;
esac

persist_rules

echo "${LOG_PREFIX}: completed mode=${MODE} zone=${ZONE_NAME}"