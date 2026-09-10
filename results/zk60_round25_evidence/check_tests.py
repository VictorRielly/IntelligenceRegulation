"""Require every affected test and retained capture; never accept skipped work."""
import json
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
captures = ROOT/"results/zk60_round22_captures"
if len(list(captures.glob("*.json"))) != 4:
    raise SystemExit("REFUSED: four retained captures are mandatory")
suite = unittest.TestSuite()
for pattern in ("test_zk60_io_*.py", "test_zk60_endpoint_*.py",
                "test_zk60_opus_oracle_bookkeeping.py", "test_zk60_opus_repeated_view.py"):
    suite.addTests(unittest.defaultTestLoader.discover(str(ROOT/"tests"), pattern=pattern))
result = unittest.TextTestRunner(verbosity=2).run(suite)
print(json.dumps(dict(tests=result.testsRun, skips=len(result.skipped), failures=len(result.failures), errors=len(result.errors))))
if not result.wasSuccessful() or result.skipped or result.testsRun != 75:
    raise SystemExit("REFUSED: test failure, missing coverage or skipped evidence")
