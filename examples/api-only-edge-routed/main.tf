# file: examples/api-only-edge-routed/main.tf
# purpose: Fresh edge-routed SDN zone without Proxmox host login
# maintainer: HybridOps

terraform {
  required_version = ">= 1.8.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.100.0, < 1.0.0"
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

  zone_name   = "apionly"
  zone_bridge = "vmbr0"

  proxmox_node = var.proxmox_node

  enable_host_orchestration = false
  enable_host_l3            = false
  enable_snat               = false
  enable_dhcp               = false

  vnets = {
    vapimgmt = {
      vlan_id     = 210
      description = "API-only management network"
      subnets = {
        mgmt = {
          cidr    = "10.210.0.0/24"
          gateway = "10.210.0.1"
        }
      }
    }
  }

  proxmox_url      = var.proxmox_url
  proxmox_token    = var.proxmox_token
  proxmox_insecure = var.proxmox_insecure
}
