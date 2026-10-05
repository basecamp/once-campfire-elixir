```
date: 2026-10-05T17:24:10+00:00
host: 7.0.12-linuxkit, , 8 threads, 7GB
server cpus: 0-3 (nproc 4); loadgen cpus: 4-7; network: host
env: WEB_CONCURRENCY=3 JOB_CONCURRENCY=3 RAILS_MAX_THREADS=5 
seed sha256: 58e6bb4498a188b33a52bbb79d82499d96a531f9afb9fc736a801532ddba1817  /Users/lau/oss/once-campfire-rust/parity/.seed/default/db/production.sqlite3
elixir source digest: f84778bedf993cde9028c8846023cf3a19278a1946728e618f1167ebf6435f9a
rust extra env: 
workload: suites=http cable HTTP_SECS=4 HTTP_CONCS=1 16 64 CABLE_CLIENTS=100 500 1000 CABLE_TPUT_SECS=15 CABLE_POSTERS=4 UPLOAD_REPS=5 REPS=3
request logging (LOG_REQUESTS): false
parity ledger gate: skipped; runner: bench/docker-desktop
quiet wait: LOAD_MAX=1.5 LOAD_WAIT_SECS=120
user agent: (none)
elixir image: campfire-elixir:further-perf-r4 sha256:cd37417bb02555adcf86fbc4c1932f630f288c27e5c8a76f9dd2ec9ac98c27eb 2026-10-05T17:23:57.721164471Z unpacked_bytes=1705222560
reference image: campfire-elixir:further-perf-r3 sha256:cf9f408c1e0180f461443b19476d0d481d9813531f7cc9bae54a9b3512a41b5c 2026-10-05T15:54:56.913347668Z unpacked_bytes=1705213032
rust HEAD: 64f8635 (dirty: 0 files)
```

Reps: reference 3, elixir 3. Cells: median [min–max].

### Startup and memory

| Metric | Rails | Elixir | Rust advantage over Elixir |
|---|---|---|---|
| cold start: docker run → /up 200 (ms) | 2,451 [1,038–2,601] | 1,473 [1,068–1,757] | – |
| idle memory.current (MiB) | 174 [161–175] | 168 [157–170] | – |
| idle anon (MiB) | 134 [127–140] | 136 [124–138] | – |
| peak memory.current under load (MiB) | 404 [394–412] | 481 [467–487] | – |
| peak anon under load (MiB) | 326 [319–333] | 396 [394–405] | – |

### HTTP (signed in as david; keep-alive; c = concurrent connections)

| Metric | Rails | Elixir | Rust advantage over Elixir |
|---|---|---|---|
| room_show c=1 req/s | 2,269 [1,937–2,417] | 4,584 [4,164–4,636] | – |
| room_show c=1 p50 ms | 0.41 [0.40–0.44] | 0.21 [0.21–0.21] | – |
| room_show c=1 p99 ms | 0.90 [0.66–1.80] | 0.34 [0.31–0.53] | – |
| room_show c=1 CPU µs/success | 760 [736–852] | 291 [284–305] | – |
| room_show c=16 req/s | 5,214 [3,804–7,465] | 16,760 [13,660–18,098] | – |
| room_show c=16 p50 ms | 2.63 [1.98–2.79] | 0.80 [0.75–0.92] | – |
| room_show c=16 p99 ms | 10.2 [5.2–27.5] | 3.88 [3.77–4.67] | – |
| room_show c=16 CPU µs/success | 700 [509–894] | 230 [218–277] | – |
| room_show c=64 req/s | 6,211 [4,882–7,389] | 18,520 [11,433–18,979] | – |
| room_show c=64 p50 ms | 9.50 [8.38–11.16] | 2.95 [2.88–4.62] | – |
| room_show c=64 p99 ms | 23.1 [13.3–31.9] | 9.66 [9.27–24.62] | – |
| room_show c=64 CPU µs/success | 605 [518–743] | 208 [205–342] | – |
| messages_page c=1 req/s | 2,995 [2,323–3,229] | 5,339 [5,241–6,032] | – |
| messages_page c=1 p50 ms | 0.29 [0.29–0.32] | 0.17 [0.16–0.17] | – |
| messages_page c=1 p99 ms | 0.55 [0.54–1.87] | 0.27 [0.24–0.58] | – |
| messages_page c=1 CPU µs/success | 559 [542–648] | 255 [233–270] | – |
| messages_page c=16 req/s | 7,785 [5,086–8,503] | 24,349 [23,252–25,256] | – |
| messages_page c=16 p50 ms | 1.92 [1.77–2.65] | 0.56 [0.54–0.58] | – |
| messages_page c=16 p99 ms | 3.83 [3.29–10.39] | 3.47 [3.44–3.50] | – |
| messages_page c=16 CPU µs/success | 450 [415–616] | 162 [156–166] | – |
| messages_page c=64 req/s | 6,692 [1,189–8,225] | 25,323 [25,024–25,988] | – |
| messages_page c=64 p50 ms | 9.12 [7.56–21.07] | 2.14 [2.06–2.18] | – |
| messages_page c=64 p99 ms | 17.5 [12.5–622.1] | 6.98 [6.96–7.00] | – |
| messages_page c=64 CPU µs/success | 500 [432–1,906] | 155 [152–157] | – |
| sidebar c=1 req/s | 1,633 [1,309–2,066] | 6,834 [6,380–6,957] | – |
| sidebar c=1 p50 ms | 0.51 [0.47–0.57] | 0.14 [0.14–0.14] | – |
| sidebar c=1 p99 ms | 1.12 [0.74–3.62] | 0.21 [0.20–0.23] | – |
| sidebar c=1 CPU µs/success | 948 [872–1,174] | 217 [216–220] | – |
| sidebar c=16 req/s | 3,820 [2,697–5,424] | 31,599 [31,277–32,159] | – |
| sidebar c=16 p50 ms | 3.45 [2.70–3.52] | 0.43 [0.42–0.43] | – |
| sidebar c=16 p99 ms | 13.3 [7.6–45.7] | 3.22 [2.83–3.25] | – |
| sidebar c=16 CPU µs/success | 938 [691–1,224] | 125 [123–126] | – |
| sidebar c=64 req/s | 3,969 [3,770–5,386] | 34,005 [33,996–34,065] | – |
| sidebar c=64 p50 ms | 14.1 [11.3–15.3] | 1.54 [1.51–1.56] | – |
| sidebar c=64 p99 ms | 32.3 [18.5–36.7] | 5.83 [5.68–5.88] | – |
| sidebar c=64 CPU µs/success | 921 [703–962] | 117 [116–117] | – |
| search c=1 req/s | 2,156 [1,836–2,322] | 6,586 [6,282–6,606] | – |
| search c=1 p50 ms | 0.40 [0.40–0.43] | 0.15 [0.15–0.15] | – |
| search c=1 p99 ms | 1.03 [0.84–2.31] | 0.23 [0.22–0.26] | – |
| search c=1 CPU µs/success | 825 [813–941] | 220 [219–223] | – |
| search c=16 req/s | 4,249 [4,206–6,010] | 28,005 [27,772–28,083] | – |
| search c=16 p50 ms | 2.83 [2.48–3.14] | 0.49 [0.49–0.50] | – |
| search c=16 p99 ms | 11.0 [6.3–26.0] | 3.29 [3.29–3.33] | – |
| search c=16 CPU µs/success | 822 [629–846] | 141 [140–142] | – |
| search c=64 req/s | 4,056 [2,234–5,765] | 29,224 [27,302–29,563] | – |
| search c=64 p50 ms | 13.0 [10.8–17.2] | 1.79 [1.76–1.89] | – |
| search c=64 p99 ms | 55.1 [16.8–341.5] | 6.29 [6.20–7.06] | – |
| search c=64 CPU µs/success | 870 [658–1,382] | 134 [133–143] | – |
| avatar c=1 req/s | 13,413 [12,025–17,285] | 15,059 [14,498–18,313] | – |
| avatar c=1 p50 ms | 0.06 [0.05–0.07] | 0.07 [0.05–0.07] | – |
| avatar c=1 p99 ms | 0.14 [0.09–0.39] | 0.09 [0.08–0.09] | – |
| avatar c=1 CPU µs/success | 59.2 [47.5–75.2] | 51.0 [49.5–57.4] | – |
| avatar c=16 req/s | 96,882 [79,558–138,247] | 134,012 [132,059–137,818] | – |
| avatar c=16 p50 ms | 0.13 [0.10–0.15] | 0.10 [0.10–0.10] | – |
| avatar c=16 p99 ms | 0.69 [0.31–0.94] | 0.32 [0.29–0.34] | – |
| avatar c=16 CPU µs/success | 30.5 [25.9–37.5] | 25.2 [24.9–25.7] | – |
| avatar c=64 req/s | 107,614 [79,372–113,404] | 173,035 [169,886–174,404] | – |
| avatar c=64 p50 ms | 0.44 [0.42–0.48] | 0.32 [0.32–0.32] | – |
| avatar c=64 p99 ms | 2.89 [2.27–5.47] | 1.11 [1.08–1.17] | – |
| avatar c=64 CPU µs/success | 33.9 [33.7–43.3] | 22.8 [22.6–23.1] | – |
| static_css c=1 req/s | 14,157 [11,966–19,442] | 19,084 [17,727–19,395] | – |
| static_css c=1 p50 ms | 0.07 [0.05–0.07] | 0.05 [0.05–0.05] | – |
| static_css c=1 p99 ms | 0.14 [0.08–0.28] | 0.08 [0.08–0.09] | – |
| static_css c=1 CPU µs/success | 53.8 [47.8–54.8] | 54.7 [54.5–55.6] | – |
| static_css c=16 req/s | 102,890 [100,418–135,533] | 139,546 [127,825–140,898] | – |
| static_css c=16 p50 ms | 0.12 [0.10–0.12] | 0.10 [0.10–0.10] | – |
| static_css c=16 p99 ms | 0.67 [0.33–0.68] | 0.30 [0.29–0.38] | – |
| static_css c=16 CPU µs/success | 29.8 [25.3–30.3] | 23.8 [23.6–25.6] | – |
| static_css c=64 req/s | 129,898 [97,731–179,985] | 192,358 [192,350–200,293] | – |
| static_css c=64 p50 ms | 0.36 [0.30–0.39] | 0.29 [0.28–0.29] | – |
| static_css c=64 p99 ms | 2.44 [1.13–3.64] | 0.94 [0.92–0.95] | – |
| static_css c=64 CPU µs/success | 28.2 [21.9–33.0] | 20.6 [19.8–20.6] | – |
| up c=1 req/s | 8,103 [7,120–10,204] | 13,185 [11,804–13,214] | – |
| up c=1 p50 ms | 0.10 [0.09–0.11] | 0.07 [0.07–0.08] | – |
| up c=1 p99 ms | 0.42 [0.14–0.73] | 0.12 [0.12–0.12] | – |
| up c=1 CPU µs/success | 110 [101–132] | 78.5 [75.3–78.7] | – |
| up c=16 req/s | 41,030 [36,218–57,342] | 87,175 [84,575–93,160] | – |
| up c=16 p50 ms | 0.30 [0.26–0.31] | 0.17 [0.16–0.17] | – |
| up c=16 p99 ms | 2.02 [0.65–2.75] | 0.48 [0.42–0.53] | – |
| up c=16 CPU µs/success | 88.8 [69.0–98.9] | 44.1 [42.2–44.6] | – |
| up c=64 req/s | 44,184 [30,177–59,491] | 92,061 [88,209–92,403] | – |
| up c=64 p50 ms | 1.23 [1.02–1.44] | 0.65 [0.63–0.66] | – |
| up c=64 p99 ms | 5.21 [2.40–12.18] | 1.82 [1.77–2.06] | – |
| up c=64 CPU µs/success | 88.8 [66.7–123.7] | 43.3 [43.1–44.8] | – |
| post_message c=1 req/s | 597 [576–839] | 1,113 [960–1,209] | – |
| post_message c=1 p50 ms | 1.14 [0.97–1.20] | 0.69 [0.67–0.78] | – |
| post_message c=1 p99 ms | 8.68 [7.05–8.99] | 6.58 [6.36–7.18] | – |
| post_message c=1 CPU µs/success | 3,615 [2,821–3,693] | 1,790 [1,703–1,943] | – |
| post_message c=16 req/s | 1,479 [1,472–2,004] | 2,121 [2,113–2,212] | – |
| post_message c=16 p50 ms | 8.60 [6.29–9.27] | 5.86 [5.76–6.21] | – |
| post_message c=16 p99 ms | 26.2 [16.7–27.5] | 16.1 [15.9–16.2] | – |
| post_message c=16 CPU µs/success | 2,398 [1,749–2,429] | 1,353 [1,323–1,409] | – |
| post_message c=64 req/s | 1,463 [1,263–1,948] | 2,106 [2,070–2,183] | – |
| post_message c=64 p50 ms | 40.0 [31.4–43.7] | 29.5 [28.4–29.6] | – |
| post_message c=64 p99 ms | 73.9 [50.3–159.9] | 45.1 [44.3–48.7] | – |
| post_message c=64 CPU µs/success | 2,428 [1,810–2,806] | 1,365 [1,317–1,375] | – |

### HTTP errors / non-2xx-3xx (first rep, per app)

| Metric | Rails | Elixir | Rust advantage over Elixir |
|---|---|---|---|
- reference: none
- elixir: none

### Action Cable fan-out (one room; chatter.js subscriptions per client)

| Metric | Rails | Elixir | Rust advantage over Elixir |
|---|---|---|---|
| 100 clients: subscribed | 100 [100–100] | 100 [100–100] | – |
| 100 clients: connect+subscribe all (s) | 0.07 [0.06–0.11] | 0.06 [0.06–0.07] | – |
| 100 clients: paced post→one client p50 ms | 7.84 [7.62–8.54] | 7.04 [6.82–7.54] | – |
| 100 clients: paced post→all clients p50 ms | 8.46 [7.98–8.79] | 7.49 [7.03–7.90] | – |
| 100 clients: paced post→all clients p99 ms | 23.3 [13.1–184.4] | 19.1 [18.6–21.5] | – |
| 100 clients: max sustained msgs/s (delivered to all) | 667 [512–950] | 1,032 [1,018–1,068] | – |
| 100 clients: deliveries/s (client×message) | 66,662 [51,189–95,021] | 103,155 [101,818–106,853] | – |
| 100 clients: saturated post→all p50 ms | 4.25 [3.44–5.29] | 3.10 [3.10–3.21] | – |
| 100 clients: saturated POST p50 ms | 4.28 [3.43–5.39] | 3.06 [3.05–3.15] | – |
| 500 clients: subscribed | 500 [500–500] | 500 [500–500] | – |
| 500 clients: connect+subscribe all (s) | 0.24 [0.14–0.25] | 0.19 [0.18–0.19] | – |
| 500 clients: paced post→one client p50 ms | 14.2 [12.1–14.5] | 13.0 [12.7–13.1] | – |
| 500 clients: paced post→all clients p50 ms | 15.7 [13.5–16.1] | 14.9 [14.6–15.0] | – |
| 500 clients: paced post→all clients p99 ms | 42.1 [22.8–454.7] | 21.2 [19.1–25.6] | – |
| 500 clients: max sustained msgs/s (delivered to all) | 354 [204–355] | 366 [361–383] | – |
| 500 clients: deliveries/s (client×message) | 176,866 [101,780–177,620] | 182,873 [180,562–191,299] | – |
| 500 clients: saturated post→all p50 ms | 11.2 [11.2–15.6] | 10.9 [10.6–11.1] | – |
| 500 clients: saturated POST p50 ms | 10.8 [10.7–15.5] | 10.4 [10.0–10.6] | – |
| 1000 clients: subscribed | 1,000 [1,000–1,000] | 1,000 [1,000–1,000] | – |
| 1000 clients: connect+subscribe all (s) | 0.36 [0.28–0.64] | 0.33 [0.32–0.39] | – |
| 1000 clients: paced post→one client p50 ms | 18.0 [17.6–18.7] | 17.7 [16.8–18.0] | – |
| 1000 clients: paced post→all clients p50 ms | 21.1 [20.5–21.4] | 20.5 [20.1–21.4] | – |
| 1000 clients: paced post→all clients p99 ms | 29.8 [27.5–32.0] | 25.6 [24.8–26.0] | – |
| 1000 clients: max sustained msgs/s (delivered to all) | 190 [134–200] | 202 [202–208] | – |
| 1000 clients: deliveries/s (client×message) | 189,532 [133,579–200,177] | 202,119 [201,835–208,407] | – |
| 1000 clients: saturated post→all p50 ms | 20.9 [20.3–26.6] | 20.1 [19.8–20.3] | – |
| 1000 clients: saturated POST p50 ms | 20.4 [19.6–26.6] | 19.3 [18.8–19.4] | – |

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
| 100 clients, all subscribed, idle: app process Pss | – | 373 [367–380] | – |
| 100 clients, all subscribed, idle: app process RssAnon | – | 332 [326–340] | – |
| 100 clients, all subscribed, idle: serving processes Pss | 0.00 [0.00–0.00] | 373 [367–380] | – |
| 100 clients, all subscribed, idle: whole container Pss | 265 [262–282] | 374 [368–381] | – |
| 100 clients, saturated fan-out: app process Pss | – | 331 [327–332] | – |
| 100 clients, saturated fan-out: app process RssAnon | – | 290 [287–291] | – |
| 100 clients, saturated fan-out: serving processes Pss | 0.00 [0.00–0.00] | 331 [327–332] | – |
| 100 clients, saturated fan-out: whole container Pss | 282 [279–293] | 332 [328–333] | – |
| 500 clients, all subscribed, idle: app process Pss | – | 327 [324–336] | – |
| 500 clients, all subscribed, idle: app process RssAnon | – | 286 [284–295] | – |
| 500 clients, all subscribed, idle: serving processes Pss | 0.00 [0.00–0.00] | 327 [324–336] | – |
| 500 clients, all subscribed, idle: whole container Pss | 270 [266–283] | 328 [325–337] | – |
| 500 clients, saturated fan-out: app process Pss | – | 373 [368–385] | – |
| 500 clients, saturated fan-out: app process RssAnon | – | 333 [327–344] | – |
| 500 clients, saturated fan-out: serving processes Pss | 0.00 [0.00–0.00] | 373 [368–385] | – |
| 500 clients, saturated fan-out: whole container Pss | 333 [315–336] | 374 [368–386] | – |
| 1000 clients, all subscribed, idle: app process Pss | – | 366 [358–384] | – |
| 1000 clients, all subscribed, idle: app process RssAnon | – | 325 [318–344] | – |
| 1000 clients, all subscribed, idle: serving processes Pss | 0.00 [0.00–0.00] | 366 [358–384] | – |
| 1000 clients, all subscribed, idle: whole container Pss | 330 [316–334] | 367 [359–385] | – |
| 1000 clients, saturated fan-out: app process Pss | – | 437 [434–445] | – |
| 1000 clients, saturated fan-out: app process RssAnon | – | 397 [394–404] | – |
| 1000 clients, saturated fan-out: serving processes Pss | 0.00 [0.00–0.00] | 437 [434–445] | – |
| 1000 clients, saturated fan-out: whole container Pss | 368 [360–375] | 438 [436–446] | – |
