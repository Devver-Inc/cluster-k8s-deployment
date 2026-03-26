output "ansible_inventory" {
  value = module.k8s_cluster.ansible_inventory
}

output "loadbalancer_ip" {
  value = module.k8s_cluster.lb_ip
}

output "provisioned_ips" {
  value = module.k8s_cluster.provisioned_ips
}

#############################################
# Génération des fichiers d'inventaire SANS RECRÉATION
# Utilise null_resource + local-exec pour mettre à jour
# les fichiers sans détruire/recréer la ressource
#############################################

resource "null_resource" "write_inventory_files" {
  triggers = {
    # Ne recalculer que si la topologie change (counts + env)
    # Pas basé sur ansible_inventory_ini pour éviter les mises à jour
    # inutiles des VMs existantes lors d'un scale in/out
    topology_hash = md5("${var.cluster_env}:${var.master_worker_count}:${var.worker_count}")
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      
      INVENTORY_DIR="${path.module}/inventory"
      mkdir -p "$INVENTORY_DIR"
      
      # Écrire les fichiers de manière atomique (tmp → mv)
      # Cela évite les problèmes d'accès si les fichiers sont lus en parallèle
      
      cat > "$INVENTORY_DIR/${var.cluster_env}-inventory.ini.tmp" << 'EOF'
${module.k8s_cluster.ansible_inventory_ini}
EOF
      mv "$INVENTORY_DIR/${var.cluster_env}-inventory.ini.tmp" "$INVENTORY_DIR/${var.cluster_env}-inventory.ini" 2>/dev/null || true
      
      cat > "$INVENTORY_DIR/${var.cluster_env}-inventory.json.tmp" << 'EOF'
${jsonencode(module.k8s_cluster.ansible_inventory)}
EOF
      mv "$INVENTORY_DIR/${var.cluster_env}-inventory.json.tmp" "$INVENTORY_DIR/${var.cluster_env}-inventory.json" 2>/dev/null || true
      
      cat > "$INVENTORY_DIR/${var.cluster_env}-cluster.yaml.tmp" << 'EOF'
cluster: DEVVER-K8S-${upper(var.cluster_env)}
env: ${var.cluster_env}
status: active
loadbalancer_ip: ${module.k8s_cluster.lb_ip}
provisioned_ips: ${jsonencode(module.k8s_cluster.provisioned_ips)}
master_worker_count: ${var.master_worker_count}
worker_count: ${var.worker_count}
mw_ip_base: ${module.k8s_cluster.mw_ip_base}
lb_ip_offset: ${module.k8s_cluster.lb_ip_offset}
EOF
      mv "$INVENTORY_DIR/${var.cluster_env}-cluster.yaml.tmp" "$INVENTORY_DIR/${var.cluster_env}-cluster.yaml" 2>/dev/null || true
      
      echo "✓ Inventaire mis à jour (ressource non-destructive)"
    EOT
  }
}