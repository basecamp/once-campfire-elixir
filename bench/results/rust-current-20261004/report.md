```
date: 2026-10-04T15:39:18+02:00
host: 7.2.5-4-omarchy, AMD RYZEN AI MAX+ 395 w/ Radeon 8060S, 32 threads, 30GB
server cpus: 8-11 (nproc 4); loadgen cpus: 12-15; network: host
env: WEB_CONCURRENCY=3 JOB_CONCURRENCY=3 RAILS_MAX_THREADS=5 
seed sha256: 433ccdce78759eef0524b2840a512077e52cc8e867f6c095430a8871d47a2e38  /home/dhh/Work/basecamp/once-campfire-rust/parity/.seed/default/db/production.sqlite3
elixir source digest: ad793a949fb8bc0f03f370a2b562b9226f3e86d9304fc4be6110ea72b0179056
rust extra env: 
workload: suites=http cable upload HTTP_SECS=4 HTTP_CONCS=1 16 64 CABLE_CLIENTS=100 500 1000 CABLE_TPUT_SECS=15 CABLE_POSTERS=4 UPLOAD_REPS=5 REPS=2
quiet wait: LOAD_MAX=1.5 LOAD_WAIT_SECS=30
user agent: (none)
rust image: campfire-rust:bench-emoon-pr43 sha256:2ef6125fcd3f33531ef4c0bc9f14db1d6432d9517267bac956f7d268dd76f4e4 2026-10-01T20:36:46.055072504+02:00 unpacked_bytes=235756793
rust HEAD: 195457b (dirty: 0 files)
```

Reps: rust 2. Cells: median [min–max].

### Startup and memory

| Metric | Rust | Rust advantage over Rails |
|---|---|---|
| cold start: docker run → /up 200 (ms) | 177 [167–187] | – |
| idle memory.current (MiB) | 32.0 [15.0–49.0] | – |
| idle anon (MiB) | 13.0 [13.0–13.0] | – |
| peak memory.current under load (MiB) | 388 [371–406] | – |
| peak anon under load (MiB) | 268 [268–269] | – |

### HTTP (signed in as david; keep-alive; c = concurrent connections)

| Metric | Rust | Rust advantage over Rails |
|---|---|---|
| room_show c=1 req/s | 8,711 [8,706–8,717] | – |
| room_show c=1 p50 ms | 0.11 [0.11–0.11] | – |
| room_show c=1 p99 ms | 0.20 [0.19–0.21] | – |
| room_show c=1 CPU µs/success | 108 [108–108] | – |
| room_show c=16 req/s | 36,260 [36,233–36,287] | – |
| room_show c=16 p50 ms | 0.43 [0.43–0.43] | – |
| room_show c=16 p99 ms | 0.80 [0.80–0.80] | – |
| room_show c=16 CPU µs/success | 103 [103–103] | – |
| room_show c=64 req/s | 36,984 [36,948–37,020] | – |
| room_show c=64 p50 ms | 1.68 [1.68–1.69] | – |
| room_show c=64 p99 ms | 3.09 [3.07–3.10] | – |
| room_show c=64 CPU µs/success | 101 [101–101] | – |
| messages_page c=1 req/s | 10,352 [10,229–10,475] | – |
| messages_page c=1 p50 ms | 0.09 [0.09–0.09] | – |
| messages_page c=1 p99 ms | 0.17 [0.17–0.17] | – |
| messages_page c=1 CPU µs/success | 91.2 [90.1–92.4] | – |
| messages_page c=16 req/s | 40,872 [40,824–40,919] | – |
| messages_page c=16 p50 ms | 0.38 [0.38–0.38] | – |
| messages_page c=16 p99 ms | 0.67 [0.67–0.67] | – |
| messages_page c=16 CPU µs/success | 91.0 [90.9–91.2] | – |
| messages_page c=64 req/s | 41,995 [41,496–42,494] | – |
| messages_page c=64 p50 ms | 1.49 [1.47–1.51] | – |
| messages_page c=64 p99 ms | 2.59 [2.56–2.61] | – |
| messages_page c=64 CPU µs/success | 88.5 [87.5–89.6] | – |
| sidebar c=1 req/s | 7,976 [7,974–7,977] | – |
| sidebar c=1 p50 ms | 0.12 [0.12–0.12] | – |
| sidebar c=1 p99 ms | 0.22 [0.21–0.22] | – |
| sidebar c=1 CPU µs/success | 118 [118–118] | – |
| sidebar c=16 req/s | 34,672 [34,590–34,756] | – |
| sidebar c=16 p50 ms | 0.44 [0.44–0.45] | – |
| sidebar c=16 p99 ms | 0.86 [0.85–0.86] | – |
| sidebar c=16 CPU µs/success | 109 [109–109] | – |
| sidebar c=64 req/s | 35,968 [35,655–36,282] | – |
| sidebar c=64 p50 ms | 1.73 [1.71–1.74] | – |
| sidebar c=64 p99 ms | 3.28 [3.26–3.30] | – |
| sidebar c=64 CPU µs/success | 105 [104–106] | – |
| search c=1 req/s | 9,721 [9,655–9,786] | – |
| search c=1 p50 ms | 0.10 [0.10–0.10] | – |
| search c=1 p99 ms | 0.16 [0.15–0.16] | – |
| search c=1 CPU µs/success | 95.9 [95.4–96.4] | – |
| search c=16 req/s | 33,299 [33,246–33,353] | – |
| search c=16 p50 ms | 0.44 [0.44–0.44] | – |
| search c=16 p99 ms | 1.02 [1.02–1.03] | – |
| search c=16 CPU µs/success | 98.8 [98.7–98.8] | – |
| search c=64 req/s | 38,533 [38,236–38,830] | – |
| search c=64 p50 ms | 1.56 [1.55–1.57] | – |
| search c=64 p99 ms | 3.20 [3.15–3.25] | – |
| search c=64 CPU µs/success | 88.0 [87.7–88.3] | – |
| avatar c=1 req/s | 61,356 [61,208–61,505] | – |
| avatar c=1 p50 ms | 0.01 [0.01–0.01] | – |
| avatar c=1 p99 ms | 0.02 [0.02–0.02] | – |
| avatar c=1 CPU µs/success | 9.22 [9.17–9.27] | – |
| avatar c=16 req/s | 364,915 [364,464–365,366] | – |
| avatar c=16 p50 ms | 0.04 [0.04–0.04] | – |
| avatar c=16 p99 ms | 0.11 [0.11–0.11] | – |
| avatar c=16 CPU µs/success | 8.03 [7.99–8.06] | – |
| avatar c=64 req/s | 408,993 [404,665–413,321] | – |
| avatar c=64 p50 ms | 0.15 [0.15–0.15] | – |
| avatar c=64 p99 ms | 0.33 [0.33–0.33] | – |
| avatar c=64 CPU µs/success | 7.49 [7.39–7.60] | – |
| static_css c=1 req/s | 65,144 [64,867–65,421] | – |
| static_css c=1 p50 ms | 0.01 [0.01–0.01] | – |
| static_css c=1 p99 ms | 0.02 [0.02–0.02] | – |
| static_css c=1 CPU µs/success | 8.95 [8.94–8.96] | – |
| static_css c=16 req/s | 383,609 [379,449–387,768] | – |
| static_css c=16 p50 ms | 0.04 [0.04–0.04] | – |
| static_css c=16 p99 ms | 0.11 [0.10–0.12] | – |
| static_css c=16 CPU µs/success | 7.64 [7.62–7.66] | – |
| static_css c=64 req/s | 425,869 [419,442–432,296] | – |
| static_css c=64 p50 ms | 0.14 [0.14–0.14] | – |
| static_css c=64 p99 ms | 0.33 [0.31–0.35] | – |
| static_css c=64 CPU µs/success | 7.09 [7.04–7.15] | – |
| up c=1 req/s | 40,443 [40,177–40,708] | – |
| up c=1 p50 ms | 0.02 [0.02–0.02] | – |
| up c=1 p99 ms | 0.04 [0.03–0.04] | – |
| up c=1 CPU µs/success | 15.5 [15.5–15.6] | – |
| up c=16 req/s | 230,480 [226,952–234,008] | – |
| up c=16 p50 ms | 0.07 [0.07–0.07] | – |
| up c=16 p99 ms | 0.12 [0.12–0.12] | – |
| up c=16 CPU µs/success | 14.8 [14.5–15.1] | – |
| up c=64 req/s | 231,156 [227,328–234,985] | – |
| up c=64 p50 ms | 0.27 [0.26–0.27] | – |
| up c=64 p99 ms | 0.56 [0.55–0.57] | – |
| up c=64 CPU µs/success | 14.8 [14.6–15.0] | – |
| post_message c=1 req/s | 2,816 [2,797–2,835] | – |
| post_message c=1 p50 ms | 0.32 [0.32–0.32] | – |
| post_message c=1 p99 ms | 1.64 [1.64–1.65] | – |
| post_message c=1 CPU µs/success | 373 [371–375] | – |
| post_message c=16 req/s | 6,896 [6,864–6,927] | – |
| post_message c=16 p50 ms | 2.04 [2.03–2.06] | – |
| post_message c=16 p99 ms | 5.89 [5.83–5.94] | – |
| post_message c=16 CPU µs/success | 385 [383–386] | – |
| post_message c=64 req/s | 6,801 [6,764–6,837] | – |
| post_message c=64 p50 ms | 9.08 [9.04–9.13] | – |
| post_message c=64 p99 ms | 14.5 [14.4–14.6] | – |
| post_message c=64 CPU µs/success | 392 [391–394] | – |

### HTTP errors / non-2xx-3xx (first rep, per app)

| Metric | Rust | Rust advantage over Rails |
|---|---|---|
- rust: none

### Action Cable fan-out (one room; chatter.js subscriptions per client)

| Metric | Rust | Rust advantage over Rails |
|---|---|---|
| 100 clients: subscribed | 100 [100–100] | – |
| 100 clients: connect+subscribe all (s) | 0.06 [0.06–0.06] | – |
| 100 clients: paced post→one client p50 ms | 1.73 [1.66–1.80] | – |
| 100 clients: paced post→all clients p50 ms | 1.99 [1.93–2.05] | – |
| 100 clients: paced post→all clients p99 ms | 3.96 [2.62–5.30] | – |
| 100 clients: max sustained msgs/s (delivered to all) | 3,861 [3,828–3,894] | – |
| 100 clients: deliveries/s (client×message) | 386,068 [382,771–389,365] | – |
| 100 clients: saturated post→all p50 ms | 1.17 [1.17–1.18] | – |
| 100 clients: saturated POST p50 ms | 0.89 [0.88–0.89] | – |
| 500 clients: subscribed | 500 [500–500] | – |
| 500 clients: connect+subscribe all (s) | 0.12 [0.12–0.13] | – |
| 500 clients: paced post→one client p50 ms | 2.69 [2.63–2.74] | – |
| 500 clients: paced post→all clients p50 ms | 3.84 [3.73–3.95] | – |
| 500 clients: paced post→all clients p99 ms | 5.30 [5.01–5.59] | – |
| 500 clients: max sustained msgs/s (delivered to all) | 1,086 [1,085–1,088] | – |
| 500 clients: deliveries/s (client×message) | 543,175 [542,363–543,987] | – |
| 500 clients: saturated post→all p50 ms | 8.07 [8.02–8.13] | – |
| 500 clients: saturated POST p50 ms | 3.40 [3.39–3.42] | – |
| 1000 clients: subscribed | 1,000 [1,000–1,000] | – |
| 1000 clients: connect+subscribe all (s) | 0.12 [0.11–0.13] | – |
| 1000 clients: paced post→one client p50 ms | 3.98 [3.95–4.01] | – |
| 1000 clients: paced post→all clients p50 ms | 6.24 [6.19–6.30] | – |
| 1000 clients: paced post→all clients p99 ms | 8.48 [8.37–8.59] | – |
| 1000 clients: max sustained msgs/s (delivered to all) | 546 [543–548] | – |
| 1000 clients: deliveries/s (client×message) | 545,654 [543,303–548,006] | – |
| 1000 clients: saturated post→all p50 ms | 16.0 [15.9–16.0] | – |
| 1000 clients: saturated POST p50 ms | 7.02 [6.95–7.09] | – |

### Upload + thumbnail (black_hole.jpg, 505 KB)

| Metric | Rust | Rust advantage over Rails |
|---|---|---|
| POST with attachment (ms) | 28.0 [27.5–28.5] | – |
| then GET thumb → 200 (ms) | 0.30 [0.30–0.30] | – |
| POST → thumbnail served (ms) | 28.3 [27.8–28.8] | – |

### Memory during cable fan-out, by process (MiB, peak within the phase)

App process: Elixir BEAM; Rails Puma master/workers when included;
Go/Rust's integrated campfire processes. Serving totals include native helpers, Redis and Thruster.
PSS apportions shared pages; RssAnon counts them in each process.

| Metric | Rust | Rust advantage over Rails |
|---|---|---|
| 100 clients, all subscribed, idle: app process Pss | 122 [122–122] | – |
| 100 clients, all subscribed, idle: app process RssAnon | 100 [100–101] | – |
| 100 clients, all subscribed, idle: serving processes Pss | 122 [122–122] | – |
| 100 clients, all subscribed, idle: whole container Pss | 122 [122–122] | – |
| 100 clients, saturated fan-out: app process Pss | 121 [120–122] | – |
| 100 clients, saturated fan-out: app process RssAnon | 99.2 [98.4–100.0] | – |
| 100 clients, saturated fan-out: serving processes Pss | 121 [120–122] | – |
| 100 clients, saturated fan-out: whole container Pss | 121 [120–122] | – |
| 500 clients, all subscribed, idle: app process Pss | 118 [117–118] | – |
| 500 clients, all subscribed, idle: app process RssAnon | 96.0 [95.5–96.5] | – |
| 500 clients, all subscribed, idle: serving processes Pss | 118 [117–118] | – |
| 500 clients, all subscribed, idle: whole container Pss | 118 [117–118] | – |
| 500 clients, saturated fan-out: app process Pss | 118 [118–118] | – |
| 500 clients, saturated fan-out: app process RssAnon | 96.2 [96.0–96.3] | – |
| 500 clients, saturated fan-out: serving processes Pss | 118 [118–118] | – |
| 500 clients, saturated fan-out: whole container Pss | 118 [118–118] | – |
| 1000 clients, all subscribed, idle: app process Pss | 126 [126–126] | – |
| 1000 clients, all subscribed, idle: app process RssAnon | 104 [104–105] | – |
| 1000 clients, all subscribed, idle: serving processes Pss | 126 [126–126] | – |
| 1000 clients, all subscribed, idle: whole container Pss | 126 [126–126] | – |
| 1000 clients, saturated fan-out: app process Pss | 125 [125–126] | – |
| 1000 clients, saturated fan-out: app process RssAnon | 104 [103–104] | – |
| 1000 clients, saturated fan-out: serving processes Pss | 125 [125–126] | – |
| 1000 clients, saturated fan-out: whole container Pss | 125 [125–126] | – |
