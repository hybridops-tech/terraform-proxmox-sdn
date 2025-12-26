#!/usr/bin/env bash
# file: control/tools/helper/proxmox/sdn_cleanup.sh
# purpose: Cleanup Proxmox SDN DHCP services, VNets, and zones for Terraform-managed VLAN SDN
# maintainer: HybridOps.Studio
# date: 2025-12-26

set -euo pipefail

MODE="${1:-single}"
ZONE_NAME="${2:-}"
VNET_ID="${3:-}"
SUBNET_CIDR="${4:-}"

cleanup_vnet_dhcp() {
    local zone="$1"
    local vnet="$2"
    local cidr="$3"

    local network mask gateway service_name
    network="${cidr%/*}"
    mask="${cidr#*/}"
    gateway="$(echo "${network}" | awk -F. '{print $1 "." $2 "." $3 ".1"}')"
    service_name="${vnet}-${zone}-${network//./-}-${mask}"

    echo "sdn_cleanup: vnet=${vnet} zone=${zone} cidr=${cidr}"

    systemctl stop "dnsmasq@${service_name}.service" 2>/dev/null || true
    systemctl disable "dnsmasq@${service_name}.service" 2>/dev/null || true

    if ip link show "${vnet}" &>/dev/null; then
        ip addr del "${gateway}/${mask}" dev "${vnet}" 2>/dev/null || true
        ip link set "${vnet}" down 2>/dev/null || true
        ip link delete "${vnet}" 2>/dev/null || true
    fi

    rm -f "/etc/dnsmasq.d/${service_name}.conf"
    rm -f "/etc/systemd/system/dnsmasq@${service_name}.service"
    rm -f "/var/lib/misc/dnsmasq.${service_name}.leases"
    rm -f "/run/dnsmasq/dnsmasq-${service_name}.pid"

    pvesh delete "/cluster/sdn/vnets/${vnet}" 2>/dev/null || true
}

cleanup_zone() {
    local zone="$1"
    local vnets=""

    echo "sdn_cleanup: zone=${zone}"

    if command -v jq &>/dev/null; then
        vnets="$(
          pvesh get /cluster/sdn/vnets --output-format=json 2>/dev/null \
          | jq -r --arg zone "${zone}" '.[] | select(.zone == $zone) | .vnet' \
          2>/dev/null || echo ""
        )"
    fi

    if [[ -n "${vnets}" ]]; then
        for vnet in ${vnets}; do
            pvesh delete "/cluster/sdn/vnets/${vnet}" 2>/dev/null || true

            local service_pattern="${vnet}-${zone}-*"

            shopt -s nullglob
            for service_file in /etc/systemd/system/dnsmasq@${service_pattern}.service; do
                if [[ -f "${service_file}" ]]; then
                    local service_name
                    service_name="$(basename "${service_file}" .service | sed 's/^dnsmasq@//')"
                    systemctl stop "dnsmasq@${service_name}.service" 2>/dev/null || true
                    systemctl disable "dnsmasq@${service_name}.service" 2>/dev/null || true
                    rm -f "${service_file}"
                fi
            done
            shopt -u nullglob

            rm -f "/etc/dnsmasq.d/${vnet}-${zone}-"*.conf
            rm -f "/var/lib/misc/dnsmasq.${vnet}-${zone}-"*.leases
            rm -f "/run/dnsmasq/dnsmasq-${vnet}-${zone}-"*.pid
        done
    fi

    pvesh delete "/cluster/sdn/zones/${zone}" 2>/dev/null || true

    if [[ -f /etc/pve/sdn/zones.cfg ]]; then
        sed -i "/^vlan:[[:space:]]\+${zone}\$/,/^$/d" /etc/pve/sdn/zones.cfg 2>/dev/null || true
    fi

    if [[ -f /etc/pve/sdn/vnets.cfg && -n "${vnets}" ]]; then
        for vnet in ${vnets}; do
            sed -i "/^vnet:[[:space:]]\+${vnet}\$/,/^$/d" /etc/pve/sdn/vnets.cfg 2>/dev/null || true
        done
    fi

    if [[ -f /etc/pve/sdn/subnets.cfg ]]; then
        sed -i "/^subnet:[[:space:]]\+${zone}-/,/^$/d" /etc/pve/sdn/subnets.cfg 2>/dev/null || true
    fi

    rm -f /etc/pve/sdn/.running-config

    for file in /etc/network/interfaces.d/sdn.backup /etc/network/interfaces.d/sdn.pre-patch; do
        if [[ -f "${file}" ]]; then
            sed -i '/^[[:space:]]*bridge_/d; /^[[:space:]]*mtu/d' "${file}" 2>/dev/null || true
            sed -i '/^$/N;/^\n$/D' "${file}" 2>/dev/null || true
        fi
    done

    rm -f /etc/dnsmasq.d/*-"${zone}"-*.conf

    if [[ -n "${vnets}" ]]; then
        for vnet in ${vnets}; do
            if ip link show "${vnet}" &>/dev/null; then
                ip link set "${vnet}" down 2>/dev/null || true
                ip link delete "${vnet}" 2>/dev/null || true
            fi
        done
    fi

    pvesh set /cluster/sdn 2>/dev/null || true
    sleep 3
    pvesh set /cluster/sdn 2>/dev/null || true
}

case "${MODE}" in
    single)
        if [[ -z "${ZONE_NAME}" || -z "${VNET_ID}" || -z "${SUBNET_CIDR}" ]]; then
            echo "Usage: $0 single <zone_name> <vnet_id> <subnet_cidr>" >&2
            exit 1
        fi
        cleanup_vnet_dhcp "${ZONE_NAME}" "${VNET_ID}" "${SUBNET_CIDR}"
        ;;
    zone)
        if [[ -z "${ZONE_NAME}" ]]; then
            echo "Usage: $0 zone <zone_name>" >&2
            exit 1
        fi
        cleanup_zone "${ZONE_NAME}"
        ;;
    *)
        echo "Usage: $0 {single|zone} <args>" >&2
        exit 1
        ;;
esac

systemctl daemon-reload
systemctl reset-failed 2>/dev/null || true
