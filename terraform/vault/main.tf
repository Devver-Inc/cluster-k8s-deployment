# Secrets engine KV v2 partagé par toutes les orgs :
# - devver-infra-deployment/proxmox            : credentials API Proxmox (partagé)
# - devver-infra-deployment/s3-backend         : credentials B2 (keyID/applicationKey) pour le backend S3 (partagé)
# - devver-infra-deployment/ansible            : réservé, pas encore utilisé par ce Terraform
# - devver-infra-deployment/vm_secret_template : vm_user + ssh_public_key + vm_password/ssh_private_key
#                                                 (placeholders) "template", cloné vers <org> une seule fois
# - devver-infra-deployment/<org>              : copie du template pour cette org — créée une seule fois par ce
#                                                 Terraform (lifecycle ignore_changes). Les placeholders vm_password
#                                                 et ssh_private_key du template atterrissent dans le state à cette
#                                                 création, mais toute valeur remplacée ensuite à la main dans l'UI
#                                                 Vault n'y remonte plus jamais — Terraform ignore ce secret après
#                                                 sa création.
resource "vault_mount" "devver_infra_deployment" {
  path = "devver-infra-deployment"
  type = "kv-v2"
}

# Policy + role AppRole dédiés au "bootstrap" : uniquement de quoi lire les
# credentials B2, utilisés AVANT terraform init (le backend S3 doit être
# configuré avant que Terraform puisse évaluer la moindre data source Vault —
# les credentials B2 ne peuvent donc jamais être lues via une data source Vault
# dans le module lui-même, seulement récupérées à part avant l'init).
resource "vault_policy" "backblaze_ro" {
  name = "terraform-backblaze-ro"

  policy = <<-EOT
    path "devver-infra-deployment/data/s3-backend" {
      capabilities = ["read"]
    }

    path "devver-infra-deployment/metadata/s3-backend" {
      capabilities = ["list", "read"]
    }
  EOT
}

resource "vault_approle_auth_backend_role" "backblaze" {
  backend        = vault_auth_backend.approle.path
  role_name      = "terraform-backblaze"
  token_policies = [vault_policy.backblaze_ro.name]
  token_ttl      = 300
  token_max_ttl  = 900
}

# Clone devver-infra-deployment/vm_secret_template vers devver-infra-deployment/<org>,
# une seule fois à la création de l'org. lifecycle.ignore_changes garantit qu'aucun
# apply ultérieur (même pour d'autres orgs) ne réécrase ce secret — les vraies valeurs
# de vm_password/ssh_private_key que tu écris ensuite à la main dans l'UI Vault (à la
# place des placeholders du template) sont préservées indéfiniment et ne remontent
# plus jamais dans le state. Ce Terraform (admin) est le seul à écrire ici ; les
# clusters ne font que lire via leur policy read-only (voir vault_policy.org_ro plus bas).
data "vault_kv_secret_v2" "vm_secret_template" {
  mount = "devver-infra-deployment"
  name  = "vm_secret_template"
}

resource "vault_kv_secret_v2" "org_secret" {
  for_each = toset(var.orgs)

  mount = vault_mount.devver_infra_deployment.path
  name  = each.key

  data_json = jsonencode({
    vm_user         = data.vault_kv_secret_v2.vm_secret_template.data["vm_user"]
    ssh_public_key  = data.vault_kv_secret_v2.vm_secret_template.data["ssh_public_key"]
    vm_password     = data.vault_kv_secret_v2.vm_secret_template.data["vm_password"]
    ssh_private_key = data.vault_kv_secret_v2.vm_secret_template.data["ssh_private_key"]
  })

  lifecycle {
    ignore_changes = [data_json]
  }
}

# Policy read-only par org, limitée à devver-infra-deployment/proxmox + devver-infra-deployment/<org>.
# auth/token/create est nécessaire même en lecture seule : le provider Vault de
# Terraform crée un child token limité à partir du token AppRole obtenu au login.
resource "vault_policy" "org_ro" {
  for_each = toset(var.orgs)

  name = "terraform-${each.key}-ro"

  policy = <<-EOT
    path "devver-infra-deployment/data/proxmox" {
      capabilities = ["read"]
    }

    path "devver-infra-deployment/metadata/proxmox" {
      capabilities = ["list", "read"]
    }

    path "devver-infra-deployment/data/${each.key}" {
      capabilities = ["read"]
    }

    path "devver-infra-deployment/metadata/${each.key}" {
      capabilities = ["list", "read"]
    }

    path "auth/token/create" {
      capabilities = ["create", "update"]
    }

    path "auth/token/lookup-self" {
      capabilities = ["read"]
    }

    path "auth/token/renew-self" {
      capabilities = ["update"]
    }
  EOT
}

resource "vault_auth_backend" "approle" {
  type        = "approle"
  path        = "terraform-orgs"
  description = "AppRole utilisé par les modules Terraform de cluster-k8s-deployment (vault/ + clusters/<org>) pour s'authentifier auprès de Vault."
}

resource "vault_approle_auth_backend_role" "org" {
  for_each = toset(var.orgs)

  backend        = vault_auth_backend.approle.path
  role_name      = "terraform-${each.key}"
  token_policies = [vault_policy.org_ro[each.key].name]
  token_ttl      = 3600
  token_max_ttl  = 14400
}

# Policy + role AppRole dédiés à la pipeline CI (deploy-cluster.yml) — un seul
# role pour piloter à la fois vault/ (structure) et l'apply/destroy infra de
# TOUTES les orgs, car GitHub Actions ne permet pas de référencer un secret
# GitHub par un nom construit dynamiquement (un role par org obligerait à
# modifier le workflow à chaque ajout/suppression d'org, cf. terraform/README.md).
#
# Portée quasi-admin (gère les mounts/policies/auth backends Vault eux-mêmes,
# en plus de lire toutes les orgs) — à traiter avec la même prudence qu'un
# token root. Protégé par : usage exclusif sur le runner self-hosted, et gates
# d'approbation manuelle avant toute action sensible côté pipeline (voir
# deploy-cluster.yml). Le secret_id de ce role, comme pour tous les autres
# roles, n'est jamais géré par Terraform — généré à la main (DEPLOY.md), donc
# absent du state.
resource "vault_policy" "ci" {
  name = "terraform-ci"

  policy = <<-EOT
    path "sys/mounts/devver-infra-deployment" {
      capabilities = ["create", "read", "update", "delete", "sudo"]
    }

    path "sys/policies/acl/terraform-*" {
      capabilities = ["create", "read", "update", "delete", "list"]
    }

    # "list" sur le path exact (sans wildcard) est nécessaire pour l'opération
    # de liste globale elle-même (vault list sys/policies/acl) — le wildcard
    # ci-dessus ne couvre que la lecture des policies individuelles. Utilisé
    # par terraform/scripts/list-vault-orgs.sh pour déduire les orgs déjà
    # connues de Vault (comparaison état repo vs état Vault, cf. detect-org-change.sh).
    path "sys/policies/acl" {
      capabilities = ["list"]
    }

    path "sys/auth/terraform-orgs" {
      capabilities = ["create", "read", "update", "delete", "sudo"]
    }

    path "auth/terraform-orgs/role/*" {
      capabilities = ["create", "read", "update", "delete", "list"]
    }

    path "devver-infra-deployment/data/*" {
      capabilities = ["read"]
    }

    path "devver-infra-deployment/metadata/*" {
      capabilities = ["list", "read"]
    }

    path "auth/token/create" {
      capabilities = ["create", "update"]
    }

    path "auth/token/lookup-self" {
      capabilities = ["read"]
    }

    path "auth/token/renew-self" {
      capabilities = ["update"]
    }
  EOT
}

resource "vault_approle_auth_backend_role" "ci" {
  backend        = vault_auth_backend.approle.path
  role_name      = "terraform-ci"
  token_policies = [vault_policy.ci.name]
  token_ttl      = 3600
  token_max_ttl  = 14400
}
