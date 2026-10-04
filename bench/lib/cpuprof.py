#!/usr/bin/env python3
"""Turn a gperftools CPU profile (libprofiler.so via LD_PRELOAD, which samples on SIGPROF and so
works with kernel.perf_event_paranoid=2) into folded stacks, a flamegraph and rollups.

  cpuprof.py PROFILE --out PREFIX [--title T]

Writes PREFIX.folded (inferno/flamegraph.pl input), PREFIX.svg (if inferno-flamegraph is on PATH)
and PREFIX.top.md (top self/inclusive functions and a category rollup). Symbolizes with
llvm-symbolizer (inlined frames expanded), so build the binary with debug line tables
(CARGO_PROFILE_RELEASE_DEBUG=line-tables-only) for useful names.
"""
import argparse, bisect, collections, json, os, re, shutil, struct, subprocess, sys

# Categories for the rollup, first match wins, applied to the inclusive stack (leaf first) so the
# nearest recognizable owner of a sample gets it.
CATEGORIES = [
    ("gzip (miniz_oxide/crc32)", r"miniz_oxide|crc32fast|flate2|deflater::"),
    ("sqlite (C)", r"^sqlite3|rusqlite::|libsqlite3_sys::"),
    ("askama render / view helpers", r"askama|campfire_views::"),
    ("rich text (Action Text pipeline)", r"campfire_richtext|html5ever|ammonia|markup5ever|lol_html|scraper"),
    ("json (serde_json)", r"serde_json"),
    ("crypto / signing (rails_compat)", r"rails_compat|hmac|sha1|sha2|aes|pbkdf2|base64"),
    ("websocket (tungstenite)", r"tungstenite"),
    ("hyper / http", r"^hyper|^http::|h1::"),
    ("tokio runtime / scheduling", r"^tokio::"),
    ("db models / queries", r"campfire_db::"),
    ("cable", r"campfire_cable::"),
    ("kit (request/response plumbing)", r"campfire_kit::"),
    ("app (controllers/channels/jobs)", r"^campfire::"),
]
LEAF_CATEGORIES = [
    ("malloc/free/realloc", r"^(__libc_)?(malloc|free|realloc|calloc|cfree|_int_malloc|_int_free|_int_free_chunk|_int_free_merge_chunk|malloc_consolidate|malloc_consolidate|_int_realloc|tcache|mi_|je_|arena_|unlink_chunk)|alloc::alloc|__rust_(alloc|dealloc|realloc)|_rjem|sdallocx"),
    ("memcpy/memmove/memset", r"^__mem(cpy|move|set|cmp)|^mem(cpy|move|set|cmp)"),
    ("syscalls (read/write/epoll/futex)", r"^(__)?(libc_)?(write|writev|read|recv|send|sendto|recvfrom|epoll_wait|futex|syscall|__GI___|pthread_cond|__lll|sched_yield|clock_gettime|fsync|fdatasync|pwrite|pread|__syscall_cancel|__internal_syscall)"),
]


def read_profile(path):
    data = open(path, "rb").read()
    w = 8
    words = lambda off, n: struct.unpack_from(f"<{n}Q", data, off)
    hdr_count, hdr_words = words(0, 2)
    assert hdr_count == 0, "not a gperftools CPU profile"
    period_us = words(0, 2 + hdr_words)[3]
    off = (2 + hdr_words) * w
    samples = []
    while True:
        count, depth = words(off, 2)
        off += 2 * w
        pcs = words(off, depth)
        off += depth * w
        if count == 0 and depth == 1 and pcs[0] == 0:
            break
        samples.append((count, pcs))
    maps = data[off:].decode("utf-8", "replace")
    return period_us, samples, maps


def parse_maps(text):
    out = []
    for line in text.splitlines():
        parts = line.split()
        if len(parts) >= 6 and "x" in parts[1] and parts[5].startswith("/"):
            start, end = (int(x, 16) for x in parts[0].split("-"))
            out.append((start, end, int(parts[2], 16), parts[5]))
    out.sort()
    return out


def load_segments(path):
    """(p_offset, p_vaddr, p_filesz) of each LOAD segment, to turn file offsets into ELF vaddrs."""
    segs = []
    try:
        out = subprocess.check_output(["readelf", "-lW", path], text=True, stderr=subprocess.DEVNULL)
    except Exception:
        return segs
    for line in out.splitlines():
        p = line.split()
        if p and p[0] == "LOAD":
            segs.append((int(p[1], 16), int(p[2], 16), int(p[4], 16)))
    return segs


def symbolize(pcs, maps):
    starts = [m[0] for m in maps]
    by_obj = collections.defaultdict(dict)
    segcache = {}
    for pc in pcs:
        i = bisect.bisect_right(starts, pc) - 1
        if i < 0 or pc >= maps[i][1]:
            continue
        start, _, offset, path = maps[i]
        fileoff = pc - start + offset
        segs = segcache.setdefault(path, load_segments(path))
        vaddr = fileoff
        for so, sv, sz in segs:
            if so <= fileoff < so + max(sz, 1):
                vaddr = fileoff - so + sv
                break
        by_obj[path][pc] = vaddr
    names = {}
    for path, addrs in by_obj.items():
        if not os.path.exists(path):
            continue
        items = list(addrs.items())
        inp = "\n".join(hex(v) for _, v in items)
        # --debuginfod names libc's internal functions (memset/memmove variants, the syscall
        # wrappers) from the distribution's debug info when DEBUGINFOD_URLS is set.
        cmd = ["llvm-symbolizer", "--obj", path, "--inlining", "--demangle", "--output-style=JSON"]
        if os.environ.get("DEBUGINFOD_URLS"):
            cmd.append("--debuginfod")
        out = subprocess.run(cmd, input=inp, capture_output=True, text=True).stdout
        for (pc, _), line in zip(items, out.splitlines()):
            try:
                rec = json.loads(line)
            except ValueError:
                continue
            frames = [qualify(clean(f.get("FunctionName", "??")), f.get("FileName", "")) for f in rec.get("Symbol", [])]
            frames = [f for f in frames if f and f != "??"] or [f"{os.path.basename(path)}+{hex(pc)}"]
            names[pc] = list(reversed(frames))  # outermost first
    return names


def crate_of(path):
    """The crate a source file belongs to: registry `name-1.2.3/src/..`, the workspace's
    `crates/<dir>/src/..`, or the standard library."""
    m = re.search(r"/registry/src/[^/]+/([A-Za-z0-9_\-]+?)-\d+\.\d+[^/]*/", path)
    if m:
        return m.group(1).replace("-", "_")
    m = re.search(r"/crates/([A-Za-z0-9_\-]+)/src/", path)
    if m:
        return {"campfire": "campfire", "kit": "campfire_kit", "db": "campfire_db", "views": "campfire_views", "cable": "campfire_cable",
                "richtext": "campfire_richtext", "storage": "campfire_storage", "assets": "campfire_assets", "routes": "campfire_routes"}.get(m.group(1), m.group(1))
    m = re.search(r"/(?:rustc/[0-9a-f]+/)?library/(std|core|alloc)/", path)
    if m:
        return m.group(1)
    if "askama" in path:
        return "campfire_views"
    return ""


def qualify(name, path):
    """Line-tables-only debug info names inlined frames without their module path; put the
    crate in front so rollups can match on it."""
    if "::" in name or not path:
        return name
    crate = crate_of(path)
    return f"{crate}::{name}" if crate else name


def clean(name):
    name = re.sub(r"::h[0-9a-f]{16}$", "", name)
    name = re.sub(r"\{closure#\d+\}|\{\{closure\}\}", "{closure}", name)
    name = name.replace(";", ",")
    return name


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("profile")
    ap.add_argument("--out", required=True)
    ap.add_argument("--title", default="")
    a = ap.parse_args()
    period_us, samples, maps_text = read_profile(a.profile)
    maps = parse_maps(maps_text)
    # Non-leaf PCs are return addresses: symbolize pc-1 so calls at the end of a function
    # (and inlined call sites) resolve to the caller's line.
    lookups = set()
    for _, pcs in samples:
        for j, pc in enumerate(pcs):
            lookups.add(pc if j == 0 else pc - 1)
    names = symbolize(sorted(lookups), maps)

    folded = collections.Counter()
    selfc, incl = collections.Counter(), collections.Counter()
    cats = collections.Counter()
    total = 0
    for count, pcs in samples:
        frames = []  # leaf first
        for j, pc in enumerate(pcs):
            key = pc if j == 0 else pc - 1
            frames.extend(reversed(names.get(key, [hex(pc)])))
        # Drop the profiler's own signal frames if present.
        while frames and re.search(r"ProfileHandler|CpuProfiler|__restore_rt|prof_handler", frames[0]):
            frames.pop(0)
        if not frames:
            continue
        total += count
        folded[";".join(reversed(frames))] += count
        selfc[frames[0]] += count
        for f in set(frames):
            incl[f] += count
        cat = None
        for label, pat in LEAF_CATEGORIES:
            if re.search(pat, frames[0]):
                cat = label
                break
        owner = None
        for f in frames:
            for label, pat in CATEGORIES:
                if re.search(pat, f):
                    owner = label
                    break
            if owner:
                break
        cats[(owner or "other", cat or "")] += count

    with open(a.out + ".folded", "w") as f:
        for stack, n in folded.most_common():
            f.write(f"{stack} {n}\n")
    if shutil.which("inferno-flamegraph"):
        with open(a.out + ".svg", "w") as f:
            subprocess.run(["inferno-flamegraph", "--title", a.title or os.path.basename(a.out), "--minwidth", "0.2",
                            a.out + ".folded"], stdout=f)
    pct = lambda n: f"{100 * n / max(total, 1):.1f}%"
    lines = [f"# {a.title or os.path.basename(a.out)}", "",
             f"{total} samples at {period_us} µs ({total * period_us / 1e6:.2f} CPU-s)", "",
             "## By owner (nearest recognizable frame) and leaf kind", "", "| owner | leaf | share |", "|---|---|---|"]
    owners = collections.Counter()
    for (o, c), n in cats.items():
        owners[o] += n
    for o, n in owners.most_common():
        lines.append(f"| **{o}** | (all) | **{pct(n)}** |")
        for (o2, c), m in sorted(cats.items(), key=lambda kv: -kv[1]):
            if o2 == o and c and m / max(total, 1) >= 0.005:
                lines.append(f"| {o} | {c} | {pct(m)} |")
    lines += ["", "## Top self", "", "| self | function |", "|---|---|"]
    lines += [f"| {pct(n)} | `{fn[:160]}` |" for fn, n in selfc.most_common(40)]
    lines += ["", "## Top inclusive", "", "| incl | function |", "|---|---|"]
    lines += [f"| {pct(n)} | `{fn[:160]}` |" for fn, n in incl.most_common(80)]
    open(a.out + ".top.md", "w").write("\n".join(lines) + "\n")
    print(f"{a.out}: {total} samples")


if __name__ == "__main__":
    main()
