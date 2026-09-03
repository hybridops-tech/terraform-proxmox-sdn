mock_provider "proxmox" {}
mock_provider "null" {}

variables {
  zone_name        = "ipamtest"
  zone_bridge      = "vmbr0"
  proxmox_node     = "pve1"
  proxmox_host     = "198.51.100.10"
  proxmox_url      = "https://192.0.2.10:8006/api2/json"
  proxmox_token    = "terraform@pve!sdn=test-token"
  proxmox_insecure = true

  enable_host_l3 = true
  enable_snat    = false
  enable_dhcp    = true

  vnets = {
    vnetprod = {
      vlan_id     = 210
      description = "Production network"
      subnets = {
        web = {
          cidr         = "10.210.0.0/24"
          gateway      = "10.210.0.1"
          dhcp_enabled = false
        }
      }
    }
    vnetmgmt = {
      vlan_id     = 220
      description = "Management network"
      subnets = {
        admin = {
          cidr    = "10.220.0.0/24"
          gateway = "10.220.0.1"
        }
      }
    }
  }
}

run "ipam_prefixes_preserve_metadata_and_effective_dhcp" {
  command = plan

  variables {
    ipam_site               = "nyc-edge"
    ipam_status             = "planned"
    static_last_host        = 119
    dhcp_default_start_host = 120
    dhcp_default_end_host   = 220
  }

  assert {
    condition     = length(output.ipam_prefixes) == 2
    error_message = "The IPAM export must contain one entry per subnet."
  }

  # The output is sorted by the flattened subnet key, not by map declaration order.
  assert {
    condition = output.ipam_prefixes[0] == {
      site         = "nyc-edge"
      status       = "planned"
      vlan_id      = 220
      role         = "management"
      prefix       = "10.220.0.0/24"
      gateway      = "10.220.0.1"
      dhcp_enabled = true
      dhcp_start   = "10.220.0.120"
      dhcp_end     = "10.220.0.220"
      description  = "Management network (static .2-.119; DHCP .120-.220)"
    }
    error_message = "The default-DHCP IPAM entry must preserve metadata and effective range values."
  }

  assert {
    condition     = output.ipam_prefixes[1].site == "nyc-edge" && output.ipam_prefixes[1].status == "planned" && output.ipam_prefixes[1].vlan_id == 210 && output.ipam_prefixes[1].role == "production" && output.ipam_prefixes[1].prefix == "10.210.0.0/24" && output.ipam_prefixes[1].gateway == "10.210.0.1" && output.ipam_prefixes[1].dhcp_enabled == false && output.ipam_prefixes[1].dhcp_start == null && output.ipam_prefixes[1].dhcp_end == null && output.ipam_prefixes[1].description == "Production network"
    error_message = "A DHCP-disabled subnet must keep null effective range values in the IPAM export."
  }
}
