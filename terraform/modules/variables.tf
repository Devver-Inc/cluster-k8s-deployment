#############################################
# Variables du module k8s-cluster
#############################################

variable "cluster_env" {
  description = "Environnement : prod, staging, dev ou test"
  type        = string
  validation {
    condition     = contains(["prod", "staging", "dev", "test"], var.cluster_env)
    error_message = "cluster_env doit être: prod, staging, dev ou test"
  }
}

# ---- Topologie ----

variable "master_worker_count" {
  description = "Nombre de nœuds Master+Worker (minimum 3)"
  type        = number
  validation {
    condition     = var.master_worker_count >= 3
    error_message = "Il faut au minimum 3 nœuds Master+Worker."
  }
}

variable "worker_count" {
  description = "Nombre de nœuds Worker seuls"
  type        = number
  default     = 0
}

# ---- Réseau ----

variable "subnet" {
  description = "Les 3 premiers octets du subnet (ex: 192.168.45)"
  type        = string
}

# Plages IPs : calculées dans locals.tf basées sur cluster_env
variable "mw_ip_base_prod" {
  type    = number
  default = 110
}
variable "lb_ip_offset_prod" {
  type    = number
  default = 81
}
variable "mw_ip_base_staging" {
  type    = number
  default = 120
}
variable "lb_ip_offset_staging" {
  type    = number
  default = 82
}
variable "mw_ip_base_dev" {
  type    = number
  default = 130
}
variable "lb_ip_offset_dev" {
  type    = number
  default = 83
}
variable "mw_ip_base_test" {
  type    = number
  default = 100
}
variable "lb_ip_offset_test" {
  type    = number
  default = 80
}

variable "gateway" {
  type = string
}

variable "nameservers" {
  type = string
}

variable "network_bridge" {
  type = string
}

variable "network_tag" {
  type = number
}

# ---- Proxmox ----

variable "target_node" {
  type = string
}

variable "storage" {
  type = string
  default = "SSD-PVE-DATA"
}

variable "vm_template" {
  description = "Nom du template VM à cloner"
  type        = string
  default     = "debian13-cloudinit"
}

variable "vm_template_id" {
  description = "ID numérique du template VM Proxmox à cloner"
  type        = number
}

# ---- Cloud-init ----

variable "vm_user" {
  type = string
}

variable "ssh_public_key" {
  type      = string
  sensitive = true
}

# ---- Ressources Master+Worker ----

variable "mw_cores" {
  type    = number
  default = 4
}

variable "mw_memory_mb" {
  type    = number
  default = 3072
}

variable "mw_disk_os_gb" {
  description = "Taille disque OS en GB (ex: 40)"
  type        = number
  default     = 40
}

variable "mw_disk_data_gb" {
  description = "Taille disque data en GB (ex: 150)"
  type        = number
  default     = 150
}

# ---- Ressources Worker seul ----

variable "w_cores" {
  type    = number
  default = 4
}

variable "w_memory_mb" {
  type    = number
  default = 3072
}

variable "w_disk_os_gb" {
  description = "Taille disque OS en GB (ex: 40)"
  type        = number
  default     = 40
}

variable "w_disk_data_gb" {
  description = "Taille disque data en GB (ex: 150)"
  type        = number
  default     = 150
}