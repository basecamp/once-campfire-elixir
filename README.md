# Campfire in Elixir

All nine compatibility contracts are verified against the pinned Rails reference.
The complete tuned suite passes 65 gates and 1,896 tests, including actual browser,
mutation, realtime, storage, jobs, TLS/HTTP2 and production rollback checks. The Rails
reference is pinned to `90b330024dec3e757c79b6a7e6568f93da8e3148`, also used by the Rust port.

The structure follows rails-to-rust: an immutable reference, source inventory,
live runtime/schema/routes oracle, compatibility vectors, generated Elixir storage
records and route contracts, HTTP and mutation comparisons, an evidence ledger,
and reusable migration skills and CLI in `tools/rails-to-elixir/`.

Implemented and live-compared slices now include Rails cookies/CSRF and login,
first-run setup, account/user/bot/room mutations, native message HTML and Turbo
responses, closed/open/direct room pages and permalink pagination, the sidebar,
mention autocomplete, notification controls, Active Storage direct uploads and
byte ranges, multipart message attachments, native libvips image variants, FFmpeg
video previews, avatar/logo replacement and recursive blob cleanup, and all
Campfire Action Cable channel families. Native and Rails
connections interoperate through Redis, including remote revocation. Native Resque
workers have delivered webhook text replies against a controlled local sink with
all persisted tables compared to Rails. Web Push cryptography and the pinned
Surfguard address policy are covered by reference vectors.

The expanded rich-text comparison includes 1,058 stored-content cases generated
from the pinned Rails runtime. Native Gumbo sources are vendored from Nokogiri
1.19.4; the application requires no Ruby process. The comparison retains the Rust
port's attribute escaping protection and treats equivalent runtime exceptions by
category. A Rails rescue logger failure on invalid UTF-8 becomes an empty native
presentation. Raw differences are preserved separately. See
[rich-text comparison rules](plans/richtext-comparison.md).

The standalone native production image uses the same pinned Thruster binary as
Rails for TLS/HTTP2, proxy caching and timeouts. Its app listener is private;
forwarded URL context is accepted from the local proxy. ONCE fresh installation,
backup/restore, active HTTP/job shutdown and Rails→Elixir→Rails rollback have passed
on disposable volumes. No production cutover has been performed.

The [evidence ledger](plans/contracts.json) and
[complete verification record](parity/results/verification.json) retain the exact
scopes and source digest. The compatibility bar includes the explicit rich-text
escaping and error rules above. Application benchmarks compare the production
images with the Rust port's unchanged populated fixture, matched CPUs and encoding,
balanced alternating rounds and response validation; see [bench/](bench/README.md).

Elixir runs in an isolated Docker toolchain; no system language packages are changed:

```sh
docker build -f Dockerfile.dev -t campfire-elixir:toolchain .
bin/mix local.hex --force
bin/mix local.rebar --force
bin/mix deps.get
bin/export-assets
bin/mix test --warnings-as-errors
bin/mix format --check-formatted
```

The oracle and asset export require the matching `campfire-reference:app` image.
Frozen-clock HTTP comparisons additionally use the existing
`campfire-reference:latest` parity image from once-campfire-rust. Both are checked
against the pinned source. The fixture servers use isolated databases, a dedicated
Redis, and ports 47070/47071/47079:

```sh
bin/parity-services start
bin/rails-to-elixir parity --force
bin/rails-to-elixir mutation-diff --force
bin/rails-to-elixir doctor
bin/parity-services stop
```

`bin/parity-services start/reset` replaces only this port's disposable fixture data.
`bin/mix` disables the HTTP server and external job adapter for unit tests; the live
HTTP/mutation gates enable both. JSON comparisons retain record identity and values;
PWA and error pages are compared as bytes. Mutation snapshots validate and mask only
new random UUID v4 identifiers, with both clocks frozen. That mutation gate captures queued jobs. Separate live gates in `parity/` exercise
worker execution and realtime delivery. Their result files record the tested scope.

The [baseline benchmarks](bench/results/baseline-20261004/report.md) are complete.
The tuned build passes complete verification, and both matched benchmark rounds are complete.
See the [before/after comparison](bench/results/tuning-comparison.md) and
[full tuned report](bench/results/tuned-fifo-20261004/report.md). The incomplete
first tuning attempt is retained as diagnostic evidence.
Tuning improved CSS throughput 8.07×, 1,000-client fanout 3.42× and message posting
1.65×; peak anonymous memory fell 42.7%. Both tuned rounds ended with zero queued
or failed jobs. Rust remains 26.0× faster on room pages and 8.21× faster on
1,000-client fanout. See [conversion state](plans/elixir-conversion.md).

Additional isolated live gates (run sequentially; each restores fixture services):

```sh
python3 parity/sessions.py
python3 parity/first_run.py
python3 parity/administration.py
python3 parity/storage.py
python3 parity/cable.py
python3 parity/cable_interop.py
python3 parity/messages.py
python3 parity/message_broadcasts.py
python3 parity/room_page.py
python3 parity/jobs.py
python3 parity/media.py
python3 parity/attachments.py
python3 parity/branding.py
```

`bin/jobs` starts the native Resque consumer using the app's database, Redis and
storage environment. Actual worker failure, claim and active-job shutdown evidence
is recorded in `parity/results/worker-lifecycle.json`.

To reproduce the complete sequential gate run, start a disposable Chromium CDP
instance for the browser gate (port 47080, a separate profile, and local-only
`campfire.test` resolution), then start the fixture services:

```sh
chromium --headless=new --no-sandbox --disable-dev-shm-usage --no-first-run \
  --disable-extensions --disable-background-networking \
  --user-data-dir="$PWD/var/browser-profile-isolated" \
  --remote-debugging-port=47080 \
  --host-resolver-rules='MAP campfire.test 127.0.0.1' about:blank \
  > var/browser.log 2>&1 &
bin/parity-services start
bin/verify-parity
```

The browser gate creates and disposes separate browser contexts for each runtime.
All other live gates reset their own fixture data; run them sequentially.
