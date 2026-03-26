#############################################
# Outputs du module k8s-cluster
#############################################

output "ansible_inventory" {
  value = {
    cluster_env    = var.cluster_env
    master_workers = [
      for ip, node in local.mw_nodes : {
        name         = node.name
        ip           = node.ip
        ansible_user = var.vm_user
        role         = "master-worker"
      }
    ]
    workers = [
      for ip, node in local.w_nodes : {
        name         = node.name
        ip           = node.ip
        ansible_user = var.vm_user
        role         = "worker"
      }
    ]
  }
}

output "ansible_inventory_ini" {
  value = <<-INI
    # Généré automatiquement par Terraform
    # Cluster : DEVVER-K8S-${upper(var.cluster_env)}

    [kube_control_plane]
    ${join("\n", [for ip, node in local.mw_nodes : "${node.name} ansible_host=${node.ip} ansible_user=${var.vm_user}"])}

    [kube_node]
    ${join("\n", [for ip, node in local.mw_nodes : "${node.name} ansible_host=${node.ip} ansible_user=${var.vm_user}"])}
    ${join("\n", [for ip, node in local.w_nodes : "${node.name} ansible_host=${node.ip} ansible_user=${var.vm_user}"])}

    [etcd]
    ${join("\n", [for ip, node in local.mw_nodes : "${node.name} ansible_host=${node.ip} ansible_user=${var.vm_user}"])}

    [k8s_cluster:children]
    kube_control_plane
    kube_node
  INI
}

output "lb_ip" {
  value = local.lb_ip
}

output "provisioned_ips" {
  value = concat(
    [for ip, node in local.mw_nodes : ip],
    [for ip, node in local.w_nodes : ip],
    [local.lb_ip]
  )
}

output "mw_ip_base" {
  value = local.mw_ip_base
}

output "lb_ip_offset" {
  value = local.lb_ip_offset
}