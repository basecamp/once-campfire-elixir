# Reader/statement-cache checkpoint: higher throughput, unresolved tails

This compares untouched upstream with the whole candidate, not statement caching in
isolation. It is a completed benchmark of work in progress, not release acceptance.

## Hardware and workload

Native amd64 Linux orb, kernel 6.1.158+, guest-reported **Intel Xeon @ 2.60 GHz,
16 vCPUs and about 31 GiB RAM**. Server affinity was `0,2,4,6`; load-generator
affinity `8,10,12,14`; the memory sampler used CPU 15. Guest CPU affinity does not
establish physical-core isolation. Both images used Elixir 1.20.4 / OTP 29.1.1 JIT,
four online normal schedulers, default dirty-IO count 10, equal `nofile=65536`,
the same populated seed and the production Thruster path. No workload-cgroup
throttling was observed; whole-run server steal was about 0.09%.

These absolute rates are not comparable to the upstream AMD Ryzen AI MAX+ 395
table or to Mac measurements. The percentages below compare only this same-host
experiment; hardware alone has not been shown to explain cross-host differences.

One attempt ran October 5, 2026, 16:34:47–17:38:31 UTC (63m44s), in balanced order
`B1,C1,C2,B2,B3,C3,C4,B4`. Each arm used twelve-second HTTP cells at concurrency
1/16/64, Cable at 100/500/1,000 clients and five uploads. There were no retries,
discarded cells, tuning, overlays or competing builds/tests during timing.

## Results and regressions

Medians of four rounds; full min–max and paired ranges are in [comparison.md](comparison.md).

| HTTP at 16 connections | Upstream req/s | Candidate req/s | Change |
|---|---:|---:|---:|
| Room | 287.55 | 343.25 | +19.4% |
| Messages | 392.35 | 453.65 | +15.6% |
| Sidebar | 449.00 | 733.10 | +63.3% |
| Search | 415.75 | 641.65 | +54.3% |
| Post | 273.40 | 396.30 | +45.0% |

**Room and messages tails worsen in all four paired rounds at 64 connections.**

| p99, milliseconds | Upstream median [range] | Candidate median [range] | Change |
|---|---:|---:|---:|
| Room, 64 connections | 260.031 [240.895–310.783] | 401.407 [341.247–401.663] | +54.4% |
| Messages, 64 connections | 210.239 [187.519–222.335] | 393.215 [378.879–402.687] | +87.0% |

Messages p99 also rises 27.5% at 16 connections. Derived CPU/success rises 6.2%
for room and 2.9% for messages at 64 connections. Cable complete-fanout rates
improve 30.1%/15.9%/5.6% at 100/500/1,000 clients, but saturated 1,000-client p99
rises 12.3%. Upload median falls 230.9 → 210.85 ms. Sampled whole-arm cgroup
`memory.current` peak rises 574.5 → 620 MiB (+7.9%); kernel `memory.peak` rises
591.5 → 651 MiB (+10.1%). These are not process RSS measurements.

All 192 HTTP cells validated: **12,858,383 successful responses, zero errors**.
The 24 Cable cases completed all 720 paced and 30,650 saturated fanouts; all 40
uploads completed. Every arm passed a populated-response preflight and ended with
11 zero-job observations spanning at least one second. No sample was excluded.

## Identity and correctness

- Baseline application: `b6b82e50a653c4060136bb04e805eb78fd76ba10`.
- Baseline image: `sha256:7cb5658090eee9c77c4d19572766434bb4a2b6654b80334bb8f43df02f922182`.
- Candidate image: `sha256:57ec8cf3ec3539e3a5b6e5b41ef1010862eebff5f36942182b52bfab556ac6f5`.
- Candidate build: `6f06e50f2ec5dae69331c2c5dd033b4ac8849580` plus the verified
  `db.ex`, `db_statement_cache_test.exs` and `messages_view_test.exs` overlay.
  All 689 application identity files match the application at harness revision
  `115cabc787bd3ed7bb6ccba5a6d9d6a4fc7e5948`; this was **not** a rebuild of that commit.
- Candidate source digest: `d95a406a33915790b632420d97840c96d76e4bd8a5e7595c58bdf2d84bf58efe`.

[Dual-architecture correctness summary](../../../parity/checkpoints/20261005-statement-cache/README.md)
records 65/65 gates and 1,941 unit tests on each architecture, strict checks and
production read/write visibility and reader-recovery probes. The later harness
passed 37 toolkit tests, pinned Rust test/check/build and real Cable wire-accounting
smokes before this run. These do not establish production readiness or continuity
of an in-flight call interrupted by reader death.

## Reproduce the report and inspect evidence

Only this summary and `comparison.md` are included in Git. The original evidence
archive is preserved locally and available on request:
`linux-final-baseline-cache-http12-evidence.tar.gz`, SHA-256
`317745a9faac3132586108455a188cc63351ea669ae3a085b00005ca288aaa73`.

It contains all raw cells, warmups, populated preflights, quiet-job windows,
environment records, reports, CPU/latency tables, exact commands, image inspections,
source identities, prechecks and audit scripts. All 438 payload hashes were checked,
and the report reproduced byte-identically. Older results and failed diagnostics
are preserved separately; removing their generated files from Git does not discard
their evidence.

After obtaining the archive and restoring its raw result directory, the report can
be checked without starting servers or rerunning timing. From the repository root,
set `RESULT` to that restored directory:

```sh
RESULT=/path/to/restored/result-directory
python3 bench/validate-results.py check "$RESULT"
bench/report "$RESULT" > /tmp/campfire-cache-report.md
cmp "$RESULT/report.md" /tmp/campfire-cache-report.md
```

## Limits of the evidence

- Raw per-cell cgroup before/after CPU counters were not saved. Derived CPU/success
  values are retained, but their deltas cannot be independently reconstructed.
- Default non-deflate Cable wire rate is null because it is unmeasured, not zero.
- Search compressed bodies are about 2.6% smaller despite equal decoded preflight
  length (165,534 bytes). The cause and normalized byte equality were not established.
- Four-round ranges are descriptive, not confidence intervals. Reported median
  p99 is the median of four cell p99s, not a pooled percentile.
- Loopback, one authenticated user and one Cable room do not establish distinct-user
  production capacity, NIC throughput or multi-node behavior.
- No causal attribution of gains or tail regressions to a single change is claimed.
