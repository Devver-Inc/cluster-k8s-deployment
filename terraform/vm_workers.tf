
resource "proxmox_vm_qemu" "workers" {
  count       = var.worker_count
  name        = "k8s-worker-${count.index + 1}"
  target_node = var.node
  clone       = var.vm_template

  vmid = 45000 + tonumber(regex(".*\\.(\\d+)$", local.workers_ips[count.index])[0])

  cores  = 2
  memory = 4096

  disks {
  scsi {
    scsi0 { disk { storage = "SSD-PVE-DATA" size = "40G" } }
    scsi1 { disk { storage = "SSD-PVE-DATA" size = "150G" } } # pour workers
  }
  ide {
    ide1 { cloudinit { storage = "SSD-PVE-DATA" } }
  }
}


  network {
    model  = "virtio"
    bridge = "vmbr0"
    ip     = "${local.workers_ips[count.index]}/24"
    gw     = var.gateway
  }

  sshkeys = file("secrets/automation_key.pub")

  cloudinit_userdata = data.template_file.user_data[count.index + var.master_count].rendered
}
