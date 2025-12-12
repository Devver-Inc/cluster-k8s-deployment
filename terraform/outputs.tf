
output "masters_ips" {
  value = local.masters_ips
}

output "workers_ips" {
  value = local.workers_ips
}

output "inventory" {
  value = "../ansible/inventory/cluster1/hosts.yaml"
}
