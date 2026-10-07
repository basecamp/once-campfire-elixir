#!/usr/bin/env python3
"""Observe Resque queued, active and failed state until it is stably drained."""
import json
import socket
import sys
import time


SCRIPT = """
local active = 0
for _, worker in ipairs(redis.call('SMEMBERS', 'resque:workers')) do
  if redis.call('EXISTS', 'resque:worker:' .. worker) == 1 then active = active + 1 end
end
return {redis.call('LLEN', 'resque:queue:default'), active, tonumber(redis.call('GET', 'resque:stat:failed') or '0')}
""".strip()


def read_value(stream):
    line = stream.readline()
    if not line:
        raise OSError("Redis closed the connection")
    kind, payload = line[:1], line[1:-2]
    if kind == b":":
        return int(payload)
    if kind == b"$":
        size = int(payload)
        return None if size < 0 else stream.read(size + 2)[:-2].decode()
    if kind == b"*":
        return [read_value(stream) for _ in range(int(payload))]
    if kind == b"-":
        raise OSError(payload.decode())
    return payload.decode()


def command(sock, stream, *args):
    encoded = [str(arg).encode() for arg in args]
    sock.sendall((f"*{len(encoded)}\r\n").encode() + b"".join(f"${len(arg)}\r\n".encode() + arg + b"\r\n" for arg in encoded))
    return read_value(stream)


def observe(sock, stream):
    queued, active, failed = command(sock, stream, "EVAL", SCRIPT, 0)
    return {"at": time.time(), "queued": queued, "active": active, "failed": failed}


def main():
    timeout = float(sys.argv[1]) if len(sys.argv) > 1 else 120.0
    interval = 0.1
    try:
        sock = socket.create_connection(("127.0.0.1", 6379), timeout=2)
    except OSError:
        print(json.dumps({"schema_version": 2, "backend": "internal_unobserved", "drained": None,
                          "reason": "no external Redis endpoint"}))
        return
    stream = sock.makefile("rb")
    observations = []
    consecutive_quiet = 0
    quiet_since = None
    deadline = time.monotonic() + timeout
    while True:
        snapshot = observe(sock, stream)
        observations.append(snapshot)
        if snapshot["queued"] == snapshot["active"] == snapshot["failed"] == 0:
            consecutive_quiet += 1
            quiet_since = quiet_since or time.monotonic()
        else:
            consecutive_quiet = 0
            quiet_since = None
        stable_quiet = consecutive_quiet >= 3 and time.monotonic() - quiet_since >= 1.0
        if stable_quiet or snapshot["failed"] > 0 or time.monotonic() >= deadline:
            break
        time.sleep(interval)
    sock.close()
    result = {"schema_version": 2, "backend": "redis_resque", "drained": stable_quiet,
              "stable_quiet_observations_required": 3, "stable_quiet_secs_required": 1.0,
              "observations": observations, "final": observations[-1]}
    print(json.dumps(result))
    if not result["drained"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
