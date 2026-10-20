# Matrix after the cache-correctness fixes

The branch's cache work was brought back in line with what the review asked for (atomic admission,
admission-time epoch check, per-request version read, restored access check and per-response cookie
reissue). This is the same three-way comparison as before, run afterwards, in one session, back to
back.

| route | @ | Elixir | Express | Go | Elixir/Express | Elixir/Go |
|---|---:|---:|---:|---:|---:|---:|
| room_show | 16 | 39,436 | 29,905 | 26,004 | 1.32× | 1.52× |
| room_show | 64 | 33,703 | 39,204 | 31,028 | 0.86× | 1.09× |
| messages_page | 16 | 39,383 | 33,680 | 25,048 | 1.17× | 1.57× |
| messages_page | 64 | 38,841 | 47,206 | 26,811 | 0.82× | 1.45× |
| sidebar | 16 | 40,352 | 43,559 | 29,430 | 0.93× | 1.37× |
| sidebar | 64 | 36,673 | 56,375 | 34,629 | 0.65× | 1.06× |
| search | 16 | 39,232 | 40,094 | 27,480 | 0.98× | 1.43× |
| search | 64 | 37,396 | 53,464 | 30,080 | 0.70× | 1.24× |
| post_message | 16 | 2,110 | 812 | 3,662 | 2.60× | 0.58× |
| post_message | 64 | 2,050 | 833 | 3,858 | 2.46× | 0.53× |

Geometric mean of the four read routes:

    @16  Elixir 39,598   Express 36,418   Go 26,940
    @64  Elixir 36,605   Express 48,598   Go 30,510

## What the fixes cost

Nothing measurable at these concurrencies. Read routes measured 33,927 @64 before the fixes and
36,605 after (inside this machine's noise); `post_message` measured 2,069 and 2,050. The earlier
single-run reading of -26% on room_show @64 was noise, not the price of correctness.

## Caveat

One session, one machine, two rounds per point, no core pinning. The same code has measured between
15k and 40k on room_show @64 across sessions, so only the ratios within this run are comparable.
