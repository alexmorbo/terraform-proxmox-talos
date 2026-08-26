output "cluster_name" {
  value       = var.cluster_name
  description = "The name of the Kubernetes cluster, as defined in the input variable."
}

output "talos_version" {
  value = local.talos_version
}

output "kubernetes_version" {
  value = var.kubernetes_version
}

output "node_ips" {
  value       = local.node_ips
  description = "A map of node names to their respective IP addresses, showing the internal IPs of each node in the cluster."
}

output "all_ips" {
  value       = local.all_ips
  description = "A set of all the IP addresses used by the cluster nodes. This includes both control plane and worker nodes."
}

output "talos_config" {
  value       = data.talos_client_configuration.this.talos_config
  description = "The Talos configuration used for the cluster nodes, containing sensitive data such as credentials and settings for node provisioning."
  sensitive   = true
}

output "kubeconfig" {
  value       = talos_cluster_kubeconfig.this.kubernetes_client_configuration
  description = "The kubeconfig for accessing the Kubernetes cluster, containing the necessary authentication information and cluster context."
  sensitive   = true
}

output "dedicated_node_groups" {
  value = [for group, nodes in local.workers_by_group : group if group != "default"]

  description = "Set of dedicated node groups in the cluster, that have taints."
}

output "node_macs_by_group" {
  value = merge(
    {
      controlplane = flatten([
        for node_name, node in module.control_plane.nodes : node.vm.mac_addresses
      ])
    },
    {
      for g_name, g in module.worker_node_group : g_name => flatten([
        for node_name, node in g.nodes : node.vm.mac_addresses
      ])
    },
  )

  description = "Map of node group name to list of MAC addresses of its nodes (all network interfaces). Useful for source filters in network policies (e.g. UniFi traffic routes)."
}

output "cilium_values" {
  value = var.cilium_values

  description = "The Cilium values used for the cluster initialization, which define the configuration for the Cilium CNI plugin."
}
