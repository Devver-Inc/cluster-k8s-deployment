# ansible

Configuration post-installation du cluster Kubernetes, à exécuter après le provisionnement Terraform des VMs.

## Structure

```
ansible/
├── inventory.ini              # Inventaire du cluster (master + workers)
├── kubespray/                 # Submodule Kubespray pour l'installation de K8s
└── post-install-kubespray/    # Playbooks de configuration post-déploiement
    ├── all-nodes.yml          # Configuration réseau/DNS (tous les noeuds)
    ├── masters.yml            # Configuration kubectl et labels (master)
    └── workers.yml            # Préparation du stockage Longhorn (workers)
```

## Inventaire

Le fichier `inventory.ini` définit la topologie du cluster :

| Hôte | IP | Rôle |
|------|----|------|
| master1 | 192.168.45.100 | control-plane + etcd |
| worker1 | 192.168.45.110 | worker |
| worker2 | 192.168.45.111 | worker |
| worker3 | 192.168.45.112 | worker |

L'inventaire peut aussi être généré automatiquement par Terraform dans `terraform/clusters/inventory/`.

## Playbooks post-install

### 1. `all-nodes.yml` — Tous les noeuds

- Désactive `systemd-resolved`
- Configure les DNS (`8.8.8.8`, `1.1.1.1`)
- Désactive IPv6

```bash
ansible-playbook -i inventory.ini post-install-kubespray/all-nodes.yml
```

### 2. `masters.yml` — Master uniquement

- Installe `kubectl`
- Configure le kubeconfig pour l'utilisateur `devver`
- Applique les labels et taints sur les noeuds

```bash
ansible-playbook -i inventory.ini post-install-kubespray/masters.yml
```

### 3. `workers.yml` — Workers uniquement

- Installe `open-iscsi`
- Formate et monte le disque secondaire sur `/mnt/longhorn` (stockage Longhorn)

```bash
ansible-playbook -i inventory.ini post-install-kubespray/workers.yml
```

## Kubespray

Kubespray est utilisé comme submodule pour installer Kubernetes sur le cluster.

```bash
cd kubespray
ansible-playbook -i ../inventory.ini cluster.yml
```

Se référer à la [documentation officielle Kubespray](https://kubespray.io) pour la configuration avancée.

## Ordre d'exécution

```bash
# 1. Configuration réseau de tous les noeuds
ansible-playbook -i inventory.ini post-install-kubespray/all-nodes.yml

# 2. Déploiement Kubernetes via Kubespray
cd kubespray && ansible-playbook -i ../inventory.ini cluster.yml && cd ..

# 3. Configuration post-K8s
ansible-playbook -i inventory.ini post-install-kubespray/masters.yml
ansible-playbook -i inventory.ini post-install-kubespray/workers.yml
```
