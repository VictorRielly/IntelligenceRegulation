# [UAGB1-BL] U-AG-B1 wave 4 lane BL: T_blind — masking the
# weight-touching round polynomials of the composed P2 path.
#
# The certificate battery (`t-blind battery`) and the derived-surcharge
# printer (`t-blind expect`) are fast (real K arithmetic, toy shapes) and
# run always. The composed P2+T_blind smoke on real ckpt data is a
# minutes-scale lane/merge gate (`pass-agg prove .. p2`) and rides only
# when the m125 exports exist, with a generous timeout.

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
class TBlindCertificate(unittest.TestCase):
    def test_battery(self):
        """The T_blind certificate battery: completeness/soundness + the
        E-1..E-9 legs (leak, blinded non-recovery, AZ-L1a full rank, the
        joint-blinding cert, the FS-order pairs, freshness, slot)."""
        p = run(["t-blind", "battery"], timeout=120)
        self.assertEqual(p.returncode, 0, p.stdout[-3000:] + p.stderr[-3000:])
        out = p.stdout
        self.assertIn("11/11 legs green", out)
        self.assertIn("L1 completeness", out)
        self.assertIn("E-1 (AZB-1)", out)
        self.assertIn("AZ-L1a: round-mask exposure map full column rank", out)
        self.assertIn("E-8 (AZ-O2)", out)
        self.assertIn("I-6 HELD", out)

    def test_expect_surcharge(self):
        """The derived wire surcharge prints (1,024 B vs BG's ~1,664 B
        [MODEL]) with the structural explanation."""
        p = run(["t-blind", "expect"], timeout=60)
        self.assertEqual(p.returncode, 0, p.stdout + p.stderr)
        self.assertIn("448 B", p.stdout)  # in-path (Surface 1 + 3)
        self.assertIn("1024 B", p.stdout)  # full (adds Surface 2)
        self.assertIn("1,664 B [MODEL]", p.stdout)

    def test_freeze_rows(self):
        """freeze-check carries the UAGB1-BL rows and stays green (every
        pre-existing digest unmoved)."""
        p = run(["freeze-check"], timeout=300)
        self.assertEqual(p.returncode, 0, p.stdout[-3000:] + p.stderr[-3000:])
        self.assertIn("UAGB1-BL-1a", p.stdout)
        self.assertIn("UAGB1-BL-1b", p.stdout)
        self.assertIn("UAGB1-BL-1c", p.stdout)
        self.assertIn("freeze-check passed", p.stdout)

    def test_mode_refusal_names_actside_gap(self):
        """P1/P3 still refuse, and the message now names the ACT-side mask
        as the only remaining absent piece (the weight round polys ARE
        masked by this lane)."""
        p = run(["pass-agg", "prove", "2", "16", "p3"], timeout=120)
        self.assertNotEqual(p.returncode, 0)
        self.assertIn("ACTIVATION-side", p.stdout + p.stderr)

    @unittest.skipUnless(
        os.path.exists(EXPORTS),
        "m125 exports absent - run scripts/m125_export_ffn.py under the frugal venv",
    )
    def test_composed_p2_blind_smoke(self):
        """P2 + T_blind composed pass at 2 layers, T = 16 on REAL ckpt
        data: the weight round polynomials are masked, G/g_open grounded
        through the one weight-group opening, accept = true. Minutes-scale
        (level-0-dominated prover)."""
        p = run(["pass-agg", "prove", "2", "16", "p2"], timeout=3600)
        self.assertEqual(p.returncode, 0, p.stdout[-4000:] + p.stderr[-4000:])
        self.assertIn("accept true", p.stdout)
        self.assertIn("T_blind", p.stdout)


if __name__ == "__main__":
    unittest.main()
