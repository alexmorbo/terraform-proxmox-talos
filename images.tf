data "talos_image_factory_extensions_versions" "this" {
  for_each      = local.all_image_configs
  talos_version = each.value.version
  filters = {
    names = each.value.extensions
  }
}

resource "talos_image_factory_schematic" "this" {
  for_each = data.talos_image_factory_extensions_versions.this

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
