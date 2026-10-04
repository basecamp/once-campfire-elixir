```
date: 2026-10-04T12:32:45+02:00
host: 7.2.5-4-omarchy, AMD RYZEN AI MAX+ 395 w/ Radeon 8060S, 32 threads, 30GB
server cpus: 8-11 (nproc 4); loadgen cpus: 12-15; network: host
env: WEB_CONCURRENCY=3 JOB_CONCURRENCY=3 RAILS_MAX_THREADS=5 
seed sha256: 433ccdce78759eef0524b2840a512077e52cc8e867f6c095430a8871d47a2e38  /home/dhh/Work/basecamp/once-campfire-rust/parity/.seed/default/db/production.sqlite3
elixir source digest: 3e88133bfe5ed1268287fc5cc6bd402e922adcb827e33ff2666d3e6b834faff8
rust extra env: 
workload: suites=http cable upload HTTP_SECS=4 HTTP_CONCS=1 16 64 CABLE_CLIENTS=100 500 1000 CABLE_TPUT_SECS=15 CABLE_POSTERS=4 UPLOAD_REPS=5 REPS=2
quiet wait: LOAD_MAX=1.5 LOAD_WAIT_SECS=30
user agent: (none)
elixir image: campfire-elixir:release sha256:9a9a5d9e92c353f7f564b968da82cf8878b4e3c5f538483fad2f38dbcef4240a 2026-10-04T12:31:08.827238697+02:00 unpacked_bytes=2617457234
rust image: campfire-rust:app sha256:7042897243ae9e9f6fc47c3e18d0ae00165de1ad8a3488369bd79d01a8d46ac7 2026-09-28T11:10:14.617808723+02:00 unpacked_bytes=236729642
rust HEAD: 195457b (dirty: 0 files)
```

Reps: elixir 2, rust 2. Cells: median [min–max].

### Startup and memory

| Metric | Elixir | Rust | Rust adv. |
|---|---|---|---|
| cold start: docker run → /up 200 (ms) | 535 [531–539] | 204 [155–253] | 2.6× |
| idle memory.current (MB) | 156 [154–159] | 37.5 [13.0–62.0] | 4.2× |
| idle anon (MB) | 120 [118–123] | 11.0 [11.0–11.0] | 11.0× |
| peak memory.current under load (MB) | 1,041 [1,010–1,072] | 436 [398–475] | 2.4× |
| peak anon under load (MB) | 984 [952–1,015] | 304 [302–307] | 3.2× |

### HTTP (signed in as david; keep-alive; c = concurrent connections)

| Metric | Elixir | Rust | Rust adv. |
|---|---|---|---|
| room_show c=1 req/s | 216 [214–218] | 4,970 [4,944–4,996] | 23.0× |
| room_show c=1 p50 ms | 4.59 [4.56–4.63] | 0.20 [0.19–0.20] | 23.6× |
| room_show c=1 p99 ms | 5.36 [5.17–5.55] | 0.29 [0.28–0.30] | 18.2× |
| room_show c=1 CPU µs/success | 5,947 [5,596–6,299] | 195 [194–196] | 30.5× |
| room_show c=16 req/s | 579 [576–581] | 19,932 [19,792–20,072] | 34.4× |
| room_show c=16 p50 ms | 27.4 [27.3–27.5] | 0.78 [0.77–0.78] | 35.1× |
| room_show c=16 p99 ms | 38.3 [38.2–38.3] | 1.53 [1.52–1.55] | 25.0× |
| room_show c=16 CPU µs/success | 6,037 [6,028–6,045] | 192 [190–193] | 31.5× |
| room_show c=64 req/s | 593 [592–594] | 19,608 [19,560–19,656] | 33.1× |
| room_show c=64 p50 ms | 107 [107–107] | 3.24 [3.23–3.24] | 33.2× |
| room_show c=64 p99 ms | 138 [136–139] | 5.54 [5.50–5.58] | 24.9× |
| room_show c=64 CPU µs/success | 6,022 [6,006–6,038] | 194 [194–194] | 31.0× |
| messages_page c=1 req/s | 273 [272–273] | 5,748 [5,677–5,819] | 21.1× |
| messages_page c=1 p50 ms | 3.63 [3.62–3.64] | 0.17 [0.17–0.17] | 21.7× |
| messages_page c=1 p99 ms | 4.41 [4.26–4.56] | 0.26 [0.26–0.26] | 16.8× |
| messages_page c=1 CPU µs/success | 4,440 [4,243–4,637] | 171 [168–173] | 26.0× |
| messages_page c=16 req/s | 756 [753–758] | 22,916 [22,737–23,094] | 30.3× |
| messages_page c=16 p50 ms | 21.1 [21.0–21.1] | 0.66 [0.66–0.67] | 31.9× |
| messages_page c=16 p99 ms | 29.3 [29.1–29.5] | 1.47 [1.46–1.47] | 20.0× |
| messages_page c=16 CPU µs/success | 4,646 [4,635–4,656] | 163 [162–164] | 28.5× |
| messages_page c=64 req/s | 806 [801–810] | 23,171 [23,082–23,260] | 28.8× |
| messages_page c=64 p50 ms | 80.4 [79.7–81.2] | 2.72 [2.71–2.73] | 29.6× |
| messages_page c=64 p99 ms | 108 [107–108] | 4.48 [4.48–4.48] | 24.0× |
| messages_page c=64 CPU µs/success | 4,469 [4,447–4,491] | 165 [164–165] | 27.2× |
| sidebar c=1 req/s | 830 [824–837] | 3,107 [3,047–3,166] | 3.7× |
| sidebar c=1 p50 ms | 1.18 [1.17–1.19] | 0.31 [0.30–0.32] | 3.8× |
| sidebar c=1 p99 ms | 1.55 [1.53–1.57] | 0.48 [0.47–0.49] | 3.2× |
| sidebar c=1 CPU µs/success | 1,985 [1,892–2,078] | 312 [306–318] | 6.4× |
| sidebar c=16 req/s | 1,274 [1,269–1,279] | 12,187 [12,047–12,326] | 9.6× |
| sidebar c=16 p50 ms | 12.5 [12.4–12.5] | 1.28 [1.26–1.30] | 9.7× |
| sidebar c=16 p99 ms | 16.7 [16.6–16.8] | 2.43 [2.42–2.44] | 6.9× |
| sidebar c=16 CPU µs/success | 2,510 [2,503–2,517] | 313 [309–316] | 8.0× |
| sidebar c=64 req/s | 1,349 [1,300–1,397] | 12,341 [12,325–12,357] | 9.1× |
| sidebar c=64 p50 ms | 47.2 [45.4–49.0] | 5.15 [5.13–5.16] | 9.2× |
| sidebar c=64 p99 ms | 56.8 [54.8–58.8] | 8.83 [8.80–8.86] | 6.4× |
| sidebar c=64 CPU µs/success | 2,430 [2,369–2,491] | 312 [311–313] | 7.8× |
| search c=1 req/s | 465 [456–474] | 6,351 [6,296–6,406] | 13.7× |
| search c=1 p50 ms | 2.12 [2.09–2.15] | 0.15 [0.15–0.15] | 13.9× |
| search c=1 p99 ms | 2.61 [2.59–2.64] | 0.24 [0.23–0.25] | 10.8× |
| search c=1 CPU µs/success | 2,909 [2,813–3,005] | 156 [155–157] | 18.6× |
| search c=16 req/s | 1,045 [1,036–1,054] | 23,196 [23,146–23,246] | 22.2× |
| search c=16 p50 ms | 15.1 [14.9–15.3] | 0.65 [0.64–0.65] | 23.3× |
| search c=16 p99 ms | 21.1 [21.1–21.2] | 1.50 [1.47–1.53] | 14.1× |
| search c=16 CPU µs/success | 3,266 [3,235–3,296] | 159 [158–160] | 20.5× |
| search c=64 req/s | 1,010 [1,003–1,018] | 23,647 [23,616–23,678] | 23.4× |
| search c=64 p50 ms | 62.8 [62.3–63.4] | 2.65 [2.64–2.65] | 23.7× |
| search c=64 p99 ms | 75.9 [73.7–78.0] | 4.50 [4.47–4.53] | 16.9× |
| search c=64 CPU µs/success | 3,357 [3,335–3,380] | 159 [159–160] | 21.1× |
| avatar c=1 req/s | 28,744 [28,460–29,029] | 61,907 [61,740–62,074] | 2.2× |
| avatar c=1 p50 ms | 0.03 [0.03–0.03] | 0.01 [0.01–0.01] | 2.1× |
| avatar c=1 p99 ms | 0.09 [0.09–0.10] | 0.02 [0.02–0.02] | 4.3× |
| avatar c=1 CPU µs/success | 29.2 [28.6–29.8] | 9.21 [9.18–9.24] | 3.2× |
| avatar c=16 req/s | 98,276 [96,837–99,715] | 380,507 [374,092–386,923] | 3.9× |
| avatar c=16 p50 ms | 0.10 [0.10–0.10] | 0.04 [0.04–0.04] | 2.6× |
| avatar c=16 p99 ms | 0.88 [0.87–0.90] | 0.11 [0.11–0.11] | 8.1× |
| avatar c=16 CPU µs/success | 30.3 [30.2–30.3] | 7.76 [7.67–7.85] | 3.9× |
| avatar c=64 req/s | 78,964 [77,928–79,999] | 387,867 [373,273–402,460] | 4.9× |
| avatar c=64 p50 ms | 0.29 [0.28–0.29] | 0.15 [0.15–0.15] | 1.9× |
| avatar c=64 p99 ms | 4.91 [4.86–4.96] | 0.45 [0.35–0.54] | 11.0× |
| avatar c=64 CPU µs/success | 37.4 [37.2–37.7] | 7.60 [7.50–7.71] | 4.9× |
| static_css c=1 req/s | 7,735 [7,428–8,043] | 65,175 [65,045–65,304] | 8.4× |
| static_css c=1 p50 ms | 0.11 [0.11–0.12] | 0.01 [0.01–0.01] | 8.2× |
| static_css c=1 p99 ms | 0.31 [0.31–0.32] | 0.02 [0.02–0.02] | 14.9× |
| static_css c=1 CPU µs/success | 328 [322–335] | 8.95 [8.93–8.97] | 36.7× |
| static_css c=16 req/s | 12,115 [12,081–12,148] | 389,614 [378,858–400,371] | 32.2× |
| static_css c=16 p50 ms | 1.20 [1.19–1.21] | 0.04 [0.04–0.04] | 31.0× |
| static_css c=16 p99 ms | 3.82 [3.75–3.88] | 0.10 [0.09–0.10] | 39.1× |
| static_css c=16 CPU µs/success | 298 [297–299] | 7.67 [7.56–7.77] | 38.9× |
| static_css c=64 req/s | 13,062 [12,940–13,184] | 403,420 [400,482–406,357] | 30.9× |
| static_css c=64 p50 ms | 4.51 [4.47–4.55] | 0.15 [0.15–0.15] | 30.6× |
| static_css c=64 p99 ms | 12.6 [12.6–12.7] | 0.39 [0.38–0.39] | 32.5× |
| static_css c=64 CPU µs/success | 271 [269–272] | 7.34 [7.32–7.37] | 36.8× |
| up c=1 req/s | 3,394 [3,330–3,458] | 26,366 [26,356–26,377] | 7.8× |
| up c=1 p50 ms | 0.29 [0.28–0.29] | 0.04 [0.04–0.04] | 8.0× |
| up c=1 p99 ms | 0.43 [0.42–0.43] | 0.06 [0.06–0.06] | 7.5× |
| up c=1 CPU µs/success | 347 [343–351] | 28.3 [28.3–28.4] | 12.3× |
| up c=16 req/s | 7,288 [7,234–7,342] | 128,770 [128,570–128,970] | 17.7× |
| up c=16 p50 ms | 2.13 [2.12–2.14] | 0.12 [0.12–0.12] | 17.2× |
| up c=16 p99 ms | 4.85 [4.78–4.93] | 0.22 [0.22–0.22] | 22.2× |
| up c=16 CPU µs/success | 478 [475–480] | 28.3 [28.2–28.3] | 16.9× |
| up c=64 req/s | 7,550 [7,528–7,572] | 129,991 [129,082–130,900] | 17.2× |
| up c=64 p50 ms | 7.96 [7.95–7.97] | 0.48 [0.47–0.48] | 16.7× |
| up c=64 p99 ms | 18.9 [18.8–19.1] | 1.00 [1.00–1.01] | 18.9× |
| up c=64 CPU µs/success | 481 [479–484] | 28.0 [27.8–28.2] | 17.2× |
| post_message c=1 req/s | 352 [350–353] | 2,235 [2,234–2,237] | 6.4× |
| post_message c=1 p50 ms | 2.79 [2.77–2.80] | 0.41 [0.41–0.41] | 6.7× |
| post_message c=1 p99 ms | 4.07 [3.92–4.21] | 1.71 [1.71–1.71] | 2.4× |
| post_message c=1 CPU µs/success | 3,659 [3,413–3,905] | 492 [492–492] | 7.4× |
| post_message c=16 req/s | 524 [519–529] | 5,485 [5,476–5,494] | 10.5× |
| post_message c=16 p50 ms | 30.3 [30.1–30.6] | 2.68 [2.67–2.68] | 11.3× |
| post_message c=16 p99 ms | 37.3 [36.7–37.9] | 7.20 [7.12–7.28] | 5.2× |
| post_message c=16 CPU µs/success | 4,175 [4,164–4,187] | 537 [533–542] | 7.8× |
| post_message c=64 req/s | 522 [514–529] | 5,461 [5,436–5,487] | 10.5× |
| post_message c=64 p50 ms | 123 [121–124] | 11.5 [11.5–11.6] | 10.6× |
| post_message c=64 p99 ms | 139 [132–146] | 16.8 [16.7–16.9] | 8.3× |
| post_message c=64 CPU µs/success | 3,975 [3,896–4,054] | 554 [551–557] | 7.2× |

### HTTP errors / non-2xx-3xx (first rep, per app)

| Metric | Elixir | Rust | Rust adv. |
|---|---|---|---|
- elixir: none
- rust: none

### Action Cable fan-out (one room; chatter.js subscriptions per client)

| Metric | Elixir | Rust | Rust adv. |
|---|---|---|---|
| 100 clients: subscribed | 100 [100–100] | 100 [100–100] | 1.0× |
| 100 clients: connect+subscribe all (s) | 0.11 [0.11–0.11] | 0.06 [0.06–0.06] | 1.8× |
| 100 clients: paced post→one client p50 ms | 11.6 [11.4–11.7] | 2.02 [2.01–2.04] | 5.7× |
| 100 clients: paced post→all clients p50 ms | 12.5 [12.4–12.6] | 2.24 [2.21–2.27] | 5.6× |
| 100 clients: paced post→all clients p99 ms | 14.1 [13.8–14.5] | 6.37 [6.00–6.73] | 2.2× |
| 100 clients: max sustained msgs/s (delivered to all) | 142 [141–142] | 2,920 [2,914–2,927] | 20.6× |
| 100 clients: deliveries/s (client×message) | 14,152 [14,139–14,166] | 292,025 [291,365–292,685] | 20.6× |
| 100 clients: saturated post→all p50 ms | 24.9 [24.9–25.0] | 1.29 [1.29–1.29] | 19.4× |
| 100 clients: saturated POST p50 ms | 28.0 [27.9–28.0] | 1.25 [1.24–1.25] | 22.4× |
| 500 clients: subscribed | 500 [500–500] | 500 [500–500] | 1.0× |
| 500 clients: connect+subscribe all (s) | 0.49 [0.48–0.50] | 0.11 [0.11–0.11] | 4.5× |
| 500 clients: paced post→one client p50 ms | 27.1 [26.2–28.0] | 3.08 [3.03–3.13] | 8.8× |
| 500 clients: paced post→all clients p50 ms | 33.1 [32.3–33.9] | 4.38 [4.35–4.42] | 7.6× |
| 500 clients: paced post→all clients p99 ms | 42.0 [41.8–42.2] | 7.81 [7.45–8.17] | 5.4× |
| 500 clients: max sustained msgs/s (delivered to all) | 35.0 [34.8–35.1] | 982 [973–990] | 28.1× |
| 500 clients: deliveries/s (client×message) | 17,477 [17,421–17,533] | 490,736 [486,581–494,891] | 28.1× |
| 500 clients: saturated post→all p50 ms | 105 [104–107] | 6.96 [6.78–7.14] | 15.2× |
| 500 clients: saturated POST p50 ms | 113 [113–114] | 3.84 [3.79–3.90] | 29.5× |
| 1000 clients: subscribed | 1,000 [1,000–1,000] | 1,000 [1,000–1,000] | 1.0× |
| 1000 clients: connect+subscribe all (s) | 1.04 [1.02–1.07] | 0.12 [0.12–0.13] | 8.4× |
| 1000 clients: paced post→one client p50 ms | 48.3 [48.1–48.4] | 4.14 [4.13–4.15] | 11.7× |
| 1000 clients: paced post→all clients p50 ms | 62.3 [61.8–62.7] | 6.59 [6.55–6.64] | 9.4× |
| 1000 clients: paced post→all clients p99 ms | 72.7 [70.6–74.8] | 8.89 [8.63–9.15] | 8.2× |
| 1000 clients: max sustained msgs/s (delivered to all) | 17.6 [17.6–17.6] | 496 [494–498] | 28.2× |
| 1000 clients: deliveries/s (client×message) | 17,628 [17,628–17,629] | 495,967 [493,660–498,274] | 28.1× |
| 1000 clients: saturated post→all p50 ms | 215 [215–216] | 14.8 [14.7–14.8] | 14.6× |
| 1000 clients: saturated POST p50 ms | 227 [226–227] | 7.78 [7.73–7.83] | 29.1× |

### Upload + thumbnail (black_hole.jpg, 505 KB)

| Metric | Elixir | Rust | Rust adv. |
|---|---|---|---|
| POST with attachment (ms) | 94.7 [93.5–95.8] | 29.6 [29.6–29.7] | 3.2× |
| then GET thumb → 200 (ms) | 0.40 [0.40–0.40] | 0.30 [0.30–0.30] | 1.3× |
| POST → thumbnail served (ms) | 95.1 [93.9–96.2] | 29.9 [29.9–30.0] | 3.2× |

### Memory during cable fan-out, by process (MB, peak within the phase)

App process: Rails' Puma master and workers (Action Cable runs in them), or Rust's one campfire
process (its front server included). Pss counts pages shared between forked workers once;
RssAnon counts them in every process.

| Metric | Elixir | Rust | Rust adv. |
|---|---|---|---|
| 100 clients, all subscribed, idle: app process Pss | 221 [214–227] | 139 [139–140] | 1.6× |
| 100 clients, all subscribed, idle: app process RssAnon | 179 [173–186] | 117 [116–118] | 1.5× |
| 100 clients, all subscribed, idle: app + Redis + Thruster Pss | 265 [259–272] | 139 [139–140] | 1.9× |
| 100 clients, all subscribed, idle: whole container Pss | 269 [262–277] | 139 [139–140] | 1.9× |
| 100 clients, saturated fan-out: app process Pss | 282 [278–287] | 148 [148–149] | 1.9× |
| 100 clients, saturated fan-out: app process RssAnon | 241 [236–246] | 125 [124–126] | 1.9× |
| 100 clients, saturated fan-out: app + Redis + Thruster Pss | 343 [338–348] | 148 [148–149] | 2.3× |
| 100 clients, saturated fan-out: whole container Pss | 343 [336–351] | 148 [148–149] | 2.3× |
| 500 clients, all subscribed, idle: app process Pss | 256 [255–258] | 152 [150–154] | 1.7× |
| 500 clients, all subscribed, idle: app process RssAnon | 215 [214–217] | 128 [126–130] | 1.7× |
| 500 clients, all subscribed, idle: app + Redis + Thruster Pss | 334 [333–335] | 152 [150–154] | 2.2× |
| 500 clients, all subscribed, idle: whole container Pss | 338 [338–339] | 152 [150–154] | 2.2× |
| 500 clients, saturated fan-out: app process Pss | 587 [570–604] | 152 [150–154] | 3.9× |
| 500 clients, saturated fan-out: app process RssAnon | 546 [529–563] | 128 [125–130] | 4.3× |
| 500 clients, saturated fan-out: app + Redis + Thruster Pss | 678 [661–696] | 152 [150–154] | 4.5× |
| 500 clients, saturated fan-out: whole container Pss | 676 [663–690] | 152 [150–154] | 4.4× |
| 1000 clients, all subscribed, idle: app process Pss | 390 [386–394] | 159 [158–159] | 2.5× |
| 1000 clients, all subscribed, idle: app process RssAnon | 349 [345–353] | 134 [133–135] | 2.6× |
| 1000 clients, all subscribed, idle: app + Redis + Thruster Pss | 518 [516–521] | 159 [158–159] | 3.3× |
| 1000 clients, all subscribed, idle: whole container Pss | 523 [520–526] | 159 [158–159] | 3.3× |
| 1000 clients, saturated fan-out: app process Pss | 905 [876–934] | 159 [158–159] | 5.7× |
| 1000 clients, saturated fan-out: app process RssAnon | 864 [835–892] | 134 [134–135] | 6.4× |
| 1000 clients, saturated fan-out: app + Redis + Thruster Pss | 1,041 [1,007–1,076] | 159 [158–159] | 6.6× |
| 1000 clients, saturated fan-out: whole container Pss | 1,043 [1,009–1,078] | 159 [158–159] | 6.6× |
