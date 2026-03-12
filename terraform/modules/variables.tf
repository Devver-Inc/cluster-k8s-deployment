#############################################
# Variables du module k8s-cluster
#############################################

variable "cluster_env" {
  description = "Environnement : prod, dev ou test"
  type        = string
  validation {
    condition     = contains(["prod", "dev", "test"], var.cluster_env)
    error_message = "cluster_env doit être 'prod', 'dev' ou 'test'."
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

variable "mw_ip_base" {
  description = "4e octet de départ pour les MW de ce cluster (ex: 100 → .100, .101...)"
  type        = number
}

variable "lb_ip_offset" {
  description = "4e octet pour le load balancer de ce cluster (ex: 80 → .80)"
  type        = number
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
}

variable "vm_template" {
  type = string
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
  type    = string
  default = "40G"
}

variable "mw_disk_data_gb" {
  type    = string
  default = "150G"
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
  type    = string
  default = "40G"
}

variable "w_disk_data_gb" {
  type    = string
  default = "150G"
}