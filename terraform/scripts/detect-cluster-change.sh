#!/usr/bin/env bash
# PRÉSÉLECTION légère avant confirmation par terraform plan
# (detect-cluster-plan.sh) — ce script ne décide JAMAIS seul d'une action,
# il réduit seulement l'espace de recherche : quelles orgs valent la peine
# d'un terraform plan (coûteux : init + plan par org) à ce push précis.
#
# - orgs_delete : comparaison d'ÉTAT RÉEL (orgs connues de Vault —
#   list-vault-orgs.sh — mais absentes du repo actuel) : pas de terraform
#   plan possible ici, le dossier a disparu. Fiable par construction, pas de
#   dépendance à un diff de commit pour CETTE détection précise (seul le job
#   delete-cluster, une fois déclenché, a encore besoin de github.event.before
#   pour retrouver le code à détruire — un problème différent : "où trouver
#   le code", pas "faut-il détruire").
# - orgs_to_plan : candidates pour un terraform plan, union de :
#     - dossiers terraform/clusters/<org>/ apparus dans ce push (présents
#       après, absents avant) ;
#     - orgs présentes aux deux commits dont un fichier .tf ou
#       values.auto.tfvars a changé.
#   Le job appelant doit ensuite lancer detect-cluster-plan.sh pour CHACUNE
#   de ces orgs afin de confirmer l'action réelle (create-cluster,
#   add-worker, remove-worker, ou aucune si le plan ne révèle rien — ex: un
#   dossier apparu mais sans structure Vault encore créée, donc le plan
#   échouerait de toute façon faute de credentials VM valides : filtré par
#   le job lui-même, pas par ce script).
#
# Prérequis : VAULT_ADDR + VAULT_TOKEN déjà exportés (pour list-vault-orgs.sh),
# jq installé, git avec un historique suffisant (fetch-depth >= 2 en CI).
#
# Usage : ./detect-cluster-change.sh <sha_avant> <sha_apres>
# Sortie ($GITHUB_OUTPUT si dispo, sinon stdout) :
#   orgs_delete=<JSON>   — orgs à détruire, ex: ["prod"]
#   orgs_to_plan=<JSON>  — orgs candidates à un terraform plan, ex: ["prod","staging"]
set -euo pipefail

before_sha="${1:?Usage: detect-cluster-change.sh <sha_avant> <sha_apres>}"
after_sha="${2:?Usage: detect-cluster-change.sh <sha_avant> <sha_apres>}"

script_dir="$(cd "$(dirname "$0")" && pwd)"
repo_root="$(cd "${script_dir}/../.." && pwd)"
cd "${repo_root}"

vault_orgs=$(bash "${script_dir}/list-vault-orgs.sh" | sort)
repo_orgs_after=$(bash "${script_dir}/list-orgs.sh" | jq -r '.[]' | sort)

to_json_array() {
  if [[ -z "$1" ]]; then
    echo "[]"
  else
    printf '%s\n' "$1" | jq -R . | jq -s -c .
  fi
}

# --- orgs_delete : état réel (Vault) vs état réel (repo), pas de diff git ---
orgs_delete_lines=$(comm -23 <(printf '%s\n' "${vault_orgs}") <(printf '%s\n' "${repo_orgs_after}") | grep -v '^$' || true)
orgs_delete="$(to_json_array "${orgs_delete_lines}")"

# --- orgs_to_plan : dossiers apparus + fichiers .tf/tfvars modifiés -------
orgs_before=$(git ls-tree -d --name-only "${before_sha}" -- terraform/clusters/ 2>/dev/null \
  | sed 's#^terraform/clusters/##' | grep -v '^_template$' | grep -v '^$' | sort || true)
orgs_after=$(git ls-tree -d --name-only "${after_sha}" -- terraform/clusters/ 2>/dev/null \
  | sed 's#^terraform/clusters/##' | grep -v '^_template$' | grep -v '^$' | sort || true)

appeared=$(comm -13 <(printf '%s\n' "${orgs_before}") <(printf '%s\n' "${orgs_after}") | grep -v '^$' || true)

changed_files=$(git diff --name-only "${before_sha}" "${after_sha}" -- 'terraform/clusters/*' 2>/dev/null || true)
orgs_with_changed_files=$(printf '%s\n' "${changed_files}" \
  | grep -E '\.tf$|values\.auto\.tfvars$' \
  | sed -E 's#^terraform/clusters/([^/]+)/.*#\1#' \
  | grep -v '^_template$' | grep -v '^$' | sort -u || true)

# Une org supprimée (dossier disparu, voir orgs_delete ci-dessus) peut
# apparaître ici à tort : git diff liste aussi les fichiers .tf/tfvars
# SUPPRIMÉS par ce push comme "changés", donc son dossier finirait dans
# orgs_to_plan malgré son absence du repo après — "cd terraform/clusters/<org>"
# échouerait alors dans la boucle terraform plan du job appelant (bug réel
# rencontré en CI : "No such file or directory" sur le dossier supprimé).
# orgs_after (ligne 60, dossiers réellement présents après ce push) est la
# source de vérité : exclut toute org déjà retirée du repo, qu'elle soit
# dans orgs_delete ou simplement renommée/déplacée.
orgs_to_plan_lines=$(comm -12 \
  <(printf '%s\n%s\n' "${appeared}" "${orgs_with_changed_files}" | grep -v '^$' | sort -u) \
  <(printf '%s\n' "${orgs_after}") || true)
orgs_to_plan="$(to_json_array "${orgs_to_plan_lines}")"

echo "detect-cluster-change.sh: orgs_delete=${orgs_delete} orgs_to_plan=${orgs_to_plan}" >&2

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  {
    echo "orgs_delete=${orgs_delete}"
    echo "orgs_to_plan=${orgs_to_plan}"
  } >> "${GITHUB_OUTPUT}"
else
  echo "orgs_delete=${orgs_delete}"
  echo "orgs_to_plan=${orgs_to_plan}"
fi
