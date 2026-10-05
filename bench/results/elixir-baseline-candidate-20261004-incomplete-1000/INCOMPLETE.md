# Excluded 1,000-client attempt

This diagnostic run is not included in the before/after comparison. On the
2-vCPU orb (CPU 0 server, CPU 1 load generator), untouched upstream `b6b82e5`
could not establish 1,000 Action Cable clients within the load generator's
120-second deadline: 160 clients became ready and 52 failed. The 100- and
500-client phases completed with zero failures before that limit was reached.

The controlled comparison therefore uses 100 and 500 clients, the highest
levels both images can complete on this hardware. The raw process-memory and
phase logs from the excluded attempt remain in this directory.
