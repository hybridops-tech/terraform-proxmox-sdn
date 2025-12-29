# purpose: Input variables for Proxmox SDN VLAN zone, VNets, and host-level orchestration (NAT, DHCP, gateway)
# maintainer: HybridOps.Studio

variable "zone_name" {
  description = "SDN zone name."
  type        = string
}

variable "zone_bridge" {
  description = "Proxmox bridge used for SDN zone attachment (typically vmbr0)."
  type        = string
  default     = "vmbr0"
}

variable "proxmox_node" {
  description = "Proxmox node name for SDN zone attachment."
  type        = string
}

variable "proxmox_host" {
  description = "Proxmox host (hostname or IP) used for SSH-based host-side configuration."
  type        = string
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

variable "vnets" {
  description = <<-EOT
    SDN VNets map keyed by VNet ID.

    Each VNet:
      - vlan_id: VLAN tag (e.g. 10, 20, 30)
      - description: logical description
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
