```
date: 2026-10-05T20:17:41+00:00
host: 7.0.12-linuxkit, , 8 threads, 7GB
server cpus: 0-3 (nproc 4); loadgen cpus: 4-7; network: host
env: WEB_CONCURRENCY=3 JOB_CONCURRENCY=3 RAILS_MAX_THREADS=5 
seed sha256: 58e6bb4498a188b33a52bbb79d82499d96a531f9afb9fc736a801532ddba1817  /Users/lau/oss/once-campfire-rust/parity/.seed/default/db/production.sqlite3
elixir source digest: 65fffaffd56478bd4838c78c088a9123e793fdc004cad6d763f32a13761a32b6
rust extra env: 
workload: suites=http HTTP_SECS=4 HTTP_CONCS=1 16 64 CABLE_CLIENTS=100 500 1000 CABLE_TPUT_SECS=15 CABLE_POSTERS=4 UPLOAD_REPS=5 REPS=2
request logging (LOG_REQUESTS): false
parity ledger gate: skipped; runner: bench/docker-desktop
quiet wait: LOAD_MAX=1.5 LOAD_WAIT_SECS=120
user agent: (none)
elixir image: campfire-elixir:further-perf-r5 sha256:5f24e7a3fe875be2ca880c5b020a94fa3a631fadb0820af8aa7fd3578f2059a0 2026-10-05T20:17:27.765786137Z unpacked_bytes=1705233643
reference image: campfire-elixir:further-perf-r4 sha256:cd37417bb02555adcf86fbc4c1932f630f288c27e5c8a76f9dd2ec9ac98c27eb 2026-10-05T17:23:57.721164471Z unpacked_bytes=1705222560
rust HEAD: 64f8635 (dirty: 0 files)
```

Reps: reference 2, elixir 2. Cells: median [min–max].

### Startup and memory

| Metric | Rails | Elixir | Rust advantage over Elixir |
|---|---|---|---|
| cold start: docker run → /up 200 (ms) | 861 [663–1,059] | 7,520 [1,242–13,797] | – |
| idle memory.current (MiB) | 172 [171–173] | 164 [156–172] | – |
| idle anon (MiB) | 135 [131–139] | 132 [125–139] | – |
| peak memory.current under load (MiB) | 424 [421–427] | 418 [403–433] | – |
| peak anon under load (MiB) | 372 [371–374] | 369 [355–383] | – |

### HTTP (signed in as david; keep-alive; c = concurrent connections)

| Metric | Rails | Elixir | Rust advantage over Elixir |
|---|---|---|---|
| room_show c=1 req/s | 4,752 [4,749–4,755] | 4,536 [4,355–4,716] | – |
| room_show c=1 p50 ms | 0.21 [0.20–0.21] | 0.21 [0.21–0.21] | – |
| room_show c=1 p99 ms | 0.28 [0.28–0.29] | 0.40 [0.29–0.51] | – |
| room_show c=1 CPU µs/success | 278 [278–279] | 288 [280–297] | – |
| room_show c=16 req/s | 19,424 [19,371–19,477] | 16,019 [16,006–16,032] | – |
| room_show c=16 p50 ms | 0.72 [0.72–0.72] | 0.80 [0.78–0.81] | – |
| room_show c=16 p99 ms | 3.71 [3.71–3.71] | 4.13 [4.11–4.16] | – |
| room_show c=16 CPU µs/success | 203 [203–204] | 241 [239–243] | – |
| room_show c=64 req/s | 22,501 [21,406–23,596] | 17,653 [16,271–19,034] | – |
| room_show c=64 p50 ms | 2.60 [2.55–2.65] | 3.14 [2.86–3.41] | – |
| room_show c=64 p99 ms | 7.09 [6.42–7.77] | 10.1 [9.2–11.0] | – |
| room_show c=64 CPU µs/success | 174 [167–182] | 221 [202–240] | – |
| messages_page c=1 req/s | 6,053 [5,991–6,114] | 5,870 [5,797–5,943] | – |
| messages_page c=1 p50 ms | 0.16 [0.16–0.16] | 0.16 [0.16–0.16] | – |
| messages_page c=1 p99 ms | 0.23 [0.23–0.23] | 0.29 [0.23–0.35] | – |
| messages_page c=1 CPU µs/success | 235 [231–240] | 244 [241–246] | – |
| messages_page c=16 req/s | 21,320 [15,459–27,181] | 25,310 [24,304–26,316] | – |
| messages_page c=16 p50 ms | 0.52 [0.52–0.53] | 0.54 [0.53–0.56] | – |
| messages_page c=16 p99 ms | 3.45 [3.37–3.52] | 3.42 [3.40–3.44] | – |
| messages_page c=16 CPU µs/success | 179 [146–212] | 155 [149–162] | – |
| messages_page c=64 req/s | 18,708 [9,113–28,304] | 25,606 [23,710–27,502] | – |
| messages_page c=64 p50 ms | 3.61 [1.93–5.30] | 2.08 [1.97–2.19] | – |
| messages_page c=64 p99 ms | 18.6 [6.0–31.2] | 7.05 [6.36–7.75] | – |
| messages_page c=64 CPU µs/success | 271 [140–401] | 155 [143–166] | – |
| sidebar c=1 req/s | 4,234 [1,913–6,556] | 7,072 [6,968–7,176] | – |
| sidebar c=1 p50 ms | 0.19 [0.14–0.24] | 0.14 [0.14–0.14] | – |
| sidebar c=1 p99 ms | 2.59 [0.22–4.97] | 0.20 [0.19–0.20] | – |
| sidebar c=1 CPU µs/success | 415 [218–612] | 213 [211–215] | – |
| sidebar c=16 req/s | 22,205 [9,529–34,882] | 33,317 [32,608–34,026] | – |
| sidebar c=16 p50 ms | 0.78 [0.40–1.16] | 0.41 [0.41–0.42] | – |
| sidebar c=16 p99 ms | 5.78 [2.69–8.86] | 3.07 [3.02–3.12] | – |
| sidebar c=16 CPU µs/success | 232 [114–350] | 118 [116–120] | – |
| sidebar c=64 req/s | 24,832 [13,009–36,654] | 34,898 [33,542–36,253] | – |
| sidebar c=64 p50 ms | 2.60 [1.42–3.79] | 1.52 [1.47–1.57] | – |
| sidebar c=64 p99 ms | 13.2 [5.0–21.4] | 5.65 [5.39–5.91] | – |
| sidebar c=64 CPU µs/success | 195 [108–281] | 114 [109–118] | – |
| search c=1 req/s | 5,431 [4,171–6,691] | 6,592 [6,529–6,655] | – |
| search c=1 p50 ms | 0.15 [0.15–0.16] | 0.15 [0.15–0.15] | – |
| search c=1 p99 ms | 0.85 [0.20–1.49] | 0.22 [0.21–0.23] | – |
| search c=1 CPU µs/success | 259 [213–305] | 220 [219–221] | – |
| search c=16 req/s | 22,880 [15,833–29,926] | 29,027 [27,911–30,143] | – |
| search c=16 p50 ms | 0.58 [0.48–0.68] | 0.48 [0.47–0.49] | – |
| search c=16 p99 ms | 4.22 [3.00–5.45] | 3.26 [3.26–3.26] | – |
| search c=16 CPU µs/success | 182 [133–231] | 136 [131–141] | – |
| search c=64 req/s | 27,946 [24,638–31,254] | 30,075 [29,316–30,833] | – |
| search c=64 p50 ms | 1.88 [1.71–2.06] | 1.77 [1.72–1.82] | – |
| search c=64 p99 ms | 6.83 [5.54–8.11] | 6.18 [5.92–6.45] | – |
| search c=64 CPU µs/success | 142 [126–158] | 131 [128–134] | – |
| avatar c=1 req/s | 18,702 [18,212–19,192] | 18,243 [17,790–18,695] | – |
| avatar c=1 p50 ms | 0.05 [0.05–0.05] | 0.05 [0.05–0.05] | – |
| avatar c=1 p99 ms | 0.09 [0.08–0.10] | 0.08 [0.08–0.08] | – |
| avatar c=1 CPU µs/success | 55.0 [54.0–56.1] | 57.8 [57.0–58.5] | – |
| avatar c=16 req/s | 144,362 [136,416–152,309] | 139,423 [136,768–142,078] | – |
| avatar c=16 p50 ms | 0.10 [0.09–0.10] | 0.10 [0.10–0.10] | – |
| avatar c=16 p99 ms | 0.27 [0.24–0.30] | 0.29 [0.28–0.30] | – |
| avatar c=16 CPU µs/success | 24.7 [24.1–25.3] | 24.6 [24.2–25.1] | – |
| avatar c=64 req/s | 181,478 [176,109–186,848] | 182,516 [170,526–194,507] | – |
| avatar c=64 p50 ms | 0.31 [0.31–0.32] | 0.31 [0.29–0.33] | – |
| avatar c=64 p99 ms | 1.01 [0.95–1.06] | 1.02 [0.92–1.12] | – |
| avatar c=64 CPU µs/success | 21.8 [21.2–22.4] | 21.7 [20.3–23.1] | – |
| static_css c=1 req/s | 15,992 [15,293–16,691] | 19,647 [19,548–19,746] | – |
| static_css c=1 p50 ms | 0.06 [0.06–0.07] | 0.05 [0.05–0.05] | – |
| static_css c=1 p99 ms | 0.08 [0.08–0.09] | 0.08 [0.08–0.08] | – |
| static_css c=1 CPU µs/success | 47.0 [43.6–50.4] | 54.3 [54.3–54.4] | – |
| static_css c=16 req/s | 147,401 [139,383–155,419] | 143,853 [137,487–150,218] | – |
| static_css c=16 p50 ms | 0.10 [0.09–0.10] | 0.10 [0.09–0.10] | – |
| static_css c=16 p99 ms | 0.28 [0.26–0.30] | 0.28 [0.25–0.31] | – |
| static_css c=16 CPU µs/success | 23.2 [22.6–23.8] | 23.3 [22.7–24.0] | – |
| static_css c=64 req/s | 198,146 [190,454–205,839] | 194,802 [189,358–200,247] | – |
| static_css c=64 p50 ms | 0.29 [0.28–0.29] | 0.29 [0.28–0.29] | – |
| static_css c=64 p99 ms | 0.95 [0.89–1.01] | 0.96 [0.90–1.01] | – |
| static_css c=64 CPU µs/success | 20.0 [19.3–20.7] | 20.2 [19.6–20.9] | – |
| up c=1 req/s | 13,154 [12,946–13,362] | 13,188 [12,947–13,428] | – |
| up c=1 p50 ms | 0.07 [0.07–0.07] | 0.07 [0.07–0.07] | – |
| up c=1 p99 ms | 0.11 [0.11–0.11] | 0.11 [0.10–0.12] | – |
| up c=1 CPU µs/success | 79.3 [78.3–80.2] | 79.0 [77.9–80.0] | – |
| up c=16 req/s | 91,939 [85,868–98,010] | 92,653 [89,354–95,951] | – |
| up c=16 p50 ms | 0.16 [0.15–0.17] | 0.16 [0.16–0.16] | – |
| up c=16 p99 ms | 0.41 [0.37–0.46] | 0.42 [0.39–0.46] | – |
| up c=16 CPU µs/success | 42.5 [40.5–44.4] | 42.2 [40.7–43.8] | – |
| up c=64 req/s | 95,032 [92,510–97,555] | 94,532 [91,965–97,100] | – |
| up c=64 p50 ms | 0.63 [0.62–0.64] | 0.64 [0.63–0.66] | – |
| up c=64 p99 ms | 1.61 [1.52–1.71] | 1.72 [1.67–1.77] | – |
| up c=64 CPU µs/success | 41.9 [40.8–42.9] | 41.9 [40.9–42.9] | – |
| post_message c=1 req/s | 1,127 [1,064–1,190] | 1,132 [1,084–1,181] | – |
| post_message c=1 p50 ms | 0.68 [0.68–0.69] | 0.67 [0.65–0.70] | – |
| post_message c=1 p99 ms | 7.13 [6.83–7.42] | 6.87 [6.35–7.39] | – |
| post_message c=1 CPU µs/success | 1,775 [1,727–1,824] | 1,762 [1,708–1,817] | – |
| post_message c=16 req/s | 2,267 [2,150–2,385] | 2,192 [2,131–2,253] | – |
| post_message c=16 p50 ms | 5.48 [5.20–5.76] | 5.72 [5.54–5.91] | – |
| post_message c=16 p99 ms | 15.7 [15.1–16.2] | 15.9 [15.8–15.9] | – |
| post_message c=16 CPU µs/success | 1,279 [1,227–1,330] | 1,330 [1,297–1,363] | – |
| post_message c=64 req/s | 2,201 [2,080–2,322] | 2,010 [1,850–2,169] | – |
| post_message c=64 p50 ms | 28.2 [27.0–29.5] | 30.1 [28.7–31.5] | – |
| post_message c=64 p99 ms | 40.6 [38.4–42.8] | 53.0 [40.1–65.9] | – |
| post_message c=64 CPU µs/success | 1,311 [1,252–1,370] | 1,449 [1,332–1,566] | – |

### HTTP errors / non-2xx-3xx (first rep, per app)

| Metric | Rails | Elixir | Rust advantage over Elixir |
|---|---|---|---|
- reference: none
- elixir: none

### Action Cable fan-out (one room; chatter.js subscriptions per client)

| Metric | Rails | Elixir | Rust advantage over Elixir |
|---|---|---|---|

### Upload + thumbnail (black_hole.jpg, 505 KB)

| Metric | Rails | Elixir | Rust advantage over Elixir |
|---|---|---|---|
| POST with attachment (ms) | – | – | – |
| then GET thumb → 200 (ms) | – | – | – |
| POST → thumbnail served (ms) | – | – | – |

### Memory during cable fan-out, by process (MiB, peak within the phase)

App process: Elixir BEAM; Rails Puma master/workers when included;
Go/Rust's integrated campfire processes. Serving totals include native helpers, Redis and Thruster.
PSS apportions shared pages; RssAnon counts them in each process.

| Metric | Rails | Elixir | Rust advantage over Elixir |
|---|---|---|---|
