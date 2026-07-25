# 🚀 Quick Start - Déploiement avec BGP Provider

Guide rapide pour déployer après la refactorisation.

---

## 📋 Pre-requis (5 min)

```bash
# 1. Récupérer l'ID du template Proxmox
cd /home/victor/cluster-k8s-deployment/terraform/scripts
chmod +x find-template-id.sh
./find-template-id.sh

# Exemple de réponse:
# ✅ Template trouvé!
# Nom: debian13-cloudinit
# ID:  100
# 👉 Garder cette valeur: 100
```

---

## ⚙️ Configuration (2 min)

```bash
# 2. Mettre à jour terraform.tfvars
vim ../clusters/example-prod/terraform.tfvars

# Ajouter cette ligne (remplacer 100 par votre ID):
# vm_template_id = 100
```

---

## 🔑 Variables d'environnement (1 min)

```bash
# 3. Exporter les secrets (À FAIRE À CHAQUE SESSION)
export TF_VAR_proxmox_api_token_secret="your-token-secret"
export TF_VAR_ssh_public_key="ssh-ed25519 AAAA... user@host"

# Vérifier:
echo "Token: $TF_VAR_proxmox_api_token_secret"
echo "SSH key: $TF_VAR_ssh_public_key"
```

---

## 🔧 Initialisation (3 min)

```bash
# 4. Initialiser Terraform avec le nouveau provider
cd ../clusters
rm -rf .terraform .terraform.lock.hcl   # Nettoyer config ancienne
terraform init

# Attendre que le provider soit téléchargé...
# ✅ Done! (affichage qui confirme)
```

---

## 📊 Vérification (2 min)

```bash
# 5. Vérifier le plan (SANS appliquer)
terraform plan -var-file="example-prod/terraform.tfvars"

# Vérifier:
# - Aucune erreur de syntaxe
# - Plan montre les VM à créer
# - Exemple: "Plan: 2 to add, 0 to change, 0 to destroy"
```

---

## ✅ Déploiement (10-15 min)

```bash
# 6. Appliquer (créer les VMs)
terraform apply -var-file="example-prod/terraform.tfvars"

# À la fin, vous verrez:
# ✅ Apply complete! Resources: 3 added
```

---

## 🎯 Validation post-déploiement (5 min)

```bash
# 7. Afficher les IPs provisionnées
terraform output provisioned_ips

# Exemple de réponse:
# [
#   "192.168.45.110",
#   "192.168.45.111", 
#   "192.168.45.112",
#   "192.168.45.160",
#   "192.168.45.81"
# ]

# 8. Tester connectivité SSH à une VM
ssh -i ~/.ssh/id_ed25519 devver@192.168.45.110

# Commandes pour vérifier que tout est OK:
whoami                        # doit afficher: devver
hostname                      # doit afficher: DEVVER-K8S-PROD-MW-1
ip addr                       # doit afficher: 192.168.45.110
```

---

## 📝 Fichiers générés automatiquement

Après `terraform apply`, vous trouverez dans `inventory/`:

```bash
ls -la inventory/

# prod-inventory.ini      ← Pour Ansible
# prod-inventory.json     ← Format JSON
# prod-cluster.yaml       ← Metadata cluster
```

---

## 🚨 Troubleshooting rapide

**Erreur**: "API Token invalid"
```bash
# Vérifier le token:
echo $TF_VAR_proxmox_api_token_secret

# Doit correspondre à la variable globale dans variables-global.tf
# Ou votre propre token

# Solution: réexporter la variable
export TF_VAR_proxmox_api_token_secret="<votre-token-correct>"
```

**Erreur**: "vm_template_id: required"  
```bash
# Vous avez oublié de mettre vm_template_id dans terraform.tfvars
# Solution: éditer le fichier et ajouter:
# vm_template_id = 100  (remplacer 100 par votre ID)
```

**Erreur**: "Invalid resource name"  
```bash
# Vous avez peut-être une vieille configuration Telmate
# Solution:
rm -rf .terraform .terraform.lock.hcl
terraform init   # Retélécharger le bon provider
terraform plan   # Réessayer le plan
```

**VMs ne se créent pas**
```bash
# Vérifier les logs détaillés:
export TF_LOG=DEBUG
terraform apply -var-file="example-prod/terraform.tfvars" 2>&1 | head -50

# Cette sortie vous montrera l'erreur réelle
```

---

## 📊 Timing attendu

| Étape | Durée |
|-------|-------|
| Pre-requis (find template) | 5 min |
| Configuration | 2 min |
| Init Terraform | 3 min |
| Plan | 2 min |
| Deploy (create VMs) | 10-15 min |
| **TOTAL** | **~30-35 min** |

---

## ✨ Prochaines étapes (après ce guide)

1. **Appliquer le playbook Ansible** dans `cluster-k8s-deployment/ansible/`
   ```bash
   cd ../../ansible
   ansible-playbook -i ../terraform/clusters/inventory/prod-inventory.ini playbooks/site.yml
   ```

2. **Installer Kubespray** pour K8s:
   ```bash
   cd kubespray
   ansible-playbook -i inventory.ini cluster.yml
   ```

3. **Configurer ArgoCD** depuis `argocd-client-deployment/`

---

## 💾 Sauvegardes

Après `terraform apply`, sauvegarder:

```bash
# État Terraform
cp terraform.tfstate terraform.tfstate.prod.backup

# Inventory générée
cp inventory/prod-inventory.ini ../ansible/inventory/prod-inventory.ini.backup
```

---

## 📞 Aide supplémentaire

- **Erreurs Terraform**: Voir [MIGRATION_GUIDE_BGP.md](MIGRATION_GUIDE_BGP.md)
- **Détails techniques**: Voir [REFACTORING_SUMMARY.md](REFACTORING_SUMMARY.md)
- **Scripts disponibles**: Voir [scripts/README.md](scripts/README.md)

---

**⏱️ Estimé**: 30-35 minutes de votre temps pour avoir un cluster K8s prêt 🎯
