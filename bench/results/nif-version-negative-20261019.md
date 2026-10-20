# Per-process SQLite connections for `PRAGMA data_version`: measured, slower, reverted

The timeline put 3.2 ms of a cached room page between the `route_recognition` mark (15 µs) and the
`browser_guard` mark (3,211 µs). Two things run in that window: `plug(:match)` and the
`CacheEpoch` plug, which called `DB.data_version/0` — a `GenServer.call` to one of two pooled
readers. Queueing arithmetic on that segment (23k req/s, two servers, ~74 calls in flight) implied a
service time near 87 µs per pragma, so the call looked like the cost.

Following the suggestion to read the pragma on a connection the caller uses directly, the version
lookup became four read-only SQLite connections kept in `:persistent_term` and checked out with an
atomic compare-and-exchange, so a request reads the pragma in its own process with no message pass.

Measured with the same harness, same seed, medians of two rounds:

| clients | pooled GenServer calls | direct connections |
|---:|---:|---:|
| 16 | 23,930 | 22,244 |
| 64 | 23,157 | 21,095 |
| 256 | 21,431 | 20,368 |

Slower at every point, so the call was not the cost and the experiment was reverted. The lesson is
the one this session keeps repeating: the request-path segment that the marks bracket is not
necessarily the work the marks name.

## What is still unexplained

The 3.2 ms sits between two adjacent plugs with only `plug(:match)` and `CacheEpoch` between them,
and it is not `CacheEpoch`. That leaves `plug(:match)`: the router's matcher walks its clause table
for every request. It was measured at about 10 µs once, but that measurement used a request whose
match was early in the table; the room page's route is not, and the table has grown to roughly 150
clauses.

The next check is a mark immediately before and after `plug(:match)`, which distinguishes the
matcher from what follows it without changing any behaviour.
