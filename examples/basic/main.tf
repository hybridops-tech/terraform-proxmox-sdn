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

  zone_name    = "basic-zone"
  proxmox_node = var.proxmox_node
  proxmox_host = var.proxmox_host

  vnets = {
    vnetmgmt = {
      vlan_id     = 10
      description = "Management Network"

      subnets = {
        mgmt = {
          cidr             = "10.10.0.0/24"
          gateway          = "10.10.0.1"
          dhcp_enabled     = true
          dhcp_range_start = "10.10.0.100"
          dhcp_range_end   = "10.10.0.200"
          dhcp_dns_server  = "8.8.8.8"
        }
      }
    }
  }

  proxmox_url      = var.proxmox_url
  proxmox_token    = var.proxmox_token
  proxmox_insecure = var.proxmox_insecure
}

output "zone_name" {
  value = module.sdn.zone_name
}

output "vnets" {
  value = module.sdn.vnets
}
