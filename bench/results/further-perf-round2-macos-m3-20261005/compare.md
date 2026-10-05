| metric | round 1 (9ab39f9) | round 2 (03874d7) | change |
|---|---:|---:|---:|
| room_show c=16 req/s | 4,650.1 | 6,781.1 | 1.46x |
| room_show c=64 p99 ms | 20.5 | 14.9 | 0.73x |
| room_show c=16 CPU µs/request | 810.5 | 563.6 | 0.70x |
| messages_page c=16 req/s | 3,423.4 | 8,158.0 | 2.38x |
| messages_page c=64 p99 ms | 26.0 | 12.2 | 0.47x |
| messages_page c=16 CPU µs/request | 1,063.3 | 464.8 | 0.44x |
| sidebar c=16 req/s | 4,006.5 | 5,905.6 | 1.47x |
| sidebar c=64 p99 ms | 21.3 | 16.9 | 0.79x |
| sidebar c=16 CPU µs/request | 946.0 | 636.4 | 0.67x |
| search c=16 req/s | 4,345.1 | 6,493.7 | 1.49x |
| search c=64 p99 ms | 21.0 | 14.7 | 0.70x |
| search c=16 CPU µs/request | 852.2 | 583.6 | 0.68x |
| post_message c=16 req/s | 2,167.3 | 2,161.8 | 1.00x |
| post_message c=64 p99 ms | 38.8 | 43.6 | 1.12x |
| post_message c=16 CPU µs/request | 1,669.0 | 1,680.2 | 1.01x |
| avatar c=16 req/s | 142,580.3 | 146,228.0 | 1.03x |
| avatar c=64 p99 ms | 0.9 | 0.9 | 1.01x |
| avatar c=16 CPU µs/request | 24.8 | 24.3 | 0.98x |
| static_css c=16 req/s | 152,119.8 | 156,221.0 | 1.03x |
| static_css c=64 p99 ms | 0.9 | 0.9 | 1.00x |
| static_css c=16 CPU µs/request | 23.6 | 23.2 | 0.98x |
| up c=16 req/s | 60,258.3 | 60,845.5 | 1.01x |
| up c=64 p99 ms | 1.8 | 1.8 | 0.98x |
| up c=16 CPU µs/request | 65.8 | 65.3 | 0.99x |
| cable 1000 complete broadcasts/s | 214.5 | 218.4 | 1.02x |
| cable 1000 paced p50 ms | 20.9 | 20.6 | 0.99x |
| cable 1000 paced p99 ms | 25.8 | 27.0 | 1.05x |
| upload median ms | None | None |  |
| cold start ms | 853 | 847 | 0.99x |
| peak anon MiB | 336 | 329 | 0.98x |
