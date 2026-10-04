#!/usr/bin/env python3
"""Sum CPU time and RSS over a process tree (macOS/Linux ps), plus extra pids.

  bench/local-procstat.py ROOT_PID [EXTRA_PID ...]   -> {"cpu_us": N, "rss_kb": N, "pids": [...]}
"""
import json, subprocess, sys


def cputime_us(text):
    days = 0
    if "-" in text:
        d, text = text.split("-", 1)
        days = int(d)
    parts = text.split(":")
    secs = float(parts[-1])
    mins = int(parts[-2]) if len(parts) > 1 else 0
    hours = int(parts[-3]) if len(parts) > 2 else 0
    return int(((days * 24 + hours) * 3600 + mins * 60 + secs) * 1_000_000)


roots = {int(p) for p in sys.argv[1:]}
rows = subprocess.run(["ps", "-axo", "pid=,ppid=,rss=,cputime="], capture_output=True, text=True, check=True).stdout.split("\n")
procs = {}
for row in rows:
    f = row.split()
    if len(f) >= 4:
        procs[int(f[0])] = (int(f[1]), int(f[2]), cputime_us(f[3]))
selected = set()
changed = True
while changed:
    changed = False
    for pid, (ppid, _, _) in procs.items():
        if (pid in roots or ppid in selected or ppid in roots) and pid not in selected:
            selected.add(pid)
            changed = True
selected |= roots & set(procs)
print(json.dumps({
    "cpu_us": sum(procs[p][2] for p in selected),
    "rss_kb": sum(procs[p][1] for p in selected),
    "pids": sorted(selected),
}))
