# Rails to Elixir

An evidence-driven migration toolkit adapted from rails-to-rust. Python 3.11+ and
Git are required for the CLI. Generated application code uses Elixir/Mix.

```sh
bin/rails-to-elixir init ../rails-app ../app-elixir --name app
```

The initializer pins a reference submodule and installs an Elixir starter (HTTP
501), phase skills, inventory, contracts ledger, oracle scripts, and a project-local
copy of this toolkit. It does not transpile application behavior.

Commands: `inspect`, `oracle runtime|schema|routes`, `generate records|routes|contract-test`,
`parity`, `mutation-diff`, `doctor`, `verify`, and `benchmark`. Configure runtime and
fixture commands in migration.toml. Generated route tables retain ordering and
opaque constraints; they are contracts, not a route recognizer. Unsupported storage
codecs fail explicitly. Tests intentionally fail until contract adapters exist.

Oracle framing/environment names retain RAILS_TO_RUST for compatibility with the
original reference exporter. Benchmarks compare balanced process runs and preserve
raw rounds; an incomplete application is not a valid capacity comparison.

```sh
python3 -m unittest discover -s tests -v
```
