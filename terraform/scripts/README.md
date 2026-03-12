# Scripts Terraform Assistance

## 🆕 find-template-id.sh

Script interactif pour récupérer l'ID du template Proxmox à utiliser dans `terraform.tfvars`.

### Utilisation

```bash
chmod +x find-template-id.sh
./find-template-id.sh
```

### Provenance des données

Le script demande:
1. **URL Proxmox**: `https://192.168.5.3:8006`
2. **Token API ID**: `root@pam!devver`
3. **Token API Secret**: `your-token-here`
4. **Nœud Proxmox**: `PROXMOX-PVE1` (où se trouvent les templates)
5. **Nom du template**: `debian13-cloudinit` (ce qu'on cherche)

### Sortie

```
✅ Template trouvé!
Nom: debian13-cloudinit
ID:  100

Ajouter cette ligne dans terraform.tfvars:
vm_template_id = 100
```

### Dépannage

**Erreur**: "Template introuvable"
- Vérifier que le nom du template est exact (case-sensitive)
- S'assurer que le nœud Proxmox est correct
- Vérifier les credentials API

**Erreur**: "Connection refused"
- Vérifier l'URL Proxmox
- S'assurer que l'API REST est activée sur Proxmox

---

## 📚 new-cluster.sh

Script existant pour créer un nouveau cluster. Pas de modification nécessaire.

Utilisation:
```bash
./new-cluster.sh <env_name> <base_ip_4th_octet>
```

Exemple:
```bash
./new-cluster.sh staging 130
# Crée un dossier staging/ avec terraform.tfvars pré-configuré
```

---

## 🛠️ Commandes Terraform courantes

```bash
cd /home/victor/cluster-k8s-deployment/terraform/clusters

# Initialiser
terraform init

# Planifier (sans appliquer)
terraform plan -var-file="example-prod/terraform.tfvars"

# Appliquer les changements
terraform apply -var-file="example-prod/terraform.tfvars"

# Détruire l'infra
terraform destroy -var-file="example-prod/terraform.tfvars"

# Afficher les outputs
terraform output

# Debug
export TF_LOG=DEBUG
terraform apply -var-file="example-prod/terraform.tfvars"
```

---

## 📝 Variables d'environnement requises

```bash
# À exécuter avant toute commande terraform
export TF_VAR_proxmox_api_token_secret="<votre-token-secret>"
export TF_VAR_ssh_public_key="ssh-ed25519 AAAA... user@host"

# Optionnel: pour plus de debug
export TF_LOG=INFO   # ou DEBUG
```

---

## ✅ Étapes initiales (après refactoring)

1. Récupérer l'ID du template:
   ```bash
   ./find-template-id.sh
   ```

2. Mettre à jour `terraform.tfvars`:
   ```bash
   vim ../clusters/example-prod/terraform.tfvars
   # Ajouter la ligne: vm_template_id = 100
   ```

3. Initialiser Terraform:
   ```bash
   cd ../clusters
   terraform init
   ```

4. Tester le plan:
   ```bash
   terraform plan -var-file="example-prod/terraform.tfvars"
   ```

5. Appliquer si tout est OK:
   ```bash
   terraform apply -var-file="example-prod/terraform.tfvars"
   ```
