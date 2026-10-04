# Tuning comparison

Two alternating rounds per app per build, same seed, four server CPU cores, gzip, validated responses. HTTP uses 64 concurrent connections. Cable counts messages delivered to every subscribed client. These short runs describe this workload; they are not long-duration production capacity estimates.

| Throughput | Elixir baseline | Elixir tuned | Improvement | Rust final | Remaining Rust advantage |
|---|---:|---:|---:|---:|---:|
| room_show | 592.9 | 751.1 | 1.27× | 19,560.3 | 26.04× |
| messages_page | 805.8 | 1,031.5 | 1.28× | 22,997.8 | 22.30× |
| sidebar | 1,348.8 | 1,328.8 | 0.99× | 12,339.0 | 9.29× |
| search | 1,010.4 | 1,161.7 | 1.15× | 23,662.5 | 20.37× |
| post_message | 521.8 | 860.7 | 1.65× | 5,405.0 | 6.28× |
| static_css | 13,062.0 | 105,374.2 | 8.07× | 417,021.8 | 3.96× |
| up | 7,550.1 | 8,931.2 | 1.18× | 131,816.9 | 14.76× |
| avatar | 78,963.8 | 78,929.4 | 1.00× | 385,201.0 | 4.88× |
| Cable 100 clients | 141.6 | 412.8 | 2.92× | 2,913.6 | 7.06× |
| Cable 500 clients | 35.0 | 121.2 | 3.47× | 979.5 | 8.08× |
| Cable 1000 clients | 17.6 | 60.2 | 3.42× | 494.9 | 8.21× |

| Cost | Elixir baseline | Elixir tuned | Rust final |
|---|---:|---:|---:|
| Cold start (ms) | 535.0 | 529.5 | 150.0 |
| Idle anonymous memory (MB) | 120.5 | 116.5 | 14.5 |
| Peak anonymous memory (MB) | 983.5 | 564.0 | 307.0 |
| Upload → thumbnail (ms) | 95.1 | 92.6 | 31.1 |

End-of-run native background queue counts (accepted HTTP writes can precede job completion):

| Build / round | Queued | Processed | Failed |
|---|---:|---:|---:|
| baseline-20261004 / elixir-1-jobs | 8,412 | 1,206 | 0 |
| baseline-20261004 / elixir-2-jobs | 8,544 | 1,203 | 0 |
| tuned-fifo-20261004 / elixir-1-jobs | 0 | 18,866 | 0 |
| tuned-fifo-20261004 / elixir-2-jobs | 0 | 18,850 | 0 |
