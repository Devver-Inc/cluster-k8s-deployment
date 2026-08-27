variable "org" {
  description = "Nom de l'organisation/environnement (ex: prod, preprod, orgaX)"
  type        = string
}

variable "network_base" {
  description = "Deux premiers octets du réseau /24 (ex: 192.168.45)"
  type        = string
  default     = "192.168.45"
}

variable "gateway" {
  description = "Gateway réseau des VMs"
  type        = string
  default     = "192.168.45.200"
}

variable "network_range_start" {
  description = "Début de la plage globale disponible pour tous les clusters (voir ip-plan.auto.tfvars)"
  type        = number
}

variable "network_range_end" {
  description = "Fin de la plage globale disponible pour tous les clusters (voir ip-plan.auto.tfvars)"
  type        = number
}

variable "subnet_size" {
  description = "Nombre d'IP réservées par org (noeuds + 1 IP MetalLB en dernière position), voir ip-plan.auto.tfvars"
  type        = number
}

variable "org_subnet_index" {
  description = "Registre centralisé { org => subnet_index } — voir ip-plan.auto.tfvars. Le module y lit l'index de var.org et valide qu'aucun doublon n'existe entre orgs."
  type        = map(number)

  validation {
    condition     = length(distinct(values(var.org_subnet_index))) == length(var.org_subnet_index)
    error_message = "Deux orgs partagent le même subnet_index dans org_subnet_index (ip-plan.auto.tfvars) — corriger avant de continuer, une collision d'IP serait sinon possible."
  }
}

variable "node_count" {
  description = "Nombre de noeuds master+worker (control-plane ET schedulable). Minimum 3."
  type        = number

  validation {
    condition     = var.node_count >= 3
    error_message = "node_count doit être >= 3 (minimum HA control-plane)."
  }
}

variable "additional_workers_count" {
  description = "Nombre de noeuds WORKER-ONLY supplémentaires, en plus des node_count master+worker"
  type        = number
  default     = 0
}

variable "tags" {
  description = "Tags supplémentaires appliqués à toutes les VMs de ce cluster (en plus de org/K8s/role)"
  type        = list(string)
  default     = []
}

variable "proxmox_node" {
  description = "Nom du noeud Proxmox cible"
  type        = string
}

variable "datastore_id" {
  description = "Datastore Proxmox pour disques et cloud-init"
  type        = string
}

variable "template_name" {
  description = "Nom du template VM Proxmox à cloner"
  type        = string
  default     = "rocky9-cloud-template"
}

variable "master_cpu_cores" {
  description = "Nombre de coeurs CPU pour les noeuds master+worker"
  type        = number
  default     = 4
}

variable "master_memory" {
  description = "RAM (Mo) pour les noeuds master+worker"
  type        = number
  default     = 6144
}

variable "master_disk_size" {
  description = "Taille du disque système (Go) pour les noeuds master+worker"
  type        = number
  default     = 40
}

variable "worker_cpu_cores" {
  description = "Nombre de coeurs CPU pour les noeuds worker-only"
  type        = number
  default     = 4
}

variable "worker_memory" {
  description = "RAM (Mo) pour les noeuds worker-only"
  type        = number
  default     = 6144
}

variable "worker_disk_size" {
  description = "Taille du disque système (Go) pour les noeuds worker-only"
  type        = number
  default     = 40
}

variable "worker_extra_disk_size" {
  description = "Taille du disque additionnel (Go) pour les noeuds worker-only, ex: stockage données"
  type        = number
  default     = 150
}

variable "vm_user" {
  description = "Utilisateur cloud-init des VMs (depuis Vault)"
  type        = string
  sensitive   = true
}

variable "ssh_public_key" {
  description = "Clé SSH publique injectée via cloud-init (depuis Vault)"
  type        = string
  sensitive   = true
}
