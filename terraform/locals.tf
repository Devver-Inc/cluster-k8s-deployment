#############################################
# Locals pour générer les indexes automatiques
#############################################

locals {

  # Map IP → index (ex: "192.168.45.10" => 0)
  master_map = {
    for idx, ip in var.master_ips :
    ip => idx
  }

  worker_map = {
    for idx, ip in var.worker_ips :
    ip => idx
  }

  public_key = file("~/.ssh/yes.pub")


}
