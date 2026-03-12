terraform {
  required_version = ">= 1.14.7"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.65"
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
  endpoint = var.proxmox_api_url
  api_token = var.proxmox_api_token
  insecure = true
}
