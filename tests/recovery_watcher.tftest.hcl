mock_provider "proxmox" {}
mock_provider "null" {}

variables {
  zone_name                 = "watchtst"
  zone_bridge               = "vmbr0"
  proxmox_node              = "pve1"
  proxmox_host              = "192.0.2.10"
  proxmox_url               = "https://192.0.2.10:8006/api2/json"
  proxmox_token             = "terraform@pve!sdn=test-token"
  proxmox_insecure          = true
  enable_host_orchestration = true
  enable_host_l3            = true
  enable_snat               = true
  enable_dhcp               = true

  host_static_routes = [
    {
      destination_cidr = "10.80.0.0/16"
      next_hop         = "10.210.0.2"
    },
  ]

  vnets = {
    vwatch01 = {
      vlan_id     = 210
      description = "Recovery watcher test network"
      subnets = {
        sub01 = {
          cidr    = "10.210.0.0/24"
          gateway = "10.210.0.1"
        }
      }
    }
  }
}

run "watcher_enabled_by_default" {
  command = plan

  assert {
    condition     = null_resource.sdn_auto_healing.triggers.recovery_watcher_enabled == "true"
    error_message = "Host orchestration must install the recovery watcher by default."
  }
}

run "watcher_can_be_disabled_independently" {
  command = plan

  variables {
    enable_host_recovery_watcher = false
  }

  assert {
    condition     = null_resource.sdn_auto_healing.triggers.recovery_watcher_enabled == "false"
    error_message = "The recovery watcher must remain disabled when explicitly turned off."
  }

  assert {
    condition     = length(null_resource.gateway_setup) == 1
    error_message = "Disabling the watcher must not disable host gateway orchestration."
  }

  assert {
    condition     = length(null_resource.host_route_setup) == 1
    error_message = "Disabling the watcher must not disable static route orchestration."
  }

  assert {
    condition     = length(null_resource.nat_setup) == 1
    error_message = "Disabling the watcher must not disable SNAT orchestration."
  }

  assert {
    condition     = length(null_resource.dhcp_setup) == 1
    error_message = "Disabling the watcher must not disable DHCP orchestration."
  }
}
