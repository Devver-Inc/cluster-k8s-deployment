#############################################
# Variables PAR CLUSTER
# Seuls ces paramètres sont à définir
# dans chaque terraform.tfvars
#############################################

# ---- Identité ----

variable "cluster_env" {
  type = string
}

# ---- Topologie ----

variable "master_worker_count" {
  type    = number
  default = 3
}

variable "worker_count" {
  type    = number
  default = 0
}

# ---- Adressage du cluster ----
# mw_ip_base  : 4e octet de départ pour les MW
#               MW-1 = subnet.mw_ip_base
#               MW-2 = subnet.mw_ip_base + 1
#               W-1  = subnet.mw_ip_base + 50
#               W-2  = subnet.mw_ip_base + 51
# lb_ip_offset: 4e octet pour le load balancer
#
# Plages globales disponibles :
#   VMs : .100 → .199  (réservez 50 IPs par cluster)
#   LB  : .80  → .98
#
# Exemple cluster TEST  : mw_ip_base=100, lb_ip_offset=80
# Exemple cluster PROD  : mw_ip_base=110, lb_ip_offset=81
# Exemple cluster DEV   : mw_ip_base=120, lb_ip_offset=82

variable "mw_ip_base" {
  description = "4e octet de départ pour les VMs de ce cluster"
  type        = number
}

variable "lb_ip_offset" {
  description = "4e octet pour le load balancer de ce cluster"
  type        = number
}

# ---- Proxmox ----

variable "target_node" {
  type    = string
  default = "PROXMOX-PVE1"
}

variable "storage" {
  type    = string
  default = "SSD-PVE-DATA"
}

variable "vm_template" {
  type    = string
  default = "debian13-cloudinit"
}

# ---- Cloud-init ----

variable "vm_user" {
  type    = string
  default = "devver"
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