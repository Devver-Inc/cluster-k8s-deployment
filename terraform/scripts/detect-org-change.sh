#!/usr/bin/env bash
# Détecte les orgs présentes dans le repo (terraform/clusters/<org>/) qui
# n'ont pas encore de structure Vault — utilisé par le job "detect" de
# vault-create-org.yml pour savoir lesquelles préparer automatiquement.
#
# Compare un ÉTAT (dossiers clusters/<org>/ existants) à un AUTRE ÉTAT (orgs
# déjà connues de Vault), plutôt qu'un diff entre deux commits git — ce
# dernier mécanisme s'est révélé peu fiable en pratique : une org ajoutée dans
# un commit, suivie d'autres commits/push avant qu'un run réussisse (ex. un
# run qui échoue avant d'être corrigé), n'était plus jamais détectée, car le
# diff du push suivant ne montrait plus cet ajout. La comparaison d'état
# donne toujours le bon résultat, peu importe l'historique.
#
# Ne détecte QUE les créations : la suppression d'un cluster se pilote par
# detect-cluster-change.sh (proxmox-deploy-cluster.yml), pas ici.
#
# Plusieurs orgs peuvent être retournées en une fois — le job vault-create
# qui consomme cette sortie les traite chacune en matrix, et chaque apply
# n'AJOUTE que l'org concernée à l'état réel de Vault (jamais de recalcul
# global), donc aucun risque à en traiter plusieurs dans le même run.
#
# Prérequis : CLI `vault` installé, VAULT_ADDR + VAULT_TOKEN déjà exportés
# (ex: via hashicorp/vault-action avec exportToken: true), jq installé.
#
# Usage : ./detect-org-change.sh
# Sortie ($GITHUB_OUTPUT si dispo, sinon stdout) :
#   orgs=<JSON> — liste d'orgs sans structure Vault, ex: ["prod","staging"]
#   Liste vide [] si repo et Vault déjà synchronisés (cas normal, pas une erreur).
set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"

repo_orgs=$(bash "${script_dir}/list-orgs.sh" | jq -r '.[]' | sort)
vault_orgs=$(bash "${script_dir}/list-vault-orgs.sh" | sort)

to_create=$(comm -23 <(printf '%s\n' "${repo_orgs}") <(printf '%s\n' "${vault_orgs}") | grep -v '^$' || true)

if [[ -z "${to_create}" ]]; then
  orgs="[]"
  echo "detect-org-change.sh: aucune org à créer (repo et Vault déjà synchronisés)." >&2
else
  orgs=$(printf '%s\n' "${to_create}" | jq -R . | jq -s -c .)
  echo "detect-org-change.sh: orgs à créer détectées : ${orgs}" >&2
fi

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  echo "orgs=${orgs}" >> "${GITHUB_OUTPUT}"
else
  echo "orgs=${orgs}"
fi
