
data "templatefile" "hosts" {
  template = file("${path.module}/templates/hosts.tpl")

  vars = {
    masters = local.masters_ips
    workers = local.workers_ips
  }
}

resource "local_file" "inventory" {
  filename = "../ansible/inventory/cluster1/hosts.yaml"
  content  = data.templatefile.hosts.rendered
}
