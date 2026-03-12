# Refactorisation Terraform : Telmate → Provider BGP Proxmox

## 📊 Vue d'ensemble

Refactorisation complète de l'infrastructure Terraform pour passer du provider **Telmate/proxmox** (community) au **provider Proxmox officiel** avec support BGP natif.

**Statut**: ✅ Refactorisation complète terminée

## 📁 Structure du projet

```
terraform/
├── clusters/                      # Configuration par cluster
│   ├── provider.tf               # 🔄 MODIFIÉ - Provider BGP
│   ├── main.tf                   # 🔄 MODIFIÉ - Passage vm_template_id
│   ├── variables-global.tf       # Variables globales (réseau, auth)
│   ├── variables-cluster.tf      # 🔄 MODIFIÉ - Ajout vm_template_id
│   ├── outputs.tf                # Outputs (inventory, IPs)
│   ├── terraform.tfstate         # ⚠️ À regénérer
│   ├── .terraform.lock.hcl       # 🔄 À regénérer
│   └── inventory/                # Outputs générés (Ansible inventory)
│
├── modules/
│   ├── locals.tf                 # 🔄 MODIFIÉ - Provider BGP
│   ├── main.tf                   # 🔄 MODIFIÉ - Ressources VM refactorisées
│   ├── variables.tf              # 🔄 MODIFIÉ - Ajout vm_template_id
│   ├── outputs.tf                # Outputs du module (inchangé)
│   └── .terraform.lock.hcl       # 🔄 À regénérer
│
├── scripts/
│   ├── new-cluster.sh            # Script création cluster
│   └── find-template-id.sh       # 🆕 NOUVEAU - Trouver ID du template
│
├── MIGRATION_GUIDE_BGP.md        # 📋 Ce document
└── example-prod/
    └── terraform.tfvars          # 🔄 MODIFIÉ - Exécution prod
```

## 🔄 Fichiers modifiés - Détail des changements

### 1️⃣ `clusters/provider.tf`

**Changement**: Configuration du provider

```hcl
# AVANT (Telmate)
required_providers {
  proxmox = {
    source  = "Telmate/proxmox"
    version = "3.0.2-rc07"
  }
}

provider "proxmox" {
  pm_api_url          = var.proxmox_api_url
  pm_api_token_id     = var.proxmox_api_token_id
  pm_api_token_secret = var.proxmox_api_token_secret
  pm_tls_insecure     = true
}

# APRÈS (Proxmox Officiel)
required_providers {
  proxmox = {
    source  = "proxmox/proxmox"
    version = "~> 0.67"
  }
}

provider "proxmox" {
  endpoint = var.proxmox_api_url
  api_token = "${var.proxmox_api_token_id}=${var.proxmox_api_token_secret}"
  insecure = true
}
```

### 2️⃣ `modules/main.tf`

**Changement**: Ressources VM

```hcl
# AVANT
resource "proxmox_vm_qemu" "master_worker" {
  vmid        = tonumber(...)
  target_node = var.target_node
  agent       = 1
  clone       = var.vm_template
  ipconfig0   = "ip=${each.value.ip}/24,gw=${var.gateway}"
  tags        = "${local.tag_base};master-worker"
}

# APRÈS
resource "proxmox_virtual_environment_vm" "master_worker" {
  vm_id       = tonumber(...)
  node_name   = var.target_node
  agent { enabled = true }
  clone { vm_id = var.vm_template_id }
  initialization {
    ip_config {
      ipv4 {
        address = "${each.value.ip}/24"
        gateway = var.gateway
      }
    }
  }
  tags = ["${local.tag_base}", "master-worker"]
}
```

**Détails des changements**:
- ✅ `proxmox_vm_qemu` → `proxmox_virtual_environment_vm`
- ✅ `vmid` → `vm_id`
- ✅ `target_node` → `node_name`
- ✅ `clone = string` → `clone { vm_id = number }`
- ✅ `ipconfig0 = "string"` → `initialization { ip_config { ipv4 { ... } } }`
- ✅ `tags = string` → `tags = list`
- ✅ Disques: `disks.scsi.scsi0` → `disk { interface = "scsi0" }`

### 3️⃣ `clusters/variables-cluster.tf`

**Ajout de variable**:
```hcl
variable "vm_template_id" {
  description = "ID numérique du template VM à cloner pour le provider officiel Proxmox"
  type        = number
}
```

### 4️⃣ `modules/variables.tf`

**Mise à jour**:
```hcl
# AVANT
variable "vm_template" {
  type = string
}

# APRÈS
variable "vm_template" {
  type = string
}

variable "vm_template_id" {
  description = "ID numérique du template VM Proxmox (ex: 100)"
  type        = number
}
```

### 5️⃣ `modules/locals.tf`

**Mise à jour provider**:
```hcl
# AVANT
source  = "telmate/proxmox"
version = "3.0.2-rc07"

# APRÈS
source  = "proxmox/proxmox"
version = "~> 0.67"
```

### 6️⃣ `clusters/main.tf`

**Passage de variable au module**:
```hcl
module "k8s_cluster" {
  source = "../modules"
  
  # ... autres variables ...
  
  # NOUVEAU
  vm_template_id  = var.vm_template_id
}
```

### 7️⃣ `clusters/example-prod/terraform.tfvars`

**Mise à jour exemple**:
```hcl
# Pour prod au lieu de test
cluster_env         = "prod"
mw_ip_base   = 110
lb_ip_offset = 81

# NOUVEAU - À adapter à votre template
vm_template_id = 100
```

## 🚀 Étapes de déploiement

### Étape 1: Récupérer l'ID du template

```bash
cd /home/victor/cluster-k8s-deployment/terraform

# Rendre le script exécutable
chmod +x scripts/find-template-id.sh

# Exécuter pour trouver l'ID
./scripts/find-template-id.sh
```

Exemple de sortie:
```
✅ Template trouvé!
Nom: debian13-cloudinit
ID:  100

Ajouter cette ligne dans terraform.tfvars:
vm_template_id = 100
```

### Étape 2: Mettre à jour terraform.tfvars

```bash
# Éditer le fichier correspondant
vim clusters/example-prod/terraform.tfvars

# Exemple contenu:
# cluster_env = "prod"
# vm_template_id = 100
```

### Étape 3: Réinitialiser Terraform

```bash
cd /home/victor/cluster-k8s-deployment/terraform/clusters

# ⚠️ IMPORTANT: Supprimer l'ancien état (incompatible)
rm -f .terraform.lock.hcl .terraform/
# ou pour aussi supprimer les VMs existantes:
# terraform destroy -auto-approve

# Initialiser avec le nouveau provider
terraform init

# Planifier
terraform plan -var-file="example-prod/terraform.tfvars"

# Appliquer
terraform apply -var-file="example-prod/terraform.tfvars"
```

### Étape 4: Variables d'environnement

Avant d'exécuter terraform:
```bash
export TF_VAR_proxmox_api_token_secret="<votre-token>"
export TF_VAR_ssh_public_key="ssh-ed25519 AAAA..."

# Vérifier
echo $TF_VAR_proxmox_api_token_secret
```

## 📋 Checklist migrage

- [ ] Récupérer l'ID du template via `find-template-id.sh`
- [ ] Mettre à jour `terraform.tfvars` avec `vm_template_id`
- [ ] Sauvegarder l'ancien état: `cp terraform.tfstate terraform.tfstate.backup.telmate`
- [ ] Supprimer `.terraform.lock.hcl`: `rm -f .terraform.lock.hcl`
- [ ] Exécuter `terraform init` pour télécharger le nouveau provider
- [ ] Tester avec `terraform plan` sur un cluster TEST d'abord
- [ ] Une fois validé, appliquer sur PROD: `terraform apply`
- [ ] Vérifier les outputs (IPs, inventory)
- [ ] Tester la connectivité SSH aux VMs

## ⚠️ Points critiques

### 1. **Reconstruction d'état Terraform**
L'état Terraform (`terraform.tfstate`) n'est **pas réutilisable**. 

**Deux options**:

**Option A** (Plus sûr - recommandé):
```bash
# Détruire les anciennes VMs
terraform destroy -var-file="example-prod/terraform.tfvars"

# Supprimer l'état
rm -f terraform.tfstate*

# Recréer tout
terraform init && terraform apply
```

**Option B** (Migration avec import):
```bash
# Garder les VMs, recréer l'état
terraform state rm module.k8s_cluster.proxmox_vm_qemu
# Puis importer avec le nouveau provider
# ⚠️ Complexe, pas recommandé
```

### 2. **ID du template**
Le premier point de blocage: obtenir l'**ID numérique** du template.

```bash
# Via API (dans le script fourni)
curl -k -H "Authorization: PveAPIToken=root@pam!devver=<token>" \
  https://192.168.5.3:8006/api2/json/nodes/PROXMOX-PVE1/qemu | jq .

# Via Web UI: Données Center → VMID affiché en haut à gauche
```

### 3. **Variables d'environnement**
Toujours définir avant d'exécuter terraform:
```bash
export TF_VAR_proxmox_api_token_secret="..."
export TF_VAR_ssh_public_key="..."
```

### 4. **Initialisation cloud-init**
La syntaxe est différente mais les résultats attendus (hostname, IP, SSH keys) restent identiques.

## 🔍 Validations après déploiement

```bash
# Vérifier les IPs provisionnées
terraform output provisioned_ips

# Vérifier l'inventory Ansible généré
cat inventory/<env>-inventory.ini

# Tester connectivité
ssh -i ~/.ssh/id_ed25519 devver@192.168.45.110

# Vérifier sur Proxmox
pvesh get /nodes/PROXMOX-PVE1/qemu
```

## 📚 Ressources

- [Documentation Provider Proxmox](https://registry.terraform.io/providers/proxmox/proxmox/latest/docs)
- [Ressource VM Documentation](https://registry.terraform.io/providers/proxmox/proxmox/latest/docs/resources/virtual_environment_vm)
- [Proxmox Forum](https://forum.proxmox.com)

## 🤝 Support

En cas de problème:
1. Vérifier les logs: `terraform logs`
2. Activer debug: `export TF_LOG=DEBUG`
3. Consulter les guides cloud-init pour la syntaxe d'initialisation
4. Vérifier que l'ID du template est correct

---

**Refactorisation complétée**: Mars 2026 ✅
