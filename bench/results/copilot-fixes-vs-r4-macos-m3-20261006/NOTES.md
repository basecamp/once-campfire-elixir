# Copilot review fixes vs round 4 (Docker Desktop, Apple M3, October 6, 2026)

A regression check of the four fixes for Copilot's review on PR #5 (`84f9c5f`…`24c4b08`):

1. a matching `Origin` is required for writes without `Sec-Fetch-Site`;
2. `MAX_REQUEST_BODY` is enforced while the body is read;
3. cache accounting is exact, with eviction replacing the full wipe;
4. the HTTPS redirect names its port.

The candidate is `campfire-elixir:further-perf-r5` at `24c4b08`. The baseline is
`campfire-elixir:further-perf-r4` at `cc47003`.

```sh
SKIP_LEDGER=1 HTTP_SECS=4 LOAD_WAIT_SECS=120 ELIXIR_IMAGE=campfire-elixir:further-perf-r5 \
  REFERENCE_IMAGE=campfire-elixir:further-perf-r4 SUITES="http" \
  bench/docker-desktop/run --apps elixir,reference --reps 2 --out bench/results/copilot-fixes-vs-r4-macos-m3-20261006
```

Every validation passed with zero errors, and decoded bodies are byte-identical. At c=16 (req/s,
CPU µs per request; reps 1 and 2):

| Route | Round 4 | Fixes |
|---|---|---|
| Room page | 19,371 / 204, 19,477 / 203 | 16,006 / 239, 16,032 / 243 |
| Messages page | 27,181 / 146, 15,459 / 212 | 26,316 / 149, 24,304 / 162 |
| Sidebar | 34,882 / 114, 9,529 / 350 | 34,026 / 116, 32,608 / 120 |
| Search | 29,926 / 133, 15,833 / 231 | 30,143 / 131, 27,911 / 141 |
| Post message | 2,385 / 1,227, 2,150 / 1,330 | 2,253 / 1,297, 2,131 / 1,363 |

Round 4's rep 2 was disturbed on the messages page, sidebar and search. Everything else is level
except the room page, which looked about 17% slower in both reps. The follow-up checks found no
regression:

- **Profile:** a room-page profile of the fixed build (`../profile-macos-r5/room_show.txt`) shows
  no recomputation. `select_replace` never runs, nothing is deflated, and all 81 derived lookups
  per page hit.
- **Alternating room-page run:** the room page alone, alternating the two images on fresh
  seeds three times (6 s at c=16, `bench/.work/roomab.sh`, not committed), gave round 4
  17,218, 16,720 and 17,425 req/s against the fixes' 16,956, 16,978 and 17,317.

The room-page gap in the A/B was host noise or a run-order effect.
