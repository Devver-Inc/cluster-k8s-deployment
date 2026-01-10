data "external" "ip_allocator" {
  program = ["python3", "${path.module}/scripts/compute_ips.py"]
  query = {
    master_range_start   = var.master_range_start
    master_range_end     = var.master_range_end
    worker_range_start   = var.worker_range_start
    worker_range_end     = var.worker_range_end
    master_count         = tostring(var.master_count)
    worker_count         = tostring(var.worker_count)
    allocated_ips_path   = var.allocated_ips_path
  }
}

locals {
  master_ips = jsondecode(data.external.ip_allocator.result.master_ips)
  worker_ips = jsondecode(data.external.ip_allocator.result.worker_ips)
}

resource "local_file" "kubespray_inventory" {
  content = join("\n", concat(
    ["[kube_control_plane]"],
    [for ip in local.master_ips : "${""}master-" + replace(ip, ".", "-") + " ansible_host=${ip} ansible_user=user ansible_become=True"],
    ["", "[etcd]"],
    [for ip in local.master_ips : "master-" + replace(ip, ".", "-") + " ansible_host=${ip} ansible_user=user ansible_become=True"],
    ["", "[kube_node]"],
    [for ip in concat(local.master_ips, local.worker_ips) : "node-" + replace(ip, ".", "-") + " ansible_host=${ip} ansible_user=user ansible_become=True"],
    ["", "[k8s_cluster:children]", "kube_control_plane", "kube_node"]
  ))
  filename = "${path.module}/generated_hosts.ini"
}

resource "local_file" "allocated_ips" {
  content  = jsonencode({ master_ips = local.master_ips, worker_ips = local.worker_ips })
  filename = var.allocated_ips_path
}
