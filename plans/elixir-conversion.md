# Conversion state

Jobs run on an in-process, non-durable queue and Action Cable delivery is in
process, as in the Rust port (see README, Known differences). The compatibility
contracts are recorded against Rails `90b330024dec3e757c79b6a7e6568f93da8e3148`.
The complete tuned run passed 65 gates and 1,929 tests. Raw scopes, logs, runtime results and the source digest are
in `parity/results/verification.json` and `contracts.json`.

The project follows rails-to-rust: immutable reference, source inventory, live
oracles, captured compatibility vectors, generated records/routes, toolkit and
migration skills, HTTP/mutation comparisons, and production rollback evidence.
The unchanged frontend runs on the native BEAM implementation. The production
package also includes the same pinned Thruster 0.1.23 binary for TLS/HTTP2, proxy
caching, compression, timeouts and startup behavior. Its upstream is private.

Verification includes actual Chromium composer uploads and administration/profile
flows; session/form interchange; all-table/FTS/storage mutation snapshots and
injected transaction failures; message/room/user Cable effects and revocation;
signed storage/range/embed and media operations; actual queue claims/failures/drain,
webhook protocol/timeout cases and encrypted HTTPS push delivery; fresh schema/setup,
ONCE backup/restore, TLS/HTTP2, in-flight HTTP shutdown and production Rails→Elixir→Rails
rollback. Rich-text comparisons retain the explicit escaping/error rules in
`richtext-comparison.md`. No production cutover has been performed.

The requested benchmark and performance pass is complete. Both baseline and tuned
measurements use two balanced alternating rounds per app, the Rust port's unchanged
populated seed, production images, matched CPU sets and validated responses. The
final build has zero HTTP errors, complete Cable delivery to every client, valid
upload/thumbnail responses and empty native job queues at the end of both rounds.

Tuning improved static CSS throughput 8.07×, 1,000-client fanout 3.42× and message
posting 1.65×. Peak anonymous memory fell from 983.5 to 564.0 MB. Room rendering
improved 1.27×, reaching 751.1 requests/s at 64 connections; Rust reaches 19,560.3.
The native fanout rate reaches 60.2 messages/s to 1,000 clients; Rust reaches 494.9.
The implementations retain their own response sizes, compression and production
process models. These short samples are workload comparisons, not production sizing.

Raw HTTP, Cable, upload, latency, CPU, memory, startup, preflight and queue-state
results are in `bench/results/baseline-20261004/` and
`bench/results/tuned-fifo-20261004/`. The before/after table is
`bench/results/tuning-comparison.md`; profiling and changes are described in
`bench/TUNING.md`. The aborted latest-frame-only attempt is retained separately
and is rejected by benchmark reports.

The later frozen `b6b82e5` → `7c1ed67` comparison records four balanced rounds on
native x86_64 Linux and native ARM64 Linux under OrbStack. The clean x86_64 run
regressed populated dynamic HTTP throughput 16–47% at concurrency 16 and Cable
throughput 5–20%. The ARM64 response observations were mostly faster but are not a
clean performance result: unrelated shared-host contention occurred and one candidate
round retained 1,125 queued jobs. Both complete platform tables and all raw rounds are
retained under `bench/results/`; no universal performance improvement is claimed.

All authorized conversion, verification, benchmark and tuning evidence is recorded.
The port does not match Rust's measured capacity. No production deployment was requested.

