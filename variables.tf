# purpose: Input variables for Proxmox SDN VLAN zone, VNets, and host-level orchestration (NAT, DHCP, gateway)
# maintainer: HybridOps

variable "zone_name" {
  description = "SDN zone name."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z][A-Za-z0-9]{1,7}$", var.zone_name))
    error_message = "zone_name must start with a letter, contain only letters and digits, and be 2-8 characters long (Proxmox SDN zone ID constraint)."
  }
}

variable "zone_bridge" {
  description = "Proxmox bridge used for SDN zone attachment (typically vmbr0)."
  type        = string
  default     = "vmbr0"
}

variable "proxmox_node" {
  description = "Legacy single Proxmox node name for SDN zone attachment. Used when proxmox_nodes is empty."
  type        = string
  default     = ""
}

variable "proxmox_nodes" {
  description = "Optional Proxmox node names for cluster-wide SDN zone membership. Takes precedence over proxmox_node when set."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for node in var.proxmox_nodes : trimspace(node) != ""])
    error_message = "proxmox_nodes must not contain empty node names."
  }

  validation {
    condition = length(var.proxmox_nodes) == length(distinct([
      for node in var.proxmox_nodes : trimspace(node)
    ]))
    error_message = "proxmox_nodes must not contain duplicate node names."
  }
}

variable "proxmox_host" {
  description = "Proxmox host (hostname or IP) used for host-managed gateway, NAT, DHCP, recovery, and cleanup."
  type        = string
  default     = ""
}

variable "enable_host_orchestration" {
  description = "Enable host login for gateway, NAT, DHCP, recovery, and cleanup. Disable only for fresh edge-routed deployments."
  type        = bool
  default     = true
}

variable "enable_host_l3" {
  description = "Enable host-level L3 gateway configuration on VNet interfaces."
  type        = bool
  default     = true
}

variable "enable_snat" {
  description = "Enable SNAT/masquerade for SDN subnets via the uplink interface."
  type        = bool
  default     = true
}

variable "uplink_interface" {
  description = "Uplink interface used for SNAT (typically vmbr0)."
  type        = string
  default     = "vmbr0"
}

variable "enable_dhcp" {
  description = "Enable host-level dnsmasq DHCP provisioning (requires enable_host_l3 = true)."
  type        = bool
  default     = false

  validation {
    condition     = !(var.enable_dhcp && !var.enable_host_l3)
    error_message = "enable_dhcp = true requires enable_host_l3 = true so DHCP can bind to VNet interfaces."
  }
}

variable "dns_domain" {
  description = "DNS domain suffix for DHCP clients."
  type        = string
  default     = "hybridops.local"
}

variable "dns_lease" {
  description = "DHCP lease duration."
  type        = string
  default     = "24h"

  validation {
    condition     = can(regex("^[0-9]+[smhd]$", var.dns_lease))
    error_message = "Lease time must be a number followed by s, m, h, or d (e.g., 24h, 7d)."
  }
}

variable "host_reconcile_nonce" {
  description = "Optional operator-supplied token to force host-side SDN reconciliation (gateway/NAT/DHCP) even when topology inputs are unchanged."
  type        = string
  default     = ""
}

variable "host_static_routes" {
  description = <<-EOT
    Optional static routes installed on the Proxmox host when it is acting as the
    subnet gateway (`enable_host_l3 = true`).

    This is the supported path for host-routed Proxmox SDN environments that need
    selected cloud or upstream prefixes to exit through a separate on-prem edge.
  EOT

  type = list(object({
    destination_cidr = string
    next_hop         = string
  }))
  default = []

  validation {
    condition     = !(length(var.host_static_routes) > 0 && !var.enable_host_l3)
    error_message = "host_static_routes requires enable_host_l3 = true because the Proxmox host must own the gateway role."
  }
}

variable "vnets" {
  description = <<-EOT
    SDN VNets map keyed by VNet ID.

    VNet keys: 2-8 chars, must start with a letter, followed by letters/digits only (e.g. vnet1, vnetA, vnetmgmt)

    Each VNet:
      - vlan_id: VLAN tag (e.g. 10, 20, 30)
      - description: logical description, applied as the Proxmox VNet alias (letters, digits, spaces and - _ . ( ) only, up to 256 characters)
      - subnets: map keyed by subnet ID (e.g. submgmt, subdev)

    Each subnet:
      - cidr: CIDR prefix (e.g. 10.10.0.0/24)
      - gateway: gateway IP (e.g. 10.10.0.1)

    Optional DHCP hints:
      - dhcp_enabled: boolean; if omitted, treated as false
      - dhcp_range_start / dhcp_range_end: range for DHCP pool
      - dhcp_dns_server: override DNS server for this subnet

    The module will only create DHCP services when:
      - enable_host_l3 = true
      - enable_dhcp = true
      - and the subnet is selected by dhcp_setup in main.tf.
  EOT

  type = map(object({
    vlan_id     = number
    description = string
    subnets = map(object({
      cidr    = string
      gateway = string

      dhcp_enabled     = optional(bool)
      dhcp_range_start = optional(string)
      dhcp_range_end   = optional(string)
      dhcp_dns_server  = optional(string)
    }))
  }))

  validation {
    condition     = alltrue([for k in keys(var.vnets) : can(regex("^[A-Za-z][A-Za-z0-9]{1,7}$", k))])
    error_message = "Each VNet ID must start with a letter, contain only letters and digits, and be 2-8 characters long (Proxmox SDN VNet ID constraint)."
  }
  validation {
    condition = alltrue([
      for vnet in values(var.vnets) :
      vnet.vlan_id >= 1 &&
      vnet.vlan_id <= 4094 &&
      vnet.vlan_id == floor(vnet.vlan_id)
    ])
    error_message = "Each VLAN ID must be a whole number between 1 and 4094."
  }
  validation {
    condition = alltrue([
      for vnet in values(var.vnets) :
      can(regex("^[()._a-zA-Z0-9\\s-]+$", vnet.description)) &&
      length(vnet.description) <= 256
    ])
    error_message = "Each VNet description is applied as the Proxmox VNet alias, so it must be 1-256 characters and contain only letters, digits, spaces, and - _ . ( )."
  }

}

variable "proxmox_url" {
  description = "Proxmox API URL."
  type        = string
}

variable "proxmox_token" {
  description = "Proxmox API token."
  type        = string
  sensitive   = true
}

variable "proxmox_insecure" {
  description = "Whether to skip TLS verification when connecting to the Proxmox API."
  type        = bool
  default     = false
}

variable "ipam_site" {
  description = "NetBox site slug/name to stamp onto IPAM exports."
  type        = string
  default     = "onprem-hybridhub"
}

variable "ipam_status" {
  description = "NetBox status to stamp onto IPAM exports."
  type        = string
  default     = "active"
}

variable "static_last_host" {
  description = "Last host index in the 'static' region for description text."
  type        = number
  default     = 119
}

variable "dhcp_default_dns_server" {
  description = "Default DNS server for DHCP when not set per subnet."
  type        = string
  default     = "8.8.8.8"
}

variable "dhcp_default_start_host" {
  description = "Default DHCP start host index when DHCP is enabled and start is not set."
  type        = number
  default     = 120

  validation {
    condition     = var.dhcp_default_start_host >= 2
    error_message = "dhcp_default_start_host must be >= 2."
  }
}

variable "dhcp_default_end_host" {
  description = "Default DHCP end host index when DHCP is enabled and end is not set."
  type        = number
  default     = 220

  validation {
    condition     = var.dhcp_default_end_host > var.dhcp_default_start_host
    error_message = "dhcp_default_end_host must be greater than dhcp_default_start_host."
  }
}
