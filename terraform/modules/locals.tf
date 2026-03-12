terraform {
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
}

#############################################
# Locals : Calcul automatique des IPs par cluster_env
# Élimine le besoin de spécifier mw_ip_base et lb_ip_offset dans terraform.tfvars
#
# IPs MW : base_ip + index        (ex: .110, .111, .112)
# IPs W  : base_ip + 50 + index   (ex: .160, .161, .162)
# LB : lb_ip_offset               (ex: .81)
#############################################

locals {
  env_upper = upper(var.cluster_env)

  # Sélectionner mw_ip_base et lb_ip_offset selon cluster_env
  mw_ip_base = try({
    prod    = var.mw_ip_base_prod
    staging = var.mw_ip_base_staging
    dev     = var.mw_ip_base_dev
    test    = var.mw_ip_base_test
  }[var.cluster_env])

  lb_ip_offset = try({
    prod    = var.lb_ip_offset_prod
    staging = var.lb_ip_offset_staging
    dev     = var.lb_ip_offset_dev
    test    = var.lb_ip_offset_test
  }[var.cluster_env])

  # IPs MW : mw_ip_base + index (0-based)
  mw_nodes = {
    for idx in range(var.master_worker_count) :
    "${var.subnet}.${local.mw_ip_base + idx}" => {
      name  = "DEVVER-K8S-${local.env_upper}-MW-${idx + 1}"
      index = idx + 1
      ip    = "${var.subnet}.${local.mw_ip_base + idx}"
    }
  }

  # IPs W : mw_ip_base + 50 + index (plage séparée des MW)
  w_nodes = {
    for idx in range(var.worker_count) :
    "${var.subnet}.${local.mw_ip_base + 50 + idx}" => {
      name  = "DEVVER-K8S-${local.env_upper}-W-${idx + 1}"
      index = idx + 1
      ip    = "${var.subnet}.${local.mw_ip_base + 50 + idx}"
    }
  }

  lb_ip    = "${var.subnet}.${local.lb_ip_offset}"
  tag_base = "devver;K8s;${var.cluster_env}"
}