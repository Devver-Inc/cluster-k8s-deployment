
locals {
  parse_octet = {
    masters_start = tonumber(regex(".*\\.(\\d+)$", var.masters_range_start)[0])
    masters_end   = tonumber(regex(".*\\.(\\d+)$", var.masters_range_end)[0])
    workers_start = tonumber(regex(".*\\.(\\d+)$", var.workers_range_start)[0])
    workers_end   = tonumber(regex(".*\\.(\\d+)$", var.workers_range_end)[0])
  }

  masters_pool = [
    for i in range(local.parse_octet.masters_start, local.parse_octet.masters_end + 1) :
    "192.168.45.${i}"
  ]

  workers_pool = [
    for i in range(local.parse_octet.workers_start, local.parse_octet.workers_end + 1) :
    "192.168.45.${i}"
  ]

  masters_ips = slice(local.masters_pool, 0, var.master_count)
  workers_ips = slice(local.workers_pool, 0, var.worker_count)
}
