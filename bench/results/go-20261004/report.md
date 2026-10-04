```
date: 2026-10-04T15:29:44+02:00
host: 7.2.5-4-omarchy, AMD RYZEN AI MAX+ 395 w/ Radeon 8060S, 32 threads, 30GB
server cpus: 8-11 (nproc 4); loadgen cpus: 12-15; network: host
env: WEB_CONCURRENCY=3 JOB_CONCURRENCY=3 RAILS_MAX_THREADS=5 
seed sha256: 433ccdce78759eef0524b2840a512077e52cc8e867f6c095430a8871d47a2e38  /home/dhh/Work/basecamp/once-campfire-rust/parity/.seed/default/db/production.sqlite3
elixir source digest: ad793a949fb8bc0f03f370a2b562b9226f3e86d9304fc4be6110ea72b0179056
rust extra env: 
workload: suites=http cable upload HTTP_SECS=4 HTTP_CONCS=1 16 64 CABLE_CLIENTS=100 500 1000 CABLE_TPUT_SECS=15 CABLE_POSTERS=4 UPLOAD_REPS=5 REPS=2
quiet wait: LOAD_MAX=1.5 LOAD_WAIT_SECS=30
user agent: (none)
go image: once-campfire-go:readme-504428 sha256:929c0116613a3696ff2ad276b7e11ef00554f5469003775361e136e760617c45 2026-10-04T15:28:42.439061071+02:00 unpacked_bytes=241608271
go HEAD: 504428addff333549f1fc88b003c7331779a3c2a (dirty: 0 files)
rust HEAD: 195457b (dirty: 0 files)
```

Reps: go 2. Cells: median [min–max].

### Startup and memory

| Metric | Go | Rust advantage over Rails |
|---|---|---|
| cold start: docker run → /up 200 (ms) | 145 [143–147] | – |
| idle memory.current (MiB) | 15.5 [9.0–22.0] | – |
| idle anon (MiB) | 8.00 [8.00–8.00] | – |
| peak memory.current under load (MiB) | 399 [389–409] | – |
| peak anon under load (MiB) | 349 [347–351] | – |

### HTTP (signed in as david; keep-alive; c = concurrent connections)

| Metric | Go | Rust advantage over Rails |
|---|---|---|
| room_show c=1 req/s | 990 [987–992] | – |
| room_show c=1 p50 ms | 1.00 [0.99–1.00] | – |
| room_show c=1 p99 ms | 1.31 [1.30–1.31] | – |
| room_show c=1 CPU µs/success | 1,027 [1,024–1,031] | – |
| room_show c=16 req/s | 3,860 [3,853–3,868] | – |
| room_show c=16 p50 ms | 3.41 [3.35–3.47] | – |
| room_show c=16 p99 ms | 12.8 [12.7–12.9] | – |
| room_show c=16 CPU µs/success | 1,007 [1,005–1,009] | – |
| room_show c=64 req/s | 3,810 [3,791–3,829] | – |
| room_show c=64 p50 ms | 14.0 [13.7–14.3] | – |
| room_show c=64 p99 ms | 60.5 [58.7–62.3] | – |
| room_show c=64 CPU µs/success | 1,019 [1,013–1,025] | – |
| messages_page c=1 req/s | 1,365 [1,362–1,368] | – |
| messages_page c=1 p50 ms | 0.72 [0.72–0.72] | – |
| messages_page c=1 p99 ms | 0.99 [0.98–0.99] | – |
| messages_page c=1 CPU µs/success | 741 [740–743] | – |
| messages_page c=16 req/s | 5,573 [5,554–5,591] | – |
| messages_page c=16 p50 ms | 2.18 [2.13–2.23] | – |
| messages_page c=16 p99 ms | 9.05 [8.98–9.12] | – |
| messages_page c=16 CPU µs/success | 697 [695–699] | – |
| messages_page c=64 req/s | 5,461 [5,460–5,462] | – |
| messages_page c=64 p50 ms | 8.48 [8.41–8.55] | – |
| messages_page c=64 p99 ms | 50.2 [50.0–50.4] | – |
| messages_page c=64 CPU µs/success | 711 [711–712] | – |
| sidebar c=1 req/s | 5,033 [5,029–5,037] | – |
| sidebar c=1 p50 ms | 0.19 [0.19–0.19] | – |
| sidebar c=1 p99 ms | 0.35 [0.34–0.36] | – |
| sidebar c=1 CPU µs/success | 212 [212–213] | – |
| sidebar c=16 req/s | 19,753 [19,554–19,953] | – |
| sidebar c=16 p50 ms | 0.67 [0.67–0.68] | – |
| sidebar c=16 p99 ms | 2.61 [2.58–2.64] | – |
| sidebar c=16 CPU µs/success | 186 [185–188] | – |
| sidebar c=64 req/s | 19,732 [19,617–19,848] | – |
| sidebar c=64 p50 ms | 3.10 [3.08–3.13] | – |
| sidebar c=64 p99 ms | 6.26 [6.25–6.27] | – |
| sidebar c=64 CPU µs/success | 188 [187–189] | – |
| search c=1 req/s | 1,762 [1,754–1,771] | – |
| search c=1 p50 ms | 0.55 [0.55–0.56] | – |
| search c=1 p99 ms | 0.83 [0.81–0.84] | – |
| search c=1 CPU µs/success | 588 [584–592] | – |
| search c=16 req/s | 7,053 [7,014–7,092] | – |
| search c=16 p50 ms | 1.66 [1.64–1.68] | – |
| search c=16 p99 ms | 7.57 [7.43–7.71] | – |
| search c=16 CPU µs/success | 546 [542–549] | – |
| search c=64 req/s | 6,971 [6,918–7,024] | – |
| search c=64 p50 ms | 8.07 [8.04–8.11] | – |
| search c=64 p99 ms | 31.9 [30.5–33.3] | – |
| search c=64 CPU µs/success | 552 [548–556] | – |
| avatar c=1 req/s | 39,037 [38,974–39,099] | – |
| avatar c=1 p50 ms | 0.02 [0.02–0.02] | – |
| avatar c=1 p99 ms | 0.05 [0.05–0.05] | – |
| avatar c=1 CPU µs/success | 18.9 [18.9–19.0] | – |
| avatar c=16 req/s | 200,856 [200,458–201,255] | – |
| avatar c=16 p50 ms | 0.06 [0.06–0.06] | – |
| avatar c=16 p99 ms | 0.35 [0.35–0.35] | – |
| avatar c=16 CPU µs/success | 16.6 [16.6–16.6] | – |
| avatar c=64 req/s | 202,708 [202,417–202,999] | – |
| avatar c=64 p50 ms | 0.22 [0.22–0.22] | – |
| avatar c=64 p99 ms | 1.49 [1.48–1.50] | – |
| avatar c=64 CPU µs/success | 16.7 [16.7–16.7] | – |
| static_css c=1 req/s | 54,649 [54,643–54,655] | – |
| static_css c=1 p50 ms | 0.02 [0.02–0.02] | – |
| static_css c=1 p99 ms | 0.03 [0.03–0.03] | – |
| static_css c=1 CPU µs/success | 13.4 [13.4–13.4] | – |
| static_css c=16 req/s | 289,554 [288,579–290,529] | – |
| static_css c=16 p50 ms | 0.04 [0.04–0.04] | – |
| static_css c=16 p99 ms | 0.20 [0.20–0.20] | – |
| static_css c=16 CPU µs/success | 11.0 [11.0–11.0] | – |
| static_css c=64 req/s | 295,610 [293,418–297,802] | – |
| static_css c=64 p50 ms | 0.16 [0.16–0.16] | – |
| static_css c=64 p99 ms | 0.98 [0.98–0.98] | – |
| static_css c=64 CPU µs/success | 10.9 [10.9–11.0] | – |
| up c=1 req/s | 33,455 [33,409–33,501] | – |
| up c=1 p50 ms | 0.03 [0.03–0.03] | – |
| up c=1 p99 ms | 0.06 [0.06–0.06] | – |
| up c=1 CPU µs/success | 25.4 [25.3–25.5] | – |
| up c=16 req/s | 154,476 [153,505–155,448] | – |
| up c=16 p50 ms | 0.08 [0.08–0.08] | – |
| up c=16 p99 ms | 0.42 [0.42–0.43] | – |
| up c=16 CPU µs/success | 23.0 [22.9–23.2] | – |
| up c=64 req/s | 154,068 [153,158–154,979] | – |
| up c=64 p50 ms | 0.31 [0.31–0.31] | – |
| up c=64 p99 ms | 1.74 [1.71–1.76] | – |
| up c=64 CPU µs/success | 23.1 [23.0–23.2] | – |
| post_message c=1 req/s | 1,655 [1,651–1,660] | – |
| post_message c=1 p50 ms | 0.52 [0.52–0.52] | – |
| post_message c=1 p99 ms | 3.53 [3.52–3.55] | – |
| post_message c=1 CPU µs/success | 618 [618–618] | – |
| post_message c=16 req/s | 4,767 [4,750–4,784] | – |
| post_message c=16 p50 ms | 2.18 [2.15–2.21] | – |
| post_message c=16 p99 ms | 12.8 [12.8–12.8] | – |
| post_message c=16 CPU µs/success | 570 [568–572] | – |
| post_message c=64 req/s | 4,660 [4,613–4,708] | – |
| post_message c=64 p50 ms | 10.2 [10.1–10.3] | – |
| post_message c=64 p99 ms | 59.7 [59.3–60.1] | – |
| post_message c=64 CPU µs/success | 578 [577–580] | – |

### HTTP errors / non-2xx-3xx (first rep, per app)

| Metric | Go | Rust advantage over Rails |
|---|---|---|
- go: none

### Action Cable fan-out (one room; chatter.js subscriptions per client)

| Metric | Go | Rust advantage over Rails |
|---|---|---|
| 100 clients: subscribed | 100 [100–100] | – |
| 100 clients: connect+subscribe all (s) | 0.06 [0.06–0.06] | – |
| 100 clients: paced post→one client p50 ms | 2.01 [1.97–2.04] | – |
| 100 clients: paced post→all clients p50 ms | 2.38 [2.37–2.38] | – |
| 100 clients: paced post→all clients p99 ms | 11.1 [7.7–14.5] | – |
| 100 clients: max sustained msgs/s (delivered to all) | 1,804 [1,802–1,806] | – |
| 100 clients: deliveries/s (client×message) | 180,410 [180,195–180,626] | – |
| 100 clients: saturated post→all p50 ms | 3.46 [3.41–3.52] | – |
| 100 clients: saturated POST p50 ms | 1.90 [1.90–1.90] | – |
| 500 clients: subscribed | 500 [500–500] | – |
| 500 clients: connect+subscribe all (s) | 0.11 [0.11–0.12] | – |
| 500 clients: paced post→one client p50 ms | 3.83 [3.79–3.86] | – |
| 500 clients: paced post→all clients p50 ms | 5.31 [5.26–5.37] | – |
| 500 clients: paced post→all clients p99 ms | 14.3 [10.2–18.4] | – |
| 500 clients: max sustained msgs/s (delivered to all) | 468 [461–475] | – |
| 500 clients: deliveries/s (client×message) | 233,966 [230,416–237,516] | – |
| 500 clients: saturated post→all p50 ms | 20.8 [20.4–21.2] | – |
| 500 clients: saturated POST p50 ms | 7.00 [6.94–7.06] | – |
| 1000 clients: subscribed | 1,000 [1,000–1,000] | – |
| 1000 clients: connect+subscribe all (s) | 0.17 [0.14–0.20] | – |
| 1000 clients: paced post→one client p50 ms | 5.90 [5.78–6.03] | – |
| 1000 clients: paced post→all clients p50 ms | 9.39 [9.28–9.51] | – |
| 1000 clients: paced post→all clients p99 ms | 15.9 [12.0–19.7] | – |
| 1000 clients: max sustained msgs/s (delivered to all) | 239 [239–240] | – |
| 1000 clients: deliveries/s (client×message) | 239,119 [238,557–239,681] | – |
| 1000 clients: saturated post→all p50 ms | 39.6 [38.4–40.7] | – |
| 1000 clients: saturated POST p50 ms | 15.2 [15.2–15.2] | – |

### Upload + thumbnail (black_hole.jpg, 505 KB)

| Metric | Go | Rust advantage over Rails |
|---|---|---|
| POST with attachment (ms) | 28.1 [27.6–28.5] | – |
| then GET thumb → 200 (ms) | 0.30 [0.30–0.30] | – |
| POST → thumbnail served (ms) | 28.4 [27.9–28.8] | – |

### Memory during cable fan-out, by process (MiB, peak within the phase)

App process: Elixir BEAM; Rails Puma master/workers when included;
Go/Rust's integrated campfire processes. Serving totals include native helpers, Redis and Thruster.
PSS apportions shared pages; RssAnon counts them in each process.

| Metric | Go | Rust advantage over Rails |
|---|---|---|
| 100 clients, all subscribed, idle: app process Pss | 139 [137–141] | – |
| 100 clients, all subscribed, idle: app process RssAnon | 117 [115–119] | – |
| 100 clients, all subscribed, idle: serving processes Pss | 139 [137–141] | – |
| 100 clients, all subscribed, idle: whole container Pss | 139 [137–141] | – |
| 100 clients, saturated fan-out: app process Pss | 139 [136–142] | – |
| 100 clients, saturated fan-out: app process RssAnon | 116 [114–119] | – |
| 100 clients, saturated fan-out: serving processes Pss | 139 [136–142] | – |
| 100 clients, saturated fan-out: whole container Pss | 139 [136–142] | – |
| 500 clients, all subscribed, idle: app process Pss | 141 [138–144] | – |
| 500 clients, all subscribed, idle: app process RssAnon | 119 [116–123] | – |
| 500 clients, all subscribed, idle: serving processes Pss | 141 [138–144] | – |
| 500 clients, all subscribed, idle: whole container Pss | 141 [138–144] | – |
| 500 clients, saturated fan-out: app process Pss | 170 [170–170] | – |
| 500 clients, saturated fan-out: app process RssAnon | 148 [148–149] | – |
| 500 clients, saturated fan-out: serving processes Pss | 170 [170–170] | – |
| 500 clients, saturated fan-out: whole container Pss | 170 [170–170] | – |
| 1000 clients, all subscribed, idle: app process Pss | 169 [167–170] | – |
| 1000 clients, all subscribed, idle: app process RssAnon | 147 [145–149] | – |
| 1000 clients, all subscribed, idle: serving processes Pss | 169 [167–170] | – |
| 1000 clients, all subscribed, idle: whole container Pss | 169 [167–170] | – |
| 1000 clients, saturated fan-out: app process Pss | 218 [217–219] | – |
| 1000 clients, saturated fan-out: app process RssAnon | 196 [196–196] | – |
| 1000 clients, saturated fan-out: serving processes Pss | 218 [217–219] | – |
| 1000 clients, saturated fan-out: whole container Pss | 218 [217–219] | – |
