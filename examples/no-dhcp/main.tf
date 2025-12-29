# file: examples/no-dhcp/main.tf
# purpose: Single-VNet SDN example with static IPs (no DHCP) on a Proxmox node
# maintainer: HybridOps.Studio

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.50.0"
    }
  }
}

provider "proxmox" {
  endpoint  = var.proxmox_url
  api_token = var.proxmox_token
  insecure  = var.proxmox_insecure
}

module "sdn" {
  source = "../.."

  # SDN zone ID must be <= 8 chars, lowercase, no dashes
  zone_name   = "statzone"
  zone_bridge = "vmbr0"

  proxmox_node = var.proxmox_node
  proxmox_host = var.proxmox_host

  # Host-level routing and NAT, but no DHCP
  enable_host_l3   = true
  enable_snat      = true
  uplink_interface = "vmbr0"
  enable_dhcp      = false

  dns_domain = "hybridops.local"
  dns_lease  = "24h"

  vnets = {
    vstatic = {
      vlan_id     = 100
      description = "Static IP network - no DHCP"
      subnets = {
        static = {
          cidr    = "10.100.0.0/24"
          gateway = "10.100.0.1"

          # No DHCP ranges defined: all addresses are static
        }
      }
    }
  }

  proxmox_url      = var.proxmox_url
  proxmox_token    = var.proxmox_token
  proxmox_insecure = var.proxmox_insecure
}
