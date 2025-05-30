locals {
  talos_version        = var.talos_cp_version
  talos_version_update = coalesce(var.talos_cp_version_update, var.talos_cp_version)
  cp_is_update         = local.talos_version != coalesce(local.talos_version_update, local.talos_version)

  datastores_per_node = { for node_name, node in var.proxmox_cluster.nodes : node_name => node.datastore }

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

  versions = toset(
    concat(
      [local.talos_version, local.talos_version_update],
      flatten(
        [
          for group, pve_node_workers in var.workers : [
            for node_group, node_config in pve_node_workers :
            coalesce(lookup(node_config, "talos_version", null), local.talos_version)
          ]
        ]
      ),
      flatten(
        [
          for group, pve_node_workers in var.workers : [
            for node_group, node_config in pve_node_workers :
            coalesce(lookup(node_config, "talos_version_update", null), local.talos_version_update)
          ]
        ]
      )
    )
  )

  first_controlplane_node_key = length(var.controlplanes) > 0 ? sort(keys(var.controlplanes))[0] : null

  nodes = merge(
    {
      for vm_data in flatten([
        for node_key, cp_config in var.controlplanes : [
          for i in range(cp_config.count) : {
            key = "${var.cluster_name}-cp-${substr(sha256("${node_key}${i}${local.talos_version}"), 0, 7)}"

            value = {
              type        = "controlplane"
              sockets     = cp_config.socket
              cpus        = cp_config.cpu
              memory      = cp_config.ram
              sysctls     = cp_config.sysctls
              networks    = cp_config.networks
              image       = proxmox_virtual_environment_download_file.talos_image["${node_key}_${local.talos_version}"].id
              bootstrap   = (node_key == local.first_controlplane_node_key && i == 0)
              target_node = node_key
              # pci_passthrough = (node_key == local.first_controlplane_node_key && i == 0) ? ["0000:03:00"] : []
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
              type        = "controlplane"
              sockets     = cp_config.socket
              cpus        = cp_config.cpu
              memory      = cp_config.ram
              sysctls     = cp_config.sysctls
              networks    = cp_config.networks
              image       = proxmox_virtual_environment_download_file.talos_image["${node_key}_${local.talos_version_update}"].id
              bootstrap   = false
              target_node = node_key
              # pci_passthrough = (node_key == local.first_controlplane_node_key && i == 0) ? ["0000:03:00"] : []
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
                type        = "worker"
                from        = "init"
                sockets     = worker_config.socket
                cpus        = worker_config.cpu
                memory      = worker_config.ram
                sysctls     = worker_config.sysctls
                networks    = worker_config.networks
                image       = proxmox_virtual_environment_download_file.talos_image["${node_key}_${worker_config.talos_version}"].id
                node_group  = node_group
                target_node = node_key
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
                type        = "worker"
                from        = "update"
                sockets     = worker_config.socket
                cpus        = worker_config.cpu
                memory      = worker_config.ram
                sysctls     = worker_config.sysctls
                networks    = worker_config.networks
                image       = proxmox_virtual_environment_download_file.talos_image["${node_key}_${worker_config.talos_version_update}"].id
                node_group  = node_group
                target_node = node_key
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

  node_ips = {
    for node in merge(module.control_plane.nodes, local.all_worker_nodes) :
    node.vm.name => [
      for ip in flatten(node.vm.ipv4_addresses) : ip
      if cidrhost("${ip}/${split("/", var.vm_subnet)[1]}", 1) == var.default_gateway && ip != var.cluster_vip
    ]
  }

  all_ips = toset(flatten([
    for node in merge(module.control_plane.nodes, local.all_worker_nodes) :
    [
      for ip in flatten(node.vm.ipv4_addresses) : ip
      if cidrhost("${ip}/${split("/", var.vm_subnet)[1]}", 1) == var.default_gateway && ip != var.cluster_vip
    ]
  ]))

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

  bootstrap_node = one([for node in local.controlplane_nodes : node.name if try(node.bootstrap, false) == true])

  workers_by_group = {
    for node in local.worker_nodes :
    node.node_group => node...
  }

  images = {
    for version in local.versions : version => {
      file_name               = "talos-${version}-${var.talos_platform}-${var.talos_arch}.img"
      url                     = "${var.talos_factory_url}/image/${talos_image_factory_schematic.version[version].id}/${version}/${var.talos_platform}-${var.talos_arch}.raw.gz"
      decompression_algorithm = "gz"
      version_type            = "current"
    }
  }

  image_per_pve_node = {
    for pair in flatten([
      for node_name, node in var.proxmox_cluster.nodes : [
        for version, image_data in local.images : {
          key = "${node_name}_${version}"
          value = merge(
            image_data, {
              node      = node_name
              datastore = node.datastore
            }
          )
        }
      ]
    ]) : pair.key => pair.value
  }
}
