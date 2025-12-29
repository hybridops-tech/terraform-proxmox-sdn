# file: outputs.tf
# purpose: Expose SDN outputs for the node1 example

output "sdn_nodes" {
  description = "Aggregated SDN outputs for all nodes in this example."
  value = {
    node1 = {
      zone_name = module.sdn_node1.zone_name
      vnets     = module.sdn_node1.vnets
      subnets   = module.sdn_node1.subnets
    }

    # Uncomment when sdn_node2 is enabled
    # node2 = {
    #   zone_name = module.sdn_node2.zone_name
    #   vnets     = module.sdn_node2.vnets
    #   subnets   = module.sdn_node2.subnets
    # }
  }
}
