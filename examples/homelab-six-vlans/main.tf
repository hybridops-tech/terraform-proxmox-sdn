# file: examples/homelab-six-vlans/main.tf
# purpose: Single-node SDN example with six VLAN-backed VNets
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
  # When running from within this repo, point to the root module
  source = "../.."

  # SDN zone ID must be <= 8 chars, lowercase, no dashes
  zone_name   = "hybzone"
  zone_bridge = "vmbr0"

  proxmox_node = var.proxmox_node
  proxmox_host = var.proxmox_host

  # Host-level services
  enable_host_l3   = true
  enable_snat      = true
  uplink_interface = "vmbr0"
  enable_dhcp      = true

  dns_domain = "hybridops.local"
  dns_lease  = "24h"

  vnets = {
    vnetmgmt = {
      vlan_id     = 10
      description = "Management network"
      subnets = {
        mgmt = {
          cidr    = "10.10.0.0/24"
          gateway = "10.10.0.1"

          # DHCP enabled implicitly because ranges are set
          dhcp_range_start = "10.10.0.120"
          dhcp_range_end   = "10.10.0.220"
          dhcp_dns_server  = "8.8.8.8"
        }
      }
    }

    vnetobs = {
      vlan_id     = 11
      description = "Observability network"
      subnets = {
        obs = {
          cidr    = "10.11.0.0/24"
          gateway = "10.11.0.1"

          dhcp_range_start = "10.11.0.120"
          dhcp_range_end   = "10.11.0.220"
          dhcp_dns_server  = "8.8.8.8"
        }
      }
    }

    vnetdev = {
      vlan_id     = 20
      description = "Development network"
      subnets = {
        dev = {
          cidr    = "10.20.0.0/24"
          gateway = "10.20.0.1"

          dhcp_range_start = "10.20.0.120"
          dhcp_range_end   = "10.20.0.220"
          dhcp_dns_server  = "8.8.8.8"
        }
      }
    }

    vnetstag = {
      vlan_id     = 30
      description = "Staging network"
      subnets = {
        stag = {
          cidr    = "10.30.0.0/24"
          gateway = "10.30.0.1"

          dhcp_range_start = "10.30.0.120"
          dhcp_range_end   = "10.30.0.220"
          dhcp_dns_server  = "8.8.8.8"
        }
      }
    }

    vnetprod = {
      vlan_id     = 40
      description = "Production network"
      subnets = {
        prod = {
          cidr    = "10.40.0.0/24"
          gateway = "10.40.0.1"

          dhcp_range_start = "10.40.0.120"
          dhcp_range_end   = "10.40.0.220"
          dhcp_dns_server  = "8.8.8.8"
        }
      }
    }

    vnetlab = {
      vlan_id     = 50
      description = "Lab/testing network"
      subnets = {
        lab = {
          cidr    = "10.50.0.0/24"
          gateway = "10.50.0.1"

          dhcp_range_start = "10.50.0.120"
          dhcp_range_end   = "10.50.0.220"
          dhcp_dns_server  = "8.8.8.8"
        }
      }
    }
  }

  proxmox_url      = var.proxmox_url
  proxmox_token    = var.proxmox_token
  proxmox_insecure = var.proxmox_insecure
}
