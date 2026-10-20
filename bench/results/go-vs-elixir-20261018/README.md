# Go against Elixir on room_show, native, this Mac

Both native processes on the same host, same seed fixture, fresh database and storage copy per
app, gzip, responses validated by the shared load generator (`route-contract-v1`), two rounds of
6 s per cell, medians. Neither app ran in a container.

## Same session, same conditions

Both runs happened back to back while the machine was loaded (load average 7.5 rising to 9.7:
two leftover fixture containers plus unidentified Erlang VMs). Elixir's samples diverged
noticeably under that load, so read these as a lower bound for the Elixir side.

| Workload | Go | Elixir | Go/Elixir |
|---|---:|---:|---:|
| room_show @1 | 7,106 | 2,140 | 3.3x |
| room_show @16 | 27,947 | 6,967 | 4.0x |
| room_show @64 | 32,913 | 10,530 | 3.1x |

## Both apps measured on a quiet machine, separate sessions

Go from `bench/results/torque-20261018/summary-go.json`; Elixir from the run recorded in
`702803b` (room_show @16 13,435, @64 13,709), same configuration.

| Workload | Go | Elixir | Go/Elixir |
|---|---:|---:|---:|
| room_show @16 | 27,865 | 13,435 | 2.1x |
| room_show @64 | 33,064 | 13,709 | 2.4x |

## What the gap is not

The Elixir side has been profiled and counted piece by piece: database reads are 0.003 per
request after the version-keyed memo, route recognition is 0.6 µs, the router clause scan hits the
hot route at clause 11, `PRAGMA data_version` is 3.6 µs under load, asset reads and the PWA
manifest are memoised, and cookie percent encoding went from 86 to 34 µs per request with a
table-driven codec. A cached room page now costs roughly 130 µs of application work against Go's
whole render; the remaining difference in throughput tracks how many cores each process actually
gets, which is where the next measurement should go.
