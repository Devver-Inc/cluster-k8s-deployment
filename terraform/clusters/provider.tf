terraform {
  required_version = ">= 1.14.7"

  required_providers {
    proxmox = {
      source  = "Telmate/proxmox"
      version = "3.0.2-rc07"
    }


    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }

  # ------------------------------------------------------------------
  # BACKEND LOCAL (par défaut)
  # ------------------------------------------------------------------
  backend "local" {}

  # ------------------------------------------------------------------
  # BACKEND S3 / MINIO (décommenter pour migrer)
  # terraform init -migrate-state
  #
  # backend "s3" {
  #   endpoint                    = "https://minio.devver.internal"
  #   bucket                      = "terraform-states"
  #   key                         = "k8s/${var.cluster_env}/terraform.tfstate"
  #   region                      = "us-east-1"
  #   skip_credentials_validation = true
  #   skip_metadata_api_check     = true
  #   skip_region_validation      = true
  #   force_path_style            = true
  # }
  # ------------------------------------------------------------------
}

provider "proxmox" {
  pm_api_url          = var.proxmox_api_url
  pm_api_token_id     = var.proxmox_api_token_id
  pm_api_token_secret = var.proxmox_api_token_secret
  pm_tls_insecure     = true
}
