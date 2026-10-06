#!/usr/bin/env bash
# Détermine l'action RÉELLE qu'un terraform apply effectuerait pour une org
# donnée, en lisant un vrai `terraform plan` — pas un diff de fichiers entre
# deux commits. Remplace/généralise l'ancien detect-worker-removal.sh : celui
# ne détectait QUE les suppressions de workers ; celui-ci classe aussi les
# créations de masters (create-cluster) et de workers (add-worker).
#
# Pourquoi un plan plutôt qu'un diff : un diff "dossier apparu"/"compteur
# changé" entre deux commits consécutifs (github.event.before/github.sha)
# rate un delta si un run échoue entre deux push, ou si plusieurs push
# s'enchaînent rapidement — déjà le bug qui a fait abandonner l'ancien
# detect-org-change.sh basé sur un diff. terraform plan compare le VOULU
# (values.auto.tfvars actuel) à l'ÉTAT RÉEL (state Terraform sur B2),
# peu importe l'historique des commits — fiable par construction, et
# naturellement idempotent (une org déjà à jour ne révèle plus rien).
#
# Garde-fou : si le plan révèle la destruction d'un MASTER
# (proxmox_virtual_environment_vm.mixed[...], piloté par node_count), le
# script échoue explicitement. Jamais de retrait de master automatisé
# (risque de perte de quorum etcd) — intervention manuelle requise.
#
# Prérequis : terraform déjà init dans le répertoire courant
# (terraform/clusters/<org>/), jq installé.
#
# Usage : ./detect-cluster-plan.sh
# Sortie ($GITHUB_OUTPUT si dispo, sinon stdout) :
#   action=<create-cluster|add-worker|remove-worker|none>
#   nodes_to_remove=<JSON> — uniquement pertinent si action=remove-worker,
#     ex: ["worker-3"], sinon [].
# Échoue (exit 1) si une destruction de master est détectée dans le plan.
set -euo pipefail

plan_file="$(mktemp)"
trap 'rm -f "${plan_file}"' EXIT

terraform plan -out="${plan_file}" -input=false >&2

plan_json=$(terraform show -json "${plan_file}")

masters_destroyed=$(echo "${plan_json}" | jq -r '
  .resource_changes[]?
  | select(.type == "proxmox_virtual_environment_vm")
  | select(.address | startswith("proxmox_virtual_environment_vm.mixed["))
  | select(.change.actions == ["delete"])
  | .index
')

if [[ -n "${masters_destroyed}" ]]; then
  echo "detect-cluster-plan.sh: destruction de MASTER(S) détectée dans le plan [${masters_destroyed}] — retrait de master non supporté par ce mécanisme (risque de perte de quorum etcd). Intervention manuelle requise." >&2
  exit 1
fi

masters_created=$(echo "${plan_json}" | jq -r '
  .resource_changes[]?
  | select(.type == "proxmox_virtual_environment_vm")
  | select(.address | startswith("proxmox_virtual_environment_vm.mixed["))
  | select(.change.actions == ["create"])
  | .index
')

workers_created=$(echo "${plan_json}" | jq -r '
  .resource_changes[]?
  | select(.type == "proxmox_virtual_environment_vm")
  | select(.address | startswith("proxmox_virtual_environment_vm.worker_only["))
  | select(.change.actions == ["create"])
  | .index
')

workers_removed=$(echo "${plan_json}" | jq -c '[
  .resource_changes[]?
  | select(.type == "proxmox_virtual_environment_vm")
  | select(.address | startswith("proxmox_virtual_environment_vm.worker_only["))
  | select(.change.actions == ["delete"])
  | .index
]')

# Ordre de priorité : un premier apply crée à la fois tous les masters ET
# les workers_only éventuels (node_count + additional_workers_count d'un
# coup) — create-cluster prime donc sur add-worker si les deux sont présents
# dans le même plan (cas du tout premier apply d'une org).
if [[ -n "${masters_created}" ]]; then
  action="create-cluster"
  nodes_to_remove="[]"
elif [[ -n "${workers_created}" ]]; then
  action="add-worker"
  nodes_to_remove="[]"
elif [[ "${workers_removed}" != "[]" ]]; then
  action="remove-worker"
  nodes_to_remove="${workers_removed}"
else
  action="none"
  nodes_to_remove="[]"
fi

echo "detect-cluster-plan.sh: action=${action} nodes_to_remove=${nodes_to_remove}" >&2

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  {
    echo "action=${action}"
    echo "nodes_to_remove=${nodes_to_remove}"
  } >> "${GITHUB_OUTPUT}"
else
  echo "action=${action}"
  echo "nodes_to_remove=${nodes_to_remove}"
fi
