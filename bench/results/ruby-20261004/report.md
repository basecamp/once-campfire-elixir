```
date: 2026-10-04T15:19:03+02:00
host: 7.2.5-4-omarchy, AMD RYZEN AI MAX+ 395 w/ Radeon 8060S, 32 threads, 30GB
server cpus: 8-11 (nproc 4); loadgen cpus: 12-15; network: host
env: WEB_CONCURRENCY=3 JOB_CONCURRENCY=3 RAILS_MAX_THREADS=5 
seed sha256: 433ccdce78759eef0524b2840a512077e52cc8e867f6c095430a8871d47a2e38  /home/dhh/Work/basecamp/once-campfire-rust/parity/.seed/default/db/production.sqlite3
elixir source digest: ad793a949fb8bc0f03f370a2b562b9226f3e86d9304fc4be6110ea72b0179056
rust extra env: 
workload: suites=http cable upload HTTP_SECS=4 HTTP_CONCS=1 16 64 CABLE_CLIENTS=100 500 1000 CABLE_TPUT_SECS=15 CABLE_POSTERS=4 UPLOAD_REPS=5 REPS=2
quiet wait: LOAD_MAX=1.5 LOAD_WAIT_SECS=30
user agent: (none)
reference image: campfire-reference:app sha256:d91fdb852402e2d3393ca262e50b657ea0cf861fc7d4150aaf3773c91d41c2fa 2026-09-27T22:01:29.746709947+02:00 unpacked_bytes=1291498414
rust HEAD: 195457b (dirty: 0 files)
```

Reps: reference 2. Cells: median [min–max].

### Startup and memory

| Metric | Rails | Rust advantage over Rails |
|---|---|---|
| cold start: docker run → /up 200 (ms) | 2,601 [2,575–2,627] | – |
| idle memory.current (MiB) | 298 [297–298] | – |
| idle anon (MiB) | 278 [278–278] | – |
| peak memory.current under load (MiB) | 1,458 [1,433–1,484] | – |
| peak anon under load (MiB) | 1,419 [1,393–1,445] | – |

### HTTP (signed in as david; keep-alive; c = concurrent connections)

| Metric | Rails | Rust advantage over Rails |
|---|---|---|
| room_show c=1 req/s | 90.0 [89.4–90.6] | – |
| room_show c=1 p50 ms | 10.6 [10.5–10.7] | – |
| room_show c=1 p99 ms | 14.0 [13.6–14.4] | – |
| room_show c=1 CPU µs/success | 11,190 [11,119–11,260] | – |
| room_show c=16 req/s | 216 [215–216] | – |
| room_show c=16 p50 ms | 69.2 [68.7–69.6] | – |
| room_show c=16 p99 ms | 173 [173–174] | – |
| room_show c=16 CPU µs/success | 14,292 [14,206–14,379] | – |
| room_show c=64 req/s | 190 [182–197] | – |
| room_show c=64 p50 ms | 367 [316–417] | – |
| room_show c=64 p99 ms | 474 [400–548] | – |
| room_show c=64 CPU µs/success | 15,972 [15,327–16,617] | – |
| messages_page c=1 req/s | 173 [172–174] | – |
| messages_page c=1 p50 ms | 5.61 [5.58–5.63] | – |
| messages_page c=1 p99 ms | 7.80 [7.77–7.83] | – |
| messages_page c=1 CPU µs/success | 5,854 [5,831–5,877] | – |
| messages_page c=16 req/s | 384 [378–389] | – |
| messages_page c=16 p50 ms | 38.9 [38.2–39.6] | – |
| messages_page c=16 p99 ms | 112 [105–119] | – |
| messages_page c=16 CPU µs/success | 7,936 [7,839–8,033] | – |
| messages_page c=64 req/s | 378 [377–379] | – |
| messages_page c=64 p50 ms | 173 [166–180] | – |
| messages_page c=64 p99 ms | 266 [252–280] | – |
| messages_page c=64 CPU µs/success | 7,952 [7,925–7,978] | – |
| sidebar c=1 req/s | 195 [177–213] | – |
| sidebar c=1 p50 ms | 4.51 [4.50–4.53] | – |
| sidebar c=1 p99 ms | 14.3 [6.9–21.7] | – |
| sidebar c=1 CPU µs/success | 5,217 [4,735–5,699] | – |
| sidebar c=16 req/s | 503 [489–518] | – |
| sidebar c=16 p50 ms | 30.0 [30.0–30.1] | – |
| sidebar c=16 p99 ms | 79.3 [58.7–99.8] | – |
| sidebar c=16 CPU µs/success | 5,794 [5,634–5,953] | – |
| sidebar c=64 req/s | 514 [502–527] | – |
| sidebar c=64 p50 ms | 130 [119–141] | – |
| sidebar c=64 p99 ms | 169 [153–186] | – |
| sidebar c=64 CPU µs/success | 5,639 [5,519–5,759] | – |
| search c=1 req/s | 172 [170–173] | – |
| search c=1 p50 ms | 5.64 [5.57–5.72] | – |
| search c=1 p99 ms | 8.00 [7.99–8.01] | – |
| search c=1 CPU µs/success | 5,838 [5,781–5,896] | – |
| search c=16 req/s | 380 [377–383] | – |
| search c=16 p50 ms | 40.9 [40.0–41.8] | – |
| search c=16 p99 ms | 77.0 [68.4–85.6] | – |
| search c=16 CPU µs/success | 7,616 [7,567–7,665] | – |
| search c=64 req/s | 379 [379–379] | – |
| search c=64 p50 ms | 169 [169–169] | – |
| search c=64 p99 ms | 192 [191–193] | – |
| search c=64 CPU µs/success | 7,657 [7,622–7,692] | – |
| avatar c=1 req/s | 27,763 [27,460–28,067] | – |
| avatar c=1 p50 ms | 0.03 [0.03–0.03] | – |
| avatar c=1 p99 ms | 0.10 [0.09–0.10] | – |
| avatar c=1 CPU µs/success | 30.3 [29.7–31.0] | – |
| avatar c=16 req/s | 94,703 [94,383–95,023] | – |
| avatar c=16 p50 ms | 0.10 [0.10–0.10] | – |
| avatar c=16 p99 ms | 0.92 [0.90–0.93] | – |
| avatar c=16 CPU µs/success | 31.5 [31.5–31.6] | – |
| avatar c=64 req/s | 76,098 [75,920–76,277] | – |
| avatar c=64 p50 ms | 0.31 [0.31–0.31] | – |
| avatar c=64 p99 ms | 5.05 [5.04–5.06] | – |
| avatar c=64 CPU µs/success | 39.5 [39.5–39.5] | – |
| static_css c=1 req/s | 33,772 [33,589–33,956] | – |
| static_css c=1 p50 ms | 0.03 [0.03–0.03] | – |
| static_css c=1 p99 ms | 0.07 [0.07–0.07] | – |
| static_css c=1 CPU µs/success | 25.7 [25.5–25.8] | – |
| static_css c=16 req/s | 129,639 [127,745–131,532] | – |
| static_css c=16 p50 ms | 0.08 [0.08–0.09] | – |
| static_css c=16 p99 ms | 0.66 [0.65–0.66] | – |
| static_css c=16 CPU µs/success | 24.4 [24.1–24.8] | – |
| static_css c=64 req/s | 106,504 [106,479–106,530] | – |
| static_css c=64 p50 ms | 0.28 [0.28–0.29] | – |
| static_css c=64 p99 ms | 3.52 [3.51–3.54] | – |
| static_css c=64 CPU µs/success | 29.2 [29.1–29.3] | – |
| up c=1 req/s | 1,787 [1,772–1,801] | – |
| up c=1 p50 ms | 0.53 [0.52–0.53] | – |
| up c=1 p99 ms | 1.09 [1.06–1.13] | – |
| up c=1 CPU µs/success | 596 [591–601] | – |
| up c=16 req/s | 4,054 [4,043–4,066] | – |
| up c=16 p50 ms | 3.81 [3.79–3.83] | – |
| up c=16 p99 ms | 7.92 [7.89–7.96] | – |
| up c=16 CPU µs/success | 718 [718–719] | – |
| up c=64 req/s | 4,003 [4,000–4,006] | – |
| up c=64 p50 ms | 15.7 [15.7–15.8] | – |
| up c=64 p99 ms | 25.9 [25.9–25.9] | – |
| up c=64 CPU µs/success | 732 [732–733] | – |
| post_message c=1 req/s | 140 [139–141] | – |
| post_message c=1 p50 ms | 6.67 [6.64–6.70] | – |
| post_message c=1 p99 ms | 13.3 [13.1–13.5] | – |
| post_message c=1 CPU µs/success | 9,532 [9,527–9,537] | – |
| post_message c=16 req/s | 267 [265–268] | – |
| post_message c=16 p50 ms | 57.3 [56.1–58.6] | – |
| post_message c=16 p99 ms | 158 [151–165] | – |
| post_message c=16 CPU µs/success | 12,340 [12,317–12,364] | – |
| post_message c=64 req/s | 264 [263–264] | – |
| post_message c=64 p50 ms | 233 [229–236] | – |
| post_message c=64 p99 ms | 368 [366–371] | – |
| post_message c=64 CPU µs/success | 12,542 [12,485–12,599] | – |

### HTTP errors / non-2xx-3xx (first rep, per app)

| Metric | Rails | Rust advantage over Rails |
|---|---|---|
- reference: none

### Action Cable fan-out (one room; chatter.js subscriptions per client)

| Metric | Rails | Rust advantage over Rails |
|---|---|---|
| 100 clients: subscribed | 100 [100–100] | – |
| 100 clients: connect+subscribe all (s) | 0.27 [0.27–0.27] | – |
| 100 clients: paced post→one client p50 ms | 14.5 [14.2–14.7] | – |
| 100 clients: paced post→all clients p50 ms | 20.1 [20.0–20.2] | – |
| 100 clients: paced post→all clients p99 ms | 56.2 [32.4–79.9] | – |
| 100 clients: max sustained msgs/s (delivered to all) | 76.6 [75.7–77.5] | – |
| 100 clients: deliveries/s (client×message) | 7,662 [7,573–7,752] | – |
| 100 clients: saturated post→all p50 ms | 50.2 [48.8–51.6] | – |
| 100 clients: saturated POST p50 ms | 42.4 [38.3–46.5] | – |
| 500 clients: subscribed | 500 [500–500] | – |
| 500 clients: connect+subscribe all (s) | 0.79 [0.77–0.80] | – |
| 500 clients: paced post→one client p50 ms | 28.0 [27.8–28.3] | – |
| 500 clients: paced post→all clients p50 ms | 57.0 [54.9–59.2] | – |
| 500 clients: paced post→all clients p99 ms | 109 [91–127] | – |
| 500 clients: max sustained msgs/s (delivered to all) | 20.9 [20.7–21.2] | – |
| 500 clients: deliveries/s (client×message) | 10,482 [10,360–10,604] | – |
| 500 clients: saturated post→all p50 ms | 966 [150–1,782] | – |
| 500 clients: saturated POST p50 ms | 144 [116–173] | – |
| 1000 clients: subscribed | 1,000 [1,000–1,000] | – |
| 1000 clients: connect+subscribe all (s) | 1.50 [1.49–1.50] | – |
| 1000 clients: paced post→one client p50 ms | 43.3 [40.2–46.4] | – |
| 1000 clients: paced post→all clients p50 ms | 135 [84–185] | – |
| 1000 clients: paced post→all clients p99 ms | 188 [173–204] | – |
| 1000 clients: max sustained msgs/s (delivered to all) | 12.4 [11.9–12.9] | – |
| 1000 clients: deliveries/s (client×message) | 12,412 [11,923–12,901] | – |
| 1000 clients: saturated post→all p50 ms | 879 [325–1,434] | – |
| 1000 clients: saturated POST p50 ms | 209 [196–223] | – |

### Upload + thumbnail (black_hole.jpg, 505 KB)

| Metric | Rails | Rust advantage over Rails |
|---|---|---|
| POST with attachment (ms) | 57.5 [55.5–59.4] | – |
| then GET thumb → 200 (ms) | 0.40 [0.40–0.40] | – |
| POST → thumbnail served (ms) | 57.8 [55.8–59.8] | – |

### Memory during cable fan-out, by process (MiB, peak within the phase)

App process: Elixir BEAM; Rails Puma master/workers when included;
Go/Rust's integrated campfire processes. Serving totals include native helpers, Redis and Thruster.
PSS apportions shared pages; RssAnon counts them in each process.

| Metric | Rails | Rust advantage over Rails |
|---|---|---|
| 100 clients, all subscribed, idle: app process Pss | 546 [544–547] | – |
| 100 clients, all subscribed, idle: app process RssAnon | 692 [692–693] | – |
| 100 clients, all subscribed, idle: serving processes Pss | 580 [578–581] | – |
| 100 clients, all subscribed, idle: whole container Pss | 851 [848–854] | – |
| 100 clients, saturated fan-out: app process Pss | 646 [644–647] | – |
| 100 clients, saturated fan-out: app process RssAnon | 792 [791–792] | – |
| 100 clients, saturated fan-out: serving processes Pss | 691 [690–693] | – |
| 100 clients, saturated fan-out: whole container Pss | 964 [961–967] | – |
| 500 clients, all subscribed, idle: app process Pss | 617 [617–617] | – |
| 500 clients, all subscribed, idle: app process RssAnon | 762 [760–764] | – |
| 500 clients, all subscribed, idle: serving processes Pss | 680 [680–680] | – |
| 500 clients, all subscribed, idle: whole container Pss | 953 [952–954] | – |
| 500 clients, saturated fan-out: app process Pss | 784 [761–807] | – |
| 500 clients, saturated fan-out: app process RssAnon | 928 [903–953] | – |
| 500 clients, saturated fan-out: serving processes Pss | 857 [833–881] | – |
| 500 clients, saturated fan-out: whole container Pss | 1,129 [1,106–1,152] | – |
| 1000 clients, all subscribed, idle: app process Pss | 678 [667–689] | – |
| 1000 clients, all subscribed, idle: app process RssAnon | 822 [808–835] | – |
| 1000 clients, all subscribed, idle: serving processes Pss | 792 [782–802] | – |
| 1000 clients, all subscribed, idle: whole container Pss | 1,065 [1,054–1,076] | – |
| 1000 clients, saturated fan-out: app process Pss | 991 [986–995] | – |
| 1000 clients, saturated fan-out: app process RssAnon | 1,135 [1,133–1,137] | – |
| 1000 clients, saturated fan-out: serving processes Pss | 1,112 [1,089–1,135] | – |
| 1000 clients, saturated fan-out: whole container Pss | 1,381 [1,357–1,406] | – |
