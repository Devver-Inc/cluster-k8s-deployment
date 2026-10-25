# Structure Vault des secrets APPLICATIFS des clusters (≠ devver-infra-deployment,
# qui ne porte que les secrets d'infra : Proxmox, B2, SSH VM, kubeconfig).
#
#   kubernetes-cluster/<org>/<env>/<app>                   secrets de la stack Devver
#   kubernetes-cluster/<org>/<env>/clients/<namespace>/*   secrets des déploiements clients
#
# Consommés dans le cluster par External Secrets Operator (ESO) via l'auth
# Kubernetes k8s-<org>-<env> (un mount par cluster : CA + API propres).
#
# Ce Terraform ne crée QUE la structure (mount, auth, policies, roles) — jamais
# de valeur : le contenu est initialisé par ansible/playbooks/05-vault-k8s.yml
# (valeurs générées ou CHANGEME), puis complété à la main dans la console. Rien
# de secret n'atterrit donc dans le state.
#
# La config de l'auth (kubernetes_host, CA, token reviewer) n'existe qu'une
# fois RKE2 installé : elle est écrite par le même playbook 05, pas ici.

locals {
  # var.orgs contient TOUS les identifiants de cluster connus (y compris les
  # anciens sans suffixe d'env, ex: "prod", "test-vr-f2") : seuls ceux au
  # format <org>-<prod|staging|dev> reçoivent la structure Kubernetes, les
  # autres sont ignorés sans erreur.
  k8s_clusters = {
    for id in var.orgs : id => {
      org = regex(local.cluster_id_regex, id)[0]
      env = regex(local.cluster_id_regex, id)[1]
    } if can(regex(local.cluster_id_regex, id))
  }

  cluster_id_regex = "^([a-z0-9][a-z0-9-]*)-(prod|staging|dev)$"
}

resource "vault_mount" "kubernetes_cluster" {
  path        = "kubernetes-cluster"
  type        = "kv-v2"
  description = "Secrets applicatifs des clusters Kubernetes : <org>/<env>/<app> et <org>/<env>/clients/<namespace>/*"

  depends_on = [vault_policy.ci]
}

# --- Auth Kubernetes : un mount par cluster -----------------------------------

resource "vault_auth_backend" "k8s" {
  for_each = local.k8s_clusters

  type        = "kubernetes"
  path        = "k8s-${each.key}"
  description = "Auth Kubernetes du cluster ${each.key} (config écrite par ansible/playbooks/05-vault-k8s.yml)"

  depends_on = [vault_policy.ci]
}

# --- Policies -------------------------------------------------------------------

# ESO plateforme (ClusterSecretStore vault-platform) : toute la stack du
# cluster, SAUF les dossiers clients.
resource "vault_policy" "k8s_platform" {
  for_each = local.k8s_clusters

  name = "k8s-${each.key}-platform"

  policy = <<-EOT
    path "kubernetes-cluster/data/${each.value.org}/${each.value.env}/*" {
      capabilities = ["read"]
    }

    path "kubernetes-cluster/data/${each.value.org}/${each.value.env}/clients/*" {
      capabilities = ["deny"]
    }
  EOT

  depends_on = [vault_policy.ci]
}

# ESO ghcr (ClusterSecretStore vault-ghcr) : uniquement le pull secret GHCR,
# distribué dans tous les namespaces (y compris clients) par un ClusterExternalSecret.
resource "vault_policy" "k8s_ghcr" {
  for_each = local.k8s_clusters

  name = "k8s-${each.key}-ghcr"

  policy = <<-EOT
    path "kubernetes-cluster/data/${each.value.org}/${each.value.env}/ghcr" {
      capabilities = ["read"]
    }
  EOT

  depends_on = [vault_policy.ci]
}

# ESO tenant (SecretStore "vault" dans chaque namespace client) : policy
# templatée — un namespace ne lit QUE clients/<son propre namespace>/*.
# Le namespace vient des métadonnées de l'alias d'entité créé au login k8s.
resource "vault_policy" "k8s_tenant" {
  for_each = local.k8s_clusters

  name = "k8s-${each.key}-tenant"

  policy = <<-EOT
    path "kubernetes-cluster/data/${each.value.org}/${each.value.env}/clients/{{identity.entity.aliases.${vault_auth_backend.k8s[each.key].accessor}.metadata.service_account_namespace}}/*" {
      capabilities = ["read"]
    }
  EOT

  depends_on = [vault_policy.ci]
}

# Backend Devver : écrit/supprime les secrets des déploiements clients
# (voir Devver-Inc/kubernetes docs/vault-integration-backend.md).
resource "vault_policy" "k8s_backend" {
  for_each = local.k8s_clusters

  name = "k8s-${each.key}-backend"

  policy = <<-EOT
    path "kubernetes-cluster/data/${each.value.org}/${each.value.env}/clients/*" {
      capabilities = ["create", "read", "update", "delete"]
    }

    path "kubernetes-cluster/metadata/${each.value.org}/${each.value.env}/clients/*" {
      capabilities = ["list", "read", "delete"]
    }

    path "auth/token/lookup-self" {
      capabilities = ["read"]
    }

    path "auth/token/renew-self" {
      capabilities = ["update"]
    }
  EOT

  depends_on = [vault_policy.ci]
}

# --- Roles de l'auth Kubernetes --------------------------------------------------
# Les ServiceAccounts eso-platform / eso-ghcr sont créés par
# le chart platform-secrets ; vault-reader / vault-reader-mongo par les charts
# clients helm-chart-deployment-template / helm-chart-mongo-template
# (Devver-Inc/kubernetes) — deux Applications Argo distinctes, d'où deux SA.

resource "vault_kubernetes_auth_backend_role" "eso_platform" {
  for_each = local.k8s_clusters

  backend                          = vault_auth_backend.k8s[each.key].path
  role_name                        = "eso-platform"
  bound_service_account_names      = ["eso-platform"]
  bound_service_account_namespaces = ["external-secrets-system"]
  token_policies                   = [vault_policy.k8s_platform[each.key].name]
  token_ttl                        = 3600
}

resource "vault_kubernetes_auth_backend_role" "eso_ghcr" {
  for_each = local.k8s_clusters

  backend                          = vault_auth_backend.k8s[each.key].path
  role_name                        = "eso-ghcr"
  bound_service_account_names      = ["eso-ghcr"]
  bound_service_account_namespaces = ["external-secrets-system"]
  token_policies                   = [vault_policy.k8s_ghcr[each.key].name]
  token_ttl                        = 3600
}

resource "vault_kubernetes_auth_backend_role" "eso_tenant" {
  for_each = local.k8s_clusters

  backend                          = vault_auth_backend.k8s[each.key].path
  role_name                        = "eso-tenant"
  bound_service_account_names      = ["vault-reader", "vault-reader-mongo"]
  bound_service_account_namespaces = ["*"]
  token_policies                   = [vault_policy.k8s_tenant[each.key].name]
  token_ttl                        = 3600
}

# --- AppRole du backend Devver ----------------------------------------------------
# Mount séparé de terraform-orgs (réservé à l'infra). Le secret_id n'est pas
# géré ici (il serait dans le state) : généré par le playbook 05 et déposé
# dans kubernetes-cluster/<org>/<env>/backend (VAULT_ROLE_ID / VAULT_SECRET_ID).

resource "vault_auth_backend" "devver_apps" {
  type        = "approle"
  path        = "devver-apps"
  description = "AppRole des applications Devver (backend) — écriture des secrets clients"

  depends_on = [vault_policy.ci]
}

resource "vault_approle_auth_backend_role" "backend" {
  for_each = local.k8s_clusters

  backend        = vault_auth_backend.devver_apps.path
  role_name      = "backend-${each.key}"
  token_policies = [vault_policy.k8s_backend[each.key].name]
  token_ttl      = 3600
  token_max_ttl  = 14400
}
