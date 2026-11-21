# DNS du cluster dans Cloudflare : le domaine du cluster et son wildcard, en
# CNAME vers le reverse proxy frontal. Deux enregistrements par cluster au lieu
# d'un par application ; supprimés par terraform destroy avec le cluster.
#
# proxied = false : le certificat Cloudflare ne couvre qu'un niveau
# (*.devver.app) — ce sont les certificats Let's Encrypt du cluster qui servent.
#
# Prod (domaine = base_domain) : supprimer l'ancien enregistrement devver.app
# AVANT de créer le cluster, sinon la création échoue (nom déjà pris).

data "cloudflare_zone" "base" {
  name = var.base_domain
}

locals {
  dns_names = var.dns_records ? toset([local.cluster_domain, "*.${local.cluster_domain}"]) : toset([])
}

resource "cloudflare_record" "cluster" {
  for_each = local.dns_names

  zone_id = data.cloudflare_zone.base.id
  name    = each.value
  type    = "CNAME"
  content = var.dns_target
  proxied = false
  ttl     = 1
  comment = "Géré par Terraform — cluster ${local.cluster_id}"

  lifecycle {
    precondition {
      condition     = local.cluster_domain == var.base_domain || endswith(local.cluster_domain, ".${var.base_domain}")
      error_message = "Le domaine du cluster (${local.cluster_domain}) doit être ${var.base_domain} ou un de ses sous-domaines : le token Cloudflare n'a accès qu'à cette zone."
    }
  }
}
