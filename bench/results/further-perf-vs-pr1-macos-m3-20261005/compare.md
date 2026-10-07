| metric | pr1-fix (48609bd + e14c105) | further-perf (e14c105) | change |
|---|---:|---:|---:|
| room_show c=16 req/s | 2,057.2 | 4,765.4 | 2.32x |
| room_show c=64 p99 ms | 41.4 | 19.3 | 0.47x |
| room_show c=16 CPU µs/request | 1,777.4 | 804.9 | 0.45x |
| messages_page c=16 req/s | 1,398.0 | 3,286.5 | 2.35x |
| messages_page c=64 p99 ms | 55.9 | 26.5 | 0.47x |
| messages_page c=16 CPU µs/request | 2,602.9 | 1,086.7 | 0.42x |
| sidebar c=16 req/s | 2,462.9 | 4,303.0 | 1.75x |
| sidebar c=64 p99 ms | 40.2 | 19.4 | 0.48x |
| sidebar c=16 CPU µs/request | 1,527.0 | 901.6 | 0.59x |
| search c=16 req/s | 1,766.9 | 4,473.7 | 2.53x |
| search c=64 p99 ms | 49.9 | 19.5 | 0.39x |
| search c=16 CPU µs/request | 2,074.7 | 837.6 | 0.40x |
| post_message c=16 req/s | 1,595.6 | 2,227.2 | 1.40x |
| post_message c=64 p99 ms | 54.9 | 38.2 | 0.70x |
| post_message c=16 CPU µs/request | 2,354.1 | 1,657.7 | 0.70x |
| avatar c=16 req/s | 70,210.2 | 148,660.5 | 2.12x |
| avatar c=64 p99 ms | 6.1 | 0.9 | 0.15x |
| avatar c=16 CPU µs/request | 38.5 | 24.3 | 0.63x |
| static_css c=16 req/s | 94,625.8 | 151,239.7 | 1.60x |
| static_css c=64 p99 ms | 4.4 | 1.0 | 0.22x |
| static_css c=16 CPU µs/request | 30.6 | 23.6 | 0.77x |
| up c=16 req/s | 12,154.1 | 59,838.6 | 4.92x |
| up c=64 p99 ms | 17.6 | 1.9 | 0.11x |
| up c=16 CPU µs/request | 275.3 | 66.1 | 0.24x |
| cable 1000 complete broadcasts/s | 127.8 | 206.1 | 1.61x |
| cable 1000 paced p50 ms | 26.5 | 21.4 | 0.81x |
| cable 1000 paced p99 ms | 35.3 | 27.3 | 0.77x |
| upload median ms | None | None |  |
| cold start ms | 1076 | 1188 | 1.10x |
| peak anon MiB | 497 | 339 | 0.68x |
