#############################################
# Variables GLOBALES — authentification et réseau
# Identiques pour tous les clusters.
#############################################

# ---- Authentification Proxmox ----

variable "proxmox_api_url" {
  type    = string
  default = "https://192.168.5.3:8006/api2/json"
}

variable "proxmox_api_token_id" {
  type    = string
  default = "root@pam!devver"
}

variable "proxmox_api_token_secret" {
  type      = string
  sensitive = true
  default   = "your-token-here"
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