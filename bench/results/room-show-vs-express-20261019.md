# room_show: Elixir against Node Express

Same host, same load generator and route contracts, same seed fixture, fresh database and storage
copy per app, gzip, every response validated. Both run natively, one at a time. Two rounds of 6 s
per cell, medians.

## Throughput

| clients | Express | Elixir | ratio |
|---:|---:|---:|---:|
| 1 | 7,395 | 4,459 | 1.66x |
| 4 | 19,327 | 10,952 | 1.76x |
| 16 | 32,581 | 23,930 | 1.36x |
| 64 | 43,756 | 22,985 | 1.90x |

## Latency and payload

| clients | Express p50 | Elixir p50 | Express bytes | Elixir bytes |
|---:|---:|---:|---:|---:|
| 1 | 0.12 ms | 0.21 ms | 19,513 | 20,615 |
| 4 | 0.19 ms | 0.36 ms | 19,513 | 20,615 |
| 16 | 0.32 ms | 0.65 ms | 19,513 | 20,615 |
| 64 | 0.78 ms | 2.70 ms | 19,513 | 20,615 |

The port serves about 5% more bytes for the same page.

## Where this stands against the start of the session

| clients | start of session | now | change | Express |
|---:|---:|---:|---:|---:|
| 16 | 9,552 | 23,930 | +151% | 32,581 |
| 64 | 9,489 | 22,985 | +142% | 43,756 |

The gap narrowed from 3.0x / 4.6x to 1.36x / 1.90x. What moved it, in order of size: the response
cache key stopped hashing and reading the environment (which had been serialising every request on
a VM-wide lock), cache entries moved to ETS so a hit no longer ships the body through one process,
the database version went from a single-process observation to a pooled read in the caller, and the
per-key memos moved off `persistent_term`.

## What is left

At 16 clients the port is within 1.36x and its latency is sub-millisecond. At 64 clients it stops
scaling (23.0k against 23.9k at 16) while Express keeps going to 43.8k, so the remaining difference
is a per-request cost that saturates rather than a queue a single process owns: the last measurement
of the request path showed no caller waiting in `GenServer.call` and the pre-cache plug chain at
22 µs. The next step would be a per-request CPU profile under load — this OTP build has no `tools`
application for `:eprof`/`:fprof`, so it needs either a different OTP or stack sampling.
