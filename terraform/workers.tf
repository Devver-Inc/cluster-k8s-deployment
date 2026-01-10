resource "proxmox_vm_qemu" "workers" {
  for_each = { for ip in local.worker_ips : ip => ip }

  vmid = tonumber(join("", [split(".", each.key)[2], split(".", each.key)[3]]))
  name = "DEVVER-KUB-WORKER-${replace(each.key, ".", "-")}"
  target_node = var.target_node
  agent       = 1

  cpu {
    cores   = 4
    sockets = 1
  }
  memory      = 4096
  clone       = var.vm_template
  scsihw      = "virtio-scsi-single"
  vm_state    = "running"
  automatic_reboot = true

  cicustom   = "vendor=local:snippets/qemu-guest-agent.yml"
  ciupgrade  = true
  skip_ipv6  = true
  ciuser     = "devver"
  nameserver = var.nameserver
  ipconfig0  = "ip=${each.key}/24,gw=192.168.45.200"
  sshkeys    = file(var.public_key_path)

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
