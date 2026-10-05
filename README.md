# Campfire in Elixir

An Elixir implementation of [ONCE Campfire](https://github.com/basecamp/once-campfire).
It keeps the existing SQLite database, storage layout, signed/encrypted cookies and
Action Cable protocol, so existing installs can retain their data and sessions.

The application runs on Elixir 1.20.4 / OTP 29 with Bandit and Plug. Local OTP
registries handle broadcasts, ETS holds rendered fragments, and a persistent Redis
queue feeds the native Resque-compatible worker. The same Thruster binary as Rails
handles TLS, HTTP/2 and proxy caching. libvips and FFmpeg process media. The Rails
frontend is preserved, including Turbo and the composer.

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

The latest matched comparison freezes upstream baseline `b6b82e5` and candidate
`7c1ed67` on Elixir 1.20.4 / OTP 29.1.1 with four server and four load-generator
CPUs, the same populated seed, four balanced rounds, and validated HTTP, Cable and
upload responses. Results are platform-specific; they do **not** establish a general
performance improvement.

The native x86_64 Linux run is the authoritative clean benchmark: all eight rounds
ended with empty job queues and zero failed jobs. At 16 HTTP connections the
candidate regressed on every populated dynamic route and on Cable fanout:

| Native x86_64 Linux metric | Baseline | Candidate | Change |
|---|---:|---:|---:|
| Room page | 305.4 req/s | 255.8 req/s | −16.3% |
| Messages page | 429.5 req/s | 330.3 req/s | −23.1% |
| Sidebar | 462.0 req/s | 243.5 req/s | −47.3% |
| Search | 448.8 req/s | 318.9 req/s | −28.9% |
| Post a message | 287.6 req/s | 174.1 req/s | −39.5% |
| Cable, 1,000 clients | 34.85 msg/s | 33.20 msg/s | −4.7% |

Native ARM64 Linux containers under OrbStack on an M4 Pro showed different response
rates: room, messages, search and posting improved at 16 connections, while sidebar
regressed 6.8%. Those are qualified shared-workstation observations, not a clean
benchmark result: unrelated macOS activity drove host load as high as 29.06, and one
candidate round retained 1,125 queued jobs. All rounds remain in the evidence; none
was removed or replaced after seeing its result.

See the [clean Linux report](bench/results/native-linux-b6b82e5-7c1ed67-20261005-nofile65536/README.md)
and [qualified M4 report](bench/results/m4-arm64-b6b82e5-7c1ed67-20261005/README.md)
for medians, complete ranges, raw interleaved records, immutable image/runtime
identities, fixture provenance and limitations. No cause for the cross-platform
performance difference was isolated.

### October 4 four-language comparison

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

The complete verified run passes **65 gates and 1,929 tests**, including actual
Chromium flows, all-table/FTS/storage mutation snapshots, injected transaction
failures, media operations, cross-runtime Cable delivery and session revocation,
worker claims/failures/drain, webhook replies and encrypted HTTPS push delivery,
TLS/HTTP2, fresh schema/setup and production rollback. See the
[evidence ledger](plans/contracts.json), [verification record](parity/results/verification.json)
and [conversion state](plans/elixir-conversion.md).

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
The current SQLite design keeps one serialized writer and uses WAL-backed pooled
readers; Redis remains only for cross-process job transport. A new matched benchmark
of those changes is recorded above: it regressed dynamic HTTP and Cable throughput on
native x86_64 Linux, while the qualified M4 observations were mixed and failed the
fully-drained-job audit. Replacing Redis entirely would require a durable transactional
outbox or an explicitly accepted loss of queued work.
No production cutover has been performed.

## License

MIT. See [`MIT-LICENSE`](MIT-LICENSE).
