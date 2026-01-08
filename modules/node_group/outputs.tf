output "nodes" {
  value = {
    for node_name, node in module.vm : node_name => {
      type               = local.type
      target_node        = node.target_node
      networks           = node.networks
      node_group         = node.node_group
      vm                 = node.node
      sysctls            = node.sysctls
      kubernetes_version = node.kubernetes_version
      extra_mounts       = node.extra_mounts
    }
  }
}

# output "node_groups" {
#   value = {
#     for node_group, nodes in module.vm : node_group => {
#       nodes = nodes
#     }
#   }
# }

output "type" {
  value = local.type
}
