output "zone_name_node1" {
  description = "SDN zone name (node1)"
  value       = module.sdn_node1.zone_name
}

output "vnets_node1" {
  description = "Created VNets (node1)"
  value       = module.sdn_node1.vnets
}

output "subnets_node1" {
  description = "Created subnets with DHCP configuration (node1)"
  value       = module.sdn_node1.subnets
}

# Planned outputs for future multi-node support
#
# output "zone_name_node2" {
#   description = "SDN zone name (node2)"
#   value       = module.sdn_node2.zone_name
# }
#
# output "vnets_node2" {
#   description = "Created VNets (node2)"
#   value       = module.sdn_node2.vnets
# }
#
# output "subnets_node2" {
#   description = "Created subnets with DHCP configuration (node2)"
#   value       = module.sdn_node2.subnets
# }
