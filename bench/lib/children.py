#!/usr/bin/env python3
"""Where the time under a frame goes: inclusive share of each frame directly (or, with --skip,
nearest non-generic frame) below the first frame matching PATTERN, from a .folded file.

  children.py FILE.folded PATTERN [--skip REGEX] [--n 20]
"""
import argparse, collections, re

ap = argparse.ArgumentParser()
ap.add_argument("folded")
ap.add_argument("pattern")
ap.add_argument("--skip", default=r"^(core::|alloc::|std::|<core::|<alloc::|<std::|\{closure|call_once|map|try_|from_iter|collect|next|spec_|extend|fold|for_each|<&|<\[|iter)")
ap.add_argument("--n", type=int, default=20)
a = ap.parse_args()
rx, skip = re.compile(a.pattern), re.compile(a.skip)
total, parent, kids = 0, 0, collections.Counter()
for line in open(a.folded):
    stack, _, n = line.rstrip("\n").rpartition(" ")
    n = int(float(n))
    total += n
    frames = stack.split(";")
    idx = next((i for i, f in enumerate(frames) if rx.search(f)), None)
    if idx is None:
        continue
    parent += n
    below = [f for f in frames[idx + 1:] if not skip.search(f)]
    kids[(below[0] if below else "(self)")[:170]] += n
print(f"{100 * parent / total:.1f}% of samples under /{a.pattern}/")
for k, n in kids.most_common(a.n):
    print(f"  {100 * n / total:5.1f}%  {k}")
