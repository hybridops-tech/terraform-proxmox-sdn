# purpose: Proxmox SDN VLAN zone, vnets, subnets, and optional host-level orchestration (NAT, DHCP, gateway)
# maintainer: HybridOps.Studio

locals {
  subnets_flat = merge([
    for vnet_key, vnet in var.vnets : {
      for subnet_key, subnet in vnet.subnets :
      "${vnet_key}-${subnet_key}" => merge(subnet, {
        vnet_id = vnet_key

        dhcp_enabled_effective = (
          var.enable_host_l3 && var.enable_dhcp &&
          try(subnet.dhcp_enabled, true) != false
        )

        dhcp_range_start_effective = (
          (var.enable_host_l3 && var.enable_dhcp && try(subnet.dhcp_enabled, true) != false)
          ? coalesce(try(subnet.dhcp_range_start, null), cidrhost(subnet.cidr, var.dhcp_default_start_host))
          : null
        )

        dhcp_range_end_effective = (
          (var.enable_host_l3 && var.enable_dhcp && try(subnet.dhcp_enabled, true) != false)
          ? coalesce(try(subnet.dhcp_range_end, null), cidrhost(subnet.cidr, var.dhcp_default_end_host))
          : null
        )

        dhcp_dns_server_effective = (
          (var.enable_host_l3 && var.enable_dhcp && try(subnet.dhcp_enabled, true) != false)
          ? coalesce(try(subnet.dhcp_dns_server, null), var.dhcp_default_dns_server)
          : null
        )
      })
    }
  ]...)

  vnet_list = join(" ", keys(var.vnets))

  sdn_reload_hash = sha1(jsonencode({
    zone_name        = var.zone_name
    zone_bridge      = var.zone_bridge
    proxmox_node     = var.proxmox_node
    enable_host_l3   = var.enable_host_l3
    enable_snat      = var.enable_snat
    uplink_interface = var.uplink_interface
    enable_dhcp      = var.enable_dhcp
    dns_domain       = var.dns_domain
    dns_lease        = var.dns_lease
    # Explicit operator-controlled nonce to force host-side reconciliation
    # (gateway/NAT/DHCP) even when topology inputs are otherwise unchanged.
    host_reconcile_nonce = var.host_reconcile_nonce
    vnets                = var.vnets
  }))

  dhcp_subnets = (var.enable_host_l3 && var.enable_dhcp) ? {
    for key, s in local.subnets_flat : key => s
    if s.dhcp_enabled_effective
  } : {}
}

resource "proxmox_virtual_environment_sdn_zone_vlan" "zone" {
  id     = var.zone_name
  bridge = var.zone_bridge
  nodes  = [var.proxmox_node]
  mtu    = 1500

  depends_on = [null_resource.sdn_apply_finalizer]
}

resource "proxmox_virtual_environment_sdn_vnet" "vnet" {
  for_each = var.vnets

  id   = each.key
  zone = proxmox_virtual_environment_sdn_zone_vlan.zone.id
  tag  = each.value.vlan_id

  depends_on = [
    null_resource.sdn_apply_finalizer,
    proxmox_virtual_environment_sdn_zone_vlan.zone,
  ]
}

resource "proxmox_virtual_environment_sdn_subnet" "subnet" {
  for_each = local.subnets_flat

  vnet    = proxmox_virtual_environment_sdn_vnet.vnet[each.value.vnet_id].id
  cidr    = each.value.cidr
  gateway = each.value.gateway

  depends_on = [
    null_resource.sdn_apply_finalizer,
    proxmox_virtual_environment_sdn_vnet.vnet,
  ]
}

resource "proxmox_virtual_environment_sdn_applier" "apply" {
  depends_on = [
    null_resource.sdn_apply_finalizer,
    proxmox_virtual_environment_sdn_zone_vlan.zone,
    proxmox_virtual_environment_sdn_vnet.vnet,
    proxmox_virtual_environment_sdn_subnet.subnet,
  ]
}

resource "null_resource" "gateway_setup" {
  for_each = var.enable_host_l3 ? local.subnets_flat : {}

  triggers = {
    zone_name    = var.zone_name
    vnet_id      = each.value.vnet_id
    subnet_cidr  = each.value.cidr
    gateway      = each.value.gateway
    proxmox_host = var.proxmox_host
    # Force gateway re-apply for all subnets when SDN reload inputs change.
    # Without this, gateway_cleanup can remove existing gateways during a zone/VNet change,
    # but unchanged gateway_setup resources will not re-run.
    sdn_reload_hash     = local.sdn_reload_hash
    setup_script_hash   = filemd5("${path.module}/scripts/setup/setup-gateway.sh")
    cleanup_script_hash = filemd5("${path.module}/scripts/cleanup/cleanup-gateway.sh")
  }

  provisioner "local-exec" {
    command = <<-EOT
      scp ${path.module}/scripts/setup/setup-gateway.sh root@${var.proxmox_host}:/tmp/setup-gateway-${each.key}.sh
      ssh root@${var.proxmox_host} 'chmod +x /tmp/setup-gateway-${each.key}.sh && /tmp/setup-gateway-${each.key}.sh \
        "${var.zone_name}" \
        "${each.value.vnet_id}" \
        "${each.value.cidr}" \
        "${each.value.gateway}"'
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      scp ${path.module}/scripts/cleanup/cleanup-gateway.sh root@${self.triggers.proxmox_host}:/tmp/cleanup-gateway.sh
      ssh root@${self.triggers.proxmox_host} 'chmod +x /tmp/cleanup-gateway.sh && /tmp/cleanup-gateway.sh \
        single \
        "${self.triggers.zone_name}" \
        "${self.triggers.vnet_id}" \
        "${self.triggers.subnet_cidr}" \
        "${self.triggers.gateway}"'
    EOT
  }

  depends_on = [
    null_resource.sdn_reload,
  ]
}

resource "null_resource" "gateway_cleanup" {
  triggers = {
    count        = var.enable_host_l3 ? 1 : 0
    zone_name    = var.zone_name
    proxmox_host = var.proxmox_host
    vnets_hash   = md5(jsonencode(var.vnets))
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      scp ${path.module}/scripts/cleanup/cleanup-gateway.sh root@${self.triggers.proxmox_host}:/tmp/cleanup-gateway.sh
      ssh root@${self.triggers.proxmox_host} 'chmod +x /tmp/cleanup-gateway.sh && /tmp/cleanup-gateway.sh \
        zone \
        "${self.triggers.zone_name}"'
    EOT
  }

  depends_on = [
    null_resource.gateway_setup,
    proxmox_virtual_environment_sdn_applier.apply,
  ]
}

resource "null_resource" "nat_setup" {
  for_each = (var.enable_host_l3 && var.enable_snat) ? {
    for k, s in local.subnets_flat : k => s
  } : {}

  triggers = {
    zone_name        = var.zone_name
    vnet_id          = each.value.vnet_id
    subnet_cidr      = each.value.cidr
    proxmox_host     = var.proxmox_host
    uplink_interface = var.uplink_interface
    # Re-run SNAT setup when SDN reload inputs change (zone/VNet expansions, etc.).
    sdn_reload_hash     = local.sdn_reload_hash
    setup_script_hash   = filemd5("${path.module}/scripts/setup/setup-nat.sh")
    cleanup_script_hash = filemd5("${path.module}/scripts/cleanup/cleanup-nat.sh")
  }

  provisioner "local-exec" {
    command = <<-EOT
      scp ${path.module}/scripts/setup/setup-nat.sh root@${var.proxmox_host}:/tmp/setup-nat-${each.key}.sh
      ssh root@${var.proxmox_host} 'chmod +x /tmp/setup-nat-${each.key}.sh && /tmp/setup-nat-${each.key}.sh \
        "${var.zone_name}" \
        "${each.value.vnet_id}" \
        "${each.value.cidr}" \
        "${var.uplink_interface}"'
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      scp ${path.module}/scripts/cleanup/cleanup-nat.sh root@${self.triggers.proxmox_host}:/tmp/cleanup-nat.sh
      ssh root@${self.triggers.proxmox_host} 'chmod +x /tmp/cleanup-nat.sh && /tmp/cleanup-nat.sh \
        single \
        "${self.triggers.zone_name}" \
        "${self.triggers.vnet_id}" \
        "${self.triggers.subnet_cidr}" \
        "${self.triggers.uplink_interface}"'
    EOT
  }

  depends_on = [
    null_resource.sdn_reload,
    null_resource.gateway_setup,
  ]
}

resource "null_resource" "nat_cleanup" {
  triggers = {
    count        = (var.enable_host_l3 && var.enable_snat) ? 1 : 0
    zone_name    = var.zone_name
    proxmox_host = var.proxmox_host
    vnets_hash   = md5(jsonencode(var.vnets))
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      scp ${path.module}/scripts/cleanup/cleanup-nat.sh root@${self.triggers.proxmox_host}:/tmp/cleanup-nat.sh
      ssh root@${self.triggers.proxmox_host} 'chmod +x /tmp/cleanup-nat.sh && /tmp/cleanup-nat.sh \
        zone \
        "${self.triggers.zone_name}"'
    EOT
  }

  depends_on = [
    null_resource.nat_setup,
    proxmox_virtual_environment_sdn_applier.apply,
  ]
}

resource "null_resource" "dhcp_setup" {
  for_each = local.dhcp_subnets

  triggers = {
    zone_name        = var.zone_name
    vnet_id          = each.value.vnet_id
    subnet_cidr      = each.value.cidr
    gateway          = each.value.gateway
    dhcp_range_start = each.value.dhcp_range_start_effective
    dhcp_range_end   = each.value.dhcp_range_end_effective
    dns_server       = coalesce(each.value.dhcp_dns_server_effective, var.dhcp_default_dns_server)
    dns_domain       = var.dns_domain
    dns_lease        = var.dns_lease
    proxmox_host     = var.proxmox_host
    # Re-run DHCP setup when SDN reload inputs change (zone/VNet expansions, etc.).
    sdn_reload_hash     = local.sdn_reload_hash
    setup_script_hash   = filemd5("${path.module}/scripts/setup/setup-dhcp.sh")
    cleanup_script_hash = filemd5("${path.module}/scripts/cleanup/cleanup-dhcp.sh")
  }

  provisioner "local-exec" {
    command = <<-EOT
      scp ${path.module}/scripts/setup/setup-dhcp.sh root@${var.proxmox_host}:/tmp/setup-dhcp-${each.key}.sh
      ssh root@${var.proxmox_host} 'chmod +x /tmp/setup-dhcp-${each.key}.sh && /tmp/setup-dhcp-${each.key}.sh \
        "${var.zone_name}" \
        "${each.value.vnet_id}" \
        "${each.value.cidr}" \
        "${each.value.gateway}" \
        "${each.value.dhcp_range_start_effective}" \
        "${each.value.dhcp_range_end_effective}" \
        "${coalesce(each.value.dhcp_dns_server_effective, var.dhcp_default_dns_server)}" \
        "${var.dns_domain}" \
        "${var.dns_lease}"'
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      scp ${path.module}/scripts/cleanup/cleanup-dhcp.sh root@${self.triggers.proxmox_host}:/tmp/cleanup-dhcp.sh
      ssh root@${self.triggers.proxmox_host} 'chmod +x /tmp/cleanup-dhcp.sh && /tmp/cleanup-dhcp.sh \
        single \
        "${self.triggers.zone_name}" \
        "${self.triggers.vnet_id}" \
        "${self.triggers.subnet_cidr}"'
    EOT
  }

  depends_on = [
    null_resource.sdn_reload,
    null_resource.gateway_setup,
  ]
}

resource "null_resource" "dhcp_cleanup" {
  triggers = {
    count        = (var.enable_host_l3 && var.enable_dhcp) ? 1 : 0
    zone_name    = var.zone_name
    proxmox_host = var.proxmox_host
    vnets_hash   = md5(jsonencode(var.vnets))
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      scp ${path.module}/scripts/cleanup/cleanup-dhcp.sh root@${self.triggers.proxmox_host}:/tmp/cleanup-dhcp.sh
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

resource "null_resource" "sdn_reload" {
  triggers = {
    proxmox_host = var.proxmox_host
    config_hash  = local.sdn_reload_hash
    vnet_list    = local.vnet_list
  }

  provisioner "local-exec" {
    command = <<-EOT
      # Terraform local-exec uses /bin/sh by default; keep this POSIX-sh safe.
      ssh -o StrictHostKeyChecking=no root@${self.triggers.proxmox_host} 'set -eu

        echo "Applying SDN configuration via /cluster/sdn..."
        if ! pvesh set /cluster/sdn >/dev/null 2>&1; then
          echo "ERROR: pvesh set /cluster/sdn failed" >&2
          exit 1
        fi

        echo "Waiting for VNet interfaces to materialize..."
        sleep 3

        for vnet in ${self.triggers.vnet_list}; do
          RETRY=0
          MAX_RETRIES=30
          while [ "$RETRY" -lt "$MAX_RETRIES" ]; do
            if ip link show "$${vnet}" >/dev/null 2>&1; then
              echo "  ✓ $${vnet} ready"
              break
            fi
            sleep 1
            RETRY=$((RETRY + 1))
          done

          if ! ip link show "$${vnet}" >/dev/null 2>&1; then
            echo "ERROR: Interface $${vnet} not created after 30s" >&2
            echo "Available interfaces:" >&2
            ip link show | grep -E "^[0-9]+:" >&2
            exit 1
          fi
        done

        echo "All VNet interfaces verified successfully"
      '
    EOT
  }

  depends_on = [
    proxmox_virtual_environment_sdn_applier.apply,
  ]
}

resource "null_resource" "sdn_apply_finalizer" {
  triggers = {
    proxmox_host = var.proxmox_host
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      ssh root@${self.triggers.proxmox_host} 'set -u; \
        if pvesh ls /cluster/sdn >/dev/null 2>&1; then \
          if pvesh set /cluster/sdn >/dev/null 2>&1; then exit 0; fi; \
          if pvesh set /cluster/sdn/reload >/dev/null 2>&1; then exit 0; fi; \
          if pvesh create /cluster/sdn >/dev/null 2>&1; then exit 0; fi; \
        fi; \
        echo "sdn-finalizer: no supported /cluster/sdn apply endpoint found" >&2; \
        exit 1'
    EOT
  }
}
