# Final matrix: Elixir against Express and Go, after the optimisation round

Same host, same fixture, same generator, one session, back to back: five routes, two concurrencies,
two rounds of 8 s each. Contracts validated and writes audited throughout.

| route | @ | Elixir | Express | Go | Elixir/Express | Elixir/Go |
|---|---:|---:|---:|---:|---:|---:|
| room_show | 16 | 33,211 | 25,317 | 26,734 | 1.31× | 1.24× |
| room_show | 64 | 32,317 | 36,931 | 30,668 | 0.88× | 1.05× |
| messages_page | 16 | 34,016 | 33,174 | 28,499 | 1.03× | 1.19× |
| messages_page | 64 | 34,293 | 40,936 | 31,437 | 0.84× | 1.09× |
| sidebar | 16 | 36,261 | 42,533 | 30,952 | 0.85× | 1.17× |
| sidebar | 64 | 35,181 | 50,876 | 34,092 | 0.69× | 1.03× |
| search | 16 | 36,338 | 38,596 | 30,296 | 0.94× | 1.20× |
| search | 64 | 33,981 | 49,181 | 31,821 | 0.69× | 1.07× |
| post_message | 16 | 1,852 | 788 | 3,723 | 2.35× | 0.50× |
| post_message | 64 | 2,069 | 767 | 3,770 | 2.70× | 0.55× |

Geometric mean of the four read routes:

    @16  Elixir 34,930   Express 34,266   Go 29,073
    @64  Elixir 33,927   Express 44,101   Go 31,979

## What changed since the first matrix

`post_message` at @64 went from 292 to 2,069 req/s (**7.1×**), from 8.5% of Go to 55% of it, and from
0.32× of Express to 2.70×. Three changes account for it:

- the posted message was rendered twice (once for the response, once inside `Broadcasts.create`);
- the fragment cache pruned by walking its whole table inside the posting request's process;
- two statements in the new-message transaction were provably no-ops.

Reads are unchanged in shape: the port leads at @16 and Express leads at @64, where its lack of a
per-request process and of a version probe shows.

## Caveat

Absolute numbers move between sessions on this machine (the same code has measured 22k and 40k on
room_show @64), so only the ratios within this one session are comparable, and even those carry a
few percent of noise.

## Post path: the handler is not the gap, and the profiler is missing from this toolchain

Measured in process, with no network or concurrency:

    Endpoint.call (POST)        0.139 ms
    a static body round trip    0.080 ms   (earlier, same stack)
    POST round trip at @1       0.483 ms
    Go's POST round trip        0.265 ms

So the handler costs about half of Go's entire round trip, and roughly 0.26 ms per post is spent
between the socket and the handler: request body read, response finalize, and write. That matches the
read-path shape (the port wins at low concurrency and loses at high), and it is not something an
application-level change fixes.

Function-level attribution was attempted and is blocked by the toolchain:

- `:eprof` and `:fprof` do not exist here: this Erlang was installed without the `tools` and
  `runtime_tools` applications, and the repository's `bin/mix` runs a container that lacks them too.
- Hand-rolling it on `:erlang.trace/3` works for `:call` events (8,977 captured for one request) but
  not for timing: with `:return_to` set, no `:return_from` event is delivered on this build, so
  inclusive/exclusive time cannot be computed.

Unblocking it needs an Erlang with `tools` (the official installer, Homebrew, or asdf/mise with the
full OTP), then `:fprof` answers the remaining question directly.
