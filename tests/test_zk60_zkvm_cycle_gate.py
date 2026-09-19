"""Unit tests for scripts/zk60_zkvm_cycle_gate.py.

The host here is a MOCK Python script written into a temp directory. It
imitates only the command-line and file contract of zk60-block-host
(`image-id`, `prepare-input`, `execute`), refuses inputs outside a small
range the way the real calibration does, refuses to start if any RISC0_*,
BONSAI_* or RUST_LOG* variable reached it, and prints an execute JSON line
whose cycle counts it makes up. It runs no zkVM, needs no r0vm, no Rust and
no network, and proves nothing cryptographic. A passing test says the gate's
parsing, refusal handling, constant/non-constant verdict, timeout bounding
and private-work cleanup behave as specified.
"""
import importlib.util
import json
import os
from pathlib import Path
import stat
import subprocess
import sys
import tempfile
import time
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "zk60_zkvm_cycle_gate.py"
spec = importlib.util.spec_from_file_location("zk60_zkvm_cycle_gate", SCRIPT)
gate = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gate)

IMAGE_ID = "ab" * 32
SECRET_TAG = b"MOCK-SALT-9c1d4e7a0b2f3d61"

MOCK_HOST = r'''#!{python}
# MOCK zk60-block-host: file contract only. No zkVM, no proof, no receipt.
import json, os, sys, time
a = sys.argv
if any(k.startswith(("RISC0_", "BONSAI_", "RUST_LOG")) for k in os.environ):
    sys.exit("zk60 MOCK: prover, cloud and logging switches must be unset")
CONFIG = json.load(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "mock.json")))
TAG = {secret!r}


def refuse(message):
    print(message, file=sys.stderr)
    sys.exit(1)


if a[1] == "image-id" and len(a) == 2:
    print({image_id!r})
    sys.exit(0)
if a[1] == "prepare-input" and len(a) == 6:
    model, source, public, private = a[2], a[3], a[4], a[5]
    data = open(source, "rb").read()
    if len(data) != 1024:
        refuse("zk60 block: input must contain exactly 512 little-endian i16 words")
    values = [int.from_bytes(data[i:i + 2], "little", signed=True) for i in range(0, 1024, 2)]
    if max(abs(v) for v in values) > CONFIG["refuse_above"]:
        refuse("zk60 block: block computation refused input")
    if os.path.lexists(public) or os.path.lexists(private):
        refuse("zk60 block: output directories must be new and disjoint")
    os.mkdir(public, 0o755)
    os.mkdir(private, 0o700)
    open(os.path.join(public, "model.bin"), "wb").write(open(model, "rb").read())
    open(os.path.join(public, "policy.bin"), "wb").write(bytes(144))
    fd = os.open(os.path.join(private, "request.bin"), os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    os.write(fd, TAG + bytes(96 - len(TAG)) + data)
    os.close(fd)
    print('{{"prepared":true,"coverage":"mock","mvp_complete":false}}')
    sys.exit(0)
if a[1] == "execute" and len(a) == 7:
    request, receipt = a[3], a[5]
    if os.path.lexists(receipt):
        refuse("zk60 block: receipt output already exists")
    body = open(request, "rb").read()[96:]
    values = [int.from_bytes(body[i:i + 2], "little", signed=True) for i in range(0, len(body), 2)]
    time.sleep(CONFIG.get("sleep", 0))
    # Diagnostic noise on stderr must not disturb the gate's parsing.
    print("mock: executor finished", file=sys.stderr)
    if CONFIG["mode"] == "garbage":
        print("no json here")
        sys.exit(0)
    user = 200000
    segments = 1
    if CONFIG["mode"] in ("variable", "user_only"):
        # Deliberately input-dependent work. In "variable" a second segment
        # appears once it passes the limit, so the padded shape moves too; in
        # "user_only" only the unpadded user count moves.
        user += sum(1 for v in values if v != 0) * 200
        if CONFIG["mode"] == "variable":
            segments = 1 if user <= 262144 else 2
    total = 262144 * segments
    print(json.dumps({{"execution_matches_policy": True, "proof_created": False,
                      "total_cycles": total, "user_cycles": user, "segments": segments,
                      "segment_limit_po2": 18,
                      "mvp_complete": CONFIG["mode"] == "mvp"}}))
    sys.exit(0)
sys.exit("zk60 MOCK: unsupported invocation")
'''


class GateTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.addCleanup(self.tmp.cleanup)
        self.host = self.root / "mock_host.py"
        self.host.write_text(MOCK_HOST.format(python=sys.executable, image_id=IMAGE_ID,
                                              secret=SECRET_TAG))
        self.host.chmod(0o700)
        self.r0vm = self.root / "mock_r0vm"
        self.r0vm.write_text("#!/bin/sh\nexit 0\n")
        self.r0vm.chmod(0o700)
        self.model = self.root / "model.bin"
        self.model.write_bytes(b"Z60MDL01" + bytes(6176))
        self.configure()

    def configure(self, mode="constant", refuse_above=8, sleep=0):
        (self.root / "mock.json").write_text(
            json.dumps({"mode": mode, "refuse_above": refuse_above, "sleep": sleep}))

    def run_gate(self, name="out", extra=()):
        out = self.root / name
        code = gate.main(["--host", str(self.host), "--model", str(self.model),
                          "--r0vm", str(self.r0vm), "--out", str(out), *extra])
        return code, out

    def record(self, out):
        return json.loads((out / "cycle_gate.json").read_text())

    # ---- the input set ---------------------------------------------------
    def test_pattern_files_have_the_right_length_and_values(self):
        seen = {}
        for name, _ in gate.PATTERNS:
            values = gate.pattern_values(name)
            data = gate.encode_input(values)
            self.assertEqual(len(data), 1024, name)
            self.assertEqual(len(values), 512, name)
            decoded = [int.from_bytes(data[i:i + 2], "little", signed=True)
                       for i in range(0, 1024, 2)]
            self.assertEqual(decoded, values, name)
            seen[name] = values
        self.assertEqual(seen["zero"], [0] * 512)
        self.assertEqual(seen["pos3"], [3] * 512)
        self.assertEqual(seen["neg3"], [-3] * 512)
        self.assertEqual(seen["alt"][:4], [3, -3, 3, -3])
        self.assertEqual(set(seen["alt"]), {3, -3})
        rows = [seen["rows_equal"][r * 16:(r + 1) * 16] for r in range(32)]
        for row in rows:
            self.assertEqual(len(set(row)), 1)
        self.assertGreater(len({row[0] for row in rows}), 1)
        self.assertTrue(all(-3 <= v <= 3 for v in seen["random_small"]))
        self.assertEqual(seen["ramp"], [(i % 7) - 3 for i in range(512)])
        self.assertEqual(seen["pos64"], [64] * 512)
        self.assertEqual(seen["neg64"], [-64] * 512)
        self.assertNotEqual(gate.pattern_values("random_small"),
                            gate.pattern_values("random_small"))
        with self.assertRaises(gate.GateError):
            gate.pattern_values("no_such_pattern")
        with self.assertRaises(gate.GateError):
            gate.encode_input([0] * 511)

    # ---- verdicts --------------------------------------------------------
    def test_constant_run_records_a_constant_verdict_and_cleans_up(self):
        # The mock refuses to start if any switch survived; a clean run is
        # the evidence that the gate scrubs the child environment.
        os.environ.update(RISC0_DEV_MODE="1", RISC0_PROVER="bonsai",
                          BONSAI_API_KEY="k", RUST_LOG_STYLE="always")
        for key in ("RISC0_DEV_MODE", "RISC0_PROVER", "BONSAI_API_KEY", "RUST_LOG_STYLE"):
            self.addCleanup(os.environ.pop, key, None)
        code, out = self.run_gate()
        self.assertEqual(code, 0)
        record = self.record(out)
        self.assertTrue(record["constant_cycles"])
        self.assertTrue(record["constant_total_cycles"])
        self.assertTrue(record["constant_user_cycles"])
        self.assertEqual(record["distinct_user_cycle_counts"], [200000])
        self.assertEqual(record["total_cycle_spread"], 0)
        self.assertEqual(record["user_cycle_spread"], 0)
        self.assertIsNone(record["declared_leakage"])
        self.assertEqual(len(record["distinct_cycle_shapes"]), 1)
        self.assertEqual(record["accepted_patterns"],
                         ["zero", "pos3", "neg3", "alt", "rows_equal", "random_small", "ramp"])
        self.assertEqual(record["refused_patterns"], ["pos64", "neg64"])
        self.assertEqual(record["image_id"], IMAGE_ID)
        self.assertEqual(record["mvp_complete"], False)
        refused = [r for r in record["patterns"] if not r["accepted"]]
        for row in refused:
            self.assertEqual(row["stage"], "prepare-input")
            self.assertEqual(row["exit_code"], 1)
            self.assertEqual(row["refusal"], "zk60 block: block computation refused input")
        for row in [r for r in record["patterns"] if r["accepted"]]:
            self.assertEqual((row["total_cycles"], row["user_cycles"], row["segments"]),
                             (262144, 200000, 1))
            self.assertEqual(row["segment_limit_po2"], 18)
        # No witness material survives, and none of it is in the record.
        self.assertFalse((out / "work").exists())
        self.assertEqual(sorted(p.name for p in out.iterdir()), ["cycle_gate.json"])
        self.assertNotIn(SECRET_TAG.decode(), (out / "cycle_gate.json").read_text())
        self.assertEqual(stat.S_IMODE(out.stat().st_mode), 0o700)
        self.assertEqual(stat.S_IMODE((out / "cycle_gate.json").stat().st_mode), 0o600)

    def test_variable_run_declares_timing_leakage(self):
        self.configure(mode="variable")
        code, out = self.run_gate()
        self.assertEqual(code, 0)
        record = self.record(out)
        self.assertFalse(record["constant_cycles"])
        self.assertFalse(record["constant_total_cycles"])
        self.assertFalse(record["constant_user_cycles"])
        self.assertGreater(record["user_cycle_spread"], 0)
        self.assertGreater(record["total_cycle_spread"], 0)
        self.assertIn("Declared timing leakage", record["declared_leakage"])
        self.assertIn("segment count a receipt exposes", record["declared_leakage"])
        self.assertIn(str(record["total_cycle_spread"]), record["declared_leakage"])
        self.assertGreater(len(record["distinct_cycle_shapes"]), 1)
        # zero has no nonzero values, so it is the cheapest accepted pattern.
        rows = {r["name"]: r for r in record["patterns"] if r["accepted"]}
        self.assertEqual(rows["zero"]["user_cycles"], 200000)
        self.assertGreater(rows["pos3"]["user_cycles"], rows["zero"]["user_cycles"])
        # --require-constant turns the declared leakage into a failing gate.
        code, out = self.run_gate("strict", ["--require-constant"])
        self.assertEqual(code, 1)
        self.assertFalse(self.record(out)["constant_cycles"])

    def test_constant_padded_shape_with_moving_user_cycles_is_still_leakage(self):
        self.configure(mode="user_only")
        code, out = self.run_gate()
        self.assertEqual(code, 0)
        record = self.record(out)
        self.assertTrue(record["constant_total_cycles"])
        self.assertFalse(record["constant_user_cycles"])
        self.assertFalse(record["constant_cycles"])
        self.assertEqual(record["total_cycle_spread"], 0)
        self.assertGreater(record["user_cycle_spread"], 0)
        self.assertEqual(len(record["distinct_cycle_shapes"]), 1)
        self.assertGreater(len(record["distinct_user_cycle_counts"]), 1)
        self.assertIn("the padded total", record["declared_leakage"])
        self.assertIn("USER cycle count is not", record["declared_leakage"])

    def test_keep_retains_the_private_work_tree(self):
        code, out = self.run_gate(extra=["--keep"])
        self.assertEqual(code, 0)
        work = out / "work"
        self.assertEqual(stat.S_IMODE(work.stat().st_mode), 0o700)
        self.assertEqual(stat.S_IMODE((work / "zero").stat().st_mode), 0o700)
        request = work / "zero" / "private" / "request.bin"
        self.assertEqual(stat.S_IMODE(request.stat().st_mode), 0o600)
        self.assertEqual(stat.S_IMODE((work / "zero" / "input.i16").stat().st_mode), 0o600)

    # ---- fail-closed behaviour ------------------------------------------
    def test_child_timeout_is_bounded_and_nothing_is_recorded(self):
        self.configure(sleep=30)
        started = time.monotonic()
        code, out = self.run_gate(extra=["--timeout", "1"])
        self.assertEqual(code, 1)
        self.assertLess(time.monotonic() - started, 25)
        self.assertFalse((out / "cycle_gate.json").exists())
        self.assertFalse((out / "work").exists())

    def test_unparsable_or_overclaiming_output_fails_closed(self):
        for mode in ("garbage", "mvp"):
            self.configure(mode=mode)
            code, out = self.run_gate(name=f"out-{mode}")
            self.assertEqual(code, 1, mode)
            self.assertFalse((out / "cycle_gate.json").exists(), mode)

    def test_every_pattern_refused_is_an_error_not_a_verdict(self):
        self.configure(refuse_above=-1)
        code, out = self.run_gate()
        self.assertEqual(code, 1)
        self.assertFalse((out / "cycle_gate.json").exists())

    def test_output_directory_must_be_new(self):
        (self.root / "taken").mkdir()
        code, _ = self.run_gate(name="taken")
        self.assertEqual(code, 1)

    def test_missing_prerequisites_are_reported_not_raised(self):
        for flag, value in (("--host", "/nonexistent/host"),
                            ("--r0vm", "/nonexistent/r0vm"),
                            ("--model", "/nonexistent/model.bin")):
            args = {"--host": str(self.host), "--model": str(self.model),
                    "--r0vm": str(self.r0vm)}
            args[flag] = value
            out = self.root / f"missing{flag.strip('-')}"
            code = gate.main([*sum(([k, v] for k, v in args.items()), []),
                              "--out", str(out)])
            self.assertEqual(code, 1, flag)
        # A directory whose parent does not exist is reported the same way.
        self.assertEqual(self.run_gate(name="no/such/parent")[0], 1)

    def test_mock_host_really_refuses_a_polluted_environment(self):
        # The control for the scrubbing test above: without the gate, the
        # same mock fails when a switch is present.
        env = dict(os.environ, RISC0_DEV_MODE="1")
        done = subprocess.run([str(self.host), "image-id"], env=env,
                              capture_output=True, text=True)
        self.assertEqual(done.returncode, 1)
        self.assertIn("must be unset", done.stderr)

    def test_unknown_stderr_is_withheld_from_the_record(self):
        self.assertEqual(gate.refusal_message("/nonexistent/err"), gate.WITHHELD)
        with tempfile.NamedTemporaryFile("w", suffix=".err", delete=False) as f:
            f.write("zk60 block: refused input -3 -3 2 at row 7\n")
            path = f.name
        self.addCleanup(os.unlink, path)
        self.assertEqual(gate.refusal_message(path), gate.WITHHELD)


if __name__ == "__main__":
    unittest.main()
