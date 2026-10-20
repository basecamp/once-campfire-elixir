# The remaining 2.7 ms is the per-request `PRAGMA data_version`

Marks inside each remaining segment, at 64 clients, cumulative microseconds from the front of the
pipeline:

| mark | cumulative | segment |
|---|---:|---|
| `guard_start` (BrowserGuard entry) | 2,721 | everything before it: ~2.7 ms |
| `guard_end` | 2,752 | whole BrowserGuard 31 µs |
| `hit_auth` | 2,776 | session + browser session 24 µs |
| `hit_accessible` | 2,783 | room authorization 7 µs |
| `hit_key` | 2,786 | cache key 3 µs |
| `hit_replay` | 2,882 | ETS lookup + headers 96 µs |
| `sent` | 2,936 | `send_resp` 54 µs |
| `request_total` | 2,940 | — |

Between the timeline's start plug and `guard_start` there is only `plug(:match)` (measured at 2.3 µs
in the previous run) and `CacheEpoch`, which calls `DB.data_version/0`. So the 2.7 ms is that one
call; the matcher, BrowserGuard, session resolution, authorization, cache key, the ETS lookup, the
replay and the socket write together are under 200 µs.

## Why the call is expensive, and why direct connections did not help

With two pooled readers at ~20k req/s, the pool is at capacity, which requires roughly 100 µs of
service per pragma read. Reading it on four per-process connections instead (atomic slot checkout,
no message pass) measured slower at every client count, so the cost is not the message and not the
pool size: the pragma read itself costs on the order of 100 µs under this workload.

## The decision this leaves

Per-request reads of `data_version` are the ceiling. Removing them changes the documented guarantee
that a commit retires cached entries immediately, so it is a product decision rather than a
refactor:

- a short TTL on the version (one millisecond measured +13% at 16 clients, no change at 64);
- publish the generation from the writer on commit, with a periodic reconcile for connections
  outside the application.

Everything else on the path is now measured and accounted for.
