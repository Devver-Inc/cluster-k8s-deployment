#!/usr/bin/env bash
# Récupère ssh_private_key depuis Vault (devver-infra-deployment/<org>) et
# l'écrit dans un fichier temporaire local, référencé par
# ansible_ssh_private_key_file (group_vars/all.yml) — nécessaire car Ansible
# résout ce champ AVANT sa première connexion SSH, donc aucune tâche d'un
# playbook ne peut l'écrire à temps.
#
# La clé est TOUJOURS supprimée en sortie (trap EXIT), y compris en cas
# d'échec du script ou du run Ansible qui suit — jamais laissée sur le
# disque du runner au-delà de l'exécution.
#
# Usage : source fetch-ssh-key.sh <org>
# Prérequis : VAULT_ADDR, VAULT_TOKEN (ou VAULT_ROLE_ID/VAULT_SECRET_ID),
# CLI vault installé. Volontairement pas de "set -e" (script sourcé dans un
# shell interactif — un exit y fermerait le terminal), cf. terraform/login.sh.
#
# Isolation : exécuté à plat sur le runner self-hosted (comme Terraform,
# décision déjà actée dans terraform/DEPLOY.md) — la clé privée n'existe sur
# disque que le temps du run Ansible, jamais committée, toujours nettoyée.

org="${1:?Usage: source fetch-ssh-key.sh <org>}"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
key_file="${script_dir}/.ssh_key_${org}"

# VAULT_ADDR (vars.VAULT_ADDR côté GitHub Actions) peut arriver avec un \r
# de fin de ligne selon la façon dont la variable a été saisie/injectée — le
# CLI vault (contrairement à hashicorp/vault-action) ne le tolère pas
# ("invalid control character in URL"), d'où le nettoyage explicite.
export VAULT_ADDR="${VAULT_ADDR:-https://vault.devver.app}"
VAULT_ADDR="${VAULT_ADDR%$'\r'}"
export VAULT_ADDR

if [[ -z "${VAULT_TOKEN:-}" ]]; then
  if [[ -z "${VAULT_ROLE_ID:-}" || -z "${VAULT_SECRET_ID:-}" ]]; then
    echo "fetch-ssh-key.sh: exporter VAULT_TOKEN, ou VAULT_ROLE_ID + VAULT_SECRET_ID." >&2
    return 1 2>/dev/null || true
  fi
  VAULT_TOKEN=$(vault write -field=token auth/terraform-orgs/login \
    role_id="${VAULT_ROLE_ID}" secret_id="${VAULT_SECRET_ID}")
  if [[ -z "${VAULT_TOKEN}" ]]; then
    echo "fetch-ssh-key.sh: échec du login AppRole." >&2
    return 1 2>/dev/null || true
  fi
  export VAULT_TOKEN
fi

fetched_key=$(vault kv get -field=ssh_private_key "devver-infra-deployment/${org}")
if [[ -z "${fetched_key}" ]]; then
  echo "fetch-ssh-key.sh: échec de lecture de ssh_private_key sur devver-infra-deployment/${org}." >&2
  return 1 2>/dev/null || true
fi

printf '%s\n' "${fetched_key}" > "${key_file}"
chmod 600 "${key_file}"
unset fetched_key

# Nettoyage garanti à la sortie du shell (fin du run Ansible qui suit dans le
# même shell, ou toute erreur) — jamais laissée sur disque au-delà.
cleanup_ssh_key() {
  rm -f "${key_file}"
}
trap cleanup_ssh_key EXIT

echo "fetch-ssh-key.sh: clé SSH écrite dans ${key_file} (supprimée en fin de shell)."
