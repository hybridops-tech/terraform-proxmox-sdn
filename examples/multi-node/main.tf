# file: examples/multi-node/main.tf
# purpose: Shared edge-routed SDN zone across a Proxmox cluster
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

module "sdn_cluster" {
  source = "../.."

  # SDN zone ID must be <= 8 chars, lowercase, no dashes
  zone_name   = "clust01"
  zone_bridge = "vmbr0"

  proxmox_nodes = var.proxmox_nodes
  proxmox_host  = var.proxmox_host

  # Multi-node membership is edge-routed in this release. Gateway, SNAT,
  # DHCP, and static routes remain outside this module invocation.
  enable_host_l3 = false
  enable_snat    = false
  enable_dhcp    = false

  vnets = {
    vclst01m = {
      vlan_id     = 200
      description = "Cluster management network"
      subnets = {
        cluster = {
          cidr    = "10.200.0.0/24"
          gateway = "10.200.0.1"
        }
      }
    }
  }

  proxmox_url      = var.proxmox_url
  proxmox_token    = var.proxmox_token
  proxmox_insecure = var.proxmox_insecure
}
