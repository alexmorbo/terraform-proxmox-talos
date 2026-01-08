terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.76.1"
    }
    talos = {
      source  = "siderolabs/talos"
      version = ">= 0.8.0, < 0.10.0"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.5.2"
    }
  }

  required_version = ">= 1.5.0"
}
