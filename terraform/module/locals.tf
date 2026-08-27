locals {
  # subnet_index lu depuis le registre centralisé org_subnet_index (ip-plan.auto.tfvars) —
  # jamais saisi en dur par cluster, impossible d'oublier de l'incrémenter puisqu'il n'y a
  # qu'un seul endroit où il est écrit.
  subnet_index = var.org_subnet_index[var.org]

  # Sous-plage dérivée de subnet_index — aucune borne saisie à la main par org.
  subnet_start = var.network_range_start + local.subnet_index * var.subnet_size
  subnet_end   = local.subnet_start + var.subnet_size - 1

  mixed_indices       = range(var.node_count)
  worker_only_indices = range(var.node_count, var.node_count + var.additional_workers_count)
  total_nodes         = var.node_count + var.additional_workers_count

  ip_for_index = { for idx in range(local.total_nodes) :
    idx => "${var.network_base}.${local.subnet_start + idx}"
  }

  mixed_nodes = { for idx in local.mixed_indices :
    "master-${idx + 1}" => {
      ip       = local.ip_for_index[idx]
      vmid     = tonumber("${split(".", local.ip_for_index[idx])[2]}${split(".", local.ip_for_index[idx])[3]}")
      hostname = "devver-k8s-${lower(var.org)}-mw-${idx + 1}"
    }
  }

  worker_only_nodes = { for i, idx in local.worker_only_indices :
    "worker-${i + 1}" => {
      ip       = local.ip_for_index[idx]
      vmid     = tonumber("${split(".", local.ip_for_index[idx])[2]}${split(".", local.ip_for_index[idx])[3]}")
      hostname = "devver-k8s-${lower(var.org)}-w-${i + 1}"
    }
  }

  all_nodes = merge(local.mixed_nodes, local.worker_only_nodes)

  # IP MetalLB = dernière IP de la sous-plage dérivée (jamais assignée à un noeud).
  metallb_ip      = "${var.network_base}.${local.subnet_end}"
  last_node_octet = local.subnet_start + local.total_nodes - 1
}

check "nodes_fit_in_subnet" {
  assert {
    condition     = local.last_node_octet < local.subnet_end
    error_message = "Le nombre de noeuds (${local.total_nodes}) déborde sur l'IP MetalLB réservée en fin de sous-plage (.${local.subnet_end}) — réduire node_count/additional_workers_count ou augmenter subnet_size dans ip-plan.auto.tfvars."
  }
}

check "subnet_within_global_range" {
  assert {
    condition     = local.subnet_end <= var.network_range_end
    error_message = "La sous-plage de l'org '${var.org}' (jusqu'à .${local.subnet_end}) déborde de la plage globale (jusqu'à .${var.network_range_end}) — vérifier subnet_index/subnet_size dans ip-plan.auto.tfvars."
  }
}
