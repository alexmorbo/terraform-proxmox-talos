resource "proxmox_virtual_environment_download_file" "talos_image" {
  for_each = local.image_per_pve_node

  content_type = "iso"
  datastore_id = each.value.datastore
  node_name    = each.value.node

  file_name               = each.value.file_name
  url                     = each.value.url
  decompression_algorithm = each.value.decompression_algorithm
  overwrite               = true
  overwrite_unmanaged     = true
  verify                  = false
}
