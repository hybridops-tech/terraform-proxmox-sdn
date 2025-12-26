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

  zone_name    = "statzone"
  proxmox_node = var.proxmox_node
  proxmox_host = var.proxmox_host

  # Static IP network, no DHCP
  vnets = {
    vstatic = { # <= 8 chars, valid VNet ID
      vlan_id     = 100
      description = "Static IP Network - No DHCP"

      subnets = {
        static = {
          cidr         = "10.100.0.0/24"
          gateway      = "10.100.0.1"
          dhcp_enabled = false
        }
      }
    }
  }

  proxmox_url      = var.proxmox_url
  proxmox_token    = var.proxmox_token
  proxmox_insecure = var.proxmox_insecure
}
