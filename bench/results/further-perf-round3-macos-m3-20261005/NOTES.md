# further-perf round 3 vs round 2, first run (Docker Desktop, Apple M3, October 5, 2026)

The same images and command as `../further-perf-round3-http-macos-m3-20261005`, with
`SUITES="http cable"`. Every validation passed with zero errors, and decoded bodies are
byte-identical. Round 3's rep 1 was disturbed: 30–40% slower on nearly every route, including
ones the changes don't touch. So the medians in [compare.md](compare.md) understate round 3
and show false regressions for the messages page and sidebar. The interpretation, the
HTTP-only confirmation run and the next work are in that directory's NOTES.md. Cable fan-out at
1,000 clients was 168 vs 194 broadcasts/s, within this host's noise.
