#############################################
# CONFIGURATION MINIMALE — PROD
# Seules 3 variables obligatoires :
#
# 1. cluster_env: Environnement (prod, staging, dev, test)
# 2. master_worker_count: Nombre de nœuds Master+Worker (min 3)
# 3. worker_count: Nombre de nœuds Worker purs (facultatif)
# 4. vm_template_id: ID du template VM Proxmox à cloner
#
# Tous les autres paramètres (réseau, ressources, template name)
# sont définis dans variables-global.tf avec des valeurs par défaut.
#
# Les secrets sont fournis via variables d'environnement:
#   export TF_VAR_proxmox_api_token="root@pam!devver=xxxxxxxx..."
#   export TF_VAR_ssh_public_key="ssh-ed25519 AAAA... user@host"
#############################################

cluster_env         = "prod"
master_worker_count = 3
worker_count        = 1
vm_template_id      = 9000
storage             = "SSD-PVE-DATA"