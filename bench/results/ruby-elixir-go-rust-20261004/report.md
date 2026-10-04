```
comparison date: 2026-10-04
measurement order: elixir,rust / rust,elixir; later ruby / ruby; then go / go; then current rust / rust
date: 2026-10-04T15:19:03+02:00
host: 7.2.5-4-omarchy, AMD RYZEN AI MAX+ 395 w/ Radeon 8060S, 32 threads, 30GB
server cpus: 8-11 (nproc 4); loadgen cpus: 12-15; network: host
env: WEB_CONCURRENCY=3 JOB_CONCURRENCY=3 RAILS_MAX_THREADS=5 
seed sha256: 433ccdce78759eef0524b2840a512077e52cc8e867f6c095430a8871d47a2e38  /home/dhh/Work/basecamp/once-campfire-rust/parity/.seed/default/db/production.sqlite3
elixir source digest: ad793a949fb8bc0f03f370a2b562b9226f3e86d9304fc4be6110ea72b0179056
rust extra env: 
workload: suites=http cable upload HTTP_SECS=4 HTTP_CONCS=1 16 64 CABLE_CLIENTS=100 500 1000 CABLE_TPUT_SECS=15 CABLE_POSTERS=4 UPLOAD_REPS=5 REPS=2
quiet wait: LOAD_MAX=1.5 LOAD_WAIT_SECS=30
user agent: (none)
reference image: campfire-reference:app sha256:d91fdb852402e2d3393ca262e50b657ea0cf861fc7d4150aaf3773c91d41c2fa 2026-09-27T22:01:29.746709947+02:00 unpacked_bytes=1291498414
rust HEAD: 195457b (dirty: 0 files)

Original Elixir/Rust measurement environment:
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

Original Go measurement environment:
date: 2026-10-04T15:29:44+02:00
host: 7.2.5-4-omarchy, AMD RYZEN AI MAX+ 395 w/ Radeon 8060S, 32 threads, 30GB
server cpus: 8-11 (nproc 4); loadgen cpus: 12-15; network: host
env: WEB_CONCURRENCY=3 JOB_CONCURRENCY=3 RAILS_MAX_THREADS=5 
seed sha256: 433ccdce78759eef0524b2840a512077e52cc8e867f6c095430a8871d47a2e38  /home/dhh/Work/basecamp/once-campfire-rust/parity/.seed/default/db/production.sqlite3
elixir source digest: ad793a949fb8bc0f03f370a2b562b9226f3e86d9304fc4be6110ea72b0179056
rust extra env: 
workload: suites=http cable upload HTTP_SECS=4 HTTP_CONCS=1 16 64 CABLE_CLIENTS=100 500 1000 CABLE_TPUT_SECS=15 CABLE_POSTERS=4 UPLOAD_REPS=5 REPS=2
quiet wait: LOAD_MAX=1.5 LOAD_WAIT_SECS=30
user agent: (none)
go image: once-campfire-go:readme-504428 sha256:929c0116613a3696ff2ad276b7e11ef00554f5469003775361e136e760617c45 2026-10-04T15:28:42.439061071+02:00 unpacked_bytes=241608271
go HEAD: 504428addff333549f1fc88b003c7331779a3c2a (dirty: 0 files)
rust HEAD: 195457b (dirty: 0 files)

Current Rust measurement environment:
date: 2026-10-04T15:39:18+02:00
host: 7.2.5-4-omarchy, AMD RYZEN AI MAX+ 395 w/ Radeon 8060S, 32 threads, 30GB
server cpus: 8-11 (nproc 4); loadgen cpus: 12-15; network: host
env: WEB_CONCURRENCY=3 JOB_CONCURRENCY=3 RAILS_MAX_THREADS=5 
seed sha256: 433ccdce78759eef0524b2840a512077e52cc8e867f6c095430a8871d47a2e38  /home/dhh/Work/basecamp/once-campfire-rust/parity/.seed/default/db/production.sqlite3
elixir source digest: ad793a949fb8bc0f03f370a2b562b9226f3e86d9304fc4be6110ea72b0179056
rust extra env: 
workload: suites=http cable upload HTTP_SECS=4 HTTP_CONCS=1 16 64 CABLE_CLIENTS=100 500 1000 CABLE_TPUT_SECS=15 CABLE_POSTERS=4 UPLOAD_REPS=5 REPS=2
quiet wait: LOAD_MAX=1.5 LOAD_WAIT_SECS=30
user agent: (none)
rust image: campfire-rust:bench-emoon-pr43 sha256:2ef6125fcd3f33531ef4c0bc9f14db1d6432d9517267bac956f7d268dd76f4e4 2026-10-01T20:36:46.055072504+02:00 unpacked_bytes=235756793
rust HEAD: 195457b (dirty: 0 files)
```

Reps: reference 2, elixir 2, go 2, rust 2. Cells: median [min–max].

### Startup and memory

| Metric | Rails | Elixir | Go | Rust | Rust advantage over Elixir |
|---|---|---|---|---|---|
| cold start: docker run → /up 200 (ms) | 2,601 [2,575–2,627] | 530 [523–536] | 145 [143–147] | 177 [167–187] | 3.0× |
| idle memory.current (MiB) | 298 [297–298] | 152 [150–153] | 15.5 [9.0–22.0] | 32.0 [15.0–49.0] | 4.7× |
| idle anon (MiB) | 278 [278–278] | 116 [115–118] | 8.00 [8.00–8.00] | 13.0 [13.0–13.0] | 9.0× |
| peak memory.current under load (MiB) | 1,458 [1,433–1,484] | 631 [609–653] | 399 [389–409] | 388 [371–406] | 1.6× |
| peak anon under load (MiB) | 1,419 [1,393–1,445] | 564 [545–583] | 349 [347–351] | 268 [268–269] | 2.1× |

### HTTP (signed in as david; keep-alive; c = concurrent connections)

| Metric | Rails | Elixir | Go | Rust | Rust advantage over Elixir |
|---|---|---|---|---|---|
| room_show c=1 req/s | 90.0 [89.4–90.6] | 292 [292–292] | 990 [987–992] | 8,711 [8,706–8,717] | 29.8× |
| room_show c=1 p50 ms | 10.6 [10.5–10.7] | 3.38 [3.37–3.39] | 1.00 [0.99–1.00] | 0.11 [0.11–0.11] | 31.0× |
| room_show c=1 p99 ms | 14.0 [13.6–14.4] | 3.99 [3.94–4.03] | 1.31 [1.30–1.31] | 0.20 [0.19–0.21] | 20.2× |
| room_show c=1 CPU µs/success | 11,190 [11,119–11,260] | 4,595 [4,329–4,861] | 1,027 [1,024–1,031] | 108 [108–108] | 42.6× |
| room_show c=16 req/s | 216 [215–216] | 722 [718–726] | 3,860 [3,853–3,868] | 36,260 [36,233–36,287] | 50.2× |
| room_show c=16 p50 ms | 69.2 [68.7–69.6] | 21.9 [21.7–22.0] | 3.41 [3.35–3.47] | 0.43 [0.43–0.43] | 51.3× |
| room_show c=16 p99 ms | 173 [173–174] | 31.2 [31.1–31.2] | 12.8 [12.7–12.9] | 0.80 [0.80–0.80] | 39.1× |
| room_show c=16 CPU µs/success | 14,292 [14,206–14,379] | 4,760 [4,730–4,790] | 1,007 [1,005–1,009] | 103 [103–103] | 46.1× |
| room_show c=64 req/s | 190 [182–197] | 751 [750–752] | 3,810 [3,791–3,829] | 36,984 [36,948–37,020] | 49.2× |
| room_show c=64 p50 ms | 367 [316–417] | 84.4 [84.0–84.7] | 14.0 [13.7–14.3] | 1.68 [1.68–1.69] | 50.1× |
| room_show c=64 p99 ms | 474 [400–548] | 108 [106–111] | 60.5 [58.7–62.3] | 3.09 [3.07–3.10] | 35.1× |
| room_show c=64 CPU µs/success | 15,972 [15,327–16,617] | 4,674 [4,671–4,676] | 1,019 [1,013–1,025] | 101 [101–101] | 46.2× |
| messages_page c=1 req/s | 173 [172–174] | 407 [404–410] | 1,365 [1,362–1,368] | 10,352 [10,229–10,475] | 25.4× |
| messages_page c=1 p50 ms | 5.61 [5.58–5.63] | 2.43 [2.42–2.45] | 0.72 [0.72–0.72] | 0.09 [0.09–0.09] | 26.4× |
| messages_page c=1 p99 ms | 7.80 [7.77–7.83] | 2.98 [2.87–3.09] | 0.99 [0.98–0.99] | 0.17 [0.17–0.17] | 17.6× |
| messages_page c=1 CPU µs/success | 5,854 [5,831–5,877] | 3,121 [3,016–3,226] | 741 [740–743] | 91.2 [90.1–92.4] | 34.2× |
| messages_page c=16 req/s | 384 [378–389] | 1,053 [1,043–1,063] | 5,573 [5,554–5,591] | 40,872 [40,824–40,919] | 38.8× |
| messages_page c=16 p50 ms | 38.9 [38.2–39.6] | 15.0 [14.9–15.2] | 2.18 [2.13–2.23] | 0.38 [0.38–0.38] | 39.5× |
| messages_page c=16 p99 ms | 112 [105–119] | 23.1 [22.8–23.5] | 9.05 [8.98–9.12] | 0.67 [0.67–0.67] | 34.6× |
| messages_page c=16 CPU µs/success | 7,936 [7,839–8,033] | 3,364 [3,348–3,380] | 697 [695–699] | 91.0 [90.9–91.2] | 37.0× |
| messages_page c=64 req/s | 378 [377–379] | 1,031 [1,028–1,035] | 5,461 [5,460–5,462] | 41,995 [41,496–42,494] | 40.7× |
| messages_page c=64 p50 ms | 173 [166–180] | 61.7 [61.5–62.0] | 8.48 [8.41–8.55] | 1.49 [1.47–1.51] | 41.4× |
| messages_page c=64 p99 ms | 266 [252–280] | 73.7 [73.2–74.2] | 50.2 [50.0–50.4] | 2.59 [2.56–2.61] | 28.5× |
| messages_page c=64 CPU µs/success | 7,952 [7,925–7,978] | 3,449 [3,436–3,462] | 711 [711–712] | 88.5 [87.5–89.6] | 39.0× |
| sidebar c=1 req/s | 195 [177–213] | 855 [846–864] | 5,033 [5,029–5,037] | 7,976 [7,974–7,977] | 9.3× |
| sidebar c=1 p50 ms | 4.51 [4.50–4.53] | 1.15 [1.14–1.16] | 0.19 [0.19–0.19] | 0.12 [0.12–0.12] | 9.6× |
| sidebar c=1 p99 ms | 14.3 [6.9–21.7] | 1.46 [1.41–1.51] | 0.35 [0.34–0.36] | 0.22 [0.21–0.22] | 6.7× |
| sidebar c=1 CPU µs/success | 5,217 [4,735–5,699] | 1,869 [1,851–1,887] | 212 [212–213] | 118 [118–118] | 15.9× |
| sidebar c=16 req/s | 503 [489–518] | 1,275 [1,270–1,280] | 19,753 [19,554–19,953] | 34,672 [34,590–34,756] | 27.2× |
| sidebar c=16 p50 ms | 30.0 [30.0–30.1] | 12.4 [12.3–12.5] | 0.67 [0.67–0.68] | 0.44 [0.44–0.45] | 27.9× |
| sidebar c=16 p99 ms | 79.3 [58.7–99.8] | 17.2 [17.0–17.4] | 2.61 [2.58–2.64] | 0.86 [0.85–0.86] | 20.1× |
| sidebar c=16 CPU µs/success | 5,794 [5,634–5,953] | 2,489 [2,486–2,492] | 186 [185–188] | 109 [109–109] | 22.9× |
| sidebar c=64 req/s | 514 [502–527] | 1,329 [1,319–1,338] | 19,732 [19,617–19,848] | 35,968 [35,655–36,282] | 27.1× |
| sidebar c=64 p50 ms | 130 [119–141] | 48.1 [47.7–48.4] | 3.10 [3.08–3.13] | 1.73 [1.71–1.74] | 27.9× |
| sidebar c=64 p99 ms | 169 [153–186] | 57.5 [57.4–57.5] | 6.26 [6.25–6.27] | 3.28 [3.26–3.30] | 17.5× |
| sidebar c=64 CPU µs/success | 5,639 [5,519–5,759] | 2,436 [2,426–2,447] | 188 [187–189] | 105 [104–106] | 23.2× |
| search c=1 req/s | 172 [170–173] | 608 [604–611] | 1,762 [1,754–1,771] | 9,721 [9,655–9,786] | 16.0× |
| search c=1 p50 ms | 5.64 [5.57–5.72] | 1.62 [1.62–1.62] | 0.55 [0.55–0.56] | 0.10 [0.10–0.10] | 16.4× |
| search c=1 p99 ms | 8.00 [7.99–8.01] | 2.02 [1.98–2.06] | 0.83 [0.81–0.84] | 0.16 [0.15–0.16] | 12.8× |
| search c=1 CPU µs/success | 5,838 [5,781–5,896] | 2,301 [2,297–2,306] | 588 [584–592] | 95.9 [95.4–96.4] | 24.0× |
| search c=16 req/s | 380 [377–383] | 1,156 [1,148–1,164] | 7,053 [7,014–7,092] | 33,299 [33,246–33,353] | 28.8× |
| search c=16 p50 ms | 40.9 [40.0–41.8] | 13.7 [13.6–13.8] | 1.66 [1.64–1.68] | 0.44 [0.44–0.44] | 30.9× |
| search c=16 p99 ms | 77.0 [68.4–85.6] | 18.8 [18.5–19.0] | 7.57 [7.43–7.71] | 1.02 [1.02–1.03] | 18.3× |
| search c=16 CPU µs/success | 7,616 [7,567–7,665] | 2,815 [2,804–2,826] | 546 [542–549] | 98.8 [98.7–98.8] | 28.5× |
| search c=64 req/s | 379 [379–379] | 1,162 [1,161–1,162] | 6,971 [6,918–7,024] | 38,533 [38,236–38,830] | 33.2× |
| search c=64 p50 ms | 169 [169–169] | 55.0 [54.9–55.1] | 8.07 [8.04–8.11] | 1.56 [1.55–1.57] | 35.2× |
| search c=64 p99 ms | 192 [191–193] | 64.8 [63.5–66.2] | 31.9 [30.5–33.3] | 3.20 [3.15–3.25] | 20.2× |
| search c=64 CPU µs/success | 7,657 [7,622–7,692] | 2,843 [2,840–2,846] | 552 [548–556] | 88.0 [87.7–88.3] | 32.3× |
| avatar c=1 req/s | 27,763 [27,460–28,067] | 28,715 [28,414–29,016] | 39,037 [38,974–39,099] | 61,356 [61,208–61,505] | 2.1× |
| avatar c=1 p50 ms | 0.03 [0.03–0.03] | 0.03 [0.03–0.03] | 0.02 [0.02–0.02] | 0.01 [0.01–0.01] | 2.1× |
| avatar c=1 p99 ms | 0.10 [0.09–0.10] | 0.09 [0.09–0.10] | 0.05 [0.05–0.05] | 0.02 [0.02–0.02] | 4.3× |
| avatar c=1 CPU µs/success | 30.3 [29.7–31.0] | 29.2 [28.6–29.7] | 18.9 [18.9–19.0] | 9.22 [9.17–9.27] | 3.2× |
| avatar c=16 req/s | 94,703 [94,383–95,023] | 96,970 [96,381–97,558] | 200,856 [200,458–201,255] | 364,915 [364,464–365,366] | 3.8× |
| avatar c=16 p50 ms | 0.10 [0.10–0.10] | 0.10 [0.10–0.10] | 0.06 [0.06–0.06] | 0.04 [0.04–0.04] | 2.5× |
| avatar c=16 p99 ms | 0.92 [0.90–0.93] | 0.91 [0.91–0.91] | 0.35 [0.35–0.35] | 0.11 [0.11–0.11] | 8.0× |
| avatar c=16 CPU µs/success | 31.5 [31.5–31.6] | 30.6 [30.4–30.8] | 16.6 [16.6–16.6] | 8.03 [7.99–8.06] | 3.8× |
| avatar c=64 req/s | 76,098 [75,920–76,277] | 78,929 [77,960–79,898] | 202,708 [202,417–202,999] | 408,993 [404,665–413,321] | 5.2× |
| avatar c=64 p50 ms | 0.31 [0.31–0.31] | 0.28 [0.28–0.29] | 0.22 [0.22–0.22] | 0.15 [0.15–0.15] | 1.9× |
| avatar c=64 p99 ms | 5.05 [5.04–5.06] | 4.92 [4.86–4.97] | 1.49 [1.48–1.50] | 0.33 [0.33–0.33] | 14.9× |
| avatar c=64 CPU µs/success | 39.5 [39.5–39.5] | 37.7 [37.2–38.3] | 16.7 [16.7–16.7] | 7.49 [7.39–7.60] | 5.0× |
| static_css c=1 req/s | 33,772 [33,589–33,956] | 33,864 [33,592–34,136] | 54,649 [54,643–54,655] | 65,144 [64,867–65,421] | 1.9× |
| static_css c=1 p50 ms | 0.03 [0.03–0.03] | 0.03 [0.03–0.03] | 0.02 [0.02–0.02] | 0.01 [0.01–0.01] | 2.0× |
| static_css c=1 p99 ms | 0.07 [0.07–0.07] | 0.07 [0.07–0.07] | 0.03 [0.03–0.03] | 0.02 [0.02–0.02] | 3.4× |
| static_css c=1 CPU µs/success | 25.7 [25.5–25.8] | 25.5 [25.2–25.8] | 13.4 [13.4–13.4] | 8.95 [8.94–8.96] | 2.9× |
| static_css c=16 req/s | 129,639 [127,745–131,532] | 125,904 [124,586–127,223] | 289,554 [288,579–290,529] | 383,609 [379,449–387,768] | 3.0× |
| static_css c=16 p50 ms | 0.08 [0.08–0.09] | 0.09 [0.09–0.09] | 0.04 [0.04–0.04] | 0.04 [0.04–0.04] | 2.2× |
| static_css c=16 p99 ms | 0.66 [0.65–0.66] | 0.71 [0.68–0.74] | 0.20 [0.20–0.20] | 0.11 [0.10–0.12] | 6.4× |
| static_css c=16 CPU µs/success | 24.4 [24.1–24.8] | 24.8 [24.7–24.9] | 11.0 [11.0–11.0] | 7.64 [7.62–7.66] | 3.2× |
| static_css c=64 req/s | 106,504 [106,479–106,530] | 105,374 [104,042–106,707] | 295,610 [293,418–297,802] | 425,869 [419,442–432,296] | 4.0× |
| static_css c=64 p50 ms | 0.28 [0.28–0.29] | 0.28 [0.28–0.29] | 0.16 [0.16–0.16] | 0.14 [0.14–0.14] | 2.0× |
| static_css c=64 p99 ms | 3.52 [3.51–3.54] | 3.53 [3.48–3.58] | 0.98 [0.98–0.98] | 0.33 [0.31–0.35] | 10.7× |
| static_css c=64 CPU µs/success | 29.2 [29.1–29.3] | 29.6 [29.5–29.7] | 10.9 [10.9–11.0] | 7.09 [7.04–7.15] | 4.2× |
| up c=1 req/s | 1,787 [1,772–1,801] | 4,128 [4,004–4,252] | 33,455 [33,409–33,501] | 40,443 [40,177–40,708] | 9.8× |
| up c=1 p50 ms | 0.53 [0.52–0.53] | 0.23 [0.23–0.24] | 0.03 [0.03–0.03] | 0.02 [0.02–0.02] | 10.1× |
| up c=1 p99 ms | 1.09 [1.06–1.13] | 0.37 [0.37–0.38] | 0.06 [0.06–0.06] | 0.04 [0.03–0.04] | 10.6× |
| up c=1 CPU µs/success | 596 [591–601] | 374 [366–382] | 25.4 [25.3–25.5] | 15.5 [15.5–15.6] | 24.1× |
| up c=16 req/s | 4,054 [4,043–4,066] | 8,493 [8,440–8,547] | 154,476 [153,505–155,448] | 230,480 [226,952–234,008] | 27.1× |
| up c=16 p50 ms | 3.81 [3.79–3.83] | 1.83 [1.81–1.84] | 0.08 [0.08–0.08] | 0.07 [0.07–0.07] | 26.9× |
| up c=16 p99 ms | 7.92 [7.89–7.96] | 4.30 [4.28–4.32] | 0.42 [0.42–0.43] | 0.12 [0.12–0.12] | 34.8× |
| up c=16 CPU µs/success | 718 [718–719] | 404 [401–406] | 23.0 [22.9–23.2] | 14.8 [14.5–15.1] | 27.3× |
| up c=64 req/s | 4,003 [4,000–4,006] | 8,931 [8,920–8,943] | 154,068 [153,158–154,979] | 231,156 [227,328–234,985] | 25.9× |
| up c=64 p50 ms | 15.7 [15.7–15.8] | 6.72 [6.71–6.74] | 0.31 [0.31–0.31] | 0.27 [0.26–0.27] | 25.1× |
| up c=64 p99 ms | 25.9 [25.9–25.9] | 16.6 [16.5–16.6] | 1.74 [1.71–1.76] | 0.56 [0.55–0.57] | 29.5× |
| up c=64 CPU µs/success | 732 [732–733] | 398 [397–399] | 23.1 [23.0–23.2] | 14.8 [14.6–15.0] | 26.8× |
| post_message c=1 req/s | 140 [139–141] | 413 [413–414] | 1,655 [1,651–1,660] | 2,816 [2,797–2,835] | 6.8× |
| post_message c=1 p50 ms | 6.67 [6.64–6.70] | 2.30 [2.29–2.30] | 0.52 [0.52–0.52] | 0.32 [0.32–0.32] | 7.2× |
| post_message c=1 p99 ms | 13.3 [13.1–13.5] | 7.76 [7.72–7.81] | 3.53 [3.52–3.55] | 1.64 [1.64–1.65] | 4.7× |
| post_message c=1 CPU µs/success | 9,532 [9,527–9,537] | 4,666 [4,626–4,705] | 618 [618–618] | 373 [371–375] | 12.5× |
| post_message c=16 req/s | 267 [265–268] | 801 [798–804] | 4,767 [4,750–4,784] | 6,896 [6,864–6,927] | 8.6× |
| post_message c=16 p50 ms | 57.3 [56.1–58.6] | 19.4 [19.3–19.6] | 2.18 [2.15–2.21] | 2.04 [2.03–2.06] | 9.5× |
| post_message c=16 p99 ms | 158 [151–165] | 26.9 [26.6–27.1] | 12.8 [12.8–12.8] | 5.89 [5.83–5.94] | 4.6× |
| post_message c=16 CPU µs/success | 12,340 [12,317–12,364] | 3,841 [3,821–3,861] | 570 [568–572] | 385 [383–386] | 10.0× |
| post_message c=64 req/s | 264 [263–264] | 861 [853–868] | 4,660 [4,613–4,708] | 6,801 [6,764–6,837] | 7.9× |
| post_message c=64 p50 ms | 233 [229–236] | 74.4 [73.7–75.1] | 10.2 [10.1–10.3] | 9.08 [9.04–9.13] | 8.2× |
| post_message c=64 p99 ms | 368 [366–371] | 83.1 [80.5–85.8] | 59.7 [59.3–60.1] | 14.5 [14.4–14.6] | 5.7× |
| post_message c=64 CPU µs/success | 12,542 [12,485–12,599] | 3,602 [3,571–3,633] | 578 [577–580] | 392 [391–394] | 9.2× |

### HTTP errors / non-2xx-3xx (first rep, per app)

| Metric | Rails | Elixir | Go | Rust | Rust advantage over Elixir |
|---|---|---|---|---|---|
- reference: none
- elixir: none
- go: none
- rust: none

### Action Cable fan-out (one room; chatter.js subscriptions per client)

| Metric | Rails | Elixir | Go | Rust | Rust advantage over Elixir |
|---|---|---|---|---|---|
| 100 clients: subscribed | 100 [100–100] | 100 [100–100] | 100 [100–100] | 100 [100–100] | 1.0× |
| 100 clients: connect+subscribe all (s) | 0.27 [0.27–0.27] | 0.06 [0.06–0.06] | 0.06 [0.06–0.06] | 0.06 [0.06–0.06] | 1.0× |
| 100 clients: paced post→one client p50 ms | 14.5 [14.2–14.7] | 3.60 [3.58–3.62] | 2.01 [1.97–2.04] | 1.73 [1.66–1.80] | 2.1× |
| 100 clients: paced post→all clients p50 ms | 20.1 [20.0–20.2] | 4.03 [4.02–4.04] | 2.38 [2.37–2.38] | 1.99 [1.93–2.05] | 2.0× |
| 100 clients: paced post→all clients p99 ms | 56.2 [32.4–79.9] | 25.4 [10.3–40.6] | 11.1 [7.7–14.5] | 3.96 [2.62–5.30] | 6.4× |
| 100 clients: max sustained msgs/s (delivered to all) | 76.6 [75.7–77.5] | 413 [411–414] | 1,804 [1,802–1,806] | 3,861 [3,828–3,894] | 9.4× |
| 100 clients: deliveries/s (client×message) | 7,662 [7,573–7,752] | 41,278 [41,116–41,440] | 180,410 [180,195–180,626] | 386,068 [382,771–389,365] | 9.4× |
| 100 clients: saturated post→all p50 ms | 50.2 [48.8–51.6] | 8.00 [7.94–8.06] | 3.46 [3.41–3.52] | 1.17 [1.17–1.18] | 6.8× |
| 100 clients: saturated POST p50 ms | 42.4 [38.3–46.5] | 9.29 [9.24–9.34] | 1.90 [1.90–1.90] | 0.89 [0.88–0.89] | 10.5× |
| 500 clients: subscribed | 500 [500–500] | 500 [500–500] | 500 [500–500] | 500 [500–500] | 1.0× |
| 500 clients: connect+subscribe all (s) | 0.79 [0.77–0.80] | 0.20 [0.18–0.21] | 0.11 [0.11–0.12] | 0.12 [0.12–0.13] | 1.6× |
| 500 clients: paced post→one client p50 ms | 28.0 [27.8–28.3] | 7.98 [7.89–8.07] | 3.83 [3.79–3.86] | 2.69 [2.63–2.74] | 3.0× |
| 500 clients: paced post→all clients p50 ms | 57.0 [54.9–59.2] | 11.0 [10.8–11.1] | 5.31 [5.26–5.37] | 3.84 [3.73–3.95] | 2.9× |
| 500 clients: paced post→all clients p99 ms | 109 [91–127] | 14.7 [12.7–16.8] | 14.3 [10.2–18.4] | 5.30 [5.01–5.59] | 2.8× |
| 500 clients: max sustained msgs/s (delivered to all) | 20.9 [20.7–21.2] | 121 [121–122] | 468 [461–475] | 1,086 [1,085–1,088] | 9.0× |
| 500 clients: deliveries/s (client×message) | 10,482 [10,360–10,604] | 60,592 [60,333–60,850] | 233,966 [230,416–237,516] | 543,175 [542,363–543,987] | 9.0× |
| 500 clients: saturated post→all p50 ms | 966 [150–1,782] | 29.0 [28.6–29.4] | 20.8 [20.4–21.2] | 8.07 [8.02–8.13] | 3.6× |
| 500 clients: saturated POST p50 ms | 144 [116–173] | 32.8 [32.8–32.8] | 7.00 [6.94–7.06] | 3.40 [3.39–3.42] | 9.6× |
| 1000 clients: subscribed | 1,000 [1,000–1,000] | 1,000 [1,000–1,000] | 1,000 [1,000–1,000] | 1,000 [1,000–1,000] | 1.0× |
| 1000 clients: connect+subscribe all (s) | 1.50 [1.49–1.50] | 0.40 [0.38–0.42] | 0.17 [0.14–0.20] | 0.12 [0.11–0.13] | 3.3× |
| 1000 clients: paced post→one client p50 ms | 43.3 [40.2–46.4] | 10.6 [10.5–10.8] | 5.90 [5.78–6.03] | 3.98 [3.95–4.01] | 2.7× |
| 1000 clients: paced post→all clients p50 ms | 135 [84–185] | 18.3 [18.2–18.3] | 9.39 [9.28–9.51] | 6.24 [6.19–6.30] | 2.9× |
| 1000 clients: paced post→all clients p99 ms | 188 [173–204] | 21.7 [21.3–22.1] | 15.9 [12.0–19.7] | 8.48 [8.37–8.59] | 2.6× |
| 1000 clients: max sustained msgs/s (delivered to all) | 12.4 [11.9–12.9] | 60.2 [59.7–60.8] | 239 [239–240] | 546 [543–548] | 9.1× |
| 1000 clients: deliveries/s (client×message) | 12,412 [11,923–12,901] | 60,219 [59,666–60,772] | 239,119 [238,557–239,681] | 545,654 [543,303–548,006] | 9.1× |
| 1000 clients: saturated post→all p50 ms | 879 [325–1,434] | 58.7 [58.6–58.8] | 39.6 [38.4–40.7] | 16.0 [15.9–16.0] | 3.7× |
| 1000 clients: saturated POST p50 ms | 209 [196–223] | 66.6 [66.1–67.0] | 15.2 [15.2–15.2] | 7.02 [6.95–7.09] | 9.5× |

### Upload + thumbnail (black_hole.jpg, 505 KB)

| Metric | Rails | Elixir | Go | Rust | Rust advantage over Elixir |
|---|---|---|---|---|---|
| POST with attachment (ms) | 57.5 [55.5–59.4] | 92.2 [88.8–95.7] | 28.1 [27.6–28.5] | 28.0 [27.5–28.5] | 3.3× |
| then GET thumb → 200 (ms) | 0.40 [0.40–0.40] | 0.40 [0.40–0.40] | 0.30 [0.30–0.30] | 0.30 [0.30–0.30] | 1.3× |
| POST → thumbnail served (ms) | 57.8 [55.8–59.8] | 92.6 [89.1–96.1] | 28.4 [27.9–28.8] | 28.3 [27.8–28.8] | 3.3× |

### Memory during cable fan-out, by process (MiB, peak within the phase)

App process: Elixir BEAM; Rails Puma master/workers when included;
Go/Rust's integrated campfire processes. Serving totals include native helpers, Redis and Thruster.
PSS apportions shared pages; RssAnon counts them in each process.

| Metric | Rails | Elixir | Go | Rust | Rust advantage over Elixir |
|---|---|---|---|---|---|
| 100 clients, all subscribed, idle: app process Pss | 546 [544–547] | 231 [228–234] | 139 [137–141] | 122 [122–122] | 1.9× |
| 100 clients, all subscribed, idle: app process RssAnon | 692 [692–693] | 187 [184–190] | 117 [115–119] | 100 [100–101] | 1.9× |
| 100 clients, all subscribed, idle: serving processes Pss | 580 [578–581] | 284 [281–288] | 139 [137–141] | 122 [122–122] | 2.3× |
| 100 clients, all subscribed, idle: whole container Pss | 851 [848–854] | 284 [280–288] | 139 [137–141] | 122 [122–122] | 2.3× |
| 100 clients, saturated fan-out: app process Pss | 646 [644–647] | 356 [355–356] | 139 [136–142] | 121 [120–122] | 2.9× |
| 100 clients, saturated fan-out: app process RssAnon | 792 [791–792] | 309 [309–310] | 116 [114–119] | 99.2 [98.4–100.0] | 3.1× |
| 100 clients, saturated fan-out: serving processes Pss | 691 [690–693] | 432 [432–432] | 139 [136–142] | 121 [120–122] | 3.6× |
| 100 clients, saturated fan-out: whole container Pss | 964 [961–967] | 432 [432–433] | 139 [136–142] | 121 [120–122] | 3.6× |
| 500 clients, all subscribed, idle: app process Pss | 617 [617–617] | 363 [360–365] | 141 [138–144] | 118 [117–118] | 3.1× |
| 500 clients, all subscribed, idle: app process RssAnon | 762 [760–764] | 316 [314–318] | 119 [116–123] | 96.0 [95.5–96.5] | 3.3× |
| 500 clients, all subscribed, idle: serving processes Pss | 680 [680–680] | 456 [455–458] | 141 [138–144] | 118 [117–118] | 3.9× |
| 500 clients, all subscribed, idle: whole container Pss | 953 [952–954] | 458 [456–459] | 141 [138–144] | 118 [117–118] | 3.9× |
| 500 clients, saturated fan-out: app process Pss | 784 [761–807] | 377 [371–383] | 170 [170–170] | 118 [118–118] | 3.2× |
| 500 clients, saturated fan-out: app process RssAnon | 928 [903–953] | 331 [325–336] | 148 [148–149] | 96.2 [96.0–96.3] | 3.4× |
| 500 clients, saturated fan-out: serving processes Pss | 857 [833–881] | 516 [508–524] | 170 [170–170] | 118 [118–118] | 4.4× |
| 500 clients, saturated fan-out: whole container Pss | 1,129 [1,106–1,152] | 517 [508–525] | 170 [170–170] | 118 [118–118] | 4.4× |
| 1000 clients, all subscribed, idle: app process Pss | 678 [667–689] | 394 [389–399] | 169 [167–170] | 126 [126–126] | 3.1× |
| 1000 clients, all subscribed, idle: app process RssAnon | 822 [808–835] | 347 [342–352] | 147 [145–149] | 104 [104–105] | 3.3× |
| 1000 clients, all subscribed, idle: serving processes Pss | 792 [782–802] | 546 [533–559] | 169 [167–170] | 126 [126–126] | 4.3× |
| 1000 clients, all subscribed, idle: whole container Pss | 1,065 [1,054–1,076] | 547 [534–561] | 169 [167–170] | 126 [126–126] | 4.3× |
| 1000 clients, saturated fan-out: app process Pss | 991 [986–995] | 423 [418–429] | 218 [217–219] | 125 [125–126] | 3.4× |
| 1000 clients, saturated fan-out: app process RssAnon | 1,135 [1,133–1,137] | 376 [370–382] | 196 [196–196] | 104 [103–104] | 3.6× |
| 1000 clients, saturated fan-out: serving processes Pss | 1,112 [1,089–1,135] | 600 [600–601] | 218 [217–219] | 125 [125–126] | 4.8× |
| 1000 clients, saturated fan-out: whole container Pss | 1,381 [1,357–1,406] | 600 [600–600] | 218 [217–219] | 125 [125–126] | 4.8× |
