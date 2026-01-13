terraform {
  required_providers {
    proxmox = {
      source  = "Telmate/proxmox"
      version = "3.0.2-rc05"
    }
  }
}

provider "proxmox" {
  pm_api_url            = var.proxmox_api_url

  # Support both API token and user/password authentication.
  # To use an API token, set `proxmox_api_token_id` to the token id
  # (example: 'terraform-prov@pve!mytoken') and `proxmox_api_token_secret`.
  pm_api_token_id       = var.proxmox_api_token_id
  pm_api_token_secret   = var.proxmox_api_token_secret

  pm_tls_insecure = true   # si certificat auto-signé
}
#