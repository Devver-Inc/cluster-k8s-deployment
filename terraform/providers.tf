terraform {
  required_providers {
    proxmox = {
      source  = "Telmate/proxmox"
      version = "3.0.2-rc05"
    }
  }
}

provider "proxmox" {
  pm_api_url          = var.proxmox_api_url
  pm_user     = var.proxmox_api_token_id
  pm_password = var.proxmox_api_token_secret
  pm_tls_insecure = true   # si certificat auto-signé
}
#