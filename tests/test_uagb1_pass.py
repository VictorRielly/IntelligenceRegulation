"""U-AG-B1 lane BF: the manifest-v4 typed codec battery, the UAGB1-BF
freeze rows (per-scale SiLU table family + v3 digest stability), and a
pass-machinery smoke leg on the real 125M exports.

The full pass tamper battery (6 legs, ~7 min) runs via
`ring_matmul m125-pass battery small`; the full-shape per-layer proofs
via `ring_matmul m125-pass prove <layer>` (see M125_PASS_REPORT.md).
This module keeps the suite-budget subset: the v4 battery and freeze
rows always; the smoke leg (honest layer 0 at T = 16, ~75 s) requires
a complete read-only checkpoint export. Missing/invalid fixture configuration
fails visibly; see regression_fixtures.py for explicit/default selection.
"""

import pathlib
import subprocess
import unittest
from regression_fixtures import m125_environment

ROOT = pathlib.Path(__file__).resolve().parents[1]
BIN = ROOT / "zkmatrix-rs" / "target" / "release" / "ring_matmul"


def _run(args, timeout, requires_exports=False):
    return subprocess.run(
        [str(BIN), *args],
        cwd=ROOT,
        capture_output=True,
        text=True,
        timeout=timeout,
        env=m125_environment(ROOT) if requires_exports else None,
    )


@unittest.skipUnless(BIN.exists(), "release binary missing (cargo build --release)")
class UagB1PassTests(unittest.TestCase):
    def test_v4_statement_battery(self):
        """The one versioned codec change: every v4 positive/negative
        vector (typing, symmetric accumulators, class/base, table
        family, version gates, codec pairing)."""
        proc = _run(["m125-pass", "v4-battery"], timeout=120)
        self.assertEqual(proc.returncode, 0, proc.stdout + proc.stderr)
        self.assertIn("statement-v4 passed", proc.stdout)
        self.assertNotIn("FAIL", proc.stdout)

    def test_freeze_rows_uagb1_bf(self):
        """Freeze rows both directions: the silu-int8-table-v2 family
        (regeneration, the (-4,-4)==v1 identity, member separation,
        clamp-never-fires) and the v3 digest-stability pins — with every
        pre-existing freeze row still green."""
        proc = _run(["freeze-check"], timeout=300, requires_exports=True)
        self.assertEqual(proc.returncode, 0, proc.stdout + proc.stderr)
        self.assertIn("freeze-check passed", proc.stdout)
        for row in ["UAGB1-BF-1a", "UAGB1-BF-1b", "UAGB1-BF-1c",
                    "UAGB1-BF-1d", "UAGB1-BF-2a", "UAGB1-BF-2b",
                    "UAGB1-BF-2c"]:
            self.assertIn(row, proc.stdout)

    def test_pass_smoke_real_data(self):
        """The pass machinery end to end on real checkpoint data:
        honest layer 0 at T = 16 — statement gate, 3 matmul sumchecks,
        Hadamard, requant pins, 8 lookup instances, masked wave rounds,
        closing — ACCEPT."""
        proc = _run(["m125-pass", "battery", "smoke"], timeout=900, requires_exports=True)
        self.assertEqual(proc.returncode, 0, proc.stdout + proc.stderr)
        self.assertIn("honest layer 0 ACCEPT", proc.stdout)
        self.assertIn("pass smoke passed", proc.stdout)


if __name__ == "__main__":
    unittest.main()
