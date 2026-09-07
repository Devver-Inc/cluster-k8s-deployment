# Backend S3 compatible Backblaze B2 — même bucket que les autres states,
# key dédiée à ce state (config Vault, séparé des clusters).
# Les clés d'accès B2 (keyID/applicationKey) passent par AWS_ACCESS_KEY_ID /
# AWS_SECRET_ACCESS_KEY en variables d'environnement, jamais ici.
#
# NOTE : key volontairement laissée à "setup-vault-for-terraform/..." malgré le
# renommage du dossier en vault/ — c'est la clé du state DÉJÀ existant sur B2 ;
# la changer casserait l'accès au state réel. Le nom de la clé S3 est indépendant
# du nom du dossier local.

bucket = "devver-tfstate"
key    = "setup-vault-for-terraform/terraform.tfstate"
region = "eu-central-003" # ex: eu-central-003
endpoints = {
  s3 = "https://s3.eu-central-003.backblazeb2.com" # ex: https://s3.eu-central-003.backblazeb2.com
}

skip_credentials_validation = true
skip_region_validation      = true
skip_requesting_account_id  = true
skip_s3_checksum             = true
use_path_style                = true
