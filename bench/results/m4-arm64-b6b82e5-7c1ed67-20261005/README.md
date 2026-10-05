# M4 Pro / native ARM64 OrbStack observations

Measured 2026-10-05, 08:12:05–08:51:04 UTC. Four balanced rounds per build,
in order B1,C1,C2,B2,B3,C3,C4,B4. `bench/run` exited 0 and its `report.md`
reproduced byte-for-byte on the source ARM64 host. No rounds were omitted or
replaced. Regeneration on the x86_64 integration host differs in one displayed
rounded memory maximum (381 versus 382 MiB); the raw sample is unchanged.

**Response validation passed, but the stricter fully-drained-work audit did not.**
Candidate round 2 ended with 1,125 queued Resque jobs and zero failed jobs.
Every other end-of-run queue was empty. The benchmark tears down each run;
it did not measure the time needed to drain that remaining work. These are
HTTP response and completed Cable delivery rates, not fully drained
background-work throughput. `audit.json` deliberately records `passed=false`
and `response_validation_passed=true`.

**The Mac was a shared workstation, not an isolated benchmark machine.**
Host load increased during later rounds; candidate 4 reached 29.06 on the
14-core host, and baseline 4 reached 18.55. Spotlight, Raycast, and Moonlock
CPU activity was observed. No task-owned builds, tests, or other load tests
ran concurrently. Host swapout counters did not increase, but swapins did.
All runs began below the VM's 1-minute load threshold of 1.5; that check
does not guarantee a quiet macOS host. A quiet-host rerun with background
queues accounted for is needed before a stronger performance claim.

## Medians and full ranges

HTTP rows use concurrency 16 and req/s. Change is candidate / baseline − 1.
These are qualified observations, not an isolated measurement of the code
delta. `report.md` preserves concurrency 1/16/64, latency, CPU/success,
startup, cgroup memory, and per-process memory from every round.

| Metric | Baseline median [min–max] | Candidate median [min–max] | Change |
|---|---:|---:|---:|
| Room, req/s | 359.45 [337.0–391.1] | 599.85 [583.3–644.0] | +66.9% |
| Messages page, req/s | 559.35 [518.8–599.1] | 870.10 [839.9–896.7] | +55.6% |
| Sidebar, req/s | 739.05 [661.8–819.0] | 688.70 [624.5–722.3] | −6.8% |
| Search, req/s | 615.25 [552.2–686.7] | 914.50 [864.4–938.4] | +48.6% |
| Post message, req/s | 339.45 [226.5–422.2] | 530.65 [439.5–588.9] | +56.3% |
| Avatar, req/s | 17,264.40 [16,663.1–17,775.9] | 17,417.50 [17,116.1–18,104.6] | +0.9% |
| Static CSS, req/s | 25,970.80 [25,748.4–26,057.8] | 25,910.00 [24,565.3–26,475.5] | −0.2% |
| Health check, req/s | 6,068.55 [5,227.5–6,316.8] | 7,962.80 [7,371.0–8,438.4] | +31.2% |
| Cable 100 clients, delivered messages/s | 217.25 [127.9–245.4] | 336.40 [282.4–368.3] | +54.8% |
| Cable 500 clients, delivered messages/s | 107.75 [80.4–114.9] | 139.55 [129.2–147.7] | +29.5% |
| Cable 1,000 clients, delivered messages/s | 61.20 [56.5–68.0] | 79.15 [76.7–82.7] | +29.3% |
| Upload → thumbnail served, ms | 97.75 [93.8–102.5] | 95.40 [94.4–96.4] | −2.4% |
| Peak sampled cgroup memory.current, MiB | 703.0 [657–739] | 716.0 [685–754] | +1.8% |

Memory is not normalized to equal throughput. Small upload and memory
median differences have overlapping ranges and are not established wins.
At concurrency 64 the sidebar also regressed: 748.80 → 620.85 req/s (−17.1%).
Keep these observations separate from the native x86_64 Linux table; the
platforms differ in hardware, virtualization, memory, and descriptor limits.

## Platform, source, and workload

- Mac16,11, Apple M4 Pro, 14 cores, 64 GiB physical RAM, macOS 27.0.
  Docker 29.4.0 under OrbStack; ARM64 Linux VM with 14 vCPUs and about
  16 GiB RAM. This is neither bare macOS nor Rosetta/QEMU emulation.
- Server vCPUs 2–5; loadgen vCPUs 6–9; process sampler vCPU 0. These are
  VM CPU assignments, not guaranteed exclusive macOS physical-core bindings.
- Both releases: Elixir 1.20.4, OTP 29.1.1, native aarch64, JIT, four
  schedulers, no extra ERL_FLAGS. Runtime probes are in `runtime-probes.txt`.
- Both server images and loadgen: soft nofile 20,480, hard 1,048,576.
  All eight 1,000-client runs connected and delivered completely.
- Identical media packages within this comparison: libvips 8.16.1-1+deb13u1,
  FFmpeg 7:7.1.5-0+deb13u1, SQLite 3.46.1-7+deb13u2.
- Baseline is untouched application source from
  [b6b82e5](https://github.com/basecamp/once-campfire-elixir/commit/b6b82e50a653c4060136bb04e805eb78fd76ba10).
  Its two archived build-only Docker overlays select the matched toolchain,
  native ARM64 Thruster layout, and preserve historical compiler warnings.
  `baseline-source-clean.txt` confirms no tracked baseline changes.
- Candidate is frozen local/unpushed 7c1ed67d062f5e241d37e3eb0e9a3d97a2324636
  from the [source integrator](https://ampcode.com/threads/T-01a10864-1f5f-70f9-bed3-f513babe9469).
- The exact command is retained in `command.txt`; immutable image IDs,
  source and loadgen digests, seed hashes, and workload settings are in
  `env.txt`. The images actually measured are the pinned IDs there and in
  `runtime-probes.txt`, not a mutable tag from the earlier platform snapshot.
- HTTP: 4-second samples, concurrency 1/16/64, 2-second warmup, signed-in
  populated routes, gzip, keepalive. Cable: 100/500/1,000 clients, six
  subscriptions per client, four posters, 15-second saturated phases.
  Five upload/thumbnail checks per run. Host networking, fixed seeded
  topology; this does not establish Internet/TLS or unique-user capacity.

## Evidence and remaining limitations

- Full ARM64 parity: 65/65 gates and 1,929 tests, including browser,
  mutation, realtime/jobs, storage/media, TLS, fresh install, shutdown,
  and rollback. `verification.json` records the exact commands and exits.
- Post-run `bench/validate.py ledger` passed and source digest remained
  cf87f7de83295e1cb2510ed2e0f3287ac476f42cd2aee31dcb12653304af611b.
  Generated parity logs/results are the only tracked changes in the runner;
  the reference checkout remains clean. No application source was edited.
- All 192 HTTP samples / 4,209,394 responses passed status, body, and
  transport checks; 24 Cable cases / 19,339,000 client deliveries completed;
  all 40 uploads returned valid thumbnails. There were zero failed jobs,
  but 1,125 queued jobs remained in candidate round 2 as described above.
- `seed-manifest.txt` matches all 16 files from the shared seed archive,
  with no additions, deletions, or content changes. Seed database SHA-256:
  bda9a5cd61d78d53f377cf07ee9268741caebc19b94a6efe782cafe827efc8db.
  Linux's 16 archive files also match, but its full seed directory includes
  a 32 KiB SQLite SHM file and an empty WAL predating timing. Full seed-tree
  hashes therefore differ; do not call the two entire directories identical.
  The Linux results retain the full manifest and `linux-seed-comparison.json`.
- Raw JSONs, response preflights, job samples, hidden Cable process samples,
  interleaved log, host samples, and per-round host load ranges in
  `audit.json` are retained. `host-pressure.txt` records competing activity.

The fully-drained-work audit failure and host contention are unresolved;
they were not hidden by excluding a run or changing the workload. No cause
for the architecture-dependent performance differences was isolated here.
Results are local evidence, not a commit, push, deployment, or upstream PR.
