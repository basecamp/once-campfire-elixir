| metric | round 2 (c81bd37) | round 3 (a34e991) | change |
|---|---:|---:|---:|
| room_show c=16 req/s | 6,453.3 | 7,463.6 | 1.16x |
| room_show c=64 p99 ms | 16.3 | 14.6 | 0.90x |
| room_show c=16 CPU µs/request | 590.1 | 510.0 | 0.86x |
| messages_page c=16 req/s | 7,752.4 | 6,255.8 | 0.81x |
| messages_page c=64 p99 ms | 15.8 | 25.6 | 1.63x |
| messages_page c=16 CPU µs/request | 489.2 | 527.6 | 1.08x |
| sidebar c=16 req/s | 5,271.7 | 4,480.9 | 0.85x |
| sidebar c=64 p99 ms | 17.7 | 25.2 | 1.43x |
| sidebar c=16 CPU µs/request | 712.0 | 811.3 | 1.14x |
| search c=16 req/s | 6,374.4 | 6,154.9 | 0.97x |
| search c=64 p99 ms | 18.3 | 22.9 | 1.25x |
| search c=16 CPU µs/request | 595.7 | 615.8 | 1.03x |
| post_message c=16 req/s | 2,022.9 | 2,033.0 | 1.00x |
| post_message c=64 p99 ms | 41.5 | 49.2 | 1.19x |
| post_message c=16 CPU µs/request | 1,765.9 | 1,745.6 | 0.99x |
| avatar c=16 req/s | 131,406.8 | 121,905.3 | 0.93x |
| avatar c=64 p99 ms | 1.1 | 1.1 | 0.93x |
| avatar c=16 CPU µs/request | 26.3 | 26.7 | 1.01x |
| static_css c=16 req/s | 140,494.2 | 144,449.2 | 1.03x |
| static_css c=64 p99 ms | 1.0 | 1.3 | 1.30x |
| static_css c=16 CPU µs/request | 24.2 | 23.5 | 0.97x |
| up c=16 req/s | 58,153.3 | 56,441.0 | 0.97x |
| up c=64 p99 ms | 2.6 | 3.2 | 1.23x |
| up c=16 CPU µs/request | 67.6 | 69.5 | 1.03x |
| cable 1000 complete broadcasts/s | 168.2 | 193.6 | 1.15x |
| cable 1000 paced p50 ms | 21.1 | 21.4 | 1.02x |
| cable 1000 paced p99 ms | 27.8 | 26.2 | 0.94x |
| upload median ms | None | None |  |
| cold start ms | 857 | 1036 | 1.21x |
| peak anon MiB | 301 | 330 | 1.10x |
