module "k8s_cluster" {
  source = "../modules"

  cluster_env         = var.cluster_env
  master_worker_count = var.master_worker_count
  worker_count        = var.worker_count

  subnet       = var.subnet
  mw_ip_base   = var.mw_ip_base
  lb_ip_offset = var.lb_ip_offset

  gateway        = var.gateway
  nameservers    = var.nameservers
  network_bridge = var.network_bridge
  network_tag    = var.network_tag

  target_node = var.target_node
  storage     = var.storage
  vm_template = var.vm_template

  vm_user        = var.vm_user
  ssh_public_key = var.ssh_public_key

  mw_cores        = var.mw_cores
  mw_memory_mb    = var.mw_memory_mb
  mw_disk_os_gb   = var.mw_disk_os_gb
  mw_disk_data_gb = var.mw_disk_data_gb

  w_cores        = var.w_cores
  w_memory_mb    = var.w_memory_mb
  w_disk_os_gb   = var.w_disk_os_gb
  w_disk_data_gb = var.w_disk_data_gb
}