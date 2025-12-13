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

# # NOTE: Current module version supports single node. 
# # This example shows planned multi-node usage (future enhancement)

# module "sdn_node1" {
#   source = "../.."

#   zone_name    = "cluster-zone"
#   proxmox_node = "pve1"
#   proxmox_host = var.proxmox_host_node1

#   vnets = {
#     vnetcluster = {
#       vlan_id     = 200
#       description = "Cluster Network - Node 1"
#       subnets = {
#         cluster = {
#           cidr             = "10.200.0.0/24"
#           gateway          = "10.200.0.1"
#           dhcp_enabled     = true
#           dhcp_range_start = "10.200.0.100"
#           dhcp_range_end   = "10.200.0.150"
#           dhcp_dns_server  = "8.8.8.8"
#         }
#       }
#     }
#   }

#   proxmox_url      = var.proxmox_url
#   proxmox_token    = var.proxmox_token
#   proxmox_insecure = var.proxmox_insecure
# }

# module "sdn_node2" {
#   source = "../.."
#
#   zone_name    = "cluster-zone"
#   proxmox_node = "pve2"
#   proxmox_host = var.proxmox_host_node2
#
#   vnets = { ... }
# }
