"""Synthetic accounting tests; no GPU, proving binary or model is executed."""
from contextlib import nullcontext
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch


SPEC = importlib.util.spec_from_file_location("hashline_profile", Path(__file__).resolve().parents[1] / "scripts/hashline_profile.py")
profile = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(profile)


def fixture(privacy="P1", layers=1, include_run=True):
    timing = {"schema": 1, "coverage": "ffn-only", "privacy": privacy,
              "layers": layers, "tokens": 16, "d": 768, "f": 2048,
              "witness_s": 5.0 * layers, "prove_s": 2.0 * layers,
              "serialize_s": .1, "proof_ready_s": 7.4 * layers, "verify_s": .2,
              "verified": True, "serialized": True, "proof_bytes": 16,
              "gpu_requested": False, "gpu_enabled": False, "randomness": "os"}
    records = []
    for layer in range(layers):
        records.append({"schema": 1, "coverage": "ffn-only", "privacy": privacy, "layer": layer,
                        "tokens": 16, "d": 768, "f": 2048, "witness_s": 5., "prove_s": 2.,
                        "witness_exclusive": [{"phase": name, "seconds": value, "calls": 1} for name, value in
                                              (("read.export_including_buffer_allocation", .6), ("hash.sha256", .4),
                                               ("matmul.gate", 1.), ("matmul.up", 1.), ("matmul.down", 1.), ("copy.clone_witness", .5))],
                        "prover_sequential": [{"phase": "commit W", "seconds": 1.}, {"phase": "helpers + commit H", "seconds": .5}],
                        "device_counters_included": False, "private_timing_diagnostics": True})
    return timing, records, {"exit_code": 0, "process_wall_s": 8. * layers} if include_run else None


def log(timing=None, profiles=None, run=None, *, values=None):
    if values is None:
        values = fixture()
    timing = values[0] if timing is None else timing
    profiles = values[1] if profiles is None else profiles
    run = values[2] if run is None else run
    text = "PASS-V3 ACCEPT [ZK]: fixture\nHASHLINE_TIMING " + json.dumps(timing) + "\n"
    text += "".join("HASHLINE_PROFILE " + json.dumps(record) + "\n" for record in profiles)
    if run is not None:
        text += "HASHLINE_PROFILE_RUN " + json.dumps(run) + "\n"
    return text


class ProfileTests(unittest.TestCase):
    def test_exclusive_rank_conserves_clock_and_exposes_unknown_cost(self):
        result = profile.analyze_log(log())
        self.assertAlmostEqual(sum(row["seconds"] for row in result["exclusive_ranked"]), 7.4)
        self.assertAlmostEqual(result["unknown_within_proof_ready_s"], 1.3)
        self.assertAlmostEqual(result["outside_proof_ready_and_verify_s"], .4)
        self.assertFalse(result["goal_met"])
        self.assertEqual(result["shape"]["tokens"], 16)

    def test_multiple_layers_are_added_once(self):
        result = profile.analyze_log(log(values=fixture(layers=2)))
        self.assertAlmostEqual(sum(row["seconds"] for row in result["exclusive_ranked"]), 14.8)
        costs = {row["phase"]: row["seconds"] for row in result["exclusive_ranked"]}
        self.assertEqual(costs["witness.matmul.gate"], 2.)
        self.assertEqual(costs["prover.commit W"], 2.)

    def test_missing_duplicate_or_unknown_profile_fails_cleanly(self):
        timing, profiles, run = fixture()
        for records in ([], profiles + profiles, [{**profiles[0], "layer": 9}], [{**profiles[0], "tensor_digest": "secret"}]):
            with self.subTest(records=records), self.assertRaises(ValueError):
                profile.analyze_log(log(timing, records, run))
        with self.assertRaises(ValueError):
            profile.analyze_log(log() + "HASHLINE_TIMING {}\n")

    def test_cpu_and_exclusive_declarations_are_required(self):
        timing, profiles, run = fixture()
        for key in ("gpu_enabled", "gpu_requested"):
            with self.subTest(key=key), self.assertRaises(ValueError):
                profile.analyze_log(log({**timing, key: True}, profiles, run))
        for key in ("device_counters_included", "private_timing_diagnostics"):
            changed = [{**profiles[0], key: not profiles[0][key]}]
            with self.subTest(key=key), self.assertRaises(ValueError):
                profile.analyze_log(log(timing, changed, run))

    def test_negative_overlap_and_mismatched_enclosing_clocks_reject(self):
        timing, profiles, run = fixture()
        for changes in ({"witness_s": 4}, {"prove_s": 1}, {"witness_s": 7}, {"privacy": "P3"}, {"tokens": 32}):
            with self.subTest(changes=changes), self.assertRaises(ValueError):
                profile.analyze_log(log(timing, [{**profiles[0], **changes}], run))
        with self.assertRaises(ValueError):
            profile.analyze_log(log({**timing, "proof_ready_s": 6}, profiles, run))

    def test_malformed_numeric_fields_reject_without_type_errors(self):
        timing, profiles, run = fixture()
        for value in (None, "2", [], {}, True, -1, float("nan"), float("inf"), 10**400):
            with self.subTest(value=str(value)[:30]), self.assertRaises(ValueError):
                profile.analyze_log(log({**timing, "witness_s": value}, profiles, run))
        for text in ("HASHLINE_TIMING {", "HASHLINE_TIMING null", "HASHLINE_PROFILE_RUN []"):
            with self.subTest(text=text), self.assertRaises(ValueError):
                profile.analyze_log(text)

    def test_unknown_labels_are_not_echoed_as_private_values(self):
        timing, profiles, run = fixture()
        profiles[0]["witness_exclusive"][0]["phase"] = "private-tensor-value-123"
        with self.assertRaises(ValueError) as failure:
            profile.analyze_log(log(timing, profiles, run))
        self.assertNotIn("private-tensor-value-123", str(failure.exception))

    def test_failed_or_unverified_or_incomplete_run_rejects(self):
        timing, profiles, run = fixture()
        bad = [log({**timing, "verified": False}, profiles, run), log(timing, profiles, {**run, "exit_code": 1}),
               log() + "command --no-verify", log() + "\nthread main panicked at failure\n",
               log(values=fixture(include_run=False))]
        for text in bad:
            with self.subTest(text=text), self.assertRaises(ValueError):
                profile.analyze_log(text)

    def test_analyzer_keeps_privacy_groups_separate(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            paths = []
            for privacy in ("P0", "P1", "P3"):
                path = root / f"{privacy}.log"
                path.write_text(log(values=fixture(privacy=privacy)))
                paths.append(str(path))
            with patch.object(profile, "metadata", return_value={"source": "fixture"}), patch.object(profile.subprocess, "run", side_effect=AssertionError("unexpected process")):
                self.assertEqual(profile.main(["analyze", "--source-tree", str(root), "--binary", "fixture", "--logs", *paths, "--out", str(root / "out")]), 0)
            report = json.loads((root / "out/summary.json").read_text())
            self.assertEqual(len(report["groups"]), 3)
            self.assertFalse(report["goal_met"])
            self.assertEqual((root / "out").stat().st_mode & 0o777, 0o700)

    def test_bounded_runner_checks_profile_on_off_proof_identity(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            export = root / "export"
            export.mkdir()
            (export / "digests.txt").write_text("00 dims 512 768 2048 12\n")
            def fake_run(command, **kwargs):
                self.assertNotIn("HL_GPU", kwargs["env"])
                self.assertEqual(kwargs["env"]["RAYON_NUM_THREADS"], "2")
                self.assertEqual(kwargs["timeout"], 120)
                self.assertEqual(command[1:4], ["pass", "1", "16"])
                Path(command[command.index("--proof-out") + 1]).write_bytes(bytes(16))
                values = fixture(privacy="P0", include_run=False)
                kwargs["stdout"].write(log(values=values, profiles=values[1] if "--phase-profile" in command else []))
                return subprocess.CompletedProcess(command, 0)
            with patch.object(profile, "metadata", return_value={"source": "fixture"}), patch.object(profile, "heavy_lock", nullcontext), patch.object(profile.time, "perf_counter", side_effect=[0, 8]), patch.object(profile.subprocess, "run", side_effect=fake_run) as process:
                status = profile.main(["run", "--source-tree", str(root), "--binary", "fixture", "--export", str(export), "--privacy", "P0", "--rows", "16", "--compare-unprofiled", "--out", str(root / "out")])
            self.assertEqual(status, 0)
            self.assertEqual(process.call_count, 2)
            workload = json.loads((root / "out/workload.json").read_text())
            self.assertEqual(workload["export_shape"], {"tokens": 512, "d": 768, "f": 2048, "layers": 12})
            self.assertTrue(workload["full_export_reference_planes_read"])
            commands = json.loads((root / "out/rows-16-command.json").read_text())
            self.assertEqual(commands["environment_enforced"], {"HL_GPU": "unset", "RAYON_NUM_THREADS": "2"})
            self.assertEqual(commands["written_proof_sha256"], commands["unprofiled_proof_sha256"])
            result = json.loads((root / "out/summary.json").read_text())
            self.assertTrue(next(iter(result["groups"].values()))[0]["profile_on_off_byte_identical"])

    def test_runner_timeout_leaves_ineligible_raw_completion(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            export = root / "export"
            export.mkdir()
            (export / "digests.txt").write_text("00 dims 512 768 2048 12\n")
            with patch.object(profile, "metadata", return_value={}), patch.object(profile, "heavy_lock", nullcontext), patch.object(profile.time, "perf_counter", side_effect=[0, 120]), patch.object(profile.subprocess, "run", side_effect=subprocess.TimeoutExpired("fixture", 120)):
                with self.assertRaises(SystemExit) as failure:
                    profile.main(["run", "--source-tree", str(root), "--binary", "fixture", "--export", str(export), "--privacy", "P0", "--rows", "16", "--out", str(root / "out")])
            self.assertEqual(failure.exception.code, 2)
            self.assertIn('"exit_code": "timeout"', (root / "out/rows-16.log").read_text())
            self.assertFalse((root / "out/summary.json").exists())
            self.assertTrue((root / "out/rows-16-command.json").is_file())


if __name__ == "__main__":
    unittest.main()
