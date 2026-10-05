# Four-round native Linux comparison: complete, with tail regressions

Baseline is untouched upstream; candidate is the verified reader/cache application. This is not an isolated attribution of all gains to statement caching.

## HTTP throughput and paired ranges

Each arm cell is median [min–max] over four rounds. Paired changes compare candidate/baseline within the same round; these ranges are descriptive, not confidence intervals. p99 is the median of four cell p99s, not a pooled percentile. Positive CPU or latency changes are worse.

**CPU limitation:** Derived CPU/success is retained, but raw per-cell cgroup before/after counter pairs are not. Raw/enriched load-generator records can be compared; CPU deltas cannot be independently reconstructed from retained counters.

| Route | c | Baseline req/s | Candidate req/s | Median change | Paired changes | p99 median change | CPU/success median change |
|---|---:|---:|---:|---:|---:|---:|---:|
| room_show | 1 | 100.3 [93.2–105.7] | 114.4 [106.2–121.5] | +14.0% | +4.7 to +22.4% | -26.7% | -15.5% |
| room_show | 16 | 287.6 [277.4–313.7] | 343.2 [322.1–366.1] | +19.4% | +4.7 to +29.1% | +0.9% | -6.1% |
| room_show | 64 | 302.8 [281.8–310.2] | 320.8 [313.5–337.3] | +5.9% | +2.0 to +14.8% | +54.4% | +6.2% |
| messages_page | 1 | 137.5 [118.5–138.9] | 147.4 [139.0–150.7] | +7.2% | +0.7 to +27.2% | -13.6% | -9.1% |
| messages_page | 16 | 392.4 [374.6–418.2] | 453.6 [431.6–456.0] | +15.6% | +9.0 to +20.8% | +27.5% | -4.9% |
| messages_page | 64 | 397.6 [381.0–420.8] | 418.3 [404.5–423.7] | +5.2% | +0.7 to +8.5% | +87.0% | +2.9% |
| sidebar | 1 | 248.8 [199.3–277.1] | 293.8 [283.1–304.9] | +18.1% | +10.0 to +43.8% | -16.3% | -11.3% |
| sidebar | 16 | 449.0 [411.4–465.4] | 733.1 [717.1–749.3] | +63.3% | +55.9 to +80.1% | -26.1% | -24.7% |
| sidebar | 64 | 448.3 [418.6–457.1] | 728.0 [716.7–769.0] | +62.4% | +56.8 to +74.0% | -31.5% | -24.4% |
| search | 1 | 177.3 [165.7–182.5] | 234.4 [214.3–244.9] | +32.2% | +22.4 to +40.0% | -25.9% | -26.7% |
| search | 16 | 415.8 [404.2–422.9] | 641.6 [634.5–652.2] | +54.3% | +53.7 to +57.0% | -23.5% | -22.9% |
| search | 64 | 441.7 [431.9–451.6] | 632.7 [624.3–652.7] | +43.2% | +38.7 to +51.1% | -3.1% | -17.2% |
| avatar | 1 | 4,245.0 [3,673.8–4,468.7] | 4,515.1 [4,203.6–4,706.5] | +6.4% | +4.0 to +14.4% | -7.3% | -6.2% |
| avatar | 16 | 25,287.2 [24,568.2–27,610.7] | 26,249.7 [25,174.5–28,563.8] | +3.8% | -0.5 to +7.1% | -6.0% | -3.3% |
| avatar | 64 | 19,203.2 [18,540.6–20,899.2] | 19,294.7 [18,959.1–19,910.7] | +0.5% | -8.2 to +4.7% | -0.2% | +0.1% |
| static_css | 1 | 5,183.8 [5,065.9–5,408.4] | 5,211.1 [5,065.3–5,371.3] | +0.5% | -6.3 to +6.0% | -0.6% | +0.8% |
| static_css | 16 | 34,905.7 [33,556.9–35,547.6] | 36,111.7 [33,878.7–40,452.1] | +3.5% | -1.1 to +14.2% | -4.0% | -2.5% |
| static_css | 64 | 29,708.7 [27,507.1–31,887.5] | 29,005.2 [27,324.0–29,675.3] | -2.4% | -14.3 to +3.2% | +1.7% | +2.5% |
| up | 1 | 976.0 [905.0–1,039.4] | 1,297.8 [1,209.3–1,335.9] | +33.0% | +21.7 to +44.2% | -21.6% | -22.7% |
| up | 16 | 3,253.2 [3,016.2–3,281.6] | 4,402.6 [4,122.1–4,518.1] | +35.3% | +26.7 to +43.4% | -31.1% | -27.9% |
| up | 64 | 3,270.2 [2,976.6–3,367.1] | 4,380.3 [4,157.8–4,482.6] | +33.9% | +29.8 to +39.7% | -19.2% | -28.6% |
| post_message | 1 | 85.9 [72.5–89.6] | 143.9 [138.2–155.0] | +67.5% | +63.6 to +97.7% | -30.5% | -20.6% |
| post_message | 16 | 273.4 [251.8–307.0] | 396.3 [354.1–400.2] | +45.0% | +28.8 to +50.8% | -23.3% | -17.7% |
| post_message | 64 | 297.8 [260.1–319.4] | 384.4 [375.6–393.6] | +29.1% | +21.6 to +44.4% | -26.4% | -6.7% |

## High-concurrency rendering tails remain unresolved

| Route | c | Baseline p99 ms | Candidate p99 ms | Paired p99 change | Baseline CPU µs/success | Candidate CPU µs/success |
|---|---:|---:|---:|---:|---:|---:|
| room_show | 16 | 82.271 [66.239–94.527] | 82.975 [74.111–89.855] | -19.4 to +35.6% | 12,322.0 [11,420.4–12,660.5] | 11,569.6 [10,841.9–12,313.7] |
| room_show | 64 | 260.031 [240.895–310.783] | 401.407 [341.247–401.663] | +29.1 to +66.7% | 11,617.6 [11,423.1–12,471.2] | 12,334.7 [11,699.1–12,630.8] |
| messages_page | 16 | 61.855 [56.895–70.911] | 78.879 [74.943–86.207] | +5.8 to +45.4% | 9,233.0 [8,650.7–9,630.3] | 8,777.9 [8,735.5–9,152.3] |
| messages_page | 64 | 210.239 [187.519–222.335] | 393.215 [378.879–402.687] | +73.2 to +102.0% | 9,227.2 [8,648.7–9,499.1] | 9,490.4 [9,395.8–9,858.6] |

## HTTP response-body wire bytes

These are integer-truncated mean body bytes from each load-generator cell, with gzip requested. Headers/framing/TCP/TLS are excluded. Full per-cell numbers are in http-cells.csv; the table covers all 12 cells per route and arm. This is not independently decoded per-response content evidence.

All eight retained preflights have equal decoded lengths for each route, including search (165,534 bytes), room (463,753 bytes), messages (430,965 bytes) and sidebar (31,427 bytes). Search wire bodies are about 2.6% smaller in the candidate; no compression setting was changed in this run. These full-run captures alone do not establish normalized equality. A [separate same-image follow-up](README.md#follow-up-tails-persist-without-the-proxy) found identical decoded search content outside validated CSRF values and reproduced the gzip size difference from those values; the original measurements below are unchanged.

| Route | Baseline min–max bytes | Candidate min–max bytes |
|---|---:|---:|
| room_show | 21,232–21,233 | 21,232–21,232 |
| messages_page | 12,080–12,089 | 12,084–12,084 |
| sidebar | 6,106–6,107 | 6,106–6,107 |
| search | 10,259–10,272 | 9,990–9,990 |
| avatar | 3,360–3,360 | 3,360–3,360 |
| static_css | 653–653 | 653–653 |
| up | 88–88 | 88–88 |
| post_message | 2,005–2,006 | 2,004–2,006 |

## Cable, memory, startup and uploads

Cable wire rate is null/unmeasured in every measured case. The separate deflate smoke demonstrates measured nonzero wire rates but is not part of these timings. Memory units are MiB; whole arm-run cgroup peaks include all three suites, not a single HTTP route.

| Workload | Metric | Baseline median [min–max] | Candidate median [min–max] | Median change | Paired changes |
|---|---|---:|---:|---:|---:|
| Cable100 | complete fanouts/s | 135.050 [132.800–140.900] | 175.650 [169.100–184.100] | +30.1% | +20.4 to +38.6% |
| Cable100 | paced all-client p50 ms | 11.511 [11.431–12.663] | 9.543 [9.135–10.455] | -17.1% | -20.1 to -15.5% |
| Cable100 | paced all-client p99 ms | 28.359 [19.583–29.935] | 12.787 [11.175–25.327] | -54.9% | -57.0 to -15.4% |
| Cable100 | saturated all-client p50 ms | 24.743 [24.031–25.503] | 22.223 [21.199–23.167] | -10.2% | -16.9 to -3.6% |
| Cable100 | saturated all-client p99 ms | 40.415 [35.103–44.319] | 35.887 [34.911–35.999] | -11.2% | -19.1 to -0.5% |
| Cable100 | connect all seconds | 0.130 [0.110–0.160] | 0.155 [0.140–0.170] | +19.2% | -6.7 to +45.5% |
| Cable500 | complete fanouts/s | 58.400 [55.700–59.400] | 67.700 [65.500–71.000] | +15.9% | +12.3 to +27.5% |
| Cable500 | paced all-client p50 ms | 20.839 [20.239–22.095] | 19.047 [17.215–20.319] | -8.6% | -16.8 to -3.2% |
| Cable500 | paced all-client p99 ms | 32.551 [29.023–35.231] | 29.031 [22.655–39.679] | -10.8% | -32.2 to +36.7% |
| Cable500 | saturated all-client p50 ms | 60.847 [59.775–61.759] | 59.839 [57.375–60.319] | -1.7% | -7.1 to -0.4% |
| Cable500 | saturated all-client p99 ms | 94.303 [82.367–100.479] | 94.623 [90.175–100.479] | +0.3% | -4.8 to +9.5% |
| Cable500 | connect all seconds | 0.545 [0.520–0.580] | 0.575 [0.510–0.620] | +5.5% | -7.3 to +19.2% |
| Cable1000 | complete fanouts/s | 34.700 [32.300–35.100] | 36.650 [35.600–40.700] | +5.6% | +1.4 to +17.6% |
| Cable1000 | paced all-client p50 ms | 29.935 [28.959–34.303] | 29.519 [28.927–32.511] | -1.4% | -15.6 to +12.3% |
| Cable1000 | paced all-client p99 ms | 46.031 [40.415–48.479] | 41.503 [37.887–55.679] | -9.8% | -18.9 to +20.3% |
| Cable1000 | saturated all-client p50 ms | 106.591 [106.303–115.135] | 108.895 [101.055–111.743] | +2.2% | -4.9 to +5.1% |
| Cable1000 | saturated all-client p99 ms | 158.207 [156.543–187.519] | 177.727 [161.023–194.303] | +12.3% | +0.4 to +24.1% |
| Cable1000 | connect all seconds | 0.990 [0.940–1.070] | 1.075 [1.040–1.250] | +8.6% | +1.9 to +22.5% |
| whole arm-run | idle_current_mb | 145.500 [136.000–152.000] | 145.000 [142.000–150.000] | -0.3% | -3.9 to +5.9% |
| whole arm-run | idle_anon_mb | 111.000 [102.000–117.000] | 110.000 [107.000–115.000] | -0.9% | -5.1 to +6.9% |
| whole arm-run | peak_current_mb | 574.500 [543.000–611.000] | 620.000 [594.000–657.000] | +7.9% | +2.0 to +21.0% |
| whole arm-run | peak_anon_mb | 497.500 [483.000–562.000] | 533.500 [507.000–564.000] | +7.2% | -4.6 to +15.8% |
| whole arm-run | cgroup_peak_mb | 591.500 [580.000–612.000] | 651.000 [632.000–661.000] | +10.1% | +7.1 to +11.0% |
| startup | cold_start_ms | 1,260.000 [1,115.000–1,329.000] | 1,216.000 [1,149.000–1,250.000] | -3.5% | -13.5 to +10.2% |
| upload5 | upload_total_ms | 230.900 [224.300–232.900] | 210.850 [197.400–224.900] | -8.7% | -12.0 to -2.9% |
