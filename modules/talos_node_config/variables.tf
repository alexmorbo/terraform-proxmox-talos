variable "nodes" {
  description = "Map of node_name => node_data from node_group module output"
  type        = any
}

variable "node_ips" {
  description = "Map of node_name => list of IPs"
  type        = map(list(string))
}

variable "node_kubernetes_versions" {
  description = "Map of node_name => kubernetes version"
  type        = map(string)
}

variable "cluster_name" { type = string }
variable "cluster_vip" { type = string }
variable "vm_subnet" { type = string }
variable "pod_subnet" { type = string }
variable "service_subnet" { type = string }
variable "dns" { type = set(string) }
variable "proxmox_cluster_name" { type = string }
variable "sysctls" { type = map(string) }
variable "machine_features" { type = map(any) }
variable "machine_secrets" {
  type      = any
  sensitive = true
}
variable "client_configuration" {
  type      = any
  sensitive = true
}
variable "cilium_values" { type = any }
variable "config_template_path" { type = string }
variable "cilium_template_path" { type = string }
variable "talos_version" {
  type    = string
  default = null
}

variable "static_routes" {
  type = list(object({
    network = string
    gateway = string
  }))
  default = []
}
