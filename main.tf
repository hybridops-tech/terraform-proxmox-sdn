# file: infra/terraform/modules/proxmox/sdn/main.tf
# purpose: Proxmox SDN VLAN zone, vnets, subnets, and DHCP orchestration for Terraform-managed environments
# maintainer: HybridOps.Studio

locals {
  subnets_flat = merge([
    for vnet_key, vnet in var.vnets : {
      for subnet_key, subnet in vnet.subnets :
      "${vnet_key}-${subnet_key}" => merge(subnet, {
        vnet_id = vnet_key
      })
    }
  ]...)
}

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
  for_each = local.subnets_flat

  vnet    = proxmox_virtual_environment_sdn_vnet.vnet[each.value.vnet_id].id
  cidr    = each.value.cidr
  gateway = each.value.gateway

  depends_on = [proxmox_virtual_environment_sdn_vnet.vnet]
}

resource "proxmox_virtual_environment_sdn_applier" "apply" {
  depends_on = [
    proxmox_virtual_environment_sdn_zone_vlan.zone,
    proxmox_virtual_environment_sdn_vnet.vnet,
    proxmox_virtual_environment_sdn_subnet.subnet,
  ]
}

resource "null_resource" "dhcp_setup" {
  for_each = {
    for key, subnet in local.subnets_flat : key => subnet
    if try(subnet.dhcp_enabled, false)
  }

  triggers = {
    zone_name           = var.zone_name
    vnet_id             = each.value.vnet_id
    subnet_cidr         = each.value.cidr
    gateway             = each.value.gateway
    dhcp_range_start    = each.value.dhcp_range_start
    dhcp_range_end      = each.value.dhcp_range_end
    dns_server          = try(each.value.dhcp_dns_server, "8.8.8.8")
    dns_domain          = var.dns_domain
    dns_lease           = var.dns_lease
    proxmox_host        = var.proxmox_host
    setup_script_hash   = filemd5("${path.module}/scripts/setup-dhcp.sh")
    cleanup_script_hash = filemd5("${path.module}/scripts/cleanup-dhcp.sh")
  }

  provisioner "local-exec" {
    command = <<-EOT
      scp ${path.module}/scripts/setup-dhcp.sh root@${var.proxmox_host}:/tmp/setup-dhcp-${each.value.vnet_id}.sh
      ssh root@${var.proxmox_host} 'chmod +x /tmp/setup-dhcp-${each.value.vnet_id}.sh && /tmp/setup-dhcp-${each.value.vnet_id}.sh \
        "${var.zone_name}" \
        "${each.value.vnet_id}" \
        "${each.value.cidr}" \
        "${each.value.gateway}" \
        "${each.value.dhcp_range_start}" \
        "${each.value.dhcp_range_end}" \
        "${try(each.value.dhcp_dns_server, "8.8.8.8")}" \
        "${var.dns_domain}" \
        "${var.dns_lease}"'
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      scp ${path.module}/scripts/cleanup-dhcp.sh root@${self.triggers.proxmox_host}:/tmp/cleanup-dhcp.sh
      ssh root@${self.triggers.proxmox_host} 'chmod +x /tmp/cleanup-dhcp.sh && /tmp/cleanup-dhcp.sh \
        single \
        "${self.triggers.zone_name}" \
        "${self.triggers.vnet_id}" \
        "${self.triggers.subnet_cidr}"'
    EOT
  }

  depends_on = [proxmox_virtual_environment_sdn_applier.apply]
}

resource "null_resource" "sdn_cleanup" {
  triggers = {
    zone_name    = var.zone_name
    proxmox_host = var.proxmox_host
    vnets_hash   = md5(jsonencode(var.vnets))
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      scp ${path.module}/scripts/cleanup-dhcp.sh root@${self.triggers.proxmox_host}:/tmp/cleanup-dhcp.sh
      ssh root@${self.triggers.proxmox_host} 'chmod +x /tmp/cleanup-dhcp.sh && /tmp/cleanup-dhcp.sh \
        zone \
        "${self.triggers.zone_name}"'
    EOT
  }

  depends_on = [
    null_resource.dhcp_setup,
    proxmox_virtual_environment_sdn_applier.apply,
  ]
}
