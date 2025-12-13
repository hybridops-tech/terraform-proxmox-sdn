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

  zone_name    = "hybzone"
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

    vnetobs = {
      vlan_id     = 11
      description = "Observability Network"
      subnets = {
        obs = {
          cidr             = "10.11.0.0/24"
          gateway          = "10.11.0.1"
          dhcp_enabled     = true
          dhcp_range_start = "10.11.0.100"
          dhcp_range_end   = "10.11.0.200"
          dhcp_dns_server  = "8.8.8.8"
        }
      }
    }

    vnetdev = {
      vlan_id     = 20
      description = "Development Network"
      subnets = {
        dev = {
          cidr             = "10.20.0.0/24"
          gateway          = "10.20.0.1"
          dhcp_enabled     = true
          dhcp_range_start = "10.20.0.100"
          dhcp_range_end   = "10.20.0.200"
          dhcp_dns_server  = "8.8.8.8"
        }
      }
    }

    vnetstag = {
      vlan_id     = 30
      description = "Staging Network"
      subnets = {
        stag = {
          cidr             = "10.30.0.0/24"
          gateway          = "10.30.0.1"
          dhcp_enabled     = true
          dhcp_range_start = "10.30.0.100"
          dhcp_range_end   = "10.30.0.200"
          dhcp_dns_server  = "8.8.8.8"
        }
      }
    }

    vnetprod = {
      vlan_id     = 40
      description = "Production Network"
      subnets = {
        prod = {
          cidr             = "10.40.0.0/24"
          gateway          = "10.40.0.1"
          dhcp_enabled     = true
          dhcp_range_start = "10.40.0.100"
          dhcp_range_end   = "10.40.0.200"
          dhcp_dns_server  = "8.8.8.8"
        }
      }
    }

    vnetlab = {
      vlan_id     = 50
      description = "Lab/Testing Network"
      subnets = {
        lab = {
          cidr             = "10.50.0.0/24"
          gateway          = "10.50.0.1"
          dhcp_enabled     = true
          dhcp_range_start = "10.50.0.100"
          dhcp_range_end   = "10.50.0.200"
          dhcp_dns_server  = "8.8.8.8"
        }
      }
    }
  }

  proxmox_url      = var.proxmox_url
  proxmox_token    = var.proxmox_token
  proxmox_insecure = var.proxmox_insecure
}

output "all_vnets" {
  description = "All created VNets"
  value       = module.sdn.vnets
}

output "all_subnets" {
  description = "All created subnets"
  value       = module.sdn.subnets
}
