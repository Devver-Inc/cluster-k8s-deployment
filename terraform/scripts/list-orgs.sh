#!/usr/bin/env bash
# Scanne terraform/clusters/ et liste les orgs existantes (sous-dossiers, hors
# _template), pour construire la variable Terraform "orgs" consommée par
# terraform/vault/ (policy + role AppRole + secret par org).
#
# Usage : ./list-orgs.sh
# Sortie : une ligne JSON, ex: ["prod","preprod"]
# En CI, rediriger vers $GITHUB_OUTPUT : echo "orgs=$(./list-orgs.sh)" >> "$GITHUB_OUTPUT"
set -euo pipefail

cd "$(dirname "$0")/../clusters"

orgs=$(find . -maxdepth 1 -mindepth 1 -type d ! -name '_template' -exec basename {} \; | sort)

if [[ -z "${orgs}" ]]; then
  echo "[]"
else
  printf '%s\n' "${orgs}" | jq -R . | jq -s -c .
fi
