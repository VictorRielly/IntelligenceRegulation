"""Legacy baseline must use the guard and withhold rates on any failure."""
import importlib.util
import json
from pathlib import Path
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

SCRIPT = Path(__file__).resolve().parents[1] / "ops/zkp-mvp/baseline_run.py"
spec = importlib.util.spec_from_file_location("legacy_baseline", SCRIPT)
baseline = importlib.util.module_from_spec(spec)
spec.loader.exec_module(baseline)


class GuardedBaseline(unittest.TestCase):
    def attempt(self, code, body):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            source = root / "source"
            binary = source / "hashline/target/release/deps/hashline-test"
            binary.parent.mkdir(parents=True)
            binary.touch()
            binary.chmod(0o700)
            out = root / "out"
            sampler = SimpleNamespace(samples=[], stop=SimpleNamespace(set=lambda: None),
                                      thread=SimpleNamespace(start=lambda: None, join=lambda **kwargs: None))
            def guarded(name, command, **kwargs):
                self.assertEqual(kwargs["guard_class"], "gpu")
                self.assertEqual(command[0], str(binary))
                log = out / "run.log"
                log.write_text(body)
                return {"exit_code": code, "guard_result": {"peak_vram_mib": 200},
                        "process_wall_seconds": 2.0,
                        "guard_wall_seconds_including_queue_and_drain": 12.0}, log
            with patch.object(baseline, "SRC", source), patch.object(sys, "argv", [str(SCRIPT), "--output", str(out)]), \
                    patch.object(baseline.bench, "run_step", guarded), patch.object(baseline.bench, "GpuSampler", return_value=sampler), \
                    patch("builtins.print"):
                result = baseline.main()
            return result, json.loads((out / "report.json").read_text()), (out / "run.done").read_text()

    def test_guard_refusal_never_reports_throughput(self):
        code, report, done = self.attempt(70, "guard refused admission\n")
        self.assertEqual((code, report["state"], done), (1, "failed", "1\n"))
        self.assertNotIn("diagnostic_positions_per_workload_second", report)

    def test_failure_after_proof_timing_line_still_withholds_rate(self):
        body = "[ZK60] keyed gpu zk commit accepted\n" * 24
        body += "RESULT: prove 1.0 s and verify by streaming 2.0 s, receipt 3 B\n"
        body += "1 passed; 0 failed\n"
        code, report, done = self.attempt(75, body)
        self.assertEqual((code, report["state"], done), (1, "failed", "1\n"))
        self.assertNotIn("diagnostic_positions_per_workload_second", report)


if __name__ == "__main__":
    unittest.main()
