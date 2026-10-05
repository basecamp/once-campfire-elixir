```
date: 2026-10-05T08:12:05+00:00
host: 7.0.14-orbstack-00380-ga7e0a2dc9535, , 14 threads, 15GB
server cpus: 2-5 (nproc 4); loadgen cpus: 6-9; network: host
env: WEB_CONCURRENCY=3 JOB_CONCURRENCY=3 RAILS_MAX_THREADS=5
seed sha256: bda9a5cd61d78d53f377cf07ee9268741caebc19b94a6efe782cafe827efc8db  /var/lib/docker/volumes/campfire-mac-bench-01a10a43/_data/arm64/candidate/parity/.seed/default/db/production.sqlite3
seed tree sha256: c58532c20db34e3df10e5c39969cd328f4bd815e5beb1dabfdfa2af5805e29c5  -
loadgen sha256: 1f42704c27a8ee84fb4f59967d57dd0bb24c6aaf1a0af017229c068037cedec8  /var/lib/docker/volumes/campfire-mac-bench-01a10a43/_data/arm64/candidate/target/bench/release/loadgen
loadgen build image: rust@sha256:4cd829461bd5c4d511c32e269da9cb8929223b666519d8004e35fc8d1d771ab7
elixir source digest: cf87f7de83295e1cb2510ed2e0f3287ac476f42cd2aee31dcb12653304af611b
rust extra env:
workload: suites=http cable upload HTTP_SECS=4 HTTP_CONCS=1 16 64 CABLE_CLIENTS=100 500 1000 CABLE_TPUT_SECS=15 CABLE_POSTERS=4 UPLOAD_REPS=5 REPS=4
quiet wait: LOAD_MAX=1.5 LOAD_WAIT_SECS=900
user agent: (none)
baseline image: sha256:2c20e000614331f2078e86e78b0397995ee23157e910cd4428f9d3ea988e993e sha256:2c20e000614331f2078e86e78b0397995ee23157e910cd4428f9d3ea988e993e 2026-10-05T08:34:24.266842039+02:00 unpacked_bytes=671674566
candidate image: sha256:020a82c81cece6952cbd143c2057709b56dd853c43164e7789c4052af2bf61d9 sha256:020a82c81cece6952cbd143c2057709b56dd853c43164e7789c4052af2bf61d9 2026-10-05T09:18:17.693459155+02:00 unpacked_bytes=671447728
baseline source: b6b82e50a653c4060136bb04e805eb78fd76ba10
candidate source: 7c1ed67d062f5e241d37e3eb0e9a3d97a2324636
```

Reps: baseline 4, candidate 4. Cells: median [min–max].

### Startup and memory

| Metric | Elixir baseline | Elixir candidate | Candidate advantage over baseline |
|---|---|---|---|
| cold start: docker run → /up 200 (ms) | 664 [619–696] | 624 [602–667] | 1.1× |
| idle memory.current (MiB) | 198 [191–209] | 194 [192–205] | 1.0× |
| idle anon (MiB) | 124 [110–135] | 118 [111–124] | 1.1× |
| peak memory.current under load (MiB) | 703 [657–739] | 716 [685–754] | 1.0× |
| peak anon under load (MiB) | 560 [515–595] | 573 [539–611] | 1.0× |

### HTTP (signed in as david; keep-alive; c = concurrent connections)

| Metric | Elixir baseline | Elixir candidate | Candidate advantage over baseline |
|---|---|---|---|
| room_show c=1 req/s | 275 [255–277] | 266 [234–289] | 1.0× |
| room_show c=1 p50 ms | 3.52 [3.42–3.83] | 3.61 [3.40–4.22] | 1.0× |
| room_show c=1 p99 ms | 6.33 [5.55–7.00] | 5.74 [4.32–6.22] | 1.1× |
| room_show c=1 CPU µs/success | 4,203 [4,111–4,464] | 4,507 [4,142–5,234] | 0.9× |
| room_show c=16 req/s | 359 [337–391] | 600 [583–644] | 1.7× |
| room_show c=16 p50 ms | 44.3 [40.5–46.9] | 26.2 [24.3–27.0] | 1.7× |
| room_show c=16 p99 ms | 59.1 [56.4–67.1] | 38.7 [36.8–40.1] | 1.5× |
| room_show c=16 CPU µs/success | 5,349 [4,883–5,913] | 5,320 [5,109–5,472] | 1.0× |
| room_show c=64 req/s | 428 [396–456] | 555 [539–583] | 1.3× |
| room_show c=64 p50 ms | 148 [140–161] | 114 [109–118] | 1.3× |
| room_show c=64 p99 ms | 182 [166–195] | 134 [126–136] | 1.4× |
| room_show c=64 CPU µs/success | 4,921 [4,659–5,173] | 5,468 [5,207–5,602] | 0.9× |
| messages_page c=1 req/s | 338 [294–386] | 341 [295–373] | 1.0× |
| messages_page c=1 p50 ms | 2.88 [2.50–3.26] | 2.88 [2.60–3.31] | 1.0× |
| messages_page c=1 p99 ms | 5.69 [3.94–7.63] | 4.79 [3.59–5.02] | 1.2× |
| messages_page c=1 CPU µs/success | 3,409 [2,919–4,018] | 3,339 [3,068–3,833] | 1.0× |
| messages_page c=16 req/s | 559 [519–599] | 870 [840–897] | 1.6× |
| messages_page c=16 p50 ms | 28.2 [26.3–30.6] | 17.9 [17.4–18.5] | 1.6× |
| messages_page c=16 p99 ms | 45.1 [40.0–49.1] | 29.7 [29.3–31.2] | 1.5× |
| messages_page c=16 CPU µs/success | 4,015 [3,750–4,225] | 3,822 [3,753–3,896] | 1.1× |
| messages_page c=64 req/s | 622 [592–638] | 782 [745–818] | 1.3× |
| messages_page c=64 p50 ms | 102 [99–109] | 81.3 [78.1–85.5] | 1.3× |
| messages_page c=64 p99 ms | 137 [121–156] | 97.1 [92.7–104.3] | 1.4× |
| messages_page c=64 CPU µs/success | 3,813 [3,713–4,002] | 4,002 [3,900–4,172] | 1.0× |
| sidebar c=1 req/s | 611 [512–733] | 588 [413–638] | 1.0× |
| sidebar c=1 p50 ms | 1.51 [1.27–1.79] | 1.62 [1.50–2.26] | 0.9× |
| sidebar c=1 p99 ms | 3.47 [2.85–5.41] | 3.78 [2.82–5.42] | 0.9× |
| sidebar c=1 CPU µs/success | 2,312 [1,889–2,621] | 2,462 [2,316–3,339] | 0.9× |
| sidebar c=16 req/s | 739 [662–819] | 689 [624–722] | 0.9× |
| sidebar c=16 p50 ms | 20.9 [18.7–23.1] | 22.8 [21.6–25.3] | 0.9× |
| sidebar c=16 p99 ms | 33.7 [32.2–38.8] | 34.0 [31.6–34.9] | 1.0× |
| sidebar c=16 CPU µs/success | 2,281 [2,050–2,415] | 4,164 [3,950–4,500] | 0.5× |
| sidebar c=64 req/s | 749 [670–780] | 621 [585–648] | 0.8× |
| sidebar c=64 p50 ms | 84.8 [80.4–94.9] | 102 [98–109] | 0.8× |
| sidebar c=64 p99 ms | 107 [106–121] | 122 [119–127] | 0.9× |
| sidebar c=64 CPU µs/success | 2,301 [2,211–2,539] | 4,456 [4,278–4,711] | 0.5× |
| search c=1 req/s | 482 [374–550] | 504 [439–540] | 1.0× |
| search c=1 p50 ms | 1.90 [1.72–2.53] | 1.91 [1.78–2.12] | 1.0× |
| search c=1 p99 ms | 4.43 [3.09–6.47] | 4.37 [3.26–5.85] | 1.0× |
| search c=1 CPU µs/success | 2,499 [2,271–3,263] | 2,563 [2,393–2,926] | 1.0× |
| search c=16 req/s | 615 [552–687] | 914 [864–938] | 1.5× |
| search c=16 p50 ms | 25.7 [23.0–28.6] | 17.1 [16.7–18.1] | 1.5× |
| search c=16 p99 ms | 38.2 [34.2–44.6] | 26.4 [26.3–28.1] | 1.4× |
| search c=16 CPU µs/success | 2,841 [2,617–3,072] | 3,283 [3,187–3,440] | 0.9× |
| search c=64 req/s | 643 [616–706] | 815 [788–838] | 1.3× |
| search c=64 p50 ms | 97.9 [90.2–104.7] | 77.9 [75.8–80.3] | 1.3× |
| search c=64 p99 ms | 141 [112–155] | 93.0 [89.7–95.8] | 1.5× |
| search c=64 CPU µs/success | 2,839 [2,596–3,011] | 3,531 [3,448–3,642] | 0.8× |
| avatar c=1 req/s | 8,472 [7,793–8,774] | 8,561 [8,364–8,778] | 1.0× |
| avatar c=1 p50 ms | 0.09 [0.09–0.10] | 0.08 [0.08–0.09] | 1.0× |
| avatar c=1 p99 ms | 0.96 [0.87–1.10] | 1.08 [0.89–1.32] | 0.9× |
| avatar c=1 CPU µs/success | 61.9 [56.4–68.8] | 59.2 [57.8–63.4] | 1.0× |
| avatar c=16 req/s | 17,264 [16,663–17,776] | 17,418 [17,116–18,105] | 1.0× |
| avatar c=16 p50 ms | 0.32 [0.31–0.35] | 0.31 [0.29–0.32] | 1.0× |
| avatar c=16 p99 ms | 7.08 [6.95–7.59] | 7.27 [6.99–7.46] | 1.0× |
| avatar c=16 CPU µs/success | 58.5 [55.8–66.6] | 57.1 [54.1–58.1] | 1.0× |
| avatar c=64 req/s | 18,143 [17,869–18,531] | 19,293 [18,394–19,381] | 1.1× |
| avatar c=64 p50 ms | 1.35 [1.18–1.37] | 1.24 [1.21–1.27] | 1.1× |
| avatar c=64 p99 ms | 19.0 [18.2–19.7] | 18.2 [17.8–19.0] | 1.0× |
| avatar c=64 CPU µs/success | 64.6 [60.1–67.8] | 62.5 [59.4–63.8] | 1.0× |
| static_css c=1 req/s | 9,999 [9,539–10,964] | 10,472 [9,929–10,672] | 1.0× |
| static_css c=1 p50 ms | 0.08 [0.07–0.08] | 0.08 [0.07–0.08] | 1.1× |
| static_css c=1 p99 ms | 0.21 [0.16–0.28] | 0.20 [0.17–0.22] | 1.0× |
| static_css c=1 CPU µs/success | 53.5 [46.7–58.8] | 49.5 [47.4–56.4] | 1.1× |
| static_css c=16 req/s | 25,971 [25,748–26,058] | 25,910 [24,565–26,476] | 1.0× |
| static_css c=16 p50 ms | 0.23 [0.22–0.24] | 0.23 [0.21–0.27] | 1.0× |
| static_css c=16 p99 ms | 5.85 [5.53–6.15] | 6.04 [5.75–6.24] | 1.0× |
| static_css c=16 CPU µs/success | 43.7 [40.2–47.4] | 41.5 [39.4–49.7] | 1.1× |
| static_css c=64 req/s | 24,323 [23,763–24,360] | 24,882 [23,402–25,402] | 1.0× |
| static_css c=64 p50 ms | 0.95 [0.89–1.01] | 0.89 [0.84–1.01] | 1.1× |
| static_css c=64 p99 ms | 14.7 [14.3–15.1] | 14.9 [14.7–15.5] | 1.0× |
| static_css c=64 CPU µs/success | 51.9 [46.5–52.6] | 47.6 [45.5–57.0] | 1.1× |
| up c=1 req/s | 2,862 [2,476–3,242] | 4,073 [3,694–4,570] | 1.4× |
| up c=1 p50 ms | 0.30 [0.26–0.33] | 0.18 [0.17–0.20] | 1.6× |
| up c=1 p99 ms | 1.69 [1.49–1.91] | 1.92 [1.67–2.32] | 0.9× |
| up c=1 CPU µs/success | 374 [307–403] | 238 [203–269] | 1.6× |
| up c=16 req/s | 6,069 [5,228–6,317] | 7,963 [7,371–8,438] | 1.3× |
| up c=16 p50 ms | 2.32 [2.18–2.68] | 1.61 [1.44–1.77] | 1.4× |
| up c=16 p99 ms | 8.58 [8.12–9.46] | 7.92 [7.78–8.12] | 1.1× |
| up c=16 CPU µs/success | 425 [405–490] | 290 [263–321] | 1.5× |
| up c=64 req/s | 6,891 [6,521–7,235] | 9,226 [8,097–9,680] | 1.3× |
| up c=64 p50 ms | 8.68 [8.26–9.16] | 6.31 [5.93–7.33] | 1.4× |
| up c=64 p99 ms | 22.4 [21.3–22.8] | 19.1 [18.1–20.5] | 1.2× |
| up c=64 CPU µs/success | 428 [410–456] | 289 [269–324] | 1.5× |
| post_message c=1 req/s | 193 [105–222] | 231 [182–264] | 1.2× |
| post_message c=1 p50 ms | 4.94 [4.34–8.50] | 4.05 [3.59–5.20] | 1.2× |
| post_message c=1 p99 ms | 13.7 [11.3–23.4] | 12.0 [10.4–13.1] | 1.1× |
| post_message c=1 CPU µs/success | 6,882 [6,196–11,933] | 6,632 [5,723–8,089] | 1.0× |
| post_message c=16 req/s | 339 [226–422] | 531 [440–589] | 1.6× |
| post_message c=16 p50 ms | 46.2 [37.1–67.1] | 30.2 [26.9–36.2] | 1.5× |
| post_message c=16 p99 ms | 72.6 [56.0–126.6] | 41.5 [35.7–46.9] | 1.8× |
| post_message c=16 CPU µs/success | 4,702 [3,724–6,786] | 6,224 [5,546–7,281] | 0.8× |
| post_message c=64 req/s | 375 [331–471] | 470 [398–531] | 1.3× |
| post_message c=64 p50 ms | 171 [136–190] | 138 [120–160] | 1.2× |
| post_message c=64 p99 ms | 211 [157–244] | 159 [140–195] | 1.3× |
| post_message c=64 CPU µs/success | 4,401 [3,432–5,035] | 6,912 [6,057–8,022] | 0.6× |

### HTTP errors / non-2xx-3xx (first rep, per app)

| Metric | Elixir baseline | Elixir candidate | Candidate advantage over baseline |
|---|---|---|---|
- baseline: none
- candidate: none

### Action Cable fan-out (one room; chatter.js subscriptions per client)

| Metric | Elixir baseline | Elixir candidate | Candidate advantage over baseline |
|---|---|---|---|
| 100 clients: subscribed | 100 [100–100] | 100 [100–100] | 1.0× |
| 100 clients: connect+subscribe all (s) | 0.12 [0.12–0.17] | 0.09 [0.06–0.11] | 1.3× |
| 100 clients: paced post→one client p50 ms | 8.81 [7.97–10.53] | 7.92 [6.48–8.66] | 1.1× |
| 100 clients: paced post→all clients p50 ms | 9.60 [8.32–11.41] | 8.40 [6.66–9.28] | 1.1× |
| 100 clients: paced post→all clients p99 ms | 23.0 [17.2–34.2] | 18.3 [12.1–21.2] | 1.3× |
| 100 clients: max sustained msgs/s (delivered to all) | 217 [128–245] | 336 [282–368] | 1.5× |
| 100 clients: deliveries/s (client×message) | 21,724 [12,789–24,537] | 33,640 [28,243–36,829] | 1.5× |
| 100 clients: saturated post→all p50 ms | 15.1 [13.5–25.0] | 10.9 [9.9–12.8] | 1.4× |
| 100 clients: saturated POST p50 ms | 17.6 [15.6–29.3] | 11.4 [10.3–13.5] | 1.5× |
| 500 clients: subscribed | 500 [500–500] | 500 [500–500] | 1.0× |
| 500 clients: connect+subscribe all (s) | 0.35 [0.26–0.48] | 0.32 [0.31–0.36] | 1.1× |
| 500 clients: paced post→one client p50 ms | 16.6 [13.5–24.7] | 12.7 [11.1–14.2] | 1.3× |
| 500 clients: paced post→all clients p50 ms | 19.4 [15.7–29.9] | 15.0 [13.4–17.3] | 1.3× |
| 500 clients: paced post→all clients p99 ms | 38.3 [30.4–43.3] | 33.4 [27.5–38.8] | 1.1× |
| 500 clients: max sustained msgs/s (delivered to all) | 108 [80–115] | 140 [129–148] | 1.3× |
| 500 clients: deliveries/s (client×message) | 53,874 [40,188–57,435] | 69,774 [64,619–73,836] | 1.3× |
| 500 clients: saturated post→all p50 ms | 32.1 [30.2–38.4] | 28.4 [26.9–30.3] | 1.1× |
| 500 clients: saturated POST p50 ms | 36.5 [34.1–43.8] | 28.3 [26.7–30.4] | 1.3× |
| 1000 clients: subscribed | 1,000 [1,000–1,000] | 1,000 [1,000–1,000] | 1.0× |
| 1000 clients: connect+subscribe all (s) | 0.58 [0.53–0.76] | 0.61 [0.52–0.64] | 1.0× |
| 1000 clients: paced post→one client p50 ms | 30.1 [29.0–32.2] | 18.1 [15.0–19.4] | 1.7× |
| 1000 clients: paced post→all clients p50 ms | 36.4 [35.2–40.4] | 23.1 [20.5–26.2] | 1.6× |
| 1000 clients: paced post→all clients p99 ms | 51.9 [38.5–62.7] | 40.9 [29.0–49.2] | 1.3× |
| 1000 clients: max sustained msgs/s (delivered to all) | 61.2 [56.5–68.0] | 79.2 [76.7–82.7] | 1.3× |
| 1000 clients: deliveries/s (client×message) | 61,176 [56,469–68,036] | 79,141 [76,740–82,669] | 1.3× |
| 1000 clients: saturated post→all p50 ms | 56.2 [51.7–60.5] | 49.8 [47.7–50.7] | 1.1× |
| 1000 clients: saturated POST p50 ms | 64.2 [58.1–69.6] | 50.2 [48.2–51.6] | 1.3× |

### Upload + thumbnail (black_hole.jpg, 505 KB)

| Metric | Elixir baseline | Elixir candidate | Candidate advantage over baseline |
|---|---|---|---|
| POST with attachment (ms) | 97.4 [93.6–102.1] | 95.2 [94.2–96.0] | 1.0× |
| then GET thumb → 200 (ms) | 0.30 [0.30–0.40] | 0.30 [0.30–0.30] | 1.0× |
| POST → thumbnail served (ms) | 97.8 [93.8–102.5] | 95.4 [94.4–96.4] | 1.0× |

### Memory during cable fan-out, by process (MiB, peak within the phase)

App process: Elixir BEAM; Rails Puma master/workers when included;
Go/Rust's integrated campfire processes. Serving totals include native helpers, Redis and Thruster.
PSS apportions shared pages; RssAnon counts them in each process.

| Metric | Elixir baseline | Elixir candidate | Candidate advantage over baseline |
|---|---|---|---|
| 100 clients, all subscribed, idle: app process Pss | 232 [222–241] | 204 [195–212] | 1.1× |
| 100 clients, all subscribed, idle: app process RssAnon | 198 [186–207] | 172 [162–179] | 1.1× |
| 100 clients, all subscribed, idle: serving processes Pss | 271 [260–279] | 232 [224–241] | 1.2× |
| 100 clients, all subscribed, idle: whole container Pss | 270 [261–278] | 232 [225–242] | 1.2× |
| 100 clients, saturated fan-out: app process Pss | 313 [257–323] | 351 [323–371] | 0.9× |
| 100 clients, saturated fan-out: app process RssAnon | 278 [222–288] | 318 [292–338] | 0.9× |
| 100 clients, saturated fan-out: serving processes Pss | 367 [304–382] | 390 [361–412] | 0.9× |
| 100 clients, saturated fan-out: whole container Pss | 368 [305–382] | 391 [362–412] | 0.9× |
| 500 clients, all subscribed, idle: app process Pss | 320 [268–333] | 367 [344–384] | 0.9× |
| 500 clients, all subscribed, idle: app process RssAnon | 287 [233–300] | 334 [312–351] | 0.9× |
| 500 clients, all subscribed, idle: serving processes Pss | 400 [340–411] | 432 [407–449] | 0.9× |
| 500 clients, all subscribed, idle: whole container Pss | 401 [341–412] | 432 [408–449] | 0.9× |
| 500 clients, saturated fan-out: app process Pss | 358 [320–371] | 368 [353–384] | 1.0× |
| 500 clients, saturated fan-out: app process RssAnon | 326 [285–338] | 335 [324–351] | 1.0× |
| 500 clients, saturated fan-out: serving processes Pss | 477 [428–490] | 473 [458–490] | 1.0× |
| 500 clients, saturated fan-out: whole container Pss | 477 [427–488] | 469 [456–484] | 1.0× |
| 1000 clients, all subscribed, idle: app process Pss | 392 [342–405] | 393 [392–396] | 1.0× |
| 1000 clients, all subscribed, idle: app process RssAnon | 360 [311–372] | 364 [362–366] | 1.0× |
| 1000 clients, all subscribed, idle: serving processes Pss | 526 [479–551] | 521 [515–523] | 1.0× |
| 1000 clients, all subscribed, idle: whole container Pss | 527 [479–552] | 521 [516–524] | 1.0× |
| 1000 clients, saturated fan-out: app process Pss | 406 [385–418] | 424 [411–428] | 1.0× |
| 1000 clients, saturated fan-out: app process RssAnon | 374 [354–387] | 394 [382–398] | 0.9× |
| 1000 clients, saturated fan-out: serving processes Pss | 573 [543–588] | 578 [566–587] | 1.0× |
| 1000 clients, saturated fan-out: whole container Pss | 572 [544–584] | 575 [566–586] | 1.0× |
