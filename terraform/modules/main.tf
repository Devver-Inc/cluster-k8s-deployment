#############################################
# Nœuds MASTER+WORKER — DEVVER-K8S-{ENV}-MW-{n}
# Rôle K8s : control-plane + worker
#############################################

resource "proxmox_virtual_environment_vm" "master_worker" {
  for_each = local.mw_nodes

  # VMID : calculé automatiquement de l'IP (3e octet + 4e octet)
  # Ex: 192.168.45.110 → VMID 45110
  # Permet un mapping déterministe IP → VMID
  vm_id       = tonumber("${split(".", each.value.ip)[2]}${split(".", each.value.ip)[3]}")
  name        = each.value.name
  node_name   = var.target_node
  started     = true
  description = "Kubernetes Master+Worker - ${var.cluster_env}"

  cpu {
    cores   = var.mw_cores
    sockets = 1
    type    = "x86-64-v2-AES"
  }

  memory {
    dedicated = var.mw_memory_mb
  }

  clone {
    vm_id = var.vm_template_id
    full  = true
  }

  agent {
    enabled = true
    timeout = "15m"
    trim    = false
    type    = "virtio"
  }

  scsi_hardware = "virtio-scsi-single"
  boot_order    = ["scsi0"]
  lifecycle {
    ignore_changes = [boot_order]
  }

  disk {
    datastore_id = var.storage
    size         = var.mw_disk_os_gb
    interface    = "scsi0"
    iothread     = true
  }

  disk {
    datastore_id = var.storage
    size         = var.mw_disk_data_gb
    interface    = "scsi1"
    iothread     = true
  }

  network_device {
    bridge = var.network_bridge
    vlan_id = var.network_tag
  }

  initialization {
    datastore_id         = var.storage
    vendor_data_file_id  = "local:snippets/qemu-guest-agent.yml"

    ip_config {
      ipv4 {
        address = "${each.value.ip}/24"
        gateway = var.gateway
      }
    }

    user_account {
      username = var.vm_user
      keys     = [var.ssh_public_key]
    }
  }

  tags = concat(local.tag_base, var.additional_tags, ["master-worker"])
}

#############################################
# Nœuds WORKER seuls — DEVVER-K8S-{ENV}-W-{n}
# Rôle K8s : worker uniquement
#############################################

resource "proxmox_virtual_environment_vm" "worker" {
  for_each = local.w_nodes

  vm_id       = tonumber("${split(".", each.value.ip)[2]}${split(".", each.value.ip)[3]}")
  name        = each.value.name
  node_name   = var.target_node
  started     = true
  description = "Kubernetes Worker - ${var.cluster_env}"

  cpu {
    cores   = var.w_cores
    sockets = 1
    type    = "x86-64-v2-AES"
  }

  memory {
    dedicated = var.w_memory_mb
  }

  clone {
    vm_id = var.vm_template_id
    full  = true
  }

  agent {
    enabled = true
    timeout = "15m"
    trim    = false
    type    = "virtio"
  }

  scsi_hardware = "virtio-scsi-single"
  boot_order    = ["scsi0"]

  lifecycle {
    ignore_changes = [boot_order]
  }

  disk {
    datastore_id = var.storage
    size         = var.w_disk_os_gb
    interface    = "scsi0"
    iothread     = true
  }

  disk {
    datastore_id = var.storage
    size         = var.w_disk_data_gb
    interface    = "scsi1"
    iothread     = true
  }

  network_device {
    bridge = var.network_bridge
    vlan_id = var.network_tag
  }

  initialization {
    datastore_id         = var.storage
    vendor_data_file_id  = "local:snippets/qemu-guest-agent.yml"

    ip_config {
      ipv4 {
        address = "${each.value.ip}/24"
        gateway = var.gateway
      }
    }

    user_account {
      username = var.vm_user
      keys     = [var.ssh_public_key]
    }
  }

  tags = concat(local.tag_base, var.additional_tags, ["worker"])
}
