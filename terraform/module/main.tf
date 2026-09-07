data "proxmox_virtual_environment_vms" "template" {
  node_name = var.proxmox_node
  tags      = []

  filter {
    name   = "name"
    values = [var.template_name]
  }
}

resource "proxmox_virtual_environment_vm" "mixed" {
  for_each = local.mixed_nodes

  name      = each.value.hostname
  node_name = var.proxmox_node
  vm_id     = each.value.vmid
  machine   = "q35"

  clone {
    vm_id        = data.proxmox_virtual_environment_vms.template.vms[0].vm_id
    full         = true
    datastore_id = var.datastore_id
  }

  cpu {
    cores = var.master_cpu_cores
    type  = "host"
  }

  memory {
    dedicated = var.master_memory
  }

  disk {
    datastore_id = var.datastore_id
    interface    = "scsi0"
    size         = var.master_disk_size
    discard      = "on"
    iothread     = true
  }

  network_device {
    bridge  = "vmbr1"
    model   = "virtio"
    vlan_id = 45
  }

  initialization {
    datastore_id = var.datastore_id

    dns {
      servers = ["1.1.1.1", "1.0.0.1"]
    }

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

  agent {
    enabled = true
  }

  tags = concat(var.tags, ["K8s", "master"])

  on_boot = true
  started = true
}

resource "proxmox_virtual_environment_vm" "worker_only" {
  for_each = local.worker_only_nodes

  name      = each.value.hostname
  node_name = var.proxmox_node
  vm_id     = each.value.vmid
  machine   = "q35"

  clone {
    vm_id        = data.proxmox_virtual_environment_vms.template.vms[0].vm_id
    full         = true
    datastore_id = var.datastore_id
  }

  cpu {
    cores = var.worker_cpu_cores
    type  = "host"
  }

  memory {
    dedicated = var.worker_memory
  }

  disk {
    datastore_id = var.datastore_id
    interface    = "scsi0"
    size         = var.worker_disk_size
    discard      = "on"
    iothread     = true
  }

  disk {
    datastore_id = var.datastore_id
    interface    = "scsi1"
    size         = var.worker_extra_disk_size
    discard      = "on"
    iothread     = true
  }

  network_device {
    bridge  = "vmbr1"
    model   = "virtio"
    vlan_id = 45
  }

  initialization {
    datastore_id = var.datastore_id

    dns {
      servers = ["1.1.1.1", "1.0.0.1"]
    }

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

  agent {
    enabled = true
  }

  tags = concat(var.tags, ["K8s", "worker"])

  on_boot = true
  started = true
}
