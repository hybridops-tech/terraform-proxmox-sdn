#!/usr/bin/env bash
# file: cleanup-dhcp.sh
# purpose: Remove dnsmasq DHCP services created for Proxmox SDN VNet interfaces
# architecture decision: ADR-0101
# maintainer: HybridOps.Studio
# date: 2025-12-27

set -euo pipefail

LOG_PREFIX="hybridops-sdn-dhcp-cleanup"

MODE="${1:-}"
ZONE_NAME="${2:-}"
VNET_ID="${3:-}"
SUBNET_CIDR="${4:-}"

if [[ "${EUID}" -ne 0 ]]; then
  echo "${LOG_PREFIX}: must be run as root" >&2
  exit 1
fi

stop_disable_remove_unit() {
  local unit_name="$1"
  systemctl stop "${unit_name}" >/dev/null 2>&1 || true
  systemctl disable "${unit_name}" >/dev/null 2>&1 || true
  rm -f "/etc/systemd/system/${unit_name}"
}

service_name_for() {
  local zone="$1"
  local vnet="$2"
  local cidr="$3"

  IFS=/ read -r network mask <<< "${cidr}"
  local network_id="${network//./-}"
  echo "hybridops-sdn-dhcp-${vnet}-${zone}-${network_id}-${mask}"
}

cleanup_single() {
  local zone="$1"
  local vnet="$2"
  local cidr="$3"

  if [[ -z "${zone}" || -z "${vnet}" || -z "${cidr}" ]]; then
    echo "Usage: $0 single <zone_name> <vnet_id> <subnet_cidr>" >&2
    exit 2
  fi

  local svc
  svc="$(service_name_for "${zone}" "${vnet}" "${cidr}")"

  local unit="dnsmasq@${svc}.service"
  local conf="/etc/dnsmasq.d/dhcp-${svc}.conf"
  local lease="/var/lib/misc/dnsmasq-${svc}.leases"
  local pid="/run/dnsmasq-${svc}.pid"

  if [[ -f "/etc/systemd/system/${unit}" ]]; then
    stop_disable_remove_unit "${unit}"
  else
    systemctl stop "${unit}" >/dev/null 2>&1 || true
    systemctl disable "${unit}" >/dev/null 2>&1 || true
  fi

  rm -f "${conf}" "${lease}" "${pid}"
}

cleanup_zone() {
  local zone="$1"
  if [[ -z "${zone}" ]]; then
    echo "Usage: $0 zone <zone_name>" >&2
    exit 2
  fi

  shopt -s nullglob

  for unit_file in /etc/systemd/system/dnsmasq@hybridops-sdn-dhcp-*-"${zone}"-*.service; do
    stop_disable_remove_unit "$(basename "${unit_file}")"
  done

  rm -f /etc/dnsmasq.d/dhcp-hybridops-sdn-dhcp-*-"${zone}"-*.conf || true
  rm -f /var/lib/misc/dnsmasq-hybridops-sdn-dhcp-*-"${zone}"-*.leases || true
  rm -f /run/dnsmasq-hybridops-sdn-dhcp-*-"${zone}"-*.pid || true
}

if [[ -z "${MODE}" || -z "${ZONE_NAME}" ]]; then
  echo "Usage: $0 {single|zone} <zone_name> [vnet_id] [subnet_cidr]" >&2
  exit 2
fi

case "${MODE}" in
  single)
    cleanup_single "${ZONE_NAME}" "${VNET_ID}" "${SUBNET_CIDR}"
    ;;
  zone)
    cleanup_zone "${ZONE_NAME}"
    ;;
  *)
    echo "Usage: $0 {single|zone} <zone_name> [vnet_id] [subnet_cidr]" >&2
    exit 2
    ;;
esac

systemctl daemon-reload
systemctl reset-failed >/dev/null 2>&1 || true

echo "${LOG_PREFIX}: completed mode=${MODE} zone=${ZONE_NAME}"