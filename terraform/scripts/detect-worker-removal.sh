#!/usr/bin/env bash
# Détermine QUEL(S) worker(s) un terraform apply est sur le point de détruire
# — utilisé par le job remove-worker de proxmox-deploy-cluster.yml pour
# savoir lesquels drainer/désinstaller AVANT l'apply qui détruit leur VM.
#
# Lit un vrai terraform plan (pas un diff de additional_workers_count) pour
# avoir la liste EXACTE des ressources que Terraform va réellement détruire —
# la source de vérité la plus fiable disponible à ce stade.
#
# Garde-fou : si le plan révèle la destruction d'un MASTER
# (proxmox_virtual_environment_vm.mixed[...], piloté par node_count, pas
# additional_workers_count), le script échoue explicitement. Ce mécanisme ne
# gère QUE le retrait de workers — un retrait de master risque une perte de
# quorum etcd et nécessite une intervention manuelle, jamais automatisée ici.
#
# Prérequis : terraform déjà init dans le répertoire courant
# (terraform/clusters/<org>/), jq installé.
#
# Usage : ./detect-worker-removal.sh
# Sortie ($GITHUB_OUTPUT si dispo, sinon stdout) :
#   nodes_to_remove=<JSON> — ex: ["worker-3"], ou [] si rien à détruire.
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
  echo "detect-worker-removal.sh: destruction de MASTER(S) détectée dans le plan [${masters_destroyed}] — retrait de master non supporté par ce mécanisme (risque de perte de quorum etcd). Intervention manuelle requise." >&2
  exit 1
fi

nodes_to_remove=$(echo "${plan_json}" | jq -c '[
  .resource_changes[]?
  | select(.type == "proxmox_virtual_environment_vm")
  | select(.address | startswith("proxmox_virtual_environment_vm.worker_only["))
  | select(.change.actions == ["delete"])
  | .index
]')

echo "detect-worker-removal.sh: nodes_to_remove=${nodes_to_remove}" >&2

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  echo "nodes_to_remove=${nodes_to_remove}" >> "${GITHUB_OUTPUT}"
else
  echo "nodes_to_remove=${nodes_to_remove}"
fi
