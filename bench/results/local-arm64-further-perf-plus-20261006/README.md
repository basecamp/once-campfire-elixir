# further-perf plus cached regexes, native reads and a cheaper WAL check (local, arm64)

Apple M4 Max, Docker Desktop, `--cpus 4` per app container, the repository's test fixture plus
2,000 generated messages in one room on a VM-local volume, `LOG_REQUESTS=false`, 6-second runs
at 1 and 16 connections, three rounds in alternating order. The load generator
(`bench/loadgen`) runs natively on macOS through Docker's port forwarding, which caps `/up`
near 43,000 req/s here. Every response was validated (status 200, no errors) and decoded
bodies are byte-identical between `pr5` and `plus`. No parity gates were run; the pending
contracts are unchanged. Not comparable with the README table or with the Docker Desktop
runner's results in the sibling directories.

- `ours`: an unpublished experiment on `main`'s architecture (fragment caches, native reads,
  libdeflate at level 1), served by Bandit without Thruster (`raw-baseline.jsonl`).
- `pr5`: `further-perf` at `cf65478`.
- `plus`: this branch. `plus-off` is the same image with `CAMPFIRE_DB_NATIVE_READS=0`.

`REPO=<checkout> run.sh OUTDIR "labels" ROUNDS` produced the raw files; `python3 summary.py <raw> <labels>`
prints the medians.

Requests/second at 16 connections, median (range), from `raw-plus.jsonl`:

| workload | pr5 | plus | plus-off |
|---|---:|---:|---:|
| room page | 11,434 (11,200–11,581) | 22,224 (19,549–22,968) | 22,828 (22,220–22,845) |
| messages page | 13,493 (13,210–13,651) | 28,479 (26,232–29,683) | 29,271 (28,457–29,380) |
| sidebar | 14,827 (14,825–15,202) | 34,665 (33,741–35,565) | 35,031 (34,392–36,450) |
| search | 15,302 (15,242–15,454) | 35,706 (35,175–38,302) | 37,062 (33,909–37,248) |
| /up | 42,855 | 42,894 | 42,705 |
| post a message | 1,507 (1,439–1,540) | 1,690 (1,657–1,795) | 1,656 (1,624–1,706) |

BEAM CPU per request (µs): room 349 / 178 / 174, messages 296 / 140 / 136, sidebar 270 / 112 /
109, search 261 / 110 / 104, post 2,574 / 1,585 / 2,230. With one connection the read pages
gain 1.18–1.34× and posting 1.39×.

The read-page gain comes from the regex cache and the WAL check, not from native reads (those
pages are served from the read cache). In the container an inline `~r` cost about 17 µs per
evaluation against 0.9 µs precompiled, and the WAL index check 16.8 µs per request against
0.7 µs. Native reads account for the posting CPU difference between `plus` and `plus-off`.

Baseline (`raw-baseline.jsonl`), 16 connections: `ours` 3,654 / 3,406 / 7,925 / 13,744 / 1,472
and `pr5` 11,268 / 13,246 / 14,682 / 15,135 / 1,371 req/s for room, messages, sidebar, search
and post.
