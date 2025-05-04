resource "proxmox_virtual_environment_vm" "vm" {
  name        = var.name
  description = "Managed by Terraform"
  on_boot     = true
  machine     = "q35"

  tags = [var.cluster_name, coalesce(var.node_group, var.node_type)]

  node_name = var.target_node

  cpu {
    sockets = var.sockets
    cores   = var.cores
    type    = var.cpu_type
  }

  memory {
    dedicated = var.memory
  }

  agent {
    enabled = true
  }

  dynamic "network_device" {
    for_each = var.networks
    content {
      model   = network_device.value.model
      bridge  = network_device.value.bridge
      vlan_id = network_device.value.tag
    }
  }

  disk {
    datastore_id = var.datastore
    file_id      = var.image
    file_format  = "raw"
    interface    = "virtio0"
    size         = 64
  }

  operating_system {
    type = "l26" # Linux Kernel 2.6 - 5.X.
  }

  initialization {
    datastore_id = var.datastore

    dns {
      servers = var.dns
    }

    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }
  }

  serial_device {
    device = "socket"
  }

  vga {
    type = "serial0"
  }

  # dynamic "hostpci" {
  #   for_each = each.value.pci_passthrough
  #   content {
  #     device = "hostpci${hostpci.key}"
  #     id     = hostpci.value
  #     pcie   = true
  #     rombar = true
  #   }
  # }
}
