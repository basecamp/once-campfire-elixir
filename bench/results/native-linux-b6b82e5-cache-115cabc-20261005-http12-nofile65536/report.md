```
date: 2026-10-05T16:34:48+00:00
host: 6.1.158+, Intel(R) Xeon(R) Processor @ 2.60GHz, 16 threads, 31GB
server cpus: 0,2,4,6 (nproc 4); loadgen cpus: 8,10,12,14; network: host
env: WEB_CONCURRENCY=3 JOB_CONCURRENCY=3 RAILS_MAX_THREADS=5
seed sha256: bda9a5cd61d78d53f377cf07ee9268741caebc19b94a6efe782cafe827efc8db  /home/user/workspace/repo/var/linux-benchmark-setup/seed/default/db/production.sqlite3
seed tree sha256: d0c0b2708846c2f261e7bf6c8a4d7b220b9df71ba21190a172ffcb5acf38b963  -
loadgen sha256: 6d5b5bc3ceb0125a5996a1517de04782763eb53c2b2fb7bc0d0e4967db144820  /home/user/workspace/benchmark-cache-final-linux/target/bench/release/loadgen
loadgen build image: rust@sha256:4cd829461bd5c4d511c32e269da9cb8929223b666519d8004e35fc8d1d771ab7
docker runtime: 29.8.1
benchmark source: 115cabc787bd3ed7bb6ccba5a6d9d6a4fc7e5948 (bench dirty: 1 files)
benchmark harness sha256: 69f8334c0a2a2f778ba4890cb973085786e454b0a940e8529e16522ec213a392  -
elixir source digest: d95a406a33915790b632420d97840c96d76e4bd8a5e7595c58bdf2d84bf58efe
rust extra env:
workload: suites=http cable upload HTTP_SECS=12 HTTP_CONCS=1 16 64 CABLE_CLIENTS=100 500 1000 CABLE_TPUT_SECS=15 CABLE_POSTERS=4 UPLOAD_REPS=5 REPS=4
descriptors: server_nofile=65536 loadgen_nofile=65536; job_drain_secs=120
quiet wait: LOAD_MAX=1.5 LOAD_WAIT_SECS=900
user agent: (none)
baseline image: sha256:7cb5658090eee9c77c4d19572766434bb4a2b6654b80334bb8f43df02f922182 sha256:7cb5658090eee9c77c4d19572766434bb4a2b6654b80334bb8f43df02f922182 2026-10-05T06:37:12.019194803Z unpacked_bytes=2542179488
candidate image: sha256:57ec8cf3ec3539e3a5b6e5b41ef1010862eebff5f36942182b52bfab556ac6f5 sha256:57ec8cf3ec3539e3a5b6e5b41ef1010862eebff5f36942182b52bfab556ac6f5 2026-10-05T15:17:39.928256978Z unpacked_bytes=2540419277
baseline source: b6b82e50a653c4060136bb04e805eb78fd76ba10
candidate source: 6f06e50f2ec5dae69331c2c5dd033b4ac8849580+verified-cache-overlay; app-source-equivalent-to-115cabc787bd3ed7bb6ccba5a6d9d6a4fc7e5948; not-rebuilt-from-115cabc
```

Reps: baseline 4, candidate 4. Cells: median [min–max].

### Startup and memory

| Metric | Elixir baseline | Elixir candidate | Candidate advantage over baseline |
|---|---|---|---|
| cold start: docker run → /up 200 (ms) | 1,260 [1,115–1,329] | 1,216 [1,149–1,250] | 1.0× |
| idle memory.current (MiB) | 146 [136–152] | 145 [142–150] | 1.0× |
| idle anon (MiB) | 111 [102–117] | 110 [107–115] | 1.0× |
| peak memory.current under load (MiB) | 574 [543–611] | 620 [594–657] | 0.9× |
| peak anon under load (MiB) | 498 [483–562] | 534 [507–564] | 0.9× |

### HTTP (signed in as david; keep-alive; c = concurrent connections)

| Metric | Elixir baseline | Elixir candidate | Candidate advantage over baseline |
|---|---|---|---|
| room_show c=1 req/s | 100 [93–106] | 114 [106–122] | 1.1× |
| room_show c=1 p50 ms | 9.27 [9.19–10.07] | 8.42 [8.10–8.81] | 1.1× |
| room_show c=1 p99 ms | 17.3 [13.1–18.8] | 12.7 [10.6–17.2] | 1.4× |
| room_show c=1 CPU µs/success | 13,000 [12,449–14,263] | 10,985 [10,271–12,031] | 1.2× |
| room_show c=16 req/s | 288 [277–314] | 343 [322–366] | 1.2× |
| room_show c=16 p50 ms | 54.4 [50.6–56.2] | 45.5 [42.8–48.3] | 1.2× |
| room_show c=16 p99 ms | 82.3 [66.2–94.5] | 83.0 [74.1–89.9] | 1.0× |
| room_show c=16 CPU µs/success | 12,322 [11,420–12,660] | 11,570 [10,842–12,314] | 1.1× |
| room_show c=64 req/s | 303 [282–310] | 321 [314–337] | 1.1× |
| room_show c=64 p50 ms | 210 [203–221] | 195 [187–201] | 1.1× |
| room_show c=64 p99 ms | 260 [241–311] | 401 [341–402] | 0.6× |
| room_show c=64 CPU µs/success | 11,618 [11,423–12,471] | 12,335 [11,699–12,631] | 0.9× |
| messages_page c=1 req/s | 138 [118–139] | 147 [139–151] | 1.1× |
| messages_page c=1 p50 ms | 7.03 [6.79–7.93] | 6.51 [6.42–6.86] | 1.1× |
| messages_page c=1 p99 ms | 12.3 [10.7–14.3] | 10.6 [10.1–11.9] | 1.2× |
| messages_page c=1 CPU µs/success | 9,118 [9,008–10,762] | 8,292 [8,116–9,793] | 1.1× |
| messages_page c=16 req/s | 392 [375–418] | 454 [432–456] | 1.2× |
| messages_page c=16 p50 ms | 40.0 [37.4–41.3] | 32.9 [32.4–34.3] | 1.2× |
| messages_page c=16 p99 ms | 61.9 [56.9–70.9] | 78.9 [74.9–86.2] | 0.8× |
| messages_page c=16 CPU µs/success | 9,233 [8,651–9,630] | 8,778 [8,736–9,152] | 1.1× |
| messages_page c=64 req/s | 398 [381–421] | 418 [404–424] | 1.1× |
| messages_page c=64 p50 ms | 158 [150–164] | 138 [133–140] | 1.1× |
| messages_page c=64 p99 ms | 210 [188–222] | 393 [379–403] | 0.5× |
| messages_page c=64 CPU µs/success | 9,227 [8,649–9,499] | 9,490 [9,396–9,859] | 1.0× |
| sidebar c=1 req/s | 249 [199–277] | 294 [283–305] | 1.2× |
| sidebar c=1 p50 ms | 3.69 [3.49–4.39] | 3.26 [3.14–3.37] | 1.1× |
| sidebar c=1 p99 ms | 6.45 [5.53–13.49] | 5.39 [4.83–5.56] | 1.2× |
| sidebar c=1 CPU µs/success | 6,398 [5,915–8,065] | 5,672 [5,489–5,873] | 1.1× |
| sidebar c=16 req/s | 449 [411–465] | 733 [717–749] | 1.6× |
| sidebar c=16 p50 ms | 34.7 [33.6–38.1] | 21.0 [20.6–21.5] | 1.6× |
| sidebar c=16 p99 ms | 54.3 [51.7–59.0] | 40.1 [39.3–42.0] | 1.4× |
| sidebar c=16 CPU µs/success | 7,091 [7,006–7,659] | 5,341 [5,188–5,466] | 1.3× |
| sidebar c=64 req/s | 448 [419–457] | 728 [717–769] | 1.6× |
| sidebar c=64 p50 ms | 140 [139–146] | 86.7 [77.8–91.8] | 1.6× |
| sidebar c=64 p99 ms | 213 [170–313] | 146 [141–166] | 1.5× |
| sidebar c=64 CPU µs/success | 7,139 [6,899–7,471] | 5,395 [5,072–5,476] | 1.3× |
| search c=1 req/s | 177 [166–182] | 234 [214–245] | 1.3× |
| search c=1 p50 ms | 5.42 [5.28–5.86] | 4.11 [3.89–4.43] | 1.3× |
| search c=1 p99 ms | 8.89 [8.28–9.12] | 6.58 [6.29–7.71] | 1.3× |
| search c=1 CPU µs/success | 8,237 [7,586–8,458] | 6,038 [5,866–6,672] | 1.4× |
| search c=16 req/s | 416 [404–423] | 642 [634–652] | 1.5× |
| search c=16 p50 ms | 37.6 [36.5–38.4] | 24.4 [23.8–24.5] | 1.5× |
| search c=16 p99 ms | 59.1 [55.4–61.3] | 45.2 [41.9–47.0] | 1.3× |
| search c=16 CPU µs/success | 7,999 [7,779–8,036] | 6,166 [6,025–6,193] | 1.3× |
| search c=64 req/s | 442 [432–452] | 633 [624–653] | 1.4× |
| search c=64 p50 ms | 143 [140–148] | 100 [95–105] | 1.4× |
| search c=64 p99 ms | 186 [182–227] | 180 [163–185] | 1.0× |
| search c=64 CPU µs/success | 7,533 [7,339–7,622] | 6,240 [6,063–6,341] | 1.2× |
| avatar c=1 req/s | 4,245 [3,674–4,469] | 4,515 [4,204–4,706] | 1.1× |
| avatar c=1 p50 ms | 0.21 [0.20–0.24] | 0.21 [0.20–0.22] | 1.0× |
| avatar c=1 p99 ms | 0.54 [0.49–0.61] | 0.50 [0.48–0.53] | 1.1× |
| avatar c=1 CPU µs/success | 328 [311–385] | 308 [292–336] | 1.1× |
| avatar c=16 req/s | 25,287 [24,568–27,611] | 26,250 [25,174–28,564] | 1.0× |
| avatar c=16 p50 ms | 0.38 [0.35–0.39] | 0.37 [0.34–0.38] | 1.0× |
| avatar c=16 p99 ms | 3.03 [2.75–3.07] | 2.85 [2.58–3.00] | 1.1× |
| avatar c=16 CPU µs/success | 135 [124–139] | 131 [121–136] | 1.0× |
| avatar c=64 req/s | 19,203 [18,541–20,899] | 19,295 [18,959–19,911] | 1.0× |
| avatar c=64 p50 ms | 1.50 [1.47–1.57] | 1.47 [1.41–1.50] | 1.0× |
| avatar c=64 p99 ms | 20.4 [18.5–21.1] | 20.4 [19.5–20.5] | 1.0× |
| avatar c=64 CPU µs/success | 174 [160–180] | 174 [169–178] | 1.0× |
| static_css c=1 req/s | 5,184 [5,066–5,408] | 5,211 [5,065–5,371] | 1.0× |
| static_css c=1 p50 ms | 0.18 [0.17–0.18] | 0.18 [0.17–0.18] | 1.0× |
| static_css c=1 p99 ms | 0.44 [0.41–0.45] | 0.44 [0.41–0.46] | 1.0× |
| static_css c=1 CPU µs/success | 284 [272–295] | 286 [277–294] | 1.0× |
| static_css c=16 req/s | 34,906 [33,557–35,548] | 36,112 [33,879–40,452] | 1.0× |
| static_css c=16 p50 ms | 0.30 [0.29–0.31] | 0.29 [0.26–0.31] | 1.0× |
| static_css c=16 p99 ms | 2.29 [2.23–2.38] | 2.20 [1.96–2.36] | 1.0× |
| static_css c=16 CPU µs/success | 101 [100–107] | 98.6 [88.4–104.7] | 1.0× |
| static_css c=64 req/s | 29,709 [27,507–31,888] | 29,005 [27,324–29,675] | 1.0× |
| static_css c=64 p50 ms | 1.12 [1.06–1.24] | 1.15 [1.12–1.19] | 1.0× |
| static_css c=64 p99 ms | 12.7 [11.6–13.6] | 12.9 [12.6–14.0] | 1.0× |
| static_css c=64 CPU µs/success | 117 [110–129] | 120 [118–128] | 1.0× |
| up c=1 req/s | 976 [905–1,039] | 1,298 [1,209–1,336] | 1.3× |
| up c=1 p50 ms | 0.99 [0.94–1.05] | 0.74 [0.73–0.79] | 1.3× |
| up c=1 p99 ms | 1.59 [1.42–1.78] | 1.25 [1.16–1.42] | 1.3× |
| up c=1 CPU µs/success | 1,615 [1,505–1,718] | 1,249 [1,217–1,337] | 1.3× |
| up c=16 req/s | 3,253 [3,016–3,282] | 4,403 [4,122–4,518] | 1.4× |
| up c=16 p50 ms | 4.34 [4.32–4.75] | 3.30 [3.27–3.51] | 1.3× |
| up c=16 p99 ms | 14.9 [14.6–15.2] | 10.3 [9.2–11.4] | 1.5× |
| up c=16 CPU µs/success | 1,130 [1,122–1,282] | 815 [807–873] | 1.4× |
| up c=64 req/s | 3,270 [2,977–3,367] | 4,380 [4,158–4,483] | 1.3× |
| up c=64 p50 ms | 18.4 [17.8–20.0] | 13.5 [13.1–14.1] | 1.4× |
| up c=64 p99 ms | 48.9 [48.6–54.9] | 39.6 [38.1–42.3] | 1.2× |
| up c=64 CPU µs/success | 1,165 [1,111–1,258] | 832 [825–897] | 1.4× |
| post_message c=1 req/s | 85.9 [72.5–89.6] | 144 [138–155] | 1.7× |
| post_message c=1 p50 ms | 11.3 [11.0–12.5] | 6.79 [6.28–6.83] | 1.7× |
| post_message c=1 p99 ms | 19.0 [18.0–31.8] | 13.2 [12.4–14.1] | 1.4× |
| post_message c=1 CPU µs/success | 18,939 [18,097–21,908] | 15,031 [14,157–15,790] | 1.3× |
| post_message c=16 req/s | 273 [252–307] | 396 [354–400] | 1.4× |
| post_message c=16 p50 ms | 57.6 [51.4–61.6] | 39.9 [39.0–44.2] | 1.4× |
| post_message c=16 p99 ms | 81.2 [68.9–97.7] | 62.2 [56.5–72.4] | 1.3× |
| post_message c=16 CPU µs/success | 11,753 [10,422–12,648] | 9,676 [9,502–10,844] | 1.2× |
| post_message c=64 req/s | 298 [260–319] | 384 [376–394] | 1.3× |
| post_message c=64 p50 ms | 214 [198–234] | 165 [157–169] | 1.3× |
| post_message c=64 p99 ms | 276 [258–361] | 203 [195–245] | 1.4× |
| post_message c=64 CPU µs/success | 10,702 [9,952–12,165] | 9,986 [9,687–10,146] | 1.1× |

### HTTP errors / non-2xx-3xx (first rep, per app)

| Metric | Elixir baseline | Elixir candidate | Candidate advantage over baseline |
|---|---|---|---|
- baseline: none
- candidate: none

### Action Cable fan-out (one room; chatter.js subscriptions per client)

Wire MB/s is measured only by the deflate client; – means unmeasured. Historical non-deflate captures stored 0 instead; that does not mean zero network traffic.

| Metric | Elixir baseline | Elixir candidate | Candidate advantage over baseline |
|---|---|---|---|
| 100 clients: subscribed | 100 [100–100] | 100 [100–100] | 1.0× |
| 100 clients: connect+subscribe all (s) | 0.13 [0.11–0.16] | 0.15 [0.14–0.17] | 0.8× |
| 100 clients: paced post→one client p50 ms | 10.7 [10.6–12.0] | 8.73 [8.49–9.46] | 1.2× |
| 100 clients: paced post→all clients p50 ms | 11.5 [11.4–12.7] | 9.54 [9.13–10.46] | 1.2× |
| 100 clients: paced post→all clients p99 ms | 28.4 [19.6–29.9] | 12.8 [11.2–25.3] | 2.2× |
| 100 clients: paced POST attempts | 30.0 [30.0–30.0] | 30.0 [30.0–30.0] | 1.0× |
| 100 clients: paced successful POSTs | 30.0 [30.0–30.0] | 30.0 [30.0–30.0] | 1.0× |
| 100 clients: paced POST errors | 0.00 [0.00–0.00] | 0.00 [0.00–0.00] | – |
| 100 clients: paced completed fanouts | 30.0 [30.0–30.0] | 30.0 [30.0–30.0] | 1.0× |
| 100 clients: max sustained msgs/s (delivered to all) | 135 [133–141] | 176 [169–184] | 1.3× |
| 100 clients: deliveries/s (client×message) | 13,504 [13,284–14,095] | 17,564 [16,915–18,410] | 1.3× |
| 100 clients: saturated post→all p50 ms | 24.7 [24.0–25.5] | 22.2 [21.2–23.2] | 1.1× |
| 100 clients: saturated POST p50 ms | 28.8 [27.8–29.6] | 22.4 [21.2–23.3] | 1.3× |
| 100 clients: saturated POST attempts | 2,028 [1,996–2,117] | 2,637 [2,540–2,764] | 1.3× |
| 100 clients: saturated successful POSTs | 2,028 [1,996–2,117] | 2,637 [2,540–2,764] | 1.3× |
| 100 clients: saturated POST errors | 0.00 [0.00–0.00] | 0.00 [0.00–0.00] | – |
| 100 clients: completed fanouts | 2,028 [1,996–2,117] | 2,637 [2,540–2,764] | 1.3× |
| 100 clients: saturated POSTs/s | 135 [133–141] | 176 [169–184] | 1.3× |
| 100 clients: wire MB/s | – | – | – |
| 100 clients: drain (s) | 0.00 [0.00–0.00] | 0.00 [0.00–0.00] | – |
| 500 clients: subscribed | 500 [500–500] | 500 [500–500] | 1.0× |
| 500 clients: connect+subscribe all (s) | 0.55 [0.52–0.58] | 0.57 [0.51–0.62] | 0.9× |
| 500 clients: paced post→one client p50 ms | 16.0 [14.9–16.3] | 14.0 [13.0–14.3] | 1.1× |
| 500 clients: paced post→all clients p50 ms | 20.8 [20.2–22.1] | 19.0 [17.2–20.3] | 1.1× |
| 500 clients: paced post→all clients p99 ms | 32.6 [29.0–35.2] | 29.0 [22.7–39.7] | 1.1× |
| 500 clients: paced POST attempts | 30.0 [30.0–30.0] | 30.0 [30.0–30.0] | 1.0× |
| 500 clients: paced successful POSTs | 30.0 [30.0–30.0] | 30.0 [30.0–30.0] | 1.0× |
| 500 clients: paced POST errors | 0.00 [0.00–0.00] | 0.00 [0.00–0.00] | – |
| 500 clients: paced completed fanouts | 30.0 [30.0–30.0] | 30.0 [30.0–30.0] | 1.0× |
| 500 clients: max sustained msgs/s (delivered to all) | 58.4 [55.7–59.4] | 67.7 [65.5–71.0] | 1.2× |
| 500 clients: deliveries/s (client×message) | 29,180 [27,848–29,700] | 33,858 [32,753–35,515] | 1.2× |
| 500 clients: saturated post→all p50 ms | 60.8 [59.8–61.8] | 59.8 [57.4–60.3] | 1.0× |
| 500 clients: saturated POST p50 ms | 68.1 [65.8–70.4] | 59.1 [55.3–60.3] | 1.2× |
| 500 clients: saturated POST attempts | 879 [838–893] | 1,020 [986–1,069] | 1.2× |
| 500 clients: saturated successful POSTs | 879 [838–893] | 1,020 [986–1,069] | 1.2× |
| 500 clients: saturated POST errors | 0.00 [0.00–0.00] | 0.00 [0.00–0.00] | – |
| 500 clients: completed fanouts | 879 [838–893] | 1,020 [986–1,069] | 1.2× |
| 500 clients: saturated POSTs/s | 58.4 [55.7–59.4] | 67.8 [65.5–71.0] | 1.2× |
| 500 clients: wire MB/s | – | – | – |
| 500 clients: drain (s) | 0.00 [0.00–0.00] | 0.00 [0.00–0.01] | – |
| 1000 clients: subscribed | 1,000 [1,000–1,000] | 1,000 [1,000–1,000] | 1.0× |
| 1000 clients: connect+subscribe all (s) | 0.99 [0.94–1.07] | 1.08 [1.04–1.25] | 0.9× |
| 1000 clients: paced post→one client p50 ms | 20.2 [19.8–22.0] | 18.6 [17.9–21.2] | 1.1× |
| 1000 clients: paced post→all clients p50 ms | 29.9 [29.0–34.3] | 29.5 [28.9–32.5] | 1.0× |
| 1000 clients: paced post→all clients p99 ms | 46.0 [40.4–48.5] | 41.5 [37.9–55.7] | 1.1× |
| 1000 clients: paced POST attempts | 30.0 [30.0–30.0] | 30.0 [30.0–30.0] | 1.0× |
| 1000 clients: paced successful POSTs | 30.0 [30.0–30.0] | 30.0 [30.0–30.0] | 1.0× |
| 1000 clients: paced POST errors | 0.00 [0.00–0.00] | 0.00 [0.00–0.00] | – |
| 1000 clients: paced completed fanouts | 30.0 [30.0–30.0] | 30.0 [30.0–30.0] | 1.0× |
| 1000 clients: max sustained msgs/s (delivered to all) | 34.7 [32.3–35.1] | 36.6 [35.6–40.7] | 1.1× |
| 1000 clients: deliveries/s (client×message) | 34,686 [32,303–35,052] | 36,646 [35,559–40,660] | 1.1× |
| 1000 clients: saturated post→all p50 ms | 107 [106–115] | 109 [101–112] | 1.0× |
| 1000 clients: saturated POST p50 ms | 115 [114–123] | 108 [98–111] | 1.1× |
| 1000 clients: saturated POST attempts | 524 [487–529] | 553 [536–615] | 1.1× |
| 1000 clients: saturated successful POSTs | 524 [487–529] | 553 [536–615] | 1.1× |
| 1000 clients: saturated POST errors | 0.00 [0.00–0.00] | 0.00 [0.00–0.00] | – |
| 1000 clients: completed fanouts | 524 [487–529] | 553 [536–615] | 1.1× |
| 1000 clients: saturated POSTs/s | 34.7 [32.3–35.1] | 36.6 [35.6–40.7] | 1.1× |
| 1000 clients: wire MB/s | – | – | – |
| 1000 clients: drain (s) | 0.00 [0.00–0.04] | 0.00 [0.00–0.00] | – |

### Upload + thumbnail (black_hole.jpg, 505 KB)

| Metric | Elixir baseline | Elixir candidate | Candidate advantage over baseline |
|---|---|---|---|
| POST with attachment (ms) | 228 [224–232] | 210 [196–224] | 1.1× |
| then GET thumb → 200 (ms) | 0.90 [0.80–1.00] | 0.80 [0.80–0.90] | 1.1× |
| POST → thumbnail served (ms) | 231 [224–233] | 211 [197–225] | 1.1× |
| completed uploads | 5.00 [5.00–5.00] | 5.00 [5.00–5.00] | 1.0× |
| thumbnail bytes (median) | 630 [630–630] | 630 [630–630] | 1.0× |

### Final Redis/Resque audit

| Metric | Elixir baseline | Elixir candidate | Candidate advantage over baseline |
|---|---|---|---|
| queued jobs | 0.00 [0.00–0.00] | 0.00 [0.00–0.00] | – |
| active jobs | 0.00 [0.00–0.00] | 0.00 [0.00–0.00] | – |
| failed jobs | 0.00 [0.00–0.00] | 0.00 [0.00–0.00] | – |

### Memory during cable fan-out, by process (MiB, peak within the phase)

App process: Elixir BEAM; Rails Puma master/workers when included;
Go/Rust's integrated campfire processes. Serving totals include native helpers, Redis and Thruster.
PSS apportions shared pages; RssAnon counts them in each process.

| Metric | Elixir baseline | Elixir candidate | Candidate advantage over baseline |
|---|---|---|---|
| 100 clients, all subscribed, idle: app process Pss | 220 [215–231] | 224 [221–228] | 1.0× |
| 100 clients, all subscribed, idle: app process RssAnon | 176 [170–186] | 182 [178–186] | 1.0× |
| 100 clients, all subscribed, idle: serving processes Pss | 267 [265–281] | 256 [251–259] | 1.0× |
| 100 clients, all subscribed, idle: whole container Pss | 269 [266–283] | 256 [252–260] | 1.0× |
| 100 clients, saturated fan-out: app process Pss | 270 [251–286] | 298 [289–304] | 0.9× |
| 100 clients, saturated fan-out: app process RssAnon | 224 [206–240] | 255 [246–261] | 0.9× |
| 100 clients, saturated fan-out: serving processes Pss | 332 [316–352] | 340 [330–346] | 1.0× |
| 100 clients, saturated fan-out: whole container Pss | 333 [316–353] | 340 [330–346] | 1.0× |
| 500 clients, all subscribed, idle: app process Pss | 278 [266–286] | 300 [296–300] | 0.9× |
| 500 clients, all subscribed, idle: app process RssAnon | 233 [221–240] | 257 [254–258] | 0.9× |
| 500 clients, all subscribed, idle: serving processes Pss | 356 [348–369] | 360 [356–360] | 1.0× |
| 500 clients, all subscribed, idle: whole container Pss | 357 [349–370] | 361 [358–362] | 1.0× |
| 500 clients, saturated fan-out: app process Pss | 327 [319–335] | 361 [358–366] | 0.9× |
| 500 clients, saturated fan-out: app process RssAnon | 282 [273–289] | 319 [315–324] | 0.9× |
| 500 clients, saturated fan-out: serving processes Pss | 435 [423–446] | 451 [447–458] | 1.0× |
| 500 clients, saturated fan-out: whole container Pss | 437 [424–447] | 451 [448–458] | 1.0× |
| 1000 clients, all subscribed, idle: app process Pss | 348 [335–358] | 366 [362–377] | 1.0× |
| 1000 clients, all subscribed, idle: app process RssAnon | 303 [290–313] | 324 [320–335] | 0.9× |
| 1000 clients, all subscribed, idle: serving processes Pss | 484 [474–495] | 477 [465–499] | 1.0× |
| 1000 clients, all subscribed, idle: whole container Pss | 486 [476–497] | 479 [466–500] | 1.0× |
| 1000 clients, saturated fan-out: app process Pss | 385 [374–407] | 428 [423–434] | 0.9× |
| 1000 clients, saturated fan-out: app process RssAnon | 339 [329–361] | 386 [381–392] | 0.9× |
| 1000 clients, saturated fan-out: serving processes Pss | 539 [526–563] | 558 [550–570] | 1.0× |
| 1000 clients, saturated fan-out: whole container Pss | 539 [527–564] | 558 [551–570] | 1.0× |
