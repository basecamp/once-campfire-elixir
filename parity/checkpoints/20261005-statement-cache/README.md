# Statement-cache verification checkpoint

These are unchanged receipts from the October 5, 2026 verification of the
statement-cache integration. They do not replace historical records under
`parity/results/`, and correctness results do not establish a performance win.

| Check | Native amd64 Linux | Native ARM64 Linux under OrbStack |
|---|---:|---:|
| Complete Rails comparison gates | 65/65 | 65/65 |
| Unit tests | 1,941 passed | 1,941 passed |
| Toolkit tests at this checkpoint | 36 passed | 36 passed |
| Format and strict compile | Passed | Passed |
| Strict Credo / Dialyzer | Passed / zero errors | Passed / zero errors |
| Production mixed-write visibility / reader recovery | Passed | Passed |

The gate commands, durations and source identities are in the
[amd64 ledger](amd64/parity/results/verification.json) and
[ARM64 ledger](arm64/parity/results/verification.json). Each architecture directory
preserves the original archive paths. The compact subset includes unit/toolkit
logs, strict checks, production probes and source hashes; paths to other gate logs
inside the ledgers refer to the full archives, not this compact subset.

## Exact source and images

Both runs used base revision `6f06e50f2ec5dae69331c2c5dd033b4ac8849580` plus three
overlay files: `lib/campfire/db.ex`, `test/db_statement_cache_test.exs`, and
`test/messages_view_test.exs`. Their hashes are recorded in each architecture's
`var/` directory and match the subsequently committed integration. The base Git
revision alone does **not** identify the verified source.

- amd64 source digest: `d95a406a33915790b632420d97840c96d76e4bd8a5e7595c58bdf2d84bf58efe`.
- ARM64 source digest: `37c3f77421c678d63ec12ce5171eba5371583da2440e343a37ca63ab674d2924`.
  Generated architecture-specific artifacts make the complete digests differ.
- amd64 production image: `sha256:57ec8cf3ec3539e3a5b6e5b41ef1010862eebff5f36942182b52bfab556ac6f5`.
- ARM64 production image: `sha256:98073580d65b01180becb79c46a4c3480a4c093547bdc90229efd89d4077e626`.

Production probes used Elixir 1.20.4 / OTP 29.1.1 JIT, four online normal schedulers,
four readonly readers, default dirty-IO scheduling and a 65,536 descriptor limit.
Mixed writes proved progress during an open writer transaction and visibility after
commit. Forced-reader death proved automatic replacement and subsequent routed
reads, **not** continuity of a query interrupted by that death. Observed recovery
times are individual functional probes, not latency benchmarks.

The later benchmark-only wire-accounting fix adds a 37th toolkit test and represents
unmeasured Cable wire throughput as null. These earlier 36-test receipts remain
unchanged; they are not relabeled as tests of that later harness revision.

## Full capture archives retained separately

The compact records here were copied byte-for-byte from these archives. Full raw
HTTP/media/browser captures, detailed gate logs and executable probe scripts remain
in the archives; they are not all duplicated in Git.

| Archive | SHA-256 |
|---|---|
| `linux-statement-cache-integration-correctness.tar.gz` | `33b26c518026ea8a1039c110ad8ec420a38aeae92e6ba9b600469849a76e43d7` |
| `m4-verify-statement-cache-evidence.tar.gz` | `f37070b799a71f8aa35c6b0ead718191c907165d5b0d6f562473657eca9f5fea` |

The ARM64 archive also retains an initial format-gate failure caused by accidentally
extracted AppleDouble metadata and a scratch probe's missing-seed setup failure.
The corrected complete run is the one reported above. On amd64, extraction named
only the three intended source files, so AppleDouble metadata never entered the
checkout and caused no failed gate. These setup failures were not application
failures, and their original evidence was not discarded.
