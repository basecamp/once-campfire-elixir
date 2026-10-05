import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


PROJECT = Path(__file__).resolve().parents[3]
VALIDATOR = PROJECT / "bench/validate-results.py"
REPORT = PROJECT / "bench/report"


class BenchmarkValidationTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        (self.root / "raw").mkdir()
        (self.root / "env.txt").write_text("fixture identities\n")
        self.write("manifest.json", {
            "schema_version": 2, "status": "running", "complete": False,
            "expected": {"apps": ["baseline", "candidate"], "reps": 1,
                         "suites": ["http", "cable", "upload"], "http_routes": ["room_show"],
                         "http_concs": [1], "cable_clients": [3], "upload_reps": 2},
        })
        for app, successes in (("baseline", 11), ("candidate", 7)):
            sample = self.sample(app, successes)
            self.write(f"{app}-1.json", sample)
            self.write(f"{app}-1-validation.json", {"passed": True})
            quiet = [{"at": at, "queued": 0, "active": 0, "failed": 0} for at in (1, 1.5, 2)]
            self.write(f"{app}-1-jobs.json", {"schema_version": 2, "backend": "redis_resque", "drained": True,
                                                       "observations": quiet, "final": quiet[-1]})
            self.write(f"raw/{app}-1-http-room_show-c1.json",
                       {key: value for key, value in sample["http"][0].items() if key not in {"route", "cpu_us_per_success"}})
            self.write(f"raw/{app}-1-cable-3.json", sample["cable"][0])
            self.write(f"raw/{app}-1-upload.json", sample["upload"])

    def write(self, name, value):
        (self.root / name).write_text(json.dumps(value) + "\n")

    def sample(self, app, successes):
        histogram = {"n": successes, "p50_ms": 1.0, "p99_ms": 2.0}
        cable_histogram = {"n": 2, "p50_ms": 1.0, "p99_ms": 2.0}
        return {
            "schema_version": 2, "sample_complete": True, "app": app, "rep": 1, "cold_start_ms": 10,
            "memory": {"idle_current_mb": 10, "idle_anon_mb": 8, "peak_current_mb": 20,
                       "peak_anon_mb": 16, "cgroup_peak_mb": 21},
            "http": [{"route": "room_show", "conc": 1, "ok": successes, "errors": 0,
                      "invalid_responses": 0, "statuses": {"200": successes}, "latency": histogram,
                      "cpu_us_per_success": 3.0, "rps": float(successes)}],
            "cable": [{"clients": 3, "ready": 3, "failed": 0, "connect_secs": 1.0,
                       "latency": {"messages": 2, "post_attempts": 2, "post_successes": 2,
                                   "post_errors": 0, "complete": 2, "post": cable_histogram,
                                   "per_client": cable_histogram, "all_clients": cable_histogram},
                       "throughput": {"post_attempts": 4, "post_errors": 0, "posted": 4, "complete": 4,
                                      "posts_per_sec": 4.0, "delivered_msgs_per_sec": 3.0,
                                      "frames_per_sec": 9.0, "wire_mb_per_sec": 0.1, "drain_secs": 0.2,
                                      "post": cable_histogram, "per_client": cable_histogram,
                                      "all_clients": cable_histogram}}],
            "upload": {"median_total_ms": 5.0, "runs": [
                {"post_status": 200, "post_ms": 2.0, "thumb_status": 200, "thumb_bytes": 500,
                 "thumb_ms": 3.0, "total_ms": 5.0},
                {"post_status": 200, "post_ms": 3.0, "thumb_status": 200, "thumb_bytes": 600,
                 "thumb_ms": 3.0, "total_ms": 6.0},
            ]},
        }

    def run_validator(self, command="finalize"):
        return subprocess.run([sys.executable, str(VALIDATOR), command, str(self.root)], capture_output=True, text=True)

    def test_complete_asymmetric_fixture_is_accepted(self):
        result = self.run_validator()
        self.assertEqual(result.returncode, 0, result.stderr)
        manifest = json.loads((self.root / "manifest.json").read_text())
        self.assertTrue(manifest["complete"])
        self.assertEqual(json.loads((self.root / "audit.json").read_text())["counts"]["http_successes"], 18)
        report = subprocess.run([sys.executable, str(REPORT), str(self.root)], capture_output=True, text=True)
        self.assertEqual(report.returncode, 0, report.stderr)
        self.assertIn("saturated POST attempts", report.stdout)

    def test_plausible_http_error_is_rejected(self):
        sample = json.loads((self.root / "candidate-1.json").read_text())
        sample["http"][0].update(errors=1, statuses={"200": 7, "500": 1})
        self.write("candidate-1.json", sample)
        result = self.run_validator()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("HTTP errors", result.stderr)

    def test_cable_post_error_is_rejected_even_if_completed_matches_posted(self):
        sample = json.loads((self.root / "candidate-1.json").read_text())
        throughput = sample["cable"][0]["throughput"]
        throughput.update(post_attempts=5, post_errors=1, posted=4, complete=4)
        self.write("candidate-1.json", sample)
        result = self.run_validator()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("saturated POST errors", result.stderr)

    def test_missing_sample_and_missing_raw_evidence_are_rejected(self):
        (self.root / "candidate-1.json").unlink()
        self.assertIn("missing sample", self.run_validator().stderr)
        self.write("candidate-1.json", self.sample("candidate", 7))
        (self.root / "raw/candidate-1-cable-3.json").unlink()
        self.assertIn("missing raw Cable", self.run_validator().stderr)

    def test_zero_work_and_incomplete_uploads_are_rejected(self):
        sample = json.loads((self.root / "candidate-1.json").read_text())
        sample["http"][0].update(ok=0, statuses={"200": 0}, latency={"n": 0})
        self.write("candidate-1.json", sample)
        self.assertIn("zero successful HTTP work", self.run_validator().stderr)
        sample = self.sample("candidate", 7)
        sample["upload"]["runs"].pop()
        self.write("candidate-1.json", sample)
        self.assertIn("expected 2 uploads", self.run_validator().stderr)

    def test_active_or_failed_jobs_are_rejected(self):
        jobs = json.loads((self.root / "candidate-1-jobs.json").read_text())
        jobs["drained"] = False
        jobs["final"]["active"] = 1
        self.write("candidate-1-jobs.json", jobs)
        self.assertIn("jobs did not drain", self.run_validator().stderr)

    def test_report_refuses_incomplete_new_format(self):
        result = subprocess.run([sys.executable, str(REPORT), str(self.root)], capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("benchmark attempt is incomplete", result.stderr)

    def test_raw_results_must_match_reported_samples(self):
        for name, mutate in (
            ("raw/candidate-1-http-room_show-c1.json", lambda raw: raw.update(rps=999)),
            ("raw/candidate-1-cable-3.json", lambda raw: raw["throughput"].update(delivered_msgs_per_sec=999)),
            ("raw/candidate-1-upload.json", lambda raw: raw.update(median_total_ms=999)),
        ):
            with self.subTest(name=name):
                original = json.loads((self.root / name).read_text())
                changed = json.loads(json.dumps(original))
                mutate(changed)
                self.write(name, changed)
                self.assertIn("raw result differs", self.run_validator().stderr)
                self.write(name, original)

    def test_job_quiet_window_is_recomputed_not_trusted(self):
        original = json.loads((self.root / "candidate-1-jobs.json").read_text())
        for case in ("too_short", "interrupted", "final_mismatch", "time_reversed"):
            with self.subTest(case=case):
                jobs = json.loads(json.dumps(original))
                if case == "too_short":
                    for index, observation in enumerate(jobs["observations"]):
                        observation["at"] = 1 + index / 100
                    jobs["final"] = jobs["observations"][-1]
                elif case == "interrupted":
                    jobs["observations"][1]["active"] = 1
                elif case == "final_mismatch":
                    jobs["final"]["at"] = 99
                else:
                    jobs["observations"][1]["at"] = 0
                self.write("candidate-1-jobs.json", jobs)
                self.assertNotEqual(self.run_validator().returncode, 0)
        self.write("candidate-1-jobs.json", original)

    def test_matrix_rejects_empty_invalid_and_duplicate_workloads(self):
        original = json.loads((self.root / "manifest.json").read_text())
        for changes in ({"suites": []}, {"suites": ["typo"]}, {"apps": ["candidate", "candidate"]},
                        {"apps": ["typo"]}, {"http_routes": []}, {"http_concs": []},
                        {"http_concs": [0]}, {"cable_clients": []}, {"cable_clients": [3, 3]},
                        {"upload_reps": 0}, {"apps": ["rust-identity"], "suites": ["cable"]}):
            with self.subTest(changes=changes):
                manifest = json.loads(json.dumps(original))
                manifest["expected"].update(changes)
                self.write("manifest.json", manifest)
                result = self.run_validator("matrix")
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("matrix", result.stderr)
        self.write("manifest.json", original)

    def test_unexpected_extra_run_is_rejected(self):
        self.write("candidate-2.json", self.sample("candidate", 7))
        self.assertIn("unexpected sample", self.run_validator().stderr)

    def test_legacy_option_cannot_bypass_new_manifest(self):
        result = subprocess.run([sys.executable, str(REPORT), "--legacy", str(self.root)], capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("legacy", result.stderr.lower())


if __name__ == "__main__":
    unittest.main()
