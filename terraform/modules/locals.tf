terraform {
  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "3.0.2-rc07"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

#############################################
# Locals : IPs déterministes par index
# MW : base_ip + index        (ex: .100, .101, .102)
# W  : base_ip + 50 + index   (ex: .150, .151, .152)
# LB : lb_ip_start            (ex: .80)
# Garantit qu'un nœud existant garde toujours
# la même IP quoi qu'il arrive sur les autres clusters.
#############################################

locals {
  env_upper = upper(var.cluster_env)

  # IPs MW : mw_ip_base + index (0-based)
  mw_nodes = {
    for idx in range(var.master_worker_count) :
    "${var.subnet}.${var.mw_ip_base + idx}" => {
      name  = "DEVVER-K8S-${local.env_upper}-MW-${idx + 1}"
      index = idx + 1
      ip    = "${var.subnet}.${var.mw_ip_base + idx}"
    }
  }

  # IPs W : mw_ip_base + 50 + index (plage séparée des MW)
  w_nodes = {
    for idx in range(var.worker_count) :
    "${var.subnet}.${var.mw_ip_base + 50 + idx}" => {
      name  = "DEVVER-K8S-${local.env_upper}-W-${idx + 1}"
      index = idx + 1
      ip    = "${var.subnet}.${var.mw_ip_base + 50 + idx}"
    }
  }

  lb_ip    = "${var.subnet}.${var.lb_ip_offset}"
  tag_base = "devver;K8s;${var.cluster_env}"
}