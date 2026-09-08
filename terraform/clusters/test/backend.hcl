# Backend S3 compatible Backblaze B2 — même bucket que les autres states,
# key dédiée à ce cluster.

bucket = "devver-tfstate"
key    = "clusters/test/terraform.tfstate"
region = "eu-central-003"
endpoints = {
  s3 = "https://s3.eu-central-003.backblazeb2.com"
}

skip_credentials_validation = true
skip_region_validation      = true
skip_requesting_account_id  = true
skip_s3_checksum             = true
use_path_style                = true
