# `plug(:match)` measured at 2.3 µs: not the cost

Marks immediately before and immediately after the router's matcher, at 64 clients, same host and
harness:

```
pre_match    0.2 µs
post_match   2.5 µs      (so the matcher itself is ~2.3 µs)
request_total 2,906 µs
```

The earlier timeline put 3.2 ms between the `route_recognition` mark and the `browser_guard` mark,
and after ruling out the `CacheEpoch` version read (per-process connections measured slower and were
reverted), the matcher was the remaining candidate in that window. It is 2.3 µs, so the cost is
after `post_match`, i.e. inside the `CacheEpoch`/`BrowserGuard`/`response_cache` chain or beyond it.

## Where that leaves the investigation

Ruled out by measurement, each with the number that rules it out: database reads (0.003 per
request), session and membership reads (ETS memo), the response cache lookup (ETS), cache admission
(the caller writes), the fragment cache (ETS, no process), the version read (direct connections were
slower), `plug(:match)` (2.3 µs), the pre-cache plug chain (22 µs), `GenServer.call` blocking (none
under load), `persistent_term` writes on the request path (none), environment reads (read once at
boot in config).

What is left is the segment between `post_match` and the response being written: `CacheEpoch`,
`BrowserGuard`, the response cache plug and its replay. Those need marks of their own — the previous
set bracketed them together with everything else, which is why the attribution kept moving.
