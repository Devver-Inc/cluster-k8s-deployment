terraform {
  required_version = ">= 1.5"

  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "~> 4.0"
    }
  }

  backend "s3" {}
}

# Authentification admin via VAULT_TOKEN en variable d'environnement
# (comportement par défaut du provider vault, pas de auth_login ici).
provider "vault" {
  address = var.vault_address
}
