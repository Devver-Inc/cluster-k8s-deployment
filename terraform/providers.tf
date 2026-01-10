terraform {
  required_providers {
    proxmox = {
      source  = "Telmate/proxmox"
      version = "3.0.2-rc07"
    }
  }
}

provider "proxmox" {
  pm_api_url        = var.proxmox_url
  pm_api_token_id   = var.proxmox_token_id
  pm_api_token      = var.proxmox_password
  pm_tls_insecure   = var.proxmox_tls_insecure
}
