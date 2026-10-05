```
date: 2026-10-05T15:55:10+00:00
host: 7.0.12-linuxkit, , 8 threads, 7GB
server cpus: 0-3 (nproc 4); loadgen cpus: 4-7; network: host
env: WEB_CONCURRENCY=3 JOB_CONCURRENCY=3 RAILS_MAX_THREADS=5 
seed sha256: 58e6bb4498a188b33a52bbb79d82499d96a531f9afb9fc736a801532ddba1817  /Users/lau/oss/once-campfire-rust/parity/.seed/default/db/production.sqlite3
elixir source digest: c95ebdcbb522fd614da9c50c546713f64b7a193324ddd30c610213fe21ae53eb
rust extra env: 
workload: suites=http cable HTTP_SECS=4 HTTP_CONCS=1 16 64 CABLE_CLIENTS=100 500 1000 CABLE_TPUT_SECS=15 CABLE_POSTERS=4 UPLOAD_REPS=5 REPS=3
request logging (LOG_REQUESTS): false
parity ledger gate: skipped; runner: bench/docker-desktop
quiet wait: LOAD_MAX=1.5 LOAD_WAIT_SECS=120
user agent: (none)
elixir image: campfire-elixir:further-perf-r3 sha256:cf9f408c1e0180f461443b19476d0d481d9813531f7cc9bae54a9b3512a41b5c 2026-10-05T15:54:56.913347668Z unpacked_bytes=1705213032
reference image: campfire-elixir:further-perf-r2 sha256:9f25d3da2160a42b326141bb8ad730f5158ade580823868cad725babd936da4d 2026-10-05T08:08:41.624360552Z unpacked_bytes=1705209136
rust HEAD: 64f8635 (dirty: 0 files)
```

Reps: reference 3, elixir 3. Cells: median [min–max].

### Startup and memory

| Metric | Rails | Elixir | Rust advantage over Elixir |
|---|---|---|---|
| cold start: docker run → /up 200 (ms) | 857 [720–1,030] | 1,036 [886–1,219] | – |
| idle memory.current (MiB) | 172 [157–174] | 174 [159–174] | – |
| idle anon (MiB) | 140 [124–142] | 141 [126–142] | – |
| peak memory.current under load (MiB) | 386 [381–389] | 410 [388–412] | – |
| peak anon under load (MiB) | 301 [300–310] | 330 [310–331] | – |

### HTTP (signed in as david; keep-alive; c = concurrent connections)

| Metric | Rails | Elixir | Rust advantage over Elixir |
|---|---|---|---|
| room_show c=1 req/s | 1,946 [1,944–1,957] | 1,790 [693–2,443] | – |
| room_show c=1 p50 ms | 0.50 [0.50–0.50] | 0.62 [0.39–1.25] | – |
| room_show c=1 p99 ms | 0.79 [0.79–0.81] | 0.81 [0.68–4.32] | – |
| room_show c=1 CPU µs/success | 898 [897–918] | 812 [728–1,922] | – |
| room_show c=16 req/s | 6,453 [6,434–6,516] | 7,464 [3,661–7,767] | – |
| room_show c=16 p50 ms | 2.29 [2.28–2.32] | 2.00 [1.93–3.71] | – |
| room_show c=16 p99 ms | 6.43 [6.08–7.29] | 4.91 [4.79–12.65] | – |
| room_show c=16 CPU µs/success | 590 [588–595] | 510 [491–977] | – |
| room_show c=64 req/s | 6,012 [5,952–6,119] | 7,131 [5,464–7,475] | – |
| room_show c=64 p50 ms | 10.3 [10.1–10.4] | 8.60 [8.29–11.08] | – |
| room_show c=64 p99 ms | 16.3 [16.2–16.6] | 14.6 [12.8–21.2] | – |
| room_show c=64 CPU µs/success | 635 [624–636] | 536 [511–685] | – |
| messages_page c=1 req/s | 2,261 [2,227–2,503] | 2,567 [2,465–3,275] | – |
| messages_page c=1 p50 ms | 0.39 [0.38–0.40] | 0.33 [0.28–0.40] | – |
| messages_page c=1 p99 ms | 0.72 [0.68–0.73] | 0.61 [0.52–0.89] | – |
| messages_page c=1 CPU µs/success | 695 [679–721] | 575 [518–580] | – |
| messages_page c=16 req/s | 7,752 [6,713–7,780] | 6,256 [4,205–8,294] | – |
| messages_page c=16 p50 ms | 1.90 [1.89–2.24] | 2.32 [1.81–3.21] | – |
| messages_page c=16 p99 ms | 5.86 [5.54–6.05] | 7.26 [3.37–12.14] | – |
| messages_page c=16 CPU µs/success | 489 [486–562] | 528 [421–743] | – |
| messages_page c=64 req/s | 6,754 [6,221–7,116] | 5,703 [3,354–8,117] | – |
| messages_page c=64 p50 ms | 9.20 [8.79–9.62] | 10.3 [7.6–14.9] | – |
| messages_page c=64 p99 ms | 15.8 [13.2–20.6] | 25.6 [11.5–84.8] | – |
| messages_page c=64 CPU µs/success | 561 [534–604] | 580 [434–928] | – |
| sidebar c=1 req/s | 2,002 [1,828–2,085] | 1,784 [1,389–1,965] | – |
| sidebar c=1 p50 ms | 0.47 [0.46–0.48] | 0.50 [0.47–0.65] | – |
| sidebar c=1 p99 ms | 0.88 [0.77–1.14] | 1.47 [0.92–1.74] | – |
| sidebar c=1 CPU µs/success | 893 [876–935] | 977 [910–1,085] | – |
| sidebar c=16 req/s | 5,272 [5,144–5,539] | 4,481 [3,744–5,691] | – |
| sidebar c=16 p50 ms | 2.75 [2.66–2.81] | 3.00 [2.56–4.09] | – |
| sidebar c=16 p99 ms | 7.82 [7.26–8.39] | 9.05 [8.09–10.19] | – |
| sidebar c=16 CPU µs/success | 712 [674–726] | 811 [658–985] | – |
| sidebar c=64 req/s | 5,648 [4,580–5,658] | 4,832 [2,752–5,595] | – |
| sidebar c=64 p50 ms | 11.0 [10.8–13.5] | 11.9 [10.9–19.0] | – |
| sidebar c=64 p99 ms | 17.7 [17.3–23.0] | 25.2 [17.3–89.7] | – |
| sidebar c=64 CPU µs/success | 672 [670–823] | 765 [675–1,292] | – |
| search c=1 req/s | 2,406 [1,890–2,428] | 2,227 [2,094–2,371] | – |
| search c=1 p50 ms | 0.40 [0.40–0.46] | 0.40 [0.39–0.41] | – |
| search c=1 p99 ms | 0.74 [0.74–1.23] | 1.03 [0.78–1.39] | – |
| search c=1 CPU µs/success | 793 [787–923] | 801 [799–863] | – |
| search c=16 req/s | 6,374 [6,013–6,397] | 6,155 [5,365–6,298] | – |
| search c=16 p50 ms | 2.35 [2.33–2.43] | 2.44 [2.38–2.56] | – |
| search c=16 p99 ms | 6.16 [6.08–6.42] | 5.94 [5.75–8.73] | – |
| search c=16 CPU µs/success | 596 [593–629] | 616 [602–686] | – |
| search c=64 req/s | 5,708 [5,475–5,854] | 5,231 [4,684–5,939] | – |
| search c=64 p50 ms | 10.7 [10.6–11.0] | 11.0 [10.4–13.4] | – |
| search c=64 p99 ms | 18.3 [16.2–19.6] | 22.9 [16.8–23.5] | – |
| search c=64 CPU µs/success | 661 [647–687] | 708 [636–786] | – |
| avatar c=1 req/s | 15,519 [15,256–17,278] | 17,233 [16,564–19,646] | – |
| avatar c=1 p50 ms | 0.07 [0.05–0.07] | 0.05 [0.05–0.06] | – |
| avatar c=1 p99 ms | 0.09 [0.09–0.10] | 0.09 [0.08–0.13] | – |
| avatar c=1 CPU µs/success | 51.0 [50.9–60.0] | 54.7 [54.2–59.3] | – |
| avatar c=16 req/s | 131,407 [125,542–137,964] | 121,905 [115,724–126,700] | – |
| avatar c=16 p50 ms | 0.10 [0.10–0.11] | 0.11 [0.11–0.11] | – |
| avatar c=16 p99 ms | 0.33 [0.31–0.35] | 0.37 [0.35–0.50] | – |
| avatar c=16 CPU µs/success | 26.3 [25.1–27.2] | 26.7 [26.0–28.2] | – |
| avatar c=64 req/s | 172,659 [163,793–182,426] | 175,336 [145,268–181,170] | – |
| avatar c=64 p50 ms | 0.32 [0.31–0.34] | 0.33 [0.31–0.35] | – |
| avatar c=64 p99 ms | 1.13 [1.02–1.19] | 1.05 [1.02–1.87] | – |
| avatar c=64 CPU µs/success | 22.8 [21.6–24.1] | 22.5 [21.7–26.1] | – |
| static_css c=1 req/s | 19,119 [16,605–19,733] | 19,201 [18,197–24,042] | – |
| static_css c=1 p50 ms | 0.05 [0.05–0.05] | 0.05 [0.04–0.05] | – |
| static_css c=1 p99 ms | 0.08 [0.08–0.13] | 0.08 [0.08–0.12] | – |
| static_css c=1 CPU µs/success | 55.5 [54.2–59.7] | 55.3 [44.6–56.9] | – |
| static_css c=16 req/s | 140,494 [116,525–148,576] | 144,449 [122,477–144,745] | – |
| static_css c=16 p50 ms | 0.10 [0.10–0.11] | 0.10 [0.10–0.10] | – |
| static_css c=16 p99 ms | 0.29 [0.28–0.47] | 0.28 [0.28–0.48] | – |
| static_css c=16 CPU µs/success | 24.2 [23.4–28.3] | 23.5 [23.4–26.4] | – |
| static_css c=64 req/s | 193,002 [186,077–196,175] | 180,534 [141,578–196,026] | – |
| static_css c=64 p50 ms | 0.29 [0.29–0.30] | 0.30 [0.29–0.34] | – |
| static_css c=64 p99 ms | 0.98 [0.90–1.08] | 1.28 [0.98–1.94] | – |
| static_css c=64 CPU µs/success | 20.5 [20.2–21.2] | 21.4 [20.1–26.3] | – |
| up c=1 req/s | 10,224 [10,187–10,621] | 10,700 [10,082–11,322] | – |
| up c=1 p50 ms | 0.09 [0.09–0.09] | 0.09 [0.07–0.09] | – |
| up c=1 p99 ms | 0.15 [0.14–0.16] | 0.18 [0.14–0.28] | – |
| up c=1 CPU µs/success | 101 [98–103] | 101 [89–101] | – |
| up c=16 req/s | 58,153 [57,859–58,730] | 56,441 [38,805–59,081] | – |
| up c=16 p50 ms | 0.26 [0.26–0.26] | 0.26 [0.25–0.32] | – |
| up c=16 p99 ms | 0.62 [0.61–0.69] | 0.71 [0.63–1.98] | – |
| up c=16 CPU µs/success | 67.6 [67.4–68.4] | 69.5 [66.6–88.2] | – |
| up c=64 req/s | 59,040 [57,525–60,060] | 53,220 [50,575–60,329] | – |
| up c=64 p50 ms | 1.03 [1.02–1.06] | 1.08 [1.05–1.08] | – |
| up c=64 p99 ms | 2.62 [2.51–2.98] | 3.21 [2.40–4.38] | – |
| up c=64 CPU µs/success | 67.4 [66.4–69.1] | 74.9 [66.1–77.0] | – |
| post_message c=1 req/s | 834 [778–865] | 826 [741–841] | – |
| post_message c=1 p50 ms | 0.99 [0.97–1.07] | 0.98 [0.94–1.05] | – |
| post_message c=1 p99 ms | 6.80 [6.43–7.67] | 6.40 [5.84–7.02] | – |
| post_message c=1 CPU µs/success | 2,888 [2,810–3,041] | 2,875 [2,794–3,256] | – |
| post_message c=16 req/s | 2,023 [2,013–2,079] | 2,033 [1,412–2,068] | – |
| post_message c=16 p50 ms | 6.24 [6.19–6.33] | 6.20 [6.18–8.93] | – |
| post_message c=16 p99 ms | 17.2 [16.3–17.4] | 17.2 [16.4–45.4] | – |
| post_message c=16 CPU µs/success | 1,766 [1,744–1,793] | 1,746 [1,728–2,425] | – |
| post_message c=64 req/s | 2,102 [2,031–2,115] | 2,054 [1,661–2,064] | – |
| post_message c=64 p50 ms | 29.4 [29.4–30.2] | 29.8 [29.7–34.9] | – |
| post_message c=64 p99 ms | 41.5 [41.0–45.3] | 49.2 [44.0–65.2] | – |
| post_message c=64 CPU µs/success | 1,726 [1,719–1,761] | 1,749 [1,728–2,183] | – |

### HTTP errors / non-2xx-3xx (first rep, per app)

| Metric | Rails | Elixir | Rust advantage over Elixir |
|---|---|---|---|
- reference: none
- elixir: none

### Action Cable fan-out (one room; chatter.js subscriptions per client)

| Metric | Rails | Elixir | Rust advantage over Elixir |
|---|---|---|---|
| 100 clients: subscribed | 100 [100–100] | 100 [100–100] | – |
| 100 clients: connect+subscribe all (s) | 0.06 [0.06–0.06] | 0.06 [0.06–0.07] | – |
| 100 clients: paced post→one client p50 ms | 7.83 [7.09–7.85] | 8.19 [7.43–8.83] | – |
| 100 clients: paced post→all clients p50 ms | 8.16 [7.29–8.28] | 8.74 [7.84–9.20] | – |
| 100 clients: paced post→all clients p99 ms | 12.6 [11.4–14.2] | 12.4 [10.2–19.8] | – |
| 100 clients: max sustained msgs/s (delivered to all) | 1,025 [1,015–1,034] | 1,010 [742–1,033] | – |
| 100 clients: deliveries/s (client×message) | 102,469 [101,484–103,360] | 100,951 [74,210–103,325] | – |
| 100 clients: saturated post→all p50 ms | 3.18 [3.16–3.22] | 3.23 [3.14–4.38] | – |
| 100 clients: saturated POST p50 ms | 3.17 [3.16–3.20] | 3.22 [3.13–4.33] | – |
| 500 clients: subscribed | 500 [500–500] | 500 [500–500] | – |
| 500 clients: connect+subscribe all (s) | 0.15 [0.15–0.19] | 0.14 [0.14–0.15] | – |
| 500 clients: paced post→one client p50 ms | 13.6 [12.6–14.0] | 13.2 [12.9–14.8] | – |
| 500 clients: paced post→all clients p50 ms | 14.8 [14.7–15.9] | 16.1 [15.5–16.8] | – |
| 500 clients: paced post→all clients p99 ms | 25.5 [19.4–26.8] | 21.5 [19.9–22.5] | – |
| 500 clients: max sustained msgs/s (delivered to all) | 363 [361–371] | 371 [337–373] | – |
| 500 clients: deliveries/s (client×message) | 181,460 [180,724–185,569] | 185,522 [168,599–186,460] | – |
| 500 clients: saturated post→all p50 ms | 11.1 [10.8–11.1] | 10.8 [10.8–11.8] | – |
| 500 clients: saturated POST p50 ms | 10.6 [10.3–10.6] | 10.3 [10.3–11.3] | – |
| 1000 clients: subscribed | 1,000 [1,000–1,000] | 1,000 [1,000–1,000] | – |
| 1000 clients: connect+subscribe all (s) | 0.26 [0.22–0.27] | 0.28 [0.27–0.32] | – |
| 1000 clients: paced post→one client p50 ms | 18.0 [16.9–18.3] | 18.7 [17.7–19.9] | – |
| 1000 clients: paced post→all clients p50 ms | 21.1 [19.9–21.4] | 21.4 [21.0–23.1] | – |
| 1000 clients: paced post→all clients p99 ms | 27.8 [27.5–31.1] | 26.2 [25.3–472.6] | – |
| 1000 clients: max sustained msgs/s (delivered to all) | 168 [147–189] | 194 [143–204] | – |
| 1000 clients: deliveries/s (client×message) | 168,250 [147,166–189,097] | 193,630 [142,804–204,208] | – |
| 1000 clients: saturated post→all p50 ms | 21.7 [21.3–22.7] | 20.5 [19.8–20.5] | – |
| 1000 clients: saturated POST p50 ms | 20.8 [20.6–22.2] | 19.6 [19.2–19.7] | – |

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
| 100 clients, all subscribed, idle: app process Pss | – | 281 [255–291] | – |
| 100 clients, all subscribed, idle: app process RssAnon | – | 241 [214–250] | – |
| 100 clients, all subscribed, idle: serving processes Pss | 0.00 [0.00–0.00] | 281 [255–291] | – |
| 100 clients, all subscribed, idle: whole container Pss | 284 [274–292] | 282 [256–292] | – |
| 100 clients, saturated fan-out: app process Pss | – | 293 [276–299] | – |
| 100 clients, saturated fan-out: app process RssAnon | – | 253 [235–259] | – |
| 100 clients, saturated fan-out: serving processes Pss | 0.00 [0.00–0.00] | 293 [276–299] | – |
| 100 clients, saturated fan-out: whole container Pss | 287 [272–293] | 294 [277–300] | – |
| 500 clients, all subscribed, idle: app process Pss | – | 271 [269–272] | – |
| 500 clients, all subscribed, idle: app process RssAnon | – | 231 [229–232] | – |
| 500 clients, all subscribed, idle: serving processes Pss | 0.00 [0.00–0.00] | 271 [269–272] | – |
| 500 clients, all subscribed, idle: whole container Pss | 264 [262–275] | 272 [270–274] | – |
| 500 clients, saturated fan-out: app process Pss | – | 341 [322–346] | – |
| 500 clients, saturated fan-out: app process RssAnon | – | 301 [281–306] | – |
| 500 clients, saturated fan-out: serving processes Pss | 0.00 [0.00–0.00] | 341 [322–346] | – |
| 500 clients, saturated fan-out: whole container Pss | 339 [326–352] | 342 [322–347] | – |
| 1000 clients, all subscribed, idle: app process Pss | – | 296 [291–320] | – |
| 1000 clients, all subscribed, idle: app process RssAnon | – | 256 [251–279] | – |
| 1000 clients, all subscribed, idle: serving processes Pss | 0.00 [0.00–0.00] | 296 [291–320] | – |
| 1000 clients, all subscribed, idle: whole container Pss | 289 [276–300] | 298 [292–321] | – |
| 1000 clients, saturated fan-out: app process Pss | – | 370 [350–371] | – |
| 1000 clients, saturated fan-out: app process RssAnon | – | 329 [310–330] | – |
| 1000 clients, saturated fan-out: serving processes Pss | 0.00 [0.00–0.00] | 370 [350–371] | – |
| 1000 clients, saturated fan-out: whole container Pss | 343 [342–346] | 371 [351–372] | – |
