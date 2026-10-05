```
date: 2026-10-04T23:20:41+00:00
host: 6.1.158+, Intel(R) Xeon(R) Processor @ 2.60GHz, 2 threads, 3GB
server cpus: 0 (nproc 1); loadgen cpus: 1; network: host
env: WEB_CONCURRENCY=1 JOB_CONCURRENCY=1 RAILS_MAX_THREADS=5
seed sha256: bda9a5cd61d78d53f377cf07ee9268741caebc19b94a6efe782cafe827efc8db  /home/user/workspace/repo/parity/.seed/default/db/production.sqlite3
seed tree sha256: c58532c20db34e3df10e5c39969cd328f4bd815e5beb1dabfdfa2af5805e29c5  -
loadgen sha256: a611112f1cf606deeb511bd7e955a57b5fa28bacc09bffdd88dd6064b0b8a488  /home/user/workspace/repo/target/bench/release/loadgen
loadgen build image: rust@sha256:4cd829461bd5c4d511c32e269da9cb8929223b666519d8004e35fc8d1d771ab7
elixir source digest: 76dd233a90d7c99455301a744bc292f3fcc184a25ee75b2da21eaa1d54b15b39
rust extra env:
workload: suites=http cable upload HTTP_SECS=8 HTTP_CONCS=1 16 64 CABLE_CLIENTS=100 500 CABLE_TPUT_SECS=15 CABLE_POSTERS=4 UPLOAD_REPS=5 REPS=3
quiet wait: LOAD_MAX=1.5 LOAD_WAIT_SECS=900
user agent: (none)
baseline image: campfire-elixir:baseline-b6b82e5 sha256:52e35947d029026caff725621e4a11edfc5dccce5530f409ab25b9e0ed09ba24 2026-10-04T21:45:00.310444525Z unpacked_bytes=2582410724
candidate image: campfire-elixir:candidate-a6225d7 sha256:58e9da531de4c76580b335484046945abbad1302dcdd21f3c58204e670fcbc9a 2026-10-04T22:37:50.82790572Z unpacked_bytes=2582425018
baseline source: b6b82e50a653c4060136bb04e805eb78fd76ba10
candidate source: a6225d7e1c006d90950c91ddd2b15622d5f87df9
```

Reps: baseline 3, candidate 3. Cells: median [min–max].

### Startup and memory

| Metric | Elixir baseline | Elixir candidate | Candidate advantage over baseline |
|---|---|---|---|
| cold start: docker run → /up 200 (ms) | 2,447 [1,874–2,503] | 2,216 [1,963–2,232] | 1.1× |
| idle memory.current (MiB) | 126 [125–157] | 126 [126–126] | 1.0× |
| idle anon (MiB) | 93.0 [93.0–94.0] | 94.0 [93.0–94.0] | 1.0× |
| peak memory.current under load (MiB) | 321 [304–347] | 330 [328–331] | 1.0× |
| peak anon under load (MiB) | 269 [259–277] | 285 [283–288] | 0.9× |

### HTTP (signed in as david; keep-alive; c = concurrent connections)

| Metric | Elixir baseline | Elixir candidate | Candidate advantage over baseline |
|---|---|---|---|
| room_show c=1 req/s | 60.5 [59.0–69.6] | 63.6 [53.2–63.6] | 1.1× |
| room_show c=1 p50 ms | 15.9 [14.1–16.3] | 15.3 [14.9–15.8] | 1.0× |
| room_show c=1 p99 ms | 22.8 [19.2–23.3] | 35.5 [21.4–55.1] | 0.6× |
| room_show c=1 CPU µs/success | 16,157 [14,102–16,577] | 15,389 [14,613–16,745] | 1.0× |
| room_show c=16 req/s | 54.8 [54.6–57.6] | 57.5 [55.2–59.9] | 1.0× |
| room_show c=16 p50 ms | 281 [278–291] | 275 [264–288] | 1.0× |
| room_show c=16 p99 ms | 348 [334–488] | 358 [329–373] | 1.0× |
| room_show c=16 CPU µs/success | 17,508 [17,313–18,135] | 17,282 [16,579–18,033] | 1.0× |
| room_show c=64 req/s | 70.3 [69.7–71.2] | 63.8 [60.2–64.2] | 0.9× |
| room_show c=64 p50 ms | 889 [873–891] | 975 [952–1,016] | 0.9× |
| room_show c=64 p99 ms | 1,000 [995–1,056] | 1,200 [1,172–1,275] | 0.8× |
| room_show c=64 CPU µs/success | 14,111 [13,907–14,177] | 15,518 [14,822–16,434] | 0.9× |
| messages_page c=1 req/s | 83.5 [83.3–86.7] | 83.9 [80.0–86.4] | 1.0× |
| messages_page c=1 p50 ms | 11.6 [11.2–11.7] | 11.7 [11.3–12.1] | 1.0× |
| messages_page c=1 p99 ms | 17.3 [17.2–17.3] | 17.2 [15.8–19.2] | 1.0× |
| messages_page c=1 CPU µs/success | 11,694 [11,246–11,710] | 11,612 [11,306–12,058] | 1.0× |
| messages_page c=16 req/s | 74.1 [71.7–79.1] | 75.1 [73.6–78.1] | 1.0× |
| messages_page c=16 p50 ms | 215 [200–221] | 214 [205–218] | 1.0× |
| messages_page c=16 p99 ms | 263 [259–286] | 248 [234–273] | 1.1× |
| messages_page c=16 CPU µs/success | 13,400 [12,571–13,890] | 13,283 [12,769–13,540] | 1.0× |
| messages_page c=64 req/s | 80.4 [78.5–84.7] | 82.0 [81.7–82.3] | 1.0× |
| messages_page c=64 p50 ms | 750 [741–754] | 763 [756–764] | 1.0× |
| messages_page c=64 p99 ms | 1,153 [891–1,212] | 968 [952–995] | 1.2× |
| messages_page c=64 CPU µs/success | 11,979 [11,734–12,186] | 12,130 [12,096–12,143] | 1.0× |
| sidebar c=1 req/s | 145 [139–155] | 142 [136–144] | 1.0× |
| sidebar c=1 p50 ms | 6.59 [5.98–6.65] | 6.67 [6.66–6.80] | 1.0× |
| sidebar c=1 p99 ms | 13.3 [11.3–15.5] | 12.4 [11.3–13.6] | 1.1× |
| sidebar c=1 CPU µs/success | 6,626 [6,189–6,883] | 6,762 [6,667–7,057] | 1.0× |
| sidebar c=16 req/s | 149 [146–160] | 152 [130–153] | 1.0× |
| sidebar c=16 p50 ms | 105 [98–106] | 102 [98–115] | 1.0× |
| sidebar c=16 p99 ms | 151 [136–178] | 220 [145–298] | 0.7× |
| sidebar c=16 CPU µs/success | 6,695 [6,236–6,825] | 6,522 [6,369–7,393] | 1.0× |
| sidebar c=64 req/s | 172 [164–176] | 164 [160–176] | 1.0× |
| sidebar c=64 p50 ms | 358 [354–384] | 376 [355–394] | 1.0× |
| sidebar c=64 p99 ms | 459 [453–465] | 477 [441–490] | 1.0× |
| sidebar c=64 CPU µs/success | 5,779 [5,650–6,040] | 5,987 [5,644–6,249] | 1.0× |
| search c=1 req/s | 114 [109–121] | 103 [102–116] | 0.9× |
| search c=1 p50 ms | 8.54 [7.90–8.94] | 9.18 [8.25–9.23] | 0.9× |
| search c=1 p99 ms | 13.0 [11.8–13.4] | 15.1 [13.6–22.9] | 0.9× |
| search c=1 CPU µs/success | 8,512 [8,073–8,881] | 9,092 [8,337–9,347] | 0.9× |
| search c=16 req/s | 115 [104–116] | 115 [110–126] | 1.0× |
| search c=16 p50 ms | 138 [136–151] | 134 [126–145] | 1.0× |
| search c=16 p99 ms | 216 [167–221] | 182 [157–182] | 1.2× |
| search c=16 CPU µs/success | 8,646 [8,565–9,602] | 8,645 [7,890–9,053] | 1.0× |
| search c=64 req/s | 126 [124–133] | 128 [118–137] | 1.0× |
| search c=64 p50 ms | 495 [468–499] | 487 [461–540] | 1.0× |
| search c=64 p99 ms | 595 [568–626] | 601 [540–682] | 1.0× |
| search c=64 CPU µs/success | 7,908 [7,495–8,008] | 7,756 [7,257–8,417] | 1.0× |
| avatar c=1 req/s | 3,051 [2,761–3,424] | 3,268 [2,255–3,316] | 1.1× |
| avatar c=1 p50 ms | 0.26 [0.25–0.29] | 0.26 [0.26–0.37] | 1.0× |
| avatar c=1 p99 ms | 1.91 [0.81–1.99] | 0.90 [0.85–1.70] | 2.1× |
| avatar c=1 CPU µs/success | 200 [182–218] | 198 [191–278] | 1.0× |
| avatar c=16 req/s | 10,216 [9,690–10,703] | 9,168 [7,853–9,567] | 0.9× |
| avatar c=16 p50 ms | 1.35 [1.27–1.36] | 1.47 [1.43–1.66] | 0.9× |
| avatar c=16 p99 ms | 5.65 [5.54–6.29] | 6.48 [6.00–7.66] | 0.9× |
| avatar c=16 CPU µs/success | 88.6 [82.8–89.9] | 96.0 [94.2–112.4] | 0.9× |
| avatar c=64 req/s | 9,231 [8,838–9,425] | 9,780 [8,365–9,781] | 1.1× |
| avatar c=64 p50 ms | 6.80 [6.43–6.83] | 6.39 [6.37–7.15] | 1.1× |
| avatar c=64 p99 ms | 18.5 [17.0–21.0] | 17.2 [16.7–22.1] | 1.1× |
| avatar c=64 CPU µs/success | 101 [99–104] | 96.7 [95.6–109.7] | 1.0× |
| static_css c=1 req/s | 3,499 [3,166–3,562] | 3,186 [3,060–3,863] | 0.9× |
| static_css c=1 p50 ms | 0.25 [0.24–0.27] | 0.25 [0.23–0.25] | 1.0× |
| static_css c=1 p99 ms | 0.82 [0.81–0.88] | 1.78 [0.69–1.98] | 0.5× |
| static_css c=1 CPU µs/success | 184 [181–196] | 180 [161–195] | 1.0× |
| static_css c=16 req/s | 11,532 [11,383–12,328] | 12,209 [10,675–12,229] | 1.1× |
| static_css c=16 p50 ms | 1.10 [1.09–1.16] | 1.12 [1.10–1.19] | 1.0× |
| static_css c=16 p99 ms | 5.25 [5.14–7.25] | 4.88 [4.65–6.67] | 1.1× |
| static_css c=16 CPU µs/success | 74.1 [73.0–78.2] | 73.9 [73.4–80.3] | 1.0× |
| static_css c=64 req/s | 10,675 [9,913–11,974] | 10,745 [10,046–11,708] | 1.0× |
| static_css c=64 p50 ms | 5.58 [5.08–5.98] | 5.67 [5.33–5.96] | 1.0× |
| static_css c=64 p99 ms | 18.1 [15.8–19.5] | 16.9 [14.7–19.6] | 1.1× |
| static_css c=64 CPU µs/success | 86.4 [76.0–91.6] | 85.6 [79.6–89.1] | 1.0× |
| up c=1 req/s | 874 [782–939] | 859 [822–866] | 1.0× |
| up c=1 p50 ms | 1.04 [1.00–1.15] | 1.05 [1.05–1.10] | 1.0× |
| up c=1 p99 ms | 2.67 [2.06–2.73] | 2.72 [2.46–2.96] | 1.0× |
| up c=1 CPU µs/success | 1,018 [954–1,142] | 1,027 [1,022–1,067] | 1.0× |
| up c=16 req/s | 862 [755–974] | 915 [892–982] | 1.1× |
| up c=16 p50 ms | 17.8 [15.6–18.2] | 16.6 [15.6–16.8] | 1.1× |
| up c=16 p99 ms | 34.5 [28.9–50.4] | 31.6 [30.1–34.1] | 1.1× |
| up c=16 CPU µs/success | 1,150 [1,019–1,237] | 1,084 [1,011–1,107] | 1.1× |
| up c=64 req/s | 822 [742–844] | 802 [793–802] | 1.0× |
| up c=64 p50 ms | 71.4 [70.9–76.5] | 72.8 [72.8–74.2] | 1.0× |
| up c=64 p99 ms | 141 [140–249] | 143 [143–144] | 1.0× |
| up c=64 CPU µs/success | 1,208 [1,174–1,272] | 1,232 [1,220–1,245] | 1.0× |
| post_message c=1 req/s | 81.4 [74.7–85.7] | 84.7 [83.6–90.9] | 1.0× |
| post_message c=1 p50 ms | 12.3 [11.8–13.4] | 11.7 [11.6–12.4] | 1.0× |
| post_message c=1 p99 ms | 23.6 [20.5–24.9] | 21.8 [18.5–22.2] | 1.1× |
| post_message c=1 CPU µs/success | 11,933 [11,362–12,999] | 11,483 [10,787–11,709] | 1.0× |
| post_message c=16 req/s | 104 [99–109] | 119 [118–131] | 1.2× |
| post_message c=16 p50 ms | 153 [144–161] | 128 [120–128] | 1.2× |
| post_message c=16 p99 ms | 196 [177–214] | 280 [166–296] | 0.7× |
| post_message c=16 CPU µs/success | 9,522 [9,064–9,949] | 7,946 [7,487–8,030] | 1.2× |
| post_message c=64 req/s | 109 [106–114] | 134 [134–147] | 1.2× |
| post_message c=64 p50 ms | 579 [544–596] | 460 [428–473] | 1.3× |
| post_message c=64 p99 ms | 742 [718–758] | 552 [514–561] | 1.3× |
| post_message c=64 CPU µs/success | 9,047 [8,684–9,312] | 7,317 [6,697–7,333] | 1.2× |

### HTTP errors / non-2xx-3xx (first rep, per app)

| Metric | Elixir baseline | Elixir candidate | Candidate advantage over baseline |
|---|---|---|---|
- baseline: none
- candidate: none

### Action Cable fan-out (one room; chatter.js subscriptions per client)

| Metric | Elixir baseline | Elixir candidate | Candidate advantage over baseline |
|---|---|---|---|
| 100 clients: subscribed | 100 [100–100] | 100 [100–100] | 1.0× |
| 100 clients: connect+subscribe all (s) | 0.40 [0.37–0.41] | 0.46 [0.42–0.47] | 0.9× |
| 100 clients: paced post→one client p50 ms | 18.6 [16.5–20.9] | 17.6 [15.4–18.9] | 1.1× |
| 100 clients: paced post→all clients p50 ms | 22.9 [19.9–25.4] | 21.3 [19.4–22.9] | 1.1× |
| 100 clients: paced post→all clients p99 ms | 37.5 [29.3–85.2] | 52.6 [36.9–101.1] | 0.7× |
| 100 clients: max sustained msgs/s (delivered to all) | 28.0 [27.4–29.0] | 33.6 [31.2–34.1] | 1.2× |
| 100 clients: deliveries/s (client×message) | 2,801 [2,735–2,895] | 3,359 [3,119–3,406] | 1.2× |
| 100 clients: saturated post→all p50 ms | 111 [104–116] | 92.8 [90.4–93.2] | 1.2× |
| 100 clients: saturated POST p50 ms | 141 [136–141] | 119 [115–122] | 1.2× |
| 500 clients: subscribed | 500 [500–500] | 500 [500–500] | 1.0× |
| 500 clients: connect+subscribe all (s) | 1.91 [1.83–2.03] | 1.62 [1.57–1.66] | 1.2× |
| 500 clients: paced post→one client p50 ms | 55.0 [50.9–58.9] | 43.6 [40.2–47.9] | 1.3× |
| 500 clients: paced post→all clients p50 ms | 97.2 [93.6–106.8] | 79.1 [78.8–92.4] | 1.2× |
| 500 clients: paced post→all clients p99 ms | 194 [124–203] | 139 [110–166] | 1.4× |
| 500 clients: max sustained msgs/s (delivered to all) | 8.30 [8.10–9.40] | 9.60 [8.20–10.40] | 1.2× |
| 500 clients: deliveries/s (client×message) | 4,135 [4,048–4,710] | 4,814 [4,105–5,183] | 1.2× |
| 500 clients: saturated post→all p50 ms | 370 [336–396] | 331 [317–401] | 1.1× |
| 500 clients: saturated POST p50 ms | 467 [417–469] | 415 [373–480] | 1.1× |

### Upload + thumbnail (black_hole.jpg, 505 KB)

| Metric | Elixir baseline | Elixir candidate | Candidate advantage over baseline |
|---|---|---|---|
| POST with attachment (ms) | 381 [370–422] | 384 [344–485] | 1.0× |
| then GET thumb → 200 (ms) | 0.70 [0.70–0.90] | 0.70 [0.60–1.00] | 1.0× |
| POST → thumbnail served (ms) | 385 [371–425] | 385 [344–486] | 1.0× |

### Memory during cable fan-out, by process (MiB, peak within the phase)

App process: Elixir BEAM; Rails Puma master/workers when included;
Go/Rust's integrated campfire processes. Serving totals include native helpers, Redis and Thruster.
PSS apportions shared pages; RssAnon counts them in each process.

| Metric | Elixir baseline | Elixir candidate | Candidate advantage over baseline |
|---|---|---|---|
| 100 clients, all subscribed, idle: app process Pss | 183 [183–184] | 211 [210–217] | 0.9× |
| 100 clients, all subscribed, idle: app process RssAnon | 141 [141–142] | 168 [168–175] | 0.8× |
| 100 clients, all subscribed, idle: serving processes Pss | 216 [216–216] | 237 [237–244] | 0.9× |
| 100 clients, all subscribed, idle: whole container Pss | 217 [217–217] | 238 [238–245] | 0.9× |
| 100 clients, saturated fan-out: app process Pss | 178 [175–180] | 210 [209–214] | 0.8× |
| 100 clients, saturated fan-out: app process RssAnon | 136 [133–137] | 167 [166–171] | 0.8× |
| 100 clients, saturated fan-out: serving processes Pss | 219 [215–219] | 244 [243–249] | 0.9× |
| 100 clients, saturated fan-out: whole container Pss | 220 [216–220] | 244 [244–249] | 0.9× |
| 500 clients, all subscribed, idle: app process Pss | 198 [195–199] | 228 [228–229] | 0.9× |
| 500 clients, all subscribed, idle: app process RssAnon | 156 [152–157] | 186 [186–187] | 0.8× |
| 500 clients, all subscribed, idle: serving processes Pss | 258 [254–258] | 282 [281–283] | 0.9× |
| 500 clients, all subscribed, idle: whole container Pss | 259 [255–259] | 283 [282–284] | 0.9× |
| 500 clients, saturated fan-out: app process Pss | 210 [205–214] | 236 [235–237] | 0.9× |
| 500 clients, saturated fan-out: app process RssAnon | 168 [163–172] | 194 [192–194] | 0.9× |
| 500 clients, saturated fan-out: serving processes Pss | 274 [270–280] | 295 [293–296] | 0.9× |
| 500 clients, saturated fan-out: whole container Pss | 275 [271–281] | 296 [295–297] | 0.9× |
