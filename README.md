# cluster-k8s-deployment

Déploiement d'un cluster Kubernetes HA sur Proxmox VE, combinant Terraform pour le provisionnement des VMs et Ansible pour la configuration post-installation.

## Architecture

- **3 nœuds** (master + workers) sur le réseau `192.168.45.0/24` (VLAN 45)
- Kubernetes déployé via **RKE2** (SUSE — remplace Kubespray depuis T3)
- Stockage persistant via **NFS CSI Driver** sur NAS externe (remplace Longhorn depuis T3)

## Structure du repo

```
cluster-k8s-deployment/
├── terraform/   # Provisionnement des VMs sur Proxmox
└── ansible/     # Configuration post-installation (DNS, NFS utils, kubectl)
```

## Flux de déploiement

```
1. terraform apply       → Crée les VMs sur Proxmox + génère l'inventaire Ansible
2. ansible post-install  → Configure DNS, installe nfs-common, kubectl
3. RKE2                  → Installe Kubernetes (via script officiel RKE2)
```

## Prérequis

- Proxmox VE avec un template cloud-init (Debian)
- Token API Proxmox : `TF_VAR_proxmox_api_token_secret`
- Clé SSH : `TF_VAR_ssh_public_key`
- NAS accessible depuis les nodes (pour NFS CSI)

## Démarrage rapide

```bash
# 1. Provisionner les VMs
cd terraform/clusters
terraform init
terraform apply -var-file="example-prod/terraform.tfvars"

# 2. Post-install Ansible
cd ../../ansible
ansible-playbook -i inventory.ini post-install-kubespray/all-nodes.yml
ansible-playbook -i inventory.ini post-install-kubespray/masters.yml
ansible-playbook -i inventory.ini post-install-kubespray/workers.yml
```

Voir [terraform/QUICKSTART.md](terraform/QUICKSTART.md) pour le guide détaillé Terraform.

## Évolutions

| Trimestre | Changement |
|---|---|
| T1/T2 | Kubespray + Longhorn |
| T3 | Migration vers RKE2 + NFS CSI Driver (NAS externe) |

> **Note** : Le refactoring Terraform (gestion des secrets via Vault) est prévu après finalisation de l'intégration Vault/Kubernetes.
