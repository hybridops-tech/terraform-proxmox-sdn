# file: infra/terraform/modules/proxmox/sdn/outputs.tf

output "zone_name" {
  description = "SDN zone name"
  value       = proxmox_virtual_environment_sdn_zone_vlan.zone.id
}

output "vnets" {
  description = "Created VNets"
  value = {
    for k, v in proxmox_virtual_environment_sdn_vnet.vnet : k => {
      id      = v.id
      zone    = v.zone
      vlan_id = v.tag
    }
  }
}

output "subnets" {
  description = "Created subnets with DHCP info"
  value = {
    for k, v in proxmox_virtual_environment_sdn_subnet.subnet : k => {
      vnet    = v.vnet
      cidr    = v.cidr
      gateway = v.gateway
    }
  }
}
