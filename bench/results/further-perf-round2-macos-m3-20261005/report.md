```
date: 2026-10-05T08:08:53+00:00
host: 7.0.12-linuxkit, , 8 threads, 7GB
server cpus: 0-3 (nproc 4); loadgen cpus: 4-7; network: host
env: WEB_CONCURRENCY=3 JOB_CONCURRENCY=3 RAILS_MAX_THREADS=5 
seed sha256: 58e6bb4498a188b33a52bbb79d82499d96a531f9afb9fc736a801532ddba1817  /Users/lau/oss/once-campfire-rust/parity/.seed/default/db/production.sqlite3
elixir source digest: a6d19867bfe1c5170d501725c82fe26ee82fdbd02432bedc89ce64f058fdd0ea
rust extra env: 
workload: suites=http cable HTTP_SECS=4 HTTP_CONCS=1 16 64 CABLE_CLIENTS=100 500 1000 CABLE_TPUT_SECS=15 CABLE_POSTERS=4 UPLOAD_REPS=5 REPS=3
request logging (LOG_REQUESTS): false
parity ledger gate: skipped; runner: bench/docker-desktop
quiet wait: LOAD_MAX=1.5 LOAD_WAIT_SECS=120
user agent: (none)
elixir image: campfire-elixir:further-perf-r2 sha256:9f25d3da2160a42b326141bb8ad730f5158ade580823868cad725babd936da4d 2026-10-05T08:08:41.624360552Z unpacked_bytes=1705209136
reference image: campfire-elixir:further-perf-otp29 sha256:29396bafc9e0453d884ba117485dc681ea9c978cbe9ee8081c30b121d3b50c01 2026-10-05T07:36:36.967708842Z unpacked_bytes=1705188693
rust HEAD: 64f8635 (dirty: 0 files)
```

Reps: reference 3, elixir 3. Cells: median [min–max].

### Startup and memory

| Metric | Rails | Elixir | Rust advantage over Elixir |
|---|---|---|---|
| cold start: docker run → /up 200 (ms) | 853 [837–1,071] | 847 [775–3,415] | – |
| idle memory.current (MiB) | 162 [159–170] | 170 [158–175] | – |
| idle anon (MiB) | 129 [126–133] | 138 [125–140] | – |
| peak memory.current under load (MiB) | 420 [400–432] | 409 [399–436] | – |
| peak anon under load (MiB) | 336 [312–356] | 329 [327–358] | – |

### HTTP (signed in as david; keep-alive; c = concurrent connections)

| Metric | Rails | Elixir | Rust advantage over Elixir |
|---|---|---|---|
| room_show c=1 req/s | 1,335 [1,205–1,364] | 1,708 [1,653–1,762] | – |
| room_show c=1 p50 ms | 0.67 [0.67–0.67] | 0.51 [0.50–0.53] | – |
| room_show c=1 p99 ms | 1.28 [1.28–1.29] | 0.86 [0.84–1.30] | – |
| room_show c=1 CPU µs/success | 1,193 [1,193–1,243] | 930 [912–962] | – |
| room_show c=16 req/s | 4,650 [4,497–4,687] | 6,781 [4,365–6,868] | – |
| room_show c=16 p50 ms | 3.17 [3.14–3.32] | 2.22 [2.20–3.28] | – |
| room_show c=16 p99 ms | 8.23 [8.03–8.43] | 6.98 [5.01–10.38] | – |
| room_show c=16 CPU µs/success | 811 [806–844] | 564 [560–853] | – |
| room_show c=64 req/s | 4,589 [4,459–4,632] | 6,360 [2,910–6,464] | – |
| room_show c=64 p50 ms | 13.6 [13.4–13.8] | 9.82 [9.69–19.36] | – |
| room_show c=64 p99 ms | 20.5 [20.2–20.8] | 14.9 [14.7–71.2] | – |
| room_show c=64 CPU µs/success | 830 [821–856] | 598 [592–1,228] | – |
| messages_page c=1 req/s | 972 [955–1,008] | 2,570 [1,752–2,686] | – |
| messages_page c=1 p50 ms | 1.00 [0.98–1.01] | 0.38 [0.36–0.47] | – |
| messages_page c=1 p99 ms | 1.34 [1.17–1.39] | 0.52 [0.50–2.07] | – |
| messages_page c=1 CPU µs/success | 1,311 [1,276–1,341] | 652 [635–861] | – |
| messages_page c=16 req/s | 3,423 [3,224–3,436] | 8,158 [6,456–8,184] | – |
| messages_page c=16 p50 ms | 4.51 [4.48–4.78] | 1.86 [1.86–2.18] | – |
| messages_page c=16 p99 ms | 9.02 [8.79–9.74] | 5.16 [4.72–7.09] | – |
| messages_page c=16 CPU µs/success | 1,063 [1,060–1,112] | 465 [465–576] | – |
| messages_page c=64 req/s | 3,360 [3,156–3,419] | 8,154 [7,260–8,208] | – |
| messages_page c=64 p50 ms | 18.8 [18.6–19.9] | 7.69 [7.63–8.46] | – |
| messages_page c=64 p99 ms | 26.0 [23.8–27.0] | 12.2 [11.7–15.2] | – |
| messages_page c=64 CPU µs/success | 1,082 [1,081–1,139] | 470 [466–524] | – |
| sidebar c=1 req/s | 1,242 [1,238–1,282] | 2,019 [1,809–2,146] | – |
| sidebar c=1 p50 ms | 0.77 [0.77–0.78] | 0.46 [0.46–0.48] | – |
| sidebar c=1 p99 ms | 1.19 [1.01–1.48] | 0.87 [0.62–0.94] | – |
| sidebar c=1 CPU µs/success | 1,514 [1,495–1,531] | 886 [867–906] | – |
| sidebar c=16 req/s | 4,006 [3,824–4,040] | 5,906 [5,387–6,002] | – |
| sidebar c=16 p50 ms | 3.67 [3.63–3.81] | 2.52 [2.50–2.75] | – |
| sidebar c=16 p99 ms | 9.41 [9.02–9.90] | 7.13 [6.74–7.28] | – |
| sidebar c=16 CPU µs/success | 946 [940–989] | 636 [628–693] | – |
| sidebar c=64 req/s | 4,055 [3,829–4,074] | 5,898 [5,348–5,921] | – |
| sidebar c=64 p50 ms | 15.4 [15.3–16.2] | 10.4 [10.4–11.6] | – |
| sidebar c=64 p99 ms | 21.3 [20.9–24.1] | 16.9 [16.7–17.5] | – |
| sidebar c=64 CPU µs/success | 954 [948–1,004] | 643 [638–703] | – |
| search c=1 req/s | 1,130 [1,100–1,315] | 2,457 [2,310–2,499] | – |
| search c=1 p50 ms | 0.78 [0.71–1.05] | 0.39 [0.39–0.40] | – |
| search c=1 p99 ms | 1.24 [1.20–1.25] | 0.75 [0.53–0.85] | – |
| search c=1 CPU µs/success | 1,250 [1,199–1,264] | 785 [773–801] | – |
| search c=16 req/s | 4,345 [4,218–4,392] | 6,494 [6,109–6,588] | – |
| search c=16 p50 ms | 3.35 [3.33–3.47] | 2.33 [2.27–2.46] | – |
| search c=16 p99 ms | 9.11 [8.95–9.29] | 5.92 [5.85–6.16] | – |
| search c=16 CPU µs/success | 852 [844–880] | 584 [576–619] | – |
| search c=64 req/s | 4,322 [4,053–4,345] | 6,175 [5,636–6,268] | – |
| search c=64 p50 ms | 14.4 [14.4–15.1] | 10.2 [10.0–11.0] | – |
| search c=64 p99 ms | 21.0 [20.5–23.9] | 14.7 [13.5–18.1] | – |
| search c=64 CPU µs/success | 866 [862–918] | 615 [608–669] | – |
| avatar c=1 req/s | 18,190 [18,020–18,373] | 17,782 [17,421–18,509] | – |
| avatar c=1 p50 ms | 0.05 [0.05–0.05] | 0.05 [0.05–0.06] | – |
| avatar c=1 p99 ms | 0.08 [0.08–0.08] | 0.08 [0.08–0.09] | – |
| avatar c=1 CPU µs/success | 57.4 [56.0–57.4] | 58.9 [55.0–59.5] | – |
| avatar c=16 req/s | 142,580 [138,530–144,372] | 146,228 [120,972–148,025] | – |
| avatar c=16 p50 ms | 0.10 [0.10–0.10] | 0.10 [0.10–0.11] | – |
| avatar c=16 p99 ms | 0.27 [0.27–0.30] | 0.26 [0.24–0.34] | – |
| avatar c=16 CPU µs/success | 24.8 [24.6–25.4] | 24.3 [24.3–26.8] | – |
| avatar c=64 req/s | 186,513 [173,170–187,602] | 184,232 [168,209–193,534] | – |
| avatar c=64 p50 ms | 0.31 [0.31–0.33] | 0.32 [0.30–0.33] | – |
| avatar c=64 p99 ms | 0.93 [0.92–1.07] | 0.94 [0.89–1.14] | – |
| avatar c=64 CPU µs/success | 21.3 [21.2–22.9] | 21.5 [20.6–23.2] | – |
| static_css c=1 req/s | 15,344 [14,378–19,166] | 19,929 [18,535–20,177] | – |
| static_css c=1 p50 ms | 0.07 [0.05–0.07] | 0.05 [0.05–0.05] | – |
| static_css c=1 p99 ms | 0.09 [0.08–0.09] | 0.07 [0.07–0.09] | – |
| static_css c=1 CPU µs/success | 49.8 [46.4–53.6] | 54.1 [53.4–56.0] | – |
| static_css c=16 req/s | 152,120 [147,589–156,041] | 156,221 [135,831–161,470] | – |
| static_css c=16 p50 ms | 0.09 [0.09–0.10] | 0.09 [0.09–0.10] | – |
| static_css c=16 p99 ms | 0.26 [0.25–0.28] | 0.24 [0.23–0.30] | – |
| static_css c=16 CPU µs/success | 23.6 [23.2–23.9] | 23.2 [23.1–24.6] | – |
| static_css c=64 req/s | 200,233 [194,166–201,288] | 198,443 [183,707–203,431] | – |
| static_css c=64 p50 ms | 0.29 [0.28–0.29] | 0.29 [0.29–0.30] | – |
| static_css c=64 p99 ms | 0.90 [0.89–0.99] | 0.89 [0.83–1.07] | – |
| static_css c=64 CPU µs/success | 19.9 [19.7–20.4] | 19.9 [19.6–21.5] | – |
| up c=1 req/s | 10,114 [9,749–10,224] | 10,342 [8,759–10,547] | – |
| up c=1 p50 ms | 0.10 [0.10–0.10] | 0.09 [0.09–0.12] | – |
| up c=1 p99 ms | 0.13 [0.13–0.14] | 0.13 [0.13–0.14] | – |
| up c=1 CPU µs/success | 101 [101–101] | 98.7 [96.8–100.5] | – |
| up c=16 req/s | 60,258 [58,340–60,314] | 60,846 [55,907–62,071] | – |
| up c=16 p50 ms | 0.26 [0.26–0.26] | 0.26 [0.25–0.27] | – |
| up c=16 p99 ms | 0.51 [0.50–0.65] | 0.46 [0.46–0.68] | – |
| up c=16 CPU µs/success | 65.8 [65.5–67.2] | 65.3 [64.2–70.3] | – |
| up c=64 req/s | 61,816 [60,849–62,931] | 63,389 [59,603–64,354] | – |
| up c=64 p50 ms | 1.03 [1.02–1.06] | 1.01 [1.00–1.06] | – |
| up c=64 p99 ms | 1.83 [1.81–2.28] | 1.79 [1.43–2.24] | – |
| up c=64 CPU µs/success | 64.5 [63.4–65.6] | 62.9 [62.0–66.8] | – |
| post_message c=1 req/s | 855 [817–898] | 880 [785–928] | – |
| post_message c=1 p50 ms | 0.98 [0.96–1.01] | 0.96 [0.93–1.03] | – |
| post_message c=1 p99 ms | 6.56 [6.42–6.60] | 6.42 [6.13–7.21] | – |
| post_message c=1 CPU µs/success | 2,805 [2,728–2,885] | 2,779 [2,680–2,967] | – |
| post_message c=16 req/s | 2,167 [2,042–2,219] | 2,162 [1,955–2,185] | – |
| post_message c=16 p50 ms | 5.83 [5.75–6.23] | 6.03 [5.81–6.96] | – |
| post_message c=16 p99 ms | 16.0 [14.9–17.0] | 15.5 [14.5–17.0] | – |
| post_message c=16 CPU µs/success | 1,669 [1,633–1,769] | 1,680 [1,667–1,911] | – |
| post_message c=64 req/s | 2,220 [2,064–2,223] | 2,093 [2,044–2,193] | – |
| post_message c=64 p50 ms | 28.2 [28.0–29.8] | 29.4 [28.3–30.3] | – |
| post_message c=64 p99 ms | 38.8 [37.2–42.7] | 43.6 [38.7–50.3] | – |
| post_message c=64 CPU µs/success | 1,644 [1,641–1,771] | 1,725 [1,632–1,783] | – |

### HTTP errors / non-2xx-3xx (first rep, per app)

| Metric | Rails | Elixir | Rust advantage over Elixir |
|---|---|---|---|
- reference: none
- elixir: none

### Action Cable fan-out (one room; chatter.js subscriptions per client)

| Metric | Rails | Elixir | Rust advantage over Elixir |
|---|---|---|---|
| 100 clients: subscribed | 100 [100–100] | 100 [100–100] | – |
| 100 clients: connect+subscribe all (s) | 0.06 [0.06–0.07] | 0.06 [0.06–0.07] | – |
| 100 clients: paced post→one client p50 ms | 7.55 [7.29–9.41] | 8.30 [8.10–8.70] | – |
| 100 clients: paced post→all clients p50 ms | 7.91 [7.75–9.86] | 8.54 [8.35–9.11] | – |
| 100 clients: paced post→all clients p99 ms | 18.6 [14.1–21.4] | 13.8 [13.8–18.0] | – |
| 100 clients: max sustained msgs/s (delivered to all) | 1,034 [1,000–1,074] | 1,094 [1,003–1,101] | – |
| 100 clients: deliveries/s (client×message) | 103,425 [100,016–107,452] | 109,435 [100,330–110,130] | – |
| 100 clients: saturated post→all p50 ms | 3.20 [3.05–3.28] | 2.97 [2.96–3.26] | – |
| 100 clients: saturated POST p50 ms | 3.17 [3.05–3.27] | 2.95 [2.95–3.26] | – |
| 500 clients: subscribed | 500 [500–500] | 500 [500–500] | – |
| 500 clients: connect+subscribe all (s) | 0.14 [0.13–0.14] | 0.16 [0.14–0.19] | – |
| 500 clients: paced post→one client p50 ms | 12.6 [12.1–14.1] | 13.7 [13.7–14.1] | – |
| 500 clients: paced post→all clients p50 ms | 14.3 [13.4–16.4] | 16.0 [15.6–16.2] | – |
| 500 clients: paced post→all clients p99 ms | 20.2 [18.8–20.5] | 21.2 [20.3–22.7] | – |
| 500 clients: max sustained msgs/s (delivered to all) | 399 [355–402] | 394 [332–399] | – |
| 500 clients: deliveries/s (client×message) | 199,617 [177,507–201,161] | 197,223 [166,031–199,499] | – |
| 500 clients: saturated post→all p50 ms | 10.1 [10.1–11.3] | 10.2 [10.2–11.6] | – |
| 500 clients: saturated POST p50 ms | 9.62 [9.54–10.78] | 9.70 [9.63–11.17] | – |
| 1000 clients: subscribed | 1,000 [1,000–1,000] | 1,000 [1,000–1,000] | – |
| 1000 clients: connect+subscribe all (s) | 0.27 [0.27–0.27] | 0.28 [0.27–0.35] | – |
| 1000 clients: paced post→one client p50 ms | 18.4 [16.9–18.7] | 17.3 [17.3–18.0] | – |
| 1000 clients: paced post→all clients p50 ms | 20.9 [19.3–21.3] | 20.6 [20.0–21.8] | – |
| 1000 clients: paced post→all clients p99 ms | 25.8 [25.2–28.6] | 27.0 [25.2–27.2] | – |
| 1000 clients: max sustained msgs/s (delivered to all) | 214 [196–222] | 218 [198–221] | – |
| 1000 clients: deliveries/s (client×message) | 214,466 [196,199–221,982] | 218,360 [198,030–221,159] | – |
| 1000 clients: saturated post→all p50 ms | 19.0 [18.4–20.4] | 18.7 [18.7–20.4] | – |
| 1000 clients: saturated POST p50 ms | 18.2 [17.6–19.8] | 18.0 [17.8–19.7] | – |

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
| 100 clients, all subscribed, idle: app process Pss | – | 280 [264–281] | – |
| 100 clients, all subscribed, idle: app process RssAnon | – | 240 [224–241] | – |
| 100 clients, all subscribed, idle: serving processes Pss | 0.00 [0.00–0.00] | 280 [264–281] | – |
| 100 clients, all subscribed, idle: whole container Pss | 268 [266–280] | 281 [265–282] | – |
| 100 clients, saturated fan-out: app process Pss | – | 287 [281–293] | – |
| 100 clients, saturated fan-out: app process RssAnon | – | 247 [241–253] | – |
| 100 clients, saturated fan-out: serving processes Pss | 0.00 [0.00–0.00] | 287 [281–293] | – |
| 100 clients, saturated fan-out: whole container Pss | 276 [274–289] | 288 [282–294] | – |
| 500 clients, all subscribed, idle: app process Pss | – | 285 [273–289] | – |
| 500 clients, all subscribed, idle: app process RssAnon | – | 244 [233–249] | – |
| 500 clients, all subscribed, idle: serving processes Pss | 0.00 [0.00–0.00] | 285 [273–289] | – |
| 500 clients, all subscribed, idle: whole container Pss | 270 [267–284] | 286 [274–290] | – |
| 500 clients, saturated fan-out: app process Pss | – | 329 [315–334] | – |
| 500 clients, saturated fan-out: app process RssAnon | – | 288 [275–294] | – |
| 500 clients, saturated fan-out: serving processes Pss | 0.00 [0.00–0.00] | 329 [315–334] | – |
| 500 clients, saturated fan-out: whole container Pss | 330 [324–337] | 330 [316–335] | – |
| 1000 clients, all subscribed, idle: app process Pss | – | 344 [302–360] | – |
| 1000 clients, all subscribed, idle: app process RssAnon | – | 304 [262–319] | – |
| 1000 clients, all subscribed, idle: serving processes Pss | 0.00 [0.00–0.00] | 344 [302–360] | – |
| 1000 clients, all subscribed, idle: whole container Pss | 313 [280–325] | 345 [303–361] | – |
| 1000 clients, saturated fan-out: app process Pss | – | 370 [366–399] | – |
| 1000 clients, saturated fan-out: app process RssAnon | – | 330 [326–358] | – |
| 1000 clients, saturated fan-out: serving processes Pss | 0.00 [0.00–0.00] | 370 [366–399] | – |
| 1000 clients, saturated fan-out: whole container Pss | 378 [353–398] | 371 [367–400] | – |
