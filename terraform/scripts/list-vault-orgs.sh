#!/usr/bin/env bash
# Liste les orgs qui ont DÉJÀ une structure Vault (policy terraform-<org>-ro
# créée par terraform/vault/main.tf), en lisant l'état réel de Vault plutôt
# que de déduire quoi que ce soit d'un historique git — utilisé par
# detect-org-change.sh pour comparer "orgs voulues" (repo) vs "orgs déjà
# créées" (Vault) et en déduire ce qui reste à créer.
#
# Prérequis : CLI `vault` installé, VAULT_ADDR + VAULT_TOKEN déjà exportés
# dans l'environnement (ex: via hashicorp/vault-action avec exportToken: true).
#
# Usage : ./list-vault-orgs.sh
# Sortie : une org par ligne, triée (ex: prod)
set -euo pipefail

vault list -format=json sys/policies/acl \
  | jq -r '.[] | select(startswith("terraform-") and endswith("-ro")) | sub("^terraform-";"") | sub("-ro$";"")' \
  | grep -v '^backblaze$' \
  | sort
