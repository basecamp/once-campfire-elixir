# Performance tuning

The initial parity-verified release is preserved in
`results/baseline-20261004/`. Two alternating matched rounds completed all HTTP,
Cable and upload checks. These are capacity measurements on four server CPU cores,
not TLS/NIC or many-distinct-user measurements.

Diagnostic eprof results are retained separately in `results/profile-http/` and
`results/profile-cable/`; tracing overhead means their load rates are not benchmarks.
The room profile spent 25.25% in deflation and 7.65% in inflation. Cable spent
33.72% in JSON string decoding and 33.87% in JSON escaping. Every subscribed
connection was decoding and encoding the same broadcast independently.

The tuned implementation:

* Reuses outgoing Cable frames keyed by stream, subscription identifier and exact
  payload, after each connection's subscription authorization. The supervised
  cache retains at most 4,096 frames in FIFO order, including multiple concurrent
  payloads per stream/identifier. Payloads over 256 KiB bypass retention. Disconnect
  handling remains separate.
* Fetches message fragments in a single Redis MGET, preserving record order,
  versions, output and miss behavior. A bounded decoded cache reuses only identical
  nonexpiring Redis entries; Redis is still checked on every request. Expiring,
  corrupt, changed and differently versioned entries retain the original checks.
* Groups ordered routes by the first literal path segment and precomputes verbs,
  retaining regex matching and route precedence within each group.
* Uses the Rails connection's captured SQLite NORMAL synchronization, page cache
  and mmap settings. The native busy timeout is retained.
* Polls immediately after completing a queued job; idle/error polls retain the
  50 ms delay. This removes the accidental 20 jobs/second ceiling.
* Removes the unused fast_html dependency and its parser pool; the pinned native
  Nokogiri Gumbo parser still renders rich text.
* Serves assets with the pinned Rack MIME table, public cache lifetime,
  Last-Modified, conditional/range behavior and chunked gzip. The prior Plug.Static
  configuration omitted the cache lifetime and left proxy caching ineffective.
  `parity/assets.py` compares bytes and selected headers with Rails for 130 cases.

The final complete parity run must match the source digest before timing starts.
Raw queue depth and processed counts remain part of the benchmark evidence:
HTTP acceptance throughput alone does not establish background-job capacity.

The first latest-frame-only implementation passed the ordinary protocol gates but
thrashed under concurrent saturation: only 2,754/3,590 messages completed fanout at
500 clients and 1,548/2,340 at 1,000 clients before the drain deadline. That aborted
run is retained in `results/tuned-20261004/` with an `INCOMPLETE.md` marker. Reports
refuse to publish it. The corrected FIFO cache retains concurrent messages; its
isolated 1,000-client stress run delivered all 919 messages at 61.0 messages/s,
processed all 949 queued jobs and ended with no backlog or failures. The subsequent
balanced full comparison is stored separately in `results/tuned-fifo-20261004/`.

The benchmark launcher and reporter reject failed subscriptions, incomplete paced
messages and any posted message that does not complete fanout to every client.

The final matched comparison completed two alternating rounds per app with zero
HTTP errors, complete paced and saturated fanout, valid uploads/thumbnails, and
zero remaining native jobs or failures. CSS improves 8.07×, 1,000-client fanout
3.42×, message posting 1.65× and room rendering 1.27×. Peak anonymous memory drops
42.7%. Rust retains a 26.04× room throughput advantage and an 8.21× 1,000-client
fanout advantage. Results are in `results/tuning-comparison.md` and
`results/tuned-fifo-20261004/report.md`. The Native/Rust room preflights record
approximately 464/416 KB decoded and 21/24 KB compressed; actual response sizes
and each port's production process model remain part of the comparison.
