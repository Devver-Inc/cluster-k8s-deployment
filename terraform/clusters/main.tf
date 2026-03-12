module "k8s_cluster" {
  source = "../modules"

  cluster_env         = var.cluster_env
  master_worker_count = var.master_worker_count
  worker_count        = var.worker_count

  subnet                = var.subnet
  mw_ip_base_prod      = var.mw_ip_base_prod
  lb_ip_offset_prod    = var.lb_ip_offset_prod
  mw_ip_base_staging   = var.mw_ip_base_staging
  lb_ip_offset_staging = var.lb_ip_offset_staging
  mw_ip_base_dev       = var.mw_ip_base_dev
  lb_ip_offset_dev     = var.lb_ip_offset_dev
  mw_ip_base_test      = var.mw_ip_base_test
  lb_ip_offset_test    = var.lb_ip_offset_test

  gateway        = var.gateway
  nameservers    = var.nameservers
  network_bridge = var.network_bridge
  network_tag    = var.network_tag

  target_node = var.target_node
  storage     = var.storage
  vm_template = var.vm_template
  vm_template_id = var.vm_template_id

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