# Torque JSON swap and the Go/Express comparison

Measured on the same host as `native-20261018` (Darwin arm64, 10 CPUs, one server process at a
time, no other load), same seed fixture, gzip, and a fresh database/storage copy per app so the
writes of one run cannot warm the next. Every response is validated by the shared load
generator: 0 invalid responses and 0 errors across 4.8M requests.

## Jason vs Torque (same code, parent commit 3e9789b vs current)

| Workload | Jason | Torque | Change |
|---|---:|---:|---:|
| room_show @16 | 8,926 | 9,552 | +7.0% |
| room_show @64 | 8,923 | 9,489 | +6.3% |
| search @16 | 11,993 | 11,894 | −0.8% |
| search @64 | 12,053 | 12,130 | +0.6% |

The room page gains because every rendered message decodes its Active Storage metadata envelope;
that is 40 JSON decodes per request at 0.4–0.5 µs each instead of 0.8–0.9 µs. `search` returns a
small JSON body where the SQLite query dominates, so the swap is inside the noise there.

## Against Go and Express (current Elixir build)

| Workload | Elixir | Go | Express | Go/Elixir | Express/Elixir |
|---|---:|---:|---:|---:|---:|
| room_show @16 | 9,552 | 27,865 | 31,941 | 2.9× | 3.3× |
| room_show @64 | 9,489 | 33,064 | 47,130 | 3.5× | 5.0× |
| search @16 | 11,894 | 30,598 | 47,294 | 2.6× | 4.0× |
| search @64 | 12,130 | 34,632 | 61,719 | 2.9× | 5.1× |

Elixir flatlines between 16 and 64 clients while Go and Express keep scaling, so the remaining
gap is scheduling and per-request overhead rather than JSON. The JSON library is no longer a
lever of that size: Torque removed the last measurable encode/decode cost on the HTML path, and
the JSON-only routes were already bound by SQLite.

## How to reproduce

```sh
# Elixir (this repo), Go and Express must each expose the same seed on their own port.
MIX_ENV=prod PORT=4101 DATABASE_PATH=… STORAGE_PATH=… mix run --no-halt
ruby bench/native-http.rb --app elixir --base http://127.0.0.1:4101 \
  --out tmp/native/ab-torque --routes room_show,search --concs 16,64 --duration 6 --rounds 2
```

Two rounds per workload, medians reported. These short runs describe this workload on this host;
they are not long-duration capacity estimates.
