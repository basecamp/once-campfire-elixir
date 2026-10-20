# The runtime is not the gap: a static body costs the same on Bandit and on Express

Question left over from the room-page work: the port answers a cached 19.5 KB page at 21k req/s while
Express answers the same page at 46k. Is that the runtime, or our pipeline?

## Method

Each application got one route, `/__bench/static`, registered before all middleware, that returns a
fixed 25,492 byte body gzip-compressed to 1,091 bytes with `content-length` set. The gzip bytes are
identical in all three (verified with `cmp`), so the only difference is the HTTP layer.

The load generator spoke HTTP/1.1 with keep-alive, 8 s per point, no cookie (the route needs none).

## Results

| `/__bench/static` | @1 | @16 | @64 |
|---|---:|---:|---:|
| Elixir (Bandit) | 12,504 | 59,283 | 77,362 |
| Express (Node 24) | 18,892 | 72,530 | 79,031 |
| Rust (axum, reviewed revision) | not measured | | |

At @64 the two are within 2%: 77.4k against 79.0k. At @1 Express leads 1.5x, which is the cost of
admitting and scheduling a process per connection.

Against the same applications' cached room page at @64 (Elixir 21,114, Express 46,649) the picture
inverts: the 2.2x gap survives only when our pipeline runs. Remove the pipeline and the gap closes.

## Where the pipeline money goes (measured earlier, per request, reductions)

| stage | before | after the session memo |
|---|---:|---:|
| response cache replay (headers, cookies, `send_resp`) | 4,725 | 1,806 |
| browser guard (user-agent scan, assigns) | 1,665 | 901 |
| session verification | 1,372 | 594 |
| socket write | 406 | 406 |
| route recognition | 77 | 77 |

`socket write` is 6% of a cached response; the rest is string and struct work in our own code.

## Is the compute itself slow? A microbenchmark

Same three operations, 50,000 iterations each, one process/thread, no I/O:

| operation | Elixir | Node | |
|---|---:|---:|---|
| build 25 KB from 400 fragments (`map_join` / `Array.join`) | 0.095 ms | 0.022 ms | Node 4.3x |
| same, built as iodata then flattened | 0.072 ms | 0.022 ms | Node 3.3x |
| ten updates on a 60-key map / object spread | 0.002 ms | 0.019 ms | **Elixir 9.5x** |
| path regex | 0.001 ms | 0.000 ms | tie |

Two different answers in one table:

- **String construction is 3-5x slower on the BEAM.** HTML rendering, header validation, cookie
  encoding and user-agent scanning are all string construction, so a pipeline that does a dozen of
  those per request pays the full multiple.
- **Immutable struct updates are 10x faster on the BEAM** than the JavaScript equivalent, so the
  `Plug.Conn` copying that the pipeline does is not where the money is.

## Conclusion

The remaining per-request gap is not "the runtime is slower"; it is "we do more string work per
request, and string work is the primitive where this runtime is weakest". A port that wants the
Node numbers has to remove string operations per request (merged cookies, no per-request header
validation, no user-agent re-parsing), not replace the runtime.

Caveat: the Rust route was not measured. The local binary still contains it until the next build;
its source is reverted.
