# Raw summaries behind the tables in this directory's parents

Machine: Apple M1 Pro, 10 cores, macOS 27.0.0 arm64.
Harness: `once-campfire-verification` — `bench/native-http.rb` driving
`loadgen/target/release/loadgen`, fixture `fixtures/default` restored per run, every response checked
against its route contract and every acknowledged write audited.

- `room-show/final-*.json` — the matrix recorded in `../final-matrix-20261019.md`
- `room-show/cmp-*.json` — the matrix recorded in `../compliance-matrix-20261020.md`
  (`cmp` = after the cache-correctness fixes)
- `fanout-after.json` — `cable` mode, 100 clients, six subscriptions each, four posters, 12 s, the
  frame-once change applied

Command, for both matrices (concurrencies and routes as noted in each table):

    bench/native-http.rb --app <elixir|express|go> --base <url> --out <dir> \
      --routes room_show,messages_page,sidebar,search,post_message --concs 16,64 \
      --duration 8 --rounds 2

and for the fan-out point:

    loadgen cable --base <url> --cookie <session> --room <room> --streams <streams> \
      --clients 100 --posters 4 --tput-secs 12

The fan-out figure before the change (245.9 messages/s) was measured earlier in the same session with
the same command; the re-run kept in this repository is the one after it. Reproducing the "before"
number means reverting the fan-out change together with the two call sites that depend on it
(`Campfire.Broadcasts`, `Campfire.Messages`), which this directory does not do.

Ratios within one matrix are comparable; absolute numbers move between sessions on this machine (the
same code has measured 15k-40k on `room_show @64`).
