# further-perf vs PR #1 (Docker Desktop, Apple M3, October 5, 2026)

An alternating A/B of two images through the same harness, seed and CPU split (4 app vCPUs,
4 load-generator vCPUs), with request logging off for both:

- **Baseline (`reference` slot):** `campfire-elixir:pr1-fix`, PR #1 head `48609bd` plus only the
  FragmentCache race fix `e14c105`, built with the arm64 Thruster path. The unmodified PR image
  returned rare 500s on `post_message` that abort the harness (see the `-aborted` directory).
- **Candidate (`elixir` slot):** `campfire-elixir:further-perf` at `e14c105`.

```sh
SKIP_LEDGER=1 HTTP_SECS=4 LOAD_WAIT_SECS=120 ELIXIR_IMAGE=campfire-elixir:further-perf \
  REFERENCE_IMAGE=campfire-elixir:pr1-fix SUITES="http cable" \
  bench/docker-desktop/run --apps elixir,reference --reps 3 --out bench/results/further-perf-vs-pr1-macos-m3-20261005
bench/docker-desktop/compare "DIR:reference" "DIR:elixir"
```

Every HTTP and cable validation passed with zero errors in all six reps. The per-rep spread was
small: room_show c=16 ran 2,001–2,143 req/s on the baseline and 4,459–4,848 on further-perf.

What further-perf changes on top of the PR (one commit each):

1. Thruster replaced by the in-process `Campfire.Front` (ported from `various-improvements`),
   with gzip at zlib level 1.
2. CSRF tokens replaced by `Sec-Fetch-Site`/`Origin` checks. Pages carry no tokens, and the
   `_campfire_session` cookie is decrypted once per request and written only when it changes.
3. Boot adds `index_messages_on_room_id_and_created_at`, and SQLite mmap is off.
4. `session_token` is re-signed only on start or the hourly refresh, `last_room` is written
   only on change, and the session and user load in one joined query.
5. Spliced pages take their ETag from cached fragment digests, the invitation count is bounded,
   and complete gzipped bodies are sent with Content-Length.

Medians of 3 rounds: see [compare.md](compare.md). Highlights at c=16:

| Route | Baseline req/s | further-perf req/s | CPU µs/request |
|---|---:|---:|---:|
| Room page | 2,057 | 4,765 (2.3×) | 1,777 → 805 |
| Messages page | 1,398 | 3,287 (2.4×) | 2,603 → 1,087 |
| Sidebar | 2,463 | 4,303 (1.7×) | 1,527 → 902 |
| Search | 1,767 | 4,474 (2.5×) | 2,075 → 838 |
| Post message | 1,596 | 2,227 (1.4×) | 2,354 → 1,658 |
| `/up` | 12,154 | 59,839 (4.9×) | 275 → 66 |
| Cable, 1,000 clients | 128 broadcasts/s | 206 (1.6×) | |

Peak anonymous memory fell from 497 to 339 MiB. Cold start was 1,076 vs 1,188 ms, within this
host's noise.

Response sizes: the room page's decoded body is 417,155 bytes against the baseline's 463,753,
because the per-form `authenticity_token` inputs are gone. On the wire it is 33,082 bytes against
25,136, because of level-1 deflate. The messages page is 384,885 against 430,965 decoded and
20,556 against 12,089 on the wire.

Caveats:

- **Host noise:** the Mac's load average was 5–10 during the run (desktop apps and idle
  database containers). The VM load gate (1.5) held before each rep. Alternation balances the
  noise, but compare only against runs in this same environment.
- **Parity ledger:** skipped. The sessions, data, views, jobs, realtime and operations contracts
  are pending in `plans/contracts.json`. The parity and browser gates have not been re-run for
  these changes.
- **Upload suite:** not run (`SUITES="http cable"`).

Next unresolved work:

- Re-run the parity gates on the Linux rig. Update `parity/http.py` and the browser flows for
  token-free markup, and rewrite the jobs, realtime and operations legs for the in-process
  design.
- Cable fan-out at 1,000 clients (206 broadcasts/s here; Rust 1ea6d6f measured 394 on
  this machine in the `various-improvements` branch's results): profile per-connection websocket writes.
- The account row and logo lookup are still queried on every page. Caching them needs
  invalidation wherever `accounts` and the logo attachment change.
