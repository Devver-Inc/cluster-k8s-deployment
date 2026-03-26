# Guide de Migration : Telmate → Provider BGP Proxmox Officiel

## 📋 Résumé des changements

Migration de `Telmate/proxmox` (v3.0.2-rc07) vers le **provider officiel Proxmox** (`proxmox/proxmox` v~0.67)

## 🔄 Changements principaux

### 1. **Provider Source**
- Avant: `Telmate/proxmox`
- Après: `proxmox/proxmox` (officiel BGP)

### 2. **Configuration du Provider**
```hcl
# 🔴 Ancien (Telmate)
provider "proxmox" {
  pm_api_url          = var.proxmox_api_url
  pm_api_token_id     = var.proxmox_api_token_id
  pm_api_token_secret = var.proxmox_api_token_secret
  pm_tls_insecure     = true
}

# 🟢 Nouveau (Officiel)
provider "proxmox" {
  endpoint = var.proxmox_api_url
  api_token = "${var.proxmox_api_token_id}=${var.proxmox_api_token_secret}"
  insecure = true
}
```

### 3. **Ressources VM**
- Avant: `proxmox_vm_qemu`
- Après: `proxmox_virtual_environment_vm`

### 4. **Attributs clés changés**

| Telmate | Officiel | Notes |
|---------|----------|-------|
| `vmid` | `vm_id` | ID de la VM |
| `target_node` | `node_name` | Nœud Proxmox |
| `clone` (string) | `clone {vm_id = ...}` | Structure bloc |
| `agent` (1/0) | `agent {enabled = true}` | Structure bloc |
| `vm_state = "running"` | `started = true` | Booléen |
| `memory` (int) | `memory {dedicated = ...}` | Structure bloc |
| `ipconfig0` | `initialization {ip_config {...}}` | Cloud-init moderne |
| `sshkeys` | `user_account {keys = [...]}` | Structure bloc |
| `tags` (string) | `tags` (list) | Liste au lieu de string |

### 5. **Nouvelle variable requise**

```hcl
variable "vm_template_id" {
  description = "ID numérique du template VM à cloner (Proxmox officiel)"
  type        = number
}
```

**Important**: Vous devez connaître l'**ID numérique** de votre template Debian 13 dans Proxmox.
- Exemple: Si le template a VMID=100, utiliser `vm_template_id = 100`

## 🚀 Fichiers modifiés

1. **clusters/provider.tf** ✅
   - Configuration provider mise à jour

2. **modules/locals.tf** ✅
   - Déclaration provider mise à jour

3. **modules/main.tf** ✅
   - Ressources `proxmox_vm_qemu` → `proxmox_virtual_environment_vm`
   - Syntaxe des disques: `scsi0`, `scsi1` avec `interface`
   - Syntaxe du réseau: `network_device {bridge, vlan_id}`
   - Cloud-init: format `initialization {ip_config {...}}`

4. **modules/variables.tf** ✅
   - Ajout: `vm_template_id`

5. **clusters/variables-cluster.tf** ✅
   - Ajout: `vm_template_id`

6. **clusters/main.tf** ✅
   - Passage de `vm_template_id` au module

7. **clusters/example-prod/terraform.tfvars** ✅
   - Exemple: `vm_template_id = 100`

## ⚠️ Points importants

### Stockage des états
- Les fichiers `terraform.tfstate` et `.terraform.lock.hcl` sont **incompatibles**
- Nouvelles ressources seront créées lors du `terraform apply`
- **Action recommandée**: 
  ```bash
  # Détruire les anciennes VMs (optionnel mais sûr)
  terraform destroy
  
  # Initialiser le nouveau provider
  terraform init
  
  # Planifier et appliquer
  terraform plan
  terraform apply
  ```

### Différences de comportement

1. **IDs de VM restent identiques** (calculés via l'IP)
2. **Agent Proxmox**: Le nouveau provider gère mieux l'intégration QEMU
3. **Cloud-init**: Syntaxe plus moderne et compatible

## 📝 Checklist avant déploiement

- [ ] Récupérer l'ID numérique du template Proxmox
  ```bash
  # Dans l'interface Proxmox ou via API
  curl -k -H "Authorization: PveAPIToken=<token>" \
    https://<proxmox>:8006/api2/json/nodes/<node>/qemu \
    | grep -A5 "debian13-cloudinit"
  ```

- [ ] Mettre à jour `terraform.tfvars` avec le bon `vm_template_id`

- [ ] Exécuter `terraform init` pour télécharger le nouveau provider

- [ ] Tester avec `terraform plan` sur un cluster de test

- [ ] Valider que les outputs (IPs, inventory) sont corrects

## 🔗 Liens utiles

- [Documentation Provider Proxmox Officiel](https://registry.terraform.io/providers/proxmox/proxmox/latest/docs)
- [Ressource VM](https://registry.terraform.io/providers/proxmox/proxmox/latest/docs/resources/virtual_environment_vm)
- [Forum Proxmox Terraform](https://forum.proxmox.com)

## 🎯 Avantages du provider officiel

✅ Support maintenu par Proxmox directement  
✅ Compatibilité avec les futures versions  
✅ Meilleure documentation  
✅ API plus stable et cohérente  
✅ Support du BGP natif pour les IPs virtuelles  
