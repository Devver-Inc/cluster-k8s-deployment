variable "vault_address" {
  description = "URL de l'API Vault"
  type        = string
  default     = "https://vault.devver.app"
}

variable "orgs" {
  description = "Identifiants de cluster (<org>-<env>, ou anciens noms sans env) : policy read-only + role AppRole infra pour chacun, et structure kubernetes-cluster/ (k8s-secrets.tf) pour ceux au format <org>-<prod|staging|dev>"
  type        = list(string)
  default     = ["prod"]
}
