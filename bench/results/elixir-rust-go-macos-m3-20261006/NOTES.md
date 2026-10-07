# Elixir vs Go vs Rust (Docker Desktop, Apple M3, October 5, 2026)

Four production images, alternating through the same harness in one session, on the same seed
and CPU split (4 app vCPUs, 4 load-generator vCPUs), with request logging off:

| Slot | Image | Source |
|---|---|---|
| `elixir` | `campfire-elixir:further-perf-r4` | once-campfire-elixir `further-perf` at `cc47003` (round 4) |
| `go` | `once-campfire-go:8d2f7f2` | basecamp/once-campfire-go `main` at `8d2f7f2` |
| `rust` | `campfire-rust:3fe9f61` | basecamp/once-campfire-rust `3fe9f61` (September 27) |
| `reference` | `campfire-rust:ccece30` | basecamp/once-campfire-rust `main` at `ccece30` (October 5) |

`reference` is only a slot name here: it holds the second Rust image, not Rails. Each image was
built natively for arm64 from a clean checkout with its submodules. All four pin the Rails
reference at `90b3300`. `ccece30` has the same build inputs as `1ea6d6f`, which the earlier
Rust comparisons measured. Its newer commits change only READMEs.

```sh
SKIP_LEDGER=1 HTTP_SECS=4 LOAD_WAIT_SECS=120 ELIXIR_IMAGE=campfire-elixir:further-perf-r4 \
  RUST_IMAGE=campfire-rust:3fe9f61 REFERENCE_IMAGE=campfire-rust:ccece30 GO_IMAGE=once-campfire-go:8d2f7f2 \
  SUITES="http" bench/docker-desktop/run --apps elixir,rust,go,reference --reps 3 \
  --out bench/results/elixir-rust-go-macos-m3-20261006
```

Every HTTP validation passed with zero errors in all twelve reps. The tables are in
[tables.md](tables.md): medians of 3 rounds at c=16, as throughput with CPU per successful
request.

Caveats:

- **Response sizes differ** by implementation (decoded / gzip bytes, rep 1):

  | Route | Elixir | Go | Rust 3fe9f61 | Rust ccece30 |
  |---|---|---|---|---|
  | Room page | 417,155 / 33,082 | 374,024 / 21,282 | 463,863 / 45,549 | 416,127 / 24,233 |
  | Messages page | 384,885 / 23,167 | 342,444 / 12,817 | 430,964 / 36,044 | 383,844 / 16,158 |
  | Sidebar | 30,909 / 6,720 | 9,462 / 2,249 | 31,379 / 6,293 | 30,763 / 5,910 |
  | Search | 150,040 / 12,750 | 135,497 / 9,462 | 165,555 / 17,898 | 149,625 / 9,767 |

  Go's sidebar response is a third the size of the others. Rust `3fe9f61` still carries
  per-request CSRF tokens (like the original Rails pages); the other three do not.
- **Host noise:** Go's post-message rep 2 was disturbed (1,054 req/s against 3,234–3,922 in the
  others). The median absorbs it.
- **Elixir's read cache:** Elixir keeps reads and rendered page parts until the tables they read
  change (see the round-4 notes). This benchmark's page routes are read-only, so it serves them
  from those caches. Posting a message invalidates them as it would in real use.
- **Parity:** the parity ledger gate was skipped. The pending Elixir contracts are unchanged.
  This is a benchmark comparison, not a claim that every implementation passes the Elixir
  parity ledger.
- **Seed and load generator:** both come from the `once-campfire-rust` checkout at `64f8635`, as
  in every earlier Docker Desktop run. `rust HEAD` in env.txt names that checkout, not an
  image.
