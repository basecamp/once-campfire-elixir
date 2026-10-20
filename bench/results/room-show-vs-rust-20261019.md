# room_show: Elixir against the Rust port

Both native on this host, same seed fixture, fresh database and storage per app, gzip, responses
validated, two rounds of 6 s per cell, both apps run inside the same window with the Rust process
stopped before the Elixir one started.

| clients | Rust | Elixir | Elixir/Rust |
|---:|---:|---:|---:|
| 16 | 12,002 | 18,226 | 1.52x |
| 64 | 12,599 | 16,962 | 1.35x |

Rust was stable across two passes (11,918 and 12,002 at 16 clients; 12,648 and 12,599 at 64). Elixir
varied more in the same window (10,147, 19,125 and 18,226 at 16 clients), and on a quieter machine
earlier in the day it measured 23,930 and 23,157. The load average was still decaying from the Rust
release build and previous runs during this window, so treat the ratio as indicative and the
absolute Elixir numbers as a floor.

## What this does and does not say

The Rust port answers `/searches?q=coffee` with message ids that differ from the seed SQL, so the
shared harness refused to prepare contracts for any run against it. `bench/contracts.rb` now
prepares only the routes a run asks for, which unblocked this measurement without touching the
route being measured.

The comparison is therefore one route: the room page, `GET /rooms/:id`, cache-hit path, 20.6 KB
gzipped response for Elixir and 19.5 KB for Rust.
