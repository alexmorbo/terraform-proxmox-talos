# VM image is passed as a pre-computed string (local.talos_image_ids)
# rather than resource[key].id. This breaks the value-level dependency
# from VM → download_file, so adding a new image entry no longer
# invalidates downstream data sources for unrelated nodes.
#
# Trade-off: there is no graph dependency VM → download_file. In
# practice, `proxmox_download_file` still depends
# on `talos_image_factory_schematic.this` (via url), so the
# create-order is schematic → download → (parallel) VM. On incremental
# changes to existing clusters (all prior images already present) this
# is safe. On a fresh bootstrap with many new images, it is possible
# for TF to try to create a VM before its image has finished
# downloading — in that case the Proxmox API returns a clear error and
# the next `apply` succeeds.
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
