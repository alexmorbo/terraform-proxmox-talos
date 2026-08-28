terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.76.1"
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

  required_version = ">= 1.5.0"
}
