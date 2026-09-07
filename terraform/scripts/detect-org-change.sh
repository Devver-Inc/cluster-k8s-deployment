#!/usr/bin/env bash
# Détecte si une org présente dans le repo (terraform/clusters/<org>/) n'a pas
# encore de structure Vault — utilisé par le job "detect" de vault-create-org.yml
# pour savoir s'il doit préparer la structure Vault d'une nouvelle org.
#
# Compare un ÉTAT (dossiers clusters/<org>/ existants) à un AUTRE ÉTAT (orgs
# déjà connues de Vault), plutôt qu'un diff entre deux commits git — ce
# dernier mécanisme s'est révélé peu fiable en pratique : une org ajoutée dans
# un commit, suivie d'autres commits/push avant qu'un run réussisse (ex. un
# run qui échoue avant d'être corrigé), n'était plus jamais détectée, car le
# diff du push suivant ne montrait plus cet ajout. La comparaison d'état
# donne toujours le bon résultat, peu importe l'historique.
#
# Ne détecte QUE les créations : la suppression d'un cluster ne passe pas par
# ce script — elle se pilote directement via workflow_dispatch sur
# proxmox-deploy-cluster.yml, qui retire lui-même le dossier une fois le
# destroy infra confirmé réussi.
#
# Prérequis : CLI `vault` installé, VAULT_ADDR + VAULT_TOKEN déjà exportés
# (ex: via hashicorp/vault-action avec exportToken: true), jq installé.
#
# Usage : ./detect-org-change.sh
# Sortie ($GITHUB_OUTPUT si dispo, sinon stdout) :
#   - une org à créer trouvée : org=<nom>  action=create
#   - aucune org à créer      : action=none  (pas une erreur — cas normal)
# Échoue explicitement si PLUSIEURS orgs sont à créer en même temps (une à la fois).
set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"

repo_orgs=$(bash "${script_dir}/list-orgs.sh" | jq -r '.[]' | sort)
vault_orgs=$(bash "${script_dir}/list-vault-orgs.sh" | sort)

to_create=$(comm -23 <(printf '%s\n' "${repo_orgs}") <(printf '%s\n' "${vault_orgs}") | grep -v '^$' || true)
create_count=$(printf '%s\n' "${to_create}" | grep -c . || true)

if [[ "${create_count}" -eq 0 ]]; then
  org=""
  action="none"
  echo "detect-org-change.sh: aucune org à créer (repo et Vault déjà synchronisés)." >&2
elif [[ "${create_count}" -eq 1 ]]; then
  org="${to_create}"
  action="create"
  echo "detect-org-change.sh: org=${org} action=${action}" >&2
else
  echo "detect-org-change.sh: plusieurs orgs à créer détectées en une fois [${to_create}] — les traiter une par une." >&2
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
