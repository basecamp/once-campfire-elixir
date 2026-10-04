#!/usr/bin/env python3
"""Inclusive share of a profile's samples whose stack matches each pattern (any frame), from a
.folded file (bench/lib/cpuprof.py, or jeprof --collapsed).

  share.py FILE.folded 'label=regex' ['label=regex' ...] [--within regex]

--within restricts the denominator to stacks matching that regex too.
"""
import re, sys

args = sys.argv[1:]
within = None
if "--within" in args:
    i = args.index("--within")
    within = re.compile(args[i + 1])
    del args[i:i + 2]
path, pats = args[0], [(p.split("=", 1)[0], re.compile(p.split("=", 1)[1])) for p in args[1:]]
total, hits = 0, {l: 0 for l, _ in pats}
for line in open(path):
    stack, _, n = line.rstrip("\n").rpartition(" ")
    n = int(float(n))
    if within and not within.search(stack):
        continue
    total += n
    for l, rx in pats:
        if rx.search(stack):
            hits[l] += n
for l, _ in pats:
    print(f"{100 * hits[l] / max(total, 1):5.1f}%  {l}")
print(f"({total} samples)")
