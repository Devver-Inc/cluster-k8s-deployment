#############################################
# Déploiement des WORKER NODES
#############################################

resource "proxmox_vm_qemu" "workers" {
  for_each = toset(var.worker_ips)

  # VMID basé sur IP
  vmid = tonumber("${split(".", each.value)[2]}${split(".", each.value)[3]}")

  # Nom : DEVVER-KUB-WORKER-1 / WORKER-2 …
  name = "DEVVER-KUB-WORKER-${local.worker_map[each.value] + 1}"

  target_node = var.target_node
  agent       = 1

  # CONFIGURATION SPÉCIFIQUE WORKER
  cpu {
  cores = 4
  sockets = 1
}
  memory      = 4096
  clone       = "debian13-cloudinit"
  scsihw      = "virtio-scsi-single"
  vm_state    = "running"
  automatic_reboot = true

 # IP cloud-init
  cicustom   = "vendor=local:snippets/qemu-guest-agent.yml" # /var/lib/vz/snippets/qemu-guest-agent.yml
  ciupgrade  = true
  skip_ipv6  = true
  ciuser     = "user"
  cipassword = "user"
  nameserver = "1.1.1.1 8.8.8.8"
  ipconfig0 = "ip=${each.value}/24,gw=192.168.45.200"
  sshkeys = local.public_key

  serial { id = 0 }

  disks {
    scsi {
      scsi0 {
        disk {
          storage = "SSD-PVE-DATA"
          size    = "40G"
        }
      
    }
    scsi1 {
        disk {
          storage = "SSD-PVE-DATA"
          size    = "150G"
        }   
    }
  }
    ide {
      # Some images require a cloud-init disk on the IDE controller, others on the SCSI or SATA controller
      ide1 {
        cloudinit {
          storage = "SSD-PVE-DATA"
        }
      }
    }
  }

  network {
    id     = 0
    bridge = "vmbr1"
    model  = "virtio"
    tag    = 45
  }
}
