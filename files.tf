resource "proxmox_download_file" "talos_image" {
  for_each = local.image_per_pve_node

  content_type = "iso"
  datastore_id = each.value.datastore
  node_name    = each.value.node

  file_name               = each.value.file_name
  url                     = each.value.url
  decompression_algorithm = each.value.decompression_algorithm
  overwrite               = false
  overwrite_unmanaged     = true
  verify                  = false
}

# The provider is shortening resource names by dropping the
# virtual_environment prefix. The short name implements MoveState, so this is
# a moved block rather than a replacement — recreating it would delete the
# Talos image from the datastore and download it again. Needs Terraform 1.8.
moved {
  from = proxmox_virtual_environment_download_file.talos_image
  to   = proxmox_download_file.talos_image
}
