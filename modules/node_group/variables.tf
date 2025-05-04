variable "cluster_name" {
  type = string
}

variable "dns" {
  type = set(string)
}

variable "group_name" {
  type = string

  default = ""
}

variable "nodes" {
  type = list(object({
    name        = string
    type        = string
    target_node = string
    datastore   = string
    image       = string
    node_group  = optional(string)

    sockets = optional(number, 1)
    cores   = optional(number, 4)
    memory  = optional(number, 2048)
    networks = list(object({
      interface = string
      bridge    = string
      tag       = number
      model     = optional(string, "virtio")
      address   = optional(string, null)
    }))
  }))
}
