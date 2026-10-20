# Express against Elixir on room_show, after the cache change

Native processes, same host, same seed, fresh database and storage per app, gzip, every response
validated by the shared generator. No container.

## Back to back, this window (host at load average 7 to 10)

| Workload | Express | Elixir | Express/Elixir |
|---|---:|---:|---:|
| room_show @16 | 27,612 and 29,699 | 11,305 | 2.5x |

Sixty-four-client cells were rejected by the generator at this load, so there is no @64 number for
this window.

## Earlier today, quieter host (load average ~4.4)

| Workload | Express | Elixir | Express/Elixir |
|---|---:|---:|---:|
| room_show @16 | 31,974 | 14,041 | 2.3x |
| room_show @64 | 45,830 | 13,647 | 3.4x |

## What the cache change did and did not do

Process sampling under load went from 63 blocked callers to 13 — one serialised cache call per
request instead of two, with lookups and counters served from ETS. Throughput did not move, so the
queue behind the cache was a symptom of how requests were spread rather than the ceiling itself.

Per request the two implementations are close: Express completes a room request in about 172 µs
inside Node (handler 102 µs, of which the page cache is 90), while this port's cached room page
costs roughly 200 µs in process and about 130 µs of application work. The remaining difference in
throughput tracks how many cores each process actually occupies: Express spreads across about
5.5 cores at 32k req/s, this port about 4 at 13.5k.
