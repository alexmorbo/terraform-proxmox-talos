locals {
  # STATE and EPHEMERAL are encrypted with a node-bound key. This used to
  # live in machine.systemDiskEncryption, deprecated in Talos 1.13 in favour
  # of separate VolumeConfig documents.
  disk_encryption = {
    provider = "luks2"
    options  = ["no_read_workqueue", "no_write_workqueue"]
    keys = [
      {
        slot   = 0
        nodeID = {}
      }
    ]
  }
}

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
      node_label_domain  = var.node_label_domain
      node_group         = try(each.value.node_group, null)
      sysctls            = merge(var.sysctls, each.value.sysctls)
      extra_kernel_args  = try(each.value.extra_kernel_args, [])
      machine_features   = var.machine_features
      balloon_enabled    = try(each.value.balloon_enabled, false)
      static_routes      = var.static_routes

      api_server_extra_args         = var.api_server_extra_args
      controller_manager_extra_args = var.controller_manager_extra_args
      scheduler_extra_args          = var.scheduler_extra_args
      etcd_extra_args               = var.etcd_extra_args
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
    yamlencode({
      apiVersion = "v1alpha1"
      kind       = "VolumeConfig"
      name       = "STATE"
      encryption = local.disk_encryption
    }),
    yamlencode({
      apiVersion = "v1alpha1"
      kind       = "VolumeConfig"
      name       = "EPHEMERAL"
      encryption = local.disk_encryption
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
