resource "local_file" "ansible_inventory" {
  filename = "${path.root}/generated/inventory-${var.org}.ini"
  content = templatefile("${path.module}/inventory.tpl", {
    org               = var.org
    vm_user           = var.vm_user
    mixed_nodes       = local.mixed_nodes
    worker_only_nodes = local.worker_only_nodes
    metallb_ip        = local.metallb_ip
  })
}

output "cluster_nodes" {
  description = "Map complète des noeuds (ip, vmid, hostname) du cluster"
  value       = local.all_nodes
}

output "metallb_ip" {
  description = "IP réservée pour MetalLB (dernière IP de la sous-plage de l'org)"
  value       = local.metallb_ip
}

output "ansible_inventory_path" {
  description = "Chemin de l'inventaire Ansible généré"
  value       = local_file.ansible_inventory.filename
}
