import copy
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
import zk60_io_review_gate as gate


class ReviewAcceptance(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.report = json.loads((gate.ROOT / "results/zk60_opus_io_capture_analysis.json").read_text())
        cls.ids = {c["proof_sha256"] for c in cls.report["captures"]}

    def test_delivered_complete_record_accepts(self):
        gate.check_report(self.report, self.ids)

    def test_empty_directory_cannot_report_success(self):
        manifest = gate.ROOT / "results/zk60_round19_validation.json"
        with tempfile.TemporaryDirectory() as directory:
            # Reproduce the delivery bug with real preflight/analysis: the old
            # verdict is vacuously true even though all capture evidence is absent.
            old = gate.opus.analyze(directory, str(manifest), None, log=lambda *a: None)
            self.assertFalse(old["preflight"]["pass"])
            self.assertTrue(old["verdict"]["controls_all_pass"])
            with patch.object(gate.opus, "analyze") as analysis:
                with self.assertRaisesRegex(ValueError, "failed input preflight"):
                    gate.run(Path(directory), manifest)
                analysis.assert_not_called()

    def test_failed_preflight_cannot_be_overridden_by_green_model(self):
        bad = copy.deepcopy(self.report)
        bad["preflight"]["checks"][0]["pass"] = False
        with self.assertRaisesRegex(ValueError, "analysis preflight"):
            gate.check_report(bad, self.ids)

    def test_missing_and_duplicate_results_are_refused(self):
        for key in ("cases", "captures"):
            for duplicate in (False, True):
                with self.subTest(key=key, duplicate=duplicate):
                    bad = copy.deepcopy(self.report)
                    if duplicate:
                        bad[key][-1] = bad[key][0]
                    else:
                        bad[key].pop()
                    with self.assertRaisesRegex(ValueError, "incomplete or duplicate"):
                        gate.check_report(bad, self.ids)

    def test_failed_ingestion_control_is_not_a_successful_analysis(self):
        bad = copy.deepcopy(self.report)
        bad["controls"]["ingestion_negatives_P1"]["controls"][0]["rejected"] = False
        # The archived verdict omits ingestion controls, so its true flag must
        # never be sufficient for the integration gate.
        self.assertTrue(gate.opus.verdict(bad)["controls_all_pass"])
        with self.assertRaisesRegex(ValueError, "ingestion control"):
            gate.check_report(bad, self.ids)


if __name__ == "__main__":
    unittest.main()
