resource "talos_machine_secrets" "this" {}

data "talos_client_configuration" "this" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoints            = flatten([for node in local.controlplane_nodes : local.node_ips[node.name]])
}

locals {
  talos_config_common = {
    cluster_name         = var.cluster_name
    cluster_vip          = var.cluster_vip
    vm_subnet            = var.vm_subnet
    pod_subnet           = var.pod_subnet
    service_subnet       = var.service_subnet
    dns                  = var.dns
    proxmox_cluster_name = var.proxmox_cluster.cluster_name
    sysctls              = var.sysctls
    machine_features     = var.machine_features
    machine_secrets      = talos_machine_secrets.this.machine_secrets
    client_configuration = data.talos_client_configuration.this.client_configuration
    cilium_values        = var.cilium_values
    config_template_path = "${path.module}/talos/pve_vm_machineconfig.yaml.tftpl"
    cilium_template_path = "${path.module}/talos/cilium-install.yaml.tftpl"
    talos_version        = "v${join(".", slice(split(".", var.talos_cp_version), 0, 2))}"
    static_routes        = var.static_routes
  }
}

module "controlplane_talos_config" {
  source     = "./modules/talos_node_config"
  depends_on = [module.control_plane]

  nodes = module.control_plane.nodes
  node_ips = {
    for k, v in module.control_plane.nodes : k => [
      for ip in flatten(v.vm.ipv4_addresses) : ip
      if cidrhost("${ip}/${split("/", var.vm_subnet)[1]}", 1) == var.default_gateway && ip != var.cluster_vip
    ]
  }
  node_kubernetes_versions = {
    for k, _ in module.control_plane.nodes : k => local.node_kubernetes_versions[k]
  }

  cluster_name         = local.talos_config_common.cluster_name
  cluster_vip          = local.talos_config_common.cluster_vip
  vm_subnet            = local.talos_config_common.vm_subnet
  pod_subnet           = local.talos_config_common.pod_subnet
  service_subnet       = local.talos_config_common.service_subnet
  dns                  = local.talos_config_common.dns
  proxmox_cluster_name = local.talos_config_common.proxmox_cluster_name
  sysctls              = local.talos_config_common.sysctls
  machine_features     = local.talos_config_common.machine_features
  machine_secrets      = local.talos_config_common.machine_secrets
  client_configuration = local.talos_config_common.client_configuration
  cilium_values        = local.talos_config_common.cilium_values
  config_template_path = local.talos_config_common.config_template_path
  cilium_template_path = local.talos_config_common.cilium_template_path
  talos_version        = local.talos_config_common.talos_version
  static_routes        = local.talos_config_common.static_routes
}

module "worker_talos_config" {
  source   = "./modules/talos_node_config"
  for_each = module.worker_node_group

  nodes = each.value.nodes
  node_ips = {
    for k, v in each.value.nodes : k => [
      for ip in flatten(v.vm.ipv4_addresses) : ip
      if cidrhost("${ip}/${split("/", var.vm_subnet)[1]}", 1) == var.default_gateway && ip != var.cluster_vip
    ]
  }
  node_kubernetes_versions = {
    for k, _ in each.value.nodes : k => local.node_kubernetes_versions[k]
  }

  cluster_name         = local.talos_config_common.cluster_name
  cluster_vip          = local.talos_config_common.cluster_vip
  vm_subnet            = local.talos_config_common.vm_subnet
  pod_subnet           = local.talos_config_common.pod_subnet
  service_subnet       = local.talos_config_common.service_subnet
  dns                  = local.talos_config_common.dns
  proxmox_cluster_name = local.talos_config_common.proxmox_cluster_name
  sysctls              = local.talos_config_common.sysctls
  machine_features     = local.talos_config_common.machine_features
  machine_secrets      = local.talos_config_common.machine_secrets
  client_configuration = local.talos_config_common.client_configuration
  cilium_values        = local.talos_config_common.cilium_values
  config_template_path = local.talos_config_common.config_template_path
  cilium_template_path = local.talos_config_common.cilium_template_path
  talos_version        = local.talos_config_common.talos_version
  static_routes        = local.talos_config_common.static_routes
}

data "talos_machine_configuration" "external" {
  for_each = local.external_workers

  cluster_name     = var.cluster_name
  cluster_endpoint = "https://${var.cluster_vip}:6443"
  machine_type     = each.value.type
  machine_secrets  = talos_machine_secrets.this.machine_secrets
  talos_version    = local.talos_config_common.talos_version
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
      inline_manifests = [
        {
          name = "cilium-install"
          contents = templatefile("${path.module}/talos/cilium-install.yaml.tftpl", {
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
    module.controlplane_talos_config,
    module.worker_talos_config,
    talos_machine_configuration_apply.external,
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
