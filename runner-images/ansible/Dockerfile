# Image des jobs "configure" et "remove-worker" du workflow "2 - Proxmox:
# apply/destroy cluster" — buildée et poussée sur GHCR par le job
# build-ansible-image, réutilisée tant que la version ci-dessous ne change
# pas (voir .github/workflows/proxmox-deploy-cluster.yml, qui extrait cette
# ligne par grep pour construire le tag de l'image).
#
# IMAGE_VERSION=12
#
# Incrémenter cette version à chaque changement de ce Dockerfile ou de
# ansible/requirements.yml, pour forcer un rebuild/push.
#
# Contient tout ce dont le job a besoin, y compris le login Vault
# (hashicorp/vault-action tourne dans ce même conteneur) : Ansible + la
# collection community.hashi_vault, le CLI vault (pour fetch-ssh-key.sh), git
# (actions/checkout), un client SSH (connexion aux VMs cibles), jq (utilisé
# par terraform/scripts/list-orgs.sh dans le job list-clusters), kubectl
# (utilisé par le job remove-worker pour drainer/désinscrire un node avant
# que Terraform ne détruise sa VM — voir fetch-kubeconfig.sh et
# playbooks/04-remove-node.yml) et terraform (le job remove-worker fait tout
# son init/plan/apply dans ce même conteneur, entre le drain Kubernetes et le
# playbook SSH — découvert en CI : "terraform: not found" sans ce binaire).
#
# Les jobs configure/remove-worker passent désormais container: options:
# --user ${{ vars.RUNNER_UID }}:${{ vars.RUNNER_GID }} (voir le workflow) —
# un UID arbitraire sans entrée dans /etc/passwd du conteneur ne résout pas
# $HOME automatiquement, d'où ENV HOME=/tmp ci-dessous (répertoire déjà
# accessible en écriture par tout UID sur une image Linux standard).
FROM python:3.12-slim

ENV HOME=/tmp

ARG VAULT_VERSION=1.17.6
# Alignée sur rke2_version dans ansible/group_vars/all.yml (v1.30.5+rke2r1) —
# kubectl reste compatible +/- 1 version mineure avec le serveur, mais autant
# matcher précisément.
ARG KUBECTL_VERSION=v1.30.5
# Alignée sur la version utilisée par les jobs Terraform à plat du même
# workflow (create-cluster, add-worker, delete-cluster) — pas de contrainte
# stricte de compatibilité ici, mais autant rester cohérent.
ARG TERRAFORM_VERSION=1.9.8

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        git \
        openssh-client \
        curl \
        unzip \
        ca-certificates \
        jq \
    && curl -fsSL -o /tmp/vault.zip \
        "https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_amd64.zip" \
    && unzip -o /tmp/vault.zip -d /usr/local/bin \
    && rm /tmp/vault.zip \
    && curl -fsSL -o /tmp/terraform.zip \
        "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip" \
    && unzip -o /tmp/terraform.zip -d /usr/local/bin \
    && rm /tmp/terraform.zip \
    && curl -fsSL -o /usr/local/bin/kubectl \
        "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl" \
    && chmod +x /usr/local/bin/kubectl \
    && rm -rf /var/lib/apt/lists/*

# Version épinglée strictement : ~=2.17 résolvait vers 2.21.4 (probablement
# une pré-release/version très récente publiée sous ce schéma), qui a un bug
# de découverte des group_vars/<nom-groupe>.yml — group_vars/all.yml se
# chargeait mais pas group_vars/server.yml ni agent.yml malgré une
# appartenance de groupe correcte (group_names confirmé correct). 2.17.6 est
# une version stable connue sans ce problème.
# hvac pinné aussi : non pinné auparavant, installait la dernière version
# disponible au build — même risque que ansible-core~=2.17 (résolution vers
# une version imprévue). 2.3.0 est une version stable largement utilisée.
RUN pip install --no-cache-dir \
        ansible-core==2.17.6 \
        hvac==2.3.0

# Chemin explicite et fixe (indépendant de $HOME, qui peut différer entre le
# build de l'image et le runtime du job GitHub Actions container: — le
# comportement par défaut d'ansible-galaxy, ~/.ansible/collections, s'est
# révélé invisible à ansible-playbook au runtime malgré une installation
# réussie au build). ANSIBLE_COLLECTIONS_PATH ci-dessous force les deux à
# chercher/écrire au même endroit.
ENV ANSIBLE_COLLECTIONS_PATH=/usr/share/ansible/collections
COPY ansible/requirements.yml /tmp/requirements.yml
RUN mkdir -p /usr/share/ansible/collections \
    && ansible-galaxy collection install -r /tmp/requirements.yml -p /usr/share/ansible/collections \
    && rm /tmp/requirements.yml
