"""Statement v3 negative vectors (audit 2026-07-12 Phase 2 exit, U-S P2).

Drives the native binaries the same way test_zkmatrix_native_backends.py
does. The battery itself lives in zkmatrix-rs/src/manifest.rs
(statement_negative_battery) because statement validation is metadata-only
and backend-free; the lattice binary hosts the CLI mode. Coverage per the
remediation plan's Phase 2 exit line: inconsistent fraction bits, the
+2^(w-1) signed endpoint, cycles, empty add, wrong table digest/scale,
dangling roles (dangling ids, orphan entries, unproduced outputs), and
noncanonical padding — plus the v3-new gates (empty operation lists,
topological ordering, output visibility, modulus capacity).
"""

import shutil
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RUST_CRATE = ROOT / "zkmatrix-rs"
LATTICE_MATMUL_BINARY = RUST_CRATE / "target" / "release" / "lattice_matmul"
RING_MATMUL_BINARY = RUST_CRATE / "target" / "release" / "ring_matmul"


@unittest.skipIf(shutil.which("cargo") is None, "cargo is not installed")
class StatementV3Tests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        subprocess.run(["cargo", "build", "--release"], cwd=RUST_CRATE, check=True)

    def run_mode(self, binary, *args):
        result = subprocess.run(
            [str(binary), *args],
            check=True,
            text=True,
            stdout=subprocess.PIPE,
        )
        return result.stdout

    def test_statement_negative_battery(self):
        # Every exit-list vector rejects with its exact structured error,
        # and the honest base statement validates with a deterministic,
        # tamper-sensitive digest.
        out = self.run_mode(LATTICE_MATMUL_BINARY, "statement-negatives")
        self.assertIn("statement-negatives passed", out)
        self.assertNotIn("FAIL", out)
        # Spot-pin the exit list so a battery edit cannot silently drop a
        # vector class.
        for needle in [
            "rescale fraction-bit lie under a narrowing fact",
            "signed +2^(w-1) accumulator endpoint",
            "cyclic dataflow",
            "empty Add",
            "attacker-chosen table digest",
            "table spec scale lie",
            "dangling operand id",
            "noncanonical padding",
            "non-topological operation order",
            "entry wider than the modulus",
        ]:
            self.assertIn(needle, out)

    def test_lattice_gadget_demo_validated_statement(self):
        # M2 gadget family end-to-end with its transcript context derived
        # from the VALIDATED v3 statement (positive control for the port;
        # this mode was previously outside the suite). Small shape.
        out = self.run_mode(
            LATTICE_MATMUL_BINARY, "gadget-demo", "4", "8", "8", "6", "9"
        )
        self.assertIn("lattice gadget-demo ok", out)

    def test_ring_statement_inventory_validates(self):
        # The 32-layer FFN surrogate statement (737 entries) validates
        # under v3: scale-consistent rescales, asymmetric signed bounds,
        # topological order, canonical padding, q31 modulus capacity.
        out = self.run_mode(RING_MATMUL_BINARY, "statement-inventory")
        self.assertIn("ok   statement validates", out)

    def test_ring_statement_codec(self):
        # U-S Phase 3 (P3-D2): canonical PublicStatement codec — round-trip
        # canonicality, digest preservation, and every malformed-input class
        # (truncation/trailing/bad-magic/bad-version/oversized/invalid) plus
        # a 4000-input bit-flip fuzz decode to structured errors, no panics.
        out = self.run_mode(RING_MATMUL_BINARY, "statement-codec")
        self.assertIn("statement-codec passed", out)
        self.assertNotIn("FAIL", out)
        for needle in [
            "round-trip",
            "trailing bytes rejected",
            "oversized length prefix rejected",
            "decoded-but-invalid statement rejected",
            "zero panics",
        ]:
            self.assertIn(needle, out)

    def test_ring_p3_proof_artifact(self):
        # U-S Phase 3 (P3-D1..D5): the COMPLETE committed masked-lookup proof
        # — statement+proof canonical bytes verified by a FRESH ring_matmul
        # process (no prover-local state), model_digest/commitment/descent
        # tampers reject, and a 4000-input malformed-proof fuzz never panics.
        out = self.run_mode(RING_MATMUL_BINARY, "p3-battery")
        self.assertNotIn("FAIL", out)
        for needle in [
            "P3 honest committed lookup ACCEPTS in-process",
            "serialization round-trip verifies",
            "P3 two-process: a SECOND process ACCEPTS",
            "P3 model_digest tamper REJECTS",
            "P3 commitment swap REJECTS",
            "P3 descent tamper REJECTS",
            "without a single panic",
        ]:
            self.assertIn(needle, out)


if __name__ == "__main__":
    unittest.main()
