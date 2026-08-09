"""U-AG-B1 lane BE (wave 2): the IXF fold battery as a suite member.

Drives `ring_matmul ixf-fold battery` — the engine-scale
index-extension-folding battery (stacked zero-check + joint matmul
fold at toy AND 12-layer counts, cross-layer swap, the early-draw F5
pairs both directions, the padded-slot tamper, the AZB-10a
segment-map F5 pair, the FD-L2 naive-fold negative) — and the
`ixf-fold norm` measurement legs. The UAGB1-BE freeze rows ride the
existing freeze-check test (test_zkmatrix_native_backends).
"""

import shutil
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RUST_CRATE = ROOT / "zkmatrix-rs"
RING_MATMUL_BINARY = RUST_CRATE / "target" / "release" / "ring_matmul"


@unittest.skipIf(shutil.which("cargo") is None, "cargo is not installed")
class IxfFoldTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        subprocess.run(["cargo", "build", "--release"], cwd=RUST_CRATE, check=True)

    def test_ixf_fold_battery(self):
        result = subprocess.run(
            [str(RING_MATMUL_BINARY), "ixf-fold", "battery"],
            check=True,
            text=True,
            stdout=subprocess.PIPE,
        )
        self.assertIn("battery passed", result.stdout)
        # assert_true's failure marker is the line prefix "  FAIL " —
        # a bare "FAIL" substring would trip on leg labels ("... FAILS
        # the outside-fold check").
        self.assertNotIn("\n  FAIL ", result.stdout)

    def test_ixf_fold_norm_measurement(self):
        result = subprocess.run(
            [str(RING_MATMUL_BINARY), "ixf-fold", "norm"],
            check=True,
            text=True,
            stdout=subprocess.PIPE,
        )
        self.assertIn("STACKED law at engine ring", result.stdout)
        self.assertNotIn("\n  FAIL ", result.stdout)


if __name__ == "__main__":
    unittest.main()
