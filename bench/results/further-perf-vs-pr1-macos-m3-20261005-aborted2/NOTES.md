# Aborted A/B, second attempt (Docker Desktop, Apple M3, October 5, 2026)

Same command and images as the completed `further-perf-vs-pr1-macos-m3-20261005`. Elixir rep 1
completed with every response valid. The harness then failed reading its own memory sample
(`cat .elixir-1.mem: No such file or directory`), even though the file exists. The sampler
replaces that file by rename every 0.2 s, and on Docker Desktop's macOS file sharing a reader
can briefly miss it. `bench/run` now retries that read. Kept as raw evidence, not as a result.
