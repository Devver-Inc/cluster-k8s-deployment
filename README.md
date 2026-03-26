# cluster-k8s-deployment

Déploiement d'un cluster Kubernetes HA sur Proxmox VE, combinant Terraform pour le provisionnement des VMs et Ansible pour la configuration post-installation.

## Architecture

- **1 master** + **3 workers** sur le réseau `192.168.45.0/24` (VLAN 45)
- Stockage distribué via **Longhorn** (disque secondaire sur chaque worker)
- Kubernetes déployé via **Kubespray**

## Structure du repo

```
cluster-k8s-deployment/
├── terraform/   # Provisionnement des VMs sur Proxmox
└── ansible/     # Configuration post-installation et déploiement K8s
```

## Flux de déploiement

```
1. terraform apply       → Crée les VMs sur Proxmox + génère l'inventaire Ansible
2. ansible post-install  → Configure DNS, stockage, kubectl
3. kubespray             → Installe Kubernetes
```

## Prérequis

- Proxmox VE avec un template cloud-init (Debian)
- Token API Proxmox : `TF_VAR_proxmox_api_token_secret`
- Clé SSH : `TF_VAR_ssh_public_key`

## Démarrage rapide

```bash
# 1. Provisionner les VMs
cd terraform/clusters
terraform init
terraform apply -var-file="example-prod/terraform.tfvars"

# 2. Post-install Ansible
cd ../../ansible
ansible-playbook -i ../terraform/clusters/inventory/prod-inventory.ini post-install-kubespray/all-nodes.yml
ansible-playbook -i ../terraform/clusters/inventory/prod-inventory.ini post-install-kubespray/masters.yml
ansible-playbook -i ../terraform/clusters/inventory/prod-inventory.ini post-install-kubespray/workers.yml

# 3. Déployer Kubernetes via Kubespray
cd kubespray
ansible-playbook -i ../inventory.ini cluster.yml
```

Voir [terraform/QUICKSTART.md](terraform/QUICKSTART.md) pour le guide détaillé Terraform.
