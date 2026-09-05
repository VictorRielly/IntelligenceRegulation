"""Log fixtures exercise benchmark accounting without GPUs, datasets or binaries."""

import importlib.util
from contextlib import contextmanager, nullcontext
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import call, mock_open, patch


SPEC = importlib.util.spec_from_file_location("hashline_benchmark", Path(__file__).resolve().parents[1] / "scripts/hashline_benchmark.py")
bench = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(bench)


def fixture(privacy="P1", gpu=True, timing=True, **changes):
    zk = f" [ZK, mode {privacy}, randomness os]" if privacy != "P0" else ""
    suffix = " [ZK]" if privacy != "P0" else ""
    label = "gpu: ON — example (sm_120, 170 SMs, 34.4 GB)" if gpu else "gpu: off (HL_GPU unset; built with gpu-cuda)"
    record = {"schema": 1, "coverage": "ffn-only", "privacy": privacy, "layers": 32,
              "tokens": 512, "d": 4096, "f": 14336, "witness_s": 1.0, "prove_s": 2.0,
              "serialize_s": .2, "proof_ready_s": 3.3, "verify_s": .5, "verified": True,
              "serialized": True, "proof_bytes": 256, "gpu_requested": gpu, "gpu_enabled": gpu,
              "randomness": "os" if privacy != "P0" else "none"}
    record.update(changes)
    log = (f"pass (v3){zk}: 32 layers x 512 tokens of 512 — export (d 4096 f 14336; log_cols 14, inv_rate 4, col checks 256, threads 8)\n"
           f"  {label}\nPROOF sha256 {'a' * 64} (256 B){suffix}\n"
           f"PASS-V3 ACCEPT{suffix}: 32 x 512 (d 4096 f 14336): witness load+chain 1.00 s | PROVE 2.00 s | VERIFY 0.50 s | proof 256 B (0.0 MB) | 1.0e12 MACs | 1.0e10 proven MAC/s (prove wall) | wall 3.80 s\n"
           "  Exit status: 0\n")
    if timing:
        log += "HASHLINE_TIMING " + json.dumps(record) + "\n"
    return log


def parse(log, **kwargs):
    return bench.parse_log(log, privacy=kwargs.get("privacy", "P1"),
                           coverage="ffn-only", device=kwargs.get("device", "gpu"))


class AccountingTests(unittest.TestCase):
    def setUp(self):
        self.real_heavy_lock = bench.heavy_lock
        lock_patch = patch.object(bench, "heavy_lock", nullcontext)
        lock_patch.start()
        self.addCleanup(lock_patch.stop)

    def test_record_preserves_separate_clocks(self):
        row = parse(fixture())
        self.assertTrue(row["measurement_eligible"], row["errors"])
        self.assertEqual(row["timing"]["proof_ready_s"], 3.3)
        self.assertEqual(row["prove_s"], 2)
        self.assertIsNone(row["process_wall_s"])
        self.assertFalse(row["goal_met"])

    def test_legacy_prove_is_not_end_to_end(self):
        row = parse(fixture(timing=False))
        self.assertFalse(row["measurement_eligible"])
        self.assertIsNone(row["timing"])
        self.assertNotIn("prefill_rows_per_proof_ready_second", row)
        self.assertEqual(row["legacy_pass_wall_s"], 3.8)
        self.assertEqual(row["proof_bytes"], 256)

    def test_verified_boolean_required_even_if_accept(self):
        for log in (fixture(verified=False), fixture() + "command --no-verify\n", fixture(verify_s=0)):
            with self.subTest(log=log):
                self.assertFalse(parse(log)["measurement_eligible"])

    def test_gpu_fallback_invalidates_accept(self):
        for diagnostic in ("gpu: off (init failed)", "[GPU] streamed commit declined (OOM); block upload", "GPU fallback to host"):
            with self.subTest(diagnostic=diagnostic):
                row = parse(fixture() + diagnostic + "\n")
                self.assertFalse(row["measurement_eligible"])
        self.assertFalse(parse(fixture(gpu=False))["measurement_eligible"])
        self.assertFalse(parse(fixture(gpu_enabled=False))["measurement_eligible"])

    def test_cpu_and_p3_identity(self):
        row = parse(fixture(privacy="P3", gpu=False), privacy="P3", device="cpu")
        self.assertTrue(row["measurement_eligible"], row["errors"])
        self.assertFalse(parse(fixture(privacy="P3"))["measurement_eligible"])

    def test_failures_missing_proof_and_multiple_passes(self):
        cases = [fixture() + "Exit status: 9\n", fixture() + "thread 'main' panicked at OOM\n",
                 fixture().replace("PROOF sha256", "no proof"), fixture().replace("(256 B)", "(255 B)"),
                 fixture() + fixture(), fixture().replace("32 x 512", "31 x 512"),
                 fixture().replace("(d 4096 f 14336):", "(d 1024 f 4096):"),
                 fixture(serialized=False), fixture() + " MODE P3 (full tier)\n"]
        for log in cases:
            with self.subTest(log=log):
                self.assertFalse(parse(log)["measurement_eligible"])

    def test_nonfinite_or_incomplete_timing_rejected(self):
        for change in ({"prove_s": float("nan")}, {"proof_ready_s": -1}, {"proof_ready_s": 2.2},
                       {"verify_s": True}, {"schema": True}, {"serialized": 1},
                       {"randomness": "deterministic-test"}, {"prove_s": 100}):
            with self.subTest(change=change):
                self.assertFalse(parse(fixture(**change))["measurement_eligible"])

    def test_malformed_json_and_non_object(self):
        for value in ("{", "null", "[]", "5"):
            row = parse(fixture(timing=False) + "HASHLINE_TIMING " + value + "\n")
            self.assertFalse(row["measurement_eligible"])

    def test_high_resolution_verification_can_be_sub_centisecond(self):
        log = fixture(verify_s=.001).replace("VERIFY 0.50", "VERIFY 0.00")
        self.assertTrue(parse(log)["measurement_eligible"])

    def test_process_wall_distinct_and_exit_metadata(self):
        log = fixture().replace("  Exit status: 0\n", "")
        self.assertFalse(parse(log)["measurement_eligible"])
        row = parse(log + 'HASHLINE_BENCHMARK_RUN {"process_wall_s": 9, "exit_code": 0}\n')
        self.assertTrue(row["measurement_eligible"], row["errors"])
        self.assertEqual(row["process_wall_s"], 9)
        self.assertEqual(row["timing"]["proof_ready_s"], 3.3)

    def test_twenty_warm_runs_nearest_rank_and_cold_separation(self):
        rows = []
        for n in range(20):
            row = parse(fixture(proof_ready_s=4 + n))
            row["sample_kind"] = "warm"
            rows.append(row)
        cold = parse(fixture(proof_ready_s=999))
        cold["sample_kind"] = "cold"
        report = bench.summarize([cold] + rows, "P1", "ffn-only", "gpu")
        self.assertTrue(report["measurement_eligible"], report["ineligible_reasons"])
        self.assertEqual(report["warm_metrics"]["proof_ready_s"]["p50"], 13)
        self.assertEqual(report["warm_metrics"]["proof_ready_s"]["p95"], 22)
        self.assertFalse(report["goal_met"])
        self.assertFalse(bench.summarize([cold] + rows[:-1], "P1", "ffn-only", "gpu")["measurement_eligible"])

    def test_mixed_cohort_and_single_invalid_sample(self):
        cold = parse(fixture())
        cold["sample_kind"] = "cold"
        rows = [cold]
        for _ in range(20):
            row = parse(fixture())
            row["sample_kind"] = "warm"
            rows.append(row)
        self.assertTrue(bench.summarize(rows, "P1", "ffn-only", "gpu")["measurement_eligible"])
        rows[-1]["d"] = 1024
        self.assertFalse(bench.summarize(rows, "P1", "ffn-only", "gpu")["measurement_eligible"])
        rows[-1]["d"] = 4096
        rows[-1]["measurement_eligible"] = False
        self.assertFalse(bench.summarize(rows, "P1", "ffn-only", "gpu")["measurement_eligible"])

    def test_no_cold_sample_cannot_qualify_with_twenty_warm_runs(self):
        warm = dict(parse(fixture()), sample_kind="warm")
        report = bench.summarize([warm] * 20, "P1", "ffn-only", "gpu")
        self.assertFalse(report["measurement_eligible"])
        self.assertEqual(report["cold_count"], 0)
        self.assertIn("exactly one separate cold sample required", report["ineligible_reasons"])

    def test_multiple_cold_samples_cannot_qualify_with_twenty_warm_runs(self):
        warm = dict(parse(fixture()), sample_kind="warm")
        cold = dict(parse(fixture()), sample_kind="cold")
        report = bench.summarize([cold, cold] + [warm] * 20, "P1", "ffn-only", "gpu")
        self.assertFalse(report["measurement_eligible"])
        self.assertEqual(report["cold_count"], 2)
        self.assertIn("exactly one separate cold sample required", report["ineligible_reasons"])

    def test_analyze_archives_logs_and_does_not_spawn_processes(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            log = root / "source.log"
            log.write_text(fixture(timing=False))
            with patch.object(bench.subprocess, "run", side_effect=AssertionError("unexpected subprocess")):
                self.assertEqual(bench.main(["analyze", "--privacy", "P1", "--device", "gpu", "--cold", str(log), "--out", str(root / "report")]), 0)
            report = json.loads((root / "report/summary.json").read_text())
            self.assertFalse(report["measurement_eligible"])
            self.assertEqual((root / "report/cold-000.log").read_bytes(), log.read_bytes())

    def test_archived_gnu_time_clock_remains_process_wall(self):
        log = fixture(timing=False) + "\tElapsed (wall clock) time (h:mm:ss or m:ss): 1:02:03.40\n"
        row = parse(log)
        self.assertAlmostEqual(row["process_wall_s"], 3723.4)
        self.assertIsNone(row["timing"])

    def test_duplicate_copied_log_cannot_inflate_sample_count(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            first, second = root / "one.log", root / "two.log"
            first.write_text(fixture())
            second.write_text(fixture())
            with self.assertRaises(SystemExit) as error:
                bench.main(["analyze", "--privacy", "P1", "--device", "gpu", "--warm", str(first), str(second), "--out", str(root / "report")])
            self.assertEqual(error.exception.code, 2)
            self.assertFalse((root / "report").exists())

    def test_runner_records_fresh_cpu_run_and_retains_proof_without_executing_binary(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            binary, export = root / "not-executed", root / "export"
            binary.write_bytes(b"binary fixture")
            export.mkdir()
            (export / "digests.txt").write_text("00 profile v3-widened\n00 dims 512 4096 14336 32\n")
            def fake_run(command, **kwargs):
                self.assertNotIn("--seed", command)
                self.assertNotIn("HL_GPU", kwargs["env"])
                self.assertIn("--zk", command)
                self.assertIn("--wcache", command)
                proof = bytes(256)
                Path(command[command.index("--proof-out") + 1]).write_bytes(proof)
                kwargs["stdout"].write(fixture(gpu=False).replace("a" * 64, hashlib.sha256(proof).hexdigest()))
                return subprocess.CompletedProcess(command, 0)
            with patch.object(bench.subprocess, "run", side_effect=fake_run) as process:
                self.assertEqual(bench.main(["run", "--binary", str(binary), "--export", str(export), "--privacy", "P1", "--device", "cpu", "--warm-runs", "0", "--out", str(root / "report")]), 0)
            self.assertEqual(process.call_count, 1)
            report = json.loads((root / "report/summary.json").read_text())
            self.assertTrue(report["samples"][0]["measurement_eligible"])
            self.assertFalse(report["measurement_eligible"])
            self.assertEqual((root / "report/last.proof").stat().st_size, 256)
            manifest = json.loads((root / "report/manifest.json").read_text())
            self.assertEqual(manifest["system"]["prover_threads"], 8)
            self.assertTrue(manifest["system"]["cpu"])
            self.assertEqual(manifest["lock"], "/tmp/zk-heavy.lock")

    def test_runner_stops_after_failed_sample_and_returns_nonzero(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            binary, export = root / "not-executed", root / "export"
            binary.write_bytes(b"binary fixture")
            export.mkdir()
            (export / "digests.txt").write_text("00 profile v3-widened\n00 dims 512 4096 14336 32\n")
            def failed_run(command, **kwargs):
                kwargs["stdout"].write("error: allocation failed\n")
                return subprocess.CompletedProcess(command, 1)
            with patch.object(bench.subprocess, "run", side_effect=failed_run) as process:
                self.assertEqual(bench.main(["run", "--binary", str(binary), "--export", str(export), "--privacy", "P3", "--device", "cpu", "--out", str(root / "report")]), 1)
            self.assertEqual(process.call_count, 1)
            report = json.loads((root / "report/summary.json").read_text())
            self.assertFalse(report["measurement_eligible"])
            self.assertIn("nonzero process exit", report["samples"][0]["errors"])

    def test_preflight_refuses_laptop_private_8b_before_running_binary(self):
        result = subprocess.CompletedProcess([], 0, "Laptop, GPU-1, 8188, 8000, 590\n", "")
        with patch.object(bench.subprocess, "run", return_value=result) as run:
            with self.assertRaisesRegex(ValueError, "at least 16 GiB"):
                bench.gpu_preflight(0, 4096, "P3")
            self.assertEqual(run.call_count, 1)
            self.assertEqual(run.call_args.args[0][0], "nvidia-smi")
            self.assertEqual(bench.gpu_preflight(0, 1024, "P1")["total_mib"], 8188)

    def test_preflight_large_gpu_and_ambiguous_devices(self):
        result = subprocess.CompletedProcess([], 0, "5090, GPU-2, 32768, 32000, 595\n", "")
        with patch.object(bench.subprocess, "run", return_value=result):
            self.assertEqual(bench.gpu_preflight(0, 4096, "P1")["total_mib"], 32768)
            result.stdout += result.stdout
            with self.assertRaisesRegex(ValueError, "exactly one"):
                bench.gpu_preflight(0, 4096, "P1")

    def test_shared_lock_unlocks_on_exception_without_unlink(self):
        opened = mock_open()
        with patch("builtins.open", opened), patch.object(bench.fcntl, "flock") as flock:
            with self.assertRaisesRegex(RuntimeError, "fixture"):
                with self.real_heavy_lock():
                    self.assertEqual(flock.call_args, call(opened.return_value.fileno(), bench.fcntl.LOCK_EX))
                    raise RuntimeError("fixture")
        opened.assert_called_once_with("/tmp/zk-heavy.lock", "a")
        self.assertEqual(flock.call_args_list, [call(opened.return_value.fileno(), bench.fcntl.LOCK_EX), call(opened.return_value.fileno(), bench.fcntl.LOCK_UN)])

    def test_private_large_gpu_refuses_busy_device(self):
        result = subprocess.CompletedProcess([], 0, "5090, GPU-2, 32768, 30000, 595\n", "")
        with patch.object(bench.subprocess, "run", return_value=result):
            with self.assertRaisesRegex(ValueError, "GPU busy"):
                bench.gpu_preflight(0, 4096, "P3")
            self.assertEqual(bench.gpu_preflight(0, 4096, "P3", enforce=False)["free_mib"], 30000)
            result.stdout = "5090, GPU-2, 32768, 31744, 595\n"
            self.assertEqual(bench.gpu_preflight(0, 4096, "P1")["free_mib"], 31744)

    def test_invalid_inputs_rejected_before_binary_or_gpu_query(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            binary, export = root / "not-executed", root / "export"
            binary.write_bytes(b"binary fixture")
            export.mkdir()
            (export / "digests.txt").write_text("00 profile v3-widened\n00 dims 512 4096 14336 32\n")
            base = ["run", "--binary", str(binary), "--export", str(export), "--privacy", "P1", "--device", "gpu", "--out", str(root / "report")]
            for options in (["--tokens", "0"], ["--tokens", "-1"], ["--tokens", "3"], ["--layers", "0"],
                            ["--layers", "-1"], ["--seed", "-1"], ["--seed", str(2**64)]):
                with self.subTest(options=options), patch.object(bench.subprocess, "run", side_effect=AssertionError("unexpected subprocess")):
                    with self.assertRaises(SystemExit) as error:
                        bench.main(base + options)
                    self.assertEqual(error.exception.code, 2)
            (export / "digests.txt").write_text("00 profile v3-widened\n00 dims 512 0 14336 32\n")
            with self.assertRaises(SystemExit) as error:
                bench.main(base)
            self.assertEqual(error.exception.code, 2)
            self.assertFalse((root / "report").exists())

    def test_truncated_binary_shape_is_not_accepted(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            binary, export = root / "not-executed", root / "export"
            binary.write_bytes(b"binary fixture")
            export.mkdir()
            (export / "digests.txt").write_text("00 profile v3-widened\n00 dims 512 4096 14336 33\n")
            def truncated_run(command, **kwargs):
                proof = bytes(256)
                Path(command[command.index("--proof-out") + 1]).write_bytes(proof)
                kwargs["stdout"].write(fixture(gpu=False).replace("a" * 64, hashlib.sha256(proof).hexdigest()))
                return subprocess.CompletedProcess(command, 0)
            with patch.object(bench.subprocess, "run", side_effect=truncated_run):
                status = bench.main(["run", "--binary", str(binary), "--export", str(export), "--layers", "33", "--privacy", "P1", "--device", "cpu", "--warm-runs", "0", "--out", str(root / "report")])
            self.assertEqual(status, 1)
            report = json.loads((root / "report/summary.json").read_text())
            self.assertIn("observed layers differs from requested manifest", report["samples"][0]["errors"])

    def test_gpu_rechecked_each_sample_under_lock_and_busy_sample_recorded(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            binary, export = root / "not-executed", root / "export"
            binary.write_bytes(b"binary fixture")
            export.mkdir()
            (export / "digests.txt").write_text("00 profile v3-widened\n00 dims 512 4096 14336 32\n")
            events = []
            @contextmanager
            def locking():
                events.append("locked")
                yield
                events.append("unlocked")
            def preflight(*args, **kwargs):
                self.assertEqual(events[0], "locked")
                self.assertNotIn("unlocked", events)
                events.append("gpu")
                free = 30000 if events.count("gpu") == 3 else 32000
                return {"name": "5090", "uuid": "GPU-2", "total_mib": 32768, "free_mib": free, "driver": "595"}
            def fake_run(command, **kwargs):
                proof = bytes(256)
                Path(command[command.index("--proof-out") + 1]).write_bytes(proof)
                kwargs["stdout"].write(fixture().replace("a" * 64, hashlib.sha256(proof).hexdigest()))
                return subprocess.CompletedProcess(command, 0)
            with patch.object(bench, "heavy_lock", locking), patch.object(bench, "gpu_preflight", side_effect=preflight), patch.object(bench.subprocess, "run", side_effect=fake_run) as process:
                status = bench.main(["run", "--binary", str(binary), "--export", str(export), "--privacy", "P1", "--device", "gpu", "--warm-runs", "2", "--out", str(root / "report")])
            self.assertEqual(status, 1)
            self.assertEqual(process.call_count, 1)
            self.assertEqual(events[-1], "unlocked")
            report = json.loads((root / "report/summary.json").read_text())
            self.assertEqual(report["samples"][0]["gpu_before"]["free_mib"], 32000)
            self.assertEqual(report["samples"][1]["gpu_before"]["free_mib"], 30000)
            self.assertIn("GPU busy", (root / "report/warm-001.log").read_text())

    def test_malformed_numeric_timings_always_produce_serializable_ineligible_reports(self):
        record = json.loads(fixture().split("HASHLINE_TIMING ")[1])
        del record["prove_s"]
        logs = [fixture(prove_s=value) for value in (None, "oops", [], {}, True, 10**400)]
        logs += [fixture(proof_ready_s=1e-320), fixture().replace('"prove_s": 2.0', '"prove_s": 1e999'),
                 fixture(timing=False) + "HASHLINE_TIMING " + json.dumps(record) + "\n",
                 fixture().replace("PROVE 2.00", "PROVE ...")]
        for log in logs:
            with self.subTest(log=log):
                row = parse(log)
                row["sample_kind"] = "warm"
                report = bench.summarize([row], "P1", "ffn-only", "gpu")
                self.assertFalse(report["measurement_eligible"])
                json.dumps(report, allow_nan=False)

    def test_zero_or_negative_logged_shape_cannot_be_eligible(self):
        for value in (0, -1):
            with self.subTest(value=value):
                log = fixture(layers=value).replace("32 layers", f"{value} layers").replace("32 x 512", f"{value} x 512")
                self.assertFalse(parse(log)["measurement_eligible"])


if __name__ == "__main__":
    unittest.main()
