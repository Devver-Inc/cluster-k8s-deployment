#############################################
# Variables GLOBALES — authentification et réseau
# Identiques pour tous les clusters.
#############################################

# ---- Authentification Proxmox ----

variable "proxmox_api_url" {
  type    = string
  default = "https://192.168.5.3:8006/"
}

variable "proxmox_api_token" {
  type        = string
  sensitive   = true
  description = "Format: user@realm!tokenid=secret (ex: root@pam!devver=xxxxxxxx-xxxx...)"
  default = "your-token-here"
}

# ---- Réseau global ----

variable "subnet" {
  description = "Les 3 premiers octets du subnet"
  type        = string
  default     = "192.168.45"
}

variable "gateway" {
  type    = string
  default = "192.168.45.200"
}

variable "nameservers" {
  type    = string
  default = "1.1.1.1 8.8.8.8"
}

variable "network_bridge" {
  type    = string
  default = "vmbr1"
}

variable "network_tag" {
  type    = number
  default = 45
}

# ---- Proxmox Infrastructure ----

variable "target_node" {
  description = "Nœud Proxmox cible pour les VMs"
  type        = string
  default     = "PROXMOX-PVE1"
}

variable "storage" {
  description = "Datastore Proxmox pour les déclarations"
  type        = string
  default     = "SSD-PVE-DATA"
}

variable "vm_template" {
  description = "Nom du template VM à cloner (cloud-init required)"
  type        = string
  default     = "debian13-cloudinit"
}

variable "vm_template_id" {
  description = "ID numérique du template VM Proxmox (ex: 9000 pour debian13-cloudinit)"
  type        = number
  default     = 9000
}

variable "vm_user" {
  description = "Utilisateur cloud-init par défaut pour les VMs"
  type        = string
  default     = "devver"
}

variable "ssh_public_key" {
  description = "Clé publique SSH à injecter (format: ssh-ed25519 AAAA...)"
  type        = string
  sensitive   = true
}

# ---- Allocation IP par cluster (déterministe) ----
# mw_ip_base et lb_ip_offset sont calculées automatiquement à partir de cluster_env
# pour éviter le besoin de les spécifier dans terraform.tfvars

variable "mw_ip_base_prod" {
  description = "4e octet de départ pour MW en PROD"
  type        = number
  default     = 110  # 192.168.45.110-115
}

variable "lb_ip_offset_prod" {
  type    = number
  default = 81
}

variable "mw_ip_base_staging" {
  description = "4e octet de départ pour MW en STAGING"
  type        = number
  default     = 120  # 192.168.45.120-125
}

variable "lb_ip_offset_staging" {
  type    = number
  default = 82
}

variable "mw_ip_base_dev" {
  description = "4e octet de départ pour MW en DEV"
  type        = number
  default     = 130  # 192.168.45.130-135
}

variable "lb_ip_offset_dev" {
  type    = number
  default = 83
}

variable "mw_ip_base_test" {
  description = "4e octet de départ pour MW en TEST"
  type        = number
  default     = 100  # 192.168.45.100-105
}

variable "lb_ip_offset_test" {
  type    = number
  default = 80
}

# ---- Ressources VM — Master+Worker ----

variable "mw_cores" {
  description = "Nombre de CPU pour Master+Worker"
  type        = number
  default     = 4
}

variable "mw_memory_mb" {
  description = "Mémoire (MB) pour Master+Worker"
  type        = number
  default     = 3072
}

variable "mw_disk_os_gb" {
  description = "Taille disque OS (GB) Master+Worker"
  type        = number
  default     = 40
}

variable "mw_disk_data_gb" {
  description = "Taille disque data (GB) pour Master+Worker"
  type        = number
  default     = 150
}

# ---- Ressources VM — Worker seul ----

variable "w_cores" {
  description = "Nombre de CPU pour Workers purs"
  type        = number
  default     = 4
}

variable "w_memory_mb" {
  description = "Mémoire (MB) pour Workers purs"
  type        = number
  default     = 3072
}

variable "w_disk_os_gb" {
  description = "Taille disque OS (GB) pour Workers purs"
  type        = number
  default     = 40
}

variable "w_disk_data_gb" {
  description = "Taille disque data (GB) pour Workers purs"
  type        = number
  default     = 150
}