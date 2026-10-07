# further-perf round 4 vs round 3 (Docker Desktop, Apple M3, October 5, 2026)

An alternating A/B through the same harness, seed and CPU split (4 app vCPUs, 4 load-generator
vCPUs), with request logging off:

- **Baseline (`reference` slot):** `campfire-elixir:further-perf-r3`, `a34e991` (round 3).
- **Candidate (`elixir` slot):** `campfire-elixir:further-perf-r4`, `cc47003`.

```sh
SKIP_LEDGER=1 HTTP_SECS=4 LOAD_WAIT_SECS=120 ELIXIR_IMAGE=campfire-elixir:further-perf-r4 \
  REFERENCE_IMAGE=campfire-elixir:further-perf-r3 SUITES="http cable" \
  bench/docker-desktop/run --apps elixir,reference --reps 3 --out bench/results/further-perf-round4-macos-m3-20261005
bench/docker-desktop/compare "DIR:reference" "DIR:elixir"
```

Every HTTP and cable validation passed with zero errors in all six reps. Decoded bodies and gzip
sizes are byte-identical between the images on every validated route.

Host noise depressed the baseline's reps 1 and 2. Round 3's rep 3 matches its earlier runs, so
it is the fair comparison. Round 4's three reps agree within a few percent. CPU per successful
request at c=16:

| Route | Round 3 (rep 3) | Round 4 (reps 1–3) | req/s, round 4 |
|---|---:|---:|---:|
| Room page | 509 µs | 218–277 µs | 13,660–18,098 |
| Messages page | 415 µs | 156–166 µs | 23,252–25,256 |
| Sidebar | 691 µs | 123–126 µs | 31,277–32,159 |
| Search | 629 µs | 140–142 µs | 27,772–28,083 |
| Post message | 1,749 µs | 1,323–1,409 µs | 2,113–2,212 |
| `/up` | 69 µs | 42–45 µs | 84,575–93,160 |

The medians in [compare.md](compare.md) include the disturbed baseline reps and overstate the
gains (room page 3.2×, sidebar 8.3×). By the clean comparison, the room page uses about 2.2×
less CPU, the messages page 2.6×, the sidebar 5.5×, search 4.5×, posting about 23% less and
the pipeline about 36% less. Cable fan-out is unchanged, at about 200 broadcasts/s at 1,000
clients.

Peak anonymous memory rose from 326 to 396 MiB, from the memo table (bounded at 64 MiB of
counted entries) holding cached reads, shells and gzip bodies.

What round 4 changes:

- **Read cache:** reads are kept until a table they read is written (DB.cached/3, with
  generations bumped after each commit). Outside commits are caught through the WAL index
  header.
- **Pipeline:** memoized header parsing; no cookie parsing without a session cookie; one-pass
  security headers; the gzip of whole bodies kept by digest; PublicFiles' fast pass-through.
- **Sidebar and search:** the sidebar is kept by table generations, and search keeps its shell
  by inputs.
- **Posting:** 31 → 16 SQL statements per post, from a fragment rendered from the request's
  records, cached bans and attachments, no empty embed sync, and a leaner push job.

Next unresolved work:

- **Posting** (≈1,350 µs) is now dominated by its 6-statement write transaction, the WAL commit,
  and the broadcast to cable subscribers.
- **Cable fan-out** at 1,000 clients remains socket-write bound.
- **Parity:** the gates have not been re-run for rounds 1–4. The contracts in
  `plans/contracts.json` stay pending.
