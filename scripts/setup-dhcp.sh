#!/usr/bin/env bash
# file: control/tools/helper/proxmox/sdn_configure_dhcp.sh
# purpose: Configure dnsmasq DHCP service for a Proxmox SDN VLAN VNet
# maintainer: HybridOps.Studio
# date: 2025-12-26

set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
    echo "This script must be run as root" >&2
    exit 1
fi

ZONE_NAME="${1:-}"
VNET_ID="${2:-}"
SUBNET_CIDR="${3:-}"
GATEWAY="${4:-}"
DHCP_RANGE_START="${5:-}"
DHCP_RANGE_END="${6:-}"
DNS_SERVER="${7:-8.8.8.8}"
DNS_DOMAIN="${8:-hybridops.local}"
DNS_LEASE_TIME="${9:-24h}"

if [[ -z "${ZONE_NAME}" || -z "${VNET_ID}" || -z "${SUBNET_CIDR}" || -z "${GATEWAY}" || -z "${DHCP_RANGE_START}" || -z "${DHCP_RANGE_END}" ]]; then
    echo "Usage: $0 <zone_name> <vnet_id> <subnet_cidr> <gateway> <dhcp_range_start> <dhcp_range_end> [dns_server] [dns_domain] [dns_lease_time]" >&2
    exit 1
fi

NETWORK="${SUBNET_CIDR%/*}"
MASK="${SUBNET_CIDR#*/}"

cidr_to_netmask() {
    local mask="$1"
    local full_octets=$((mask / 8))
    local partial_octet=$((mask % 8))
    local netmask=""
    local i

    for ((i=0; i<4; i++)); do
        if (( i < full_octets )); then
            netmask+="255"
        elif (( i == full_octets && partial_octet > 0 )); then
            netmask+=$((256 - 2**(8-partial_octet)))
        else
            netmask+="0"
        fi
        (( i < 3 )) && netmask+="."
    done

    echo "${netmask}"
}

NETMASK="$(cidr_to_netmask "${MASK}")"
SERVICE_NAME="${VNET_ID}-${ZONE_NAME}-${NETWORK//./-}-${MASK}"

echo "sdn_configure_dhcp: vnet=${VNET_ID} zone=${ZONE_NAME} cidr=${SUBNET_CIDR}"
echo "  service=${SERVICE_NAME}"
echo "  range=${DHCP_RANGE_START}-${DHCP_RANGE_END} gateway=${GATEWAY} dns=${DNS_SERVER}"
echo "  domain=${DNS_DOMAIN} lease=${DNS_LEASE_TIME}"

RETRY=0
MAX_RETRIES=30
while (( RETRY < MAX_RETRIES )); do
    if ip link show "${VNET_ID}" &>/dev/null; then
        break
    fi
    sleep 1
    RETRY=$((RETRY + 1))
done

if (( RETRY == MAX_RETRIES )); then
    echo "Warning: interface ${VNET_ID} not available after ${MAX_RETRIES}s" >&2
fi

if ip link show "${VNET_ID}" &>/dev/null; then
    ip addr flush dev "${VNET_ID}" 2>/dev/null || true
    if ip addr add "${GATEWAY}/${MASK}" dev "${VNET_ID}" 2>/dev/null; then
        echo "Gateway IP assigned on ${VNET_ID}"
    else
        if ip addr show "${VNET_ID}" | grep -q "${GATEWAY}"; then
            echo "Gateway IP already present on ${VNET_ID}"
        else
            echo "Failed to assign gateway IP on ${VNET_ID}" >&2
            exit 1
        fi
    fi
    ip link set "${VNET_ID}" up 2>/dev/null || true
fi

DNSMASQ_CONFIG_DIR="/etc/dnsmasq.d"
CONFIG_FILE="${DNSMASQ_CONFIG_DIR}/${SERVICE_NAME}.conf"
SYSTEMD_SERVICE="/etc/systemd/system/dnsmasq@${SERVICE_NAME}.service"

mkdir -p "${DNSMASQ_CONFIG_DIR}"

cat > "${CONFIG_FILE}" <<EOF
# Proxmox SDN DHCP - ${VNET_ID} (${SUBNET_CIDR})
# Zone: ${ZONE_NAME}
# Generated: $(date -Iseconds)

interface=${VNET_ID}
bind-dynamic

dhcp-range=${DHCP_RANGE_START},${DHCP_RANGE_END},${NETMASK},${DNS_LEASE_TIME}
dhcp-option=3,${GATEWAY}
dhcp-option=6,${DNS_SERVER}
dhcp-option=15,${DNS_DOMAIN}
domain=${DNS_DOMAIN}

port=0
dhcp-authoritative
log-dhcp

dhcp-leasefile=/var/lib/misc/dnsmasq.${SERVICE_NAME}.leases
EOF

cat > "${SYSTEMD_SERVICE}" <<EOF
[Unit]
Description=dnsmasq DHCP server for ${VNET_ID} (${SUBNET_CIDR})
After=network-online.target
Wants=network-online.target
ConditionPathExists=${CONFIG_FILE}

[Service]
Type=forking
PIDFile=/run/dnsmasq/dnsmasq-${SERVICE_NAME}.pid
ExecStartPre=/usr/bin/mkdir -p /run/dnsmasq
ExecStart=/usr/sbin/dnsmasq --conf-file=${CONFIG_FILE} --pid-file=/run/dnsmasq/dnsmasq-${SERVICE_NAME}.pid
ExecReload=/bin/kill -HUP \$MAINPID
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable "dnsmasq@${SERVICE_NAME}.service"
systemctl restart "dnsmasq@${SERVICE_NAME}.service"

sleep 2

if systemctl is-active --quiet "dnsmasq@${SERVICE_NAME}.service"; then
    echo "DHCP service started"
    systemctl status "dnsmasq@${SERVICE_NAME}.service" --no-pager --lines=0 || true
else
    echo "DHCP service failed to start" >&2
    systemctl status "dnsmasq@${SERVICE_NAME}.service" --no-pager || true
    journalctl -u "dnsmasq@${SERVICE_NAME}.service" -n 20 --no-pager || true
    exit 1
fi
