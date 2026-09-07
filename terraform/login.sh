#!/usr/bin/env bash
# Prépare le shell courant pour lancer Terraform : force VAULT_ADDR (évite le
# fallback silencieux vers https://127.0.0.1:8200 si la variable n'est pas
# positionnée), puis récupère les credentials Backblaze B2 depuis Vault et les
# exporte, AVANT terraform init (le backend S3 doit être configuré avant que
# Terraform puisse évaluer la moindre data source Vault — impossible de lire
# ces credentials via le module lui-même, cf. README "Mise en place").
#
# Usage : source login.sh
# Prérequis : soit VAULT_TOKEN déjà exporté, soit VAULT_ROLE_ID/VAULT_SECRET_ID
# pour un login AppRole ponctuel (role dédié terraform-backblaze, lecture seule
# sur devver-infra-deployment/s3-backend, TTL court).
#
# Volontairement PAS de "set -e" : ce script est destiné à être sourcé dans un
# shell interactif — un "exit" y fermerait le terminal, on préfère "return" à
# chaque point d'échec et laisser le shell parent en vie dans tous les cas.

export VAULT_ADDR="${VAULT_ADDR:-https://vault.devver.app}"
echo "VAULT_ADDR=${VAULT_ADDR}"

if [[ -z "${VAULT_TOKEN:-}" ]]; then
  if [[ -z "${VAULT_ROLE_ID:-}" || -z "${VAULT_SECRET_ID:-}" ]]; then
    echo "Erreur: exporter VAULT_TOKEN, ou VAULT_ROLE_ID + VAULT_SECRET_ID (role terraform-backblaze)." >&2
    return 1 2>/dev/null || true
  fi

  VAULT_TOKEN=$(vault write -field=token auth/terraform-orgs/login \
    role_id="${VAULT_ROLE_ID}" secret_id="${VAULT_SECRET_ID}")
  if [[ -z "${VAULT_TOKEN}" ]]; then
    echo "Erreur: échec du login AppRole (VAULT_TOKEN vide)." >&2
    return 1 2>/dev/null || true
  fi
  export VAULT_TOKEN
fi

fetched_key_id=$(vault kv get -field=key_id devver-infra-deployment/s3-backend)
if [[ -z "${fetched_key_id}" ]]; then
  echo "Erreur: échec de lecture de key_id sur devver-infra-deployment/s3-backend." >&2
  return 1 2>/dev/null || true
fi

fetched_app_key=$(vault kv get -field=application_key devver-infra-deployment/s3-backend)
if [[ -z "${fetched_app_key}" ]]; then
  echo "Erreur: échec de lecture de application_key sur devver-infra-deployment/s3-backend." >&2
  return 1 2>/dev/null || true
fi

export AWS_ACCESS_KEY_ID="${fetched_key_id}"
export AWS_SECRET_ACCESS_KEY="${fetched_app_key}"
unset fetched_key_id fetched_app_key

echo "AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY exportés depuis devver-infra-deployment/s3-backend."
