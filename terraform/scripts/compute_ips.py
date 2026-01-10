#!/usr/bin/env python3
import sys
import json
import re
import ipaddress

def ip_range(start, end):
    s = ipaddress.ip_address(start)
    e = ipaddress.ip_address(end)
    if s.version != 4 or e.version != 4:
        raise SystemExit(json.dumps({"error":"only IPv4 supported"}))
    ips = []
    cur = int(s)
    while cur <= int(e):
        ips.append(str(ipaddress.ip_address(cur)))
        cur += 1
    return ips

def used_ips_from_file(path):
    try:
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)
        used = []
        used += data.get("master_ips", [])
        used += data.get("worker_ips", [])
        return used
    except Exception:
        return []

def used_ips_from_allocated_json(path):
    return used_ips_from_file(path)

def pick_available(range_list, used, count):
    avail = [ip for ip in range_list if ip not in used]
    if len(avail) < count:
        raise SystemExit(json.dumps({"error": f"Not enough free IPs in range (need {count}, avail {len(avail)})"}))
    return avail[:count]

def main():
    payload = json.load(sys.stdin)
    m_start = payload.get("master_range_start")
    m_end = payload.get("master_range_end")
    w_start = payload.get("worker_range_start")
    w_end = payload.get("worker_range_end")
    m_count = int(payload.get("master_count", 0))
    w_count = int(payload.get("worker_count", 0))
    allocated_path = payload.get("allocated_ips_path", "./allocated_ips.json")

    prev_masters = []
    prev_workers = []
    try:
        with open(allocated_path, "r", encoding="utf-8") as f:
            data = json.load(f)
            prev_masters = list(dict.fromkeys(data.get("master_ips", [])))
            prev_workers = list(dict.fromkeys(data.get("worker_ips", [])))
    except Exception:
        pass

    # Start used set from previous allocations (de-duped)
    used = set(prev_masters + prev_workers)

    # Compute masters: keep previous allocations that are still in range, then add new ones
    masters = []
    if m_count > 0:
        full_range_m = ip_range(m_start, m_end)
        # keep previous masters that are still within range (preserve order)
        for ip in prev_masters:
            if ip in full_range_m and len(masters) < m_count:
                masters.append(ip)
        # mark kept masters as used
        used.update(masters)
        # add newly available IPs if needed
        if len(masters) < m_count:
            extra = pick_available(full_range_m, used, m_count - len(masters))
            masters += extra
            used.update(extra)

    # Compute workers similarly, ensuring no overlap with masters
    workers = []
    if w_count > 0:
        full_range_w = ip_range(w_start, w_end)
        for ip in prev_workers:
            if ip in full_range_w and ip not in masters and len(workers) < w_count:
                workers.append(ip)
        used.update(workers)
        if len(workers) < w_count:
            extra = pick_available(full_range_w, used, w_count - len(workers))
            workers += extra
            used.update(extra)

    out = {"master_ips": json.dumps(masters), "worker_ips": json.dumps(workers)}
    print(json.dumps(out))

if __name__ == '__main__':
    main()
