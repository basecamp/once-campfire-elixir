# further-perf round 3 vs round 2 (Docker Desktop, Apple M3, October 5, 2026)

Two alternating A/B runs of the same two images through the same harness, seed and CPU split
(4 app vCPUs, 4 load-generator vCPUs), with request logging off:

- **Baseline (`reference` slot):** `campfire-elixir:further-perf-r2`, `c81bd37`.
- **Candidate (`elixir` slot):** `campfire-elixir:further-perf-r3`, `a34e991`.

1. `../further-perf-round3-macos-m3-20261005`: `SUITES="http cable"`, 3 reps.
2. This directory: `SUITES="http"`, 3 reps, run straight after as a confirmation, because rep 1
   of the first run was disturbed.

```sh
SKIP_LEDGER=1 HTTP_SECS=4 LOAD_WAIT_SECS=120 ELIXIR_IMAGE=campfire-elixir:further-perf-r3 \
  REFERENCE_IMAGE=campfire-elixir:further-perf-r2 SUITES="http" \
  bench/docker-desktop/run --apps elixir,reference --reps 3 --out DIR
bench/docker-desktop/compare "DIR:reference" "DIR:elixir"
```

Every validation passed with zero errors in all twelve reps. Decoded bodies and gzip sizes are
byte-identical between the images on every validated route.

**Host noise was high.** In the first run, round 3's rep 1 was 30–40% slower on nearly every
route, including ones these changes don't touch, so its medians understate round 3. In this run,
the baseline's rep 3 was disturbed (messages page 2,518 req/s against about 7,000 in the other
reps). CPU per successful request is the steadier measure. By that measure the two runs agree:

| c=16 CPU µs/request | Round 2 | Round 3 |
|---|---:|---:|
| Room page | 590 (run 1) / 707 (run 2) | 510 / 529 |
| Messages page | 489 / 551 | 528 (rep 1 disturbed; 421 in rep 3) / 455 |
| Sidebar | 712 / 757 | 811 (rep 1 disturbed; 658 in rep 3) / 690 |
| Search | 596 / 713 | 616 / 630 |

Medians from this directory (see [compare.md](compare.md)): room page 5,112 → 7,188 req/s, messages
page 6,757 → 7,585, sidebar 4,868 → 5,398, search 5,136 → 5,986. Comparing the cleanest reps
gives a lower but consistent estimate: about 15–20% less CPU on the room page and about 10–15% on
the messages page. The sidebar and search gain a few percent from the cached cookie and
User-Agent parsing. Post message, cable and static routes are unchanged.

What round 3 changes: a cached room shell keyed by its template inputs, the messages page's
parts and gzip kept per ETag, memo entries in their own bounded table, cached session-cookie
verification (expiry still checked) and User-Agent parsing, single-query paging, the original
room folded into the account query, and byte-level cache keys.

`bench/docker-desktop/compare` now tolerates result files without a cable or HTTP suite.

Next unresolved work:

- Both pages still run 3–4 SQLite queries per request: session and user, room, messages, and
  account on the room page. In the profiles, query execution and row-to-map conversion are about
  20% of the work.
- The Front/Plug pipeline costs about 65–70 µs per request even on `/up`.
- Post message (≈1,800 µs/request) and cable fan-out remain as in round 2.
