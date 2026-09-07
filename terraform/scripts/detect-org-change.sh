#!/usr/bin/env bash
# Détecte, depuis le diff entre deux commits, si une nouvelle org a été
# ajoutée sous terraform/clusters/ (hors _template) — utilisé par le job
# "detect" de vault-create-org.yml pour savoir s'il doit préparer la
# structure Vault de cette nouvelle org.
#
# Ne détecte QUE les créations : la suppression d'un cluster ne passe plus
# par un diff de dossier (trop fragile face à un historique git qui s'éloigne
# entre la suppression et le déclenchement de la pipeline) — elle se pilote
# directement via workflow_dispatch sur proxmox-deploy-cluster.yml, qui
# retire lui-même le dossier une fois le destroy infra confirmé réussi.
#
# Usage : ./detect-org-change.sh <commit_before> <commit_after>
# Sortie ($GITHUB_OUTPUT si dispo, sinon stdout) :
#   - une nouvelle org trouvée   : org=<nom>  action=create
#   - aucune nouvelle org        : action=none  (pas une erreur — cas normal
#                                   pour tout push qui n'ajoute pas de dossier,
#                                   y compris le commit qui en supprime un)
# Échoue explicitement si PLUSIEURS orgs sont ajoutées dans le même diff (un
# ajout à la fois, comme le reste du flux).
set -euo pipefail

before="${1:?Usage: $0 <commit_before> <commit_after>}"
after="${2:?Usage: $0 <commit_before> <commit_after>}"

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "${repo_root}"

added_orgs=$(git diff --diff-filter=A --name-only "${before}" "${after}" -- 'terraform/clusters/*/*' \
  | awk -F'/' '{print $3}' | grep -v '^_template$' | sort -u || true)
added_count=$(printf '%s\n' "${added_orgs}" | grep -c . || true)

if [[ "${added_count}" -eq 0 ]]; then
  org=""
  action="none"
  echo "detect-org-change.sh: aucune nouvelle org détectée dans ce diff." >&2
elif [[ "${added_count}" -eq 1 ]]; then
  org="${added_orgs}"
  action="create"
  echo "detect-org-change.sh: org=${org} action=${action}" >&2
else
  echo "detect-org-change.sh: attendu au plus une org ajoutée par diff, trouvé added=[${added_orgs}]." >&2
  exit 1
fi

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  {
    echo "org=${org}"
    echo "action=${action}"
  } >> "${GITHUB_OUTPUT}"
else
  echo "org=${org}"
  echo "action=${action}"
fi
