# file: infra/terraform/modules/proxmox/sdn/main.tf

resource "proxmox_virtual_environment_sdn_zone_vlan" "zone" {
  id     = var.zone_name
  bridge = "vmbr0"
  nodes  = [var.proxmox_node]
  mtu    = 1500
}

resource "proxmox_virtual_environment_sdn_vnet" "vnet" {
  for_each = var.vnets

  id   = each.key
  zone = proxmox_virtual_environment_sdn_zone_vlan.zone.id
  tag  = each.value.vlan_id

  depends_on = [proxmox_virtual_environment_sdn_zone_vlan.zone]
}

resource "proxmox_virtual_environment_sdn_subnet" "subnet" {
  for_each = merge([
    for vnet_key, vnet in var.vnets : {
      for subnet_key, subnet in vnet.subnets :
      "${vnet_key}-${subnet_key}" => merge(subnet, {
        vnet_id = vnet_key
      })
    }
  ]...)

  vnet    = proxmox_virtual_environment_sdn_vnet.vnet[each.value.vnet_id].id
  cidr    = each.value.cidr
  gateway = each.value.gateway

  depends_on = [proxmox_virtual_environment_sdn_vnet.vnet]
}

resource "proxmox_virtual_environment_sdn_applier" "apply" {
  depends_on = [
    proxmox_virtual_environment_sdn_zone_vlan.zone,
    proxmox_virtual_environment_sdn_vnet.vnet,
    proxmox_virtual_environment_sdn_subnet.subnet
  ]
}

locals {
  dhcp_enabled = length(flatten([
    for vnet_key, vnet in var.vnets : [
      for subnet_key, subnet in vnet.subnets :
      true
      if try(subnet.dhcp_enabled, false)
    ]
  ])) > 0
}

resource "null_resource" "dhcp_setup" {
  count = local.dhcp_enabled ? 1 : 0

  triggers = {
    vnets_hash   = md5(jsonencode(var.vnets))
    proxmox_host = var.proxmox_host
  }

  provisioner "local-exec" {
    command = "bash ${path.module}/scripts/setup-dhcp.sh"
    environment = {
      PROXMOX_HOST = var.proxmox_host
      VNETS_JSON   = jsonencode(var.vnets)
    }
  }

  provisioner "local-exec" {
    when    = destroy
    command = "bash ${path.module}/scripts/cleanup-dhcp.sh"
    environment = {
      PROXMOX_HOST = self.triggers.proxmox_host
    }
  }

  depends_on = [proxmox_virtual_environment_sdn_applier.apply]
}