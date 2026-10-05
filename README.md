# Campfire in Elixir

An Elixir implementation of [ONCE Campfire](https://github.com/basecamp/once-campfire).
It keeps the existing SQLite database, storage layout, signed/encrypted cookies and
Action Cable protocol, so existing installs can retain their data and sessions.

The application runs on Elixir 1.20.4 / OTP 29.1.1 with Bandit and Plug. Jobs and
Action Cable fan-out run in process; Bandit serves HTTP directly, with Thruster's
response cache, gzip and forwarded headers reimplemented in `Campfire.Front` and
TLS from `site_encrypt`. libvips and FFmpeg process media. The Rails frontend is
preserved, including Turbo and the composer.

## Running it

Build the production image locally. The build uses the pinned Rails reference for
assets; check out the submodule first:

```sh
git submodule update --init

docker build --build-arg GIT_REVISION="$(git -C reference rev-parse HEAD)" \
  -t campfire-reference:app reference
docker build -f Dockerfile.dev -t campfire-elixir:toolchain .
bin/mix local.hex --force
bin/mix local.rebar --force
bin/mix deps.get
bin/export-assets
docker build -t campfire-elixir:release .
```

Then run Docker:

```sh
docker run -d --name campfire -p 80:80 -p 443:443 \
  -e SECRET_KEY_BASE=... -e VAPID_PUBLIC_KEY=... -e VAPID_PRIVATE_KEY=... \
  -e TLS_DOMAIN=chat.example.com \
  -v campfire:/rails/storage \
  campfire-elixir:release
```

- `TLS_DOMAIN` enables automatic Let's Encrypt certificates (Thruster's variable
  names are kept). For local plain HTTP, omit it and set `DISABLE_SSL=true`.
- `/rails/storage` holds the database, uploads, backups and certificates. Existing
  installations must retain their storage and secrets.
- Web Push requires a valid P-256 VAPID key pair in URL-safe Base64. Use your own
  production secrets; `parity/reference.env` contains public test keys.
- Jobs run inside the app process; queued pushes and webhooks are lost if it
  crashes. `CAMPFIRE_JOBS_ADAPTER=disabled` turns the queue off.
- Bandit listens on `HTTP_PORT` (and `HTTPS_PORT` with `TLS_DOMAIN`). Forwarded
  headers are handled as Thruster did (`FORWARD_HEADERS`).
- The image includes ONCE backup/restore hooks. Fresh installation, backup/restore
  and Rails → Elixir → Rails rollback have passed on disposable volumes. A hosted
  image and automated release publishing are not configured in this repository.

## Performance

Production images, the same populated seed and four pinned hardware threads per app
on an AMD Ryzen AI MAX+ 395. These are medians of two runs per version on October 4,
2026. Elixir comes from the earlier alternating Elixir/older-Rust runs; Ruby, Go
and the optimized Rust version were each measured separately afterward with the
same harness and settings, using each public server with gzip. The
[full report](bench/results/ruby-elixir-go-rust-20261004/report.md) preserves ranges,
image IDs, response sizes and the original measurement environments.

The measured code revisions are Elixir
[`3498c18`](https://github.com/basecamp/once-campfire-elixir/commit/3498c18f3705de2bcaff778132cd5699199e1cbc),
Rails [`90b3300`](https://github.com/basecamp/once-campfire/commit/90b330024dec3e757c79b6a7e6568f93da8e3148),
Go [`504428a`](https://github.com/basecamp/once-campfire-go/commit/504428addff333549f1fc88b003c7331779a3c2a),
and Rust
[`1ea6d6f`](https://github.com/basecamp/once-campfire-rust/commit/1ea6d6f6b24fd21e7d01e69b7c92df5c380bcbde),
using the same optimized production image as the Rust README. The report retains
the image ID; its build revision identifies the measured Rust code. The local
checkout recorded by the harness is used for the seed and is a different revision.
Go's published HTTP comparison uses its direct application listener with identity
encoding; this table measures its production public server with gzip.

### HTTP throughput (16 concurrent clients)

| Measurement | Ruby (Rails) | Elixir | Go | Rust |
|---|---:|---:|---:|---:|
| Room page | 216 req/s | 722 req/s | 3,860 req/s | 36,260 req/s |
| Messages page | 384 req/s | 1,053 req/s | 5,573 req/s | 40,872 req/s |
| Sidebar | 503 req/s | 1,275 req/s | 19,753 req/s | 34,672 req/s |
| Search | 380 req/s | 1,156 req/s | 7,053 req/s | 33,299 req/s |
| Post a message | 267 req/s | 801 req/s | 4,767 req/s | 6,896 req/s |
| Avatar | 94,703 req/s | 96,970 req/s | 200,856 req/s | 364,915 req/s |
| Static CSS | 129,639 req/s | 125,904 req/s | 289,554 req/s | 383,609 req/s |
| `/up` | 4,054 req/s | 8,493 req/s | 154,476 req/s | 230,480 req/s |

### Latency and real time

| Measurement | Ruby (Rails) | Elixir | Go | Rust |
|---|---:|---:|---:|---:|
| Room page p99, 64 clients | 474.0 ms | 108.2 ms | 60.5 ms | 3.1 ms |
| Post a message p99, 64 clients | 368.3 ms | 83.1 ms | 59.7 ms | 14.5 ms |
| Upload a 505 KB JPEG until its thumbnail is served | 57.8 ms | 92.6 ms | 28.4 ms | 28.3 ms |
| Complete broadcasts/s, 1,000 clients in one room | 12.4 | 60.2 | 239.1 | 545.6 |
| Deliveries/s, 1,000 clients in one room | 12,412 | 60,219 | 239,119 | 545,654 |
| Paced post → all 1,000 clients, p50 | 134.6 ms | 18.3 ms | 9.4 ms | 6.2 ms |
| Paced post → all 1,000 clients, p99 | 188.4 ms | 21.7 ms | 15.9 ms | 8.5 ms |
| Connect and subscribe 1,000 clients | 1.50 s | 0.40 s | 0.17 s | 0.12 s |

Every client subscribed and received every paced and saturated broadcast. All HTTP
workloads returned validated successful responses with zero errors. Cable uses one
authenticated user with many connections; these loopback measurements exclude TLS
and NIC costs.

### Startup, memory and image size

| Measurement | Ruby (Rails) | Elixir | Go | Rust |
|---|---:|---:|---:|---:|
| Cold start until `/up` answers | 2,601 ms | 530 ms | 145 ms | 177 ms |
| Idle container memory, including page cache | 298 MiB | 152 MiB | 16 MiB | 32 MiB |
| Peak anonymous container memory | 1,419 MiB | 564 MiB | 349 MiB | 268 MiB |
| App memory, 1,000 idle clients (PSS) | 678 MiB | 394 MiB | 169 MiB | 126 MiB |
| App memory, 1,000 clients under load (PSS) | 991 MiB | 423 MiB | 218 MiB | 125 MiB |
| Whole container, 1,000 clients under load (PSS) | 1,381 MiB | 600 MiB | 218 MiB | 125 MiB |
| Image size, unpacked | 1,232 MiB | 2,490 MiB | 230 MiB | 225 MiB |

Ruby includes Puma, Redis and Thruster. Elixir includes BEAM, Redis, native helpers
and Thruster. Go and Rust each use one integrated app/server process. Container memory varies
with page cache; PSS apportions shared pages. MiB means 1,048,576 bytes.

The earlier [Elixir tuning comparison](bench/results/tuning-comparison.md) records an 8.07×
CSS improvement, 3.42× improvement in 1,000-client fanout and 1.65× improvement in
message posting over the initial Elixir build, using an older Rust image. Both tuned Elixir runs ended with
empty job queues and no failed jobs. Rust remains substantially faster on dynamic
HTTP and fanout.

## Development

The project follows [rails-to-rust](https://github.com/basecamp/rails-to-rust): an
immutable reference, source inventory, runtime oracles, captured compatibility
vectors, generated records/routes, HTTP and mutation comparisons, an evidence
ledger and reusable migration tooling in [`tools/rails-to-elixir/`](tools/rails-to-elixir).
The Rails reference is pinned to
[`90b3300`](https://github.com/basecamp/once-campfire/commit/90b330024dec3e757c79b6a7e6568f93da8e3148).

Use the Docker toolchain above, then run:

```sh
bin/mix format --check-formatted
bin/mix compile --warnings-as-errors
bin/mix test --warnings-as-errors
bin/parity-services start
bin/rails-to-elixir parity --force
bin/rails-to-elixir mutation-diff --force
bin/rails-to-elixir doctor
bin/parity-services stop
```

The complete verified run passes **65 gates and 1,896 tests**, including actual
Chromium flows, all-table/FTS/storage mutation snapshots, injected transaction
failures, media operations, cross-runtime Cable delivery and session revocation,
worker claims/failures/drain, webhook replies and encrypted HTTPS push delivery,
TLS/HTTP2, fresh schema/setup and production rollback. See the
[evidence ledger](plans/contracts.json), [verification record](parity/results/verification.json)
and [conversion state](plans/elixir-conversion.md).

The fixture services use isolated data, Redis and ports 47070/47071/47079. Frozen
Rails comparisons additionally require the `campfire-reference:latest` image from
the Rust parity harness, built from the same pinned reference. Live gates reset
their fixture data and must run sequentially. Unit tests disable the HTTP server
and external job adapter.

For the full gate run, start a disposable Chromium instance on port 47080 with a
separate profile, then start the fixture services:

```sh
mkdir -p var
chromium --headless=new --no-sandbox --disable-dev-shm-usage --no-first-run \
  --disable-extensions --disable-background-networking \
  --user-data-dir="$PWD/var/browser-profile-isolated" \
  --remote-debugging-port=47080 \
  --host-resolver-rules='MAP campfire.test 127.0.0.1' about:blank \
  > var/browser.log 2>&1 &
bin/parity-services start
bin/verify-parity
```

The browser gate creates and disposes separate contexts for Rails and Elixir.
Benchmarks run separately from verification; see [`bench/README.md`](bench/README.md)
for the workload, validation and reproduction commands.

## Known differences

The compatibility checks retain explicit rich-text comparison rules:

- Attribute values escape `<` and `>` to prevent stored XSS, following the Rust
  port's protection. Autolinks are never inserted inside attributes.
- Malformed rich-text failures are compared by category because Ruby and Elixir
  exception classes and diagnostic wording differ.
- When Rails' rescue logger fails on invalid UTF-8, native presentation returns
  the intended empty string. Failed plain-text extraction renders the Rails
  failed-message partial.

The corpus covers 1,058 stored-content cases. The native parser uses unmodified
Gumbo sources from Rails' Nokogiri 1.19.4. Expected oracle output is retained;
raw differences and the comparison rules are documented in
[`plans/richtext-comparison.md`](plans/richtext-comparison.md).

Performance changes deliberately depart from Rails, most of them following the
[Rust port's known differences](https://github.com/basecamp/once-campfire-rust#known-differences).
The affected contracts are pending in `plans/contracts.json` until they are re-verified:

- **CSRF:** `Sec-Fetch-Site` replaces tokens. Writes are accepted when it is
  `same-origin` or `same-site`, or when it is missing on plain HTTP, and are refused
  (422) otherwise or when `Origin` is `null` or differs from the base URL. Pages
  carry no `authenticity_token` inputs. The `csrf-token` meta tag is kept but
  empty, so `file_uploader.js` is unchanged. Pages render the same on every
  request, so their ETags are stable and revalidate with 304.
- **Cookies:** `_campfire_session` is written only when its data changes, so a
  visitor has none until a flash or return-to is stored. `session_token` is
  re-signed only when a session starts or its hourly activity refresh runs. It
  keeps its 20-year expiry.
- **SQLite:** boot adds `index_messages_on_room_id_and_created_at` if it is
  missing (additive; the Rails image ignores it). Memory mapping is disabled.
- **Jobs and Cable:** in-process queues and fan-out replace Redis/Resque, so
  queued jobs are lost on a crash and there is no cross-runtime pub/sub.
- **Front server:** Bandit replaces Thruster. Responses gzip at zlib level 1
  (Rails uses 6), so decoded bodies are unchanged but the compressed bytes are
  not. A complete gzipped body is sent with `Content-Length` rather than chunked.
  A spliced page's ETag digests its per-request text and cached fragment digests
  rather than the whole body.

Rust uses a different frontend/server implementation. Each port's process model,
response sizes and compression ratios are recorded with the benchmarks. No
production cutover has been performed.

## License

MIT. See [`MIT-LICENSE`](MIT-LICENSE).
