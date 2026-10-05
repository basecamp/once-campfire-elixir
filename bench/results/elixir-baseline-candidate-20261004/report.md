```
date: 2026-10-04T21:59:40+00:00
host: 6.1.158+, Intel(R) Xeon(R) Processor @ 2.60GHz, 2 threads, 3GB
server cpus: 0 (nproc 1); loadgen cpus: 1; network: host
env: WEB_CONCURRENCY=1 JOB_CONCURRENCY=1 RAILS_MAX_THREADS=5
seed sha256: bda9a5cd61d78d53f377cf07ee9268741caebc19b94a6efe782cafe827efc8db  /home/user/workspace/repo/parity/.seed/default/db/production.sqlite3
seed tree sha256: c58532c20db34e3df10e5c39969cd328f4bd815e5beb1dabfdfa2af5805e29c5  -
loadgen sha256: a611112f1cf606deeb511bd7e955a57b5fa28bacc09bffdd88dd6064b0b8a488  /home/user/workspace/repo/target/bench/release/loadgen
loadgen build image: rust@sha256:4cd829461bd5c4d511c32e269da9cb8929223b666519d8004e35fc8d1d771ab7
elixir source digest: 3900b84be9563488528fc030b1e8b96fe702d1e31c8851342eb3a1a0ab6a936b
rust extra env:
workload: suites=http cable upload HTTP_SECS=8 HTTP_CONCS=1 16 64 CABLE_CLIENTS=100 500 CABLE_TPUT_SECS=15 CABLE_POSTERS=4 UPLOAD_REPS=5 REPS=3
quiet wait: LOAD_MAX=1.5 LOAD_WAIT_SECS=900
user agent: (none)
baseline image: campfire-elixir:baseline-b6b82e5 sha256:52e35947d029026caff725621e4a11edfc5dccce5530f409ab25b9e0ed09ba24 2026-10-04T21:45:00.310444525Z unpacked_bytes=2582410724
candidate image: campfire-elixir:candidate-01a1675 sha256:6118496bddaf253301a8caf9fa18d1f56cf442a70141f9095a2171cdc35a641c 2026-10-04T21:22:00.50099719Z unpacked_bytes=2582425025
baseline source: b6b82e50a653c4060136bb04e805eb78fd76ba10
candidate source: 01a16759408898313538775543078f42646b830e
```

Reps: baseline 3, candidate 3. Cells: median [min–max].

### Startup and memory

| Metric | Elixir baseline | Elixir candidate | Candidate advantage over baseline |
|---|---|---|---|
| cold start: docker run → /up 200 (ms) | 1,865 [1,864–2,002] | 1,925 [1,867–2,192] | 1.0× |
| idle memory.current (MiB) | 126 [125–127] | 127 [126–128] | 1.0× |
| idle anon (MiB) | 93.0 [92.0–93.0] | 94.0 [94.0–94.0] | 1.0× |
| peak memory.current under load (MiB) | 312 [302–314] | 323 [317–327] | 1.0× |
| peak anon under load (MiB) | 261 [260–269] | 279 [274–281] | 0.9× |

### HTTP (signed in as david; keep-alive; c = concurrent connections)

| Metric | Elixir baseline | Elixir candidate | Candidate advantage over baseline |
|---|---|---|---|
| room_show c=1 req/s | 65.6 [63.6–69.9] | 62.8 [61.5–64.5] | 1.0× |
| room_show c=1 p50 ms | 14.7 [14.1–15.0] | 15.2 [15.1–15.3] | 1.0× |
| room_show c=1 p99 ms | 23.4 [19.0–25.2] | 24.7 [21.5–27.6] | 0.9× |
| room_show c=1 CPU µs/success | 14,861 [13,989–15,399] | 15,562 [15,165–15,929] | 1.0× |
| room_show c=16 req/s | 63.6 [58.7–66.4] | 56.4 [53.9–62.1] | 0.9× |
| room_show c=16 p50 ms | 242 [241–265] | 271 [256–285] | 0.9× |
| room_show c=16 p99 ms | 375 [277–381] | 407 [297–452] | 0.9× |
| room_show c=16 CPU µs/success | 15,406 [14,985–16,960] | 17,349 [16,057–18,399] | 0.9× |
| room_show c=64 req/s | 75.5 [73.4–77.4] | 70.3 [70.3–70.6] | 0.9× |
| room_show c=64 p50 ms | 821 [808–846] | 877 [877–889] | 0.9× |
| room_show c=64 p99 ms | 983 [909–1,020] | 1,025 [984–1,053] | 1.0× |
| room_show c=64 CPU µs/success | 13,169 [12,825–13,454] | 14,022 [13,964–14,137] | 0.9× |
| messages_page c=1 req/s | 88.5 [84.0–88.9] | 83.8 [80.3–89.6] | 0.9× |
| messages_page c=1 p50 ms | 11.0 [11.0–11.4] | 11.7 [10.9–12.0] | 0.9× |
| messages_page c=1 p99 ms | 15.8 [15.7–19.3] | 16.3 [14.6–18.1] | 1.0× |
| messages_page c=1 CPU µs/success | 11,014 [11,006–11,599] | 11,646 [10,922–12,117] | 0.9× |
| messages_page c=16 req/s | 74.5 [70.4–79.8] | 76.2 [74.7–80.0] | 1.0× |
| messages_page c=16 p50 ms | 210 [200–225] | 203 [198–209] | 1.0× |
| messages_page c=16 p99 ms | 283 [238–314] | 256 [232–414] | 1.1× |
| messages_page c=16 CPU µs/success | 13,169 [12,493–14,088] | 13,027 [12,459–13,046] | 1.0× |
| messages_page c=64 req/s | 88.6 [77.2–91.6] | 87.6 [84.3–89.9] | 1.0× |
| messages_page c=64 p50 ms | 723 [700–814] | 700 [700–706] | 1.0× |
| messages_page c=64 p99 ms | 836 [825–964] | 879 [794–1,070] | 1.0× |
| messages_page c=64 CPU µs/success | 11,247 [10,872–12,708] | 11,327 [11,098–11,801] | 1.0× |
| sidebar c=1 req/s | 163 [159–174] | 140 [133–147] | 0.9× |
| sidebar c=1 p50 ms | 5.86 [5.54–5.87] | 6.88 [6.60–7.12] | 0.9× |
| sidebar c=1 p99 ms | 10.2 [8.6–11.8] | 11.1 [10.9–13.6] | 0.9× |
| sidebar c=1 CPU µs/success | 5,956 [5,603–6,073] | 6,962 [6,614–7,291] | 0.9× |
| sidebar c=16 req/s | 167 [157–171] | 136 [131–138] | 0.8× |
| sidebar c=16 p50 ms | 91.8 [91.6–99.9] | 116 [114–117] | 0.8× |
| sidebar c=16 p99 ms | 145 [128–207] | 153 [142–186] | 0.9× |
| sidebar c=16 CPU µs/success | 5,962 [5,827–6,332] | 7,340 [7,249–7,613] | 0.8× |
| sidebar c=64 req/s | 176 [174–178] | 132 [130–139] | 0.7× |
| sidebar c=64 p50 ms | 354 [351–355] | 483 [451–485] | 0.7× |
| sidebar c=64 p99 ms | 471 [397–498] | 600 [574–616] | 0.8× |
| sidebar c=64 CPU µs/success | 5,670 [5,566–5,715] | 7,565 [7,063–7,643] | 0.7× |
| search c=1 req/s | 122 [117–123] | 110 [107–110] | 0.9× |
| search c=1 p50 ms | 8.02 [7.89–8.29] | 8.68 [8.60–9.10] | 0.9× |
| search c=1 p99 ms | 12.8 [11.4–13.0] | 14.6 [13.9–19.5] | 0.9× |
| search c=1 CPU µs/success | 7,992 [7,948–8,232] | 8,813 [8,717–9,060] | 0.9× |
| search c=16 req/s | 120 [119–129] | 113 [108–114] | 0.9× |
| search c=16 p50 ms | 131 [122–133] | 139 [138–145] | 0.9× |
| search c=16 p99 ms | 168 [147–180] | 175 [171–205] | 1.0× |
| search c=16 CPU µs/success | 8,316 [7,731–8,394] | 8,796 [8,724–9,244] | 0.9× |
| search c=64 req/s | 133 [131–135] | 119 [118–125] | 0.9× |
| search c=64 p50 ms | 469 [453–482] | 519 [502–530] | 0.9× |
| search c=64 p99 ms | 558 [550–738] | 621 [614–725] | 0.9× |
| search c=64 CPU µs/success | 7,483 [7,216–7,542] | 8,196 [7,945–8,409] | 0.9× |
| avatar c=1 req/s | 3,606 [3,312–3,636] | 3,528 [3,368–3,596] | 1.0× |
| avatar c=1 p50 ms | 0.24 [0.24–0.26] | 0.25 [0.24–0.25] | 1.0× |
| avatar c=1 p99 ms | 0.77 [0.71–0.87] | 0.74 [0.71–0.91] | 1.0× |
| avatar c=1 CPU µs/success | 186 [174–186] | 191 [179–196] | 1.0× |
| avatar c=16 req/s | 11,315 [10,313–11,689] | 12,116 [10,353–12,460] | 1.1× |
| avatar c=16 p50 ms | 1.21 [1.21–1.27] | 1.15 [1.12–1.32] | 1.1× |
| avatar c=16 p99 ms | 5.16 [4.78–6.63] | 4.71 [4.69–5.44] | 1.1× |
| avatar c=16 CPU µs/success | 80.0 [78.7–84.2] | 75.2 [73.6–87.6] | 1.1× |
| avatar c=64 req/s | 9,708 [9,023–10,415] | 9,922 [9,593–10,274] | 1.0× |
| avatar c=64 p50 ms | 6.41 [6.00–6.76] | 6.22 [6.13–6.42] | 1.0× |
| avatar c=64 p99 ms | 18.1 [16.3–20.2] | 18.5 [15.6–18.6] | 1.0× |
| avatar c=64 CPU µs/success | 96.3 [89.0–102.7] | 93.1 [92.8–97.2] | 1.0× |
| static_css c=1 req/s | 3,717 [3,360–3,737] | 3,535 [3,313–3,879] | 1.0× |
| static_css c=1 p50 ms | 0.24 [0.23–0.25] | 0.24 [0.23–0.25] | 1.0× |
| static_css c=1 p99 ms | 0.78 [0.74–0.90] | 0.83 [0.70–0.96] | 0.9× |
| static_css c=1 CPU µs/success | 175 [160–188] | 182 [164–187] | 1.0× |
| static_css c=16 req/s | 12,182 [11,537–13,882] | 12,614 [12,343–12,933] | 1.0× |
| static_css c=16 p50 ms | 1.10 [0.99–1.17] | 1.08 [1.04–1.11] | 1.0× |
| static_css c=16 p99 ms | 5.25 [4.19–5.51] | 4.88 [4.22–5.61] | 1.1× |
| static_css c=16 CPU µs/success | 71.8 [64.5–77.8] | 71.2 [69.1–73.1] | 1.0× |
| static_css c=64 req/s | 11,301 [10,241–12,592] | 12,264 [11,425–12,265] | 1.1× |
| static_css c=64 p50 ms | 5.38 [4.87–5.89] | 5.03 [4.79–5.37] | 1.1× |
| static_css c=64 p99 ms | 16.5 [15.0–19.1] | 15.7 [14.6–18.7] | 1.1× |
| static_css c=64 CPU µs/success | 81.7 [72.7–88.9] | 75.8 [72.6–82.0] | 1.1× |
| up c=1 req/s | 929 [925–947] | 885 [857–956] | 1.0× |
| up c=1 p50 ms | 1.00 [0.99–1.00] | 1.04 [0.99–1.07] | 1.0× |
| up c=1 p99 ms | 2.10 [1.86–2.21] | 2.45 [1.99–2.46] | 0.9× |
| up c=1 CPU µs/success | 969 [955–975] | 1,009 [943–1,044] | 1.0× |
| up c=16 req/s | 966 [885–1,000] | 961 [896–1,007] | 1.0× |
| up c=16 p50 ms | 15.8 [15.2–16.2] | 15.6 [15.1–16.2] | 1.0× |
| up c=16 p99 ms | 31.8 [29.2–45.6] | 33.4 [28.3–41.2] | 1.0× |
| up c=16 CPU µs/success | 1,027 [995–1,084] | 1,032 [987–1,070] | 1.0× |
| up c=64 req/s | 884 [862–903] | 913 [798–937] | 1.0× |
| up c=64 p50 ms | 66.6 [66.6–67.6] | 65.4 [64.7–74.9] | 1.0× |
| up c=64 p99 ms | 128 [127–142] | 128 [119–142] | 1.0× |
| up c=64 CPU µs/success | 1,124 [1,083–1,150] | 1,081 [1,055–1,237] | 1.0× |
| post_message c=1 req/s | 86.1 [86.0–87.4] | 59.5 [55.5–61.1] | 0.7× |
| post_message c=1 p50 ms | 11.8 [11.8–12.0] | 20.0 [19.7–21.2] | 0.6× |
| post_message c=1 p99 ms | 20.8 [18.2–22.4] | 33.1 [29.4–33.7] | 0.6× |
| post_message c=1 CPU µs/success | 11,363 [11,259–11,371] | 16,614 [16,111–17,745] | 0.7× |
| post_message c=16 req/s | 107 [106–118] | 78.7 [76.8–80.1] | 0.7× |
| post_message c=16 p50 ms | 141 [134–145] | 205 [201–206] | 0.7× |
| post_message c=16 p99 ms | 230 [151–239] | 246 [225–256] | 0.9× |
| post_message c=16 CPU µs/success | 9,181 [8,334–9,227] | 12,638 [12,417–12,955] | 0.7× |
| post_message c=64 req/s | 120 [118–125] | 75.4 [73.8–87.2] | 0.6× |
| post_message c=64 p50 ms | 530 [509–537] | 827 [739–867] | 0.6× |
| post_message c=64 p99 ms | 594 [570–665] | 976 [792–1,006] | 0.6× |
| post_message c=64 CPU µs/success | 8,239 [7,925–8,381] | 13,216 [11,421–13,336] | 0.6× |

### HTTP errors / non-2xx-3xx (first rep, per app)

| Metric | Elixir baseline | Elixir candidate | Candidate advantage over baseline |
|---|---|---|---|
- baseline: none
- candidate: none

### Action Cable fan-out (one room; chatter.js subscriptions per client)

| Metric | Elixir baseline | Elixir candidate | Candidate advantage over baseline |
|---|---|---|---|
| 100 clients: subscribed | 100 [100–100] | 100 [100–100] | 1.0× |
| 100 clients: connect+subscribe all (s) | 0.43 [0.39–0.44] | 0.59 [0.50–0.61] | 0.7× |
| 100 clients: paced post→one client p50 ms | 16.2 [15.7–16.7] | 25.2 [23.5–26.5] | 0.6× |
| 100 clients: paced post→all clients p50 ms | 19.2 [19.1–19.4] | 29.3 [26.8–29.6] | 0.7× |
| 100 clients: paced post→all clients p99 ms | 33.2 [31.8–41.6] | 39.5 [34.3–106.2] | 0.8× |
| 100 clients: max sustained msgs/s (delivered to all) | 30.7 [30.6–31.0] | 24.9 [24.3–26.2] | 0.8× |
| 100 clients: deliveries/s (client×message) | 3,070 [3,061–3,098] | 2,489 [2,425–2,621] | 0.8× |
| 100 clients: saturated post→all p50 ms | 104 [103–104] | 132 [127–138] | 0.8× |
| 100 clients: saturated POST p50 ms | 128 [127–128] | 156 [150–163] | 0.8× |
| 500 clients: subscribed | 500 [500–500] | 500 [500–500] | 1.0× |
| 500 clients: connect+subscribe all (s) | 1.86 [1.85–1.87] | 2.46 [2.41–2.60] | 0.8× |
| 500 clients: paced post→one client p50 ms | 51.7 [50.9–54.5] | 52.5 [48.9–56.3] | 1.0× |
| 500 clients: paced post→all clients p50 ms | 97.9 [91.3–99.4] | 91.4 [88.6–96.3] | 1.1× |
| 500 clients: paced post→all clients p99 ms | 177 [176–187] | 137 [120–211] | 1.3× |
| 500 clients: max sustained msgs/s (delivered to all) | 9.60 [8.90–10.30] | 9.00 [9.00–9.50] | 0.9× |
| 500 clients: deliveries/s (client×message) | 4,808 [4,463–5,131] | 4,508 [4,491–4,761] | 0.9× |
| 500 clients: saturated post→all p50 ms | 336 [305–359] | 377 [360–384] | 0.9× |
| 500 clients: saturated POST p50 ms | 403 [388–418] | 433 [415–443] | 0.9× |

### Upload + thumbnail (black_hole.jpg, 505 KB)

| Metric | Elixir baseline | Elixir candidate | Candidate advantage over baseline |
|---|---|---|---|
| POST with attachment (ms) | 358 [337–363] | 343 [338–353] | 1.0× |
| then GET thumb → 200 (ms) | 0.60 [0.60–0.70] | 0.60 [0.60–0.70] | 1.0× |
| POST → thumbnail served (ms) | 358 [338–364] | 343 [339–353] | 1.0× |

### Memory during cable fan-out, by process (MiB, peak within the phase)

App process: Elixir BEAM; Rails Puma master/workers when included;
Go/Rust's integrated campfire processes. Serving totals include native helpers, Redis and Thruster.
PSS apportions shared pages; RssAnon counts them in each process.

| Metric | Elixir baseline | Elixir candidate | Candidate advantage over baseline |
|---|---|---|---|
| 100 clients, all subscribed, idle: app process Pss | 175 [175–178] | 186 [184–188] | 0.9× |
| 100 clients, all subscribed, idle: app process RssAnon | 133 [133–136] | 145 [142–147] | 0.9× |
| 100 clients, all subscribed, idle: serving processes Pss | 208 [208–210] | 212 [210–214] | 1.0× |
| 100 clients, all subscribed, idle: whole container Pss | 209 [209–212] | 214 [212–216] | 1.0× |
| 100 clients, saturated fan-out: app process Pss | 175 [175–185] | 194 [189–195] | 0.9× |
| 100 clients, saturated fan-out: app process RssAnon | 132 [132–143] | 152 [147–153] | 0.9× |
| 100 clients, saturated fan-out: serving processes Pss | 216 [216–226] | 228 [222–228] | 0.9× |
| 100 clients, saturated fan-out: whole container Pss | 217 [217–228] | 229 [223–229] | 1.0× |
| 500 clients, all subscribed, idle: app process Pss | 198 [196–208] | 223 [213–223] | 0.9× |
| 500 clients, all subscribed, idle: app process RssAnon | 156 [153–165] | 181 [171–182] | 0.9× |
| 500 clients, all subscribed, idle: serving processes Pss | 259 [256–268] | 276 [263–276] | 0.9× |
| 500 clients, all subscribed, idle: whole container Pss | 261 [257–269] | 278 [265–278] | 0.9× |
| 500 clients, saturated fan-out: app process Pss | 207 [204–210] | 222 [221–228] | 0.9× |
| 500 clients, saturated fan-out: app process RssAnon | 165 [162–168] | 181 [180–186] | 0.9× |
| 500 clients, saturated fan-out: serving processes Pss | 274 [270–276] | 280 [277–286] | 1.0× |
| 500 clients, saturated fan-out: whole container Pss | 274 [271–278] | 282 [278–288] | 1.0× |
