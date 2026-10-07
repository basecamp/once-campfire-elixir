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

Measured with 16 concurrent clients on an AMD Ryzen AI MAX+ 395,
with four hardware threads allocated to each app.

| HTTP workload (requests/sec) | Rails | [Django](https://github.com/basecamp/once-campfire-django) | [Laravel](https://github.com/basecamp/once-campfire-laravel) | [Express](https://github.com/basecamp/once-campfire-express) | [Elixir](https://github.com/basecamp/once-campfire-elixir) | [Go](https://github.com/basecamp/once-campfire-go) | [Rust](https://github.com/basecamp/once-campfire-rust) |
|---|---:|---:|---:|---:|---:|---:|---:|
| Room page | 241 | 170 | 164 | 559 | 722 | 3,860 | 36,260 |
| Messages page | 413 | 196 | 175 | 777 | 1,053 | 5,573 | 40,872 |
| Sidebar | 552 | 615 | 715 | 4,125 | 1,275 | 19,753 | 34,672 |
| Search | 435 | 315 | 305 | 1,294 | 1,156 | 7,053 | 33,299 |
| Post a message | 273 | 154 | 137 | 256 | 801 | 4,767 | 6,896 |

See [benchmark commands](bench/README.md) and [earlier measurements](bench/results/ruby-elixir-go-rust-20261004/report.md).

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
  `same-origin` or `same-site`. Without it (plain HTTP, or an old browser) a write needs an
  `Origin` equal to the base URL. Anything else is refused (422), as is an `Origin` that is
  `null` or differs from the base URL. Pages
  carry no `authenticity_token` inputs. The `csrf-token` meta tag is kept but
  empty, so `file_uploader.js` is unchanged. Pages render the same on every
  request, so their ETags are stable and revalidate with 304.
- **Cookies:** `_campfire_session` is written only when its data changes, so a
  visitor has none until a flash or return-to is stored. `session_token` is
  re-signed only when a session starts or its hourly activity refresh runs. It
  keeps its 20-year expiry.
- **SQLite:** boot adds `index_messages_on_room_id_and_created_at` if it is
  missing (additive; the Rails image ignores it). Memory mapping is disabled.
- **Read cache:** reads are kept until a table they read is written. Writes through the app bump
  their tables after commit. Commits by any other SQLite client are seen through the WAL index
  (`-shm`) header and invalidate everything, so tools that edit the database while the app runs
  remain safe.
- **Regexes and native reads:** literal regexes are compiled once and kept
  (`Campfire.Sigils`), since OTP 28+ re-imports an inline `~r` at every evaluation. Short reads
  run in one NIF call on the calling scheduler (`native/sqlite_read.c`, linked against the
  same system SQLite as Exqlite and only built with `EXQLITE_USE_SYSTEM`) and fall back to
  the pooled readers; `CAMPFIRE_DB_NATIVE_READS=0` turns that off. The WAL index header is read through one kept
  descriptor. None of these change responses.
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
