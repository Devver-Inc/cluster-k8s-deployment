output "ansible_inventory" {
  value = module.k8s_cluster.ansible_inventory
}

output "loadbalancer_ip" {
  value = module.k8s_cluster.lb_ip
}

output "provisioned_ips" {
  value = module.k8s_cluster.provisioned_ips
}

resource "local_file" "inventory_ini" {
  content  = module.k8s_cluster.ansible_inventory_ini
  filename = "${path.module}/inventory/${var.cluster_env}-inventory.ini"
}

resource "local_file" "inventory_json" {
  content  = jsonencode(module.k8s_cluster.ansible_inventory)
  filename = "${path.module}/inventory/${var.cluster_env}-inventory.json"
}

resource "local_file" "cluster_yaml" {
  filename = "${path.module}/inventory/${var.cluster_env}-cluster.yaml"
  content  = <<-YAML
    cluster: DEVVER-K8S-${upper(var.cluster_env)}
    env: ${var.cluster_env}
    status: active
    loadbalancer_ip: ${module.k8s_cluster.lb_ip}
    provisioned_ips: ${jsonencode(module.k8s_cluster.provisioned_ips)}
    master_worker_count: ${var.master_worker_count}
    worker_count: ${var.worker_count}
    mw_ip_base: ${var.mw_ip_base}
    lb_ip_offset: ${var.lb_ip_offset}
  YAML
}