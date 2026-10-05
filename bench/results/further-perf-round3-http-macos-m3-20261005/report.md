```
date: 2026-10-05T16:25:07+00:00
host: 7.0.12-linuxkit, , 8 threads, 7GB
server cpus: 0-3 (nproc 4); loadgen cpus: 4-7; network: host
env: WEB_CONCURRENCY=3 JOB_CONCURRENCY=3 RAILS_MAX_THREADS=5 
seed sha256: 58e6bb4498a188b33a52bbb79d82499d96a531f9afb9fc736a801532ddba1817  /Users/lau/oss/once-campfire-rust/parity/.seed/default/db/production.sqlite3
elixir source digest: c95ebdcbb522fd614da9c50c546713f64b7a193324ddd30c610213fe21ae53eb
rust extra env: 
workload: suites=http HTTP_SECS=4 HTTP_CONCS=1 16 64 CABLE_CLIENTS=100 500 1000 CABLE_TPUT_SECS=15 CABLE_POSTERS=4 UPLOAD_REPS=5 REPS=3
request logging (LOG_REQUESTS): false
parity ledger gate: skipped; runner: bench/docker-desktop
quiet wait: LOAD_MAX=1.5 LOAD_WAIT_SECS=120
user agent: (none)
elixir image: campfire-elixir:further-perf-r3 sha256:cf9f408c1e0180f461443b19476d0d481d9813531f7cc9bae54a9b3512a41b5c 2026-10-05T15:54:56.913347668Z unpacked_bytes=1705213032
reference image: campfire-elixir:further-perf-r2 sha256:9f25d3da2160a42b326141bb8ad730f5158ade580823868cad725babd936da4d 2026-10-05T08:08:41.624360552Z unpacked_bytes=1705209136
rust HEAD: 64f8635 (dirty: 0 files)
```

Reps: reference 3, elixir 3. Cells: median [min–max].

### Startup and memory

| Metric | Rails | Elixir | Rust advantage over Elixir |
|---|---|---|---|
| cold start: docker run → /up 200 (ms) | 1,199 [1,130–1,444] | 1,133 [1,109–1,508] | – |
| idle memory.current (MiB) | 166 [160–169] | 171 [159–171] | – |
| idle anon (MiB) | 134 [127–135] | 138 [126–138] | – |
| peak memory.current under load (MiB) | 291 [290–303] | 301 [286–308] | – |
| peak anon under load (MiB) | 244 [238–247] | 249 [233–250] | – |

### HTTP (signed in as david; keep-alive; c = concurrent connections)

| Metric | Rails | Elixir | Rust advantage over Elixir |
|---|---|---|---|
| room_show c=1 req/s | 1,633 [1,352–2,007] | 2,025 [1,888–2,355] | – |
| room_show c=1 p50 ms | 0.55 [0.49–0.58] | 0.43 [0.41–0.48] | – |
| room_show c=1 p99 ms | 1.28 [0.63–3.03] | 0.76 [0.68–0.77] | – |
| room_show c=1 CPU µs/success | 1,006 [880–1,108] | 775 [764–794] | – |
| room_show c=16 req/s | 5,112 [4,556–5,575] | 7,188 [6,906–7,562] | – |
| room_show c=16 p50 ms | 2.65 [2.31–3.04] | 2.07 [1.97–2.14] | – |
| room_show c=16 p99 ms | 7.32 [7.18–10.46] | 5.40 [5.12–5.62] | – |
| room_show c=16 CPU µs/success | 707 [679–803] | 529 [503–549] | – |
| room_show c=64 req/s | 4,358 [1,036–5,679] | 7,140 [6,365–7,253] | – |
| room_show c=64 p50 ms | 12.9 [10.8–38.2] | 8.63 [8.41–9.81] | – |
| room_show c=64 p99 ms | 34.0 [18.1–296.7] | 14.8 [14.3–15.2] | – |
| room_show c=64 CPU µs/success | 839 [668–2,854] | 535 [526–597] | – |
| messages_page c=1 req/s | 1,729 [779–2,536] | 3,303 [2,851–3,313] | – |
| messages_page c=1 p50 ms | 0.58 [0.37–0.81] | 0.29 [0.29–0.29] | – |
| messages_page c=1 p99 ms | 1.59 [0.69–7.51] | 0.49 [0.49–0.55] | – |
| messages_page c=1 CPU µs/success | 792 [638–1,672] | 531 [529–545] | – |
| messages_page c=16 req/s | 6,757 [2,518–7,352] | 7,585 [7,467–7,938] | – |
| messages_page c=16 p50 ms | 2.05 [2.02–5.36] | 1.98 [1.88–2.00] | – |
| messages_page c=16 p99 ms | 7.43 [5.46–19.81] | 3.77 [3.60–3.90] | – |
| messages_page c=16 CPU µs/success | 551 [516–1,338] | 455 [437–459] | – |
| messages_page c=64 req/s | 6,352 [2,071–6,754] | 7,488 [7,352–7,807] | – |
| messages_page c=64 p50 ms | 9.66 [8.53–28.41] | 7.90 [7.84–8.54] | – |
| messages_page c=64 p99 ms | 18.2 [15.9–70.7] | 12.9 [12.5–18.1] | – |
| messages_page c=64 CPU µs/success | 595 [556–1,635] | 461 [442–475] | – |
| sidebar c=1 req/s | 1,707 [854–1,843] | 1,841 [1,568–2,033] | – |
| sidebar c=1 p50 ms | 0.53 [0.48–0.69] | 0.47 [0.47–0.54] | – |
| sidebar c=1 p99 ms | 1.54 [1.15–6.32] | 0.96 [0.85–1.03] | – |
| sidebar c=1 CPU µs/success | 990 [924–1,587] | 901 [882–975] | – |
| sidebar c=16 req/s | 4,868 [2,661–4,941] | 5,398 [5,158–5,454] | – |
| sidebar c=16 p50 ms | 2.94 [2.88–4.70] | 2.69 [2.68–2.83] | – |
| sidebar c=16 p99 ms | 8.98 [8.26–23.34] | 8.05 [7.92–8.29] | – |
| sidebar c=16 CPU µs/success | 757 [755–1,314] | 690 [687–723] | – |
| sidebar c=64 req/s | 4,533 [4,156–5,164] | 4,995 [4,956–5,342] | – |
| sidebar c=64 p50 ms | 12.6 [12.1–14.6] | 11.7 [11.4–12.5] | – |
| sidebar c=64 p99 ms | 23.4 [18.4–30.5] | 19.9 [19.6–24.2] | – |
| sidebar c=64 CPU µs/success | 812 [731–900] | 748 [706–758] | – |
| search c=1 req/s | 1,928 [1,528–2,706] | 2,323 [2,101–2,339] | – |
| search c=1 p50 ms | 0.42 [0.33–0.73] | 0.41 [0.40–0.43] | – |
| search c=1 p99 ms | 0.90 [0.80–1.32] | 0.76 [0.76–1.19] | – |
| search c=1 CPU µs/success | 874 [701–927] | 821 [813–872] | – |
| search c=16 req/s | 5,136 [4,710–6,262] | 5,986 [5,933–5,994] | – |
| search c=16 p50 ms | 2.59 [2.38–3.14] | 2.49 [2.48–2.50] | – |
| search c=16 p99 ms | 7.58 [6.46–9.00] | 6.27 [6.17–6.75] | – |
| search c=16 CPU µs/success | 713 [604–791] | 630 [629–637] | – |
| search c=64 req/s | 5,119 [4,782–5,925] | 5,666 [5,588–5,852] | – |
| search c=64 p50 ms | 11.3 [10.5–12.9] | 11.0 [10.6–11.0] | – |
| search c=64 p99 ms | 20.4 [17.0–22.5] | 17.1 [15.9–18.4] | – |
| search c=64 CPU µs/success | 722 [642–779] | 668 [648–677] | – |
| avatar c=1 req/s | 17,939 [17,209–26,174] | 18,403 [17,229–18,476] | – |
| avatar c=1 p50 ms | 0.05 [0.03–0.05] | 0.05 [0.05–0.05] | – |
| avatar c=1 p99 ms | 0.10 [0.08–0.12] | 0.09 [0.08–0.16] | – |
| avatar c=1 CPU µs/success | 58.6 [40.2–59.0] | 57.3 [55.2–60.3] | – |
| avatar c=16 req/s | 113,044 [103,348–132,587] | 133,992 [98,065–134,961] | – |
| avatar c=16 p50 ms | 0.11 [0.10–0.13] | 0.10 [0.10–0.12] | – |
| avatar c=16 p99 ms | 0.45 [0.31–0.54] | 0.32 [0.32–0.75] | – |
| avatar c=16 CPU µs/success | 28.5 [25.5–31.1] | 26.5 [26.1–31.7] | – |
| avatar c=64 req/s | 141,468 [136,924–158,277] | 165,799 [132,700–169,112] | – |
| avatar c=64 p50 ms | 0.37 [0.34–0.38] | 0.34 [0.33–0.36] | – |
| avatar c=64 p99 ms | 1.41 [1.34–1.68] | 1.11 [1.10–2.31] | – |
| avatar c=64 CPU µs/success | 27.7 [24.4–27.8] | 23.9 [23.4–27.4] | – |
| static_css c=1 req/s | 19,587 [19,299–27,018] | 19,242 [17,858–19,288] | – |
| static_css c=1 p50 ms | 0.05 [0.03–0.05] | 0.05 [0.05–0.05] | – |
| static_css c=1 p99 ms | 0.08 [0.08–0.09] | 0.08 [0.08–0.14] | – |
| static_css c=1 CPU µs/success | 54.3 [37.1–55.4] | 55.3 [55.2–57.6] | – |
| static_css c=16 req/s | 130,821 [105,307–138,003] | 138,634 [116,647–138,780] | – |
| static_css c=16 p50 ms | 0.10 [0.10–0.13] | 0.10 [0.10–0.11] | – |
| static_css c=16 p99 ms | 0.35 [0.32–0.47] | 0.32 [0.31–0.49] | – |
| static_css c=16 CPU µs/success | 24.9 [24.5–30.1] | 24.7 [24.6–27.3] | – |
| static_css c=64 req/s | 185,817 [123,506–188,137] | 175,508 [143,689–183,397] | – |
| static_css c=64 p50 ms | 0.30 [0.30–0.40] | 0.31 [0.30–0.34] | – |
| static_css c=64 p99 ms | 1.04 [1.02–2.04] | 1.16 [1.04–1.95] | – |
| static_css c=64 CPU µs/success | 21.3 [20.8–30.6] | 22.4 [21.5–26.1] | – |
| up c=1 req/s | 10,134 [10,085–11,717] | 9,676 [9,508–10,099] | – |
| up c=1 p50 ms | 0.10 [0.07–0.10] | 0.10 [0.10–0.10] | – |
| up c=1 p99 ms | 0.15 [0.14–0.21] | 0.15 [0.15–0.21] | – |
| up c=1 CPU µs/success | 102 [87–102] | 103 [101–109] | – |
| up c=16 req/s | 54,159 [45,943–57,555] | 53,935 [41,679–56,312] | – |
| up c=16 p50 ms | 0.26 [0.26–0.30] | 0.28 [0.27–0.31] | – |
| up c=16 p99 ms | 0.90 [0.65–0.94] | 0.70 [0.68–1.61] | – |
| up c=16 CPU µs/success | 71.3 [68.0–84.2] | 72.9 [70.3–88.3] | – |
| up c=64 req/s | 55,282 [46,386–60,128] | 56,578 [50,055–57,816] | – |
| up c=64 p50 ms | 1.06 [1.02–1.18] | 1.07 [1.04–1.09] | – |
| up c=64 p99 ms | 2.84 [2.23–3.78] | 2.48 [2.37–4.80] | – |
| up c=64 CPU µs/success | 71.9 [66.3–85.3] | 70.5 [69.0–77.7] | – |
| post_message c=1 req/s | 779 [622–792] | 787 [784–819] | – |
| post_message c=1 p50 ms | 1.03 [1.02–1.24] | 0.99 [0.99–1.01] | – |
| post_message c=1 p99 ms | 6.55 [6.50–7.24] | 7.32 [7.13–7.34] | – |
| post_message c=1 CPU µs/success | 3,003 [2,984–3,603] | 2,957 [2,894–3,010] | – |
| post_message c=16 req/s | 1,993 [1,438–2,048] | 1,964 [1,806–1,992] | – |
| post_message c=16 p50 ms | 6.48 [6.22–9.87] | 6.55 [6.48–7.33] | – |
| post_message c=16 p99 ms | 17.3 [17.0–24.0] | 17.9 [17.1–21.0] | – |
| post_message c=16 CPU µs/success | 1,840 [1,801–2,563] | 1,829 [1,824–1,984] | – |
| post_message c=64 req/s | 1,978 [1,624–2,051] | 1,949 [1,788–1,982] | – |
| post_message c=64 p50 ms | 30.5 [30.1–38.4] | 31.7 [30.9–32.6] | – |
| post_message c=64 p99 ms | 48.7 [43.8–57.2] | 48.5 [46.8–60.7] | – |
| post_message c=64 CPU µs/success | 1,858 [1,791–2,254] | 1,857 [1,852–2,039] | – |

### HTTP errors / non-2xx-3xx (first rep, per app)

| Metric | Rails | Elixir | Rust advantage over Elixir |
|---|---|---|---|
- reference: none
- elixir: none

### Action Cable fan-out (one room; chatter.js subscriptions per client)

| Metric | Rails | Elixir | Rust advantage over Elixir |
|---|---|---|---|

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
