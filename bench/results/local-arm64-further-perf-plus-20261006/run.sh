#!/bin/bash
# Usage: REPO=<checkout> run.sh OUTDIR "label1 label2 ..." ROUNDS   (labels: ours, pr5, plus, plus-off)
# Expects the images, a built bench/loadgen and the fixture data next to this script.
set -eu
S=$(dirname "$0"); REPO=${REPO:?path to a checkout with bench/lib and parity/reference.env}; LG=$S/loadgen-target/release/loadgen; ROOM=486777696
name=cf-demo; OUT=$S/$1; LABELS=$2; ROUNDS=${3:-3}; mkdir -p $OUT; : > $OUT/raw.jsonl; SECS=${SECS:-6}
snap() { docker exec $name sh -c 'for p in /proc/[0-9]*; do [ -r $p/stat ] || continue; echo "STAT $(cat $p/stat)"; echo "CMD $(tr "\0" " " < $p/cmdline)"; done' | python3 $REPO/bench/lib/proccpu.py parse; }
run_mode() { # label round
  local label=$1 round=$2 image extra=() port=80 cmd=()
  case $label in
    ours) image=campfire-elixir:release-demo3; port=8080
          extra=(-e CAMPFIRE_FAST_PAGES=1 -e CAMPFIRE_GZIP=libdeflate-1 -e PORT=8080 -e CAMPFIRE_WORKER=1 -e REDIS_URL=redis://127.0.0.1:6379/0)
          cmd=(sh -c "redis-server --bind 127.0.0.1 --port 6379 --daemonize yes --save '' --appendonly no >/dev/null; exec /campfire/bin/campfire start") ;;
    pr5) image=campfire-elixir:fp-base; extra=(-e LOG_REQUESTS=false) ;;
    plus*) image=campfire-elixir:fp-plus; extra=(-e LOG_REQUESTS=false)
           for kv in ${PLUS_ENV:-}; do extra+=(-e "$kv"); done
           case $label in plus-off) extra+=(-e CAMPFIRE_DB_NATIVE_READS=0) ;; esac ;;
  esac
  docker rm -f $name >/dev/null 2>&1 || true; docker volume rm -f cf-bench-data >/dev/null 2>&1 || true; docker volume create cf-bench-data >/dev/null
  docker run --rm --user 0 -v cf-bench-data:/dst -v $S/data:/src:ro campfire-elixir:toolchain-pr5 sh -c 'cp -a /src/db /src/files /dst/ && chown -R 1000:1000 /dst'
  docker run -d --name $name --cpus 4 --env-file $REPO/parity/reference.env "${extra[@]}" \
    --mount type=volume,src=cf-bench-data,dst=/rails/storage/db,volume-subpath=db --mount type=volume,src=cf-bench-data,dst=/rails/storage/files,volume-subpath=files \
    -p 18081:$port $image ${cmd[@]+"${cmd[@]}"} >/dev/null
  for i in $(seq 100); do curl -sf localhost:18081/up >/dev/null && break; sleep 0.3; done
  local cookie; cookie=$(docker exec $name bin/campfire rpc 's=Campfire.DB.one("SELECT * FROM sessions LIMIT 1"); IO.write("session_token=" <> URI.encode(Campfire.Rails.sign_cookie("session_token", s["token"], DateTime.to_iso8601(DateTime.add(DateTime.utc_now(), 86400*30))), &URI.char_unreserved?/1))')
  local before; before=$(sqlite3 $S/data/db/production.sqlite3 "SELECT id FROM messages WHERE room_id=$ROOM ORDER BY created_at DESC LIMIT 1 OFFSET 60")
  for w in "room|/rooms/$ROOM" "messages|/rooms/$ROOM/messages?before=$before" "sidebar|/users/me/sidebar" "search|/searches?q=campfire" "up|/up" "post|POST"; do
    local n=${w%%|*} p=${w#*|} args
    if [ "$p" = POST ]; then args=(--post-room $ROOM); else args=(--path "$p"); $LG fetch --base http://127.0.0.1:18081 --cookie "$cookie" --path "$p" --out $OUT/body-$label-$n.html >/dev/null; fi
    $LG http --base http://127.0.0.1:18081 --cookie "$cookie" "${args[@]}" --conc 16 --duration 2 >/dev/null
    for c in 1 16; do
      local b a r; b=$(snap); r=$($LG http --base http://127.0.0.1:18081 --cookie "$cookie" "${args[@]}" --conc $c --duration $SECS); a=$(snap)
      python3 - "$label" "$round" "$n" "$c" "$r" "$b" "$a" >> $OUT/raw.jsonl <<'PY'
import json,sys
label,rnd,n,c,r,b,a=sys.argv[1:]; r=json.loads(r); b=json.loads(b); a=json.loads(a)
assert r["errors"]==0 and r["invalid_responses"]==0 and set(r["statuses"])=={"200"}, r
print(json.dumps({"label":label,"round":int(rnd),"workload":n,"conc":int(c),"rps":r["rps"],"p50_ms":r["latency"]["p50_ms"],"p99_ms":r["latency"]["p99_ms"],"avg_bytes":r["avg_bytes"],"cpu_us_by_role":{k:round((a[k]-b.get(k,0))/r["ok"],1) for k in sorted(a) if a[k]-b.get(k,0)>0}}))
PY
    done
  done
  docker rm -f $name >/dev/null
}
read -ra L <<< "$LABELS"
for round in $(seq $ROUNDS); do
  if [ $((round % 2)) = 1 ]; then order=("${L[@]}"); else order=(); for ((i=${#L[@]}-1;i>=0;i--)); do order+=("${L[i]}"); done; fi
  for label in "${order[@]}"; do run_mode $label $round; done
done
