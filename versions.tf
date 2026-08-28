terraform {
  required_providers {
    proxmox = {
      source = "bpg/proxmox"

      # Верхняя граница по v1.0: там убирают длинные имена ресурсов
      # (proxmox_virtual_environment_*) — см. ADR-007 провайдера. До тех пор
      # оба имени работают, и переезд делается блоком moved.
      version = ">= 0.111.0, < 1.0.0"
    }
    talos = {
      source = "siderolabs/talos"

      # Верхняя граница осознанная, не поднимать без проверки. В 0.11.0
      # появился machine_configuration_hash, вокруг которого тянется цепочка
      # багов с config_patches: #327, #334, #352/#359 и #388/#389. Последний
      # фикс (b827ab3a, 27.08.2026) не вошёл ни в один релиз: в ветке 0.11+
      # стабильный только сам 0.11.0, а 0.12.0 существует лишь бетой.
      version = ">= 0.10.0, < 0.11.0"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.5.2"
    }
  }

  # moved между типами ресурсов требует 1.8.
  required_version = ">= 1.8.0"
}
