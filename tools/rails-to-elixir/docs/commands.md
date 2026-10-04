# Commands and configuration

`init SOURCE DEST --name app --elixir-version 1.19.5` creates an empty destination
with a pinned Rails submodule, Mix starter, migration plan, evidence ledger, phase
skills, and self-contained tools. It never modifies the reference checkout.

`inspect SOURCE` inventories the application without running Rails. `oracle KIND`
runs the configured argv and validates runtime/provenance/framing before writing
vectors. Forward RAILS_TO_RUST_EXPORT and RAILS_TO_RUST_REFERENCE_SHA into container
runners; the protocol remains compatible with the original exporter.

`generate records` preserves schema fields/nullability/type metadata in Elixir
structs. `generate routes` preserves the ordered contracts, including opaque
constraints; it does not invent recognition behavior. `generate contract-test KIND
--from PATH --output PATH` emits an explicitly failing ExUnit adapter.

`parity` compares explicit expected statuses, selected headers, and full bodies;
JSON comparison ignores only object-key order. Mutating requests require independent
fixture resets. `mutation-diff` checks equal baselines and post-mutation snapshots,
which must include captured effects. Masks require documented reasons.

`doctor` checks reference integrity, runner/inventory configuration, evidence ledger,
and rollback configuration. `verify` executes format/lint/test/rollback and HTTP
gates only after doctor passes. Browser, realtime, job-delivery and operational
contracts need their own evidence; green component tests do not establish parity.

`benchmark --before '["command", "arg"]' --after '["command", "arg"]'` alternates
whole-process runs and saves raw timings. Use --compare-output where appropriate.
App capacity benchmarks require equivalent complete responses, identical fixtures,
CPU affinity, encoding, warmup and balanced sequential repetitions.
