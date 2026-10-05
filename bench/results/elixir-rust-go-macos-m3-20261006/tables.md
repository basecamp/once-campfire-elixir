Medians of 3 alternating rounds at 16 concurrent connections. Each cell is throughput, with CPU time per successful request in parentheses.

### Elixir, Go and Rust 3fe9f61

| Route | Elixir | Go | Rust 3fe9f61 |
|---|---:|---:|---:|
| Room page | 17,237 req/s (228 µs) | 4,010 req/s (986 µs) | 1,566 req/s (2,471 µs) |
| Messages page | 25,238 req/s (157 µs) | 4,883 req/s (812 µs) | 3,294 req/s (1,096 µs) |
| Sidebar | 32,121 req/s (122 µs) | 13,940 req/s (244 µs) | 8,385 req/s (423 µs) |
| Search | 26,790 req/s (146 µs) | 7,284 req/s (533 µs) | 3,669 req/s (991 µs) |
| Post a message | 1,995 req/s (1,461 µs) | 3,234 req/s (541 µs) | 4,948 req/s (590 µs) |

### Elixir, Go, Rust 3fe9f61 and Rust ccece30

| Route | Elixir | Go | Rust 3fe9f61 | Rust ccece30 |
|---|---:|---:|---:|---:|
| Room page | 17,237 req/s (228 µs) | 4,010 req/s (986 µs) | 1,566 req/s (2,471 µs) | 26,796 req/s (130 µs) |
| Messages page | 25,238 req/s (157 µs) | 4,883 req/s (812 µs) | 3,294 req/s (1,096 µs) | 28,335 req/s (121 µs) |
| Sidebar | 32,121 req/s (122 µs) | 13,940 req/s (244 µs) | 8,385 req/s (423 µs) | 27,538 req/s (126 µs) |
| Search | 26,790 req/s (146 µs) | 7,284 req/s (533 µs) | 3,669 req/s (991 µs) | 25,488 req/s (125 µs) |
| Post a message | 1,995 req/s (1,461 µs) | 3,234 req/s (541 µs) | 4,948 req/s (590 µs) | 6,101 req/s (431 µs) |

### Elixir and Rust 3fe9f61

| Route | Elixir | Rust 3fe9f61 | Elixir ÷ Rust (req/s) |
|---|---:|---:|---:|
| Room page | 17,237 req/s (228 µs) | 1,566 req/s (2,471 µs) | 11.01× |
| Messages page | 25,238 req/s (157 µs) | 3,294 req/s (1,096 µs) | 7.66× |
| Sidebar | 32,121 req/s (122 µs) | 8,385 req/s (423 µs) | 3.83× |
| Search | 26,790 req/s (146 µs) | 3,669 req/s (991 µs) | 7.30× |
| Post a message | 1,995 req/s (1,461 µs) | 4,948 req/s (590 µs) | 0.40× |

