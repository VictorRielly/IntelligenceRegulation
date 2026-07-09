import shutil
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RUST_CRATE = ROOT / "zkmatrix-rs"
RING_MATMUL_BINARY = RUST_CRATE / "target" / "release" / "ring_matmul"


@unittest.skipIf(shutil.which("cargo") is None, "cargo is not installed")
class ModulusLinkTests(unittest.TestCase):
    """U-L (F3 resolution): the q8_31 <-> q8_46 modulus link.

    Values committed at q8_31, their bit planes at the dedicated q8_46
    gadget layer, tied by l = 24 FS-derived structured-weight rows with
    revealed integers y_l (grounding gate |y_l| < q46/2) and one linear
    ct-claim family per side. The demo runs the frozen point (n = 128,
    W = 4, w = 11, l = 24) with the negative battery: tampered bit,
    tampered value, oversized y, stale-xi (the F5 ordering mode).
    See docs/zkmatrix-poc/GADGET_MODULUS_DECISION.md and ring/link.rs.
    """

    @classmethod
    def setUpClass(cls):
        subprocess.run(["cargo", "build", "--release"], cwd=RUST_CRATE, check=True)

    def test_ring_link_demo(self):
        result = subprocess.run(
            [str(RING_MATMUL_BINARY), "link-demo"],
            check=True,
            text=True,
            stdout=subprocess.PIPE,
        )
        self.assertIn("honest link verifies", result.stdout)
        self.assertIn("link-demo passed", result.stdout)


if __name__ == "__main__":
    unittest.main()
