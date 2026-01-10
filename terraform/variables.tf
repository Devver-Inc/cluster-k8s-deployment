variable "proxmox_url" {
  description = "Proxmox API URL (https://proxmox.example:8006)"
  type        = string
}

variable "proxmox_user" {
  description = "Proxmox API user (e.g. root@pam)"
  type        = string
}

variable "proxmox_password" {
  description = "Proxmox API password"
  type        = string
  sensitive   = true
}

variable "proxmox_tls_insecure" {
  description = "Skip TLS verification"
  type        = bool
  default     = true
}

variable "target_node" {
  description = "Proxmox target node where VMs are created"
  type        = string
}

variable "master_count" {
  description = "Nombre de masters à provisionner"
  type        = number
  default     = 1
}

variable "worker_count" {
  description = "Nombre de workers à provisionner"
  type        = number
  default     = 3
}

variable "master_range_start" {
  description = "IP de début pour les masters (ex: 192.168.45.100)"
  type        = string
  default     = "192.168.45.100"
}

variable "master_range_end" {
  description = "IP de fin pour les masters (ex: 192.168.45.109)"
  type        = string
  default     = "192.168.45.109"
}

variable "worker_range_start" {
  description = "IP de début pour les workers (ex: 192.168.45.110)"
  type        = string
  default     = "192.168.45.110"
}

variable "worker_range_end" {
  description = "IP de fin pour les workers (ex: 192.168.45.129)"
  type        = string
  default     = "192.168.45.129"
}

variable "allocated_ips_path" {
  description = "Chemin vers le fichier JSON conservant les IPs allouées par Terraform"
  type        = string
  default     = "${path.module}/allocated_ips.json"
}

variable "public_key_path" {
  description = "Chemin vers la clé publique SSH à injecter dans les VM"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "vm_template" {
  description = "Nom du template cloud-init à cloner"
  type        = string
  default     = "debian13-cloudinit"
}

variable "nameserver" {
  description = "DNS resolvers to set in cloud-init"
  type        = string
  default     = "1.1.1.1 8.8.8.8"
}
#