# tests/host_static_routes_validation.tftest.hcl
#
# Covers issue #58: two host_static_routes entries with the same
# destination_cidr and different next hops were accepted, and each setup
# call used ip route replace, so the later one silently won. Verifies that
# a repeated destination is rejected at plan time and that distinct
# destinations still pass.

mock_provider "proxmox" {}
mock_provider "null" {}

variables {
  zone_name                 = "routetst"
  zone_bridge               = "vmbr0"
  proxmox_node              = "pve1"
  proxmox_host              = "192.0.2.10"
  proxmox_url               = "https://192.0.2.10:8006/api2/json"
  proxmox_token             = "terraform@pve!sdn=test-token"
  proxmox_insecure          = true
  enable_host_orchestration = true
  enable_host_l3            = true
  enable_snat               = false
  enable_dhcp               = false

  vnets = {
    vroute01 = {
      vlan_id     = 210
      description = "Static route validation network"
      subnets = {
        sub01 = {
          cidr    = "10.210.0.0/24"
          gateway = "10.210.0.1"
        }
      }
    }
  }
}

run "duplicate_destination_rejected" {
  command = plan

  variables {
    host_static_routes = [
      {
        destination_cidr = "10.80.0.0/16"
        next_hop         = "10.210.0.2"
      },
      {
        destination_cidr = "10.80.0.0/16"
        next_hop         = "10.210.0.3"
      },
    ]
  }

  expect_failures = [
    var.host_static_routes,
  ]
}

run "duplicate_destination_with_whitespace_rejected" {
  command = plan

  variables {
    host_static_routes = [
      {
        destination_cidr = "10.80.0.0/16"
        next_hop         = "10.210.0.2"
      },
      {
        destination_cidr = " 10.80.0.0/16 "
        next_hop         = "10.210.0.3"
      },
    ]
  }

  expect_failures = [
    var.host_static_routes,
  ]
}

run "distinct_destinations_pass" {
  command = plan

  variables {
    host_static_routes = [
      {
        destination_cidr = "10.80.0.0/16"
        next_hop         = "10.210.0.2"
      },
      {
        destination_cidr = "10.90.0.0/16"
        next_hop         = "10.210.0.2"
      },
    ]
  }

  assert {
    condition     = length(null_resource.host_route_setup) == 2
    error_message = "Two distinct destinations must plan two host route setups."
  }
}
