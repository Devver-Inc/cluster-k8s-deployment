
data "template_file" "user_data" {
  for_each = {
    for i in range(var.master_count + var.worker_count) :
    i => "node-${i}"
  }

  template = file("${path.module}/templates/user-data.tpl")

  vars = {
    ssh_username = var.ssh_username
    ssh_pub      = file("secrets/automation_key.pub")
    hostname     = "node-${each.key}"
  }
}
