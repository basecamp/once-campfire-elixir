```
date: 2026-10-04T13:38:07+02:00
host: 7.2.5-4-omarchy, AMD RYZEN AI MAX+ 395 w/ Radeon 8060S, 32 threads, 30GB
server cpus: 8-11 (nproc 4); loadgen cpus: 12-15; network: host
env: WEB_CONCURRENCY=3 JOB_CONCURRENCY=3 RAILS_MAX_THREADS=5 
seed sha256: 433ccdce78759eef0524b2840a512077e52cc8e867f6c095430a8871d47a2e38  /home/dhh/Work/basecamp/once-campfire-rust/parity/.seed/default/db/production.sqlite3
elixir source digest: ad793a949fb8bc0f03f370a2b562b9226f3e86d9304fc4be6110ea72b0179056
rust extra env: 
workload: suites=http cable upload HTTP_SECS=4 HTTP_CONCS=1 16 64 CABLE_CLIENTS=100 500 1000 CABLE_TPUT_SECS=15 CABLE_POSTERS=4 UPLOAD_REPS=5 REPS=2
quiet wait: LOAD_MAX=1.5 LOAD_WAIT_SECS=30
user agent: (none)
elixir image: campfire-elixir:release sha256:6faa05c3c97f1ce8a93dd626a7f5e4f84b008ccd4714b53115e9399d7c41a984 2026-10-04T13:35:12.949290566+02:00 unpacked_bytes=2611451232
rust image: campfire-rust:app sha256:7042897243ae9e9f6fc47c3e18d0ae00165de1ad8a3488369bd79d01a8d46ac7 2026-09-28T11:10:14.617808723+02:00 unpacked_bytes=236729642
rust HEAD: 195457b (dirty: 0 files)
```

Reps: elixir 2, rust 2. Cells: median [min–max].

### Startup and memory

| Metric | Elixir | Rust | Rust adv. |
|---|---|---|---|
| cold start: docker run → /up 200 (ms) | 530 [523–536] | 150 [149–151] | 3.5× |
| idle memory.current (MB) | 152 [150–153] | 16.0 [13.0–19.0] | 9.5× |
| idle anon (MB) | 116 [115–118] | 14.5 [11.0–18.0] | 8.0× |
| peak memory.current under load (MB) | 631 [609–653] | 412 [403–420] | 1.5× |
| peak anon under load (MB) | 564 [545–583] | 307 [299–315] | 1.8× |

### HTTP (signed in as david; keep-alive; c = concurrent connections)

| Metric | Elixir | Rust | Rust adv. |
|---|---|---|---|
| room_show c=1 req/s | 292 [292–292] | 4,972 [4,937–5,007] | 17.0× |
| room_show c=1 p50 ms | 3.38 [3.37–3.39] | 0.19 [0.19–0.20] | 17.4× |
| room_show c=1 p99 ms | 3.99 [3.94–4.03] | 0.30 [0.30–0.30] | 13.4× |
| room_show c=1 CPU µs/success | 4,595 [4,329–4,861] | 195 [194–196] | 23.6× |
| room_show c=16 req/s | 722 [718–726] | 19,902 [19,833–19,971] | 27.6× |
| room_show c=16 p50 ms | 21.9 [21.7–22.0] | 0.78 [0.78–0.78] | 28.1× |
| room_show c=16 p99 ms | 31.2 [31.1–31.2] | 1.53 [1.53–1.53] | 20.4× |
| room_show c=16 CPU µs/success | 4,760 [4,730–4,790] | 192 [191–193] | 24.8× |
| room_show c=64 req/s | 751 [750–752] | 19,560 [19,276–19,845] | 26.0× |
| room_show c=64 p50 ms | 84.4 [84.0–84.7] | 3.24 [3.20–3.28] | 26.0× |
| room_show c=64 p99 ms | 108 [106–111] | 5.55 [5.49–5.61] | 19.5× |
| room_show c=64 CPU µs/success | 4,674 [4,671–4,676] | 195 [193–197] | 24.0× |
| messages_page c=1 req/s | 407 [404–410] | 5,788 [5,758–5,817] | 14.2× |
| messages_page c=1 p50 ms | 2.43 [2.42–2.45] | 0.17 [0.17–0.17] | 14.6× |
| messages_page c=1 p99 ms | 2.98 [2.87–3.09] | 0.26 [0.26–0.26] | 11.5× |
| messages_page c=1 CPU µs/success | 3,121 [3,016–3,226] | 170 [169–171] | 18.4× |
| messages_page c=16 req/s | 1,053 [1,043–1,063] | 22,662 [22,634–22,689] | 21.5× |
| messages_page c=16 p50 ms | 15.0 [14.9–15.2] | 0.67 [0.67–0.67] | 22.5× |
| messages_page c=16 p99 ms | 23.1 [22.8–23.5] | 1.48 [1.46–1.50] | 15.7× |
| messages_page c=16 CPU µs/success | 3,364 [3,348–3,380] | 165 [165–166] | 20.4× |
| messages_page c=64 req/s | 1,031 [1,028–1,035] | 22,998 [22,860–23,135] | 22.3× |
| messages_page c=64 p50 ms | 61.7 [61.5–62.0] | 2.74 [2.73–2.75] | 22.6× |
| messages_page c=64 p99 ms | 73.7 [73.2–74.2] | 4.55 [4.47–4.63] | 16.2× |
| messages_page c=64 CPU µs/success | 3,449 [3,436–3,462] | 165 [165–166] | 20.9× |
| sidebar c=1 req/s | 855 [846–864] | 3,127 [3,111–3,142] | 3.7× |
| sidebar c=1 p50 ms | 1.15 [1.14–1.16] | 0.31 [0.31–0.31] | 3.7× |
| sidebar c=1 p99 ms | 1.46 [1.41–1.51] | 0.49 [0.48–0.49] | 3.0× |
| sidebar c=1 CPU µs/success | 1,869 [1,851–1,887] | 310 [309–312] | 6.0× |
| sidebar c=16 req/s | 1,275 [1,270–1,280] | 12,258 [12,236–12,280] | 9.6× |
| sidebar c=16 p50 ms | 12.4 [12.3–12.5] | 1.27 [1.27–1.27] | 9.7× |
| sidebar c=16 p99 ms | 17.2 [17.0–17.4] | 2.41 [2.41–2.42] | 7.1× |
| sidebar c=16 CPU µs/success | 2,489 [2,486–2,492] | 310 [310–311] | 8.0× |
| sidebar c=64 req/s | 1,329 [1,319–1,338] | 12,339 [12,260–12,418] | 9.3× |
| sidebar c=64 p50 ms | 48.1 [47.7–48.4] | 5.15 [5.12–5.19] | 9.3× |
| sidebar c=64 p99 ms | 57.5 [57.4–57.5] | 8.74 [8.69–8.80] | 6.6× |
| sidebar c=64 CPU µs/success | 2,436 [2,426–2,447] | 312 [310–314] | 7.8× |
| search c=1 req/s | 608 [604–611] | 6,247 [6,222–6,272] | 10.3× |
| search c=1 p50 ms | 1.62 [1.62–1.62] | 0.15 [0.15–0.15] | 10.6× |
| search c=1 p99 ms | 2.02 [1.98–2.06] | 0.26 [0.26–0.26] | 7.8× |
| search c=1 CPU µs/success | 2,301 [2,297–2,306] | 159 [158–159] | 14.5× |
| search c=16 req/s | 1,156 [1,148–1,164] | 23,183 [23,094–23,272] | 20.1× |
| search c=16 p50 ms | 13.7 [13.6–13.8] | 0.65 [0.65–0.65] | 21.0× |
| search c=16 p99 ms | 18.8 [18.5–19.0] | 1.48 [1.48–1.49] | 12.7× |
| search c=16 CPU µs/success | 2,815 [2,804–2,826] | 160 [159–161] | 17.6× |
| search c=64 req/s | 1,162 [1,161–1,162] | 23,663 [23,588–23,737] | 20.4× |
| search c=64 p50 ms | 55.0 [54.9–55.1] | 2.66 [2.65–2.67] | 20.7× |
| search c=64 p99 ms | 64.8 [63.5–66.2] | 4.33 [4.32–4.33] | 15.0× |
| search c=64 CPU µs/success | 2,843 [2,840–2,846] | 161 [160–161] | 17.7× |
| avatar c=1 req/s | 28,715 [28,414–29,016] | 61,906 [61,489–62,323] | 2.2× |
| avatar c=1 p50 ms | 0.03 [0.03–0.03] | 0.01 [0.01–0.01] | 2.1× |
| avatar c=1 p99 ms | 0.09 [0.09–0.10] | 0.02 [0.02–0.02] | 4.3× |
| avatar c=1 CPU µs/success | 29.2 [28.6–29.7] | 9.16 [9.14–9.19] | 3.2× |
| avatar c=16 req/s | 96,970 [96,381–97,558] | 376,203 [363,829–388,577] | 3.9× |
| avatar c=16 p50 ms | 0.10 [0.10–0.10] | 0.04 [0.04–0.04] | 2.6× |
| avatar c=16 p99 ms | 0.91 [0.91–0.91] | 0.11 [0.11–0.12] | 7.9× |
| avatar c=16 CPU µs/success | 30.6 [30.4–30.8] | 7.79 [7.74–7.85] | 3.9× |
| avatar c=64 req/s | 78,929 [77,960–79,898] | 385,201 [384,491–385,911] | 4.9× |
| avatar c=64 p50 ms | 0.28 [0.28–0.29] | 0.15 [0.15–0.15] | 1.9× |
| avatar c=64 p99 ms | 4.92 [4.86–4.97] | 0.45 [0.43–0.47] | 11.0× |
| avatar c=64 CPU µs/success | 37.7 [37.2–38.3] | 7.63 [7.55–7.72] | 4.9× |
| static_css c=1 req/s | 33,864 [33,592–34,136] | 65,242 [65,157–65,328] | 1.9× |
| static_css c=1 p50 ms | 0.03 [0.03–0.03] | 0.01 [0.01–0.01] | 2.0× |
| static_css c=1 p99 ms | 0.07 [0.07–0.07] | 0.02 [0.02–0.02] | 3.4× |
| static_css c=1 CPU µs/success | 25.5 [25.2–25.8] | 8.96 [8.95–8.96] | 2.8× |
| static_css c=16 req/s | 125,904 [124,586–127,223] | 396,432 [395,189–397,674] | 3.1× |
| static_css c=16 p50 ms | 0.09 [0.09–0.09] | 0.04 [0.04–0.04] | 2.2× |
| static_css c=16 p99 ms | 0.71 [0.68–0.74] | 0.09 [0.08–0.10] | 8.3× |
| static_css c=16 CPU µs/success | 24.8 [24.7–24.9] | 7.65 [7.62–7.68] | 3.2× |
| static_css c=64 req/s | 105,374 [104,042–106,707] | 417,022 [413,557–420,486] | 4.0× |
| static_css c=64 p50 ms | 0.28 [0.28–0.29] | 0.15 [0.14–0.15] | 1.9× |
| static_css c=64 p99 ms | 3.53 [3.48–3.58] | 0.33 [0.32–0.35] | 10.6× |
| static_css c=64 CPU µs/success | 29.6 [29.5–29.7] | 7.27 [7.23–7.32] | 4.1× |
| up c=1 req/s | 4,128 [4,004–4,252] | 26,446 [26,369–26,522] | 6.4× |
| up c=1 p50 ms | 0.23 [0.23–0.24] | 0.04 [0.04–0.04] | 6.4× |
| up c=1 p99 ms | 0.37 [0.37–0.38] | 0.06 [0.05–0.06] | 6.8× |
| up c=1 CPU µs/success | 374 [366–382] | 28.2 [28.1–28.3] | 13.3× |
| up c=16 req/s | 8,493 [8,440–8,547] | 131,007 [130,978–131,036] | 15.4× |
| up c=16 p50 ms | 1.83 [1.81–1.84] | 0.12 [0.12–0.12] | 15.0× |
| up c=16 p99 ms | 4.30 [4.28–4.32] | 0.21 [0.21–0.21] | 20.2× |
| up c=16 CPU µs/success | 404 [401–406] | 27.8 [27.7–27.8] | 14.5× |
| up c=64 req/s | 8,931 [8,920–8,943] | 131,817 [131,234–132,400] | 14.8× |
| up c=64 p50 ms | 6.72 [6.71–6.74] | 0.47 [0.47–0.47] | 14.4× |
| up c=64 p99 ms | 16.6 [16.5–16.6] | 0.99 [0.99–0.99] | 16.7× |
| up c=64 CPU µs/success | 398 [397–399] | 27.5 [27.4–27.6] | 14.5× |
| post_message c=1 req/s | 413 [413–414] | 2,211 [2,207–2,216] | 5.3× |
| post_message c=1 p50 ms | 2.30 [2.29–2.30] | 0.42 [0.41–0.42] | 5.5× |
| post_message c=1 p99 ms | 7.76 [7.72–7.81] | 1.74 [1.72–1.76] | 4.5× |
| post_message c=1 CPU µs/success | 4,666 [4,626–4,705] | 498 [497–500] | 9.4× |
| post_message c=16 req/s | 801 [798–804] | 5,484 [5,423–5,545] | 6.8× |
| post_message c=16 p50 ms | 19.4 [19.3–19.6] | 2.69 [2.67–2.71] | 7.2× |
| post_message c=16 p99 ms | 26.9 [26.6–27.1] | 7.02 [7.00–7.05] | 3.8× |
| post_message c=16 CPU µs/success | 3,841 [3,821–3,861] | 542 [540–545] | 7.1× |
| post_message c=64 req/s | 861 [853–868] | 5,405 [5,374–5,436] | 6.3× |
| post_message c=64 p50 ms | 74.4 [73.7–75.1] | 11.6 [11.6–11.7] | 6.4× |
| post_message c=64 p99 ms | 83.1 [80.5–85.8] | 17.1 [16.7–17.5] | 4.9× |
| post_message c=64 CPU µs/success | 3,602 [3,571–3,633] | 556 [554–559] | 6.5× |

### HTTP errors / non-2xx-3xx (first rep, per app)

| Metric | Elixir | Rust | Rust adv. |
|---|---|---|---|
- elixir: none
- rust: none

### Action Cable fan-out (one room; chatter.js subscriptions per client)

| Metric | Elixir | Rust | Rust adv. |
|---|---|---|---|
| 100 clients: subscribed | 100 [100–100] | 100 [100–100] | 1.0× |
| 100 clients: connect+subscribe all (s) | 0.06 [0.06–0.06] | 0.06 [0.06–0.06] | 1.0× |
| 100 clients: paced post→one client p50 ms | 3.60 [3.58–3.62] | 1.99 [1.98–2.00] | 1.8× |
| 100 clients: paced post→all clients p50 ms | 4.03 [4.02–4.04] | 2.21 [2.20–2.22] | 1.8× |
| 100 clients: paced post→all clients p99 ms | 25.4 [10.3–40.6] | 3.05 [2.70–3.40] | 8.3× |
| 100 clients: max sustained msgs/s (delivered to all) | 413 [411–414] | 2,914 [2,904–2,923] | 7.1× |
| 100 clients: deliveries/s (client×message) | 41,278 [41,116–41,440] | 291,362 [290,422–292,303] | 7.1× |
| 100 clients: saturated post→all p50 ms | 8.00 [7.94–8.06] | 1.29 [1.28–1.29] | 6.2× |
| 100 clients: saturated POST p50 ms | 9.29 [9.24–9.34] | 1.25 [1.24–1.26] | 7.4× |
| 500 clients: subscribed | 500 [500–500] | 500 [500–500] | 1.0× |
| 500 clients: connect+subscribe all (s) | 0.20 [0.18–0.21] | 0.11 [0.10–0.11] | 1.9× |
| 500 clients: paced post→one client p50 ms | 7.98 [7.89–8.07] | 3.09 [3.08–3.09] | 2.6× |
| 500 clients: paced post→all clients p50 ms | 11.0 [10.8–11.1] | 4.27 [4.25–4.29] | 2.6× |
| 500 clients: paced post→all clients p99 ms | 14.7 [12.7–16.8] | 11.4 [7.9–14.9] | 1.3× |
| 500 clients: max sustained msgs/s (delivered to all) | 121 [121–122] | 979 [976–982] | 8.1× |
| 500 clients: deliveries/s (client×message) | 60,592 [60,333–60,850] | 489,732 [488,275–491,188] | 8.1× |
| 500 clients: saturated post→all p50 ms | 29.0 [28.6–29.4] | 7.02 [6.98–7.06] | 4.1× |
| 500 clients: saturated POST p50 ms | 32.8 [32.8–32.8] | 3.86 [3.85–3.87] | 8.5× |
| 1000 clients: subscribed | 1,000 [1,000–1,000] | 1,000 [1,000–1,000] | 1.0× |
| 1000 clients: connect+subscribe all (s) | 0.40 [0.38–0.42] | 0.62 [0.16–1.09] | 0.6× |
| 1000 clients: paced post→one client p50 ms | 10.6 [10.5–10.8] | 4.10 [4.08–4.11] | 2.6× |
| 1000 clients: paced post→all clients p50 ms | 18.3 [18.2–18.3] | 6.43 [6.41–6.46] | 2.8× |
| 1000 clients: paced post→all clients p99 ms | 21.7 [21.3–22.1] | 12.5 [7.8–17.2] | 1.7× |
| 1000 clients: max sustained msgs/s (delivered to all) | 60.2 [59.7–60.8] | 495 [493–497] | 8.2× |
| 1000 clients: deliveries/s (client×message) | 60,219 [59,666–60,772] | 494,858 [493,103–496,612] | 8.2× |
| 1000 clients: saturated post→all p50 ms | 58.7 [58.6–58.8] | 14.7 [14.7–14.8] | 4.0× |
| 1000 clients: saturated POST p50 ms | 66.6 [66.1–67.0] | 7.84 [7.79–7.89] | 8.5× |

### Upload + thumbnail (black_hole.jpg, 505 KB)

| Metric | Elixir | Rust | Rust adv. |
|---|---|---|---|
| POST with attachment (ms) | 92.2 [88.8–95.7] | 30.9 [29.7–32.1] | 3.0× |
| then GET thumb → 200 (ms) | 0.40 [0.40–0.40] | 0.30 [0.30–0.30] | 1.3× |
| POST → thumbnail served (ms) | 92.6 [89.1–96.1] | 31.1 [30.0–32.3] | 3.0× |

### Memory during cable fan-out, by process (MB, peak within the phase)

App process: Elixir BEAM; Rails Puma master/workers when included;
Rust's integrated campfire process. Serving totals include native helpers, Redis and Thruster.
PSS apportions shared pages; RssAnon counts them in each process.

| Metric | Elixir | Rust | Rust adv. |
|---|---|---|---|
| 100 clients, all subscribed, idle: app process Pss | 231 [228–234] | 146 [142–150] | 1.6× |
| 100 clients, all subscribed, idle: app process RssAnon | 187 [184–190] | 124 [119–128] | 1.5× |
| 100 clients, all subscribed, idle: app + Redis + Thruster Pss | 284 [281–288] | 146 [142–150] | 1.9× |
| 100 clients, all subscribed, idle: whole container Pss | 284 [280–288] | 146 [142–150] | 1.9× |
| 100 clients, saturated fan-out: app process Pss | 356 [355–356] | 156 [152–160] | 2.3× |
| 100 clients, saturated fan-out: app process RssAnon | 309 [309–310] | 132 [128–136] | 2.3× |
| 100 clients, saturated fan-out: app + Redis + Thruster Pss | 432 [432–432] | 156 [152–160] | 2.8× |
| 100 clients, saturated fan-out: whole container Pss | 432 [432–433] | 156 [152–160] | 2.8× |
| 500 clients, all subscribed, idle: app process Pss | 363 [360–365] | 159 [156–162] | 2.3× |
| 500 clients, all subscribed, idle: app process RssAnon | 316 [314–318] | 135 [132–138] | 2.3× |
| 500 clients, all subscribed, idle: app + Redis + Thruster Pss | 456 [455–458] | 159 [156–162] | 2.9× |
| 500 clients, all subscribed, idle: whole container Pss | 458 [456–459] | 159 [156–162] | 2.9× |
| 500 clients, saturated fan-out: app process Pss | 377 [371–383] | 158 [155–162] | 2.4× |
| 500 clients, saturated fan-out: app process RssAnon | 331 [325–336] | 134 [130–138] | 2.5× |
| 500 clients, saturated fan-out: app + Redis + Thruster Pss | 516 [508–524] | 158 [155–162] | 3.3× |
| 500 clients, saturated fan-out: whole container Pss | 517 [508–525] | 158 [155–162] | 3.3× |
| 1000 clients, all subscribed, idle: app process Pss | 394 [389–399] | 170 [162–177] | 2.3× |
| 1000 clients, all subscribed, idle: app process RssAnon | 347 [342–352] | 145 [137–153] | 2.4× |
| 1000 clients, all subscribed, idle: app + Redis + Thruster Pss | 546 [533–559] | 170 [162–177] | 3.2× |
| 1000 clients, all subscribed, idle: whole container Pss | 547 [534–561] | 170 [162–177] | 3.2× |
| 1000 clients, saturated fan-out: app process Pss | 423 [418–429] | 169 [161–177] | 2.5× |
| 1000 clients, saturated fan-out: app process RssAnon | 376 [370–382] | 145 [137–153] | 2.6× |
| 1000 clients, saturated fan-out: app + Redis + Thruster Pss | 600 [600–601] | 169 [161–177] | 3.5× |
| 1000 clients, saturated fan-out: whole container Pss | 600 [600–600] | 169 [161–177] | 3.5× |
