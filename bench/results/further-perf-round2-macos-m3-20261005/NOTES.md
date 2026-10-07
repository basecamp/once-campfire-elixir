# further-perf round 2 vs round 1 (Docker Desktop, Apple M3, October 5, 2026)

An alternating A/B of two images through the same harness, seed and CPU split (4 app vCPUs,
4 load-generator vCPUs), with request logging off for both:

- **Baseline (`reference` slot):** `campfire-elixir:further-perf-otp29`, `9ab39f9` (round 1 on
  Elixir 1.20.4 / OTP 29.1.1).
- **Candidate (`elixir` slot):** `campfire-elixir:further-perf-r2`, `03874d7`.

```sh
SKIP_LEDGER=1 HTTP_SECS=4 LOAD_WAIT_SECS=120 ELIXIR_IMAGE=campfire-elixir:further-perf-r2 \
  REFERENCE_IMAGE=campfire-elixir:further-perf-otp29 SUITES="http cable" \
  bench/docker-desktop/run --apps elixir,reference --reps 3 --out bench/results/further-perf-round2-macos-m3-20261005
bench/docker-desktop/compare "DIR:reference" "DIR:elixir"
```

Every HTTP and cable validation passed with zero errors in all six reps. The decoded bodies of
every validated route are byte-identical between the two images (same SHA-256), since these are
pure performance changes. The messages page's gzip grew from 20,556 to 23,167 bytes, because
its first fragment piece is compressed without the page text as a dictionary.

The changes were found with `bench/docker-desktop/profile` (eprof, in `../profile-macos/`):
spliced gzip for the messages page and search, a cache of the compressed per-request page text,
the batched sidebar query, memoized avatar signatures, one account query per page, compiled asset
paths, single-pass escaping, regex-free timestamp digits and cached environment values.

Medians of 3 rounds: see [compare.md](compare.md). Highlights at c=16:

| Route | Round 1 req/s | Round 2 req/s | CPU µs/request |
|---|---:|---:|---:|
| Room page | 4,650 | 6,781 (1.46×) | 811 → 564 |
| Messages page | 3,423 | 8,158 (2.38×) | 1,063 → 465 |
| Sidebar | 4,007 | 5,906 (1.47×) | 946 → 636 |
| Search | 4,345 | 6,494 (1.49×) | 852 → 584 |

Post message, cable fan-out, avatar, CSS and `/up` are unchanged within noise, as expected.

Caveats:

- **Host noise:** the Mac's load average was 1.5–4 during the run. Alternation balances it, but
  compare only against runs in this same environment.
- **Parity ledger:** skipped. The pending contracts in `plans/contracts.json` are unchanged.

Next unresolved work:

- **Post message:** 1,680 µs/request, unchanged by this round. eprof's analysis comes back empty
  with the many short-lived job processes, so it needs another profiler (`tprof` or sampling).
- **Cable fan-out at 1,000 clients:** about 215 broadcasts/s. The profile is dominated by socket
  writes (`port_command`), with Bandit's per-frame serialization and stats bookkeeping next.
- **Read-connection checkout:** NimblePool's checkout was under 1% in the profiles, so the atomic
  claim from `various-improvements` was not ported.
