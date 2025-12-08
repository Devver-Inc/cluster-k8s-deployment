#############################################
# Variables globales
#############################################

#variable "proxmox_api_url" {"https://192.168.5.3:8006/api2/json"}

variable "proxmox_api_url" {
  default = "https://192.168.5.3:8006/api2/json"
}

variable "proxmox_api_token_id" {
  default = "root@pam"
}

variable "proxmox_api_token_secret" {
  default = ""
}


# Proxmox node
variable "target_node" {
  default = "PROXMOX-PVE1"
}

# Liste des IP MASTER (chargées via masters_list.tfvars)
variable "master_ips" {
  type = list(string)
}

# Liste des IP WORKER (chargées via workers_list.tfvars)
variable "worker_ips" {
  type = list(string)
}
