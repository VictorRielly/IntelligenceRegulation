# [UAGB1-BG] U-AG-B1 wave 3 lane BG: the pass-level composition —
# suite face. The derived-expectation printer and the freeze rows run
# always (no data dependency); the real-data composition smoke rides
# only when the m125 exports exist (BF's loud-skip discipline).
#
# The FULL battery (13 legs) and the AZB-11 canary are subcommand-run
# lane/merge gates (`pass-agg battery`, `pass-agg canary`) — they cost
# minutes on real data and are not suite-sized.

import os
import subprocess
import unittest

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RS = os.path.join(REPO, "zkmatrix-rs")
BIN = os.path.join(RS, "target", "release", "ring_matmul")
EXPORTS = os.path.join(REPO, "results", "m125_ffn_export", "layer00_X.bin")


def run(args, timeout):
    return subprocess.run(
        [BIN] + args, cwd=RS, capture_output=True, text=True, timeout=timeout
    )


@unittest.skipUnless(os.path.exists(BIN), "ring_matmul release binary not built")
class PassAggComposition(unittest.TestCase):
    def test_expect_derivation(self):
        """The derived 125M pass-budget expectation prints and carries
        the load-bearing lines (no export files needed)."""
        p = run(["pass-agg", "expect"], timeout=120)
        self.assertEqual(p.returncode, 0, p.stdout + p.stderr)
        out = p.stdout
        self.assertIn("act 7823360 digit rings, weight 3538944", out)
        self.assertIn("EXPECTED Tier N composed pass", out)
        self.assertIn("EXPECTED Tier Z P2 pass", out)
        self.assertIn("NOT-COMPOSED table-membership facts", out)
        self.assertIn("125M-STRUCTURAL", out)

    def test_mode_refusal(self):
        """P1/P3 refuse loudly at the composition layer (Amendment A1:
        no silent degradation; the act-side mask is not built)."""
        p = run(["pass-agg", "prove", "2", "16", "p3"], timeout=120)
        self.assertNotEqual(p.returncode, 0)
        self.assertIn("REFUSED", p.stdout + p.stderr)

    @unittest.skipUnless(
        os.path.exists(EXPORTS),
        "m125 exports absent - run scripts/m125_export_ffn.py under the frugal venv",
    )
    def test_composed_smoke_real_data(self):
        """Honest composed P0 pass at 2 layers, T = 16, REAL ckpt data:
        fold -> batch -> two eval proofs, accept = true."""
        p = run(["pass-agg", "prove", "2", "16", "p0"], timeout=1800)
        self.assertEqual(p.returncode, 0, p.stdout[-4000:] + p.stderr[-4000:])
        self.assertIn("accept true", p.stdout)
