variable "vault_address" {
  description = "URL de l'API Vault"
  type        = string
  default     = "https://vault.devver.app"
}

variable "orgs" {
  description = "Organisations pour lesquelles créer une policy read-only + un role AppRole dédié"
  type        = list(string)
  default     = ["prod"]
}
