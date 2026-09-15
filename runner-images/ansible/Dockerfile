# Image du job "3 - Ansible: configurer les clusters" — construite et
# réutilisée localement sur le runner self-hosted (pas de registry), rebuild
# uniquement quand VERSION change (voir .github/workflows/ansible-configure-clusters.yml).
#
# Contient tout ce dont le job a besoin, y compris le login Vault
# (hashicorp/vault-action tourne dans ce même conteneur) : Ansible + la
# collection community.hashi_vault, le CLI vault (pour fetch-ssh-key.sh), git
# (actions/checkout) et un client SSH (connexion aux VMs cibles).
FROM python:3.12-slim

ARG VAULT_VERSION=1.17.6

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        git \
        openssh-client \
        curl \
        unzip \
        ca-certificates \
    && curl -fsSL -o /tmp/vault.zip \
        "https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_amd64.zip" \
    && unzip /tmp/vault.zip -d /usr/local/bin \
    && rm /tmp/vault.zip \
    && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir \
        ansible-core~=2.17 \
        hvac

COPY requirements.yml /tmp/requirements.yml
RUN ansible-galaxy collection install -r /tmp/requirements.yml \
    && rm /tmp/requirements.yml
