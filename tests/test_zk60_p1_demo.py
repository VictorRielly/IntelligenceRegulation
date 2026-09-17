"""Orchestration controls for the P1 FFN component demo.

The Rust example is replaced by a process double: these tests cover the
script's failure semantics, output preservation and manifest, NOT the prover.
A run against the real binary is a separate, still outstanding step.
"""
from contextlib import redirect_stderr, redirect_stdout
import hashlib
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
import zk60_p1_demo as D

WEIGHT_ROOT = hashlib.sha256(b"public weights").hexdigest()
ARTIFACT = {"reason": "compiler-artifact",
            "target": {"name": "zk60_bound_ffn", "kind": ["example"]}}


class FakeExample:
    """Stands in for hashline/examples/zk60_bound_ffn.rs and for cargo."""

    def __init__(self, binary):
        self.binary, self.calls, self.envs = str(binary), [], []
        self.receipt = hashlib.sha256(b"receipt").digest() * 8
        self.policy = self.context = None
        self.always_accept = False
        self.prepare_stdout = self.policy_context = self.wire_bytes = None
        self.rejection_stdout, self.rejection_stderr = "", "FFN IO: refused\n"
        self.cargo_exit, self.cargo_stdout = 0, None

    def __call__(self, command, cwd, env, timeout):
        self.calls.append(list(command))
        self.envs.append(dict(env))
        if command[1] == "build":
            return self.cargo()
        args, cwd = command[1:], Path(cwd)
        if args == ["prepare"]:
            if self.prepare_stdout is not None:
                return 0, self.prepare_stdout, ""
            return 0, json.dumps({"public_weight_root": WEIGHT_ROOT,
                                  "proving_executed": False}), ""
        if args[:2] == ["prove", "p1"] and len(args) == 5:
            return self.prove(args[2], cwd / args[3], cwd / args[4])
        if args[:2] == ["verify", "p1"] and len(args) == 6:
            return self.verify(args[2], args[3], cwd / args[4], cwd / args[5])
        return 1, "", "usage: zk60_bound_ffn prepare | prove | verify\n"

    def cargo(self):
        if self.cargo_stdout is not None or self.cargo_exit != 0:
            return self.cargo_exit, self.cargo_stdout or "", "error\n"
        message = dict(ARTIFACT, executable=self.binary)
        return 0, "{\"reason\":\"build-script-executed\"}\n" + json.dumps(message) + "\n", ""

    def prove(self, context, policy_path, receipt_path):
        if policy_path.exists() or receipt_path.exists():
            return 1, "", "create new artifact: File exists (os error 17)\n"
        roots = [hashlib.sha256(tag + bytes.fromhex(context)).digest() for tag in (b"in", b"out")]
        self.policy = (b"HFFNEXP1" + bytes.fromhex(self.policy_context or context)
                       + (-3).to_bytes(4, "little", signed=True)
                       + (0).to_bytes(4, "little", signed=True) + roots[0] + roots[1])
        policy_path.write_bytes(self.policy)
        receipt_path.write_bytes(self.receipt)
        self.context = context
        return 0, json.dumps({"mode": "P1", "wire_bytes": self.wire_bytes or len(self.receipt),
                              "policy_saved_before_proving": True, "verified_from_bytes": True,
                              "input_root": roots[0].hex(), "output_root": roots[1].hex()}), ""

    def verify(self, root, context, policy_path, receipt_path):
        try:
            accept = (root == WEIGHT_ROOT and context == self.context
                      and policy_path.read_bytes() == self.policy
                      and receipt_path.read_bytes() == self.receipt)
        except OSError:
            accept = False
        if accept or self.always_accept:
            return 0, json.dumps({"mode": "P1", "wire_bytes": len(self.receipt),
                                  "verified_from_bytes": True, "proving_executed": False}), ""
        return 1, self.rejection_stdout, self.rejection_stderr


def intercept(fake, index, action):
    """Replace the reply to the index-th call (1-based) with action."""
    def replacement(command, cwd, env, timeout):
        replacement.seen += 1
        if replacement.seen == index:
            fake.calls.append(list(command))
            if isinstance(action, Exception):
                raise action
            return action
        return fake(command, cwd, env, timeout)
    replacement.seen = 0
    return replacement


class DemoCase(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp(prefix="zk60-p1-demo-"))
        self.addCleanup(shutil.rmtree, self.tmp, ignore_errors=True)
        self.binary = self.tmp / "zk60_bound_ffn"
        self.binary.write_bytes(b"not a real prover")
        self.fake = FakeExample(self.binary)

    def demo(self, launcher=None, extra=(), out="out"):
        out = self.tmp / out
        argv = ["--output", str(out), "--binary", str(self.binary), *extra]
        with mock.patch.object(D, "launch", launcher or self.fake):
            with redirect_stdout(io.StringIO()) as done, redirect_stderr(io.StringIO()) as bad:
                code = D.main(argv)
        return code, out, done.getvalue(), bad.getvalue()

    def manifest(self, out):
        return json.loads((out / "manifest.json").read_text())

    def failed(self, code, out, needle, step=None):
        self.assertEqual(code, 1)
        record = self.manifest(out)
        self.assertEqual(record["status"], "failed")
        self.assertIn(needle, record["failure"]["reason"])
        if step is not None:
            self.assertEqual(record["failure"]["step"], step)
        return record


class SuccessfulRun(DemoCase):
    def test_run_proves_verifies_and_rejects(self):
        code, out, done, _ = self.demo()
        self.assertEqual(code, 0)
        record = self.manifest(out)
        self.assertEqual(record["status"], "passed")
        self.assertEqual(json.loads(done)["status"], "passed")
        names = [step["name"] for step in record["steps"]]
        self.assertEqual(names[:3], ["register_public_weights", "prove_p1", "verify_p1"])
        self.assertEqual(record["rejection_controls"],
                         ["reject_wrong_context", "reject_wrong_public_weight",
                          "reject_wrong_endpoint_policy", "reject_tampered_receipt",
                          "reject_truncated_receipt", "reject_trailing_receipt"])
        self.assertTrue(all(step["exit_code"] == step["expected_exit"] for step in record["steps"]))
        self.assertTrue(all("seconds" in step for step in record["steps"]))

    def test_registration_precedes_proving_and_supplies_the_verified_root(self):
        _, out, _, _ = self.demo()
        record = self.manifest(out)
        self.assertEqual(record["steps"][0]["stdout_json"]["proving_executed"], False)
        self.assertEqual(record["public_weight_root"]["value"], WEIGHT_ROOT)
        self.assertFalse(record["verification"]["policy_derived_from_candidate_receipt"])
        verify = record["steps"][2]["command"]
        self.assertEqual(verify[3], WEIGHT_ROOT)
        self.assertEqual(verify[4], record["caller_context"]["value"])

    def test_context_is_fresh_os_randomness_per_run(self):
        seen = set()
        for name in ("a", "b"):
            _, out, _, _ = self.demo(out=name)
            record = self.manifest(out)
            context = record["caller_context"]["value"]
            self.assertEqual(len(context), 64)
            bytes.fromhex(context)
            seen.add(context)
            wrong = record["steps"][3]["command"][4]
            self.assertNotEqual(wrong, context)
            self.fake = FakeExample(self.binary)
        self.assertEqual(len(seen), 2)

    def test_artifacts_are_hashed_and_left_untouched(self):
        _, out, _, _ = self.demo()
        record = self.manifest(out)
        by_name = {a["name"]: a for a in record["artifacts"]}
        self.assertEqual(sorted(by_name), ["endpoint_policy", "receipt", "tampered_receipt",
                                           "trailing_receipt", "truncated_receipt",
                                           "wrong_endpoint_policy"])
        receipt = (out / "p1.receipt").read_bytes()
        self.assertEqual(by_name["receipt"]["sha256"], hashlib.sha256(receipt).hexdigest())
        self.assertEqual(receipt, self.fake.receipt)
        self.assertEqual((out / "p1.expected").read_bytes(), self.fake.policy)
        self.assertEqual(by_name["endpoint_policy"]["bytes"], 112)
        self.assertNotEqual(by_name["tampered_receipt"]["sha256"], by_name["receipt"]["sha256"])

    def test_status_claims_stay_negative_and_coverage_is_explicit(self):
        _, out, _, _ = self.demo()
        record = self.manifest(out)
        self.assertEqual(record["status_claims"], {
            "component_demo_only": True, "full_private_block": False, "mvp": False,
            "privacy_review_complete": False, "whole_proof_zero_knowledge_established": False})
        missing = json.dumps(record["coverage"]["does_not_cover"])
        self.assertIn("whole-proof zero knowledge", missing)
        self.assertIn("MVP", missing)
        self.assertIn("P3 weight privacy", missing)
        self.assertNotIn("benchmark", json.dumps(record["coverage"]["covers"]))
        self.assertIn("not a benchmark", record["timing_note"])

    def test_paths_in_the_manifest_are_portable(self):
        _, out, _, _ = self.demo()
        text = json.dumps(self.manifest(out))
        self.assertNotIn(str(out), text)
        self.assertIn("<output>/p1.receipt", text)

    def test_no_p3_mode_and_no_hl_environment_reaches_the_child(self):
        with mock.patch.dict(os.environ, {"HL_GPU": "1", "HL_FIXTURE_SEED": "7"}):
            _, out, _, _ = self.demo()
        for command in self.fake.calls:
            self.assertNotIn("p3", command)
            self.assertNotIn("fresh", command)
        for env in self.fake.envs:
            self.assertEqual([k for k in env if k.startswith("HL_")], [])
            self.assertEqual(env["RAYON_NUM_THREADS"], "2")
        removed = self.manifest(out)["environment"]["removed_env_names"]
        self.assertEqual(self.manifest(out)["environment"]["modes_invoked"], ["p1"])
        self.assertTrue(set(removed) >= {"HL_FIXTURE_SEED", "HL_GPU"})
        self.assertTrue(all(name.startswith("HL_") for name in removed))


class Arguments(DemoCase):
    def test_nonsense_limits_are_refused_before_anything_runs(self):
        for bad in (["--threads", "0"], ["--timeout", "0"], ["--build-timeout", "-1"]):
            out = self.tmp / ("refused" + bad[0])
            with self.assertRaises(SystemExit) as raised, redirect_stderr(io.StringIO()):
                D.parse_args(["--output", str(out), *bad])
            self.assertEqual(raised.exception.code, 2)
            self.assertFalse(out.exists())

    def test_threads_reach_the_child_and_the_manifest(self):
        _, out, _, _ = self.demo(extra=["--threads", "1"])
        self.assertEqual(self.manifest(out)["environment"]["rayon_num_threads"], "1")
        self.assertTrue(all(env["RAYON_NUM_THREADS"] == "1" for env in self.fake.envs))


class OutputPreservation(DemoCase):
    def test_existing_output_is_never_written_to(self):
        out = self.tmp / "out"
        out.mkdir()
        (out / "keep.txt").write_text("previous evidence")
        code, out, _, bad = self.demo()
        self.assertEqual(code, 1)
        self.assertIn("must be a new path", bad)
        self.assertEqual((out / "keep.txt").read_text(), "previous evidence")
        self.assertEqual(sorted(p.name for p in out.iterdir()), ["keep.txt"])
        self.assertEqual(self.fake.calls, [])

    def test_existing_output_file_is_refused(self):
        taken = self.tmp / "taken"
        taken.write_text("file, not a directory")
        code, _, _, _ = self.demo(out="taken")
        self.assertEqual(code, 1)
        self.assertEqual(taken.read_text(), "file, not a directory")


class ProcessFailures(DemoCase):
    def test_timeout_is_a_failure_with_retained_detail(self):
        launcher = intercept(self.fake, 2, subprocess.TimeoutExpired("prove", 1800.0))
        code, out, _, bad = self.demo(launcher)
        record = self.failed(code, out, "no exit within", step="prove_p1")
        self.assertEqual(record["steps"][-1]["error"], "timeout")
        self.assertIn("manifest.json", bad)

    def test_signal_death_is_reported_as_a_crash(self):
        code, out, _, _ = self.demo(intercept(self.fake, 3, (-11, "", "")))
        self.failed(code, out, "killed by signal 11", step="verify_p1")

    def test_unrunnable_binary_is_reported(self):
        code, out, _, _ = self.demo(intercept(self.fake, 1, OSError("Exec format error")))
        self.failed(code, out, "could not run the example", step="register_public_weights")

    def test_unexpected_exit_code_keeps_stderr(self):
        code, out, _, _ = self.demo(intercept(self.fake, 2, (3, "", "prover panicked\n")))
        record = self.failed(code, out, "exit 3 (expected 0)", step="prove_p1")
        self.assertIn("prover panicked", record["steps"][-1]["stderr"])


class MalformedOutput(DemoCase):
    def test_non_json_success_line_fails_and_is_retained(self):
        self.fake.prepare_stdout = "ready\n"
        code, out, _, _ = self.demo()
        record = self.failed(code, out, "malformed result JSON", step="register_public_weights")
        self.assertEqual(record["steps"][-1]["stdout"], "ready\n")

    def test_json_that_is_not_an_object_fails(self):
        self.fake.prepare_stdout = "[1, 2]\n"
        code, out, _, _ = self.demo()
        self.failed(code, out, "not an object", step="register_public_weights")

    def test_missing_field_fails(self):
        self.fake.prepare_stdout = json.dumps({"proving_executed": False})
        code, out, _, _ = self.demo()
        self.failed(code, out, "'public_weight_root'", step="register_public_weights")

    def test_registration_that_already_proved_fails(self):
        self.fake.prepare_stdout = json.dumps({"public_weight_root": WEIGHT_ROOT,
                                               "proving_executed": True})
        code, out, _, _ = self.demo()
        self.failed(code, out, "proving_executed is True", step="register_public_weights")

    def test_root_that_is_not_a_digest_fails(self):
        self.fake.prepare_stdout = json.dumps({"public_weight_root": "zz",
                                               "proving_executed": False})
        code, out, _, _ = self.demo()
        self.failed(code, out, "not a digest", step="register_public_weights")

    def test_wire_bytes_must_match_the_saved_receipt(self):
        self.fake.wire_bytes = 7
        code, out, _, _ = self.demo()
        self.failed(code, out, "wire_bytes disagrees", step="prove_p1")

    def test_policy_must_carry_the_caller_context(self):
        self.fake.policy_context = "5a" * 32
        code, out, _, _ = self.demo()
        self.failed(code, out, "does not carry the caller's context", step="prove_p1")


class RejectionHandling(DemoCase):
    def test_accepting_a_control_fails_the_demo(self):
        self.fake.always_accept = True
        code, out, _, _ = self.demo()
        record = self.failed(code, out, "ACCEPTED a case it must reject",
                             step="reject_wrong_context")
        self.assertEqual(record["rejection_controls"], [])

    def test_late_acceptance_of_a_tampered_receipt_fails(self):
        code, out, _, _ = self.demo(intercept(self.fake, 7, (0, "{}", "")))
        record = self.failed(code, out, "ACCEPTED", step="reject_tampered_receipt")
        self.assertEqual(record["rejection_controls"],
                         ["reject_wrong_context", "reject_wrong_public_weight",
                          "reject_wrong_endpoint_policy"])

    def test_rejection_that_prints_a_result_line_fails(self):
        self.fake.rejection_stdout = "{\"verified_from_bytes\": true}"
        code, out, _, _ = self.demo()
        self.failed(code, out, "still printed a result line", step="reject_wrong_context")

    def test_silent_rejection_fails(self):
        self.fake.rejection_stderr = ""
        code, out, _, _ = self.demo()
        self.failed(code, out, "carried no verifier message", step="reject_wrong_context")

    def test_controls_use_distinct_inputs_and_keep_the_original_pair(self):
        _, out, _, _ = self.demo()
        controls = {step["name"]: step["command"] for step in self.manifest(out)["steps"]}
        self.assertEqual(controls["reject_wrong_public_weight"][3], "00" * 32)
        self.assertEqual(controls["reject_wrong_endpoint_policy"][5],
                         "p1.wrong_policy.expected")
        self.assertEqual(controls["reject_truncated_receipt"][6], "p1.truncated.receipt")
        self.assertEqual(len((out / "p1.truncated.receipt").read_bytes()),
                         len(self.fake.receipt) - 1)
        self.assertEqual(len((out / "p1.trailing.receipt").read_bytes()),
                         len(self.fake.receipt) + 1)
        self.assertEqual((out / "p1.receipt").read_bytes(), self.fake.receipt)


class Building(DemoCase):
    def flags(self):
        """A real source root (its Cargo.toml exists) and a fixed cargo name."""
        return ["--source", str(Path(__file__).resolve().parents[1]), "--cargo", "cargo"]

    def test_supplied_binary_skips_the_build(self):
        code, out, _, _ = self.demo(extra=self.flags())
        self.assertEqual(code, 0)
        build = self.manifest(out)["build"]
        self.assertFalse(build["performed"])
        self.assertEqual(build["reason"], "--binary supplied")
        self.assertTrue(self.manifest(out)["binary"]["supplied"])
        self.assertNotIn("cargo", [command[0] for command in self.fake.calls])

    def test_cargo_build_command_shape(self):
        out = self.tmp / "built"
        argv = ["--output", str(out), *self.flags()]
        with mock.patch.object(D, "launch", self.fake):
            with redirect_stdout(io.StringIO()), redirect_stderr(io.StringIO()):
                code = D.main(argv)
        self.assertEqual(code, 0)
        build = self.manifest(out)["build"]
        self.assertEqual(build["command"][:4], ["cargo", "build", "--locked", "--release"])
        self.assertEqual(build["command"][4], "--manifest-path")
        self.assertEqual(build["command"][5], "<source>/hashline/Cargo.toml")
        self.assertIn("--example", build["command"])
        self.assertEqual(build["features"], "default (CPU)")
        self.assertEqual(self.manifest(out)["binary"]["supplied"], False)

    def test_failed_build_keeps_stderr_and_stops(self):
        self.fake.cargo_exit = 101
        out = self.tmp / "built"
        with mock.patch.object(D, "launch", self.fake):
            with redirect_stdout(io.StringIO()), redirect_stderr(io.StringIO()):
                code = D.main(["--output", str(out), *self.flags()])
        self.failed(code, out, "cargo build: exit 101", step="build")
        self.assertEqual(len(self.fake.calls), 1)

    def test_build_without_an_executable_message_fails(self):
        self.fake.cargo_stdout = "{\"reason\":\"build-finished\",\"success\":true}\n"
        out = self.tmp / "built"
        with mock.patch.object(D, "launch", self.fake):
            with redirect_stdout(io.StringIO()), redirect_stderr(io.StringIO()):
                code = D.main(["--output", str(out), *self.flags()])
        self.failed(code, out, "no executable", step="build")

    def test_missing_manifest_is_reported_before_any_process(self):
        out = self.tmp / "built"
        with mock.patch.object(D, "launch", self.fake):
            with redirect_stdout(io.StringIO()), redirect_stderr(io.StringIO()):
                code = D.main(["--output", str(out), "--source", str(self.tmp)])
        self.failed(code, out, "no cargo manifest", step="build")
        self.assertEqual(self.fake.calls, [])


if __name__ == "__main__":
    unittest.main()
