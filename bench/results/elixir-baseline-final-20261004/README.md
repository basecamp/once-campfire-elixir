# Matched Elixir baseline and final comparison

This directory is the accepted performance evidence for the Elixir runtime
architecture work. `report.md` contains every median and observed range; the JSON,
JSONL, stderr, memory, queue, validation, environment, and uptime files are the raw
records used to produce it.

## Equivalent conditions

- Baseline source: untouched upstream `b6b82e50a653c4060136bb04e805eb78fd76ba10`.
- Candidate source: `a6225d7e1c006d90950c91ddd2b15622d5f87df9`.
- Immutable production images: `sha256:52e35947d029026caff725621e4a11edfc5dccce5530f409ab25b9e0ed09ba24` and `sha256:58e9da531de4c76580b335484046945abbad1302dcdd21f3c58204e670fcbc9a`.
- Host: two-vCPU Intel Xeon 2.60 GHz orb with about 3.8 GiB RAM.
- Server pinned to CPU 0; load generator and process sampler pinned to CPU 1.
- Host networking, identical environment, populated SQLite database and storage tree.
- Seed DB SHA-256: `bda9a5cd61d78d53f377cf07ee9268741caebc19b94a6efe782cafe827efc8db`.
- Seed tree SHA-256: `c58532c20db34e3df10e5c39969cd328f4bd815e5beb1dabfdfa2af5805e29c5`.
- Locked load generator SHA-256: `a611112f1cf606deeb511bd7e955a57b5fa28bacc09bffdd88dd6064b0b8a488`, built with `rust:1.98.1-slim@sha256:4cd829461bd5c4d511c32e269da9cb8929223b666519d8004e35fc8d1d771ab7`.
- Three repetitions in alternating app order. Each endpoint is warmed, then sampled
  for eight seconds at 1, 16 and 64 connections. Cable uses 100 and 500 clients,
  four posters and fifteen-second throughput samples. Upload uses five samples.
- Every HTTP status/body, Cable subscription/delivery, upload/thumbnail, and job
  drain was validated. Both images completed with zero errors and zero failed jobs.

The exact environment and full image hashes are in `env.txt`. The benchmark command
was:

```sh
SERVER_CPUS=0 LOADGEN_CPUS=1 PROCMEM_CPUS=1 \
HTTP_SECS=8 HTTP_CONCS='1 16 64' \
CABLE_CLIENTS='100 500' CABLE_TPUT_SECS=15 CABLE_POSTERS=4 UPLOAD_REPS=5 \
BASELINE_IMAGE=campfire-elixir:baseline-b6b82e5 \
CANDIDATE_IMAGE=campfire-elixir:candidate-a6225d7 \
BASELINE_SHA=b6b82e50a653c4060136bb04e805eb78fd76ba10 \
CANDIDATE_SHA=a6225d7e1c006d90950c91ddd2b15622d5f87df9 \
bench/run --apps baseline,candidate --reps 3 \
  --out bench/results/elixir-baseline-final-20261004
```

## Results and variance

Selected medians `[minimum–maximum]`:

| Metric | Upstream baseline | Final candidate |
|---|---:|---:|
| post message, c=16 req/s | 104 [99–109] | 119 [118–131] |
| post message, c=64 req/s | 109 [106–114] | 134 [134–147] |
| post message, c=64 p50 ms | 579 [544–596] | 460 [428–473] |
| post message, c=64 p99 ms | 742 [718–758] | 552 [514–561] |
| 100-client fanout msg/s | 28.0 [27.4–29.0] | 33.6 [31.2–34.1] |
| 500-client fanout msg/s | 8.30 [8.10–9.40] | 9.60 [8.20–10.40] |
| 500-client all-client p99 ms | 194 [124–203] | 139 [110–166] |
| room page, c=64 req/s | 70.3 [69.7–71.2] | 63.8 [60.2–64.2] |
| upload plus thumbnail ms | 385 [371–425] | 385 [344–486] |
| peak anonymous container MiB | 269 [259–277] | 285 [283–288] |
| 500-client saturated whole-container PSS MiB | 275 [271–281] | 296 [295–297] |

Most read endpoint ranges overlap. The robust gains are concurrent posting and
fanout; room rendering at c=64 and memory are regressions. No overall performance
improvement is claimed.

## Profiling and design consequence

Before the final optimization, the current candidate was profiled under the same
one-server-CPU placement. Raw `:eprof` output is in the sibling directories
`profile-candidate-01a1675-{http,write,cable}`. The write profile attributed 13.50%
to SQLite prepare, 16.77% to port commands and 3.83% to stepping; HTTP attributed
5.92% to prepare and 2.63% to stepping. DBConnection checkout, holder, ETS ownership,
and prepare operations remained visible. The Cable profile is diagnostic only: the
profiler slowed setup enough that only 295 of 500 clients subscribed by 120 seconds.

The final implementation therefore keeps one direct SQLite writer, uses a read-only
DBConnection pool when more than one scheduler is online, and avoids that pool when
only one scheduler is available. This is runtime-adaptive OTP design, not a special
case for an endpoint or expected benchmark value. Full parity passed before timing.

The excluded 1,000-client baseline attempt is preserved in
`../elixir-baseline-candidate-20261004-incomplete-1000/`: untouched upstream could
establish only 160 clients and reported 52 failures by the 120-second deadline on
this host. The accepted suite uses the highest client counts both images completed.

## Non-equivalence caveats

The tweet and repository's four-language table were produced on different hardware
and/or implementation sessions and cannot be compared numerically with this run.
This comparison isolates Elixir revisions only. It preserves Campfire's endpoint
semantics, SQLite schema/storage, cookies, CSRF fields, frontend, Action Cable wire
protocol, durable job processing and full parity gates. Redis is no longer on normal
fragment-cache or Cable hot paths, but remains for durable Rails-compatible jobs;
removing it would require a separately verified transactional queue design. Loopback
traffic excludes NIC and TLS costs, and one authenticated user with many Cable
connections is not a distinct-user capacity claim.
