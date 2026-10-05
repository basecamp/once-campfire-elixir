# Aborted A/B: further-perf vs PR #1 (Docker Desktop, Apple M3, October 5, 2026)

This run alternated `campfire-elixir:further-perf` (elixir slot) with the unmodified PR #1 image
`campfire-elixir:pr1` (48609bd with the arm64 Thruster path; reference slot). The harness
stopped in the first PR rep: `POST /rooms/:id/messages` at c=16 returned one 500 out of 4,094
requests, and the harness rejects any invalid response. Only `further-perf` rep 1 completed, with
every response valid. It is kept as raw evidence, not as a result.

Cause, reproduced outside the harness with a debug build that logged the exceptions
`Campfire.Endpoint` rescues: a race in `Campfire.FragmentCache.fetch/3`. When the cache passed
64 MB, eviction ran `:ets.delete_all_objects` before re-inserting the `:bytes` counter, and a
concurrent `:ets.update_counter(:bytes, …)` raised `ArgumentError`. Sustained posting fills the
cache every few thousand messages, so the error showed up about once in 40,000 posts. It was in
both images. `further-perf` hit it too in longer repro runs, and SQLite `mmap_size` was ruled out
by an A/B. It is fixed in e14c105, and the completed comparison uses `pr1-fix` (48609bd plus
only that fix) as the baseline: `further-perf-vs-pr1-macos-m3-20261005`.
