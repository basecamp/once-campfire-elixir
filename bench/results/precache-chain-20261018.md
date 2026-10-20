# What inflates the pre-cache plug chain, and the 500s it exposed

Same host, quiet, gzip, validated responses. Requests carry a per-request timestamp at the pipeline
entry and marks at each plug boundary, averaged over a window.

## The chain itself is cheap; one call is not

At 64 clients, cumulative microseconds from the request entering the pipeline:

| mark | cumulative µs |
|---|---:|
| public_files | 9 |
| http_response | 11 |
| request_context | 15 |
| route_recognition | 16 |
| epoch_start (inside CacheEpoch) | 22 |
| **epoch_done** | **3,320** |
| browser_guard | 3,320 |
| cache_plug | 3,348 |

The whole pre-cache chain — RequestURL, PublicFiles, Plug.Head, HttpResponse, Parsers,
MethodOverride, request_context, account_format, RouteRecognition, match — costs 22 µs together.
Everything between `epoch_start` and `epoch_done` is a single `ResponseCache.snapshot()` call, which
measures 4.68 µs on its own (5.05 µs aggregated across 64 callers). Under load that one call into
the cache process is 3.3 ms.

## The 500s this uncovered

Measuring at 64 clients surfaced 12 responses with status 500 in 142,000. They did not come from the
endpoint rescue but from BrowserGuard, which turns ArgumentError into a 500. The ArgumentError was
`ets:insert` with a bad table identifier: both ETS memos created their table lazily in whichever
request process touched it first — a Bandit connection process — so the table died when that
connection closed and concurrent inserts raced against its recreation.

Fixed by owning the tables in `Campfire.Tables` under the supervisor, with both memos falling back
to computing the value when a table is missing.

## Numbers after the fix

| clients | before | after |
|---:|---:|---:|
| 16 | 17,059 | 22,553 |
| 64 | 17,621 | 22,526, no invalid responses |

## What is left

The single `snapshot()` call per request is now the last serialised step on the request path, and it
is 3.3 ms deep at 64 clients because every request queues behind one process that also reads SQLite
for `PRAGMA data_version`. Moving the observation off the request path changes the invalidation
contract (a commit must retire entries immediately), so it needs a decision rather than another
measurement.
