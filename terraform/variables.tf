
variable "gateway" {
  description = "Gateway of the cluster"
  default     = "192.168.45.1"
}

variable "master_count" {
  description = "Number of master nodes"
  default     = 3
}

variable "worker_count" {
  description = "Number of worker nodes"
  default     = 3
}

variable "masters_range_start" {
  default = "192.168.45.100"
}
variable "masters_range_end" {
  default = "192.168.45.125"
}

variable "workers_range_start" {
  default = "192.168.45.126"
}
variable "workers_range_end" {
  default = "192.168.45.250"
}

variable "vm_template" {
  description = "Proxmox template name"
  default     = "ubuntu-cloud-template"
}

variable "node" {
  description = "Proxmox node name"
  default     = "pve"
}

variable "ssh_username" {
  description = "Username created on the VM"
  default     = "admin"
}
