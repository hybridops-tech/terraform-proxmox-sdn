#!/usr/bin/env bash
# file: setup-nat.sh
# purpose: Configure SNAT and forwarding for a Proxmox SDN VNet subnet via an uplink interface
# architecture decision: ADR-0102
# maintainer: HybridOps.Studio
# date: 2025-12-27

set -euo pipefail

LOG_PREFIX="hybridops-sdn-nat"
RULE_TAG_PREFIX="${RULE_TAG_PREFIX:-proxmox-sdn-nat}"
PERSIST_RULES="${PERSIST_RULES:-true}"  # true|false

if [[ "${EUID}" -ne 0 ]]; then
  echo "${LOG_PREFIX}: must be run as root" >&2
  exit 1
fi

if ! command -v iptables >/dev/null 2>&1; then
  echo "${LOG_PREFIX}: iptables is required" >&2
  exit 1
fi

ZONE_NAME="${1:-}"
VNET_ID="${2:-}"
SUBNET_CIDR="${3:-}"
UPLINK_IF="${4:-vmbr0}"

if [[ -z "${ZONE_NAME}" || -z "${VNET_ID}" || -z "${SUBNET_CIDR}" ]]; then
  echo "Usage: $0 <zone_name> <vnet_id> <subnet_cidr> [uplink_if]" >&2
  exit 2
fi

if ! ip link show "${VNET_ID}" >/dev/null 2>&1; then
  echo "${LOG_PREFIX}: interface ${VNET_ID} not found" >&2
  exit 1
fi

if ! ip link show "${UPLINK_IF}" >/dev/null 2>&1; then
  echo "${LOG_PREFIX}: uplink interface ${UPLINK_IF} not found" >&2
  exit 1
fi

COMMENT="${RULE_TAG_PREFIX}:${ZONE_NAME}:${VNET_ID}:${SUBNET_CIDR}"

# Enable forwarding now; keep persistent via sysctl.d (no /etc/network/interfaces changes)
sysctl -w net.ipv4.ip_forward=1 >/dev/null
SYSCTL_FILE="/etc/sysctl.d/99-hybridops-sdn.conf"
if [[ ! -f "${SYSCTL_FILE}" ]] || ! grep -q '^net\.ipv4\.ip_forward=1$' "${SYSCTL_FILE}" 2>/dev/null; then
  printf "net.ipv4.ip_forward=1\n" > "${SYSCTL_FILE}"
fi

ipt() { iptables -w 5 "$@"; }

add_rule() {
  local table="$1"; shift
  if ipt -t "${table}" -C "$@" 2>/dev/null; then
    return 0
  fi
  ipt -t "${table}" -A "$@"
}

add_rule nat POSTROUTING \
  -s "${SUBNET_CIDR}" -o "${UPLINK_IF}" \
  -m comment --comment "${COMMENT}" \
  -j MASQUERADE

add_rule filter FORWARD \
  -i "${VNET_ID}" -o "${UPLINK_IF}" \
  -s "${SUBNET_CIDR}" \
  -m comment --comment "${COMMENT}" \
  -j ACCEPT

add_rule filter FORWARD \
  -i "${UPLINK_IF}" -o "${VNET_ID}" \
  -d "${SUBNET_CIDR}" \
  -m conntrack --ctstate ESTABLISHED,RELATED \
  -m comment --comment "${COMMENT}" \
  -j ACCEPT

if [[ "${PERSIST_RULES}" == "true" ]]; then
  if command -v netfilter-persistent >/dev/null 2>&1; then
    netfilter-persistent save >/dev/null 2>&1 || true
  elif [[ -d /etc/iptables ]]; then
    iptables-save > /etc/iptables/rules.v4
  fi
fi

echo "${LOG_PREFIX}: configured ${COMMENT} uplink=${UPLINK_IF}"