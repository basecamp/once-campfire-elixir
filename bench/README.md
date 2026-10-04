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
Rust owns its queue internally; its external Resque state is unavailable.

Elixir runs BEAM, Redis, native media/parser helpers, and the same pinned Thruster
binary as Rails. Rust runs its own integrated HTTP/proxy/job implementation.
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
