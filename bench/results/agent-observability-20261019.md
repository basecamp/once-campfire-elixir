# Which runtime answers "who is blocked" faster: a two-arm agent experiment

Question: this build's room page saturates at 19-25k req/s while a single request costs 0.27 ms
of CPU, so 4-5 of 10 cores are idle. Something serializes. Which runtime lets an agent find it in
fewer turns, Beam or Node?

Both arms ran on the same host, the same fixture and the same load generator. The measuring agent
is the same model in both arms; only the runtime differs.

## Arm A: Elixir (BEAM)

Protocol: start the server with `--sname` and the load generator against it, then sample every
process from a second node for two seconds and diff.

```
Process.list + Process.info(:reductions, :message_queue_len, :current_function)
```

Three commands, one of which was a wrong-port retry. Result, printed as text:

```
=== top reductions/2s ===
3384k  {:gen, :do_call, 4}   x12
=== message queues > 0 ===
33  {Exqlite.Sqlite3NIF, :columns, 2}
24  {Exqlite.Sqlite3NIF, :multi_step, 3}
run_queue=0
```

Answer: the serialized section is per-request SQLite work. Callers queue inside the read pool while
two connections execute `columns`/`multi_step`; the run queue is empty, so the limit is waiting, not
CPU. Next step follows directly: remove the per-request reads (`data_version` in CacheEpoch,
`Chat.room` in `accessible?`) instead of adding connections — adding them was measured earlier and
made it worse (16.1k against 19.1k).

## Arm B: Node (Express)

Protocol: `node --prof`, then `--cpu-prof`, with `WEB_WORKERS=1` so a single process serves.

Nine commands, of which four were my own mistakes (missing `SECRET_KEY_BASE` twice, `WEB_CONCURRENCY`
instead of `WEB_WORKERS`, killing the shell wrapper instead of the node process). Two more were
runtime puzzles rather than progress: `--prof` sampled only startup (425 ticks), and the next attempt
returned 30,931 ticks of which 99.2% were `pselect$DARWIN_EXTSN` — the event loop waiting, with no
request frames.

The `--cpu-prof` profile finally answered a different question:

```
samples=68444   (idle) 65.8%
 3.7%  writev
 2.2%  pageEpoch response_cache.js:154
 2.1%  (anon) db.js:155
 1.8%  get db.js:85
 0.9%  stringify rails.js:24
 0.8%  serialize index.js:184
```

Self-time attribution: who burns CPU, flat across small functions. It also happens to contain the
same SQLite epoch work (`pageEpoch`, `db.js`), but at 2% of samples; naming it as *the* serialization
from this table alone would have been a guess.

## What the experiment says

1. Beam ships the answer to "who is blocked on what" as a runtime primitive: process state, message
   queue length and current function are readable without touching the application. Node ships a CPU
   sampling profiler; blocking is not a first-class question, it has to be instrumented
   (`async_hooks`, APM, `perf_hooks`).
2. The asymmetry is narrow and real in both directions. For "which function burns CPU", Node's
   `--cpu-prof` gave a ranked table in two commands; the Beam equivalent (`:eprof`, `:fprof`) is
   heavier and needs a recompile or a separate run.
3. My own mistakes dominated the command counts (1 of 3 in arm A, 4 of 9 in arm B). Excluding them
   the comparison is 1 command against 3, and the third Node command only exists because the profiler
   answers the neighbouring question.
4. Cost of the wrong tool is not symmetric: a Beam sample that shows `run_queue=0` and a queue in
   `columns/2` is immediately actionable; a profile that is 99% `pselect` tells you the loop is idle and
   leaves the cause open.

Caveat for readers of this file: the agent already knew the answer from arm A before running arm B.
The Node table was not evaluated blind, so treat the ranking above as evidence about *instrumentation
cost*, not about the agent's ability to diagnose Node from scratch.
