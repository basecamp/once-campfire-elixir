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
4. `step4-dbpool`: pooled SQLite read connections used directly from the request process
   with cached prepared statements; a single writer process keeps transactions serialized.
5. `step5-pipeline`: response pipeline cleanups (no re-hashing or re-scanning of cached
   bodies, cheaper per-request plugs).

Results are appended below as they complete.
