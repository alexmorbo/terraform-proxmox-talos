data "talos_image_factory_extensions_versions" "version" {
  for_each = local.versions

  talos_version = each.value
  filters = {
    names = var.talos_schematic
  }
}

resource "talos_image_factory_schematic" "version" {
  for_each = data.talos_image_factory_extensions_versions.version

  schematic = yamlencode(
    {
      customization = {
        systemExtensions = {
          officialExtensions = each.value.extensions_info[*].name
        }
      }
    }
  )
}
