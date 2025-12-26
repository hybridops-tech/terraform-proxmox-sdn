output "zone_name" {
  description = "SDN zone name"
  value       = module.sdn.zone_name
}

output "vnets" {
  description = "Created VNets"
  value       = module.sdn.vnets
}

output "subnets" {
  description = "Created subnets with DHCP configuration"
  value       = module.sdn.subnets
}
