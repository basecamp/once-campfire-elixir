# Application benchmarks

`bench/run --apps elixir,rust --reps 4` compares the production images using the
Rust port's unchanged populated seed. The launcher requires the complete parity
ledger and a successful complete verification of the current source digest.

The suite measures eight signed-in HTTP workloads at 1/16/64 connections, actual
Action Cable fanout at 100/500/1000 connections, and image attachment uploads.
Each app runs separately on CPUs 8–11; the same load generator uses CPUs 12–15.
Rounds alternate order. Default HTTP sampling is eight seconds after warmup,
Cable throughput sampling is fifteen seconds, and upload sampling uses five runs.
`HTTP_SECS`, `HTTP_CONCS`, `CABLE_CLIENTS`, `SUITES`, and other documented environment
variables can select a workload; record any overrides with the result.

Preflight rejects redirects, errors, empty bodies, and unpopulated room/search
responses. Timed HTTP counts only successful 200 responses. Raw results retain
status/error counts, throughput, latency, CPU per successful HTTP response, cold
readiness, cgroup memory, process PSS/anonymous memory, fixture digest, source digest,
image IDs, descriptor limits, benchmark/runtime identities, workload validation, and
external Resque queued/active/failed observations where applicable. Rails and Elixir
require at least three consecutive quiet Redis observations spanning at least one second
and fail if jobs do not drain within `JOB_DRAIN_SECS`. This is an observed quiet window,
not an atomic job-completion guarantee: a worker can pop a job before registering it as
active. A single queue-length read is never treated as completion. Go and Rust
own their queues internally, so the result records that their job state is unobserved.

New runs use result schema 2. `manifest.json` declares the exact app/repetition/workload
matrix and remains `complete: false` until every sample, preflight, raw load-generator
JSON, upload/thumbnail check, job audit, and final directory audit succeeds. Raw JSON is
written under `raw/` before validation, so an interrupted or rejected attempt retains
the response that caused it to stop. The audit compares raw results with reported samples,
recomputes the final job quiet window, and rejects missing or extra runs. Cable records paced and saturated POST attempts,
successes/errors, and requires a 200 Turbo Stream response plus positive complete fanout.
The server and load generator both require the recorded `NOFILE` limit (65,536 by
default), and a run aborts if host load remains above `LOAD_MAX` after the quiet wait.

Elixir runs BEAM, Redis, native media/parser helpers, and the same pinned Thruster
binary as Rails. Go and Rust run their own integrated HTTP/proxy/job implementations.
These are their actual production process models. Loopback measurements exclude
NIC/TLS costs. Cable uses one authenticated user with many connections, so this
workload is not a distinct-user capacity claim.

Keep each result directory and `env.txt`. `bench/report DIR` revalidates schema-2
completeness before producing median and range tables. Historical directories without
a manifest can only be rendered with `bench/report --legacy DIR`; the output is marked
legacy and does not imply the new upload/job/attempt assurance. `bench/profile-elixir` profiles a warmed populated room on an isolated
release; profiler timings are diagnostic and are never used as benchmark results.
The toolkit benchmark command measures whole-process primitive wall time rather
than full application throughput.

The current reader/statement-cache comparison is in
[`results/native-linux-b6b82e5-cache-115cabc-20261005-http12-nofile65536/`](results/native-linux-b6b82e5-cache-115cabc-20261005-http12-nofile65536/README.md).
Four balanced rounds on a native amd64 Xeon @ 2.60 GHz Linux orb used four guest
server CPUs and four separate guest load-generator CPUs, twelve-second HTTP cells,
the production Thruster path and identical populated seeds. All 192 HTTP cells,
24 Cable cases and 40 uploads validated, with complete fanouts and drained jobs.
Populated HTTP throughput improves, but room/messages p99 at 64 connections and
peak memory regress. The directory includes full ranges, raw data, a reproducible
report and a checksummed provenance archive. These are not Ryzen or Mac rates;
the older checkpoints below remain historical evidence, not current-code results.

The matched Elixir architecture review is preserved in
[`results/elixir-baseline-final-20261004/`](results/elixir-baseline-final-20261004/).
It compares untouched upstream `b6b82e5` with `a6225d7` on the same two-vCPU host,
using one pinned server CPU and one pinned load-generator CPU, immutable production
images, the same populated seed, alternating order, three repetitions, eight-second
HTTP samples, fifteen-second Cable samples, and five uploads. All response, fanout,
upload, and job-drain validations passed with zero errors. See the result directory's
README for exact commands, source/image hashes, profiling evidence, results, and
semantic caveats. These matched numbers supersede neither the four-language table
nor figures captured on other hardware.

### Frozen `7c1ed67` comparison

The October 5 comparison reruns untouched upstream `b6b82e5` against frozen candidate
`7c1ed67` for four balanced rounds on two native architectures:

- [`results/native-linux-b6b82e5-7c1ed67-20261005-nofile65536/`](results/native-linux-b6b82e5-7c1ed67-20261005-nofile65536/)
  is a clean native x86_64 Linux run. All response checks and deliveries passed, and
  every round ended with zero queued or failed jobs. Populated dynamic HTTP throughput
  regressed 16–47% at concurrency 16; Cable throughput regressed 5–20%.
- [`results/m4-arm64-b6b82e5-7c1ed67-20261005/`](results/m4-arm64-b6b82e5-7c1ed67-20261005/)
  retains native ARM64 Linux/OrbStack observations from an M4 Pro. Response, Cable and
  upload checks passed, but the strict audit is intentionally failed because one
  candidate round retained 1,125 queued jobs. Unrelated macOS host activity also
  reached load 29.06. Treat this table as qualified shared-host observations, not a
  clean or fully drained benchmark.

Both directories preserve all eight rounds, generated reports, raw hidden Cable and
memory samples, immutable image/runtime identities, fixture hashes and audit receipts.
The adjacent Linux directory without the `-nofile65536` suffix preserves an excluded
attempt that correctly aborted when the original 1,024-file descriptor limit prevented
the 1,000-client Cable case. No cross-platform or universal performance win is claimed.

### Exact populated seed

The exact seed used by the matched Elixir runs is preserved as
[`fixtures/campfire-benchmark-seed-default-20261004.tar.gz`](fixtures/campfire-benchmark-seed-default-20261004.tar.gz).
Restore it without reusing mutable data from either source checkout:

```sh
test "$(shasum -a 256 bench/fixtures/campfire-benchmark-seed-default-20261004.tar.gz | awk '{print $1}')" = \
  668a9e9b5a3f0e132a3be77503446af71887289d539ea8c053e12057a18c0a52
rm -rf parity/.seed/default
mkdir -p parity/.seed
tar -xzf bench/fixtures/campfire-benchmark-seed-default-20261004.tar.gz -C parity/.seed
test "$(shasum -a 256 parity/.seed/default/db/production.sqlite3 | awk '{print $1}')" = \
  bda9a5cd61d78d53f377cf07ee9268741caebc19b94a6efe782cafe827efc8db
```

`bench/run` copies this seed for every app invocation; it does not benchmark in the
preserved directory. The public Rust harness can regenerate the canonical logical
seed with `PARITY_RUNTIME=docker parity/bin/seed build default` at commit
`95af38bcc90f0ab06f703007ca25aa9e199536f1`. That process guarantees matching SQL
dump and storage-tree bytes, but independent SQLite files need not have the same raw
file hash. Use this archived fixture when reproducing the exact historical input.

The completed baseline is in `results/baseline-20261004/`. Profiling evidence and
changes are described in [TUNING.md](TUNING.md). To reproduce the matched comparison:

```sh
HTTP_SECS=4 LOAD_WAIT_SECS=30 bench/run --apps elixir,rust --reps 2 --out bench/results/tuned-fifo-20261004
bench/report bench/results/tuned-fifo-20261004 > bench/results/tuned-fifo-20261004/report.md
bench/compare bench/results/baseline-20261004 bench/results/tuned-fifo-20261004 > bench/results/tuning-comparison.md
```

Stop the owned parity fixtures and release fixture before timing; do not run other
compiles or load tests concurrently. Two rounds provide an initial comparison with
balanced order; use longer samples and more rounds for production sizing.

Preflight retains each port's actual decoded and compressed response sizes and
body hashes. Compare those with throughput: the same seeded room can produce
slightly different markup and compression ratios across implementations.

## Ruby / Elixir / Go / Rust comparison

The [October 4 comparison](results/ruby-elixir-go-rust-20261004/report.md) contains
two validated runs per version. Elixir comes from the earlier alternating
Elixir/older-Rust session. Ruby, Go and the optimized Rust image were measured
separately afterward on the same host, CPU sets and seed. The README shows medians;
the report retains ranges, response sizes, image IDs and original environments.
`comparison.json` identifies the source result directories. This is a benchmark
comparison, not a claim that every implementation passes the Elixir parity ledger.

The Go checkout was clean at `504428addff333549f1fc88b003c7331779a3c2a`.
The Rust image is the optimized `bench-emoon-pr43` build used by the Rust README,
with build revision `1ea6d6f6b24fd21e7d01e69b7c92df5c380bcbde` and image ID
`sha256:2ef6125fcd3f33531ef4c0bc9f14db1d6432d9517267bac956f7d268dd76f4e4`.
The harness also logs the local Rust checkout used for its seed and load generator;
that checkout revision does not identify the compiled production image.

To repeat these workloads with the recorded production images available locally:

```sh
HTTP_SECS=4 LOAD_WAIT_SECS=30 bench/run --apps reference --reps 2 --out bench/results/ruby-new
GO_IMAGE=once-campfire-go:readme-504428 HTTP_SECS=4 LOAD_WAIT_SECS=30 \
  bench/run --apps go --reps 2 --out bench/results/go-new
RUST_IMAGE=campfire-rust:bench-emoon-pr43 HTTP_SECS=4 LOAD_WAIT_SECS=30 \
  bench/run --apps rust --reps 2 --out bench/results/rust-new
```

The Go image was built from the sibling `once-campfire-go` checkout:

```sh
docker build --build-arg GIT_REVISION=504428addff333549f1fc88b003c7331779a3c2a \
  -t once-campfire-go:readme-504428 ../once-campfire-go
```

Set `GO_ROOT`, `GO_IMAGE`, `RUST_ROOT` or `RUST_IMAGE` for different checkouts or
images and retain the resulting environment record. All four versions are measured
through their production public servers with gzip. Go's own published HTTP table
uses its direct application listener with identity encoding, so its numbers are
not directly interchangeable with this comparison.
