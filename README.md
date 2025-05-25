# About

[![GitHub Release](https://img.shields.io/github/v/release/alexmorbo/terraform-proxmox-talos)](https://github.com/alexmorbo/terraform-proxmox-talos/releases) [![GitHub](https://img.shields.io/github/license/alexmorbo/terraform-proxmox-talos)](https://github.com/alexmorbo/terraform-proxmox-talos/blob/main/LICENSE)

Terraform module to provision Talos Linux-based Kubernetes clusters on Proxmox Virtual Environment (PVE). Handles VM creation, Talos image deployment, cluster bootstrapping, and client configuration setup.

## Features

- Deploys Kubernetes clusters based on Talos Linux
- Supports both control plane and worker nodes
- Downloads and provisions Talos images into Proxmox
- Optional creation of kubeconfig and talosconfig files locally
- Modular and customizable node group definitions

## Quick Start

```hcl
module "talos_cluster" {
  source        = "github.com/alexmorbo/terraform-proxmox-talos"
  cluster_name  = "mycluster"
  talos_cp_version = "1.10.0"
  talos_schematic = [
    "siderolabs/i915",
    "siderolabs/qemu-guest-agent",
  ]

  default_gateway = "10.90.12.1"
  cluster_vip     = "10.90.12.11"

  vm_subnet      = "10.90.12.0/24"
  pod_subnet     = "10.209.0.0/16"
  service_subnet = "10.208.0.0/16"

  proxmox_cluster = {
    cluster_name = "homelab"
    nodes = {
      node-1 = {
        datastore = "local-lvm"
      }
      node-2 = {
        datastore = "local-lvm"
      }
      node-3 = {
        datastore = "local-lvm"
      }
    }
  }

  controlplanes = {
    node-1 = {
      count = 1
      networks = [
        {
          interface = "eth0"
          bridge    = "vmbr0"
        },
      ]
    }
    node-2 = {
      count = 1
      networks = [
        {
          interface = "eth0"
          bridge    = "vmbr0"
        },
      ]
    }
    node-3 = {
      count = 1
      networks = [
        {
          interface = "eth0"
          bridge    = "vmbr0"
        },
      ]
    }
  }

  workers = {
    node-1 = {
      ingress = {
        count = 1
        cpu   = 2
        ram   = 4096
        networks = [
          {
            interface = "eth0"
            bridge    = "vmbr0"
          },
        ]
      }
      default = {
        count = 2
        networks = [
          {
            interface = "eth0"
            bridge    = "vmbr0"
          },
        ]
      }
    }
    node-2 = {
      ingress = {
        count = 1
        cpu   = 2
        ram   = 4096
        networks = [
          {
            interface = "eth0"
            bridge    = "vmbr0"
          },
        ]
      }
      default = {
        count = 1
        networks = [
          {
            interface = "eth0"
            bridge    = "vmbr0"
          },
        ]
      }
    }
    node-2 = {
      ingress = {
        count = 1
        cpu   = 2
        ram   = 4096
        networks = [
          {
            interface = "eth0"
            bridge    = "vmbr0"
          },
        ]
      }
    }
  }
}
```

## Module Structure

- `modules/node_group/` – reusable logic for control plane and worker nodes
- `images.tf` – Talos image downloading and provisioning
- `talos.tf` – Talos client and machine configurations
- `virtual_machines.tf` – VM creation logic for Proxmox
- `files.tf` – optional local configuration file generation

## Notes

- Tested with Proxmox VE 8.2
- Requires a user with access to upload ISO/images and manage VMs
- Make sure to enable Talos provider by setting environment variables or credentials

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5.0 |
| <a name="requirement_local"></a> [local](#requirement\_local) | ~> 2.5.2 |
| <a name="requirement_proxmox"></a> [proxmox](#requirement\_proxmox) | ~> 0.76.1 |
| <a name="requirement_talos"></a> [talos](#requirement\_talos) | 0.8.0-alpha.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_local"></a> [local](#provider\_local) | 2.5.2 |
| <a name="provider_proxmox"></a> [proxmox](#provider\_proxmox) | 0.76.1 |
| <a name="provider_talos"></a> [talos](#provider\_talos) | 0.8.0-alpha.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_control_plane"></a> [control\_plane](#module\_control\_plane) | ./modules/node_group | n/a |
| <a name="module_worker_node_group"></a> [worker\_node\_group](#module\_worker\_node\_group) | ./modules/node_group | n/a |

## Resources

| Name | Type |
|------|------|
| [local_file.kubeconfig](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [local_file.talosconfig](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [proxmox_virtual_environment_download_file.talos_image](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/virtual_environment_download_file) | resource |
| [talos_cluster_kubeconfig.this](https://registry.terraform.io/providers/siderolabs/talos/0.8.0-alpha.0/docs/resources/cluster_kubeconfig) | resource |
| [talos_image_factory_schematic.version](https://registry.terraform.io/providers/siderolabs/talos/0.8.0-alpha.0/docs/resources/image_factory_schematic) | resource |
| [talos_machine_bootstrap.this](https://registry.terraform.io/providers/siderolabs/talos/0.8.0-alpha.0/docs/resources/machine_bootstrap) | resource |
| [talos_machine_configuration_apply.this](https://registry.terraform.io/providers/siderolabs/talos/0.8.0-alpha.0/docs/resources/machine_configuration_apply) | resource |
| [talos_machine_secrets.this](https://registry.terraform.io/providers/siderolabs/talos/0.8.0-alpha.0/docs/resources/machine_secrets) | resource |
| [talos_client_configuration.this](https://registry.terraform.io/providers/siderolabs/talos/0.8.0-alpha.0/docs/data-sources/client_configuration) | data source |
| [talos_image_factory_extensions_versions.version](https://registry.terraform.io/providers/siderolabs/talos/0.8.0-alpha.0/docs/data-sources/image_factory_extensions_versions) | data source |
| [talos_machine_configuration.this](https://registry.terraform.io/providers/siderolabs/talos/0.8.0-alpha.0/docs/data-sources/machine_configuration) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cilium_values"></a> [cilium\_values](#input\_cilium\_values) | A map of configuration values for Cilium, used to customize its deployment and behavior in the Kubernetes cluster. | `any` | <pre>{<br/>  "cgroup": {<br/>    "autoMount": {<br/>      "enabled": false<br/>    },<br/>    "hostRoot": "/sys/fs/cgroup"<br/>  },<br/>  "externalIPs": {<br/>    "enabled": true<br/>  },<br/>  "hubble": {<br/>    "tls": {<br/>      "auto": {<br/>        "method": "cronJob"<br/>      }<br/>    }<br/>  },<br/>  "ipam": {<br/>    "mode": "kubernetes"<br/>  },<br/>  "k8sClientRateLimit": {<br/>    "burst": 100,<br/>    "qps": 50<br/>  },<br/>  "kubeProxyReplacement": true,<br/>  "l2announcements": {<br/>    "enabled": true<br/>  },<br/>  "operator": {<br/>    "replicas": 1<br/>  },<br/>  "rollOutCiliumPods": true,<br/>  "securityContext": {<br/>    "capabilities": {<br/>      "ciliumAgent": [<br/>        "CHOWN",<br/>        "KILL",<br/>        "NET_ADMIN",<br/>        "NET_RAW",<br/>        "IPC_LOCK",<br/>        "SYS_ADMIN",<br/>        "SYS_RESOURCE",<br/>        "DAC_OVERRIDE",<br/>        "FOWNER",<br/>        "SETGID",<br/>        "SETUID"<br/>      ],<br/>      "cleanCiliumState": [<br/>        "NET_ADMIN",<br/>        "SYS_ADMIN",<br/>        "SYS_RESOURCE"<br/>      ]<br/>    }<br/>  }<br/>}</pre> | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | The name of the Talos cluster. | `string` | n/a | yes |
| <a name="input_cluster_vip"></a> [cluster\_vip](#input\_cluster\_vip) | The virtual IP (VIP) address for the cluster, typically used for load balancing or high availability setups. | `string` | n/a | yes |
| <a name="input_controlplanes"></a> [controlplanes](#input\_controlplanes) | Configuration of control plane nodes, including the number of nodes, resources (CPU, RAM), and network configuration. | <pre>map(object({<br/>    count  = number<br/>    socket = optional(number, 1)<br/>    cpu    = optional(number, 4)<br/>    ram    = optional(number, 8192)<br/>    networks = list(object({<br/>      interface = string<br/>      bridge    = string<br/>      tag       = number<br/>      model     = optional(string, "virtio")<br/>      address   = optional(string, null)<br/>    }))<br/>  }))</pre> | n/a | yes |
| <a name="input_create_kubeconfig_file"></a> [create\_kubeconfig\_file](#input\_create\_kubeconfig\_file) | Flag to determine whether a local kubernetes configuration file should be created. If set to true, a local\_file resource will be generated with the appropriate content. | `bool` | `false` | no |
| <a name="input_create_talosconfig_file"></a> [create\_talosconfig\_file](#input\_create\_talosconfig\_file) | Flag to determine whether a local Talos configuration file should be created. If set to true, a local\_file resource will be generated with the appropriate content. | `bool` | `false` | no |
| <a name="input_default_gateway"></a> [default\_gateway](#input\_default\_gateway) | The default gateway for the cluster nodes, used for routing external traffic. | `string` | n/a | yes |
| <a name="input_dns"></a> [dns](#input\_dns) | A set of DNS server addresses to be used by the cluster nodes. Default includes Cloudflare and Google DNS. | `set(string)` | <pre>[<br/>  "1.1.1.1",<br/>  "8.8.8.8"<br/>]</pre> | no |
| <a name="input_kubeconfig_file_template"></a> [kubeconfig\_file\_template](#input\_kubeconfig\_file\_template) | Template path for the kubeconfig file, where '\_\_CLUSTER\_\_' will be replaced by the cluster name. | `string` | `"~/.kube/configs/__CLUSTER__.yaml"` | no |
| <a name="input_kubernetes_version"></a> [kubernetes\_version](#input\_kubernetes\_version) | The desired version of Kubernetes to be installed in the cluster. | `string` | `"1.33.0"` | no |
| <a name="input_pod_subnet"></a> [pod\_subnet](#input\_pod\_subnet) | The subnet for Kubernetes pods, defining the IP range for pod networking. | `string` | n/a | yes |
| <a name="input_proxmox_cluster"></a> [proxmox\_cluster](#input\_proxmox\_cluster) | Proxmox cluster configuration, including the cluster name and the datastore associated with each node. | <pre>object({<br/>    cluster_name = string<br/>    nodes = map(object({<br/>      datastore = string<br/>    }))<br/>  })</pre> | n/a | yes |
| <a name="input_service_subnet"></a> [service\_subnet](#input\_service\_subnet) | The subnet for Kubernetes services, defining the IP range for internal cluster services. | `string` | n/a | yes |
| <a name="input_talos_arch"></a> [talos\_arch](#input\_talos\_arch) | The architecture for Talos nodes. Defaults to 'amd64'. | `string` | `"amd64"` | no |
| <a name="input_talos_cp_version"></a> [talos\_cp\_version](#input\_talos\_cp\_version) | The desired version of Talos to be used in the cluster nodes. | `string` | n/a | yes |
| <a name="input_talos_cp_version_update"></a> [talos\_cp\_version\_update](#input\_talos\_cp\_version\_update) | Optional: The Talos control plane version update, if any, to apply to the existing Talos version. | `string` | `null` | no |
| <a name="input_talos_factory_url"></a> [talos\_factory\_url](#input\_talos\_factory\_url) | The URL of the Talos factory, used for managing node images and configurations. | `string` | `"https://factory.talos.dev"` | no |
| <a name="input_talos_platform"></a> [talos\_platform](#input\_talos\_platform) | The platform type for Talos, typically used to define how nodes are provisioned (e.g., nocloud, vmware, etc.). | `string` | `"nocloud"` | no |
| <a name="input_talos_schematic"></a> [talos\_schematic](#input\_talos\_schematic) | A set of Talos configuration files or schematics to apply during the cluster setup. | `set(string)` | n/a | yes |
| <a name="input_talosconfig_file_name"></a> [talosconfig\_file\_name](#input\_talosconfig\_file\_name) | The path and filename for the generated Talos configuration file. Defaults to ~/.talos/config. | `string` | `"~/.talos/config"` | no |
| <a name="input_vm_subnet"></a> [vm\_subnet](#input\_vm\_subnet) | The subnet for the virtual machines in the cluster. | `string` | n/a | yes |
| <a name="input_workers"></a> [workers](#input\_workers) | Configuration of worker nodes, with the ability to specify the number of nodes, Talos version, Kubernetes version, and network details. | <pre>map(map(object({<br/>    count                = number<br/>    talos_version        = optional(string)<br/>    talos_version_update = optional(string)<br/>    kubernetes_version   = optional(string)<br/>    socket               = optional(number, 1)<br/>    cpu                  = optional(number, 4)<br/>    ram                  = optional(number, 8192)<br/>    networks = list(object({<br/>      bridge    = string<br/>      tag       = number<br/>      interface = string<br/>      model     = optional(string, "virtio")<br/>      address   = optional(string, null)<br/>    }))<br/>  })))</pre> | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_all_ips"></a> [all\_ips](#output\_all\_ips) | A set of all the IP addresses used by the cluster nodes. This includes both control plane and worker nodes. |
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | The name of the Kubernetes cluster, as defined in the input variable. |
| <a name="output_dedicated_node_groups"></a> [dedicated\_node\_groups](#output\_dedicated\_node\_groups) | Set of dedicated node groups in the cluster, that have taints. |
| <a name="output_kubeconfig"></a> [kubeconfig](#output\_kubeconfig) | The kubeconfig for accessing the Kubernetes cluster, containing the necessary authentication information and cluster context. |
| <a name="output_node_ips"></a> [node\_ips](#output\_node\_ips) | A map of node names to their respective IP addresses, showing the internal IPs of each node in the cluster. |
| <a name="output_talos_config"></a> [talos\_config](#output\_talos\_config) | The Talos configuration used for the cluster nodes, containing sensitive data such as credentials and settings for node provisioning. |
<!-- END_TF_DOCS -->
