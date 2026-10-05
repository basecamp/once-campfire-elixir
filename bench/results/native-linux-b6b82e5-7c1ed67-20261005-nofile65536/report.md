```
date: 2026-10-05T07:48:07+00:00
host: 6.1.158+, Intel(R) Xeon(R) Processor @ 2.60GHz, 16 threads, 31GB
server cpus: 0,2,4,6 (nproc 4); loadgen cpus: 8,10,12,14; network: host
env: WEB_CONCURRENCY=3 JOB_CONCURRENCY=3 RAILS_MAX_THREADS=5
seed sha256: bda9a5cd61d78d53f377cf07ee9268741caebc19b94a6efe782cafe827efc8db  /home/user/workspace/repo/var/linux-benchmark-setup/seed/default/db/production.sqlite3
seed tree sha256: d0c0b2708846c2f261e7bf6c8a4d7b220b9df71ba21190a172ffcb5acf38b963  -
loadgen sha256: 6c55f4fd8c7accb05c7f7ad211fd1892fd4efcf4304f8560d5c65b58df3d9c0f  /home/user/workspace/repo/target/bench/release/loadgen
loadgen build image: rust@sha256:4cd829461bd5c4d511c32e269da9cb8929223b666519d8004e35fc8d1d771ab7
elixir source digest: 211c7482047fcd69224c168ee21d81f689bd991d7267acae74039122a85553a6
rust extra env:
workload: suites=http cable upload HTTP_SECS=4 HTTP_CONCS=1 16 64 CABLE_CLIENTS=100 500 1000 CABLE_TPUT_SECS=15 CABLE_POSTERS=4 UPLOAD_REPS=5 REPS=4
quiet wait: LOAD_MAX=1.5 LOAD_WAIT_SECS=900
user agent: (none)
baseline image: sha256:7cb5658090eee9c77c4d19572766434bb4a2b6654b80334bb8f43df02f922182 sha256:7cb5658090eee9c77c4d19572766434bb4a2b6654b80334bb8f43df02f922182 2026-10-05T06:37:12.019194803Z unpacked_bytes=2542179488
candidate image: sha256:3cab19b9a0cc8416e94c9e91585eb4036a190d68a013df98726cbfb34fc344bc sha256:3cab19b9a0cc8416e94c9e91585eb4036a190d68a013df98726cbfb34fc344bc 2026-10-05T07:06:02.690442539Z unpacked_bytes=2540411548
baseline source: b6b82e50a653c4060136bb04e805eb78fd76ba10
candidate source: 7c1ed67d062f5e241d37e3eb0e9a3d97a2324636
```

Reps: baseline 4, candidate 4. Cells: median [min–max].

### Startup and memory

| Metric | Elixir baseline | Elixir candidate | Candidate advantage over baseline |
|---|---|---|---|
| cold start: docker run → /up 200 (ms) | 1,234 [1,143–1,338] | 1,162 [1,067–1,258] | 1.1× |
| idle memory.current (MiB) | 148 [140–152] | 147 [145–149] | 1.0× |
| idle anon (MiB) | 113 [105–117] | 112 [110–114] | 1.0× |
| peak memory.current under load (MiB) | 539 [512–556] | 510 [507–541] | 1.1× |
| peak anon under load (MiB) | 486 [456–510] | 448 [423–486] | 1.1× |

### HTTP (signed in as david; keep-alive; c = concurrent connections)

| Metric | Elixir baseline | Elixir candidate | Candidate advantage over baseline |
|---|---|---|---|
| room_show c=1 req/s | 109 [101–122] | 102 [98–112] | 0.9× |
| room_show c=1 p50 ms | 8.87 [7.97–9.34] | 9.36 [8.71–9.75] | 0.9× |
| room_show c=1 p99 ms | 12.4 [11.4–16.0] | 14.5 [12.5–16.1] | 0.9× |
| room_show c=1 CPU µs/success | 12,020 [11,123–13,296] | 13,092 [12,034–13,628] | 0.9× |
| room_show c=16 req/s | 305 [294–322] | 256 [228–259] | 0.8× |
| room_show c=16 p50 ms | 51.7 [49.5–54.0] | 62.1 [61.4–69.1] | 0.8× |
| room_show c=16 p99 ms | 66.1 [61.7–75.8] | 78.3 [76.0–92.4] | 0.8× |
| room_show c=16 CPU µs/success | 11,752 [11,224–12,139] | 15,090 [14,959–16,847] | 0.8× |
| room_show c=64 req/s | 311 [297–318] | 225 [225–232] | 0.7× |
| room_show c=64 p50 ms | 200 [196–206] | 278 [271–281] | 0.7× |
| room_show c=64 p99 ms | 266 [251–338] | 370 [333–378] | 0.7× |
| room_show c=64 CPU µs/success | 11,551 [11,303–12,092] | 16,629 [16,377–16,756] | 0.7× |
| messages_page c=1 req/s | 145 [138–150] | 144 [123–153] | 1.0× |
| messages_page c=1 p50 ms | 6.63 [6.45–6.82] | 6.66 [6.33–7.65] | 1.0× |
| messages_page c=1 p99 ms | 10.2 [9.2–12.0] | 10.4 [9.8–13.6] | 1.0× |
| messages_page c=1 CPU µs/success | 8,728 [8,348–9,093] | 9,009 [8,446–10,739] | 1.0× |
| messages_page c=16 req/s | 430 [418–443] | 330 [321–336] | 0.8× |
| messages_page c=16 p50 ms | 36.9 [35.9–37.6] | 47.9 [47.4–48.9] | 0.8× |
| messages_page c=16 p99 ms | 51.5 [49.5–55.3] | 64.5 [60.7–71.0] | 0.8× |
| messages_page c=16 CPU µs/success | 8,586 [8,321–8,837] | 11,678 [11,489–11,978] | 0.7× |
| messages_page c=64 req/s | 422 [419–427] | 308 [300–312] | 0.7× |
| messages_page c=64 p50 ms | 151 [150–152] | 204 [203–208] | 0.7× |
| messages_page c=64 p99 ms | 178 [166–182] | 238 [233–270] | 0.7× |
| messages_page c=64 CPU µs/success | 8,748 [8,677–8,882] | 12,255 [12,209–12,659] | 0.7× |
| sidebar c=1 req/s | 252 [228–282] | 226 [188–231] | 0.9× |
| sidebar c=1 p50 ms | 3.67 [3.39–4.52] | 4.27 [4.25–4.88] | 0.9× |
| sidebar c=1 p99 ms | 6.19 [5.33–7.77] | 6.43 [5.93–9.17] | 1.0× |
| sidebar c=1 CPU µs/success | 6,378 [6,034–6,799] | 7,725 [7,563–8,850] | 0.8× |
| sidebar c=16 req/s | 462 [449–486] | 243 [236–265] | 0.5× |
| sidebar c=16 p50 ms | 34.2 [32.5–34.9] | 64.6 [59.6–66.2] | 0.5× |
| sidebar c=16 p99 ms | 48.8 [45.4–59.5] | 87.1 [78.1–103.1] | 0.6× |
| sidebar c=16 CPU µs/success | 7,081 [6,754–7,138] | 14,461 [13,511–15,043] | 0.5× |
| sidebar c=64 req/s | 514 [453–524] | 246 [227–248] | 0.5× |
| sidebar c=64 p50 ms | 123 [116–140] | 258 [247–290] | 0.5× |
| sidebar c=64 p99 ms | 166 [140–204] | 320 [291–338] | 0.5× |
| sidebar c=64 CPU µs/success | 6,422 [6,234–7,175] | 14,255 [14,133–15,282] | 0.5× |
| search c=1 req/s | 196 [190–207] | 185 [178–190] | 0.9× |
| search c=1 p50 ms | 4.94 [4.67–5.05] | 5.25 [5.13–5.41] | 0.9× |
| search c=1 p99 ms | 7.23 [6.86–7.73] | 7.58 [7.10–8.86] | 1.0× |
| search c=1 CPU µs/success | 7,283 [6,983–7,754] | 8,080 [7,982–8,408] | 0.9× |
| search c=16 req/s | 449 [430–474] | 319 [310–342] | 0.7× |
| search c=16 p50 ms | 35.0 [33.4–35.2] | 49.2 [46.4–50.6] | 0.7× |
| search c=16 p99 ms | 51.9 [43.6–58.7] | 69.6 [64.4–72.2] | 0.7× |
| search c=16 CPU µs/success | 7,567 [7,187–7,788] | 11,555 [10,822–11,780] | 0.7× |
| search c=64 req/s | 484 [472–492] | 291 [275–297] | 0.6× |
| search c=64 p50 ms | 130 [128–134] | 218 [212–228] | 0.6× |
| search c=64 p99 ms | 162 [146–199] | 245 [240–296] | 0.7× |
| search c=64 CPU µs/success | 7,061 [6,996–7,127] | 12,270 [12,085–12,988] | 0.6× |
| avatar c=1 req/s | 4,557 [4,111–4,683] | 4,574 [4,284–4,887] | 1.0× |
| avatar c=1 p50 ms | 0.20 [0.20–0.22] | 0.20 [0.19–0.21] | 1.0× |
| avatar c=1 p99 ms | 0.51 [0.49–0.55] | 0.51 [0.46–0.54] | 1.0× |
| avatar c=1 CPU µs/success | 311 [303–331] | 301 [288–329] | 1.0× |
| avatar c=16 req/s | 26,756 [25,026–28,748] | 26,543 [25,436–27,250] | 1.0× |
| avatar c=16 p50 ms | 0.36 [0.34–0.39] | 0.36 [0.35–0.38] | 1.0× |
| avatar c=16 p99 ms | 2.78 [2.51–3.04] | 2.96 [2.81–3.06] | 0.9× |
| avatar c=16 CPU µs/success | 129 [121–137] | 127 [124–135] | 1.0× |
| avatar c=64 req/s | 19,228 [19,037–20,074] | 20,283 [18,525–20,703] | 1.1× |
| avatar c=64 p50 ms | 1.42 [1.38–1.44] | 1.48 [1.31–1.50] | 1.0× |
| avatar c=64 p99 ms | 20.2 [19.0–20.3] | 19.3 [18.4–21.4] | 1.0× |
| avatar c=64 CPU µs/success | 174 [167–177] | 167 [161–179] | 1.0× |
| static_css c=1 req/s | 5,434 [5,245–5,509] | 5,323 [4,899–5,391] | 1.0× |
| static_css c=1 p50 ms | 0.17 [0.17–0.17] | 0.17 [0.17–0.19] | 1.0× |
| static_css c=1 p99 ms | 0.41 [0.39–0.44] | 0.42 [0.39–0.46] | 1.0× |
| static_css c=1 CPU µs/success | 271 [266–280] | 277 [274–304] | 1.0× |
| static_css c=16 req/s | 35,064 [34,184–35,335] | 36,127 [34,773–38,753] | 1.0× |
| static_css c=16 p50 ms | 0.30 [0.30–0.30] | 0.29 [0.27–0.30] | 1.0× |
| static_css c=16 p99 ms | 2.26 [2.22–2.40] | 2.21 [2.07–2.30] | 1.0× |
| static_css c=16 CPU µs/success | 102 [102–103] | 99.1 [91.6–103.2] | 1.0× |
| static_css c=64 req/s | 28,721 [27,723–31,044] | 28,103 [26,083–30,496] | 1.0× |
| static_css c=64 p50 ms | 1.14 [1.11–1.17] | 1.14 [1.09–1.18] | 1.0× |
| static_css c=64 p99 ms | 12.9 [11.9–13.6] | 13.6 [11.7–14.3] | 1.0× |
| static_css c=64 CPU µs/success | 122 [114–126] | 125 [116–132] | 1.0× |
| up c=1 req/s | 954 [932–973] | 1,327 [1,187–1,399] | 1.4× |
| up c=1 p50 ms | 1.00 [1.00–1.02] | 0.72 [0.70–0.80] | 1.4× |
| up c=1 p99 ms | 1.61 [1.47–1.74] | 1.22 [1.05–1.47] | 1.3× |
| up c=1 CPU µs/success | 1,614 [1,532–1,718] | 1,217 [1,136–1,333] | 1.3× |
| up c=16 req/s | 3,409 [3,266–3,613] | 4,597 [4,374–4,768] | 1.3× |
| up c=16 p50 ms | 4.16 [3.93–4.39] | 3.21 [3.13–3.41] | 1.3× |
| up c=16 p99 ms | 13.3 [12.0–14.6] | 9.06 [8.44–9.61] | 1.5× |
| up c=16 CPU µs/success | 1,122 [1,083–1,155] | 797 [777–841] | 1.4× |
| up c=64 req/s | 3,344 [3,219–3,491] | 4,530 [4,344–4,721] | 1.4× |
| up c=64 p50 ms | 18.0 [17.0–18.9] | 13.0 [12.4–13.6] | 1.4× |
| up c=64 p99 ms | 49.6 [45.9–50.3] | 38.8 [37.3–40.1] | 1.3× |
| up c=64 CPU µs/success | 1,153 [1,115–1,166] | 822 [790–864] | 1.4× |
| post_message c=1 req/s | 92.2 [82.7–93.9] | 93.8 [87.9–97.9] | 1.0× |
| post_message c=1 p50 ms | 10.7 [10.4–11.9] | 10.7 [10.0–11.2] | 1.0× |
| post_message c=1 p99 ms | 17.4 [16.8–18.5] | 16.6 [15.6–19.4] | 1.0× |
| post_message c=1 CPU µs/success | 18,741 [17,987–20,367] | 24,487 [23,439–25,633] | 0.8× |
| post_message c=16 req/s | 288 [269–300] | 174 [170–210] | 0.6× |
| post_message c=16 p50 ms | 55.6 [51.9–58.8] | 91.1 [74.7–94.4] | 0.6× |
| post_message c=16 p99 ms | 76.8 [72.4–86.1] | 118 [103–131] | 0.7× |
| post_message c=16 CPU µs/success | 11,195 [10,737–11,654] | 21,193 [17,816–21,370] | 0.5× |
| post_message c=64 req/s | 319 [311–348] | 167 [157–171] | 0.5× |
| post_message c=64 p50 ms | 197 [183–206] | 392 [374–406] | 0.5× |
| post_message c=64 p99 ms | 236 [214–253] | 474 [431–513] | 0.5× |
| post_message c=64 CPU µs/success | 9,924 [9,171–10,326] | 22,273 [21,594–23,569] | 0.4× |

### HTTP errors / non-2xx-3xx (first rep, per app)

| Metric | Elixir baseline | Elixir candidate | Candidate advantage over baseline |
|---|---|---|---|
- baseline: none
- candidate: none

### Action Cable fan-out (one room; chatter.js subscriptions per client)

| Metric | Elixir baseline | Elixir candidate | Candidate advantage over baseline |
|---|---|---|---|
| 100 clients: subscribed | 100 [100–100] | 100 [100–100] | 1.0× |
| 100 clients: connect+subscribe all (s) | 0.16 [0.11–0.17] | 0.20 [0.17–0.22] | 0.8× |
| 100 clients: paced post→one client p50 ms | 11.0 [10.9–11.8] | 11.9 [11.6–12.2] | 0.9× |
| 100 clients: paced post→all clients p50 ms | 12.1 [11.7–12.5] | 12.9 [12.5–13.2] | 0.9× |
| 100 clients: paced post→all clients p99 ms | 25.9 [21.9–36.3] | 21.7 [18.9–24.0] | 1.2× |
| 100 clients: max sustained msgs/s (delivered to all) | 142 [131–144] | 114 [110–119] | 0.8× |
| 100 clients: deliveries/s (client×message) | 14,190 [13,139–14,438] | 11,364 [10,974–11,918] | 0.8× |
| 100 clients: saturated post→all p50 ms | 23.7 [23.2–25.0] | 32.2 [31.0–33.3] | 0.7× |
| 100 clients: saturated POST p50 ms | 27.7 [27.2–28.8] | 34.8 [33.4–36.0] | 0.8× |
| 500 clients: subscribed | 500 [500–500] | 500 [500–500] | 1.0× |
| 500 clients: connect+subscribe all (s) | 0.56 [0.54–0.63] | 0.82 [0.76–0.84] | 0.7× |
| 500 clients: paced post→one client p50 ms | 15.5 [14.1–16.5] | 15.6 [15.2–15.8] | 1.0× |
| 500 clients: paced post→all clients p50 ms | 20.7 [19.5–21.3] | 20.8 [20.2–21.8] | 1.0× |
| 500 clients: paced post→all clients p99 ms | 26.8 [22.4–28.8] | 27.0 [25.6–27.4] | 1.0× |
| 500 clients: max sustained msgs/s (delivered to all) | 61.5 [59.1–64.1] | 54.5 [54.0–57.0] | 0.9× |
| 500 clients: deliveries/s (client×message) | 30,787 [29,559–32,073] | 27,215 [27,001–28,505] | 0.9× |
| 500 clients: saturated post→all p50 ms | 57.3 [56.2–59.5] | 69.5 [66.9–70.3] | 0.8× |
| 500 clients: saturated POST p50 ms | 64.1 [61.9–66.5] | 72.7 [70.3–73.4] | 0.9× |
| 1000 clients: subscribed | 1,000 [1,000–1,000] | 1,000 [1,000–1,000] | 1.0× |
| 1000 clients: connect+subscribe all (s) | 1.03 [0.99–1.07] | 1.55 [1.42–1.78] | 0.7× |
| 1000 clients: paced post→one client p50 ms | 20.9 [20.0–21.8] | 20.3 [19.3–21.1] | 1.0× |
| 1000 clients: paced post→all clients p50 ms | 34.1 [32.6–34.7] | 30.7 [30.3–31.5] | 1.1× |
| 1000 clients: paced post→all clients p99 ms | 48.7 [45.8–52.2] | 41.2 [38.1–46.8] | 1.2× |
| 1000 clients: max sustained msgs/s (delivered to all) | 34.9 [34.0–36.8] | 33.2 [32.1–35.7] | 1.0× |
| 1000 clients: deliveries/s (client×message) | 34,885 [33,952–36,768] | 33,222 [32,090–35,661] | 1.0× |
| 1000 clients: saturated post→all p50 ms | 105 [101–108] | 115 [107–118] | 0.9× |
| 1000 clients: saturated POST p50 ms | 113 [108–117] | 121 [111–123] | 0.9× |

### Upload + thumbnail (black_hole.jpg, 505 KB)

| Metric | Elixir baseline | Elixir candidate | Candidate advantage over baseline |
|---|---|---|---|
| POST with attachment (ms) | 218 [196–240] | 205 [201–253] | 1.1× |
| then GET thumb → 200 (ms) | 0.80 [0.70–0.80] | 0.85 [0.70–0.90] | 0.9× |
| POST → thumbnail served (ms) | 219 [197–240] | 206 [202–254] | 1.1× |

### Memory during cable fan-out, by process (MiB, peak within the phase)

App process: Elixir BEAM; Rails Puma master/workers when included;
Go/Rust's integrated campfire processes. Serving totals include native helpers, Redis and Thruster.
PSS apportions shared pages; RssAnon counts them in each process.

| Metric | Elixir baseline | Elixir candidate | Candidate advantage over baseline |
|---|---|---|---|
| 100 clients, all subscribed, idle: app process Pss | 238 [224–243] | 198 [190–205] | 1.2× |
| 100 clients, all subscribed, idle: app process RssAnon | 195 [180–200] | 155 [148–163] | 1.3× |
| 100 clients, all subscribed, idle: serving processes Pss | 273 [260–279] | 226 [218–233] | 1.2× |
| 100 clients, all subscribed, idle: whole container Pss | 274 [261–279] | 227 [220–234] | 1.2× |
| 100 clients, saturated fan-out: app process Pss | 272 [270–274] | 276 [270–277] | 1.0× |
| 100 clients, saturated fan-out: app process RssAnon | 228 [226–230] | 234 [228–234] | 1.0× |
| 100 clients, saturated fan-out: serving processes Pss | 322 [320–325] | 314 [309–315] | 1.0× |
| 100 clients, saturated fan-out: whole container Pss | 323 [322–326] | 315 [310–316] | 1.0× |
| 500 clients, all subscribed, idle: app process Pss | 279 [271–280] | 294 [281–300] | 0.9× |
| 500 clients, all subscribed, idle: app process RssAnon | 235 [227–236] | 251 [238–258] | 0.9× |
| 500 clients, all subscribed, idle: serving processes Pss | 347 [341–350] | 352 [340–357] | 1.0× |
| 500 clients, all subscribed, idle: whole container Pss | 349 [342–351] | 353 [341–358] | 1.0× |
| 500 clients, saturated fan-out: app process Pss | 327 [323–330] | 318 [311–332] | 1.0× |
| 500 clients, saturated fan-out: app process RssAnon | 283 [278–286] | 275 [269–289] | 1.0× |
| 500 clients, saturated fan-out: serving processes Pss | 425 [421–429] | 399 [394–412] | 1.1× |
| 500 clients, saturated fan-out: whole container Pss | 425 [422–430] | 400 [395–414] | 1.1× |
| 1000 clients, all subscribed, idle: app process Pss | 340 [337–345] | 348 [331–360] | 1.0× |
| 1000 clients, all subscribed, idle: app process RssAnon | 296 [292–301] | 305 [288–318] | 1.0× |
| 1000 clients, all subscribed, idle: serving processes Pss | 465 [444–472] | 447 [416–474] | 1.0× |
| 1000 clients, all subscribed, idle: whole container Pss | 466 [445–474] | 448 [417–476] | 1.0× |
| 1000 clients, saturated fan-out: app process Pss | 386 [380–387] | 357 [353–374] | 1.1× |
| 1000 clients, saturated fan-out: app process RssAnon | 342 [336–343] | 314 [311–332] | 1.1× |
| 1000 clients, saturated fan-out: serving processes Pss | 529 [508–535] | 481 [468–494] | 1.1× |
| 1000 clients, saturated fan-out: whole container Pss | 530 [509–536] | 482 [469–494] | 1.1× |
