# devver-infra-deployment/proxmox : credentials API Proxmox, partagés entre toutes les orgs.
data "vault_kv_secret_v2" "proxmox" {
  mount = "devver-infra-deployment"
  name  = "proxmox"
}

# devver-infra-deployment/<org> : clé SSH / login VM, spécifiques à cette org.
# Créé automatiquement (copie de vm_secret_template) par vault/
# à la première apparition de cette org — ce Terraform-ci ne fait QUE lire, jamais
# écrire, donc aucune de ces valeurs n'atterrit dans son state.
data "vault_kv_secret_v2" "cluster_secrets" {
  mount = "devver-infra-deployment"
  name  = var.org
}
