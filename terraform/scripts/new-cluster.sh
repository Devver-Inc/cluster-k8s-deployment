#!/usr/bin/env bash
# ============================================================
# new-cluster.sh
# Crée un nouveau terraform.tfvars pour un cluster K8s.
# C'est le seul fichier nécessaire pour un nouveau déploiement.
#
# Usage :
#   ./scripts/new-cluster.sh \
#     --env dev \
#     --mw 3 \
#     --workers 2 \
#     --reserved "192.168.99.100,192.168.99.101,192.168.99.80"
#
# Résultat : terraform/clusters/<env>/terraform.tfvars
# Déploiement : cd terraform/clusters && terraform workspace new <env>
#               terraform apply -var-file=<env>/terraform.tfvars
# ============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="${SCRIPT_DIR}/.."
CLUSTERS_DIR="${BASE_DIR}/clusters"
REGISTRY="${BASE_DIR}/clusters-registry/clusters.yaml"

# ---- Valeurs par défaut ----
ENV=""
MW_COUNT=3
WORKER_COUNT=0
RESERVED_IPS=""

# ---- Parsing ----
usage() {
  echo "Usage: $0 --env <prod|dev|test> [--mw <n>] [--workers <n>] [--reserved \"ip1,ip2,...\"]"
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env)       ENV="$2";          shift 2 ;;
    --mw)        MW_COUNT="$2";     shift 2 ;;
    --workers)   WORKER_COUNT="$2"; shift 2 ;;
    --reserved)  RESERVED_IPS="$2"; shift 2 ;;
    *) usage ;;
  esac
done

[[ -z "$ENV" ]] && usage
[[ "$ENV" != "prod" && "$ENV" != "dev" && "$ENV" != "test" ]] && {
  echo "ERREUR : --env doit être prod, dev ou test"; exit 1
}
[[ "$MW_COUNT" -lt 3 ]] && {
  echo "ERREUR : --mw doit être >= 3"; exit 1
}

TARGET_DIR="${CLUSTERS_DIR}/${ENV}"
TFVARS="${TARGET_DIR}/terraform.tfvars"

[[ -f "$TFVARS" ]] && {
  echo "ERREUR : le cluster '${ENV}' existe déjà → ${TFVARS}"; exit 1
}

# ---- Formatage reserved_ips en HCL ----
if [[ -n "$RESERVED_IPS" ]]; then
  IFS=',' read -ra IPS <<< "$RESERVED_IPS"
  RESERVED_HCL="["
  for ip in "${IPS[@]}"; do
    RESERVED_HCL+="\"${ip}\", "
  done
  RESERVED_HCL="${RESERVED_HCL%, }]"
else
  RESERVED_HCL="[]"
fi

# ---- Création du dossier et du tfvars ----
mkdir -p "$TARGET_DIR"

cat > "$TFVARS" <<HCL
#############################################
# DEVVER-K8S-$(echo "$ENV" | tr '[:lower:]' '[:upper:]')
# Généré par new-cluster.sh le $(date +%Y-%m-%d)
#
# Secrets à passer en variables d'environnement :
#   export TF_VAR_proxmox_api_token_secret="..."
#   export TF_VAR_ssh_public_key="ssh-ed25519 AAAA..."
#############################################

cluster_env         = "${ENV}"
master_worker_count = ${MW_COUNT}
worker_count        = ${WORKER_COUNT}

# IPs déjà utilisées sur 192.168.45.0/24
reserved_ips = ${RESERVED_HCL}
HCL

# ---- Mise à jour du registre ----
cat >> "$REGISTRY" <<YAML

  - name: DEVVER-K8S-$(echo "$ENV" | tr '[:lower:]' '[:upper:]')
    env: ${ENV}
    master_worker_count: ${MW_COUNT}
    worker_count: ${WORKER_COUNT}
    provisioned_ips: []
    loadbalancer_ip: ""
    status: pending
YAML

echo ""
echo "✓ Cluster créé : ${TFVARS}"
echo ""
echo "Déploiement :"
echo "  cd ${CLUSTERS_DIR}"
echo "  export TF_VAR_proxmox_api_token_secret='...'"
echo "  export TF_VAR_ssh_public_key='ssh-ed25519 AAAA...'"
echo "  terraform workspace new ${ENV}"
echo "  terraform plan  -var-file=${ENV}/terraform.tfvars"
echo "  terraform apply -var-file=${ENV}/terraform.tfvars"
echo ""
echo "Après apply, reporter les IPs dans le registre :"
echo "  terraform output provisioned_ips"
