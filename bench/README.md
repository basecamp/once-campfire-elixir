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
image IDs, workload validation, and external Resque queue backlog where applicable.
Go and Rust own their queues internally; their external Resque state is unavailable.

Elixir runs BEAM, Redis, native media/parser helpers, and the same pinned Thruster
binary as Rails. Go and Rust run their own integrated HTTP/proxy/job implementations.
These are their actual production process models. Loopback measurements exclude
NIC/TLS costs. Cable uses one authenticated user with many connections, so this
workload is not a distinct-user capacity claim.

Keep each result directory and `env.txt`. `bench/report DIR` produces median and
range tables. `bench/profile-elixir` profiles a warmed populated room on an isolated
release; profiler timings are diagnostic and are never used as benchmark results.
The toolkit benchmark command measures whole-process primitive wall time rather
than full application throughput.

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
