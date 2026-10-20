# Why the port uses five cores and Express uses more

Same host, quiet, gzip, validated responses, room_show.

## The ceiling

| clients | 16 | 64 | 256 | 512 |
|---|---:|---:|---:|---:|
| Elixir | 23,930 | 23,157 | 21,431 | 22,395 |
| Express | 32,581 | 43,756 | | |

Throughput is flat from 64 to 512 clients, so the server is the limit, not the connection count.

## What the cores say

Per-scheduler utilisation at 23,157 req/s and 64 clients:

```
1:72 2:68 3:72 4:72 5:72 6:70 7:44 8:9 9:4 10:1     cores 4.8, run queue 0
```

Five schedulers carry the work, five are idle, and the run queue is empty — so requests are
waiting, not queueing for CPU. Dividing work by throughput gives about 217 µs of CPU per request.

A pure-CPU synthetic load on the same VM spreads evenly across all ten schedulers at 100% each, so
the BEAM and the machine can use every core; the concentration is a property of the request path.

Express on the same cell reaches 43,756 req/s. Its own timers put a room request at about 172 µs
inside Node, which is about 7.5 cores at that rate.

## One cost that was measured and is real

Memoising the `PRAGMA data_version` read for one millisecond in ETS moved 16 clients from 23,930 to
27,113 req/s (+13%), and left 64 clients at 22,922. That memo was reverted: it trades the
invalidation contract (a commit retires entries immediately) for the win, and the repository's
documented guarantee is the stronger signal.

## Status

Requests on a cached page make no `GenServer.call` except that one version read, the pre-cache plug
chain measures 22 µs, and the cache, session memo, membership memo, user-agent memo and asset memos
are all ETS. The remaining wait is per request, about 2.6 ms at 64 clients, and it is not CPU: the
next probe has to be a per-request timeline at 64 clients again, now that the process hops are gone,
to see whether the time sits before the handler, in the handler, or in the socket write.
