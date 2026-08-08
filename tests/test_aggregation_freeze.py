"""U-AG-B1 BA: the aggregation freeze-row battery under the suite.

Runs scripts/aggregation_freeze_rows.py (the both-direction freeze rows
for R-EB1..R-EB4, kappa 11, C-win, and the R-FC2 per-group
digit-headroom rows) and requires a fully green run. The script is the
authority on WHAT is frozen; this test makes the suite the place where
a drift on either side (derivation chain or pin) fails loudly, and
spot-pins the row-id inventory so a script edit cannot silently drop a
row class (the test_statement_v3 needle pattern).
"""

import subprocess
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts" / "aggregation_freeze_rows.py"

# One needle per frozen row class; dropping any of these from the script
# is itself a freeze violation.
ROW_NEEDLES = [
    "EB1-tcap",       # R-EB1: T_cap = 33
    "EB1-mc33",       # R-EB1: [MODEL] MC acceptance table
    "EB2-rule",       # R-EB2: NS22 prohibition
    "EB2-count",      # R-EB2: full r(r+1) garbage count
    "EB3-tmin",       # R-EB3: t >= 7
    "EB3-kdraw",      # R-EB3: K-draw error class 496
    "EB3-adopted",    # R-EB3: adopted direction
    "EB4-line",       # R-EB4: 2^30.5 validity line
    "EB4-emax",       # R-EB4: floor base cap e <= 7
    "KAP-11",         # kappa = 11
    "CWIN-256",       # C-win window (256-row)
    "CWIN-512",       # C-win window (512-row)
    "FC2-act2-h",     # R-FC2: adopted activation headroom
    "FC2-W-h",        # R-FC2: W-C weight headroom
    "FC2-FN2",        # R-FC2: per-level-gate infeasibility (negative)
    "FC2-N5",         # R-FC2: e0=5 negative direction
    "FC2-W8B-h",      # R-FC2: 8B knife edge [MODEL]
    "FC2-law",        # R-FC2: one-time sqrt(32) law
]


class AggregationFreezeTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        result = subprocess.run(
            [sys.executable, str(SCRIPT)],
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
        )
        cls.returncode = result.returncode
        cls.stdout = result.stdout

    def test_freeze_rows_green(self):
        self.assertEqual(
            self.returncode, 0,
            "aggregation_freeze_rows.py reported failures:\n" + self.stdout,
        )
        self.assertIn("0 FAIL", self.stdout)
        self.assertNotIn("[FAIL]", self.stdout)

    def test_row_inventory_pinned(self):
        for needle in ROW_NEEDLES:
            self.assertIn(
                needle, self.stdout,
                "freeze-row class %r missing from the script output "
                "(row dropped?)" % needle,
            )

    def test_both_directions_documented(self):
        # The both-direction contract must stay stated in the output
        # header (the LKP precedent names its freeze semantics inline).
        self.assertIn("either side moving FAILS", self.stdout)


if __name__ == "__main__":
    unittest.main()
