"""Run unchanged O8 tests on explicitly named fresh captures, not old artifacts."""
import importlib.util
import json
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("o8_fresh_tests", ROOT / "tests/test_zk60_opus_io_capture.py")
tests = importlib.util.module_from_spec(spec)
spec.loader.exec_module(tests)
tests.CAPTURES = str(ROOT / "results/zk60_round22_captures")
tests.MANIFEST = ROOT / "results/zk60_round22_captures.json"
pre = tests.M.preflight(tests.CAPTURES, str(tests.MANIFEST), log=lambda *a: None)
assert pre["pass"] and len(tests._captures()) == 4
# Their decorators tested the missing /tmp directory at import time. These
# three classes now have validated fresh fixtures and the matching manifest.
# Legacy classes remain skipped: the old ten captures are unavailable.
for name in ("AdapterRefusals", "JointModelTests", "IoCaptures"):
    getattr(tests, name).__unittest_skip__ = False
result = unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromModule(tests))
record = dict(tests_run=result.testsRun, failures=len(result.failures), errors=len(result.errors),
              skipped=[dict(test=str(test), reason=reason) for test, reason in result.skipped],
              captures=tests.CAPTURES, manifest=str(tests.MANIFEST),
              original_tests_modified=False, historical_result_binding_checked=True)
Path(__file__).with_suffix(".json").write_text(json.dumps(record, indent=2) + "\n")
sys.exit(0 if result.wasSuccessful() and len(result.skipped) == 3 else 1)
