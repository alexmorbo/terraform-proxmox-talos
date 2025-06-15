locals {
  type = var.group_name == "controlplane" ? "controlplane" : "worker"
}

module "vm" {
  source   = "./modules/proxmox_vm"
  for_each = { for node in var.nodes : node.name => node }

  cluster_name = var.cluster_name
  name         = each.key
  node_type    = each.value.type
  node_group   = each.value.node_group
  target_node  = each.value.target_node
  datastore    = each.value.datastore
  image        = each.value.image
  sysctls      = each.value.sysctls
  dns          = var.dns

  sockets         = each.value.sockets
  cores           = each.value.cores
  memory          = each.value.memory
  networks        = each.value.networks
  pci_passthrough = each.value.pci_passthrough
}
