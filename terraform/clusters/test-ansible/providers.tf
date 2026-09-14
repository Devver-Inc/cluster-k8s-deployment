terraform {
  required_version = ">= 1.5"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.73"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "~> 4.0"
    }
  }

  backend "s3" {}
}

provider "vault" {
  address = var.vault_address

  auth_login {
    path = "auth/terraform-orgs/login"

    parameters = {
      role_id   = var.vault_role_id
      secret_id = var.vault_secret_id
    }
  }
}

provider "proxmox" {
  endpoint  = var.proxmox_url
  api_token = "${data.vault_kv_secret_v2.proxmox.data["token_id"]}=${data.vault_kv_secret_v2.proxmox.data["token_secret"]}"
  insecure  = true
}

module "cluster" {
  source = "../../module"

  org                      = var.org
  network_base             = var.network_base
  network_range_start      = var.network_range_start
  network_range_end        = var.network_range_end
  subnet_size              = var.subnet_size
  org_subnet_index         = var.org_subnet_index
  node_count               = var.node_count
  additional_workers_count = var.additional_workers_count
  tags                     = var.tags

  proxmox_node  = var.proxmox_node
  datastore_id  = var.datastore_id
  template_name = var.template_name

  master_cpu_cores = var.master_cpu_cores
  master_memory    = var.master_memory
  master_disk_size = var.master_disk_size

  worker_cpu_cores       = var.worker_cpu_cores
  worker_memory          = var.worker_memory
  worker_disk_size       = var.worker_disk_size
  worker_extra_disk_size = var.worker_extra_disk_size

  vm_user        = data.vault_kv_secret_v2.cluster_secrets.data["vm_user"]
  ssh_public_key = data.vault_kv_secret_v2.cluster_secrets.data["ssh_public_key"]
}

output "cluster_nodes" {
  value = module.cluster.cluster_nodes
}

output "metallb_ip" {
  value = module.cluster.metallb_ip
}

output "ansible_inventory_path" {
  value = module.cluster.ansible_inventory_path
}
