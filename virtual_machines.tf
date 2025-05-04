module "control_plane" {
  source = "./modules/node_group"

  cluster_name = var.cluster_name
  dns          = var.dns
  group_name   = "controlplane"
  nodes        = local.controlplane_nodes
}

module "worker_node_group" {
  source   = "./modules/node_group"
  for_each = local.workers_by_group

  cluster_name = var.cluster_name
  dns          = var.dns
  group_name   = each.key
  nodes        = each.value
}
