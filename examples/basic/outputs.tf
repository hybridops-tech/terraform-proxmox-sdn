# file: outputs.tf
# purpose: Expose key SDN outputs from the example module usage

output "zone_name" {
  description = "SDN zone name."
  value       = module.sdn.zone_name
}

output "vnets" {
  description = "Created SDN VNets."
  value       = module.sdn.vnets
}

output "subnets" {
  description = "Created SDN subnets with DHCP configuration."
  value       = module.sdn.subnets
}
