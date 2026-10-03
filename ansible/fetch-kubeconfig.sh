#!/usr/bin/env bash
# Récupère kubeconfig depuis Vault (devver-infra-deployment/<org>) et l'écrit
# dans un fichier temporaire local, utilisé comme KUBECONFIG pour les
# commandes kubectl (drain, delete node) du job remove-worker — avant que
# Terraform ne détruise la VM du worker concerné.
#
# La clé est TOUJOURS supprimée en sortie (trap EXIT), y compris en cas
# d'échec du script ou de la suite du job — jamais laissée sur le disque du
# runner au-delà de l'exécution. Même pattern que fetch-ssh-key.sh.
#
# Usage : source fetch-kubeconfig.sh <org>
# Prérequis : VAULT_ADDR, VAULT_TOKEN (ou VAULT_ROLE_ID/VAULT_SECRET_ID),
# CLI vault + kubectl installés. Volontairement pas de "set -e" (script
# sourcé, cf. fetch-ssh-key.sh).

org="${1:?Usage: source fetch-kubeconfig.sh <org>}"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
kubeconfig_file="${script_dir}/.kubeconfig_${org}"

export VAULT_ADDR="${VAULT_ADDR:-https://vault.devver.app}"
VAULT_ADDR="$(printf '%s' "${VAULT_ADDR}" | tr -d '\r\n')"
export VAULT_ADDR

if [[ -z "${VAULT_TOKEN:-}" ]]; then
  if [[ -z "${VAULT_ROLE_ID:-}" || -z "${VAULT_SECRET_ID:-}" ]]; then
    echo "fetch-kubeconfig.sh: exporter VAULT_TOKEN, ou VAULT_ROLE_ID + VAULT_SECRET_ID." >&2
    return 1 2>/dev/null || true
  fi
  VAULT_TOKEN=$(vault write -field=token auth/terraform-orgs/login \
    role_id="${VAULT_ROLE_ID}" secret_id="${VAULT_SECRET_ID}")
  if [[ -z "${VAULT_TOKEN}" ]]; then
    echo "fetch-kubeconfig.sh: échec du login AppRole." >&2
    return 1 2>/dev/null || true
  fi
  export VAULT_TOKEN
fi

fetched_kubeconfig=$(vault kv get -field=kubeconfig "devver-infra-deployment/${org}")
if [[ -z "${fetched_kubeconfig}" ]]; then
  echo "fetch-kubeconfig.sh: échec de lecture de kubeconfig sur devver-infra-deployment/${org} (cluster pas encore initialisé ?)." >&2
  return 1 2>/dev/null || true
fi

printf '%s\n' "${fetched_kubeconfig}" > "${kubeconfig_file}"
chmod 600 "${kubeconfig_file}"
unset fetched_kubeconfig

# Garde-fou : même principe que ssh-keygen -lf pour la clé SSH — valide le
# format sans jamais afficher le contenu (pas de kubectl get, juste un
# parsing de config).
if ! kubectl --kubeconfig="${kubeconfig_file}" config view >/dev/null 2>&1; then
  echo "fetch-kubeconfig.sh: kubeconfig lu depuis Vault n'est pas un format valide." >&2
  return 1 2>/dev/null || true
fi

export KUBECONFIG="${kubeconfig_file}"

cleanup_kubeconfig() {
  rm -f "${kubeconfig_file}"
}
trap cleanup_kubeconfig EXIT

echo "fetch-kubeconfig.sh: kubeconfig écrit dans ${kubeconfig_file} (supprimé en fin de shell), KUBECONFIG exporté."
