# [UPERF-PC] U-PERF lane PC: wave/opening overhead — suite face.
# The differential battery (`uperf-pc diff-battery`) is toy-shape and
# always-run when the release binary exists. Full 125M wave-profile /
# pass-profile are lane/merge gates (minutes to an hour) and are NOT
# suite-sized.

import os
import subprocess
import unittest

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RS = os.path.join(REPO, "zkmatrix-rs")
BIN = os.path.join(RS, "target", "release", "ring_matmul")


def run(args, timeout):
    return subprocess.run(
        [BIN] + args, cwd=RS, capture_output=True, text=True, timeout=timeout
    )


@unittest.skipUnless(os.path.exists(BIN), "ring_matmul release binary not built")
class UPerfPc(unittest.TestCase):
    def test_diff_battery(self):
        """O1 CRS memo is byte-identical to the uncached XOF; O2/O3 (the
        NTT-domain level-h / matvec kernel) and O5 (the factored claim-
        kernel passes + the verifier's factored psi) hold byte identity
        against their Karatsuba / per-ring oracles at both moduli."""
        p = run(["uperf-pc", "diff-battery"], timeout=300)
        self.assertEqual(p.returncode, 0, (p.stdout or "")[-3000:] + (p.stderr or "")[-3000:])
        self.assertIn("O1 CRS memo: 4/4 byte-identical", p.stdout)
        self.assertIn("O2 level-h: 35/35 byte-identical", p.stdout)
        self.assertIn("O3 matvec: 63/63 byte-identical", p.stdout)
        self.assertIn("O5 kernel-pass: 12/12 byte-identical", p.stdout)
        self.assertIn("differential battery passed", p.stdout)
