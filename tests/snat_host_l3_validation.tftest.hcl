# tests/snat_host_l3_validation.tftest.hcl
#
# Covers issue #44: enable_snat = true with enable_host_l3 = false silently
# had no effective SNAT path and produced no plan-time error. Verifies the
# new zone_vlan lifecycle precondition rejects that combination and that
# both supported paths (host-managed L3 with SNAT, and edge-routed with
# both disabled) continue to pass.

mock_provider "proxmox" {}
mock_provider "null" {}

variables {
  zone_name        = "snattest"
  zone_bridge      = "vmbr0"
  proxmox_node     = "pve1"
  proxmox_host     = "192.0.2.10"
  proxmox_url      = "https://192.0.2.10:8006/api2/json"
  proxmox_token    = "terraform@pve!sdn=test-token"
  proxmox_insecure = true

  vnets = {
    vsnat01 = {
      vlan_id     = 220
      description = "SNAT validation network"
      subnets = {
        sub01 = {
          cidr    = "10.220.0.0/24"
          gateway = "10.220.0.1"
        }
      }
    }
  }
}

run "snat_without_host_l3_rejected" {
  command = plan

  variables {
    enable_host_orchestration = true
    enable_host_l3            = false
    enable_snat               = true
    enable_dhcp               = false
  }

  expect_failures = [
    proxmox_virtual_environment_sdn_zone_vlan.zone,
  ]
}

run "host_managed_l3_with_snat_passes" {
  command = plan

  variables {
    enable_host_orchestration = true
    enable_host_l3            = true
    enable_snat               = true
    enable_dhcp               = false
  }

  assert {
    condition     = local.snat_enabled == true
    error_message = "Host-managed L3 with enable_snat = true must keep SNAT effectively enabled."
  }
}

run "edge_routed_both_disabled_passes" {
  command = plan

  variables {
    proxmox_host              = ""
    enable_host_orchestration = false
    enable_host_l3            = false
    enable_snat               = false
    enable_dhcp               = false
  }

  assert {
    condition     = local.snat_enabled == false
    error_message = "Edge-routed mode with host L3 and SNAT both disabled must plan cleanly with SNAT off."
  }
}
