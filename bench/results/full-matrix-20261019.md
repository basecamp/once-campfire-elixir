# Full matrix: Elixir against Express and Go

Same host, same fixture, same generator, contract-validated responses and audited writes. Five
routes, two concurrencies, two rounds of 8 s; the numbers are the harness summary for each point.
Express renders every room page; the Elixir port replays it from the response cache.

| route | @ | Elixir | Express | Go | Elixir/Express | Elixir/Go |
|---|---:|---:|---:|---:|---:|---:|
| room_show | 16 | 41,810 | 33,118 | 28,717 | 1.26× | 1.46× |
| room_show | 64 | 38,472 | 45,606 | 32,607 | 0.84× | 1.18× |
| messages_page | 16 | 43,962 | 42,916 | 29,566 | 1.02× | 1.49× |
| messages_page | 64 | 37,716 | 52,029 | 32,957 | 0.72× | 1.14× |
| sidebar | 16 | 43,011 | 50,004 | 31,083 | 0.86× | 1.38× |
| sidebar | 64 | 41,075 | 62,993 | 33,989 | 0.65× | 1.21× |
| search | 16 | 45,046 | 43,842 | 31,193 | 1.03× | 1.44× |
| search | 64 | 38,107 | 56,966 | 34,780 | 0.67× | 1.10× |
| post_message | 16 | 521 | 905 | 3,584 | 0.58× | 0.15× |
| post_message | 64 | 291 | 920 | 3,440 | 0.32× | 0.08× |

Geometric mean of the four read routes: @16 Elixir 43,441, Express 42,014, Go 30,122;
@64 Elixir 38,821, Express 54,019, Go 33,572.

## What the table says

- **Reads, low concurrency:** the port is ahead of Express and well ahead of Go. The response cache
  is doing what it was built for.
- **Reads, high concurrency:** Express keeps scaling (42k -> 54k from @16 to @64) while the port
  flattened in that session. A later interleaved run of the port alone (three rounds of @16 and @64
  in one session, after a warmup) put @16 at 30,063 and @64 at 29,538 medians, so the port does not
  actually regress with concurrency within one session: the matrix figure was ordering and
  session noise. Absolute numbers from different sessions are not comparable on this machine.
- **Writes:** the port is far behind both. Go does 3,440 posted messages a second at @64, Express
  920, the port 291 - and the port *degrades* with concurrency (@16 521 -> @64 291), which is the
  signature of lock contention rather than throughput.
- Go's read numbers being the lowest of the three while its writes are the highest suggests its read
  path pays for something the other two avoid (it was not profiled here).

## Caveats

Single machine, generator on the same cores (about 1.2 cores of load during the runs), two rounds
per point, no core pinning. Differences under 10% are inside this environment's noise, which is why
only the ratios far from 1 are treated as findings.

## Why writes are 12x behind Go: they are compute, not contention

The matrix shows `post_message` at 292 req/s @64 against Go's 3,440, and the port *degrades* from
@16 to @64, which reads like lock contention. It is not. Measured with the stage probe:

    cached GET (room_show)     2,836 reductions per request
    POST message             148,047 - 238,232 reductions per request   (~10-16 ms of CPU)

Two orders of magnitude, in the request process: during a write run the top eight processes are each
burning 21-24 million reductions per two seconds (about 0.77 core each), so the render and the SQL go
through the caller and the writer lock is not what limits it. At 16 connections, 693 req/s x ~10 ms
is ~6.9 cores, which matches the measured server CPU: the write path is throughput-bound on its own
work.

Within that work, `RichText.serialize` and `BlobEmbeds.blobs` measured 8.1k reductions each in a
partially successful instrumentation run; a transaction-level wrap measured ~0 in the caller and is
believed to be a bad instrument, so the split inside the transaction is still open.

Consequence: closing the write gap is about how much work one message costs (rich text, escape,
autolink, the six statements), not about batching commits or sharding writers.

## The write ceiling is one process, at ~590 posts a second

Wall-clock instrumentation of the POST action (reductions cannot see this: exqlite work is a NIF and
therefore accrues none). Per post at @16:

| stage | ms |
|---|---:|
| create_message | 5.7 |
| ├ transaction (as seen by the caller) | 4.1 |
| ├ RichText.serialize | 0.03 |
| └ BlobEmbeds.blobs | 0.02 |
| broadcast | 4.1 |
| render | 3.0 |
| webhooks | 1.0 |
| Attachments.process_message | 0.3 |

Two corrections to what this file said earlier:

1. **The transaction runs inside the writer process.** `Campfire.DB.transaction/1` is
   `GenServer.call(__MODULE__, {:transaction, fun})` (db.ex:198), so the six statements execute one
   transaction at a time in a single GenServer. The ~32 reductions measured in the caller were
   accurate, not a broken probe: the work is somewhere else. My "compute-bound, not contention"
   reading was wrong.
2. The ceiling that follows is arithmetic: 1 / ~1.7 ms of transaction body is ~590 posts a second,
   which is exactly what @16 measures (577). At @64 the same ceiling holds and queueing makes it
   worse, which is the degrade the matrix shows.

Where the per-post work goes, in order: **the message is rendered twice** (once for the response in
`Campfire.Messages`, once inside `Campfire.Broadcasts.create`) at ~3 ms each; the transaction queue;
a memberships query followed by one `Cable.broadcast` per member; and ~1 ms of webhook enqueue.

So closing the 12x gap to Go means: render once and reuse, trim the per-member fan-out, and shorten
the transaction (seven statements) or take the non-critical ones out of it.

## Per-statement wall clock inside the writer

The write transaction, measured inside the writer process (the caller sees queue time on top):

| stage | ms |
|---|---:|
| BEGIN IMMEDIATE | 0.198 |
| INSERT messages | 0.184 |
| INSERT action_text_rich_texts | 0.125 |
| SELECT embeds | 0.054 |
| UPDATE memberships | 0.101 |
| UPDATE rooms | 0.068 |
| INSERT message_search_index | 0.059 |
| COMMIT | 0.288 |
| **transaction body** | **0.560** |

Two things follow:

- **A third of the cost is BEGIN/COMMIT, not the statements** (0.49 of ~1.55 ms). Each statement costs
  about 0.06-0.18 ms, which is the NIF round trip rather than the row work, so statement *count*
  matters more than statement content.
- Which means the useful lever is **batching several posts into one transaction** (amortising
  BEGIN/COMMIT), not moving individual statements out of it: the statements with parity risk
  (`message_search_index`, `rooms.updated_at`, `memberships.unread_at`) are 0.23 ms of the 1.55, and
  moving them weakens atomicity or visibility for a 15% gain.

Also measured after the single-render change: `post_message` @16 577 -> 878, @64 291 -> 478.

## Fan-out batching was measured and dropped

`Broadcasts.create` queries the room's memberships and then sends one broadcast per member. Skipping
members with no connection (one `Registry.select` instead of N dispatches) was implemented and
measured with an interleaved A/B at @64:

    fan-out skips offline members   1,089 / 1,156
    baseline                        1,138 / 1,177

No difference, and the design is worse in production: the registry scan is O(all connections) while
the loop it replaces is O(room members), which is smaller in any real deployment. Reverted.

The same session also showed how much the write path moves between sessions: the same code measured
478 req/s earlier and 1,138 here. Write-path numbers need an interleaved A/B in one session, not a
figure from another run.

## Group commit was implemented, tested and dropped

Design that was built and reverted: transactions arriving within `write_batch_ms` share one
`BEGIN IMMEDIATE`/`COMMIT`; each entry runs in its own savepoint so a failing one rolls back alone
while its siblings commit; every caller waits for the batch commit before it is replied to, so
responses still never describe uncommitted data. A test covered exactly that (one failing, one
succeeding entry in the same batch) and passed.

Interleaved A/B at @64, post_message, two rounds each:

    group commit   1,151 / 790
    baseline       1,070 / 1,058

No gain: at ~1,100 writes a second, a 1 ms window collects one or two entries, so there is almost no
BEGIN/COMMIT to amortise and each caller waits an extra millisecond. A window large enough to batch
(5-10 ms) would amortise 5-11 writes per commit, which is where the theoretical ~40% lives, but it
adds that much latency to every post.

So the write path stays as it is: single writer, one transaction per request, ~870-1,150 posts a
second depending on the session, against Go's 3,440.

## Fan-out against Go: the broadcast is cheap, the posts are the limit

Same generator, same fixture, `cable` mode, 100 clients, 6 subscriptions each, 4 posters:

| | Elixir | Go |
|---|---:|---:|
| delivered messages/s | 245.9 | **720.8** |
| frames/s | 24,594 | 72,077 |
| per-client p50 latency | 7.68 ms | 5.54 ms |
| unread frames (10 s) | 249,100 | 724,300 |

At first this looked like a fan-out problem. Sampling the live node during the run says otherwise:
the top processes are the four poster request processes (~0.9 core each, in `:gen.do_call` and
`Enum.map`), while every socket process together accounts for ~0.45M reductions. `broadcast` itself
measures 0.18 ms. The benchmark is poster-bound: 4 posters x 246 posts/s is ~3.6 cores, i.e. ~14.6 ms
of CPU per post, against Go's ~5 ms at 721 posts/s.

**Method correction.** The per-stage wall-clock probe reports 10.4 ms for `MessagesView.render`
during that load, but the same call measured in isolation takes 0.001 ms. Under saturation a
wall-clock probe measures waiting, not work, so the earlier stage table (and the "render is 20x
slower" reading of it) is withdrawn; it describes latency composition, not CPU.

The post path therefore needs CPU-time attribution per stage - `:reductions` for the Elixir part
(the DB calls are NIFs and under-count there) plus explicit timers around the SQL calls - before
another optimization is picked.

## CPU attribution attempt on the post path: blocked by the instrument

The plan was to attribute the post path by CPU time (sum of scheduler active time) at low concurrency,
so waits do not masquerade as work. With the stage probe enabled the POST route started answering
500 for about one request in eight; with the probe disabled the same route answered 842 req/s and
zero errors. So the instrument itself is at fault under load, not the application, and no attribution
from these runs is usable.

What is established and worth keeping:

- fan-out delivery is cheap: all socket processes together account for ~0.45M reductions during a
  100-client run, and `broadcast` measured 0.18 ms;
- the cable benchmark is poster-bound: the four poster processes each burn ~0.9 core, and posts
  deliver 245.9/s against Go's 720.8/s;
- a POST answers 200 with a turbo-stream body, produced by `Campfire.Messages`, and that module is
  reachable only through the generated route table - worth knowing before instrumenting it again.

Next step if this is picked up: fix the probe (the raise happens outside the try that now wraps the
accounting, so capture it around `state/0` and `cpu_us/0` first), then rerun at @2 and @4.

## Go's fan-out compared item by item

Measured under the same `cable` run: Go uses ~4.0 cores for 720 posts/s (**5.6 ms of CPU per post**),
the Elixir port ~5.85 cores for 246 posts/s (**23.8 ms per post**), a 4.2x gap.

| per post | Elixir | Go |
|---|---|---|
| SQL statements in the transaction | 5 | **8** (plus a membership check and a creator-name read) |
| room reads after the insert | 0 (cached) | 2 |
| message renders | 1 | 1 + one template execution |
| authorization recheck on publish | none (subscription-time) | **a DB query per publish** |
| frame construction | per socket: `CableFrames.frame/3` does an ETS lookup with a ~1 KB composite key | **once per identifier**: `websocket.NewPreparedMessage`, reused for every recipient |
| payload copied to recipients | **yes, the ~1 KB payload is sent to each socket process** | no: the prepared frame is written directly |
| WebSocket frame encoding | per socket (Bandit encodes each `{:push, {:text, frame}}`) | prepared message written as-is |
| delivery point | inside the posting request | inside the posting request (5 s context) |

So Go does *more* SQL and *more* authorization work per post and is still 4x faster: the difference
is in how a frame reaches 100 sockets. Our shape copies the payload once per recipient, hashes it
again for the memo lookup, and re-encodes the WebSocket frame per socket; Go builds one prepared
frame per identifier and writes it N times.

First change if this path is picked up: build the frame once in `Cable.deliver/2` and send the frame
(not the payload) to the sockets, which removes N payload copies and N 1 KB ETS hashes. A prepared
frame write path in the adapter would be the second, larger one.

## Post path attributed: its own work is ~1.4 ms, the limit is serialization

Fixed the probe (a missing `cpus` table made it raise, which is what produced the 500s; every part of
it is now guarded and a fault disables it instead of failing the request) and measured the POST
action at two posters, where waiting is small:

| stage | wall ms |
|---|---:|
| create_message (transaction, lock wait included) | 0.531 |
| render | 0.448 |
| send (response) | 0.215 |
| broadcast (fan-out to subscribers) | 0.116 |
| webhooks | 0.073 |
| process_msg | 0.040 |
| parse | 0.004 |
| **total** | **1.43 ms** |

At two posters the route answers 709 req/s, and 709 x 1.43 ms is 1.01 s of work per second: the path
is already at its own limit there. Four posters drop it to 485 req/s instead of doubling, because
every post still takes one transaction on the single writer.

So the post path is not hiding a fat stage to trim - the largest is the transaction (0.53 ms) and the
rest is under 0.5 ms each. Raising posts/s means changing how writes are serialized, and every safe
option there has already been measured: statements moved out of the transaction (~15%, weakens
atomicity), group commit at a 1 ms window (no gain), a larger window (5-10 ms of latency per post).

The CPU column of the probe stayed at zero in the server even though `scheduler_wall_time` samples
fine in a plain VM; unused for the conclusion, since two posters is already the serialized case.

## Opportunistic group commit (drain the mailbox, no timer): measured, reverted

The writer drained whatever transactions were already queued (`receive ... after 0`), ran them in one
transaction with a savepoint per entry, and committed once. No timer, so no added latency.

    both queues batched:   @4 851/851   @64 767/712      base: @4 959/959   @64 770/742
    single entry fast path: @4 959/914   @64 798/734      base: @4 959/960   @64 718/727

Batching alone is 11% *slower* at @4: the writer is not backlogged (about half busy), so batches have
one entry and each pays SAVEPOINT plus RELEASE for nothing. With a single-entry fast path it is
neutral at @4 and about 6% better at @64, which is inside this machine's noise.

Verdict: reverted. Ninety lines of savepoint machinery, a sibling-visibility change and an
unmeasurable gain is not a trade worth carrying.

## Correction: the writer is not the bottleneck (it is 12% busy)

Measured with no concurrency, in one transaction, 300 iterations of the five statements a post runs:

    median 132 us   p90 226 us   max 2,043 us
    single-writer ceiling at the median: ~7,576 posts/s

At the 959 posts/s the route measures with four posters, the writer is busy about **12%** of the
time. So the earlier "the transaction costs ~1.05 ms and caps posts at ~950/s" reading is withdrawn:
that 1.05 ms was wall clock inside the writer *during load*, which includes being descheduled, not the
work. The pragmas are as intended (WAL, synchronous=1, normal locking), so the commit is not fsyncing.

Go is therefore not doing anything magical on the write side; a 132 us transaction leaves plenty of
room. What differs is the caller side: a post costs about 1.35 ms of wall time at one client
(create_message 0.56, render 0.35, send 0.24, broadcast 0.10, webhooks 0.05), so one poster can do
~740/s and four should do ~2,900/s if they were independent - but the route measures 959/s. The four
posters are serializing somewhere, and the stage probe shows `render` jumping from 0.35 ms to 5.5 ms
at four posters, which is the shape of waiting rather than work.

Next measurement: sample the four poster processes with the process sampler during a @4 run and read
what they are blocked on.

## The caller-side wait is cache eviction, not the writer

Sampling every process during a four-poster run named it: four processes parked in
`:ets.select_trap` at `:ets.tab2list`, and the writer sitting at ~3.7% of one core with an empty
queue (`1122k reductions / 2s`, `q=0`, 622 posts/s that run).

Both caches retire entries by walking the whole table to find the least recently used one:

    response_cache.ex  oldest/0        :ets.tab2list |> Enum.min_by(used)
    fragment_cache.ex  drop_oldest/1   :ets.tab2list |> Enum.min_by(used), recursive

A write invalidates fragments and pages, so a write-heavy run keeps the caches over budget and pays
that walk once per retired entry, on the request path. That is the missing ~5 ms per post at four
posters, and it explains why the writer looked saturated in one sample and idle in the next.

**Attempted fix, reverted:** retire a bounded batch per step (`:ets.select` with a limit of 64)
instead of the LRU walk. Faster, but it breaks a documented behaviour with a test: "a read keeps an
entry ahead of an older one when the budget fills". Correct fix is an `ordered_set` index keyed by
`{used, slot}`: eviction becomes `:ets.first/1` plus a delete, but every cache hit must move its key
(six ETS operations instead of one), on the hit path this session spent so long optimising. Worth
doing deliberately, not as a one-liner.

## Fragment cache pruning was the posting bottleneck: fixed, posts +89%

A live sample during a four-poster run found four processes in `:ets.select_trap` at
`:ets.tab2list`, and the writer at ~3.7% of a core with an empty queue. The fragment cache pruned by
walking the whole table for the oldest entry (`drop_oldest/1`), and it does that **in the posting
request's own process**: a write invalidates fragments, the cache goes over budget, and every poster
pays an O(n) walk.

`Campfire.FragmentCache` now keeps a `:campfire_fragment_order` `ordered_set` keyed by
`{used, key}`: lookups move their key, pruning retires `:ets.first/1` and carries on. Stale keys from
concurrent hits are skipped.

    post_message @4   676/675 -> 810/1,750   (median +89%)
    room_show @64   31,291/33,498 -> 34,487/33,884   (median +5.5%)

The same index on the response cache was tried and dropped: room_show is served from that cache, so
its `touch` lands on the hit path, and the read numbers fell to 25-29k against 32k.

`mix test` 1979 passed, including the LRU assertion ("a read keeps an entry ahead of an older one
when the budget fills") that a bounded-batch eviction had broken earlier.

## Response cache eviction stays as it is

Tried the same idea on the response cache - move `bytes` into the row so eviction can project
`{used, slot, bytes}` without copying bodies, then retire to three quarters of the budget in one
pass. It regressed the cache tests to 7/17 (the row-shape change reaches more call sites than the
eviction path) and it was reverted.

It also has no throughput argument behind it: this eviction already runs inside the cache's own
GenServer, not in a request process, and the earlier A/B with the index on this cache showed no gain
on posts (676 -> 550-660) while reads fell to 25-29k. The one eviction that sat on the request path
was the fragment cache's, and that is fixed.
