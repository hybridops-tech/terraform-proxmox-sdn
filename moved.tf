moved {
  from = proxmox_virtual_environment_sdn_zone_vlan.zone
  to   = proxmox_sdn_zone_vlan.zone
}

moved {
  from = proxmox_virtual_environment_sdn_vnet.vnet
  to   = proxmox_sdn_vnet.vnet
}

moved {
  from = proxmox_virtual_environment_sdn_subnet.subnet
  to   = proxmox_sdn_subnet.subnet
}

moved {
  from = proxmox_virtual_environment_sdn_applier.apply
  to   = proxmox_sdn_applier.apply
}
