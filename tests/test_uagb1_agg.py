"""[UAGB1-BD] U-AG-B1 wave 2 lane BD: the aggregation-stack smoke tests.

Drives `ring_matmul agg-matmul` / `agg-kel` the same way
test_statement_v3.py drives the native binaries. The FULL battery
(23 legs incl. both F5 pairs and the Tier-Z masked-floor legs, ~4 min)
is `ring_matmul agg-matmul battery` and is run at lane/merge gates,
not per suite run; this module keeps the suite light: one honest
end-to-end instance at a small shape (claim layer + auto-planned
recursion + floor checks) and the kel exact-count identity (F-O2
standalone route) at three fast points.
"""

import shutil
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RUST_CRATE = ROOT / "zkmatrix-rs"
RING_MATMUL_BINARY = RUST_CRATE / "target" / "release" / "ring_matmul"


@unittest.skipIf(shutil.which("cargo") is None, "cargo is not installed")
class AggStackTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        subprocess.run(["cargo", "build", "--release"], cwd=RUST_CRATE, check=True)

    def run_mode(self, *args):
        result = subprocess.run(
            [str(RING_MATMUL_BINARY), *args],
            check=True,
            text=True,
            stdout=subprocess.PIPE,
        )
        return result.stdout

    def test_agg_small_honest_instance(self):
        out = self.run_mode("agg-matmul", "64", "96", "128")
        self.assertIn("accept true", out)
        self.assertIn("FLOOR SCHEDULE", out)
        self.assertIn("corner SURVIVES", out)

    def test_agg_kel_exact_counts(self):
        # The binary itself asserts real == structural == fit per point.
        out = self.run_mode("agg-kel", "10", "12", "14")
        self.assertEqual(out.count("EXACT ("), 3)
        self.assertIn("kel(25,9) = 1760", out)
        self.assertIn("kel(29,9) = 2236", out)
