#!/usr/bin/env bash
# Détecte, pour CHAQUE org ayant changé dans ce push, laquelle des 4 actions
# du workflow "2 - Proxmox" en découle : create-cluster, delete-cluster,
# add-worker, remove-worker. Remplace le workflow_dispatch manuel
# (org+action) : l'admin édite un fichier et pushe, ce script déduit l'action.
#
# - Dossier terraform/clusters/<org>/ apparu dans ce push (absent du commit
#   précédent) ET structure Vault déjà créée (list-vault-orgs.sh) ->
#   action=create-cluster. Si la structure Vault n'existe pas encore, l'org
#   n'est PAS prête (secrets pas saisis) : ignorée, cohérent avec le flux
#   "1 - Vault" qui doit tourner en premier.
# - Dossier disparu entre les deux commits -> action=delete-cluster.
# - Dossier présent aux deux commits, mais additional_workers_count a changé
#   dans values.auto.tfvars (diff TEXTUEL du fichier entre les deux commits —
#   contrairement à create/delete, cette valeur n'a pas d'équivalent "état
#   réel" externe à comparer, c'est une donnée purement locale au repo) :
#     - valeur augmentée -> action=add-worker
#     - valeur diminuée  -> action=remove-worker
#
# Pas de risque de destruction croisée comme terraform/vault/ (un seul
# for_each partagé par toutes les orgs) : chaque org a son propre state
# Terraform isolé, donc un checkout incomplet n'affecte jamais les autres
# orgs via ce mécanisme — contrairement à detect-org-change.sh, pas besoin de
# limiter à un seul changement à la fois.
#
# Sortie en 4 listes JSON séparées (pas un seul mélange à filtrer côté YAML)
# pour que chaque job du workflow consomme directement la sienne en matrix,
# sans entrée "fantôme" pour une org qui ne le concerne pas.
#
# Prérequis : CLI `vault` installé, VAULT_ADDR + VAULT_TOKEN déjà exportés,
# jq installé, git avec un historique suffisant (fetch-depth >= 2 en CI).
#
# Usage : ./detect-cluster-change.sh <sha_avant> <sha_apres>
# Sortie ($GITHUB_OUTPUT si dispo, sinon stdout), une liste JSON de strings
# (orgs) par action, ex: ["prod"] ou [] si aucune org concernée :
#   orgs_create=[...]
#   orgs_delete=[...]
#   orgs_add_worker=[...]
#   orgs_remove_worker=[...]
set -euo pipefail

before_sha="${1:?Usage: detect-cluster-change.sh <sha_avant> <sha_apres>}"
after_sha="${2:?Usage: detect-cluster-change.sh <sha_avant> <sha_apres>}"

script_dir="$(cd "$(dirname "$0")" && pwd)"
repo_root="$(cd "${script_dir}/../.." && pwd)"
cd "${repo_root}"

vault_orgs=$(bash "${script_dir}/list-vault-orgs.sh" | sort)

orgs_before=$(git ls-tree -d --name-only "${before_sha}" -- terraform/clusters/ 2>/dev/null \
  | sed 's#^terraform/clusters/##' | grep -v '^_template$' | grep -v '^$' | sort || true)
orgs_after=$(git ls-tree -d --name-only "${after_sha}" -- terraform/clusters/ 2>/dev/null \
  | sed 's#^terraform/clusters/##' | grep -v '^_template$' | grep -v '^$' | sort || true)

appeared=$(comm -13 <(printf '%s\n' "${orgs_before}") <(printf '%s\n' "${orgs_after}") | grep -v '^$' || true)
disappeared=$(comm -23 <(printf '%s\n' "${orgs_before}") <(printf '%s\n' "${orgs_after}") | grep -v '^$' || true)
present_both=$(comm -12 <(printf '%s\n' "${orgs_before}") <(printf '%s\n' "${orgs_after}") | grep -v '^$' || true)

to_json_array() {
  # $1 : une liste d'orgs séparées par des \n (peut être vide)
  if [[ -z "$1" ]]; then
    echo "[]"
  else
    printf '%s\n' "$1" | jq -R . | jq -s -c .
  fi
}

orgs_create_lines=""
orgs_delete_lines=""
orgs_add_worker_lines=""
orgs_remove_worker_lines=""

if [[ -n "${appeared}" ]]; then
  while IFS= read -r org; do
    [[ -z "${org}" ]] && continue
    if echo "${vault_orgs}" | grep -qx "${org}"; then
      echo "detect-cluster-change.sh: org=${org} action=create-cluster" >&2
      orgs_create_lines="${orgs_create_lines}${org}"$'\n'
    else
      echo "detect-cluster-change.sh: org=${org} nouvelle mais pas de structure Vault encore — ignorée (lancer 1 - Vault d'abord)." >&2
    fi
  done <<< "${appeared}"
fi

if [[ -n "${disappeared}" ]]; then
  while IFS= read -r org; do
    [[ -z "${org}" ]] && continue
    echo "detect-cluster-change.sh: org=${org} action=delete-cluster" >&2
    orgs_delete_lines="${orgs_delete_lines}${org}"$'\n'
  done <<< "${disappeared}"
fi

if [[ -n "${present_both}" ]]; then
  while IFS= read -r org; do
    [[ -z "${org}" ]] && continue
    tfvars_path="terraform/clusters/${org}/values.auto.tfvars"

    before_count=$(git show "${before_sha}:${tfvars_path}" 2>/dev/null \
      | grep -oP '^additional_workers_count\s*=\s*\K\d+' || echo "")
    after_count=$(git show "${after_sha}:${tfvars_path}" 2>/dev/null \
      | grep -oP '^additional_workers_count\s*=\s*\K\d+' || echo "")

    if [[ -z "${before_count}" || -z "${after_count}" ]]; then
      continue
    fi
    if [[ "${after_count}" -gt "${before_count}" ]]; then
      echo "detect-cluster-change.sh: org=${org} action=add-worker (${before_count} -> ${after_count})" >&2
      orgs_add_worker_lines="${orgs_add_worker_lines}${org}"$'\n'
    elif [[ "${after_count}" -lt "${before_count}" ]]; then
      echo "detect-cluster-change.sh: org=${org} action=remove-worker (${before_count} -> ${after_count})" >&2
      orgs_remove_worker_lines="${orgs_remove_worker_lines}${org}"$'\n'
    fi
  done <<< "${present_both}"
fi

orgs_create="$(to_json_array "${orgs_create_lines%$'\n'}")"
orgs_delete="$(to_json_array "${orgs_delete_lines%$'\n'}")"
orgs_add_worker="$(to_json_array "${orgs_add_worker_lines%$'\n'}")"
orgs_remove_worker="$(to_json_array "${orgs_remove_worker_lines%$'\n'}")"

if [[ "${orgs_create}" == "[]" && "${orgs_delete}" == "[]" && "${orgs_add_worker}" == "[]" && "${orgs_remove_worker}" == "[]" ]]; then
  echo "detect-cluster-change.sh: aucune action détectée." >&2
fi

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  {
    echo "orgs_create=${orgs_create}"
    echo "orgs_delete=${orgs_delete}"
    echo "orgs_add_worker=${orgs_add_worker}"
    echo "orgs_remove_worker=${orgs_remove_worker}"
  } >> "${GITHUB_OUTPUT}"
else
  echo "orgs_create=${orgs_create}"
  echo "orgs_delete=${orgs_delete}"
  echo "orgs_add_worker=${orgs_add_worker}"
  echo "orgs_remove_worker=${orgs_remove_worker}"
fi
