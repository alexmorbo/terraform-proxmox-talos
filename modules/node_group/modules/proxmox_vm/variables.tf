variable "cluster_name" {
  type = string
}

variable "name" {
  type = string
}

variable "node_type" {
  type = string
}

variable "node_group" {
  type = string

  default = null
}

variable "target_node" {
  type = string
}

variable "sockets" {
  type = number

  default = 1
}

variable "cores" {
  type = number

  default = 1
}

variable "cpu_type" {
  type = string

  default = "host"
}

variable "memory" {
  type = number

  default = 2048
}

variable "sysctls" {
  type = map(string)

  default = {}
}

variable "networks" {
  type = list(object({
    interface     = string
    bridge        = string
    tag           = number
    model         = optional(string, "virtio")
    address       = optional(string, null)
    dhcp_disabled = optional(bool, false)
  }))
}

variable "datastore" {
  type = string
}

variable "image" {
  type = string
}

variable "dns" {
  type = set(string)

  default = ["1.1.1.1", "8.8.8.8"]
}
