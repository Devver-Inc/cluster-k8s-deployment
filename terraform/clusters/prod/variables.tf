variable "org" {
  type    = string
  default = "prod"
}

variable "org_subnet_index" {
  description = "Registre centralisé { org => subnet_index }, injecté via le symlink ip-plan.auto.tfvars"
  type        = map(number)
}

variable "node_count" {
  type = number
}

variable "additional_workers_count" {
  type    = number
  default = 0
}

variable "tags" {
  type    = list(string)
  default = []
}

variable "proxmox_node" {
  type = string
}

variable "datastore_id" {
  type = string
}

variable "template_name" {
  type    = string
  default = "rocky9-cloud-template"
}

variable "master_cpu_cores" {
  type    = number
  default = 4
}

variable "master_memory" {
  type    = number
  default = 6144
}

variable "master_disk_size" {
  type    = number
  default = 40
}

variable "worker_cpu_cores" {
  type    = number
  default = 4
}

variable "worker_memory" {
  type    = number
  default = 6144
}

variable "worker_disk_size" {
  type    = number
  default = 40
}

variable "worker_extra_disk_size" {
  type    = number
  default = 150
}

# Injectées via ip-plan.auto.tfvars (symlink vers ../../ip-plan.auto.tfvars)
variable "network_base" {
  type = string
}

variable "network_range_start" {
  type = number
}

variable "network_range_end" {
  type = number
}

variable "subnet_size" {
  type = number
}

variable "vault_address" {
  type    = string
  default = "https://vault.devver.app"
}

variable "vault_role_id" {
  description = "Role ID AppRole (fourni par vault/)"
  type        = string
  sensitive   = true
}

variable "vault_secret_id" {
  description = "Secret ID AppRole (vault write -f auth/terraform-orgs/role/terraform-prod/secret-id)"
  type        = string
  sensitive   = true
}

variable "proxmox_url" {
  type    = string
  default = "https://192.168.5.3:8006/"
}
