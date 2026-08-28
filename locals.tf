locals {
  talos_version        = var.talos_cp_version
  talos_version_update = coalesce(var.talos_cp_version_update, var.talos_cp_version)

  talos_schematic        = var.talos_schematic
  talos_schematic_update = coalesce(var.talos_schematic_update, var.talos_schematic)

  schematic_fingerprint        = substr(sha256(jsonencode(sort(tolist(local.talos_schematic)))), 0, 8)
  schematic_fingerprint_update = substr(sha256(jsonencode(sort(tolist(local.talos_schematic_update)))), 0, 8)

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
            key   = "${var.cluster_name}-cp-${substr(sha256("${node_key}${i}${local.talos_version}${local.schematic_fingerprint}"), 0, 7)}"
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
            key   = "${var.cluster_name}-cp-${substr(sha256("${node_key}${i}${local.talos_version_update}${local.schematic_fingerprint_update}"), 0, 7)}"
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
              key   = "${var.cluster_name}-wk-${node_group}-${substr(sha256("${node_group}${node_key}${i}${worker_config.talos_version}${worker_config.schematic_fingerprint}"), 0, 7)}"
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
              key   = "${var.cluster_name}-wk-${node_group}-${substr(sha256("${node_group}${node_key}${i}${worker_config.talos_version_update}${worker_config.schematic_fingerprint_update}"), 0, 7)}"
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

  # All unique image configs: map of "version_fingerprint" => {version, extensions}
  all_image_configs = merge(
    {
      "${local.talos_version}_${local.schematic_fingerprint}" = {
        version    = local.talos_version
        extensions = local.talos_schematic
      }
    },
    {
      "${local.talos_version_update}_${local.schematic_fingerprint_update}" = {
        version    = local.talos_version_update
        extensions = local.talos_schematic_update
      }
    },
    # Per-worker current images. Non-override workers collapse onto the
    # cluster-wide entry thanks to identical version+fingerprint keys.
    # Key is content-derived (version + sha(extensions)), so collisions
    # are always safe: we pick the first grouped value.
    {
      for k, group in {
        for entry in flatten([
          for group, pve_node_workers in local.workers : [
            for node_group, wc in pve_node_workers : {
              key = "${wc.talos_version}_${wc.schematic_fingerprint}"
              value = {
                version    = wc.talos_version
                extensions = wc.talos_schematic
              }
            }
          ]
        ]) : entry.key => entry.value...
      } : k => group[0]
    },
    # Per-worker update images.
    {
      for k, group in {
        for entry in flatten([
          for group, pve_node_workers in local.workers : [
            for node_group, wc in pve_node_workers : {
              key = "${wc.talos_version_update}_${wc.schematic_fingerprint_update}"
              value = {
                version    = wc.talos_version_update
                extensions = wc.talos_schematic_update
              }
            }
          ]
        ]) : entry.key => entry.value...
      } : k => group[0]
    },
  )

  # Resolved per-worker talos/schematic state. Extracted so that version,
  # schematic, fingerprint and is_update share the same source of truth.
  # Non-override workers fall back to cluster-wide values; fingerprints are
  # identical to cluster fingerprints in that case, so node name hashes
  # stay stable (idempotent refactor).
  workers = {
    for group, pve_node_workers in var.workers : group => {
      for node_group, node_config in pve_node_workers : node_group => merge(node_config, {
        talos_version = coalesce(lookup(node_config, "talos_version", null), local.talos_version)
        talos_version_update = coalesce(
          lookup(node_config, "talos_version_update", null),
          coalesce(lookup(node_config, "talos_version", null), local.talos_version)
        )
        talos_schematic = coalesce(
          lookup(node_config, "talos_schematic", null),
          local.talos_schematic
        )
        talos_schematic_update = coalesce(
          lookup(node_config, "talos_schematic_update", null),
          lookup(node_config, "talos_schematic", null),
          local.talos_schematic_update
        )
        schematic_fingerprint = substr(sha256(jsonencode(sort(tolist(coalesce(
          lookup(node_config, "talos_schematic", null),
          local.talos_schematic
        ))))), 0, 8)
        schematic_fingerprint_update = substr(sha256(jsonencode(sort(tolist(coalesce(
          lookup(node_config, "talos_schematic_update", null),
          lookup(node_config, "talos_schematic", null),
          local.talos_schematic_update
        ))))), 0, 8)
        is_update = (
          coalesce(lookup(node_config, "talos_version", null), local.talos_version)
          != coalesce(
            lookup(node_config, "talos_version_update", null),
            coalesce(lookup(node_config, "talos_version", null), local.talos_version)
          )
          ) || (
          coalesce(lookup(node_config, "talos_schematic", null), local.talos_schematic)
          != coalesce(
            lookup(node_config, "talos_schematic_update", null),
            lookup(node_config, "talos_schematic", null),
            local.talos_schematic_update
          )
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
    }
  }

  first_controlplane_node_key = length(var.controlplanes) > 0 ? sort(keys(var.controlplanes))[0] : null

  # Static bootstrap node name (no dynamic dependencies)
  # Used for fresh cluster bootstrap when VIP is not yet available
  bootstrap_node_name = (
    local.first_controlplane_node_key != null
    ? "${var.cluster_name}-cp-${substr(sha256("${local.first_controlplane_node_key}0${local.talos_version}${local.schematic_fingerprint}"), 0, 7)}"
    : null
  )

  nodes = merge(
    {
      for vm_data in flatten([
        for node_key, cp_config in var.controlplanes : [
          for i in range(cp_config.count) : {
            key = "${var.cluster_name}-cp-${substr(sha256("${node_key}${i}${local.talos_version}${local.schematic_fingerprint}"), 0, 7)}"

            value = {
              type               = "controlplane"
              sockets            = cp_config.socket
              cores              = cp_config.cpu
              memory             = cp_config.ram
              balloon_enabled    = cp_config.balloon_enabled
              min_memory         = cp_config.min_memory
              sysctls            = cp_config.sysctls
              networks           = cp_config.networks
              image              = local.talos_image_ids["${node_key}_${local.talos_version}_${local.schematic_fingerprint}"]
              target_node        = node_key
              datastore          = local.datastores_per_node[node_key]
              startup            = cp_config.startup
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
            key = "${var.cluster_name}-cp-${substr(sha256("${node_key}${i}${local.talos_version_update}${local.schematic_fingerprint_update}"), 0, 7)}"

            value = {
              type            = "controlplane"
              sockets         = cp_config.socket
              cores           = cp_config.cpu
              memory          = cp_config.ram
              balloon_enabled = cp_config.balloon_enabled
              min_memory      = cp_config.min_memory
              sysctls         = cp_config.sysctls
              networks        = cp_config.networks
              # Update CP VMs: resource ref for ordering (see worker
              # update block for rationale).
              image              = proxmox_download_file.talos_image["${node_key}_${local.talos_version_update}_${local.schematic_fingerprint_update}"].id
              target_node        = node_key
              datastore          = local.datastores_per_node[node_key]
              startup            = cp_config.startup
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
              key = "${var.cluster_name}-wk-${node_group}-${substr(sha256("${node_group}${node_key}${i}${worker_config.talos_version}${worker_config.schematic_fingerprint}"), 0, 7)}"

              value = {
                type               = "worker"
                from               = "init"
                sockets            = worker_config.socket
                cores              = worker_config.cpu
                memory             = worker_config.ram
                balloon_enabled    = worker_config.balloon_enabled
                min_memory         = worker_config.min_memory
                sysctls            = worker_config.sysctls
                extra_kernel_args  = worker_config.extra_kernel_args
                networks           = worker_config.networks
                pci_passthrough    = worker_config.pci_passthrough
                startup            = worker_config.startup
                image              = local.talos_image_ids["${node_key}_${worker_config.talos_version}_${worker_config.schematic_fingerprint}"]
                node_group         = coalesce(worker_config.node_group, node_group)
                target_node        = node_key
                datastore          = coalesce(worker_config.datastore, local.datastores_per_node[node_key])
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
              key = "${var.cluster_name}-wk-${node_group}-${substr(sha256("${node_group}${node_key}${i}${worker_config.talos_version_update}${worker_config.schematic_fingerprint_update}"), 0, 7)}"

              value = {
                type              = "worker"
                from              = "update"
                sockets           = worker_config.socket
                cores             = worker_config.cpu
                memory            = worker_config.ram
                balloon_enabled   = worker_config.balloon_enabled
                min_memory        = worker_config.min_memory
                sysctls           = worker_config.sysctls
                extra_kernel_args = worker_config.extra_kernel_args
                networks          = worker_config.networks
                pci_passthrough   = worker_config.pci_passthrough
                startup           = worker_config.startup
                # Update VMs use the live resource ref so creation waits
                # for the download to finish. Existing ("init") VMs use
                # the precomputed string to avoid the unknown-cascade
                # that would otherwise invalidate unrelated nodes.
                image              = proxmox_download_file.talos_image["${node_key}_${worker_config.talos_version_update}_${worker_config.schematic_fingerprint_update}"].id
                node_group         = coalesce(worker_config.node_group, node_group)
                target_node        = node_key
                datastore          = coalesce(worker_config.datastore, local.datastores_per_node[node_key])
                kubernetes_version = coalesce(lookup(worker_config, "kubernetes_version", null), local.kubernetes_version_update)
              }
            }
          ]
        ]
      ]) : vm_data.key => vm_data.value
    },
  )

  # IP addresses for bare-metal nodes from static configuration
  external_node_ips = {
    for node, config in local.external_workers :
    node => [config.networks[0].address]
  }

  # Combine VM and bare-metal node IPs
  node_ips = merge(
    {
      for node_name, node in module.control_plane.nodes :
      node.vm.name => [
        for ip in flatten(node.vm.ipv4_addresses) : ip
        if cidrhost("${ip}/${split("/", var.vm_subnet)[1]}", 1) == var.default_gateway && ip != var.cluster_vip
      ]
    },
    merge([
      for g in values(module.worker_node_group) : {
        for node_name, node in g.nodes :
        node.vm.name => [
          for ip in flatten(node.vm.ipv4_addresses) : ip
          if cidrhost("${ip}/${split("/", var.vm_subnet)[1]}", 1) == var.default_gateway && ip != var.cluster_vip
        ]
      }
    ]...),
    local.external_node_ips
  )

  # All IPs including VM and bare-metal nodes
  all_ips = toset(flatten(concat(
    [
      for node_name, node in module.control_plane.nodes :
      [
        for ip in flatten(node.vm.ipv4_addresses) : ip
        if cidrhost("${ip}/${split("/", var.vm_subnet)[1]}", 1) == var.default_gateway && ip != var.cluster_vip
      ]
    ],
    flatten([
      for g in values(module.worker_node_group) : [
        for node_name, node in g.nodes :
        [
          for ip in flatten(node.vm.ipv4_addresses) : ip
          if cidrhost("${ip}/${split("/", var.vm_subnet)[1]}", 1) == var.default_gateway && ip != var.cluster_vip
        ]
      ]
    ]),
    [for node, ips in local.external_node_ips : ips]
  )))

  controlplane_nodes = [
    for k, v in local.nodes : merge(v, { name = k }) if v.type == "controlplane"
  ]

  worker_nodes = [
    for k, v in local.nodes : merge(v, { name = k }) if v.type == "worker"
  ]

  workers_by_group = {
    for node in local.worker_nodes :
    node.node_group => node...
  }

  # Single source of truth for image file names. Both the download_file
  # resource (files.tf, via local.images → local.image_per_pve_node) and
  # the precomputed Proxmox file ID (local.talos_image_ids) derive from
  # here, so a rename in one place can't silently diverge from the
  # other.
  image_file_names = {
    for key, config in local.all_image_configs :
    key => "talos-${config.version}-${key}-${var.talos_platform}-${var.talos_arch}.img"
  }

  images = {
    for key, config in local.all_image_configs : key => {
      file_name               = local.image_file_names[key]
      url                     = "${var.talos_factory_url}/image/${talos_image_factory_schematic.this[key].id}/${config.version}/${var.talos_platform}-${var.talos_arch}.raw.gz"
      decompression_algorithm = "gz"
    }
  }

  image_per_pve_node = {
    for pair in flatten([
      for node_name, node in var.proxmox_cluster.nodes : [
        for image_key, image_data in local.images : {
          key = "${node_name}_${image_key}"
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

  # Pre-computed Proxmox file IDs, derived WITHOUT reference to the
  # download resource or local.images (whose `url` transitively depends
  # on talos_image_factory_schematic and would propagate "unknown"
  # through the whole map). This breaks the graph dependency from
  # VM.image to the download resource, so adding a new image entry no
  # longer forces Terraform to re-read existing control-plane data
  # sources (false-positive in-place updates).
  #
  # Proxmox download_file ID format is stable: "<datastore>:iso/<file_name>".
  talos_image_ids = {
    for pair in flatten([
      for node_name, node in var.proxmox_cluster.nodes : [
        for image_key, _ in local.all_image_configs : {
          key = "${node_name}_${image_key}"
          value = format(
            "%s:iso/%s",
            node.iso_datastore != null ? node.iso_datastore : node.datastore,
            local.image_file_names[image_key],
          )
        }
      ]
    ]) : pair.key => pair.value
  }
}
