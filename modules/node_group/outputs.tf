output "nodes" {
  value = {
    for node_name, node in module.vm : node_name => {
      type        = local.type
      target_node = node.target_node
      networks    = node.networks
      node_group  = node.node_group
      vm          = node.node
    }
  }
}

output "type" {
  value = local.type
}
