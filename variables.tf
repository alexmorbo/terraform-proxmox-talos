variable "cluster_name" {
  type        = string
  description = "The name of the Talos cluster."
}

variable "kubernetes_version" {
  type        = string
  description = "The desired version of Kubernetes to be installed in the cluster."

  default = "1.33.0"
}

variable "talos_cp_version" {
  type        = string
  description = "The desired version of Talos to be used in the cluster nodes."
}

variable "talos_cp_version_update" {
  type        = string
  description = "Optional: The Talos control plane version update, if any, to apply to the existing Talos version."

  default = null
}

variable "talos_schematic" {
  description = "A set of Talos configuration files or schematics to apply during the cluster setup."
  type        = set(string)
}

variable "talos_factory_url" {
  type        = string
  description = "The URL of the Talos factory, used for managing node images and configurations."

  default = "https://factory.talos.dev"
}

variable "talos_arch" {
  type        = string
  description = "The architecture for Talos nodes. Defaults to 'amd64'."

  default = "amd64"
}

variable "talos_platform" {
  type        = string
  description = "The platform type for Talos, typically used to define how nodes are provisioned (e.g., nocloud, vmware, etc.)."

  default = "nocloud"
}

variable "proxmox_cluster" {
  type = object({
    cluster_name = string
    nodes = map(object({
      datastore = string
    }))
  })
  description = "Proxmox cluster configuration, including the cluster name and the datastore associated with each node."
}

variable "dns" {
  type        = set(string)
  description = "A set of DNS server addresses to be used by the cluster nodes. Default includes Cloudflare and Google DNS."

  default = ["1.1.1.1", "8.8.8.8"]
}

variable "controlplanes" {
  type = map(object({
    count   = number
    socket  = optional(number, 1)
    cpu     = optional(number, 4)
    ram     = optional(number, 8192)
    sysctls = optional(map(string), {})
    networks = list(object({
      interface     = string
      bridge        = string
      tag           = number
      model         = optional(string, "virtio")
      address       = optional(string, null)
      dhcp_disabled = optional(bool, false)
    }))
  }))
  description = "Configuration of control plane nodes, including the number of nodes, resources (CPU, RAM), and network configuration."
}

variable "workers" {
  type = map(map(object({
    count                = number
    talos_version        = optional(string)
    talos_version_update = optional(string)
    kubernetes_version   = optional(string)
    socket               = optional(number, 1)
    cpu                  = optional(number, 4)
    ram                  = optional(number, 8192)
    sysctls              = optional(map(string), {})
    networks = list(object({
      bridge        = string
      tag           = number
      interface     = string
      model         = optional(string, "virtio")
      address       = optional(string, null)
      dhcp_disabled = optional(bool, false)
    }))
    pci_passthrough = optional(list(object({
      id      = optional(string)
      mapping = optional(string)
      pcie    = optional(bool, true)
      rombar  = optional(bool, true)
    })))
  })))

  default     = {}
  description = "Configuration of worker nodes, with the ability to specify the number of nodes, Talos version, Kubernetes version, and network details."
}

variable "vm_subnet" {
  type        = string
  description = "The subnet for the virtual machines in the cluster."
}

variable "pod_subnet" {
  type        = string
  description = "The subnet for Kubernetes pods, defining the IP range for pod networking."
}

variable "service_subnet" {
  type        = string
  description = "The subnet for Kubernetes services, defining the IP range for internal cluster services."
}

variable "default_gateway" {
  type        = string
  description = "The default gateway for the cluster nodes, used for routing external traffic."
}

variable "cluster_vip" {
  type        = string
  description = "The virtual IP (VIP) address for the cluster, typically used for load balancing or high availability setups."
}

variable "create_talosconfig_file" {
  type        = bool
  description = "Flag to determine whether a local Talos configuration file should be created. If set to true, a local_file resource will be generated with the appropriate content."
  default     = false
}

variable "talosconfig_file_name" {
  type        = string
  description = "The path and filename for the generated Talos configuration file. Defaults to ~/.talos/config."
  default     = "~/.talos/config"
}

variable "create_kubeconfig_file" {
  type        = bool
  description = "Flag to determine whether a local kubernetes configuration file should be created. If set to true, a local_file resource will be generated with the appropriate content."
  default     = false
}

variable "kubeconfig_file_template" {
  type        = string
  description = "Template path for the kubeconfig file, where '__CLUSTER__' will be replaced by the cluster name."
  default     = "~/.kube/configs/__CLUSTER__.yaml"
}

variable "cilium_values" {
  type        = any
  description = "A map of configuration values for Cilium, used to customize its deployment and behavior in the Kubernetes cluster."
  default = {
    kubeProxyReplacement = true
    rollOutCiliumPods    = true

    k8sServiceHost = "localhost"
    k8sServicePort = 7445

    routingMode    = "tunnel"
    tunnelProtocol = "vxlan"

    k8sClientRateLimit = {
      qps   = 50
      burst = 100
    }

    cgroup = {
      hostRoot = "/sys/fs/cgroup"
      autoMount = {
        enabled = false
      }
    }

    externalIPs = {
      enabled = true
    }

    l2announcements = {
      enabled = true
    }

    ipam = {
      mode = "kubernetes"
    }

    hubble = {
      tls = {
        auto = {
          method = "cronJob"
        }
      }
    }

    operator = {
      replicas = 1
    }

    securityContext = {
      capabilities = {
        ciliumAgent = [
          "CHOWN",
          "KILL",
          "NET_ADMIN",
          "NET_RAW",
          "IPC_LOCK",
          "SYS_ADMIN",
          "SYS_RESOURCE",
          "DAC_OVERRIDE",
          "FOWNER",
          "SETGID",
          "SETUID"
        ]
        cleanCiliumState = [
          "NET_ADMIN",
          "SYS_ADMIN",
          "SYS_RESOURCE"
        ]
      }
    }
  }
}

variable "sysctls" {
  type        = map(string)
  description = "A map of sysctl settings to be applied to the nodes in the cluster. These settings can be used to tune kernel parameters for performance or security."

  default = {}
}
