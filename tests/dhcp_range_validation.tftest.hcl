mock_provider "proxmox" {}
mock_provider "null" {}

variables {
  zone_name        = "dhcptest"
  zone_bridge      = "vmbr0"
  proxmox_node     = "pve1"
  proxmox_host     = "192.0.2.10"
  proxmox_url      = "https://192.0.2.10:8006/api2/json"
  proxmox_token    = "terraform@pve!sdn=test-token"
  proxmox_insecure = true
  enable_host_l3   = true
  enable_snat      = false
  enable_dhcp      = true
}

run "valid_range_passes" {
  command = plan

  variables {
    vnets = {
      vdhcp01 = {
        vlan_id     = 210
        description = "Valid DHCP range"
        subnets = {
          sub01 = {
            cidr             = "10.210.0.0/24"
            gateway          = "10.210.0.1"
            dhcp_range_start = "10.210.0.120"
            dhcp_range_end   = "10.210.0.220"
          }
        }
      }
    }
  }

  assert {
    condition     = null_resource.dhcp_setup["vdhcp01-sub01"].triggers.dhcp_range_start == "10.210.0.120"
    error_message = "A valid DHCP range must remain available to host orchestration."
  }
}

run "start_outside_subnet_rejected" {
  command = plan

  variables {
    vnets = {
      vdhcp01 = {
        vlan_id     = 210
        description = "Invalid DHCP start"
        subnets = {
          sub01 = {
            cidr             = "10.210.0.0/24"
            gateway          = "10.210.0.1"
            dhcp_range_start = "10.211.0.120"
            dhcp_range_end   = "10.210.0.220"
          }
        }
      }
    }
  }

  expect_failures = [
    proxmox_sdn_zone_vlan.zone,
  ]
}

run "end_outside_subnet_rejected" {
  command = plan

  variables {
    vnets = {
      vdhcp01 = {
        vlan_id     = 210
        description = "Invalid DHCP end"
        subnets = {
          sub01 = {
            cidr             = "10.210.0.0/24"
            gateway          = "10.210.0.1"
            dhcp_range_start = "10.210.0.120"
            dhcp_range_end   = "10.211.0.220"
          }
        }
      }
    }
  }

  expect_failures = [
    proxmox_sdn_zone_vlan.zone,
  ]
}

run "reversed_range_rejected" {
  command = plan

  variables {
    vnets = {
      vdhcp01 = {
        vlan_id     = 210
        description = "Reversed DHCP range"
        subnets = {
          sub01 = {
            cidr             = "10.210.0.0/24"
            gateway          = "10.210.0.1"
            dhcp_range_start = "10.210.0.220"
            dhcp_range_end   = "10.210.0.120"
          }
        }
      }
    }
  }

  expect_failures = [
    proxmox_sdn_zone_vlan.zone,
  ]
}

run "gateway_in_range_rejected" {
  command = plan

  variables {
    vnets = {
      vdhcp01 = {
        vlan_id     = 210
        description = "Gateway inside DHCP range"
        subnets = {
          sub01 = {
            cidr             = "10.210.0.0/24"
            gateway          = "10.210.0.120"
            dhcp_range_start = "10.210.0.100"
            dhcp_range_end   = "10.210.0.220"
          }
        }
      }
    }
  }

  expect_failures = [
    proxmox_sdn_zone_vlan.zone,
  ]
}

run "dormant_range_remains_allowed" {
  command = plan

  variables {
    enable_dhcp = false
    vnets = {
      vdhcp01 = {
        vlan_id     = 210
        description = "Dormant DHCP range"
        subnets = {
          sub01 = {
            cidr             = "10.210.0.0/24"
            gateway          = "10.210.0.1"
            dhcp_range_start = "10.211.0.120"
            dhcp_range_end   = "10.211.0.220"
          }
        }
      }
    }
  }

  assert {
    condition     = length(null_resource.dhcp_setup) == 0
    error_message = "DHCP range hints must remain dormant when DHCP is disabled."
  }
}
