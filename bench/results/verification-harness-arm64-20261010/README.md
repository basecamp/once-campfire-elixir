# Shared verification harness on arm64 Docker (October 10, 2026)

[`once-campfire-verification`](https://github.com/basecamp/once-campfire-verification) at `ec02deb`,
run on an Apple M4 Max inside a Linux docker-in-docker daemon (Docker Desktop's `--network host`
does not reach the Mac loopback the harness assumes). The Docker VM has 16 CPUs and 16 GB; the
harness's defaults pinned the app to CPUs 8–11 and the load generator to 12–15, 16 concurrent
clients, three alternating rounds of 8 seconds after a 2-second warmup, gzip on. The seed was
built by `bin/seed --image campfire-reference:app` (the pinned Rails revision `90b3300`;
SHA-256 `1295f8a3…`). `bin/check` passed. Every response was validated against the route
contracts and every acknowledged post audited against the database; no run had an error or an
invalid response. The `*.summary.json` files are the harness's own output.

Each image ran in its own session, so the three Elixir builds were not interleaved with each
other; the rounds within a session alternate as the harness does.

| Route (req/s, median of 3) | Rails `90b3300` | Elixir `main` `58964cf` | PR #5 `cf65478` | `further-perf-plus` `dfe229b` |
|---|---:|---:|---:|---:|
| Room page | 178 | 4,342 | 10,896 | 19,831 |
| Messages page | 286 | 4,622 | 12,498 | 27,513 |
| Sidebar | 469 | 5,102 | 15,171 | 35,628 |
| Search | 310 | 4,730 | 14,294 | 29,671 |
| Post a message | 223 | 487 | 418 | 567 |

Ranges: `further-perf-plus` room 18,615–21,155, messages 27,078–28,326, sidebar 34,210–36,911,
search 29,129–30,646, post 508–644; audited persisted writes per round 5,052 / 6,322 / 5,672.
Rails here is the pinned reference image (`WEB_CONCURRENCY=3`), not the current Rails `main`
the published table measures, which caches responses.

These are not the published numbers: the virtualised Docker VM measures Elixir `main`'s reads
about 20% below the Ryzen host of the published table and its posting at less than half. Compare
the columns with each other, not with that table.

## Search contract

The harness expects search results ordered by message id, as current Rails `main` serves them
(`reorder(:id)` in `Message::Searchable`). The Rails revision this port pins, `90b3300`, orders
them by `created_at` (`.ordered.last(100)`), and so do PR #5 and this branch; the seed has one
matching message with a later `created_at` and a lower id. The harness's preflight therefore
rejected PR #5, this branch and the pinned Rails image itself with `search: differs from seed
SQL`, while Elixir `main`, which orders by id, passed. The Rails, PR #5 and `further-perf-plus`
columns were measured with the one-line change in `search-contract.patch`, which makes the
expected order `created_at DESC, id DESC`; the `main` column is from the unpatched harness. The
pages themselves are unchanged. Which order the port should follow is an open question for the
pinned contract.

## Browser flow and frontend tests

`bin/browser` (Playwright 1.63 in `mcr.microsoft.com/playwright:v1.63.0-noble` on the same
daemon) against a fresh, empty instance of each image:

- Elixir `main` `58964cf`: passes the whole flow.
- `further-perf-plus` at `dfe229b`: the session transfer page failed the harness's check for a
  complete `auto-submit` form, because PR #5's template dropped the form's closing tag with the
  token input (main fixed the same in `db7958b`); fixed here in `9b3fd9a`. The rerun then fails
  at the direct-ping autocomplete, whose response is HTML where the page expects JSON
  (`Unexpected token '<', "<lexxy-pro"...`), and the held sidebar refresh is abandoned
  (`route.continue: Route is already handled!`). Those are the frontend overrides main added
  after PR #5's base (`a43b008`, `7c91093`, `67adda5`: `assets/overrides/` and
  `bin/apply-asset-overrides`), which this branch, stacked on #5 at `b6b82e5`, does not have.

`test/sidebar-reload.mjs`, `test/editor-preservation.mjs` and `test/autocomplete-json.mjs`
pass against main's override files and have no counterpart on this branch.

## Not run

The mixed read-and-write profile (`--mixed-write-rate`) and the `loadgen cable` profile.
