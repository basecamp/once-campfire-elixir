
### HTTP throughput, req/s, 1 concurrent

| Metric | baseline | baseline-rerun | step1-gzip | step2-cache | step3-noredis | step4-spinpool | step4-dbpool | step5-pipeline | step5-level6 | vs baseline |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| room_show | 399 | 368 | 581 | 2,872 | 2,792 | 3,123 | 2,285 | 2,750 | 2,865 | 7.19× |
| messages_page | 531 | 480 | 757 | 1,830 | 1,731 | 1,844 | 1,710 | 1,843 | 1,852 | 3.49× |
| sidebar | 1,066 | 984 | 1,265 | 3,377 | 3,416 | 3,261 | 3,054 | 3,314 | 3,387 | 3.18× |
| search | 822 | 774 | 1,108 | 3,419 | 3,482 | 3,325 | 3,356 | 3,384 | 3,470 | 4.22× |
| post_message | 371 | 370 | 378 | 366 | 524 | 565 | 373 | 515 | 525 | 1.41× |
| avatar | 1,965 | 2,010 | 2,010 | 2,044 | 1,923 | 1,843 | 1,817 | 2,104 | 1,990 | 1.01× |
| static_css | 7,365 | 7,418 | 7,734 | 11,643 | 11,167 | 11,808 | 8,339 | 12,133 | 12,078 | 1.64× |
| up | 7,069 | 7,584 | 7,276 | 7,209 | 7,222 | 7,121 | 4,986 | 7,413 | 7,400 | 1.05× |

### HTTP throughput, req/s, 16 concurrent

| Metric | baseline | baseline-rerun | step1-gzip | step2-cache | step3-noredis | step4-spinpool | step4-dbpool | step5-pipeline | step5-level6 | vs baseline |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| room_show | 1,226 | 1,082 | 1,400 | 4,366 | 3,984 | 10,672 | 9,706 | 11,265 | 12,130 | 9.89× |
| messages_page | 1,619 | 1,488 | 1,967 | 2,903 | 2,830 | 4,099 | 3,876 | 3,866 | 3,901 | 2.41× |
| sidebar | 1,600 | 1,535 | 1,681 | 4,972 | 4,390 | 12,731 | 11,601 | 13,095 | 13,352 | 8.35× |
| search | 1,673 | 1,606 | 1,965 | 5,210 | 5,042 | 12,384 | 12,650 | 13,308 | 13,697 | 8.19× |
| post_message | 888 | 843 | 910 | 847 | 973 | 1,703 | 1,130 | 1,206 | 1,269 | 1.43× |
| avatar | 2,438 | 2,426 | 2,638 | 2,555 | 2,301 | 5,973 | 5,926 | 6,647 | 6,630 | 2.72× |
| static_css | 10,252 | 10,642 | 10,709 | 25,504 | 25,062 | 25,887 | 24,145 | 26,437 | 27,226 | 2.66× |
| up | 33,858 | 32,940 | 34,209 | 32,655 | 32,551 | 32,232 | 25,218 | 33,460 | 34,676 | 1.02× |

### HTTP throughput, req/s, 64 concurrent

| Metric | baseline | baseline-rerun | step1-gzip | step2-cache | step3-noredis | step4-spinpool | step4-dbpool | step5-pipeline | step5-level6 | vs baseline |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| room_show | 1,232 | 1,134 | 1,436 | 4,294 | 3,913 | 6,683 | 11,554 | 12,097 | 13,339 | 10.82× |
| messages_page | 1,659 | 1,625 | 1,943 | 2,881 | 2,817 | 3,587 | 3,851 | 3,854 | 3,845 | 2.32× |
| sidebar | 1,716 | 1,659 | 1,822 | 5,039 | 4,677 | 7,571 | 12,845 | 13,885 | 14,211 | 8.28× |
| search | 1,681 | 1,644 | 1,972 | 5,103 | 4,798 | 7,378 | 12,658 | 14,373 | 14,535 | 8.65× |
| post_message | 962 | 943 | 971 | 920 | 1,141 | 1,692 | 1,076 | 1,173 | 1,242 | 1.29× |
| avatar | 2,707 | 2,547 | 2,837 | 2,661 | 2,559 | 3,331 | 6,225 | 6,644 | 6,694 | 2.47× |
| static_css | 10,478 | 10,583 | 11,100 | 24,797 | 24,788 | 25,107 | 23,244 | 25,699 | 26,106 | 2.49× |
| up | 33,844 | 33,259 | 34,423 | 32,735 | 30,716 | 32,722 | 25,803 | 34,193 | 35,318 | 1.04× |

### HTTP p99 latency, ms, 16 concurrent

| Metric | baseline | baseline-rerun | step1-gzip | step2-cache | step3-noredis | step4-spinpool | step4-dbpool | step5-pipeline | step5-level6 | vs baseline |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| room_show | 16.4 | 28.3 | 15.1 | 5.86 | 6.92 | 3.56 | 4.10 | 2.47 | 2.04 | 8.01× |
| messages_page | 18.3 | 21.0 | 10.9 | 8.17 | 8.60 | 7.72 | 6.85 | 7.20 | 6.51 | 2.81× |
| sidebar | 14.7 | 16.1 | 15.0 | 4.94 | 7.60 | 2.81 | 2.49 | 2.16 | 2.09 | 7.04× |
| search | 12.9 | 14.8 | 11.3 | 4.71 | 4.93 | 2.95 | 2.13 | 1.97 | 1.96 | 6.54× |
| post_message | 25.2 | 27.8 | 24.9 | 27.4 | 29.2 | 11.6 | 29.4 | 19.6 | 14.6 | 1.73× |
| avatar | 10.7 | 11.6 | 9.22 | 9.36 | 11.3 | 3.81 | 4.21 | 3.52 | 3.57 | 3.01× |
| static_css | 2.45 | 2.37 | 2.28 | 0.92 | 0.93 | 0.91 | 0.93 | 0.91 | 0.87 | 2.80× |
| up | 1.00 | 1.20 | 1.01 | 1.15 | 1.12 | 1.25 | 3.10 | 1.08 | 1.01 | 1.00× |

### HTTP p99 latency, ms, 64 concurrent

| Metric | baseline | baseline-rerun | step1-gzip | step2-cache | step3-noredis | step4-spinpool | step4-dbpool | step5-pipeline | step5-level6 | vs baseline |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| room_show | 66.9 | 76.6 | 55.7 | 21.4 | 32.1 | 28.7 | 11.5 | 11.6 | 9.44 | 7.09× |
| messages_page | 55.1 | 54.4 | 42.1 | 30.9 | 32.1 | 51.8 | 33.7 | 34.5 | 34.0 | 1.62× |
| sidebar | 49.7 | 53.7 | 54.5 | 18.3 | 24.7 | 28.5 | 10.6 | 9.99 | 9.45 | 5.26× |
| search | 49.4 | 52.8 | 42.4 | 18.8 | 20.7 | 26.9 | 11.3 | 9.38 | 9.01 | 5.48× |
| post_message | 90.2 | 97.4 | 91.9 | 96.7 | 78.9 | 48.3 | 155 | 81.2 | 56.7 | 1.59× |
| avatar | 32.5 | 36.1 | 31.8 | 36.1 | 35.9 | 51.4 | 14.0 | 15.6 | 14.3 | 2.28× |
| static_css | 8.77 | 9.23 | 8.80 | 3.53 | 3.45 | 3.50 | 3.92 | 3.34 | 3.26 | 2.69× |
| up | 6.22 | 8.21 | 6.72 | 7.83 | 9.70 | 8.38 | 24.5 | 6.84 | 6.13 | 1.01× |

### CPU µs per successful response, 64 concurrent

| Metric | baseline | baseline-rerun | step1-gzip | step2-cache | step3-noredis | step4-spinpool | step4-dbpool | step5-pipeline | step5-level6 | vs baseline |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| room_show | 5,478 | 5,626 | 4,088 | 830 | 885 | 1,260 | 628 | 630 | 618 | 8.86× |
| messages_page | 3,861 | 4,005 | 2,937 | 1,305 | 1,352 | 2,356 | 2,092 | 2,148 | 2,277 | 1.70× |
| sidebar | 2,265 | 2,079 | 1,960 | 694 | 749 | 1,088 | 570 | 549 | 540 | 4.19× |
| search | 3,168 | 3,096 | 2,452 | 701 | 745 | 1,102 | 563 | 539 | 540 | 5.86× |
| post_message | 2,865 | 2,954 | 2,773 | 2,935 | 2,208 | 4,917 | 6,274 | 6,229 | 6,287 | 0.46× |
| avatar | 1,576 | 1,429 | 1,400 | 1,457 | 1,519 | 2,311 | 1,299 | 1,196 | 1,185 | 1.33× |
| static_css | 319 | 281 | 273 | 137 | 145 | 151 | 149 | 142 | 144 | 2.21× |
| up | 225 | 219 | 223 | 223 | 224 | 221 | 231 | 220 | 220 | 1.02× |

### Action Cable fan-out throughput

| Metric | baseline | baseline-rerun | step1-gzip | step2-cache | step3-noredis | step4-spinpool | step4-dbpool | step5-pipeline | step5-level6 | vs baseline |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 100 clients: delivered msgs/s (to all clients) | 471 | 446 | 461 | 448 | 494 | 757 | 629 | 685 | 715 | 1.52× |
| 500 clients: delivered msgs/s (to all clients) | 186 | 189 | 188 | 186 | 218 | 268 | 231 | 257 | 251 | 1.35× |
| 1000 clients: delivered msgs/s (to all clients) | 94.3 | 89.3 | 93.8 | 91.0 | 129 | 138 | 136 | 142 | 140 | 1.48× |

### Action Cable paced post → all clients, ms

| Metric | baseline | baseline-rerun | step1-gzip | step2-cache | step3-noredis | step4-spinpool | step4-dbpool | step5-pipeline | step5-level6 | vs baseline |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 100 clients p50 | 3.26 | 3.25 | 3.24 | 3.35 | 2.48 | 2.58 | 3.49 | 2.79 | 2.71 | 1.20× |
| 500 clients p50 | 6.40 | 6.50 | 6.31 | 6.60 | 4.03 | 4.19 | 5.36 | 5.40 | 4.80 | 1.33× |
| 1000 clients p50 | 11.2 | 11.6 | 11.7 | 11.2 | 8.59 | 7.85 | 8.86 | 8.09 | 8.18 | 1.37× |
| 100 clients p99 | 4.16 | 4.30 | 4.48 | 4.52 | 4.09 | 3.33 | 31.5 | 4.08 | 3.77 | 1.10× |
| 500 clients p99 | 12.0 | 10.8 | 11.7 | 10.8 | 13.8 | 5.62 | 10.4 | 16.1 | 13.3 | 0.90× |
| 1000 clients p99 | 26.7 | 21.6 | 18.7 | 20.1 | 22.8 | 23.9 | 18.7 | 17.9 | 19.2 | 1.39× |
| 100 clients connect+subscribe (s) | 0.06 | 0.06 | 0.06 | 0.06 | 0.06 | 0.06 | 0.14 | 0.06 | 0.06 | 1.00× |
| 500 clients connect+subscribe (s) | 0.21 | 0.23 | 0.17 | 0.20 | 0.21 | 0.15 | 0.16 | 0.18 | 0.15 | 1.35× |
| 1000 clients connect+subscribe (s) | 0.38 | 0.40 | 0.41 | 0.38 | 0.33 | 0.38 | 0.33 | 0.27 | 0.27 | 1.41× |

### Startup and memory

| Metric | baseline | baseline-rerun | step1-gzip | step2-cache | step3-noredis | step4-spinpool | step4-dbpool | step5-pipeline | step5-level6 | vs baseline |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| cold start to /up (ms) | 556 | 579 | 566 | 595 | 590 | 572 | 544 | 566 | 344 | 1.61× |
| idle RSS (MB) | 176 | 181 | 172 | 174 | 174 | 170 | 171 | 172 | 172 | 1.02× |
| peak RSS under load (MB) | 1,472 | 1,273 | 1,376 | 1,274 | 356 | 360 | 368 | 372 | 369 | 3.99× |

Jobs at end of run:
- baseline rep 1: {"queued": 0, "processed": 28247, "failed": 0}
- baseline rep 2: {"queued": 0, "processed": 26950, "failed": 0}
- baseline-rerun rep 1: {"queued": 0, "processed": 25328, "failed": 0}
- baseline-rerun rep 2: {"queued": 0, "processed": 27249, "failed": 0}
- step1-gzip rep 1: {"queued": 0, "processed": 27644, "failed": 0}
- step1-gzip rep 2: {"queued": 0, "processed": 27439, "failed": 0}
- step2-cache rep 1: {"queued": 0, "processed": 25965, "failed": 0}
- step2-cache rep 2: {"queued": 0, "processed": 26513, "failed": 0}
- step3-noredis rep 1: {"failed": 0, "processed": 29781, "queued": 0}
- step3-noredis rep 2: {"failed": 0, "processed": 30602, "queued": 0}
- step4-spinpool rep 1: {"failed": 0, "processed": 44046, "queued": 0}
- step4-spinpool rep 2: {"failed": 0, "processed": 44078, "queued": 0}
- step4-dbpool rep 1: {"failed": 0, "processed": 30185, "queued": 0}
- step4-dbpool rep 2: {"failed": 0, "processed": 34700, "queued": 0}
- step5-pipeline rep 1: {"failed": 0, "processed": 35560, "queued": 0}
- step5-pipeline rep 2: {"failed": 0, "processed": 36921, "queued": 0}
- step5-level6 rep 1: {"failed": 0, "processed": 37403, "queued": 0}
- step5-level6 rep 2: {"failed": 0, "processed": 37480, "queued": 0}
