# A synchronous NIF for `PRAGMA data_version`: measured, reverted

Node answers `pageEpoch()` by running `PRAGMA data_version` per request on the same thread. Here the
same read went through a pooled reader, so it cost a message round trip and a scheduler switch on
every cached response. This is the attempt to make it a call in the caller's process, and why it is
not in the tree.

## What was built

A ~120 line NIF (`native/sqlite_version_nif.c`): one connection opened readwrite (readonly cannot
create the `-shm` a WAL database needs, `SQLITE_CANTOPEN` = 14), one statement prepared at open, and
`data_version/1` stepping it on the calling scheduler — no dirty flags, since the statement takes
microseconds. `Campfire.DB.data_version/0` used it and fell back to the pooled reader when the NIF
was absent.

Correctness was checked before speed: a foreign write through a second connection moves the value
(2 → 3), and 20 processes × 1,000 calls saw one consistent value.

## Numbers

| room_show | pooled reader (committed) | one probe, no mutex | one probe + mutex | eight probes |
|---|---:|---:|---:|---:|
| @1 | 7,470 | 8,565 | 5,387 | 6,595 |
| @16 | 28,938 | 35,019 | 31,769 | 27,657 |
| @64 | 29,669 | 29,577 | 25,636 | 22,440 |

The fastest column is not usable: without a lock, `sqlite3_step` and `sqlite3_column_int` on the
same statement interleave between processes, and the VM died with a segmentation fault once a pool
of probes existed. With the lock the probe is safe and slower than the pooled read, because every
request now serializes on one mutex and the threads ping-pong on it.

Eight probes were expected to relieve that and did the opposite: each handle pays its own WAL read
bookkeeping, and 22.4k at @64 is worse than one probe.

## Conclusion

The per-request version read is cheap in Node because the read is a function call, but a *shared*
connection in a runtime with a scheduler per core turns it into a lock. Making it in-process only
pays if each process can hold its own connection — which is what the abandoned whole-layer NIF did,
and that regressed the same way (18.2k against 23.4k at @64).

So the pooled read stays. The remaining cost is 48 reductions per request (@64 ≈ 29.7k with the
current pipeline), and the next real lever is no longer here.

## Follow-up: the queue is real, and the fix must not move the version off the read path

Sampling the live node at @64 (`Process.info/2` over every process, callee of `:gen.do_call/4`)
showed where the remaining wait is:

    59 processes blocked in Campfire.DB.data_version/0
    server 648% CPU, generator 119%, run_queue 3

So the per-request version read is the serialization, as suspected. A dedicated VersionPool (four
read-only connections, picked by `:via` like the read pool) was tried to take it off the readers:

    cache tests        11-15 of 16 passing (baseline 15-16)
    @1 6,954   @16 29,257   @64 23,008   (baseline 7,470 / 28,938 / 29,669)

It is slower *and* wrong: the page's reads happen on a reader while the version comes from another
connection, so the epoch does not describe the snapshot the page was rendered from and entries are
captured under a version they do not match.

That leaves only two shapes for this read, both already measured: one connection per process (the
whole-layer NIF, 18.2k at @64) or a short TTL with an own-write counter, which trades immediate
visibility of foreign writes for throughput. Neither is in the tree.

## Resolution: coalesce the calls in the reader's mailbox

The queue of `data_version` callers does not need a new transport, only fewer reads. Every caller
in the mailbox asked the same question in the same instant, so the handler now answers all of them
from the one value it just read, with `receive ... after 0` on the `:"$gen_call"` pattern:

    receive do
      {:"$gen_call", from, :data_version} -> GenServer.reply(from, version); loop()
    after 0 -> :ok
    end

Only that pattern is matched, so page queries keep their place in the mailbox. A caller that gets a
slightly older version is the safe direction: the entry lands under an older epoch and the next
request, which sees the newer one, misses rather than serving something stale.

    blocked callers   59 -> 29
    @1                7,470 -> 7,382
    @16              28,938 -> 38,757
    @64              29,669 -> 34,005

Cache and db tests are unchanged (16/16 and 11/11 in isolation, one intermittent cache test as
before).

## Where batching stops paying

After the mailbox coalescing, every remaining candidate for batching was measured at @64 on the same
fixture. Baseline after the coalescing: @16 37,588, @64 33,347.

| attempt | @16 | @64 | outcome |
|---|---:|---:|---|
| drain the backlog before reading instead of after | 36,951 | 33,113 | no change |
| read pool with 4 partitions instead of 2 | 35,561 | 32,158 | worse |
| dedicated version pool, 4 connections | 29,257 | 23,008 | worse and incorrect |

The reason the first row is a tie: coalescing reduces the number of *statements*, but every caller
still pays its own message round trip and scheduler wakeup, so the per-request cost stays. Removing
that requires the version to be published rather than pulled, which moves the read off the page's
connection — that is the design that served a revoked session (200 instead of 302) because an entry
can then be stored under a version older than the snapshot it was rendered from.

So the version read is batched as far as it can be batched. What is left in the request path is
CPU (run_queue 16 at @64) and the socket write, neither of which is a batching problem.

## Two changes that moved the number

**Version TTL with an own-write counter.** `Campfire.DB.data_version/0` reads a lock-free cell
(`:atomics`) holding `{read_at_ms, version}` and refreshes it at most every `version_ttl_ms`
(2 ms in production, 0 in test, so the foreign-write tests keep seeing commits immediately). Own
writes do not wait for the TTL: they bump a write counter that is part of the cache key.

    @1  7,382 -> 9,316    @16 37,588 -> 40,127    @64 33,347 -> 34,192

**One struct update on the hit path.** Replaying a hit did `assign/3`, `Map.put/3`, `Map.merge/2`
and `halt/1` in a row, each copying the whole conn. They are one update now:

    @64 34,192 -> 36,342

Both together: @1 9,247, @16 40,113, @64 36,342. `mix test` 1978 passed.
