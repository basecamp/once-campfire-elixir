Requests per second: medians of 3 alternating rounds at 16 concurrent connections.

### Elixir, Go and Rust 3fe9f61

| Route | Elixir | Go | Rust 3fe9f61 |
|---|---:|---:|---:|
| Room page | 17,237 | 4,010 | 1,566 |
| Messages page | 25,238 | 4,883 | 3,294 |
| Sidebar | 32,121 | 13,940 | 8,385 |
| Search | 26,790 | 7,284 | 3,669 |
| Post a message | 1,995 | 3,234 | 4,948 |

### Elixir, Go, Rust 3fe9f61 and Rust ccece30

| Route | Elixir | Go | Rust 3fe9f61 | Rust ccece30 |
|---|---:|---:|---:|---:|
| Room page | 17,237 | 4,010 | 1,566 | 26,796 |
| Messages page | 25,238 | 4,883 | 3,294 | 28,335 |
| Sidebar | 32,121 | 13,940 | 8,385 | 27,538 |
| Search | 26,790 | 7,284 | 3,669 | 25,488 |
| Post a message | 1,995 | 3,234 | 4,948 | 6,101 |

### Elixir and Rust 3fe9f61

| Route | Elixir | Rust 3fe9f61 | Elixir ÷ Rust 3fe9f61 |
|---|---:|---:|---:|
| Room page | 17,237 | 1,566 | 11.01 |
| Messages page | 25,238 | 3,294 | 7.66 |
| Sidebar | 32,121 | 8,385 | 3.83 |
| Search | 26,790 | 3,669 | 7.30 |
| Post a message | 1,995 | 4,948 | 0.40 |

### Elixir and Rust ccece30

| Route | Elixir | Rust ccece30 | Elixir ÷ Rust ccece30 |
|---|---:|---:|---:|
| Room page | 17,237 | 26,796 | 0.64 |
| Messages page | 25,238 | 28,335 | 0.89 |
| Sidebar | 32,121 | 27,538 | 1.17 |
| Search | 26,790 | 25,488 | 1.05 |
| Post a message | 1,995 | 6,101 | 0.33 |

