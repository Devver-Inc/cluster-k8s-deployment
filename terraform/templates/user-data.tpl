#cloud-config
users:
  - name: ${ssh_username}
    sudo: ALL=(ALL) NOPASSWD:ALL
    ssh_authorized_keys:
      - ${ssh_pub}
hostname: ${hostname}
