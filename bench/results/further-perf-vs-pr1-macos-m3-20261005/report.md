```
date: 2026-10-05T06:52:02+00:00
host: 7.0.12-linuxkit, , 8 threads, 7GB
server cpus: 0-3 (nproc 4); loadgen cpus: 4-7; network: host
env: WEB_CONCURRENCY=3 JOB_CONCURRENCY=3 RAILS_MAX_THREADS=5 
seed sha256: 58e6bb4498a188b33a52bbb79d82499d96a531f9afb9fc736a801532ddba1817  /Users/lau/oss/once-campfire-rust/parity/.seed/default/db/production.sqlite3
elixir source digest: 141846cc585feee0f58f7cd818f2d149bd88733e32a97cea0aecf7c2bbd0cbab
rust extra env: 
workload: suites=http cable HTTP_SECS=4 HTTP_CONCS=1 16 64 CABLE_CLIENTS=100 500 1000 CABLE_TPUT_SECS=15 CABLE_POSTERS=4 UPLOAD_REPS=5 REPS=3
request logging (LOG_REQUESTS): false
parity ledger gate: skipped; runner: bench/docker-desktop
quiet wait: LOAD_MAX=1.5 LOAD_WAIT_SECS=120
user agent: (none)
elixir image: campfire-elixir:further-perf sha256:abd593206313ece079b2c7eab5e08ac4ab2a15a07457a9bcd47c180fabb668ad 2026-10-05T06:40:56.318629754Z unpacked_bytes=1746080140
reference image: campfire-elixir:pr1-fix sha256:c7990410b3a75316f15728b53c3afa96a9a2736790af278f91ff4d1b8ca3cafe 2026-10-05T06:43:26.780188796Z unpacked_bytes=1756645283
rust HEAD: 64f8635 (dirty: 0 files)
```

Reps: reference 3, elixir 3. Cells: median [min–max].

### Startup and memory

| Metric | Rails | Elixir | Rust advantage over Elixir |
|---|---|---|---|
| cold start: docker run → /up 200 (ms) | 1,076 [1,010–1,327] | 1,188 [1,017–1,245] | – |
| idle memory.current (MiB) | 161 [158–175] | 166 [165–168] | – |
| idle anon (MiB) | 131 [128–145] | 133 [133–136] | – |
| peak memory.current under load (MiB) | 606 [593–642] | 419 [373–422] | – |
| peak anon under load (MiB) | 497 [454–506] | 339 [301–339] | – |

### HTTP (signed in as david; keep-alive; c = concurrent connections)

| Metric | Rails | Elixir | Rust advantage over Elixir |
|---|---|---|---|
| room_show c=1 req/s | 695 [668–696] | 1,435 [1,364–1,467] | – |
| room_show c=1 p50 ms | 1.35 [1.33–1.36] | 0.67 [0.67–0.67] | – |
| room_show c=1 p99 ms | 2.23 [2.19–2.65] | 1.04 [1.03–1.23] | – |
| room_show c=1 CPU µs/success | 2,143 [2,090–2,168] | 1,186 [1,171–1,202] | – |
| room_show c=16 req/s | 2,057 [2,001–2,143] | 4,765 [4,459–4,848] | – |
| room_show c=16 p50 ms | 7.63 [7.32–7.63] | 3.22 [3.17–3.42] | – |
| room_show c=16 p99 ms | 13.8 [12.6–16.9] | 5.70 [5.45–6.52] | – |
| room_show c=16 CPU µs/success | 1,777 [1,750–1,817] | 805 [791–858] | – |
| room_show c=64 req/s | 2,116 [2,094–2,199] | 4,583 [4,353–4,585] | – |
| room_show c=64 p50 ms | 28.8 [28.7–29.7] | 13.8 [13.6–14.4] | – |
| room_show c=64 p99 ms | 41.4 [37.6–48.3] | 19.3 [17.7–19.5] | – |
| room_show c=64 CPU µs/success | 1,749 [1,723–1,763] | 834 [833–877] | – |
| messages_page c=1 req/s | 437 [435–445] | 1,000 [955–1,002] | – |
| messages_page c=1 p50 ms | 2.20 [2.20–2.24] | 0.98 [0.98–1.00] | – |
| messages_page c=1 p99 ms | 2.91 [2.90–3.88] | 1.43 [1.27–1.46] | – |
| messages_page c=1 CPU µs/success | 2,714 [2,663–2,731] | 1,291 [1,284–1,323] | – |
| messages_page c=16 req/s | 1,398 [1,359–1,435] | 3,286 [3,078–3,311] | – |
| messages_page c=16 p50 ms | 10.9 [10.8–11.2] | 4.71 [4.67–5.04] | – |
| messages_page c=16 p99 ms | 21.7 [19.9–21.9] | 9.34 [9.29–10.10] | – |
| messages_page c=16 CPU µs/success | 2,603 [2,562–2,757] | 1,087 [1,073–1,149] | – |
| messages_page c=64 req/s | 1,448 [1,410–1,465] | 3,217 [3,106–3,248] | – |
| messages_page c=64 p50 ms | 43.7 [42.8–44.0] | 19.6 [19.5–20.2] | – |
| messages_page c=64 p99 ms | 55.9 [55.3–64.8] | 26.5 [25.5–28.3] | – |
| messages_page c=64 CPU µs/success | 2,617 [2,574–2,620] | 1,098 [1,097–1,146] | – |
| sidebar c=1 req/s | 764 [678–782] | 1,224 [963–1,282] | – |
| sidebar c=1 p50 ms | 1.23 [1.21–1.31] | 0.77 [0.77–0.82] | – |
| sidebar c=1 p99 ms | 2.16 [2.03–3.17] | 1.48 [0.97–1.65] | – |
| sidebar c=1 CPU µs/success | 2,155 [2,147–2,382] | 1,502 [1,482–1,658] | – |
| sidebar c=16 req/s | 2,463 [2,007–2,477] | 4,303 [4,046–4,447] | – |
| sidebar c=16 p50 ms | 6.32 [6.18–7.79] | 3.59 [3.47–3.82] | – |
| sidebar c=16 p99 ms | 12.3 [10.5–12.9] | 6.16 [5.50–6.19] | – |
| sidebar c=16 CPU µs/success | 1,527 [1,520–1,762] | 902 [875–955] | – |
| sidebar c=64 req/s | 2,415 [1,872–2,438] | 4,120 [3,845–4,169] | – |
| sidebar c=64 p50 ms | 25.6 [25.0–32.8] | 15.3 [15.1–16.2] | – |
| sidebar c=64 p99 ms | 40.2 [37.8–50.2] | 19.4 [19.1–23.1] | – |
| sidebar c=64 CPU µs/success | 1,566 [1,560–1,869] | 943 [934–1,002] | – |
| search c=1 req/s | 640 [581–663] | 1,263 [1,182–1,358] | – |
| search c=1 p50 ms | 1.50 [1.48–1.77] | 0.72 [0.72–0.73] | – |
| search c=1 p99 ms | 2.19 [1.98–2.70] | 1.17 [1.14–1.19] | – |
| search c=1 CPU µs/success | 2,202 [2,142–2,247] | 1,216 [1,193–1,252] | – |
| search c=16 req/s | 1,767 [1,535–1,978] | 4,474 [4,164–4,636] | – |
| search c=16 p50 ms | 8.39 [7.82–10.14] | 3.49 [3.30–3.62] | – |
| search c=16 p99 ms | 15.9 [15.4–19.7] | 6.12 [6.08–7.42] | – |
| search c=16 CPU µs/success | 2,075 [1,841–2,152] | 838 [815–898] | – |
| search c=64 req/s | 1,894 [1,487–2,015] | 4,371 [4,039–4,455] | – |
| search c=64 p50 ms | 32.7 [30.3–42.5] | 14.4 [14.1–15.6] | – |
| search c=64 p99 ms | 49.9 [48.1–55.2] | 19.5 [18.7–21.7] | – |
| search c=64 CPU µs/success | 1,949 [1,828–2,167] | 857 [843–926] | – |
| avatar c=1 req/s | 14,309 [14,096–14,375] | 16,836 [15,323–17,748] | – |
| avatar c=1 p50 ms | 0.07 [0.07–0.07] | 0.06 [0.05–0.06] | – |
| avatar c=1 p99 ms | 0.16 [0.15–0.16] | 0.09 [0.08–0.15] | – |
| avatar c=1 CPU µs/success | 54.9 [53.9–60.7] | 56.4 [56.1–59.8] | – |
| avatar c=16 req/s | 70,210 [70,046–71,893] | 148,660 [123,578–152,376] | – |
| avatar c=16 p50 ms | 0.15 [0.15–0.15] | 0.10 [0.09–0.11] | – |
| avatar c=16 p99 ms | 1.04 [1.01–1.05] | 0.25 [0.25–0.36] | – |
| avatar c=16 CPU µs/success | 38.5 [38.4–39.1] | 24.3 [23.9–27.7] | – |
| avatar c=64 req/s | 55,630 [55,360–57,997] | 188,674 [163,417–191,982] | – |
| avatar c=64 p50 ms | 0.38 [0.34–0.38] | 0.31 [0.30–0.34] | – |
| avatar c=64 p99 ms | 6.15 [5.88–6.19] | 0.94 [0.94–1.18] | – |
| avatar c=64 CPU µs/success | 48.9 [45.9–49.0] | 21.0 [20.7–24.0] | – |
| static_css c=1 req/s | 16,407 [15,896–16,618] | 19,116 [18,926–19,135] | – |
| static_css c=1 p50 ms | 0.06 [0.06–0.06] | 0.05 [0.05–0.05] | – |
| static_css c=1 p99 ms | 0.12 [0.10–0.20] | 0.08 [0.08–0.08] | – |
| static_css c=1 CPU µs/success | 46.7 [46.6–52.4] | 55.6 [55.2–56.3] | – |
| static_css c=16 req/s | 94,626 [90,017–96,021] | 151,240 [142,476–156,334] | – |
| static_css c=16 p50 ms | 0.12 [0.11–0.12] | 0.09 [0.09–0.10] | – |
| static_css c=16 p99 ms | 0.88 [0.83–0.93] | 0.27 [0.25–0.33] | – |
| static_css c=16 CPU µs/success | 30.6 [29.9–32.3] | 23.6 [23.3–24.4] | – |
| static_css c=64 req/s | 81,516 [78,766–83,951] | 193,615 [184,399–207,209] | – |
| static_css c=64 p50 ms | 0.29 [0.28–0.33] | 0.29 [0.28–0.30] | – |
| static_css c=64 p99 ms | 4.39 [4.17–4.46] | 0.97 [0.86–1.08] | – |
| static_css c=64 CPU µs/success | 35.4 [34.3–37.6] | 20.4 [19.2–21.4] | – |
| up c=1 req/s | 4,371 [4,320–4,636] | 10,134 [10,071–10,618] | – |
| up c=1 p50 ms | 0.22 [0.21–0.22] | 0.10 [0.09–0.10] | – |
| up c=1 p99 ms | 0.40 [0.35–0.40] | 0.14 [0.13–0.18] | – |
| up c=1 CPU µs/success | 266 [263–271] | 102 [98–102] | – |
| up c=16 req/s | 12,154 [11,794–12,403] | 59,839 [56,162–60,983] | – |
| up c=16 p50 ms | 1.15 [1.14–1.21] | 0.26 [0.26–0.26] | – |
| up c=16 p99 ms | 4.15 [3.83–4.32] | 0.55 [0.47–0.71] | – |
| up c=16 CPU µs/success | 275 [254–282] | 66.1 [65.3–69.5] | – |
| up c=64 req/s | 10,975 [10,615–11,083] | 61,212 [56,854–63,663] | – |
| up c=64 p50 ms | 5.21 [5.10–5.64] | 1.05 [1.00–1.05] | – |
| up c=64 p99 ms | 17.6 [14.8–18.0] | 1.87 [1.62–2.77] | – |
| up c=64 CPU µs/success | 323 [323–331] | 65.0 [62.6–70.0] | – |
| post_message c=1 req/s | 612 [603–654] | 836 [814–860] | – |
| post_message c=1 p50 ms | 1.37 [1.35–1.40] | 0.98 [0.97–1.01] | – |
| post_message c=1 p99 ms | 7.70 [7.51–7.87] | 7.00 [6.89–7.62] | – |
| post_message c=1 CPU µs/success | 3,619 [3,530–3,630] | 2,818 [2,769–2,875] | – |
| post_message c=16 req/s | 1,596 [1,317–1,774] | 2,227 [2,065–2,254] | – |
| post_message c=16 p50 ms | 9.17 [7.58–11.79] | 5.86 [5.68–6.29] | – |
| post_message c=16 p99 ms | 19.2 [18.8–21.7] | 14.1 [13.6–15.1] | – |
| post_message c=16 CPU µs/success | 2,354 [2,181–2,742] | 1,658 [1,630–1,762] | – |
| post_message c=64 req/s | 1,769 [1,122–1,794] | 2,158 [2,039–2,234] | – |
| post_message c=64 p50 ms | 35.1 [33.1–54.4] | 29.2 [28.3–30.2] | – |
| post_message c=64 p99 ms | 54.9 [51.7–145.9] | 38.2 [36.2–47.9] | – |
| post_message c=64 CPU µs/success | 2,208 [2,176–3,186] | 1,718 [1,638–1,782] | – |

### HTTP errors / non-2xx-3xx (first rep, per app)

| Metric | Rails | Elixir | Rust advantage over Elixir |
|---|---|---|---|
- reference: none
- elixir: none

### Action Cable fan-out (one room; chatter.js subscriptions per client)

| Metric | Rails | Elixir | Rust advantage over Elixir |
|---|---|---|---|
| 100 clients: subscribed | 100 [100–100] | 100 [100–100] | – |
| 100 clients: connect+subscribe all (s) | 0.07 [0.06–0.07] | 0.06 [0.06–0.07] | – |
| 100 clients: paced post→one client p50 ms | 9.97 [9.20–10.15] | 8.91 [7.41–8.99] | – |
| 100 clients: paced post→all clients p50 ms | 10.6 [10.0–10.7] | 9.21 [7.81–9.39] | – |
| 100 clients: paced post→all clients p99 ms | 18.0 [15.4–24.0] | 16.5 [13.2–19.5] | – |
| 100 clients: max sustained msgs/s (delivered to all) | 756 [686–761] | 1,161 [1,082–1,187] | – |
| 100 clients: deliveries/s (client×message) | 75,618 [68,625–76,101] | 116,096 [108,211–118,719] | – |
| 100 clients: saturated post→all p50 ms | 4.82 [4.57–5.47] | 3.02 [2.94–3.21] | – |
| 100 clients: saturated POST p50 ms | 4.76 [4.51–5.44] | 3.00 [2.93–3.21] | – |
| 500 clients: subscribed | 500 [500–500] | 500 [500–500] | – |
| 500 clients: connect+subscribe all (s) | 0.25 [0.21–0.26] | 0.19 [0.14–0.20] | – |
| 500 clients: paced post→one client p50 ms | 18.0 [16.5–18.0] | 14.4 [14.4–15.4] | – |
| 500 clients: paced post→all clients p50 ms | 20.1 [17.7–20.2] | 16.1 [15.8–17.1] | – |
| 500 clients: paced post→all clients p99 ms | 31.9 [28.1–32.6] | 22.2 [19.7–28.2] | – |
| 500 clients: max sustained msgs/s (delivered to all) | 238 [236–251] | 400 [292–403] | – |
| 500 clients: deliveries/s (client×message) | 118,781 [118,070–125,629] | 199,832 [145,802–201,364] | – |
| 500 clients: saturated post→all p50 ms | 18.0 [16.9–18.1] | 10.1 [10.1–12.2] | – |
| 500 clients: saturated POST p50 ms | 16.4 [15.4–16.7] | 9.64 [9.57–11.94] | – |
| 1000 clients: subscribed | 1,000 [1,000–1,000] | 1,000 [1,000–1,000] | – |
| 1000 clients: connect+subscribe all (s) | 0.40 [0.30–0.42] | 0.27 [0.26–0.33] | – |
| 1000 clients: paced post→one client p50 ms | 21.6 [21.0–22.2] | 18.0 [17.6–18.2] | – |
| 1000 clients: paced post→all clients p50 ms | 26.5 [26.3–26.6] | 21.4 [20.5–21.9] | – |
| 1000 clients: paced post→all clients p99 ms | 35.3 [34.4–38.0] | 27.3 [26.0–27.5] | – |
| 1000 clients: max sustained msgs/s (delivered to all) | 128 [108–139] | 206 [198–217] | – |
| 1000 clients: deliveries/s (client×message) | 127,795 [108,138–138,743] | 206,079 [198,175–216,741] | – |
| 1000 clients: saturated post→all p50 ms | 32.4 [30.0–33.1] | 19.2 [18.7–20.1] | – |
| 1000 clients: saturated POST p50 ms | 30.9 [28.2–31.4] | 18.2 [18.0–19.6] | – |

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
| 100 clients, all subscribed, idle: app process Pss | – | 272 [269–277] | – |
| 100 clients, all subscribed, idle: app process RssAnon | – | 232 [229–237] | – |
| 100 clients, all subscribed, idle: serving processes Pss | 21.6 [21.3–22.5] | 272 [269–277] | – |
| 100 clients, all subscribed, idle: whole container Pss | 288 [285–299] | 273 [270–278] | – |
| 100 clients, saturated fan-out: app process Pss | – | 287 [284–288] | – |
| 100 clients, saturated fan-out: app process RssAnon | – | 248 [244–248] | – |
| 100 clients, saturated fan-out: serving processes Pss | 33.0 [31.2–33.3] | 287 [284–288] | – |
| 100 clients, saturated fan-out: whole container Pss | 309 [308–322] | 288 [285–289] | – |
| 500 clients, all subscribed, idle: app process Pss | – | 278 [270–292] | – |
| 500 clients, all subscribed, idle: app process RssAnon | – | 238 [230–252] | – |
| 500 clients, all subscribed, idle: serving processes Pss | 71.4 [70.2–71.9] | 278 [270–292] | – |
| 500 clients, all subscribed, idle: whole container Pss | 352 [327–359] | 279 [271–293] | – |
| 500 clients, saturated fan-out: app process Pss | – | 337 [336–341] | – |
| 500 clients, saturated fan-out: app process RssAnon | – | 297 [296–302] | – |
| 500 clients, saturated fan-out: serving processes Pss | 109 [106–111] | 337 [336–341] | – |
| 500 clients, saturated fan-out: whole container Pss | 420 [419–422] | 338 [337–342] | – |
| 1000 clients, all subscribed, idle: app process Pss | – | 331 [301–361] | – |
| 1000 clients, all subscribed, idle: app process RssAnon | – | 291 [261–321] | – |
| 1000 clients, all subscribed, idle: serving processes Pss | 113 [111–134] | 331 [301–361] | – |
| 1000 clients, all subscribed, idle: whole container Pss | 461 [449–468] | 332 [302–362] | – |
| 1000 clients, saturated fan-out: app process Pss | – | 379 [339–379] | – |
| 1000 clients, saturated fan-out: app process RssAnon | – | 339 [299–340] | – |
| 1000 clients, saturated fan-out: serving processes Pss | 172 [158–184] | 379 [339–379] | – |
| 1000 clients, saturated fan-out: whole container Pss | 541 [500–550] | 380 [340–380] | – |
