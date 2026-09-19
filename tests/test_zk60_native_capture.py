"""Native capture ingestion must reject forged telemetry and failed replays."""
import copy
import hashlib
import json
import os
import re
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
import zk60_native_capture as native


class NativeCaptureTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        directory = Path(os.environ.get("HL_NATIVE_CAPTURE_FIXTURES", ROOT / "results/zk60_native_captures_20260919/captures"))
        paths = sorted(directory.glob("*.json"))
        if not paths:
            raise unittest.SkipTest("retained native capture fixtures unavailable")
        cls.fixtures = [(p, json.loads(p.read_bytes())) for p in paths]
        cls.binary = os.environ.get("HL_NATIVE_CAPTURE_TEST_BINARY")

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        source, capture = self.fixtures[0]
        self.capture = copy.deepcopy(capture)
        self.path = Path(self.tmp.name) / source.name
        for suffix in ("json", "receipt", "expected"):
            shutil.copyfile(source.with_suffix("." + suffix), self.path.with_suffix("." + suffix))
        self.source = capture["source_commit"]

    def save(self):
        self.path.write_text(json.dumps(self.capture))

    def screen(self):
        return native.screen_bundle(self.path, self.source)

    def test_all_retained_profiles_close_public_slot_equations(self):
        profiles = set()
        for path, capture in self.fixtures:
            result, _, _, _ = native.screen_bundle(path, capture["source_commit"])
            profiles.add(result["profile"])
        self.assertEqual(profiles, set(native.PROFILES))

    def test_wrong_source_and_ffn_relabel_are_refused(self):
        with self.assertRaisesRegex(ValueError, "source mismatch"):
            native.screen_bundle(self.path, "f" * 40)
        self.capture["profile"] = "ffn-v3-mr1-fresh-io-poc/2"
        self.save()
        with self.assertRaisesRegex(ValueError, "unsupported native profile"):
            self.screen()

    def test_duplicate_keys_floats_and_booleans_are_refused(self):
        raw = self.path.read_text()
        for bad in ['{"schema":3,' + raw[1:], raw.replace('"schema":3', '"schema":3.0', 1), raw.replace('"schema":3', '"schema":true', 1)]:
            self.path.write_text(bad)
            with self.assertRaises(ValueError):
                self.screen()

    def test_bad_receipt_and_policy_digests(self):
        for suffix in ("receipt", "expected"):
            p = self.path.with_suffix("." + suffix)
            original = p.read_bytes()
            changed = bytearray(original); changed[-1] ^= 1
            p.write_bytes(changed)
            with self.assertRaises(ValueError):
                self.screen()
            p.write_bytes(original)

    def test_transcript_join(self):
        self.capture["arguments"][1]["before_definition"]["state"][0] ^= 1
        self.save()
        with self.assertRaisesRegex(ValueError, "transcript join"):
            self.screen()

    def test_sumcheck_round(self):
        self.capture["arguments"][0]["rounds"][0][0][0] ^= 1
        self.save()
        with self.assertRaisesRegex(ValueError, "sumcheck sum"):
            self.screen()

    def test_packed_subrow_alias(self):
        slot = next(a for a in self.capture["arguments"] if any(t["kind"] == "private" and t["log_size"] < 8 for t in a["tables"]))
        table = next(t for t in slot["tables"] if t["kind"] == "private" and t["log_size"] < 8)
        table["slices"][0]["offset"] += 32
        self.save()
        with self.assertRaisesRegex(ValueError, "terminal/PCS alias"):
            self.screen()

    def test_bilinear_extension_alias(self):
        slot = next(a for a in self.capture["arguments"] if a["extension"] == 2)
        table = next(t for t in slot["tables"] if t["kind"] == "private")
        table["extension_round"] = 1 - table["extension_round"]
        self.save()
        with self.assertRaisesRegex(ValueError, "terminal/PCS alias"):
            self.screen()

    def test_m_functional_alias(self):
        self.capture["mask"]["functionals"][0]["terms"][0]["weights"][0][0] ^= 1
        self.save()
        with self.assertRaisesRegex(ValueError, "functional aliases"):
            self.screen()

    def test_false_privacy_acceptance_is_refused(self):
        self.capture["privacy_review_complete"] = True
        self.save()
        with self.assertRaisesRegex(ValueError, "capture status"):
            self.screen()

    def test_wrong_binary_pin_does_not_execute(self):
        binary = Path(self.tmp.name) / "untrusted"
        binary.write_bytes(b"not a verifier")
        with patch.object(native.subprocess, "run") as run:
            with self.assertRaisesRegex(ValueError, "binary digest"):
                native.check_bundle(self.path, self.source, binary, "0" * 64)
            run.assert_not_called()

    def test_zero_tests_or_failed_process_cannot_count_as_verification(self):
        binary = Path(self.tmp.name) / "mock-verifier"
        binary.write_bytes(b"test runner stand-in")
        digest = hashlib.sha256(binary.read_bytes()).hexdigest()
        for status, stdout in [(0, "0 passed; 0 failed; 0 ignored"), (1, "1 passed; 0 failed; 0 ignored")]:
            with patch.object(native.subprocess, "run", return_value=subprocess.CompletedProcess([], status, stdout, "")):
                with self.assertRaisesRegex(ValueError, "native replay"):
                    native.check_bundle(self.path, self.source, binary, digest)

    def test_fresh_native_process_and_tampered_telemetry(self):
        if not self.binary:
            self.skipTest("set HL_NATIVE_CAPTURE_TEST_BINARY for real-process controls")
        binary = Path(self.binary)
        digest = hashlib.sha256(binary.read_bytes()).hexdigest()
        for path, capture in self.fixtures:
            self.assertTrue(native.check_bundle(path, capture["source_commit"], binary, digest)["canonical_capture_reproduced"])
        # Fields not authenticated by cheap JSON screening still MUST match
        # native replay: metadata, definition challenge tape, PCS lambdas,
        # pad coordinates, sampled columns, salts and Merkle paths.
        original = self.path.read_text()
        capture, profile, receipt, expected = self.screen()
        native.replay(self.path, capture, profile, receipt, expected, binary, digest)

        def changed_word(marker, index=0):
            start = original.index(marker) + len(marker)
            words = re.finditer(r"[0-9]+", original[start:])
            word = next(words)
            for _ in range(index):
                word = next(words)
            left, right = start + word.start(), start + word.end()
            return original[:left] + str(int(word.group()) ^ 1) + original[right:]

        # Preserve every other byte, including canonical whitespace, so these
        # refusals exercise the changed observation rather than formatting.
        candidates = [
            original.replace('"site":"A.data[0]"', '"site":"forged identity"', 1),
            changed_word('"definition_challenges":[['),
            changed_word('"lambdas":[['),
            changed_word('"vector":[[', 512),  # first pad coordinate
            changed_word('"columns":[{"index":', 1),  # first column value
            changed_word('"salt":['),
            changed_word('"path":[['),
        ]
        for candidate in candidates:
            self.assertNotEqual(candidate, original)
            self.path.write_text(candidate)
            with self.assertRaisesRegex(ValueError, "native replay"):
                native.replay(self.path, capture, profile, receipt, expected, binary, digest)



if __name__ == "__main__":
    unittest.main()
