mock_provider "proxmox" {}
mock_provider "null" {}

variables {
  zone_name        = "testzone"
  zone_bridge      = "vmbr0"
  proxmox_host     = "192.0.2.10"
  proxmox_url      = "https://192.0.2.10:8006/api2/json"
  proxmox_token    = "terraform@pve!sdn=test-token"
  proxmox_insecure = true
  enable_snat      = false
  enable_dhcp      = false

  vnets = {
    vtest01 = {
      vlan_id     = 200
      description = "Test network"
      subnets = {
        test = {
          cidr    = "10.200.0.0/24"
          gateway = "10.200.0.1"
        }
      }
    }
  }
}

run "legacy_single_node_input" {
  command = plan

  variables {
    proxmox_node   = "pve1"
    enable_host_l3 = true
  }

  assert {
    condition     = toset(proxmox_sdn_zone_vlan.zone.nodes) == toset(["pve1"])
    error_message = "The legacy proxmox_node input must remain the effective zone membership."
  }
}

run "cluster_node_membership" {
  command = plan

  variables {
    proxmox_node   = "legacy-pve"
    proxmox_nodes  = ["pve1", "pve2", "pve3"]
    enable_host_l3 = false
  }

  assert {
    condition     = toset(proxmox_sdn_zone_vlan.zone.nodes) == toset(["pve1", "pve2", "pve3"])
    error_message = "proxmox_nodes must take precedence and assign every listed node to the SDN zone."
  }
}

run "empty_effective_node_list_rejected" {
  command = plan

  variables {
    proxmox_node   = ""
    proxmox_nodes  = []
    enable_host_l3 = false
  }

  expect_failures = [
    proxmox_sdn_zone_vlan.zone,
  ]
}

run "multi_node_host_l3_rejected" {
  command = plan

  variables {
    proxmox_nodes  = ["pve1", "pve2"]
    enable_host_l3 = true
  }

  expect_failures = [
    proxmox_sdn_zone_vlan.zone,
  ]
}
