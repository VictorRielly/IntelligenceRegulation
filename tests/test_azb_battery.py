"""AZB battery spike carrier (U-AG-B1, lane BC).

Runs scripts/azb_battery_spike.py — the executable spike-level legs for
every AZB battery id (AGGREGATION_ZK_DESIGN.md Section 6 AZB-1..9, the
U-AG4 FINAL AZB-10/11) plus the F-Z1 masking-corner re-check — and
asserts the full leg count. The spike itself re-runs its three parent
simulators (aggregation_zk_spike, fold_privacy_pricing_spike,
aggregation_folding_spike) and asserts their recorded verdict lines
before printing a single leg, so this one test transitively pins all
four. Engine-scale legs are [ENGINE PENDING - BB] per
docs/zkmatrix-poc/AZB_BATTERY_PLAN.md and are NOT covered here.
"""

import subprocess
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SPIKE = ROOT / "scripts" / "azb_battery_spike.py"


class AzbBatterySpikeTests(unittest.TestCase):
    def test_azb_battery_spike_green(self):
        result = subprocess.run(
            [sys.executable, str(SPIKE)],
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            timeout=600,
        )
        self.assertEqual(
            result.returncode, 0,
            "azb_battery_spike.py exited %d:\n%s"
            % (result.returncode, result.stdout))
        self.assertIn("20/20 OK", result.stdout,
                      "expected the full 20/20 leg count:\n" + result.stdout)
        self.assertIn("parent anchors reproduced", result.stdout)


if __name__ == "__main__":
    unittest.main()
