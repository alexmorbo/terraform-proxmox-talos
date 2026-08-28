terraform {
  required_providers {
    proxmox = {
      source = "bpg/proxmox"

      # Bounded by v1.0, which drops the long resource names
      # (proxmox_virtual_environment_*) — see the provider's ADR-007. Until
      # then both names work and the switch is a moved block.
      version = ">= 0.111.0, < 1.0.0"
    }
    talos = {
      source = "siderolabs/talos"

      # The upper bound is deliberate — do not raise it without testing.
      # 0.11.0 introduced machine_configuration_hash and a run of bugs around
      # it and config_patches: #327, #334, #352/#359, #388/#389. The last fix
      # (b827ab3a, 2026-08-27) is in no release: 0.11.0 is the only stable one
      # in that line and 0.12.0 exists as a beta.
      version = ">= 0.10.0, < 0.11.0"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.5.2"
    }
  }

  # Cross-type moved blocks need 1.8.
  required_version = ">= 1.8.0"
}
