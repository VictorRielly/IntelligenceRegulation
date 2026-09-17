"""Integration review: malformed success records must not produce a pass."""
from contextlib import redirect_stderr
import io
import json
from pathlib import Path
from unittest import mock

import test_zk60_p1_demo as T


class ReviewedFailureCases(T.DemoCase):
    def test_numeric_boolean_is_not_a_no_proving_attestation(self):
        self.fake.prepare_stdout = json.dumps({
            "public_weight_root": T.WEIGHT_ROOT, "proving_executed": 0})
        code, out, _, _ = self.demo()
        self.failed(code, out, "proving_executed", step="register_public_weights")

    def test_empty_receipt_records_failure_before_controls(self):
        self.fake.receipt = b""
        code, out, _, _ = self.demo()
        record = self.failed(code, out, "wire_bytes", step="prove_p1")
        self.assertEqual(record["rejection_controls"], [])

    def test_float_byte_count_cannot_validate_a_receipt(self):
        self.fake.wire_bytes = float(len(self.fake.receipt))
        code, out, _, _ = self.demo()
        self.failed(code, out, "wire_bytes", step="prove_p1")

    def test_invalid_limits_refuse_before_creating_artifacts(self):
        for flag, value in (("--threads", "0"), ("--threads", "17"),
                            ("--timeout", "nan"), ("--timeout", "inf"),
                            ("--timeout", "0"), ("--build-timeout", "-1")):
            with self.subTest(flag=flag, value=value), redirect_stderr(io.StringIO()):
                with self.assertRaises(SystemExit) as error:
                    self.demo(extra=(flag, value))
                self.assertEqual(error.exception.code, 2)
                self.assertFalse((self.tmp / "out").exists())

    def test_malformed_cargo_target_records_failure(self):
        for index, target in enumerate((7, {"name": T.D.EXAMPLE, "kind": 7})):
            self.fake.cargo_stdout = json.dumps({"reason": "compiler-artifact", "target": target})
            out = self.tmp / f"out-{index}"
            argv = ["--output", str(out), "--source", str(Path(__file__).resolve().parents[1])]
            with self.subTest(target=target), mock.patch.object(T.D, "launch", self.fake), redirect_stderr(io.StringIO()):
                code = T.D.main(argv)
            self.failed(code, out, "malformed target", step="build")
