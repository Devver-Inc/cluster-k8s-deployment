variable "org" {
  description = "Nom de l'organisation (sans l'environnement) — ex: acme"
  type        = string
  # Pas de default volontairement : force à définir "org" dans values.auto.tfvars
  # (voir REPLACE_ME_ORG) pour ce nouveau cluster.

  validation {
    condition     = var.org != "REPLACE_ME_ORG"
    error_message = "Ce dossier est le TEMPLATE clusters/_template/ — remplacer REPLACE_ME_ORG par le vrai nom de l'org dans values.auto.tfvars (et backend.hcl) avant tout plan/apply. Voir clusters/_template/README.md."
  }

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?$", var.org))
    error_message = "org doit être en minuscules (a-z, 0-9, '-') — il sert de chemin Vault kubernetes-cluster/<org>/<env>/ et de nom de VM."
  }
}

variable "env" {
  description = "Environnement du cluster — chemin Vault kubernetes-cluster/<org>/<env>/"
  type        = string

  validation {
    condition     = contains(["prod", "staging", "dev"], var.env)
    error_message = "env doit valoir prod, staging ou dev (liste figée : terraform/vault/k8s-secrets.tf en déduit org/env depuis l'identifiant <org>-<env>)."
  }
}

variable "base_domain" {
  description = "Domaine de base : le cluster est servi sous <org>-<env>.<base_domain> (ex: acme-prod.devver.app)"
  type        = string
  default     = "devver.app"
}

variable "nfs_server" {
  description = "Serveur NFS (NAS) du stockage persistant du cluster"
  type        = string

  validation {
    condition     = can(regex("^[0-9]{1,3}(\\.[0-9]{1,3}){3}$", var.nfs_server)) || can(regex("^[a-z0-9.-]+$", var.nfs_server))
    error_message = "nfs_server doit être une IP ou un nom d'hôte."
  }
}

variable "nfs_share" {
  description = "Partage NFS DÉDIÉ à ce cluster (isolation : accès réservé aux IP de ses noeuds), à créer sur le NAS avant le déploiement — ex: /volume1/NFS_K8S_<ORG>_<ENV>"
  type        = string

  validation {
    condition     = startswith(var.nfs_share, "/") && var.nfs_share != "/volume1/NFS_K8S_DEVVER_PROD" && !strcontains(var.nfs_share, "REPLACE_ME")
    error_message = "nfs_share doit être un chemin absolu, propre à ce cluster (jamais le partage de la prod)."
  }
}

variable "kubernetes_git_revision" {
  description = "Révision (branche ou tag) du repo Devver-Inc/kubernetes que suit ArgoCD sur ce cluster"
  type        = string
  default     = "main"
}

variable "org_subnet_index" {
  description = "Registre centralisé { <org>-<env> => subnet_index }, injecté via le symlink ip-plan.auto.tfvars"
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
  description = "Secret ID AppRole (vault write -f auth/terraform-orgs/role/terraform-<org>-<env>/secret-id)"
  type        = string
  sensitive   = true
}

variable "proxmox_url" {
  type    = string
  default = "https://192.168.5.3:8006/"
}
