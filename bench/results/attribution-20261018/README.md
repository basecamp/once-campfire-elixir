# Where the request time goes (native, this Mac)

Same host as the other native runs: Darwin arm64, 10 CPUs, one server at a time, seed fixture,
gzip, responses validated by the shared load generator.

## Per-request ladder, measured at 64 concurrent clients

| Endpoint | req/s | µs per request |
|---|---:|---:|
| `Plug.Router` with one route returning `ok` | 77,098 | **13** |
| this port's `/up` (plugs, no DB, no cookies) | 33,584 | 30 |
| this port's room page, response cache hit | ~11,000 | ~90 (wall) |
| Express room page, full render, no cache hit | 33,012 | **145** (in-Node) |

## Scheduler scaling (room page, 64 clients)

| Schedulers | req/s |
|---|---:|
| 1 | 2,689 |
| 2 | 7,132 |
| 4 | 10,778 |
| 10 | 11,241 |

Throughput tracks schedulers up to four and then flattens, so the port is CPU-bound and parallel,
not blocked on one process. At four schedulers and ~10.8k req/s each request consumes roughly
**360 µs of CPU**, four times the wall figure, so most of the CPU sits outside the segments that
were instrumented (response cache, DB reads, session resolution, cookies, routing). Express
renders the same page in 145 µs on ten workers, so its CPU per request is roughly 2.5x lower.

## Cleared by measurement

- `RouteRecognition` (177 contracts): 0.2-1.0 µs.
- `Plug.Router` clause scan: the hot route sits at clause 11, so ~10 µs; an O(1) table would
  not move the room page.
- `PRAGMA data_version` per request: 2.4 µs idle, 3.6 µs under load.
- Session, user and membership reads: memoised, 0.2-12 µs after the change in cafc62d.
- Response cache lookups are a single call: ~15 µs service.
- Cookie re-signing is 37 µs per cached response and cannot be memoised without changing the
  emitted bytes, because the expiry is second-precise.

## Next

Per-request CPU attribution needs a profiler: this OTP build has no `tools` application, so
`:eprof`/`:fprof` are unavailable. Either install an OTP that ships `tools`, or sample stacks
with `:erlang.trace` under load, then fix whatever dominates.

## Profile of a cached room page (eprof, Homebrew OTP 29.1.2 with `tools`)

Twenty identical cache hits, own time per function divided by twenty. eprof inflates absolute
numbers, so read the shares.

| function | µs per request | share |
|---|---:|---:|
| `binary:match/2` | 47 | 8.5% |
| `URI.encode/2` (cookie value) | 37 | 6.8% |
| `URI.percent/2` | 32 | 5.8% |
| `URI.unpercent/3` | 19 | 3.4% |
| `URI.char_unreserved?/1` | 17 | 3.0% |
| `Base.decode64base!/1` | 16 | 2.8% |
| `Plug.Conn.Cookies.decode_value/6` | 15 | 2.8% |
| `os:getenv/1` | 9 | 1.6% |
| `Keyword.get/3`, `lists:keystore2/4`, `normalized_header_key?/1` | 8 each | ~1.4% each |

Cookie serialisation owns the request: percent encoding and decoding plus base64 come to roughly
136 µs per cached response, an order of magnitude more than any database work left (measured at
0.003 reads per request). `os:getenv/1` is called about nineteen times per request because the
response cache re-reads its limit each time.

The next cuts, in order of size: a specialised percent encoder and decoder for the cookie
alphabet (about 85 µs), memoising the cache's limit (about 9 µs), and replaying without
re-signing cookies, which needs the reference's Set-Cookie behaviour confirmed first.

## After the cookie codec: Plug.Conn bookkeeping owns the request

eprof again, twenty cache hits, now that `CookieCodec` replaced `URI.encode/2`:

| function | µs per request | share |
|---|---:|---:|
| `binary:match/2` (from `Plug.Conn.validate_header_key_value!/2`) | 47 | 10.3% |
| `Campfire.CookieCodec.encode/2` and `decode/2` | 34 | 7.3% |
| `Base.decode64` (cookie verification) | 30 | 6.5% |
| `Plug.Conn.Cookies.decode_value/6` | 15 | 3.4% |
| `Plug.Conn.normalized_header_key?/1` | 24 | 5.0% |
| `Enum.reduce`, `Keyword.get/3`, `lists:keystore2/4`, `String.replace_guarded/4` | ~37 | ~8% |

fprof attributes `binary:match/2` to `Plug.Conn.validate_header_key_value!/2`, called from
`put_resp_header/3` 42 times and from `verify_cookie!` 9 times per request: Plug scans every header
key and value for CRLF injection on every write, and the room page writes 42 headers.

That is the shape of the remaining gap against Go, which needs about 141 µs per request on one
client against roughly 300 µs here: most of a request is Plug.Conn's per-header and per-cookie
bookkeeping (validation, key normalisation, byte-wise cookie decoding, base64), not domain work.
Database reads are 0.003 per request and the page itself is served from cache.

Three measured cuts, none of them structural:

1. Replay cached headers without re-validating them (they were validated when produced): about
   16 µs per request.
2. Audit the 42 headers per response and drop duplicates.
3. Chunked cookie decoding with `:binary.match/2` instead of a per-byte recursion, and reading
   only the two cookies the session needs: about 20-30 µs together.
