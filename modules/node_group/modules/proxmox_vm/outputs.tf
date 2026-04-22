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
  value = {
    name           = proxmox_virtual_environment_vm.vm.name
    ipv4_addresses = proxmox_virtual_environment_vm.vm.ipv4_addresses
  }
}

output "kubernetes_version" {
  value = var.kubernetes_version
}

output "balloon_enabled" {
  value = var.balloon_enabled
}
