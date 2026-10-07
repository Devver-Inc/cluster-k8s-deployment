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

# grep -v peut légitimement ne laisser passer AUCUNE ligne (ex: plus aucune
# org dans Vault, cas réel rencontré juste après la suppression de la
# dernière org existante) — avec pipefail, grep retourne alors exit 1 et
# fait planter tout le script appelant (bug réel en CI : le job "detect" du
# workflow Provision cluster échouait net, sans message clair, sur ce cas
# précis). "|| true" tolère ce cas sans masquer une vraie erreur vault list
# (celle-là se manifeste avant, dans la commande vault elle-même, toujours
# propagée par pipefail).
vault list -format=json sys/policies/acl \
  | jq -r '.[] | select(startswith("terraform-") and endswith("-ro")) | sub("^terraform-";"") | sub("-ro$";"")' \
  | { grep -v '^backblaze$' || true; } \
  | sort
