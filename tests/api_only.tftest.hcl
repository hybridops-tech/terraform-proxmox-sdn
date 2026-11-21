mock_provider "proxmox" {}
mock_provider "null" {}

variables {
  zone_name        = "apionly"
  zone_bridge      = "vmbr0"
  proxmox_node     = "pve1"
  proxmox_url      = "https://192.0.2.10:8006/api2/json"
  proxmox_token    = "terraform@pve!sdn=test-token"
  proxmox_insecure = true

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
}

run "fresh_edge_routed_without_host_login" {
  command = plan

  variables {
    proxmox_host              = ""
    enable_host_orchestration = false
    enable_host_l3            = false
    enable_snat               = false
    enable_dhcp               = false
  }

  assert {
    condition     = null_resource.sdn_reload.triggers.host_orchestration_enabled == "false"
    error_message = "Fresh edge-routed mode must put the host reload step into no-host-login mode."
  }

  assert {
    condition     = null_resource.sdn_auto_healing.triggers.host_orchestration_enabled == "false"
    error_message = "Fresh edge-routed mode must put host recovery into no-host-login mode."
  }

  assert {
    condition     = null_resource.sdn_auto_healing.triggers.recovery_watcher_enabled == "false"
    error_message = "Fresh edge-routed mode must not install the host recovery watcher."
  }

  assert {
    condition     = null_resource.sdn_apply_finalizer.triggers.host_orchestration_enabled == "false"
    error_message = "Fresh edge-routed mode must put final cleanup into no-host-login mode."
  }

  assert {
    condition     = length(null_resource.gateway_setup) == 0
    error_message = "Fresh edge-routed mode must not configure host gateways."
  }
}

run "host_managed_default_still_requires_host" {
  command = plan

  variables {
    proxmox_host              = ""
    enable_host_orchestration = true
    enable_host_l3            = true
    enable_snat               = true
    enable_dhcp               = false
  }

  expect_failures = [
    proxmox_sdn_zone_vlan.zone,
  ]
}

run "host_features_rejected_when_host_login_disabled" {
  command = plan

  variables {
    proxmox_host              = ""
    enable_host_orchestration = false
    enable_host_l3            = true
    enable_snat               = true
    enable_dhcp               = false
  }

  expect_failures = [
    proxmox_sdn_zone_vlan.zone,
  ]
}
