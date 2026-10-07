| metric | round 2 (c81bd37) | round 3 (a34e991) | change |
|---|---:|---:|---:|
| room_show c=16 req/s | 5,111.8 | 7,188.3 | 1.41x |
| room_show c=64 p99 ms | 34.0 | 14.8 | 0.43x |
| room_show c=16 CPU µs/request | 706.6 | 528.8 | 0.75x |
| messages_page c=16 req/s | 6,756.8 | 7,585.0 | 1.12x |
| messages_page c=64 p99 ms | 18.2 | 12.9 | 0.71x |
| messages_page c=16 CPU µs/request | 551.0 | 455.3 | 0.83x |
| sidebar c=16 req/s | 4,867.5 | 5,398.2 | 1.11x |
| sidebar c=64 p99 ms | 23.4 | 19.9 | 0.85x |
| sidebar c=16 CPU µs/request | 757.2 | 689.6 | 0.91x |
| search c=16 req/s | 5,136.4 | 5,986.1 | 1.17x |
| search c=64 p99 ms | 20.4 | 17.1 | 0.84x |
| search c=16 CPU µs/request | 712.9 | 630.3 | 0.88x |
| post_message c=16 req/s | 1,993.1 | 1,963.5 | 0.99x |
| post_message c=64 p99 ms | 48.7 | 48.5 | 1.00x |
| post_message c=16 CPU µs/request | 1,840.5 | 1,828.7 | 0.99x |
| avatar c=16 req/s | 113,044.1 | 133,992.5 | 1.19x |
| avatar c=64 p99 ms | 1.4 | 1.1 | 0.79x |
| avatar c=16 CPU µs/request | 28.5 | 26.5 | 0.93x |
| static_css c=16 req/s | 130,820.9 | 138,634.5 | 1.06x |
| static_css c=64 p99 ms | 1.0 | 1.2 | 1.11x |
| static_css c=16 CPU µs/request | 24.9 | 24.7 | 0.99x |
| up c=16 req/s | 54,159.1 | 53,935.1 | 1.00x |
| up c=64 p99 ms | 2.8 | 2.5 | 0.87x |
| up c=16 CPU µs/request | 71.3 | 72.9 | 1.02x |
| cable 1000 complete broadcasts/s | None | None |  |
| cable 1000 paced p50 ms | None | None |  |
| cable 1000 paced p99 ms | None | None |  |
| upload median ms | None | None |  |
| cold start ms | 1199 | 1133 | 0.94x |
| peak anon MiB | 244 | 249 | 1.02x |
