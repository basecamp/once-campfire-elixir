```
date: 2026-10-04T23:16:15+00:00
host: 6.1.158+, Intel(R) Xeon(R) Processor @ 2.60GHz, 2 threads, 3GB
server cpus: 0 (nproc 1); loadgen cpus: 1; network: host
env: WEB_CONCURRENCY=1 JOB_CONCURRENCY=1 RAILS_MAX_THREADS=5
seed sha256: bda9a5cd61d78d53f377cf07ee9268741caebc19b94a6efe782cafe827efc8db  /home/user/workspace/repo/parity/.seed/default/db/production.sqlite3
seed tree sha256: c58532c20db34e3df10e5c39969cd328f4bd815e5beb1dabfdfa2af5805e29c5  -
loadgen sha256: a611112f1cf606deeb511bd7e955a57b5fa28bacc09bffdd88dd6064b0b8a488  /home/user/workspace/repo/target/bench/release/loadgen
loadgen build image: rust@sha256:4cd829461bd5c4d511c32e269da9cb8929223b666519d8004e35fc8d1d771ab7
elixir source digest: 76dd233a90d7c99455301a744bc292f3fcc184a25ee75b2da21eaa1d54b15b39
rust extra env:
workload: suites=http cable upload HTTP_SECS=3 HTTP_CONCS=1 64 CABLE_CLIENTS=100 CABLE_TPUT_SECS=5 CABLE_POSTERS=4 UPLOAD_REPS=2 REPS=1
quiet wait: LOAD_MAX=100 LOAD_WAIT_SECS=900
user agent: (none)
baseline image: campfire-elixir:candidate-01a1675 sha256:6118496bddaf253301a8caf9fa18d1f56cf442a70141f9095a2171cdc35a641c 2026-10-04T21:22:00.50099719Z unpacked_bytes=2582425025
candidate image: campfire-elixir:candidate-adaptive-read sha256:f0ab3227f6d8ee3c2605aaa283cfecf3ba4c2d34991b91be43361e56166876e2 2026-10-04T22:37:50.82790572Z unpacked_bytes=2582425018
baseline source: 01a16759408898313538775543078f42646b830e
candidate source: working-tree-adaptive-read
```

Reps: baseline 1, candidate 1. Cells: median [min–max].

### Startup and memory

| Metric | Elixir baseline | Elixir candidate | Candidate advantage over baseline |
|---|---|---|---|
| cold start: docker run → /up 200 (ms) | 2,430 | 1,957 | 1.2× |
| idle memory.current (MiB) | 125 | 126 | 1.0× |
| idle anon (MiB) | 92.0 | 93.0 | 1.0× |
| peak memory.current under load (MiB) | 229 | 236 | 1.0× |
| peak anon under load (MiB) | 195 | 203 | 1.0× |

### HTTP (signed in as david; keep-alive; c = concurrent connections)

| Metric | Elixir baseline | Elixir candidate | Candidate advantage over baseline |
|---|---|---|---|
| room_show c=1 req/s | 64.1 | 71.4 | 1.1× |
| room_show c=1 p50 ms | 15.2 | 13.7 | 1.1× |
| room_show c=1 p99 ms | 22.8 | 20.8 | 1.1× |
| room_show c=1 CPU µs/success | 15,331 | 13,685 | 1.1× |
| room_show c=64 req/s | 67.3 | 70.8 | 1.1× |
| room_show c=64 p50 ms | 912 | 882 | 1.0× |
| room_show c=64 p99 ms | 1,065 | 978 | 1.1× |
| room_show c=64 CPU µs/success | 14,592 | 13,888 | 1.1× |
| messages_page c=1 req/s | 75.8 | 94.4 | 1.2× |
| messages_page c=1 p50 ms | 12.6 | 10.4 | 1.2× |
| messages_page c=1 p99 ms | 19.9 | 13.8 | 1.4× |
| messages_page c=1 CPU µs/success | 12,784 | 10,403 | 1.2× |
| messages_page c=64 req/s | 87.4 | 97.6 | 1.1× |
| messages_page c=64 p50 ms | 714 | 646 | 1.1× |
| messages_page c=64 p99 ms | 842 | 732 | 1.2× |
| messages_page c=64 CPU µs/success | 11,362 | 10,217 | 1.1× |
| sidebar c=1 req/s | 128 | 102 | 0.8× |
| sidebar c=1 p50 ms | 7.45 | 5.96 | 1.2× |
| sidebar c=1 p99 ms | 13.3 | 52.2 | 0.3× |
| sidebar c=1 CPU µs/success | 7,586 | 6,205 | 1.2× |
| sidebar c=64 req/s | 135 | 182 | 1.3× |
| sidebar c=64 p50 ms | 460 | 345 | 1.3× |
| sidebar c=64 p99 ms | 542 | 374 | 1.4× |
| sidebar c=64 CPU µs/success | 7,350 | 5,471 | 1.3× |
| search c=1 req/s | 103 | 122 | 1.2× |
| search c=1 p50 ms | 9.12 | 7.90 | 1.2× |
| search c=1 p99 ms | 14.6 | 13.9 | 1.0× |
| search c=1 CPU µs/success | 9,380 | 7,979 | 1.2× |
| search c=64 req/s | 119 | 142 | 1.2× |
| search c=64 p50 ms | 475 | 435 | 1.1× |
| search c=64 p99 ms | 615 | 492 | 1.2× |
| search c=64 CPU µs/success | 8,267 | 6,987 | 1.2× |
| avatar c=1 req/s | 2,876 | 3,385 | 1.2× |
| avatar c=1 p50 ms | 0.29 | 0.26 | 1.2× |
| avatar c=1 p99 ms | 1.16 | 0.85 | 1.4× |
| avatar c=1 CPU µs/success | 215 | 182 | 1.2× |
| avatar c=64 req/s | 9,054 | 9,340 | 1.0× |
| avatar c=64 p50 ms | 6.64 | 6.47 | 1.0× |
| avatar c=64 p99 ms | 19.6 | 18.8 | 1.0× |
| avatar c=64 CPU µs/success | 101 | 98.9 | 1.0× |
| static_css c=1 req/s | 3,003 | 3,326 | 1.1× |
| static_css c=1 p50 ms | 0.28 | 0.26 | 1.1× |
| static_css c=1 p99 ms | 1.10 | 1.02 | 1.1× |
| static_css c=1 CPU µs/success | 195 | 180 | 1.1× |
| static_css c=64 req/s | 11,517 | 12,028 | 1.0× |
| static_css c=64 p50 ms | 5.15 | 5.16 | 1.0× |
| static_css c=64 p99 ms | 16.0 | 13.8 | 1.2× |
| static_css c=64 CPU µs/success | 78.4 | 77.2 | 1.0× |
| up c=1 req/s | 649 | 917 | 1.4× |
| up c=1 p50 ms | 1.02 | 1.00 | 1.0× |
| up c=1 p99 ms | 12.6 | 2.48 | 5.1× |
| up c=1 CPU µs/success | 1,002 | 972 | 1.0× |
| up c=64 req/s | 767 | 815 | 1.1× |
| up c=64 p50 ms | 77.3 | 71.9 | 1.1× |
| up c=64 p99 ms | 144 | 136 | 1.1× |
| up c=64 CPU µs/success | 1,288 | 1,206 | 1.1× |
| post_message c=1 req/s | 48.4 | 89.9 | 1.9× |
| post_message c=1 p50 ms | 22.8 | 11.3 | 2.0× |
| post_message c=1 p99 ms | 38.3 | 18.6 | 2.1× |
| post_message c=1 CPU µs/success | 20,405 | 10,865 | 1.9× |
| post_message c=64 req/s | 76.0 | 137 | 1.8× |
| post_message c=64 p50 ms | 846 | 439 | 1.9× |
| post_message c=64 p99 ms | 991 | 564 | 1.8× |
| post_message c=64 CPU µs/success | 13,000 | 7,119 | 1.8× |

### HTTP errors / non-2xx-3xx (first rep, per app)

| Metric | Elixir baseline | Elixir candidate | Candidate advantage over baseline |
|---|---|---|---|
- baseline: none
- candidate: none

### Action Cable fan-out (one room; chatter.js subscriptions per client)

| Metric | Elixir baseline | Elixir candidate | Candidate advantage over baseline |
|---|---|---|---|
| 100 clients: subscribed | 100 | 100 | 1.0× |
| 100 clients: connect+subscribe all (s) | 0.60 | 0.36 | 1.7× |
| 100 clients: paced post→one client p50 ms | 20.4 | 15.1 | 1.3× |
| 100 clients: paced post→all clients p50 ms | 24.9 | 18.8 | 1.3× |
| 100 clients: paced post→all clients p99 ms | 69.3 | 33.2 | 2.1× |
| 100 clients: max sustained msgs/s (delivered to all) | 24.7 | 32.6 | 1.3× |
| 100 clients: deliveries/s (client×message) | 2,472 | 3,257 | 1.3× |
| 100 clients: saturated post→all p50 ms | 134 | 91.1 | 1.5× |
| 100 clients: saturated POST p50 ms | 159 | 122 | 1.3× |

### Upload + thumbnail (black_hole.jpg, 505 KB)

| Metric | Elixir baseline | Elixir candidate | Candidate advantage over baseline |
|---|---|---|---|
| POST with attachment (ms) | 330 | 364 | 0.9× |
| then GET thumb → 200 (ms) | 1.75 | 1.95 | 0.9× |
| POST → thumbnail served (ms) | 348 | 401 | 0.9× |

### Memory during cable fan-out, by process (MiB, peak within the phase)

App process: Elixir BEAM; Rails Puma master/workers when included;
Go/Rust's integrated campfire processes. Serving totals include native helpers, Redis and Thruster.
PSS apportions shared pages; RssAnon counts them in each process.

| Metric | Elixir baseline | Elixir candidate | Candidate advantage over baseline |
|---|---|---|---|
| 100 clients, all subscribed, idle: app process Pss | 160 | 197 | 0.8× |
| 100 clients, all subscribed, idle: app process RssAnon | 118 | 155 | 0.8× |
| 100 clients, all subscribed, idle: serving processes Pss | 186 | 223 | 0.8× |
| 100 clients, all subscribed, idle: whole container Pss | 187 | 224 | 0.8× |
| 100 clients, saturated fan-out: app process Pss | 165 | 176 | 0.9× |
| 100 clients, saturated fan-out: app process RssAnon | 124 | 134 | 0.9× |
| 100 clients, saturated fan-out: serving processes Pss | 194 | 207 | 0.9× |
| 100 clients, saturated fan-out: whole container Pss | 195 | 208 | 0.9× |
