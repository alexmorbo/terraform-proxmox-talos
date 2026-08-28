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

# Провайдер укорачивает имена ресурсов, убирая префикс virtual_environment;
# у короткого имени реализован MoveState, поэтому переезд идёт блоком moved,
# без пересоздания — иначе образ Talos удалился бы из хранилища и скачался
# заново. Требует Terraform >= 1.8.
moved {
  from = proxmox_virtual_environment_download_file.talos_image
  to   = proxmox_download_file.talos_image
}
