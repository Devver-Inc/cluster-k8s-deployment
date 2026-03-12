#############################################
# DEVVER-K8S-TEST
# Seuls ces paramètres sont obligatoires.
#
# Secrets via variables d'environnement :
#   export TF_VAR_proxmox_api_token_secret="..."
#   export TF_VAR_ssh_public_key="ssh-ed25519 AAAA..."
#############################################

cluster_env         = "test"
master_worker_count = 3
worker_count        = 1

# Plage de ce cluster (choisir un mw_ip_base différent par cluster)
# MW : 192.168.45.100, .101, .102
# W  : 192.168.45.150, .151... (mw_ip_base + 50)
# LB : 192.168.45.80
mw_ip_base   = 100
lb_ip_offset = 80