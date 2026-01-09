locals {
  talos_version        = var.talos_cp_version
  talos_version_update = coalesce(var.talos_cp_version_update, var.talos_cp_version)

  talos_schematic        = var.talos_schematic
  talos_schematic_update = coalesce(var.talos_schematic_update, var.talos_schematic)

  kubernetes_version        = var.kubernetes_version
  kubernetes_version_update = coalesce(var.kubernetes_version_update, var.kubernetes_version)

  # Update is needed if any of: version, schematic, or k8s version changed
  cp_is_update = (
    local.talos_version != local.talos_version_update ||
    local.talos_schematic != local.talos_schematic_update ||
    local.kubernetes_version != local.kubernetes_version_update
  )

  # Static map of kubernetes versions per node (no dynamic dependencies)
  # This is needed because local.nodes contains dynamic values (image IDs)
  # which make the whole object "unknown" until apply
  node_kubernetes_versions = merge(
    # Controlplane current
    {
      for vm_data in flatten([
        for node_key, cp_config in var.controlplanes : [
          for i in range(cp_config.count) : {
            key   = "${var.cluster_name}-cp-${substr(sha256("${node_key}${i}${local.talos_version}"), 0, 7)}"
            value = local.kubernetes_version
          }
        ]
      ]) : vm_data.key => vm_data.value
    },
    # Controlplane update
    {
      for vm_data in flatten([
        for node_key, cp_config in var.controlplanes : [
          for i in(local.cp_is_update ? range(cp_config.count) : []) : {
            key   = "${var.cluster_name}-cp-${substr(sha256("${node_key}${i}${local.talos_version_update}"), 0, 7)}"
            value = local.kubernetes_version_update
          }
        ]
      ]) : vm_data.key => vm_data.value
    },
    # Workers current (init)
    {
      for vm_data in flatten([
        for node_key, node_group_config in local.workers : [
          for node_group, worker_config in node_group_config : [
            for i in range(worker_config.count) : {
              key   = "${var.cluster_name}-wk-${node_group}-${substr(sha256("${node_group}${node_key}${i}${worker_config.talos_version}"), 0, 7)}"
              value = coalesce(lookup(worker_config, "kubernetes_version", null), local.kubernetes_version)
            }
          ]
        ]
      ]) : vm_data.key => vm_data.value
    },
    # Workers update
    {
      for vm_data in flatten([
        for node_key, node_group_config in local.workers : [
          for node_group, worker_config in node_group_config : [
            for i in(worker_config.is_update ? range(worker_config.count) : []) : {
              key   = "${var.cluster_name}-wk-${node_group}-${substr(sha256("${node_group}${node_key}${i}${worker_config.talos_version_update}"), 0, 7)}"
              value = coalesce(lookup(worker_config, "kubernetes_version", null), local.kubernetes_version_update)
            }
          ]
        ]
      ]) : vm_data.key => vm_data.value
    },
    # External workers
    {
      for vm_data in flatten([
        for node, node_config in local.external_workers : {
          key   = node
          value = coalesce(lookup(node_config, "kubernetes_version", null), local.kubernetes_version)
        }
      ]) : vm_data.key => vm_data.value
    },
  )

  datastores_per_node = { for node_name, node in var.proxmox_cluster.nodes : node_name => node.datastore }

  # All unique Talos versions (for image downloads)
  # Workers may have custom versions different from global
  all_talos_versions = toset(
    concat(
      [local.talos_version, local.talos_version_update],
      flatten([
        for group, pve_node_workers in var.workers : [
          for node_group, node_config in pve_node_workers : [
            coalesce(lookup(node_config, "talos_version", null), local.talos_version),
            coalesce(
              lookup(node_config, "talos_version_update", null),
              coalesce(lookup(node_config, "talos_version", null), local.talos_version)
            )
          ]
        ]
      ])
    )
  )

  # Map version to schematic type (current or update)
  # Current versions use current schematic, update versions use update schematic
  version_schematic_type = {
    for v in local.all_talos_versions : v => (
      v == local.talos_version_update ? "update" : "current"
    )
  }

  workers = {
    for group, pve_node_workers in var.workers : group => {
      for node_group, node_config in pve_node_workers : node_group => merge(node_config, {
        talos_version = coalesce(lookup(node_config, "talos_version", null), local.talos_version)
        talos_version_update = coalesce(
          lookup(node_config, "talos_version_update", null),
          coalesce(lookup(node_config, "talos_version", null), local.talos_version)
        )
        is_update = coalesce(
          lookup(node_config, "talos_version", null), local.talos_version
          ) != coalesce(
          lookup(node_config, "talos_version_update", null),
          coalesce(lookup(node_config, "talos_version", null), local.talos_version)
        )
      })
    }
  }

  external_workers = {
    for node, node_config in(var.external_worker_nodes != null ? var.external_worker_nodes : {}) : "${var.cluster_name}-ext-${node}" => {
      type                 = "worker"
      architecture         = node_config.architecture
      talos_version        = node_config.talos_version
      talos_version_update = node_config.talos_version_update
      kubernetes_version   = node_config.kubernetes_version
      capabilities         = node_config.capabilities
      sysctls              = node_config.sysctls
      networks             = node_config.networks
      node_group           = node_config.node_group
      target_node          = node
      install_disk         = node_config.install_disk
      install_wipe         = node_config.install_wipe
      extra_mounts         = node_config.extra_mounts
    }
  }

  first_controlplane_node_key = length(var.controlplanes) > 0 ? sort(keys(var.controlplanes))[0] : null

  # Static bootstrap node name (no dynamic dependencies)
  # Used for fresh cluster bootstrap when VIP is not yet available
  bootstrap_node_name = (
    local.first_controlplane_node_key != null
    ? "${var.cluster_name}-cp-${substr(sha256("${local.first_controlplane_node_key}0${local.talos_version}"), 0, 7)}"
    : null
  )

  nodes = merge(
    {
      for vm_data in flatten([
        for node_key, cp_config in var.controlplanes : [
          for i in range(cp_config.count) : {
            key = "${var.cluster_name}-cp-${substr(sha256("${node_key}${i}${local.talos_version}"), 0, 7)}"

            value = {
              type               = "controlplane"
              sockets            = cp_config.socket
              cpus               = cp_config.cpu
              memory             = cp_config.ram
              sysctls            = cp_config.sysctls
              networks           = cp_config.networks
              image              = proxmox_virtual_environment_download_file.talos_image["${node_key}_${local.talos_version}"].id
              target_node        = node_key
              startup            = cp_config.startup
              extra_mounts       = cp_config.extra_mounts
              kubernetes_version = local.kubernetes_version
            }
          }
        ]
      ]) : vm_data.key => vm_data.value
    },
    {
      for vm_data in flatten([
        for node_key, cp_config in var.controlplanes : [
          for i in(local.cp_is_update ? range(cp_config.count) : []) : {
            key = "${var.cluster_name}-cp-${substr(sha256("${node_key}${i}${local.talos_version_update}"), 0, 7)}"

            value = {
              type               = "controlplane"
              sockets            = cp_config.socket
              cpus               = cp_config.cpu
              memory             = cp_config.ram
              sysctls            = cp_config.sysctls
              networks           = cp_config.networks
              image              = proxmox_virtual_environment_download_file.talos_image["${node_key}_${local.talos_version_update}"].id
              target_node        = node_key
              startup            = cp_config.startup
              extra_mounts       = cp_config.extra_mounts
              kubernetes_version = local.kubernetes_version_update
            }
          }
        ]
      ]) : vm_data.key => vm_data.value
    },
    {
      for vm_data in flatten([
        for node_key, node_group_config in local.workers : [
          for node_group, worker_config in node_group_config : [
            for i in range(worker_config.count) : {
              key = "${var.cluster_name}-wk-${node_group}-${substr(sha256("${node_group}${node_key}${i}${worker_config.talos_version}"), 0, 7)}"

              value = {
                type               = "worker"
                from               = "init"
                sockets            = worker_config.socket
                cpus               = worker_config.cpu
                memory             = worker_config.ram
                sysctls            = worker_config.sysctls
                networks           = worker_config.networks
                pci_passthrough    = worker_config.pci_passthrough
                startup            = worker_config.startup
                image              = proxmox_virtual_environment_download_file.talos_image["${node_key}_${worker_config.talos_version}"].id
                node_group         = coalesce(worker_config.node_group, node_group)
                target_node        = node_key
                extra_mounts       = worker_config.extra_mounts
                kubernetes_version = coalesce(lookup(worker_config, "kubernetes_version", null), local.kubernetes_version)
              }
            }
          ]
        ]
      ]) : vm_data.key => vm_data.value
    },
    {
      for vm_data in flatten([
        for node_key, node_group_config in local.workers : [
          for node_group, worker_config in node_group_config : [
            for i in(worker_config.is_update ? range(worker_config.count) : []) : {
              key = "${var.cluster_name}-wk-${node_group}-${substr(sha256("${node_group}${node_key}${i}${worker_config.talos_version_update}"), 0, 7)}"

              value = {
                type               = "worker"
                from               = "update"
                sockets            = worker_config.socket
                cpus               = worker_config.cpu
                memory             = worker_config.ram
                sysctls            = worker_config.sysctls
                networks           = worker_config.networks
                pci_passthrough    = worker_config.pci_passthrough
                startup            = worker_config.startup
                image              = proxmox_virtual_environment_download_file.talos_image["${node_key}_${worker_config.talos_version_update}"].id
                node_group         = coalesce(worker_config.node_group, node_group)
                target_node        = node_key
                extra_mounts       = worker_config.extra_mounts
                kubernetes_version = coalesce(lookup(worker_config, "kubernetes_version", null), local.kubernetes_version_update)
              }
            }
          ]
        ]
      ]) : vm_data.key => vm_data.value
    },
  )

  all_worker_nodes = {
    for node_obj in flatten([
      for group_instance in values(module.worker_node_group) : [
        for node_name, node_data in group_instance.nodes : {
          name = node_name
          data = node_data
        }
      ]
    ]) : node_obj.name => node_obj.data
  }

  # IP addresses for bare-metal nodes from static configuration
  external_node_ips = {
    for node, config in local.external_workers :
    node => [config.networks[0].address]
  }

  # Combine VM and bare-metal node IPs
  node_ips = merge(
    {
      for node in merge(module.control_plane.nodes, local.all_worker_nodes) :
      node.vm.name => [
        for ip in flatten(node.vm.ipv4_addresses) : ip
        if cidrhost("${ip}/${split("/", var.vm_subnet)[1]}", 1) == var.default_gateway && ip != var.cluster_vip
      ]
    },
    local.external_node_ips
  )

  # All IPs including VM and bare-metal nodes
  all_ips = toset(flatten(concat(
    [
      for node in merge(module.control_plane.nodes, local.all_worker_nodes) :
      [
        for ip in flatten(node.vm.ipv4_addresses) : ip
        if cidrhost("${ip}/${split("/", var.vm_subnet)[1]}", 1) == var.default_gateway && ip != var.cluster_vip
      ]
    ],
    [for node, ips in local.external_node_ips : ips]
  )))

  controlplane_nodes = [
    for k, v in local.nodes : merge(v, {
      name      = k
      datastore = local.datastores_per_node[v.target_node]
    }) if v.type == "controlplane"
  ]

  worker_nodes = [
    for k, v in local.nodes : merge(v, {
      name      = k
      datastore = local.datastores_per_node[v.target_node]
    }) if v.type == "worker"
  ]

  workers_by_group = {
    for node in local.worker_nodes :
    node.node_group => node...
  }

  # Images for all versions (supports worker custom versions)
  images = merge(
    # Current versions (use current schematic)
    {
      for v in local.all_talos_versions : v => {
        file_name               = "talos-${v}-${var.talos_platform}-${var.talos_arch}.img"
        url                     = "${var.talos_factory_url}/image/${talos_image_factory_schematic.current[v].id}/${v}/${var.talos_platform}-${var.talos_arch}.raw.gz"
        decompression_algorithm = "gz"
        version_type            = "current"
      } if local.version_schematic_type[v] == "current"
    },
    # Update versions (use update schematic)
    {
      for v in local.all_talos_versions : v => {
        file_name               = "talos-${v}-${var.talos_platform}-${var.talos_arch}.img"
        url                     = "${var.talos_factory_url}/image/${talos_image_factory_schematic.update[v].id}/${v}/${var.talos_platform}-${var.talos_arch}.raw.gz"
        decompression_algorithm = "gz"
        version_type            = "update"
      } if local.version_schematic_type[v] == "update"
    }
  )

  image_per_pve_node = {
    for pair in flatten([
      for node_name, node in var.proxmox_cluster.nodes : [
        for version, image_data in local.images : {
          key = "${node_name}_${version}"
          value = merge(
            image_data, {
              node      = node_name
              datastore = node.iso_datastore != null ? node.iso_datastore : node.datastore
            }
          )
        }
      ]
    ]) : pair.key => pair.value
  }
}
