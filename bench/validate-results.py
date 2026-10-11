#!/usr/bin/env python3
"""Fail-closed validation for benchmark result directories (schema 2)."""
import json
import pathlib
import sys


REDIS_APPS = {"reference", "baseline", "elixir", "candidate"}


def load(path):
    with path.open() as stream:
        return json.load(stream)


def require(condition, message):
    if not condition:
        raise AssertionError(message)


def validate_matrix(expected):
    apps = expected.get("apps", [])
    suites = expected.get("suites", [])
    require(apps and len(apps) == len(set(apps)) and set(apps) <= REDIS_APPS | {"go", "rust", "rust-identity"},
            "matrix: apps must be supported, nonempty and unique")
    require(type(expected.get("reps")) is int and expected["reps"] > 0, "matrix: repetitions must be positive")
    require(suites and len(suites) == len(set(suites)) and set(suites) <= {"http", "cable", "upload"},
            "matrix: suites must be supported, nonempty and unique")
    require("rust-identity" not in apps or "http" in suites, "matrix: rust-identity requires HTTP work")
    backends = expected.get("job_backends", {})
    require(set(backends) == set(apps) and set(backends.values()) <= {"redis_resque", "internal_unobserved"},
            "matrix: every app must declare its job backend")
    if "http" in suites:
        routes = expected.get("http_routes", [])
        require(routes and len(routes) == len(set(routes)) and all(isinstance(route, str) and route for route in routes),
                "matrix: HTTP routes must be nonempty and unique")
    for suite, field in (("http", "http_concs"), ("cable", "cable_clients")):
        if suite in suites:
            values = expected.get(field, [])
            require(values and all(type(value) is int and value > 0 for value in values) and len(values) == len(set(values)),
                    f"matrix: {field} must be positive and unique")
    if "upload" in suites:
        require(type(expected.get("upload_reps")) is int and expected["upload_reps"] > 0, "matrix: uploads must be positive")


def validate_http(sample, expected):
    actual = {(row.get("route"), row.get("conc")): row for row in sample["http"]}
    require(len(actual) == len(sample["http"]), "duplicate HTTP workload")
    require(set(actual) == expected, f"HTTP workloads differ: expected {sorted(expected)}, got {sorted(actual)}")
    for key, row in actual.items():
        require(row.get("validation") == "route-contract-v1", f"{key}: missing every-response contract")
        require(row.get("ok", 0) > 0, f"{key}: zero successful HTTP work")
        require(row.get("errors") == 0 and row.get("invalid_responses") == 0, f"{key}: HTTP errors")
        require(row.get("statuses") == {"200": row["ok"]}, f"{key}: non-200 HTTP response")
        require(row.get("latency", {}).get("n") == row["ok"], f"{key}: incomplete HTTP latency evidence")
        require(row.get("cpu_us_per_success", 0) > 0, f"{key}: missing CPU metric")


def validate_cable(sample, clients):
    actual = {row.get("clients"): row for row in sample["cable"]}
    require(len(actual) == len(sample["cable"]), "duplicate Cable workload")
    require(set(actual) == set(clients), f"Cable workloads differ: expected {clients}, got {sorted(actual)}")
    for count, row in actual.items():
        require(row.get("ready") == count and row.get("failed") == 0, f"Cable {count}: clients not ready")
        paced = row.get("latency", {})
        require(paced.get("messages", 0) > 0, f"Cable {count}: zero paced work")
        require(paced.get("post_attempts") == paced["messages"], f"Cable {count}: paced attempts missing")
        require(paced.get("post_errors") == 0, f"Cable {count}: paced POST errors")
        require(paced.get("post_successes") == paced["messages"], f"Cable {count}: paced POSTs incomplete")
        require(paced.get("complete") == paced["messages"], f"Cable {count}: paced fanout incomplete")
        saturated = row.get("throughput", {})
        require(saturated.get("post_attempts", 0) > 0, f"Cable {count}: zero saturated work")
        require(saturated.get("post_errors") == 0, f"Cable {count}: saturated POST errors")
        require(saturated.get("posted", 0) > 0, f"Cable {count}: zero successful saturated POSTs")
        require(saturated["post_attempts"] == saturated["posted"], f"Cable {count}: saturated POSTs incomplete")
        require(saturated.get("complete") == saturated["posted"], f"Cable {count}: saturated fanout incomplete")


def validate_upload(sample, count):
    upload = sample.get("upload", {})
    runs = upload.get("runs", [])
    require(len(runs) == count, f"expected {count} uploads, got {len(runs)}")
    require(count > 0 and upload.get("median_total_ms") is not None, "zero completed uploads")
    for index, row in enumerate(runs):
        require("error" not in row, f"upload {index}: {row.get('error')}")
        require(row.get("post_status") == 200, f"upload {index}: POST failed")
        require(row.get("thumb_status") == 200 and row.get("thumb_bytes", 0) > 100, f"upload {index}: invalid thumbnail")


def validate_jobs(root, app, rep, expected):
    jobs = load(root / f"{app}-{rep}-jobs.json")
    # The manifest declares each app's backend; a result never chooses its own.
    require(jobs.get("backend") == expected, f"{app}-{rep}: expected {expected} jobs, observed {jobs.get('backend')}")
    if expected == "redis_resque":
        require(jobs.get("drained") is True, f"{app}-{rep}: jobs did not drain")
        observations = jobs.get("observations", [])
        require(len(observations) >= 3, f"{app}-{rep}: insufficient job observations")
        require(jobs.get("final") == observations[-1], f"{app}-{rep}: final job state differs from observations")
        require(all(left["at"] < right["at"] for left, right in zip(observations, observations[1:])),
                f"{app}-{rep}: job observation times must increase")
        quiet = []
        for observation in observations:
            require(all(type(observation.get(key)) is int and observation[key] >= 0 for key in ("queued", "active", "failed")),
                    f"{app}-{rep}: invalid job counts")
            require(observation["failed"] == 0, f"{app}-{rep}: failed jobs observed")
            if observation["queued"] == observation["active"] == 0:
                quiet.append(observation)
            else:
                quiet = []
        require(len(quiet) >= 3 and quiet[-1]["at"] - quiet[0]["at"] >= 1.0,
                f"{app}-{rep}: final job quiet window is insufficient")
    else:
        require(jobs.get("backend") == "internal_unobserved", f"{app}-{rep}: job backend not explicit")


def validate(root, require_complete):
    manifest_path = root / "manifest.json"
    require(manifest_path.exists(), "schema-2 manifest.json is required (use --legacy only for historical evidence)")
    manifest = load(manifest_path)
    require(manifest.get("schema_version") == 2, "unsupported benchmark manifest schema")
    audit = None
    if require_complete:
        require(manifest.get("complete") is True and manifest.get("status") == "complete", "benchmark attempt is incomplete")
        audit = load(root / manifest.get("audit", "audit.json"))
        require(audit.get("schema_version") == 2 and audit.get("passed") is True, "final audit missing or failed")
    require((root / "env.txt").exists(), "environment/identity evidence is missing")
    expected = manifest.get("expected", {})
    validate_matrix(expected)
    apps = expected.get("apps", [])
    reps = expected.get("reps", 0)
    suites = set(expected.get("suites", []))
    routes = set(expected.get("http_routes", []))
    concs = expected.get("http_concs", [])
    clients = expected.get("cable_clients", [])
    upload_reps = expected.get("upload_reps", 0)
    expected_files = {f"{app}-{rep}.json" for app in apps for rep in range(1, reps + 1)}
    for path in root.glob("*-*.json"):
        if "app" in load(path):
            require(path.name in expected_files, f"unexpected sample: {path.name}")
    seen = set()
    counts = {"runs": 0, "http_samples": 0, "http_successes": 0, "cable_cases": 0,
              "cable_paced_attempts": 0, "cable_saturated_attempts": 0,
              "cable_saturated_completed": 0, "uploads": 0}
    for app in apps:
        app_suites = suites if app != "rust-identity" else suites & {"http"}
        for rep in range(1, reps + 1):
            path = root / f"{app}-{rep}.json"
            require(path.exists(), f"missing sample {path.name}")
            sample = load(path)
            require(sample.get("schema_version") == 2, f"{path.name}: new-format sample required")
            require((sample.get("app"), sample.get("rep")) == (app, rep), f"{path.name}: identity mismatch")
            require(sample.get("sample_complete") is True, f"{path.name}: sample incomplete")
            require((app, rep) not in seen, f"duplicate sample {app}-{rep}")
            seen.add((app, rep))
            preflight = load(root / f"{app}-{rep}-validation.json")
            require(preflight.get("passed") is True, f"{app}-{rep}: preflight failed")
            expected_http = {(route, conc) for route in routes for conc in concs} if "http" in app_suites else set()
            validate_http(sample, expected_http)
            if expected_http:
                writes = load(root / f"{app}-{rep}-write-audit.json")
                posts = sum(row["ok"] for row in sample["http"] if row["route"] == "post_message")
                require(writes.get("verified") is True and writes.get("acknowledged", -1) >= posts,
                        f"{app}-{rep}: exact persistent-write audit missing")
            for row in sample["http"]:
                route, conc = row["route"], row["conc"]
                raw = root / "raw" / f"{app}-{rep}-http-{route}-c{conc}.json"
                require(raw.exists(), f"{app}-{rep}: missing raw HTTP sample")
                require(load(raw) == {key: value for key, value in row.items() if key not in {"route", "cpu_us_per_success"}},
                        f"{raw.name}: raw result differs from sample")
            if "cable" in app_suites:
                validate_cable(sample, clients)
                for row in sample["cable"]:
                    count = row["clients"]
                    raw = root / "raw" / f"{app}-{rep}-cable-{count}.json"
                    require(raw.exists(), f"{app}-{rep}: missing raw Cable sample")
                    require(load(raw) == {key: value for key, value in row.items() if key != "process_memory"},
                            f"{raw.name}: raw result differs from sample")
            else:
                require(sample.get("cable") == [], f"{app}-{rep}: unexpected Cable results")
            if "upload" in app_suites:
                raw = root / "raw" / f"{app}-{rep}-upload.json"
                require(raw.exists(), f"{app}-{rep}: missing raw upload sample")
                validate_upload(sample, upload_reps)
                require(load(raw) == sample["upload"], f"{raw.name}: raw result differs from sample")
            else:
                require(sample.get("upload") == {}, f"{app}-{rep}: unexpected upload results")
            validate_jobs(root, app, rep, expected["job_backends"][app])
            require(all(sample.get("memory", {}).get(key, 0) > 0 for key in ("idle_current_mb", "idle_anon_mb", "peak_current_mb", "peak_anon_mb")),
                    f"{app}-{rep}: missing memory metrics")
            counts["runs"] += 1
            counts["http_samples"] += len(sample["http"])
            counts["http_successes"] += sum(row["ok"] for row in sample["http"])
            counts["cable_cases"] += len(sample["cable"])
            counts["cable_paced_attempts"] += sum(row["latency"]["post_attempts"] for row in sample["cable"])
            counts["cable_saturated_attempts"] += sum(row["throughput"]["post_attempts"] for row in sample["cable"])
            counts["cable_saturated_completed"] += sum(row["throughput"]["complete"] for row in sample["cable"])
            counts["uploads"] += len(sample.get("upload", {}).get("runs", []))
    require(counts["runs"] == len(apps) * reps, "sample matrix incomplete")
    if audit is not None:
        require(audit.get("counts") == counts, "final audit counts do not match samples")
    return manifest, counts


def main():
    command, directory = sys.argv[1:3]
    root = pathlib.Path(directory)
    if command == "matrix":
        validate_matrix(load(root / "manifest.json")["expected"])
        return
    if command == "interrupt":
        path = root / "manifest.json"
        if path.exists():
            manifest = load(path)
            if not manifest.get("complete"):
                manifest["status"] = "incomplete"
                path.write_text(json.dumps(manifest, indent=2) + "\n")
        return
    if command == "finalize":
        manifest, counts = validate(root, False)
        audit = {"schema_version": 2, "passed": True, "counts": counts}
        (root / "audit.json").write_text(json.dumps(audit, indent=2) + "\n")
        manifest["status"] = "complete"
        manifest["complete"] = True
        manifest["audit"] = "audit.json"
        (root / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
        return
    if command == "check":
        validate(root, True)
        return
    raise SystemExit("usage: validate-results.py matrix|check|finalize|interrupt DIR")


if __name__ == "__main__":
    try:
        main()
    except (AssertionError, KeyError, TypeError, ValueError, json.JSONDecodeError) as error:
        raise SystemExit(f"benchmark validation failed: {error}")
