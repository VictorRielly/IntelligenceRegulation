"""U-AG-B1 BA: the aggregation freeze-row battery under the suite.

Runs scripts/aggregation_freeze_rows.py (the both-direction freeze rows
for R-EB1..R-EB4, kappa 11, C-win, and the R-FC2 per-group
digit-headroom rows) and requires a fully green run. The script is the
authority on WHAT is frozen; this test makes the suite the place where
a drift on either side (derivation chain or pin) fails loudly.

Skeleton (BA lane, 2026-08-08); row-id spot pins land with the full
script content.
"""

import subprocess
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts" / "aggregation_freeze_rows.py"


class AggregationFreezeTests(unittest.TestCase):
    def test_freeze_rows_green(self):
        result = subprocess.run(
            [sys.executable, str(SCRIPT)],
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
        )
        self.assertEqual(
            result.returncode, 0,
            "aggregation_freeze_rows.py reported failures:\n" + result.stdout,
        )
        self.assertIn("0 FAIL", result.stdout)


if __name__ == "__main__":
    unittest.main()
