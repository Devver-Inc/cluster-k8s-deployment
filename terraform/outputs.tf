output "master_ips" {
  value = local.master_ips
}

output "worker_ips" {
  value = local.worker_ips
}

output "kubespray_inventory_path" {
  value = local_file.kubespray_inventory.filename
}
