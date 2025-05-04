output "target_node" {
  value = var.target_node
}

output "networks" {
  value = var.networks
}

output "node_group" {
  value = var.node_group
}

output "node" {
  value = proxmox_virtual_environment_vm.vm
}
