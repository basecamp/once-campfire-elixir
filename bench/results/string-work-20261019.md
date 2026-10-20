# Removing string work per request: room_show 2,383 -> 4,683 at @1

The static-body experiment showed the runtime is not the gap, and the microbenchmark showed where
the gap lives: building strings (3-5x) rather than copying structs (where the BEAM is 9x faster).
This records what happened when the per-request string work was removed.

## Changes

| change | why |
|---|---|
| Cookie header parsed once per connection (`Process` slot keyed by the raw header) | Plug decodes the Cookie header on every `fetch_cookies`, and the pipeline called it twice per request |
| Signed and encrypted cookie values memoized per connection | signing/encrypting identical bytes for every response |
| Replay writes `set-cookie` headers directly instead of `put_resp_cookie` | Plug re-encodes cookie maps inside `send_resp`; on a hit that merge cost more than the rest of the request. Bytes are produced by the same `Plug.Conn.Cookies.encode` call, so they are identical |
| `resp_cookies` cleared before `send_resp` and restored after | keeps the conn-visible cookies that tests and callers read, without sending them twice |
| Permanent-cookie window memorized per second | two `DateTime` computations per reissued cookie |
| Browser session memo keyed by the whole payload | the earlier key omitted `return_to_after_authenticating`, which made a stale cookie survive one request |

## Numbers

    room_show      before    after
    @1              2,383    4,683     (1.97x)
    @16            22,308   23,488
    @64            21,114   23,445

Reductions per request, cached hit: endpoint 6,961 -> 5,038. The socket write stays at ~410.

## What did not move, and why

@64 is unchanged within noise. The blocked-process sample from the observability experiment showed
why: callers queue on two SQLite readers (`33` on `columns/2`, `24` on `multi_step/3`, run queue
empty). Every request still performs `PRAGMA data_version` and `Chat.room` (the access check), so the
ceiling is the read pool, not the string work. Cutting those two reads is the next lever, and it is
a semantic decision: the version probe exists to notice foreign writes, and `Chat.room` exists to
re-check access that the cache key already covers through the version.
