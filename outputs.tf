# purpose: Output values for Proxmox SDN VLAN zone, VNets, subnets, and NetBox IPAM export payload
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

output "subnets" {
  description = "Created SDN subnets with DHCP configuration (effective values)."
  value = {
    for key, subnet in proxmox_virtual_environment_sdn_subnet.subnet : key => {
      id      = subnet.id
      vnet    = subnet.vnet
      cidr    = subnet.cidr
      gateway = subnet.gateway

      dhcp_enabled     = try(local.subnets_flat[key].dhcp_enabled_effective, false)
      dhcp_range_start = try(local.subnets_flat[key].dhcp_range_start_effective, null)
      dhcp_range_end   = try(local.subnets_flat[key].dhcp_range_end_effective, null)
      dhcp_dns_server  = try(local.subnets_flat[key].dhcp_dns_server_effective, null)
    }
  }
}

locals {
  ipam_role_map = {
    mgmt = "management"
    obs  = "observability"
    dev  = "development"
    stag = "staging"
    prod = "production"
    lab  = "lab"
    data = "data"
  }

  ipam_prefixes = [
    for key in sort(keys(local.subnets_flat)) : {
      site    = var.ipam_site
      status  = var.ipam_status
      vlan_id = var.vnets[local.subnets_flat[key].vnet_id].vlan_id

      role = lookup(
        local.ipam_role_map,
        replace(lower(local.subnets_flat[key].vnet_id), "vnet", ""),
        replace(lower(local.subnets_flat[key].vnet_id), "vnet", "")
      )

      prefix  = local.subnets_flat[key].cidr
      gateway = local.subnets_flat[key].gateway

      dhcp_enabled = local.subnets_flat[key].dhcp_enabled_effective
      dhcp_start   = local.subnets_flat[key].dhcp_range_start_effective
      dhcp_end     = local.subnets_flat[key].dhcp_range_end_effective

      description = (
        local.subnets_flat[key].dhcp_enabled_effective
        ? format(
          "%s network (static .2-.%d; DHCP .%d-.%d)",
          title(lookup(
            local.ipam_role_map,
            replace(lower(local.subnets_flat[key].vnet_id), "vnet", ""),
            replace(lower(local.subnets_flat[key].vnet_id), "vnet", "")
          )),
          var.static_last_host,
          var.dhcp_default_start_host,
          var.dhcp_default_end_host
        )
        : format(
          "%s network",
          title(lookup(
            local.ipam_role_map,
            replace(lower(local.subnets_flat[key].vnet_id), "vnet", ""),
            replace(lower(local.subnets_flat[key].vnet_id), "vnet", "")
          ))
        )
      )
    }
  ]
}

output "ipam_prefixes" {
  description = "NetBox IPAM dataset derived from SDN inputs (prefixes + DHCP metadata)."
  value       = local.ipam_prefixes
}
