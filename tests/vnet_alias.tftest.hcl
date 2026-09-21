mock_provider "proxmox" {}
mock_provider "null" {}

variables {
  zone_name        = "testzone"
  zone_bridge      = "vmbr0"
  proxmox_host     = "192.0.2.10"
  proxmox_url      = "https://192.0.2.10:8006/api2/json"
  proxmox_token    = "terraform@pve!sdn=test-token"
  proxmox_insecure = true
  proxmox_nodes    = ["pve1"]
  enable_host_l3   = false
  enable_snat      = false
  enable_dhcp      = false

  vnets = {
    vmgmt = {
      vlan_id     = 10
      description = "Management network"
      subnets = {
        mgmt = {
          cidr    = "10.10.0.0/24"
          gateway = "10.10.0.1"
        }
      }
    }
    vdev = {
      vlan_id     = 20
      description = "Development network"
      subnets = {
        dev = {
          cidr    = "10.20.0.0/24"
          gateway = "10.20.0.1"
        }
      }
    }
  }
}

run "vnet_description_is_applied_as_alias" {
  command = plan

  assert {
    condition     = proxmox_virtual_environment_sdn_vnet.vnet["vmgmt"].alias == "Management network"
    error_message = "The description of the vmgmt VNet must be applied as the Proxmox VNet alias."
  }

  assert {
    condition     = proxmox_virtual_environment_sdn_vnet.vnet["vdev"].alias == "Development network"
    error_message = "The description of the vdev VNet must be applied as the Proxmox VNet alias."
  }
}
