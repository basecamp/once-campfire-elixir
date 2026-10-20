# Where the concurrency goes: room_show does not scale

Same host, same load generator, gzip, validated responses. The machine was quiet (load average
about 1) for these runs.

## Ladder at 1, 4 and 64 clients

| endpoint | @1 | @4 | @64 | 1 -> 4 |
|---|---:|---:|---:|---:|
| Bandit, minimal plug, 140 B body | 17,228 | 44,852 | 84,547 | 2.6x |
| Bandit, minimal plug, 20,615 B body | 5,432 | 16,575 | 35,757 | 3.1x |
| Bandit, minimal plug, 20,615 B uncompressed, `compress: false` | 5,556 | 18,071 | 41,905 | 3.3x |
| this port's `/up` (no auth, no cache) | 8,537 | 22,668 | 31,080 | 2.7x |
| this port's room_show, before the cache-key fix | 3,552 | 4,037 | 13,209 | **1.14x** |
| this port's room_show, after the cache-key fix | 3,772 | 8,467 | 12,680 | **2.2x** |
| Express room_show | 6,837 | 17,277 | 44,088 | 2.5x |

## What this rules out

- **Bandit / the transport**: a bare plug on the same server and config scales 2.6 to 3.3x and
  reaches 84k with a small body, 42k with a 20 KB body.
- **The plugin chain in general**: `/up` goes through the same router, security headers, ETag,
  Vary and compression and still scales 2.7x.
- **Our request pipeline in isolation**: calling `Campfire.Router.call/2` directly for a cached hit
  costs 134.7 us on one task and 38.7 us per request across eight tasks, a 3.5x speedup.
- **Database work**: 0.003 reads per request after the version-keyed memo.
- **`GenServer.call` blocking**: process snapshots under 64 clients show no caller waiting in
  `gen.do_call`; earlier cache queueing was fixed and then that whole change was reverted as
  slower.
- **Response size**: the bare plug with the same 20,615 bytes scales 3.3x.
- **`System.get_env` and `persistent_term`**: the clock costs 0.34 us per call with no contention
  across eight schedulers, and per-key memos now live in ETS.

## Found: the page-cache key was the serialisation

The key was built with `:erlang.term_to_binary` plus a sha256, and read `SECRET_KEY_BASE` and
`VAPID_PUBLIC_KEY` through `System.get_env/2` — two environment reads per request, and
`os:getenv/1` serialises on a lock shared by the whole VM. Express keys the same cache with
`JSON.stringify` of the same fields, which is what this now does, with the deployment values read
once.

That single change took the ladder from 3,552 / 4,037 / 13,209 to 3,772 / 8,467 / 12,680 — the
1 -> 4 step from 1.14x to 2.2x, against Express's 2.5x. `Clock.now/0` had the same pattern
(two environment reads per call, many calls per request) and now reads them once with an explicit
`refresh/0`.

Remaining gap at four clients: 8,467 against Express 17,277, and this port still tops out near
13k where Express reaches 44k.


## Second serialisation: the version capture

`Campfire.CacheEpoch` now takes the database version once per request, before authentication, so
the session memo and the cache plug share it instead of each asking the cache process. This had
been tried earlier and looked like no change — at the time the environment reads in the cache key
masked everything else. With those gone it is worth 1.4 to 1.9x:

| clients | before | after | Express |
|---:|---:|---:|---:|
| 1 | 3,772 | 4,335 | 6,837 |
| 4 | 8,467 | 9,922 | 17,277 |
| 16 | 13,163 | 17,059 | 28,820 |
| 64 | 12,680 | 17,621 | 44,088 |

## Where it stands now, and what is left

Schedulers are now loaded evenly (24/23/23/23/22/23/23/23/23/22 percent across the ten normal ones,
2.3 cores in total) with no caller blocked in `gen.do_call`, and keep-alive is reused. Yet the
latency distribution at 64 clients is flat around 3.5 ms (p50 3.507, p90 4.379, p99 5.991) against
Express's 0.77 ms p50, and `/up` alone costs 2.06 ms per request where a bare plug on the same
server costs 0.76 ms.

So a per-request delay of roughly one to two milliseconds remains that is neither CPU nor
`GenServer.call` queueing. The next measurement is a per-request timeline — plug entry, cache
lookup, response write, socket flush — rather than more aggregate counters.
