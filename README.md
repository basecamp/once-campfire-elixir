# Campfire in Elixir

An Elixir implementation of [ONCE Campfire](https://github.com/basecamp/once-campfire).
It keeps the existing SQLite database, storage layout, signed/encrypted cookies and
Action Cable protocol, so existing installs can retain their data and sessions.

This is a compatibility and performance demonstration. Its release-image benchmarks
and parity checks are not a production-readiness guarantee.

The application runs on Elixir 1.20.4 / OTP 29 with Bandit and Plug. Local OTP
registries handle broadcasts, ETS holds rendered fragments, and a persistent Redis
queue feeds the native Resque-compatible worker. The same Thruster binary as Rails
handles TLS, HTTP/2 and proxy caching. libvips and FFmpeg process media. The Rails
frontend is preserved, including Turbo and the composer.

SQLite uses Exqlite's native driver with one writer and supervised readonly owners.
Each reader reuses up to 64 prepared statements, rebinds parameters on every read,
and releases statements on eviction, failure and shutdown. Query results are not
cached. Transaction-local reads stay with the writer; ordinary reads use up to eight
reader processes when multiple schedulers are online. There is no whole-response cache.

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

On an Apple Silicon Mac building `linux/amd64` images through Rosetta, OTP's JIT may
fail during the build because userspace emulation cannot use its default dual memory
mapping. Opt in to single-mapped JIT memory for that local image only:

```sh
docker build --platform linux/amd64 -f Dockerfile.dev \
  --build-arg ERL_FLAGS='+JMsingle true' -t campfire-elixir:toolchain .
```

The build argument is empty by default, so native Linux production images retain
OTP's normal JIT configuration. Record this flag and the emulated architecture in
benchmark metadata; use the same flag for every compared arm.

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
- Redis starts inside the container by default with AOF persistence under
  `/rails/storage/redis`. `REDIS_URL` selects an external Redis, whose durability is
  then the operator's responsibility. Redis transports jobs only; request fragment
  caching and single-node Cable fanout remain in the BEAM. The native job worker
  starts automatically; `bin/jobs` can also run it against the same database, Redis
  and storage environment. During a rolling Rails-to-Elixir cutover,
  `CAMPFIRE_CABLE_REDIS_BRIDGE=1` temporarily bridges Action Cable broadcasts through
  the shared Redis instance; normal single-node operation should leave it disabled.
- The app listener binds loopback behind Thruster. Forwarded URL headers are
  trusted from the local proxy. The Dockerfile selects the pinned Thruster binary
  for amd64/x86_64 or arm64/aarch64 release images.
- The image includes ONCE backup/restore hooks. Fresh installation, backup/restore
  and Rails → Elixir → Rails rollback have passed on disposable volumes. A hosted
  image and automated release publishing are not configured in this repository.

## Performance

The current reader/statement-cache candidate improves populated HTTP throughput in
a same-host, four-round comparison against untouched upstream, but **high-concurrency
rendering latency still regresses**. This is work in progress, not a universal speedup.

Hardware: native amd64 Linux orb, guest-reported **Intel Xeon @ 2.60 GHz, 16 vCPUs,
31 GiB RAM**. The server was pinned to guest CPUs `0,2,4,6`, the load generator to
`8,10,12,14`; these are CPU affinity sets, not a claim of separate physical cores.
Both production images used Elixir 1.20.4 / OTP 29.1.1 JIT, four online normal
schedulers, default dirty-IO scheduling, equal 65,536 descriptor limits and Thruster.
These absolute rates are **not directly comparable** with the Ryzen numbers below.

| Native amd64 Linux, 16 connections | Upstream req/s | Candidate req/s | Change |
|---|---:|---:|---:|
| Room page | 287.55 | 343.25 | +19.4% |
| Messages page | 392.35 | 453.65 | +15.6% |
| Sidebar | 449.00 | 733.10 | +63.3% |
| Search | 415.75 | 641.65 | +54.3% |
| Post a message | 273.40 | 396.30 | +45.0% |

At 64 connections, room p99 rose **260 → 401 ms (+54.4%)** and messages p99
**210 → 393 ms (+87.0%)**, worsening in every paired round. Sampled whole-run
cgroup peak memory rose 574.5 → 620 MiB. Cable throughput improved, but saturated
1,000-client p99 also rose 12.3%. These regressions remain unresolved.

The run retained all 192 twelve-second HTTP cells (12,858,383 successes), 24 Cable
cases and 40 uploads, with zero reported errors, complete fanouts and drained jobs.
See the [current comparison and limitations](bench/results/native-linux-b6b82e5-cache-115cabc-20261005-http12-nofile65536/README.md)
for complete ranges, exact source/image provenance and the evidence archive identity.
Raw records are preserved locally and available on request, rather than included in
the review diff. Earlier runs and failed diagnostics are also retained locally.
This measures the whole candidate, not the statement cache in isolation.

### Upstream seven-language comparison

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

### Local macOS development (no Docker)

The pinned Docker toolchain uses Elixir 1.20.4 / OTP 29; native development is also
tested with Elixir 1.19.5 / OTP 28. Use Ruby 3.4.10 (the version in
`reference/.ruby-version`) on your `PATH`. Ruby is only needed to build the genuine
Rails frontend, not to compile or run Elixir afterward. Install Xcode Command Line
Tools (`xcode-select --install`), Bundler, and the native media dependencies:

```sh
brew install vips ffmpeg pkg-config
gem install bundler -v 4.0.13
bin/setup-local
```

`bin/setup-local` initializes the pinned submodule, runs `bin/export-assets --local`,
compiles the libvips helper into `var/bin`, and fetches Hex dependencies. Mix compiles
the vendored Gumbo helper during the first Elixir build. Asset export installs the frozen
Rails bundle and precompiles assets in a disposable copy under `var/`; it never runs
Bundler or Rails inside `reference/`. The first run needs network access to public
GitHub, RubyGems and Hex sources. No reference/toolchain Docker images, Redis service
or Rails secrets are required.

In each shell, from the repository root:

```sh
export PATH="$PWD/var/bin:$PATH"
export CAMPFIRE_NO_SERVER=1 CAMPFIRE_JOBS_ADAPTER=disabled
export DATABASE_PATH="$PWD/var/test.sqlite3"

mix format --check-formatted
mix compile --warnings-as-errors
mix credo --strict
mix dialyzer
mix test --warnings-as-errors
```

The database must be disposable: tests restore fixtures into it. These environment
variables reproduce the test isolation supplied by `bin/mix`, which remains a
**Docker wrapper**. Use plain `mix` for native development. Do not reuse `_build/`
or `deps/` between host and Docker builds; remove those generated directories and
fetch dependencies again when switching toolchains. Dialyzer builds its PLT on
the first run, so expect that run to take longer.

**Media parity is platform-dependent.** The full local test command intentionally
keeps the exact Linux byte/checksum assertions in `media_test.exs` and
`transformations_test.exs`. Homebrew libvips/FFmpeg and their codecs can produce
different bytes; these failures do not indicate a missing bootstrap step. On macOS
with libvips 8.18.7, 33 such assertions failed while all other tests passed. Use the
pinned Docker toolchain for authoritative byte-level media parity; do not regenerate
the Rails vectors or weaken these assertions to accommodate host codec versions.

Native development also uses Exqlite's bundled SQLite build, while the pinned Docker
toolchain sets `EXQLITE_USE_SYSTEM=1` and links the image's SQLite library. Both must
pass the same database behavior tests, but record this engine difference alongside
codec versions when comparing local results; pinned Docker remains authoritative for
matched parity and benchmark evidence.

If only the asset manifest is missing, `bin/export-assets --local` is sufficient
(with the pinned submodule, Ruby and Bundler installed). No placeholder manifest is
used. Without `--local`, export still requires the revision-matched
`campfire-reference:app` image from the production build instructions above.

### Pinned Docker parity workflow

Build the Docker toolchain and reference image above, then run:

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

The complete native amd64 and ARM64 Linux runs pass **65 gates and 1,941 tests**, including actual
Chromium flows, all-table/FTS/storage mutation snapshots, injected transaction
failures, media operations, cross-runtime Cable delivery and session revocation,
worker claims/failures/drain, webhook replies and encrypted HTTPS push delivery,
TLS/HTTP2, fresh schema/setup and production rollback. See the exact
[statement-cache verification summary](parity/checkpoints/20261005-statement-cache/README.md)
for source/image identities, archive checksums and limitations. Detailed receipts
for both architectures are preserved locally and available on request. The
[contract ledger](plans/contracts.json), [historical verification record](parity/results/verification.json)
and [conversion state](plans/elixir-conversion.md) retain the earlier migration evidence.

Strict compilation, Credo, Dialyzer, 37 toolkit tests and the load-generator test/check
also pass. Additional release-image probes verify reads during an open writer
transaction, committed-value visibility, and automatic replacement of a killed reader.
The recovery probe does not establish continuity of an in-flight call.

The fixture services use isolated data, Redis and ports 47070/47071/47079. Frozen
Rails comparisons additionally require the `campfire-reference:latest` image from
the public Rust parity harness. Its initial self-contained Docker resources are at
[`95af38b`](https://github.com/basecamp/once-campfire-rust/commit/95af38bcc90f0ab06f703007ca25aa9e199536f1),
which pins the same Rails revision. Build both reference tags from a separate clone:

```sh
git clone --recurse-submodules https://github.com/basecamp/once-campfire-rust.git
cd once-campfire-rust
git checkout 95af38bcc90f0ab06f703007ca25aa9e199536f1
git submodule update --init reference
PARITY_RUNTIME=docker parity/bin/reference build
```

This produces `campfire-reference:app` and the parity wrapper
`campfire-reference:latest`. On Apple Silicon, use architecture-matched ARM64 images
and the recorded ARM64 media oracle, or run the benchmark's documented `linux/amd64`
environment consistently; do not mix native and emulated images within a comparison.
Live gates reset their fixture data and must run sequentially. Unit tests disable the
HTTP server and external job adapter.

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

The corpus covers 1,058 stored-content cases. Four supervised, persistent helper
processes run Gumbo from Rails' Nokogiri 1.19.4 outside the BEAM. Expected oracle
output is retained; raw differences and the comparison rules are documented in
[`plans/richtext-comparison.md`](plans/richtext-comparison.md).

Each helper limits Gumbo allocations to 256 MiB and enforces a 25-second parse and
serialization deadline without restricting platform runtime or emulator memory.
Native allocator failures, assertions, pathological expansion and timeouts terminate
and replace only that helper; they fail the parser call rather than the application VM.
Helpers also recycle after returning at least 1 MiB of serialized output to release
platform allocator high-water memory.

Serialized parser output intentionally remains uncapped so valid large documents keep
Rails behavior. A compact adversarial fragment can therefore expand into a large port
packet and decoded BEAM terms; the helper allocation limit does not bound that caller
memory. This is a known residual resource-exhaustion risk rather than a claimed fix or
an undocumented compatibility limit.

Elixir retains Redis and Resque-compatible jobs, while Rust uses integrated
queues and a different frontend/server implementation. Their actual process
models, response sizes and compression ratios are recorded with the benchmarks.
The current SQLite design keeps one serialized writer and WAL-backed readonly
owners with prepared-statement caches; Redis remains for cross-process job transport.
The historical benchmark above predates this reader design. Replacing Redis entirely
would require a durable transactional outbox or an explicitly accepted loss of queued work.
No production cutover has been performed.

## License

MIT. See [`MIT-LICENSE`](MIT-LICENSE).
