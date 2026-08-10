"""[UAGB1-BI] U-AG-B1 wave 3 lane BI: the canonical wire format (M-05).

Drives `ring_matmul uagb1-bi` the way test_uagb1_agg.py drives the
aggregation stack. The suite face runs the LIGHT battery: golden-
sample canonicality + structural/value corruption legs, kind-1
round trips (degenerate + recursed) with verify-after-round-trip,
the kind-2 fold-transcript round trip at the 12x(64x96x128) battery
shape, kind-3 statement wraps with digest stability + pairing
negatives, and the kind-4 pass-artifact writer API. The FULL battery
(adds the Tier-Z round trip at 256x768x2048, ~1 min extra) is
`ring_matmul uagb1-bi wire-battery` — a lane/merge gate, not a
per-suite item. Wire-format stability itself is freeze row
UAGB1-BI-1 inside `freeze-check`.
"""

import shutil
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RUST_CRATE = ROOT / "zkmatrix-rs"
RING_MATMUL_BINARY = RUST_CRATE / "target" / "release" / "ring_matmul"


@unittest.skipIf(shutil.which("cargo") is None, "cargo is not installed")
class WireFormatTests(unittest.TestCase):
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

    def test_wire_battery_light(self):
        out = self.run_mode("uagb1-bi", "wire-battery", "light")
        self.assertIn("wire battery passed", out)
        # Round trips + verify-after-round-trip in the suite (exit
        # criterion): both kind-1 schedules and the kind-2 fold.
        self.assertIn("kind-1 degenerate: verify-after-round-trip ACCEPTS", out)
        self.assertIn("kind-1 recursed: verify-after-round-trip ACCEPTS", out)
        self.assertIn("kind-2 mm fold: verify-after-round-trip ACCEPTS", out)
        # Digest neutrality through the wire, both statement versions.
        self.assertIn("kind-3 v3: manifest bytes verbatim + digest UNMOVED", out)
        self.assertIn("kind-3 v4: manifest bytes verbatim + digest UNMOVED", out)
        # A corrupted byte rejects cleanly (no panic; the binary exits 0
        # only if every leg held).
        self.assertIn("golden structural corruption REJECTS cleanly: magic byte", out)
        self.assertNotIn("  FAIL ", out)
