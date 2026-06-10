import shutil
import subprocess
import unittest
from pathlib import Path

from zk_matrix import (
    commit_matmul,
    make_bases,
    make_group,
    matrix_multiply,
    prove_core_matmul,
    prove_zk_matmul,
    random_matrix,
    verify_core_matmul,
    verify_zk_matmul,
)


ROOT = Path(__file__).resolve().parents[1]
RUST_CRATE = ROOT / "zkmatrix-rs"
RUST_BINARY = RUST_CRATE / "target" / "release" / "zkmatrix-rs"
SECTION3_BINARY = RUST_CRATE / "target" / "release" / "section3_kzg"
CURVE_IPA_BINARY = RUST_CRATE / "target" / "release" / "curve_ipa"


def python_case(mode: str, n: int, seed: int, valid: bool) -> bool:
    import random

    group = make_group("toy")
    rng = random.Random(seed)
    bases = make_bases(group, n, n, n, f"native-test-{mode}-{n}-{seed}".encode())
    a = random_matrix(n, n, group.q, rng=rng, max_entry=64)
    b = random_matrix(n, n, group.q, rng=rng, max_entry=64)
    c = matrix_multiply(a, b, group.q)
    if not valid:
        c[0][0] = (c[0][0] + 1) % group.q
    statement, witness = commit_matmul(
        group, bases, a, b, c, blinded=(mode == "zk"), rng=rng
    )
    if mode == "core":
        proof = prove_core_matmul(group, bases, statement, witness)
        return verify_core_matmul(group, bases, statement, proof)
    proof = prove_zk_matmul(group, bases, statement, witness, rng=rng)
    return verify_zk_matmul(group, bases, statement, proof)


@unittest.skipIf(shutil.which("cargo") is None, "cargo is not installed")
class NativeBackendTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        subprocess.run(["cargo", "build", "--release"], cwd=RUST_CRATE, check=True)

    def rust_case(self, mode: str, n: int, seed: int, valid: bool) -> bool:
        result = subprocess.run(
            [
                str(RUST_BINARY),
                "case",
                mode,
                str(n),
                str(seed),
                "valid" if valid else "invalid",
            ],
            check=True,
            text=True,
            stdout=subprocess.PIPE,
        )
        return "verified=true" in result.stdout

    def test_rust_accept_reject_matches_python_protocol(self):
        for mode in ["core", "zk"]:
            for n in [2, 4, 8]:
                with self.subTest(mode=mode, n=n, valid=True):
                    self.assertTrue(python_case(mode, n, 1000 + n, True))
                    self.assertTrue(self.rust_case(mode, n, 1000 + n, True))
                with self.subTest(mode=mode, n=n, valid=False):
                    self.assertFalse(python_case(mode, n, 2000 + n, False))
                    self.assertFalse(self.rust_case(mode, n, 2000 + n, False))

    def test_section3_kzg_self_test(self):
        subprocess.run([str(SECTION3_BINARY), "self-test"], check=True)

    def test_curve_ipa_self_test(self):
        subprocess.run([str(CURVE_IPA_BINARY), "self-test"], check=True)


if __name__ == "__main__":
    unittest.main()
