# Image du job "3 - Ansible: configurer les clusters" — buildée et poussée
# sur GHCR par le job build-image, réutilisée tant que la version ci-dessous
# ne change pas (voir .github/workflows/ansible-configure-clusters.yml, qui
# extrait cette ligne par grep pour construire le tag de l'image).
#
# IMAGE_VERSION=3
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

RUN pip install --no-cache-dir \
        ansible-core~=2.17 \
        hvac

COPY ansible/requirements.yml /tmp/requirements.yml
RUN ansible-galaxy collection install -r /tmp/requirements.yml \
    && rm /tmp/requirements.yml
