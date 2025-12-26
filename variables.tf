# purpose: Input variables for Proxmox SDN VLAN zone, VNets, and DHCP orchestration
# maintainer: HybridOps.Studio

variable "zone_name" {
  description = "SDN zone name."
  type        = string
}

variable "proxmox_node" {
  description = "Proxmox node name for SDN zone attachment."
  type        = string
}

variable "proxmox_host" {
  description = "Proxmox host (hostname or IP) used for SSH-based DHCP configuration."
  type        = string
}

variable "vnets" {
  description = "SDN VNets map keyed by VNet ID."
  type = map(object({
    vlan_id     = number
    description = string
    subnets = map(object({
      cidr             = string
      gateway          = string
      dhcp_enabled     = bool
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

variable "dns_domain" {
  description = "DNS domain suffix for DHCP clients"
  type        = string
  default     = "hybridops.local"
}

variable "dns_lease" {
  description = "DHCP lease duration"
  type        = string
  default     = "24h"

  validation {
    condition     = can(regex("^[0-9]+[smhd]$", var.dns_lease))
    error_message = "Lease time must be a number followed by s (seconds), m (minutes), h (hours), or d (days), e.g., '24h' or '7d'."
  }
}
