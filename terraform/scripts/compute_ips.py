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

    used = used_ips_from_allocated_json(allocated_path)

    masters = pick_available(ip_range(m_start, m_end), used, m_count) if m_count>0 else []
    used = used + masters
    workers = pick_available(ip_range(w_start, w_end), used, w_count) if w_count>0 else []

    out = {"master_ips": json.dumps(masters), "worker_ips": json.dumps(workers)}
    print(json.dumps(out))

if __name__ == '__main__':
    main()
