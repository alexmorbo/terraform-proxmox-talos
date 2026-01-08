# Schematic for current extensions (used for current/non-update versions)
data "talos_image_factory_extensions_versions" "current" {
  for_each = toset([for v in local.all_talos_versions : v if local.version_schematic_type[v] == "current"])

  talos_version = each.value
  filters = {
    names = local.talos_schematic
  }
}

resource "talos_image_factory_schematic" "current" {
  for_each = data.talos_image_factory_extensions_versions.current

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

# Schematic for update extensions (used for update versions)
data "talos_image_factory_extensions_versions" "update" {
  for_each = toset([for v in local.all_talos_versions : v if local.version_schematic_type[v] == "update"])

  talos_version = each.value
  filters = {
    names = local.talos_schematic_update
  }
}

resource "talos_image_factory_schematic" "update" {
  for_each = data.talos_image_factory_extensions_versions.update

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
