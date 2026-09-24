# Image du job "3 - Ansible: configurer les clusters" — buildée et poussée
# sur GHCR par le job build-image, réutilisée tant que la version ci-dessous
# ne change pas (voir .github/workflows/ansible-configure-clusters.yml, qui
# extrait cette ligne par grep pour construire le tag de l'image).
#
# IMAGE_VERSION=8
#
# Incrémenter cette version à chaque changement de ce Dockerfile ou de
# ansible/requirements.yml, pour forcer un rebuild/push.
#
# Contient tout ce dont le job a besoin, y compris le login Vault
# (hashicorp/vault-action tourne dans ce même conteneur) : Ansible + la
# collection community.hashi_vault, le CLI vault (pour fetch-ssh-key.sh), git
# (actions/checkout), un client SSH (connexion aux VMs cibles) et jq (utilisé
# par terraform/scripts/list-orgs.sh dans le job list-clusters).
FROM python:3.12-slim

ARG VAULT_VERSION=1.17.6

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
    && unzip /tmp/vault.zip -d /usr/local/bin \
    && rm /tmp/vault.zip \
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
