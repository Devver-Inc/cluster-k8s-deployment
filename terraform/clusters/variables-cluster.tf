#############################################
# Variables PAR CLUSTER — ESSENTIELLES SEULEMENT
# (Tous les autres paramètres ont des défauts dans variables-global.tf)
#############################################

variable "cluster_env" {
  description = "Environnement cluster: prod, staging, dev, test"
  type        = string
  
  validation {
    condition     = contains(["prod", "staging", "dev", "test"], var.cluster_env)
    error_message = "cluster_env doit être: prod, staging, dev ou test"
  }
}

variable "master_worker_count" {
  description = "Nombre de nœuds Master+Worker (minimum 3 pour HA)"
  type        = number
  default     = 3
  
  validation {
    condition     = var.master_worker_count >= 3
    error_message = "Minimum 3 nœuds Master+Worker requis pour Kubernetes HA"
  }
}

variable "worker_count" {
  description = "Nombre de nœuds Worker purs (facultatif)"
  type        = number
  default     = 0
}

# ---- Tags additionnels ----

variable "additional_tags" {
  description = "Tags additionnels à appliquer aux VMs (statiques, pas de modification au scale)"
  type        = list(string)
  default     = []
}