data "talos_machine_configuration" "this" {
  for_each = var.nodes

  cluster_name     = var.cluster_name
  cluster_endpoint = "https://${var.cluster_vip}:6443"
  machine_type     = each.value.type
  machine_secrets  = var.machine_secrets
  config_patches = [
    templatefile(var.config_template_path, {
      hostname           = each.key
      type               = each.value.type
      kubernetes_version = var.node_kubernetes_versions[each.key]
      cluster_vip        = var.cluster_vip
      vm_subnet          = var.vm_subnet
      pod_subnet         = var.pod_subnet
      service_subnet     = var.service_subnet
      networks           = each.value.networks
      dns                = var.dns
      proxmox_node       = each.value.target_node
      proxmox_cluster    = var.proxmox_cluster_name
      node_group         = try(each.value.node_group, null)
      sysctls            = merge(var.sysctls, each.value.sysctls)
      extra_kernel_args  = try(each.value.extra_kernel_args, [])
      machine_features   = var.machine_features
      balloon_enabled    = try(each.value.balloon_enabled, false)
      static_routes      = var.static_routes
      inline_manifests = [
        {
          name = "cilium-install"
          contents = templatefile(var.cilium_template_path, {
            cilium_values = yamlencode(var.cilium_values)
          })
        }
      ]
    }),
    yamlencode({
      apiVersion = "v1alpha1"
      kind       = "HostnameConfig"
      hostname   = each.key
      auto       = "off"
    }),
  ]

  talos_version = var.talos_version
}

resource "talos_machine_configuration_apply" "this" {
  for_each = var.nodes

  client_configuration        = var.client_configuration
  machine_configuration_input = data.talos_machine_configuration.this[each.key].machine_configuration
  node                        = var.node_ips[each.key][0]

  on_destroy = {
    graceful = true
    reboot   = false
    reset    = true
  }
}
