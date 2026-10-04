# Performance fork: plan and measurements

Branch `perf`. Goal: remove the per-request work that the baseline Elixir port does on
every dynamic request and that the Rust and Go ports avoid, then measure each step
cumulatively against the unmodified baseline with the repository's own load generator.

## Method

`bench/local-run` runs this checkout natively on the development machine (Apple M5,
10 cores, macOS): a `mix release` built from the working tree, the same
`test/fixtures/seed.json` rooms as the Rust seed's labels (busy room 486777696 with 131
messages, writes to HQ 201306877), the same routes, concurrency levels, validation
(`bench/validate.py preflight`) and `bench/loadgen` as `bench/run`. Differences from the
README's container measurements:

- No Docker, no Thruster in front, no cpuset pinning, no cgroup CPU accounting. CPU per
  response is the process tree's CPU time (`ps`) divided by successful responses.
- Redis runs as a local `redis-server` on port 47179 for variants that use it.
- The upload suite is skipped (no libvips/ffmpeg locally).
- Numbers are only comparable with other `bench/local-run` results from this machine.

Each step is one commit. After each, `mix test --warnings-as-errors` runs under the pinned
toolchain (`mise.toml`: Erlang 28.4.1, Elixir 1.19.5-otp-28) and `bench/local-run --label
stepN` records two reps. `bench/local-report` compares directories.

## Steps

0. `baseline`: unmodified `main` (`3498c18` + docs), Redis on.
1. `step1-gzip`: zlib level 1 instead of default for dynamic and static responses.
2. `step2-cache`: in-memory cache of complete compressed responses for room, messages,
   search and sidebar pages, keyed on the authenticated user, CSRF session, route inputs
   and a database write generation; static assets cached compressed with their metadata.
3. `step3-noredis`: in-process broadcasts (Registry), fragment cache (ETS), rate limiter
   and job queue; Redis becomes optional and is not started by default.
4. `step4-dbpool`: reads round-robin over pooled SQLite reader processes with cached
   prepared statements; a single writer process keeps transactions serialized.
5. `step5-pipeline`: response pipeline cleanups (no re-hashing or re-scanning of cached
   bodies, cheaper per-request plugs).

Results are appended below as they complete.

## Results (October 4, 2026, Apple M5, two reps each, medians)

Full tables: `bench/results/local/report.md`. Final = `step5-level6` (the committed
defaults: gzip level 6, no Redis).

| 16 concurrent | baseline | step1 | step2 | step3 | step4 | step5 | final (level 6) |
|---|---:|---:|---:|---:|---:|---:|---:|
| room_show req/s | 1,226 | 1,400 | 4,366 | 3,984 | 9,706 | 11,265 | 12,130 |
| messages_page req/s | 1,619 | 1,967 | 2,903 | 2,830 | 3,876 | 3,866 | 3,901 |
| sidebar req/s | 1,600 | 1,681 | 4,972 | 4,390 | 11,601 | 13,095 | 13,352 |
| search req/s | 1,673 | 1,965 | 5,210 | 5,042 | 12,650 | 13,308 | 13,697 |
| post_message req/s | 888 | 910 | 847 | 973 | 1,130 | 1,206 | 1,269 |
| avatar req/s | 2,438 | 2,638 | 2,555 | 2,301 | 5,926 | 6,647 | 6,630 |
| static_css req/s | 10,252 | 10,709 | 25,504 | 25,062 | 24,145 | 26,437 | 27,226 |
| room_show p99 ms | 16.4 | 15.1 | 5.86 | 6.92 | 4.10 | 2.47 | 2.04 |
| 1,000-client fan-out msgs/s | 94.3 | 93.8 | 91.0 | 129 | 136 | 142 | 140 |
| peak RSS MB | 1,472 | 1,376 | 1,274 | 356 | 368 | 372 | 369 |

A baseline rerun at the end of the session came out 5–10% below the first baseline
(`baseline-rerun`), which bounds the drift across the hour of measurements.

Findings:

- The gzip level stopped mattering once pages were cached (`step5-pipeline` at level 1
  and `step5-level6` are within noise), so the default returned to Rack's level 6 and
  the wire bytes match Rails again. The Rust port also compresses at level 6; its
  speed comes from splicing fragments compressed once, not from a lower level.
- `step4-spinpool` (readers checked out to the request process through an atomics slot
  table) was faster at 16 clients but spun under 64; reader processes replaced it.
- CPU per response for `post_message` rose after step 4 while throughput improved.
  `probe-sbwt` (the final build with `+sbwt none +sbwtdcpu none +sbwtdio none`) halves
  that figure (6,287 → 3,268 µs), so most of it is scheduler busy-wait rather than
  work, but it also costs 5–15% throughput on the cached pages, so the VM defaults stay.
- All 1,857 non-media unit tests pass at every step; the 39 failures are the libvips
  and ffmpeg media tests, which cannot run without those binaries on this machine.
  Every benchmark run ended with the job queue drained and no failed jobs.

Next unresolved work: cache the messages page without its query (it still renders
through the fragment cache on every request); cut the two frames per client per post
in Cable fan-out; profile the fixed per-request cost that `/up` shows; run the
parity gates (Chromium, mutation, Rails comparison) in the Docker toolchain, which
this machine does not have; measure in the production container with Thruster.
