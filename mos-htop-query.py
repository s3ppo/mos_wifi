#!/usr/bin/env python3
import json
import os
import time

def read_file(path):
    try:
        with open(path, 'r') as f:
            return f.read()
    except Exception:
        return ''

def parse_loadavg():
    parts = read_file('/proc/loadavg').split()
    task_parts = parts[3].split('/') if len(parts) > 3 else ['0', '0']
    return {
        'load1': float(parts[0]) if parts else 0,
        'load5': float(parts[1]) if len(parts) > 1 else 0,
        'load15': float(parts[2]) if len(parts) > 2 else 0,
        'running': int(task_parts[0]),
        'total': int(task_parts[1]),
    }

def parse_meminfo():
    info = {}
    for line in read_file('/proc/meminfo').splitlines():
        parts = line.split()
        if len(parts) >= 2:
            info[parts[0].rstrip(':')] = int(parts[1])
    total = info.get('MemTotal', 0)
    available = info.get('MemAvailable', info.get('MemFree', 0))
    used = total - available
    swap_total = info.get('SwapTotal', 0)
    swap_free = info.get('SwapFree', 0)
    return {
        'mem': {'total_mb': total / 1024, 'used_mb': used / 1024, 'available_mb': available / 1024},
        'swap': {'total_mb': swap_total / 1024, 'used_mb': (swap_total - swap_free) / 1024},
    }

def parse_cpu_stat():
    cpus = []
    for line in read_file('/proc/stat').splitlines():
        if not line.startswith('cpu'):
            continue
        parts = line.split()
        name = parts[0]
        if name == 'cpu':
            continue
        vals = [int(x) for x in parts[1:]]
        idle = vals[3] + (vals[4] if len(vals) > 4 else 0)
        total = sum(vals[:8]) if len(vals) >= 8 else sum(vals)
        cpus.append({'name': name, 'idle': idle, 'total': total, 'num': int(name[3:])})
    return cpus

def parse_processes(limit=50):
    procs = []
    try:
        pids = [p for p in os.listdir('/proc') if p.isdigit()]
    except Exception:
        return procs

    for pid in pids:
        try:
            status = {}
            for line in read_file(f'/proc/{pid}/status').splitlines():
                if ':' in line:
                    k, v = line.split(':', 1)
                    status[k.strip()] = v.strip()

            stat = read_file(f'/proc/{pid}/stat').split()
            cmdline = read_file(f'/proc/{pid}/cmdline').replace('\x00', ' ').strip()
            if not cmdline:
                cmdline = status.get('Name', '?')

            utime = int(stat[13]) if len(stat) > 13 else 0
            stime = int(stat[14]) if len(stat) > 14 else 0
            vsize = int(stat[22]) if len(stat) > 22 else 0
            rss = int(stat[23]) if len(stat) > 23 else 0
            state = stat[2] if len(stat) > 2 else '?'

            vm_rss_kb = int(status.get('VmRSS', '0 kB').split()[0])
            vm_virt_kb = int(status.get('VmSize', '0 kB').split()[0])

            procs.append({
                'pid': int(pid),
                'user': status.get('Uid', '0').split()[0],
                'state': state,
                'virt_kb': vm_virt_kb,
                'res_kb': vm_rss_kb,
                'utime': utime,
                'stime': stime,
                'command': cmdline[:100],
            })
        except Exception:
            continue
    return procs

def format_kb(kb):
    kb = int(kb or 0)
    if kb >= 1048576:
        return f'{kb/1048576:.1f}g'
    if kb >= 1024:
        return f'{kb/1024:.0f}m'
    return f'{kb}k'

def main():
    loadavg = parse_loadavg()
    meminfo = parse_meminfo()
    cpus_raw = parse_cpu_stat()
    procs_raw = parse_processes()

    # Second sample for CPU delta (100ms apart)
    time.sleep(0.1)
    cpus_raw2 = parse_cpu_stat()

    cpus = []
    for c1 in cpus_raw:
        c2 = next((x for x in cpus_raw2 if x['name'] == c1['name']), None)
        if c2:
            d_total = c2['total'] - c1['total']
            d_idle = c2['idle'] - c1['idle']
            used = max(0.0, min(100.0, ((d_total - d_idle) / d_total * 100) if d_total > 0 else 0.0))
            cpus.append({'num': c1['num'], 'used': round(used, 1)})
    cpus.sort(key=lambda x: x['num'])

    # Second sample for per-process CPU delta
    time.sleep(0.1)
    procs_raw2 = parse_processes()
    proc_map2 = {p['pid']: p for p in procs_raw2}

    clk_tck = os.sysconf('SC_CLK_TCK') if hasattr(os, 'sysconf') else 100
    uptime_vals = read_file('/proc/uptime').split()
    uptime_total = float(uptime_vals[0]) if uptime_vals else 1.0

    processes = []
    for p in procs_raw:
        p2 = proc_map2.get(p['pid'])
        cpu_pct = 0.0
        if p2:
            delta_ticks = (p2['utime'] + p2['stime']) - (p['utime'] + p['stime'])
            cpu_pct = round(max(0.0, (delta_ticks / clk_tck) / 0.2 * 100), 1)
        processes.append({
            'pid': p['pid'],
            'user': p['user'],
            'cpu': cpu_pct,
            'mem': round(p['res_kb'] / (meminfo['mem']['total_mb'] * 1024) * 100, 1) if meminfo['mem']['total_mb'] > 0 else 0,
            'virt': format_kb(p['virt_kb']),
            'res': format_kb(p['res_kb']),
            's': p['state'],
            'command': p['command'],
        })
    processes.sort(key=lambda x: x['cpu'], reverse=True)
    processes = processes[:100]

    result = {
        'header': {
            'load1': loadavg['load1'],
            'load5': loadavg['load5'],
            'load15': loadavg['load15'],
            'uptime': f"{int(uptime_total // 3600)}h {int((uptime_total % 3600) // 60)}m",
        },
        'tasks': {
            'running': loadavg['running'],
            'total': loadavg['total'],
            'sleeping': max(0, loadavg['total'] - loadavg['running']),
        },
        'cpus': cpus,
        'mem': {
            'total': round(meminfo['mem']['total_mb'], 0),
            'used': round(meminfo['mem']['used_mb'], 0),
        },
        'swap': {
            'total': round(meminfo['swap']['total_mb'], 0),
            'used': round(meminfo['swap']['used_mb'], 0),
        },
        'processes': processes,
    }
    print(json.dumps(result))

if __name__ == '__main__':
    main()
