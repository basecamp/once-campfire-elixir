# Campfire in Elixir

An Elixir implementation of [ONCE Campfire](https://github.com/basecamp/once-campfire).
It keeps the existing SQLite database, storage layout, signed/encrypted cookies and
Action Cable protocol, so existing installs can retain their data and sessions.

The application runs on Elixir 1.20.4 / OTP 29 with Bandit and Plug. Redis and a
native Resque-compatible worker handle jobs and broadcasts; the same Thruster
binary as Rails handles TLS, HTTP/2 and proxy caching. libvips and FFmpeg process
media. The Rails frontend is preserved, including Turbo and the composer.

## Running it

Build the production image locally. The build uses the pinned Rails reference for
assets and Thruster; check out the submodule first:

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

- `TLS_DOMAIN` enables Thruster's automatic Let's Encrypt certificates. For local
  plain HTTP, omit it and set `DISABLE_SSL=true`.
- `/rails/storage` holds the database, uploads, backups and certificates. Existing
  installations must retain their storage and secrets.
- Web Push requires a valid P-256 VAPID key pair in URL-safe Base64. Use your own
  production secrets; `parity/reference.env` contains public test keys.
- Redis starts inside the container by default. `REDIS_URL` selects an external
  Redis. The native job worker starts automatically; `bin/jobs` can also run it
  against the same database, Redis and storage environment.
- The app listener binds loopback behind Thruster. Forwarded URL headers are
  trusted from the local proxy. The current Dockerfile packages the amd64
  Thruster binary.
- The image includes ONCE backup/restore hooks. Fresh installation, backup/restore
  and Rails → Elixir → Rails rollback have passed on disposable volumes. A hosted
  image and automated release publishing are not configured in this repository.

## Performance

Measured with 16 concurrent clients on an AMD Ryzen AI MAX+ 395 with 32 GB RAM,
with four hardware cores allocated to each app.

| HTTP workload (requests/sec) | Rails | [Django](https://github.com/basecamp/once-campfire-django) | [Laravel](https://github.com/basecamp/once-campfire-laravel) | [Express](https://github.com/basecamp/once-campfire-express) | [Elixir](https://github.com/basecamp/once-campfire-elixir) | [Go](https://github.com/basecamp/once-campfire-go) | [Rust](https://github.com/basecamp/once-campfire-rust) | [C](https://github.com/basecamp/once-campfire-c) |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Room page | 4,101 | 1,507 | 3,872 | 42,636 | 5,350 | 53,060 | 106,494 | 137,524 |
| Messages page | 4,115 | 1,596 | 3,995 | 74,362 | 5,712 | 54,800 | 102,697 | 144,642 |
| Sidebar | 4,333 | 1,873 | 4,493 | 94,329 | 5,949 | 59,144 | 120,294 | 152,002 |
| Search | 4,282 | 1,862 | 4,172 | 84,665 | 5,848 | 60,509 | 121,378 | 149,487 |
| Post a message | 330 | 262 | 794 | 2,155 | 1,278 | 9,021 | 8,037 | 7,530 |
| Application KLOC | 12.9 | 11.3 | 10.0 | 13.3 | 19.9 | 29.8 | 38.5 | 101.1 |

KLOC counts application code, templates and first-party frontend, excluding tests, dependencies and generated files.

[Shared verification](https://github.com/basecamp/once-campfire-verification) · [Detailed results](https://github.com/basecamp/once-campfire-verification/blob/main/docs/performance-review.md).

See [benchmark commands](bench/README.md).

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

The native suite passes **1,961 tests**. The historical **65-gate** token-era parity run covered the
reviewed backend; fresh shared browser checks cover the current frontend.
Verification includes actual
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

- Browser writes use Fetch Metadata instead of CSRF tokens. Unsafe requests reject a null or
  mismatched Origin and require `Sec-Fetch-Site: same-origin` or `same-site`; missing metadata
  is accepted only over plain HTTP without `FORCE_SSL=1` or `true`. GET/HEAD and authenticated bot routes
  retain their existing behavior. Forms and uploads generate no CSRF tokens, while legacy
  signed cookies and token-bearing tabs remain readable. Signed disk PUTs use authenticated
  upload ownership and expiring capabilities independently of Fetch Metadata. Only the trusted
  local proxy can supply the effective scheme and origin.

- Message pagination ETags describe the actual rendered body, and omit Last-Modified:
  compatible SQLite writers can change rich text or related presentation without touching
  message timestamps.

- Authenticated room, message-list, sidebar and search complete HTML/gzip bodies use a bounded
  cache: 64 MiB per app, disabled with `CAMPFIRE_RESPONSE_CACHE_MB=0`.
  Authorization and cookies stay fresh; SQLite commits from any writer
  invalidate cached bodies. Fragment keys also retain the pre-render SQLite epoch and
  request host, including conditional requests and when response caching is disabled.
  JSON and conditional requests retain their native paths.

- Session-transfer auto-submit forms explicitly close their form tag; the pinned Rails
  reference omitted it.
- Background sidebar refreshes preserve an open New Ping form and selected recipients.

- Direct-ping autocomplete explicitly requests JSON, repairing the inherited fetch-header bug.

- Sidebar connection refresh waits for the current Turbo frame to finish loading,
  preventing an aborted response on startup or reconnect. Obsolete connections and removed frames do not reload.

- Search selects the newest 100 matching messages by insertion ID, then displays them in ID order. Backdated messages can appear in a different order from the original Rails app.

The compatibility checks retain explicit rich-text comparison rules:

- Attribute values escape `<` and `>` to prevent stored XSS, following the Rust
  port's protection. Autolinks are never inserted inside attributes.
- Malformed rich-text failures are compared by category because Ruby and Elixir
  exception classes and diagnostic wording differ.
- When Rails' rescue logger fails on invalid UTF-8, native presentation returns
  the intended empty string. Failed plain-text extraction renders the Rails
  failed-message partial.

The corpus covers 1,058 stored-content cases. The native parser uses Gumbo sources from Rails' Nokogiri 1.19.4,
with allocation limits and isolated, supervised worker processes. Expected oracle output is retained;
raw differences and the comparison rules are documented in
[`plans/richtext-comparison.md`](plans/richtext-comparison.md).

Set `CAMPFIRE_CABLE_REDIS_BRIDGE=1` for live Action Cable delivery between Rails
and Elixir. Elixir retains Redis and Resque-compatible jobs, while Rust uses integrated
queues and a different frontend/server implementation. Their actual process
models, response sizes and compression ratios are recorded with the benchmarks.
No production cutover has been performed.

## License

MIT. See [`MIT-LICENSE`](MIT-LICENSE).
