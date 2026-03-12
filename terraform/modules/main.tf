#############################################
# Nœuds MASTER+WORKER — DEVVER-K8S-{ENV}-MW-{n}
# Rôle K8s : control-plane + worker
#############################################

resource "proxmox_vm_qemu" "master_worker" {
  for_each = local.mw_nodes

  # VMID : 3e octet + 4e octet de l'IP (ex: 192.168.45.100 → 45100)
  vmid        = tonumber("${split(".", each.value.ip)[2]}${split(".", each.value.ip)[3]}")
  name        = each.value.name
  target_node = var.target_node
  agent       = 1
  clone       = var.vm_template
  scsihw      = "virtio-scsi-single"
  vm_state    = "running"
  automatic_reboot = true

  cpu {
    cores   = var.mw_cores
    sockets = 1
  }
  memory = var.mw_memory_mb

  cicustom   = "vendor=local:snippets/qemu-guest-agent.yml"
  ciupgrade  = true
  skip_ipv6  = true
  ciuser     = var.vm_user
  nameserver = var.nameservers
  ipconfig0  = "ip=${each.value.ip}/24,gw=${var.gateway}"
  sshkeys    = var.ssh_public_key

  serial { id = 0 }

  disks {
    scsi {
      scsi0 {
        disk {
          storage = var.storage
          size    = var.mw_disk_os_gb
        }
      }
      scsi1 {
        disk {
          storage = var.storage
          size    = var.mw_disk_data_gb
        }
      }
    }
    ide {
      ide1 {
        cloudinit {
          storage = var.storage
        }
      }
    }
  }

  network {
    id     = 0
    bridge = var.network_bridge
    model  = "virtio"
    tag    = var.network_tag
  }

  tags = "${local.tag_base};master-worker"
}

#############################################
# Nœuds WORKER seuls — DEVVER-K8S-{ENV}-W-{n}
# Rôle K8s : worker uniquement
#############################################

resource "proxmox_vm_qemu" "worker" {
  for_each = local.w_nodes

  vmid        = tonumber("${split(".", each.value.ip)[2]}${split(".", each.value.ip)[3]}")
  name        = each.value.name
  target_node = var.target_node
  agent       = 1
  clone       = var.vm_template
  scsihw      = "virtio-scsi-single"
  vm_state    = "running"
  automatic_reboot = true

  cpu {
    cores   = var.w_cores
    sockets = 1
  }
  memory = var.w_memory_mb

  cicustom   = "vendor=local:snippets/qemu-guest-agent.yml"
  ciupgrade  = true
  skip_ipv6  = true
  ciuser     = var.vm_user
  nameserver = var.nameservers
  ipconfig0  = "ip=${each.value.ip}/24,gw=${var.gateway}"
  sshkeys    = var.ssh_public_key

  serial { id = 0 }

  disks {
    scsi {
      scsi0 {
        disk {
          storage = var.storage
          size    = var.w_disk_os_gb
        }
      }
      scsi1 {
        disk {
          storage = var.storage
          size    = var.w_disk_data_gb
        }
      }
    }
    ide {
      ide1 {
        cloudinit {
          storage = var.storage
        }
      }
    }
  }

  network {
    id     = 0
    bridge = var.network_bridge
    model  = "virtio"
    tag    = var.network_tag
  }

  tags = "${local.tag_base};worker"
}
