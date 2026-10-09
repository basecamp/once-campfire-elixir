# once-campfire-elixir

Port of the Rails Campfire in `reference/`, pinned as a submodule. Preserve the SQLite
schema, storage layout, signed/encrypted cookies, frontend, Action Cable protocol, and
behavior of the Rails app. Further improvements should use the Rust port
(basecamp/once-campfire-rust) as reference. Record intentional differences in README.md.

Use OTP and the Elixir standard library first: Plug and Bandit for HTTP, :json, :crypto,
ETS, :persistent_term, and ExUnit. No web framework, ORM, or JavaScript build framework.
Small libraries are appropriate where OTP has no implementation (SQLite, bcrypt, HTML
parsing, QR codes). Native code lives in native/: the HTML parser is built with
elixir_make, and the campfire-vips media helper (native/vips.c, against libvips) is compiled
by bin/setup-local into var/bin/ and by Dockerfile.dev into the toolchain image.

Do not edit reference/. Port-owned frontend overrides go in assets/overrides/. Keep domain
policy app-owned and reusable Rails compatibility in separate modules. Tests live in test/.
Reuse vectors/ and the parity seed. Use the rails-to-elixir inventory, oracle, parity,
mutation-diff, doctor and benchmark workflow (parity/ and tools/rails-to-elixir/), adapted from
rails-to-rust. Do not report total parity while any contract is pending or without browser,
mutation, realtime, storage, jobs and rollback evidence.
Never benchmark an incomplete response as if it were the full application.
Use identical data, response validation, CPU affinity, encoding, warmup, repetitions,
and sequential interleaved runs. Record raw measurements and limitations in bench/results/.

Use `bin/setup-local` for native development, or `bin/mix` for the pinned toolchain.
Tests run with CAMPFIRE_NO_SERVER=1, CAMPFIRE_JOBS_ADAPTER=disabled and var/bin on PATH.
Run mix format --check-formatted and mix test --warnings-as-errors before committing.
