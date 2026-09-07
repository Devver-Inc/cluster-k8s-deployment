#!/usr/bin/env bash
# Détecte, depuis le diff entre deux commits, quelle org a été ajoutée ou
# supprimée sous terraform/clusters/ (hors _template) — utilisé par le job
# "detect" du workflow deploy-cluster.yml pour router vers la bonne branche
# (création vs suppression).
#
# Usage : ./detect-org-change.sh <commit_before> <commit_after>
# Sortie ($GITHUB_OUTPUT si dispo, sinon stdout) : org=<nom>  action=create|delete
# Échoue explicitement si 0 ou 2+ orgs sont touchées dans le même diff (le
# workflow attend un ajout OU une suppression à la fois, jamais les deux).
set -euo pipefail

before="${1:?Usage: $0 <commit_before> <commit_after>}"
after="${2:?Usage: $0 <commit_before> <commit_after>}"

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "${repo_root}"

# Dossiers de premier niveau ajoutés/supprimés sous terraform/clusters/
added_orgs=$(git diff --diff-filter=A --name-only "${before}" "${after}" -- 'terraform/clusters/*/*' \
  | awk -F'/' '{print $3}' | grep -v '^_template$' | sort -u || true)
removed_orgs=$(git diff --diff-filter=D --name-only "${before}" "${after}" -- 'terraform/clusters/*/*' \
  | awk -F'/' '{print $3}' | grep -v '^_template$' | sort -u || true)

# Une org est "ajoutée" si elle a des fichiers ajoutés ET n'existe plus dans removed
# (sinon ce serait juste une modif de fichier existant). Pareil en miroir pour delete.
added_count=$(printf '%s\n' "${added_orgs}" | grep -c . || true)
removed_count=$(printf '%s\n' "${removed_orgs}" | grep -c . || true)

if [[ "${added_count}" -eq 1 && "${removed_count}" -eq 0 ]]; then
  org="${added_orgs}"
  action="create"
elif [[ "${removed_count}" -eq 1 && "${added_count}" -eq 0 ]]; then
  org="${removed_orgs}"
  action="delete"
else
  echo "detect-org-change.sh: attendu exactement une org ajoutée OU supprimée, trouvé added=[${added_orgs}] removed=[${removed_orgs}]." >&2
  exit 1
fi

echo "detect-org-change.sh: org=${org} action=${action}" >&2

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  {
    echo "org=${org}"
    echo "action=${action}"
  } >> "${GITHUB_OUTPUT}"
else
  echo "org=${org}"
  echo "action=${action}"
fi
