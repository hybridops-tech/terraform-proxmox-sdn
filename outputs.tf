# purpose: Output values for Proxmox SDN VLAN zone, VNets, and subnet DHCP configuration
# maintainer: HybridOps.Studio

output "zone_name" {
  description = "SDN zone name."
  value       = proxmox_virtual_environment_sdn_zone_vlan.zone.id
}

output "vnets" {
  description = "Created SDN VNets."
  value = {
    for k, v in proxmox_virtual_environment_sdn_vnet.vnet : k => {
      id      = v.id
      zone    = v.zone
      vlan_id = v.tag
    }
  }
}

locals {
  subnet_config = merge([
    for vnet_key, vnet in var.vnets : {
      for subnet_key, subnet in vnet.subnets :
      "${vnet_key}-${subnet_key}" => subnet
    }
  ]...)
}

output "subnets" {
  description = "Created SDN subnets with DHCP configuration."
  value = {
    for key, subnet in proxmox_virtual_environment_sdn_subnet.subnet : key => {
      id      = subnet.id
      vnet    = subnet.vnet
      cidr    = subnet.cidr
      gateway = subnet.gateway

      dhcp_enabled = (
        var.enable_host_l3 && var.enable_dhcp &&
        (
          try(local.subnet_config[key].dhcp_enabled, null) == true ||
          (
            try(local.subnet_config[key].dhcp_enabled, null) == null &&
            try(local.subnet_config[key].dhcp_range_start, null) != null &&
            try(local.subnet_config[key].dhcp_range_end, null) != null
          )
        )
      )

      dhcp_range_start = try(local.subnet_config[key].dhcp_range_start, null)
      dhcp_range_end   = try(local.subnet_config[key].dhcp_range_end, null)
      dhcp_dns_server  = try(local.subnet_config[key].dhcp_dns_server, null)
    }
  }
}
