resource "talos_machine_secrets" "this" {}

data "talos_client_configuration" "this" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoints            = flatten([for node in local.controlplane_nodes : local.node_ips[node.name]])
}

data "talos_machine_configuration" "this" {
  for_each = merge(module.control_plane.nodes, local.all_worker_nodes)

  cluster_name     = var.cluster_name
  cluster_endpoint = "https://${var.cluster_vip}:6443"
  machine_type     = each.value.type
  machine_secrets  = talos_machine_secrets.this.machine_secrets
  config_patches = [
    templatefile("${path.module}/talos/pve_vm_machineconfig.yaml.tftpl", {
      hostname           = each.key
      type               = each.value.type
      kubernetes_version = local.node_kubernetes_versions[each.key]
      cluster_vip        = var.cluster_vip
      vm_subnet          = var.vm_subnet
      pod_subnet         = var.pod_subnet
      service_subnet     = var.service_subnet
      networks           = each.value.networks
      dns                = var.dns
      proxmox_node       = each.value.target_node
      proxmox_cluster    = var.proxmox_cluster.cluster_name
      node_group         = try(each.value.node_group, null)
      sysctls            = merge(var.sysctls, each.value.sysctls)
      machine_features   = var.machine_features
      extra_mounts       = try(each.value.extra_mounts, [])
      inline_manifests = [
        {
          name = "cilium-install"
          contents = templatefile("${path.module}/talos/cilium-install.yaml.tftpl", {
            cilium_values = yamlencode(var.cilium_values)
          })
        }
      ]
    }),
  ]
}

data "talos_machine_configuration" "external" {
  for_each = local.external_workers

  cluster_name     = var.cluster_name
  cluster_endpoint = "https://${var.cluster_vip}:6443"
  machine_type     = each.value.type
  machine_secrets  = talos_machine_secrets.this.machine_secrets
  config_patches = [
    templatefile("${path.module}/talos/external_machineconfig.yaml.tftpl", {
      hostname           = each.key
      type               = each.value.type
      kubernetes_version = local.node_kubernetes_versions[each.key]
      vm_subnet          = var.vm_subnet
      pod_subnet         = var.pod_subnet
      service_subnet     = var.service_subnet
      dns                = var.dns
      networks           = each.value.networks
      target_node        = each.value.target_node
      node_group         = each.value.node_group
      enable_taints      = lookup(each.value, "enable_taints", true)
      sysctls            = lookup(each.value, "sysctls", {})
      has_nvidia         = anytrue([for cap in each.value.capabilities : can(regex("nvidia", cap))])
      install_disk       = each.value.install_disk
      install_wipe       = each.value.install_wipe
      extra_mounts       = each.value.extra_mounts
      inline_manifests = [
        {
          name = "cilium-install"
          contents = templatefile("${path.module}/talos/cilium-install.yaml.tftpl", {
            cilium_values = yamlencode(var.cilium_values)
          })
        }
      ]
    }),
  ]
}

resource "talos_machine_configuration_apply" "this" {
  for_each = merge(module.control_plane.nodes, local.all_worker_nodes)

  client_configuration        = data.talos_client_configuration.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.this[each.key].machine_configuration
  node                        = local.node_ips[each.key][0]
  # apply_mode                  = "reboot"

  on_destroy = {
    graceful = true
    reboot   = false
    reset    = true
  }
}

resource "talos_machine_configuration_apply" "external" {
  for_each = local.external_workers

  client_configuration        = data.talos_client_configuration.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.external[each.key].machine_configuration
  node                        = each.value.networks[0].address
  # apply_mode                  = "reboot"

  on_destroy = {
    graceful = true
    reboot   = false
    reset    = true
  }
}

# # Wait for nodes to be healthy after config apply
# data "talos_cluster_health" "this" {
#   depends_on = [
#     talos_machine_configuration_apply.this,
#     talos_machine_configuration_apply.external
#   ]

#   client_configuration = talos_machine_secrets.this.client_configuration
#   endpoints            = flatten([for node in local.controlplane_nodes : local.node_ips[node.name]])
#   control_plane_nodes  = flatten([for node in local.controlplane_nodes : local.node_ips[node.name]])
#   worker_nodes         = flatten([for node_name, node_data in local.all_worker_nodes : local.node_ips[node_name]])

#   skip_kubernetes_checks = true

#   timeouts = {
#     read = "10m"
#   }
# }

resource "talos_machine_bootstrap" "this" {
  depends_on = [
    talos_machine_configuration_apply.this,
    talos_machine_configuration_apply.external
  ]

  client_configuration = data.talos_client_configuration.this.client_configuration
  # Use bootstrap node IP for fresh cluster (VIP not yet available)
  node = local.node_ips[local.bootstrap_node_name][0]
}

resource "talos_cluster_kubeconfig" "this" {
  depends_on = [talos_machine_bootstrap.this]

  client_configuration = data.talos_client_configuration.this.client_configuration
  node                 = var.cluster_vip
}

resource "local_file" "talosconfig" {
  count = var.create_talosconfig_file ? 1 : 0

  filename = pathexpand(var.talosconfig_file_name)
  content = yamlencode({
    context   = var.cluster_name
    endpoints = data.talos_client_configuration.this.endpoints
    contexts = {
      (var.cluster_name) = {
        endpoints = data.talos_client_configuration.this.endpoints
        nodes     = local.all_ips
        ca        = talos_machine_secrets.this.client_configuration.ca_certificate
        crt       = talos_machine_secrets.this.client_configuration.client_certificate
        key       = talos_machine_secrets.this.client_configuration.client_key
      }
    }
    current-context = var.cluster_name
  })
}

resource "local_file" "kubeconfig" {
  count = var.create_kubeconfig_file ? 1 : 0

  filename = pathexpand(
    replace(var.kubeconfig_file_template, "__CLUSTER__", var.cluster_name)
  )
  content = yamlencode({
    apiVersion = "v1"
    kind       = "Config"
    clusters = [
      {
        name = var.cluster_name
        cluster = {
          certificate-authority-data = talos_cluster_kubeconfig.this.kubernetes_client_configuration.ca_certificate
          server                     = talos_cluster_kubeconfig.this.kubernetes_client_configuration.host
        }
      }
    ]
    contexts = [
      {
        name = var.cluster_name
        context = {
          cluster = var.cluster_name
          user    = var.cluster_name
        }
      }
    ]
    users = [
      {
        name = var.cluster_name
        user = {
          client-certificate-data = talos_cluster_kubeconfig.this.kubernetes_client_configuration.client_certificate
          client-key-data         = talos_cluster_kubeconfig.this.kubernetes_client_configuration.client_key
        }
      }
    ]
  })
}
