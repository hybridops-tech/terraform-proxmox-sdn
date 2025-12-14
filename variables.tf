# file: infra/terraform/modules/proxmox/sdn/variables.tf

variable "zone_name" {
  description = "SDN zone name"
  type        = string
}

variable "proxmox_node" {
  description = "Proxmox node name"
  type        = string
}

variable "proxmox_host" {
  description = "Proxmox host IP for SSH"
  type        = string
}

variable "vnets" {
  description = "Map of VNets to create"
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

# Provider configuration
variable "proxmox_url" {
  description = "Proxmox API URL"
  type        = string
}

variable "proxmox_token" {
  description = "Proxmox API token"
  type        = string
  sensitive   = true
}

variable "proxmox_insecure" {
  description = "Skip TLS verification"
  type        = bool
  default     = false
}