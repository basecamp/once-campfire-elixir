# Native Linux benchmark: frozen candidate versus untouched baseline

Completed 2026-10-05, 07:48:07–08:25:52 UTC. `bench/run` exited 0 after
four balanced alternating rounds per image. This is the Linux table only;
the M4 Pro/native ARM64 OrbStack table belongs to the parent thread.

**The candidate is not an overall throughput improvement on this workload.**
At 16 concurrent HTTP connections, populated dynamic routes lost 16–47% of
baseline throughput. Health checks improved. Cable throughput decreased;
paced delivery latency at 1,000 clients improved. Smaller median peak memory
was measured under lower delivered throughput, not at equal throughput.
Upload and memory ranges overlap, so small median differences are not claims
of statistically established improvements.

## Medians and complete ranges, never selected best rounds

Change is `(candidate / baseline - 1) * 100`. Higher throughput is better;
lower upload time and memory are better. HTTP rows below use concurrency 16.
`report.md` includes concurrency 1/16/64, p50/p99, CPU per successful response,
startup, and per-process Cable memory for all four rounds.

| Metric | Baseline median [min–max] | Candidate median [min–max] | Change |
|---|---:|---:|---:|
| Room, req/s | 305.4 [294.3–322.0] | 255.8 [227.6–259.2] | −16.3% |
| Messages page, req/s | 429.5 [418.3–443.2] | 330.3 [321.2–335.5] | −23.1% |
| Sidebar, req/s | 462.0 [448.7–485.9] | 243.5 [235.6–265.3] | −47.3% |
| Search, req/s | 448.8 [430.1–473.6] | 318.9 [309.7–341.7] | −28.9% |
| Post message, req/s | 287.6 [269.0–299.5] | 174.1 [169.8–209.8] | −39.5% |
| Avatar, req/s | 26,756.5 [25,026.3–28,748.3] | 26,543.2 [25,436.4–27,249.7] | −0.8% |
| Static CSS, req/s | 35,064.0 [34,184.0–35,335.4] | 36,126.6 [34,772.7–38,753.3] | +3.0% |
| Health check, req/s | 3,409.1 [3,265.5–3,613.3] | 4,597.0 [4,373.9–4,768.5] | +34.8% |
| Cable 100 clients, delivered messages/s | 141.90 [131.4–144.4] | 113.65 [109.7–119.2] | −19.9% |
| Cable 500 clients, delivered messages/s | 61.55 [59.1–64.1] | 54.45 [54.0–57.0] | −11.5% |
| Cable 1,000 clients, delivered messages/s | 34.85 [34.0–36.8] | 33.20 [32.1–35.7] | −4.7% |
| Upload → thumbnail served, ms | 218.90 [196.9–240.4] | 206.25 [201.6–254.1] | −5.8% |
| Peak sampled cgroup memory.current, MiB | 539.0 [512–556] | 509.5 [507–541] | −5.5% |

## Hardware, native architecture, and limits

- Linux 6.1.158+, native x86_64 KVM orb, Intel Xeon model 106 at 2.60 GHz.
  The guest exposes 16 logical CPUs as eight cores × two SMT threads. This
  does not establish dedicated physical host cores or bare-metal performance.
- Guest RAM 33,669,939,200 bytes (31.36 GiB); workload cgroup limit
  32,212,254,720 bytes (30 GiB). No swap. CPU quota `max 100000`.
- Server CPUs `0,2,4,6` map to guest cores 0–3. Loadgen CPUs `8,10,12,14`
  map to cores 4–7. No guest SMT sibling is shared across those roles.
  Process-memory sampler CPU `15` shares only loadgen core 7.
- Both images verified `linux/amd64`; both execute Elixir 1.20.4, OTP
  **29.1.1**, default JIT, and four online schedulers. Baseline `ERL_FLAGS`
  is unset; candidate is empty. No Rosetta, QEMU, or other emulation was used.
- Both containers: soft/hard nofile 65,536. Host/loadgen shell:
  soft 65,536, hard 1,048,576. The separate Mac environment reports soft
  20,480, hard 1,048,576; do not describe the environments as identical.
- Pinned packages in both images: libvips-dev `8.16.1-1+deb13u1`, FFmpeg
  `7:7.1.5-0+deb13u1`, libsqlite3 `3.46.1-7+deb13u2`.
- No concurrent builds, tests, or other load workloads ran during timing.
  Every run began below the configured one-minute load threshold of 1.5.

## Exact identities

Baseline is [b6b82e50a653c4060136bb04e805eb78fd76ba10](https://github.com/basecamp/once-campfire-elixir/commit/b6b82e50a653c4060136bb04e805eb78fd76ba10).
Its application source was untouched. The supplied historical build overlays
only update the Elixir OCI pin, name the baseline toolchain image, and remove
the historical release compile `--warnings-as-errors` flag. No optimizations
were copied into baseline. The setup receipt and both overlays are archived.

Frozen candidate: `7c1ed67d062f5e241d37e3eb0e9a3d97a2324636`, imported from
the [source integrator](https://ampcode.com/threads/T-01a10864-1f5f-70f9-bed3-f513babe9469).
It was not assumed to be on `origin/main`. No application, harness, or
reference source was edited by the Linux benchmark work.

```text
Baseline release image:
sha256:7cb5658090eee9c77c4d19572766434bb4a2b6654b80334bb8f43df02f922182
Candidate release image:
sha256:3cab19b9a0cc8416e94c9e91585eb4036a190d68a013df98726cbfb34fc344bc
Elixir base OCI index (elixir:1.20.4-otp-29-slim):
sha256:3898ffe18d695e770239e4b342dc6b83136f52da0a37df2298083c03068cfd4e
Elixir base linux/amd64 manifest:
sha256:5c82b47119ae19dadc730c6fd499e34bace9edbb17c11dde1ec147e684f49c8f
Rust 1.98.1 loadgen build image:
sha256:4cd829461bd5c4d511c32e269da9cb8929223b666519d8004e35fc8d1d771ab7
Loadgen executable SHA-256:
6c55f4fd8c7accb05c7f7ad211fd1892fd4efcf4304f8560d5c65b58df3d9c0f
Local verified source + generated-input digest:
211c7482047fcd69224c168ee21d81f689bd991d7267acae74039122a85553a6
Reference Rails revision:
90b330024dec3e757c79b6a7e6568f93da8e3148
Reference production image:
sha256:1463aff8eaf0e44633c13945d1e40fe3ae31dc0c9b6868ac1d57e11b9059f680
Reference parity wrapper image:
sha256:f6838229010330e4539d1fbeaa4f3d04a9110bafef66a8c723bac6a0f2a33d5f
Public seed archive SHA-256:
668a9e9b5a3f0e132a3be77503446af71887289d539ea8c053e12057a18c0a52
Seed database SHA-256:
bda9a5cd61d78d53f377cf07ee9268741caebc19b94a6efe782cafe827efc8db
Seed tree SHA-256:
d0c0b2708846c2f261e7bf6c8a4d7b220b9df71ba21190a172ffcb5acf38b963
```

The baseline/candidate unpacked image sizes are 2,542,179,488 and
2,540,411,548 bytes. These are not compressed transfer sizes. The local
generated-input digest differs from the source orb's; this orb's inputs
were held unchanged through its own complete parity and both image timings.

## Executed benchmark command

The first attempt hit the old soft nofile limit of 1,024 at Cable 1,000 and
aborted. With no active containers, Docker was restarted using:

```sh
amp orb service stop docker
amp orb service start docker --command 'sudo dockerd --group root --default-ulimit nofile=65536:65536'
```

After probing both images' limits, all four rounds restarted. Executed from
`/home/user/workspace/repo`:

```sh
set -o pipefail
ulimit -Sn 65536
OUT=bench/results/native-linux-b6b82e5-7c1ed67-20261005-nofile65536
SERVER_CPUS=0,2,4,6 LOADGEN_CPUS=8,10,12,14 PROCMEM_CPUS=15 \
HTTP_SECS=4 HTTP_CONCS='1 16 64' \
SEED="$PWD/var/linux-benchmark-setup/seed/default" \
BASELINE_SHA=b6b82e50a653c4060136bb04e805eb78fd76ba10 \
CANDIDATE_SHA=7c1ed67d062f5e241d37e3eb0e9a3d97a2324636 \
BASELINE_IMAGE=sha256:7cb5658090eee9c77c4d19572766434bb4a2b6654b80334bb8f43df02f922182 \
CANDIDATE_IMAGE=sha256:3cab19b9a0cc8416e94c9e91585eb4036a190d68a013df98726cbfb34fc344bc \
LOADGEN_BUILD_IMAGE=rust@sha256:4cd829461bd5c4d511c32e269da9cb8929223b666519d8004e35fc8d1d771ab7 \
bench/run --apps baseline,candidate --reps 4 --out "$OUT" \
  2>&1 | tee var/linux-7c1ed67/benchmark-nofile65536.log
```

`bench/run` ran `python3 bench/validate.py ledger` before timing and rebuilt
the load generator incrementally from the frozen checkout using
`cargo build --release --locked` (0.07 seconds). Defaults were unchanged:
Cable clients 100/500/1,000, 15-second saturated phases, four posters,
five uploads per image/run, two-second HTTP warmup, host networking,
`LOAD_MAX=1.5`, `LOAD_WAIT_SECS=900`. Actual interleaving:
`B1,C1,C2,B2,B3,C3,C4,B4`.

## Executed correctness and post-run evidence

- Complete local `bin/verify-parity`: 65/65 gates, 1,929 tests,
  `passed=true`, `complete_run=true`, `source_unchanged=true`.
  This includes strict format/compile/test checks, browser, mutation,
  realtime, jobs, storage/media, TLS, fresh install, shutdown, and rollback.
  `verification.json` records every gate's command, exit code, and log path.
- Historical baseline `mix format --check-formatted` and
  `mix test --warnings-as-errors`: exit 0, 1,896 tests. Historical compilation
  warnings are preserved; no baseline source fixes suppressed them.
- `python3 bench/validate.py ledger` passed again after all timings.
  `python3 bench/validate.py digest` still matches the pre-run digest above.
- `audit.json`: eight expected runs and eight response preflights;
  192 HTTP samples / 4,279,362 successful responses, zero transport errors
  and zero invalid responses; 24 Cable cases / 27,141 complete messages /
  9,561,200 client deliveries; 40 valid uploads and thumbnails.
  Every final job sample has zero queued and zero failed jobs.
- `post-run-verification.txt`: re-executed native runtime/package/FD probes
  for both pinned image IDs, unchanged seed and loadgen hashes, no running
  containers, no tracked edits outside generated parity evidence, and a
  clean `reference/` worktree.
- `raw-run.log`, eight result JSONs, eight preflight JSONs, eight job-state
  JSONs, hidden Cable phase/process-memory samples, and `uptime.log` retain
  the raw interleaved evidence. `report.md` is the unmodified `bench/report`
  output. The failed first attempt remains in the adjacent directory
  without the `-nofile65536` suffix and is excluded from all comparison rows.

The setup archive records public reference/build/fixture commands from the
original clean baseline checkout. Do not rebuild baseline from the current
candidate working tree. The verification archive retains all local parity
logs/results. Superseded incomplete parity attempts are not substituted for
the complete frozen run.

These are short-duration, local HTTP/host-network measurements using the
repository's seeded user/room topology. They do not establish Internet/TLS
capacity, unique-user scaling, a universal memory-per-client limit, or
cross-architecture superiority. No performance cause was isolated here.
Source changes, another candidate, or profiling require separate work.
Results are local artifacts; nothing was committed, pushed, or deployed.
