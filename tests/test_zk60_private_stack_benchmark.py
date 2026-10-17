"""Prevent invalid scope, count and GPU routing from becoming a throughput claim."""
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

SCRIPT = Path(__file__).resolve().parents[1] / "scripts/zk60_private_stack_benchmark.py"
spec = importlib.util.spec_from_file_location("stack_benchmark", SCRIPT)
benchmark = importlib.util.module_from_spec(spec)
spec.loader.exec_module(benchmark)


class ClaimGates(unittest.TestCase):
    def setUp(self):
        self.prove = {"status": "accepted_in_process_and_published", "one_transcript": True,
                      "layers": 12, "shape": "m125", "tokens_counted_once": 512, "tokens": 512,
                      "synthetic": True, "trained_8b_proof": False,
                      "receipt_bytes": 100, "policy_sha256": "a" * 64}
        self.verify = {"status": "accepted", "layers": 12, "tokens": 512,
                       "trained_8b_proof": False, "receipt_bytes": 100, "policy_sha256": "a" * 64}

    def gate(self, accepted=26, declined=False, backend="gpu"):
        return benchmark.validate_result(self.prove, self.verify, backend, accepted, declined, "m125", 12)

    def test_counts_tokens_once_across_all_layers(self):
        self.assertEqual(self.gate(), 512)
        self.prove["tokens_counted_once"] *= 12
        with self.assertRaisesRegex(ValueError, "position count"):
            self.gate()

    def test_no_gpu_fallback_or_missing_layer_dispatch(self):
        with self.assertRaisesRegex(ValueError, "GPU path"):
            self.gate(accepted=25)
        with self.assertRaisesRegex(ValueError, "GPU path"):
            self.gate(declined=True)
        with self.assertRaisesRegex(ValueError, "CPU comparison"):
            self.gate(backend="cpu")

    def test_requires_complete_stack_and_independent_acceptance(self):
        self.verify["status"] = "refused"
        with self.assertRaisesRegex(ValueError, "not accepted"):
            self.gate()
        self.verify["status"] = "accepted"
        self.prove["layers"] = 1
        with self.assertRaisesRegex(ValueError, "complete stack"):
            self.gate()

    def test_cannot_relabel_synthetic_as_trained_8b(self):
        self.prove["trained_8b_proof"] = True
        with self.assertRaisesRegex(ValueError, "trained-model scope"):
            self.gate()

    def test_verifier_must_match_artifact_and_policy(self):
        self.verify["policy_sha256"] = "b" * 64
        with self.assertRaisesRegex(ValueError, "identity differs"):
            self.gate()


class RunRecovery(unittest.TestCase):
    def test_atomic_update_failure_preserves_previous_report(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "report.json"
            benchmark.atomic_write(path, '{"state":"running"}\n')
            with patch.object(benchmark.os, "replace", side_effect=OSError("injected failure")):
                with self.assertRaises(OSError):
                    benchmark.atomic_write(path, '{"state":"passed"}\n')
            self.assertEqual(json.loads(path.read_text()), {"state": "running"})
            self.assertEqual(list(Path(tmp).iterdir()), [path])

    def run_child(self, tmp, code, timeout):
        report = {"steps": []}
        path = Path(tmp) / "report.json"
        def save():
            benchmark.atomic_write(path, json.dumps(report))
        return benchmark.run_step("probe", [sys.executable, "-c", code], output=Path(tmp),
                                  source=Path(tmp), env=dict(os.environ), timeout=timeout,
                                  report=report, save=save)

    def test_timeout_reaps_owned_child_and_keeps_terminal_step_evidence(self):
        with tempfile.TemporaryDirectory() as tmp:
            with self.assertRaises(subprocess.TimeoutExpired):
                self.run_child(tmp, "import time; print('started', flush=True); time.sleep(60)", .2)
            row = json.loads((Path(tmp) / "report.json").read_text())["steps"][0]
            self.assertEqual(row["state"], "timed_out")
            self.assertLess(row["exit_code"], 0)
            self.assertEqual(row["log_sha256"], benchmark.sha(Path(tmp) / "probe.log"))
            with self.assertRaises(ProcessLookupError):
                os.kill(row["process"]["pid"], 0)

    def test_failed_command_is_not_mislabeled_as_interrupted_or_passed(self):
        with tempfile.TemporaryDirectory() as tmp:
            row, _ = self.run_child(tmp, "raise SystemExit(7)", 5)
            self.assertEqual((row["state"], row["exit_code"]), ("failed", 7))
            self.assertEqual(row["process"]["boot_id"], benchmark.process_identity(os.getpid())["boot_id"])

    def test_interrupt_reaps_owned_child_before_returning(self):
        with tempfile.TemporaryDirectory() as tmp:
            real_wait = benchmark.subprocess.Popen.wait
            first = True
            def interrupt_once(child, *args, **kwargs):
                nonlocal first
                if first:
                    first = False
                    raise benchmark.InterruptedRun("test interruption")
                return real_wait(child, *args, **kwargs)
            with patch.object(benchmark.subprocess.Popen, "wait", interrupt_once):
                with self.assertRaises(benchmark.InterruptedRun):
                    self.run_child(tmp, "import time; time.sleep(60)", 5)
            row = json.loads((Path(tmp) / "report.json").read_text())["steps"][0]
            self.assertEqual(row["state"], "interrupted")
            self.assertLess(row["exit_code"], 0)
            with self.assertRaises(ProcessLookupError):
                os.kill(row["process"]["pid"], 0)


class GuardIntegration(unittest.TestCase):
    def test_guard_change_between_steps_refuses_before_launch(self):
        with tempfile.TemporaryDirectory() as tmp:
            guard = Path(tmp) / "guard.py"
            guard.write_text("raise SystemExit(0)\n")
            report = {"steps": [], "guard_sha256": "0" * 64}
            with patch.object(benchmark, "GUARD", guard), patch.object(benchmark.subprocess, "Popen") as launch:
                with self.assertRaisesRegex(ValueError, "changed between commands"):
                    benchmark.run_step("changed", ["true"], output=Path(tmp), source=Path(tmp),
                                       env={}, timeout=1, report=report, save=lambda: None, guard_class="cpu")
                launch.assert_not_called()

    def run_with_guard(self, tmp, guard_body):
        guard = Path(tmp) / "fake_guard.py"
        guard.write_text(guard_body)
        report = {"steps": []}
        def save():
            (Path(tmp) / "report.json").write_text(json.dumps(report))
        with patch.object(benchmark, "GUARD", guard):
            return benchmark.run_step("probe", [sys.executable, "-c", "print('native')"],
                                      output=Path(tmp), source=Path(tmp), env=dict(os.environ),
                                      timeout=5, report=report, save=save,
                                      guard_class="cpu", small_shape=True)

    def test_guard_child_clock_excludes_queue_and_cleanup(self):
        with tempfile.TemporaryDirectory() as tmp:
            row, _ = self.run_with_guard(tmp, """import json,sys,time,subprocess
from pathlib import Path
args=sys.argv[1:]
assert args[args.index('--class')+1]=='cpu'
assert args[args.index('--need-gib')+1]=='1'
assert args[args.index('--cap-gib')+1]=='2'
time.sleep(.1)
rc=subprocess.run(args[args.index('--')+1:]).returncode
Path(args[args.index('--result-json')+1]).write_text(json.dumps({'exit':rc,'child_rc':rc,'guard_killed':None,'child_wall_seconds':.01}))
raise SystemExit(rc)
""")
            self.assertEqual(row["process_wall_seconds"], .01)
            self.assertGreater(row["guard_wall_seconds_including_queue_and_drain"], .1)
            self.assertEqual(row["state"], "passed")

    def test_missing_terminal_record_cannot_become_success(self):
        with tempfile.TemporaryDirectory() as tmp:
            with self.assertRaises(FileNotFoundError):
                self.run_with_guard(tmp, "raise SystemExit(0)")
            row = json.loads((Path(tmp) / "report.json").read_text())["steps"][0]
            self.assertEqual(row["state"], "failed")
            self.assertNotIn("process_wall_seconds", row)

    def test_refusal_without_native_launch_keeps_exit_and_no_rate_clock(self):
        with tempfile.TemporaryDirectory() as tmp:
            row, log = self.run_with_guard(tmp, """import json,sys
from pathlib import Path
Path(sys.argv[sys.argv.index('--result-json')+1]).write_text(json.dumps({'exit':70,'child_wall_seconds':None}))
raise SystemExit(70)
""")
            self.assertEqual(row["state"], "failed")
            self.assertEqual(row["exit_code"], 70)
            self.assertNotIn("process_wall_seconds", row)
            self.assertNotIn("native", log.read_text())

    def test_guard_failure_cannot_masquerade_as_native_refusal(self):
        with tempfile.TemporaryDirectory() as tmp:
            with self.assertRaisesRegex(ValueError, "native success/refusal"):
                self.run_with_guard(tmp, """import json,sys
from pathlib import Path
Path(sys.argv[sys.argv.index('--result-json')+1]).write_text(json.dumps({'exit':1,'child_rc':None,'guard_killed':'probe failed'}))
raise SystemExit(1)
""")


if __name__ == "__main__":
    unittest.main()
