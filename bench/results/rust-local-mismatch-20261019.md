# Why the local Rust measurement does not match the published review

## The review's environment

`docs/performance-review.md` states: 16 concurrent clients, an AMD Ryzen AI MAX+ 395 with 32 GB, each
application on **four pinned hardware cores (CPUs 8–11)** with the generator on **12–15**, container
images, warmup plus three eight-second samples, validated responses and audited writes. The four
untouched columns (Elixir, Go, Rust, C) explicitly retain their earlier verified figures rather than
being rerun.

Our host is an M1 Pro laptop: no CPU pinning exists (macOS has no taskset), the generator shares the
machine with the server, and load averages ranged from 4 to 12 during the window.

## What the local numbers say

| workload @16 | local | published |
|---|---:|---:|
| Express, room page | 43,756 | 42,203–43,372 |
| Rust, room page | 11,778–12,002 | ~105,000 (reads, mixed profile) |

Express reproduced its published figure locally, so the environment alone does not explain Rust
being roughly nine times below its published number. The local Rust run is therefore not in its
benchmarked configuration.

Ruled out by measurement or inspection:

- the listener: hitting the Thruster-emulating front (`HTTP_PORT`) instead of the app listener
  (`TARGET_PORT`) measured 11,778 vs 12,002, no difference;
- the build profile: `[profile.release]` sets `lto = "fat"` and `codegen-units = 1`, and we built
  `--release`;
- the reader pool: `RAILS_MAX_THREADS` defaults to 5, which is what the review's four-core topology
  would also use.

## A parity signal in the same run

The shared harness refused to prepare contracts against local Rust because `/searches?q=coffee`
returns message ids that differ from the seed SQL, while the same database passes for Elixir, Go and
Express. That is a behavioural difference in the local build, not a measurement artefact, and it is
consistent with the local checkout not being the reviewed configuration for this fixture.

## What it would take

Run Rust through the harness it was measured with (`bench/run` in that repository), which requires
container images and CPU pinning — not available under the current no-docker constraint. The
alternative is to find why its search and room paths differ from the reference on this fixture
before trusting any local number for it.
