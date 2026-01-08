output "target_node" {
  value = var.target_node
}

output "sysctls" {
  value = var.sysctls
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

output "extra_mounts" {
  value = var.extra_mounts
}

output "kubernetes_version" {
  value = var.kubernetes_version
}
