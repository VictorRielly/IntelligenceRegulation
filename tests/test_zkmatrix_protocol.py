import random
import unittest

from zk_matrix import (
    commit_matmul,
    make_group,
    matrix_multiply,
    prove_naive_zk_matmul,
    prove_core_matmul,
    prove_zk_matmul,
    random_matrix,
    verify_naive_zk_matmul,
    verify_core_matmul,
    verify_zk_matmul,
)
from zk_matrix import make_bases


class ZkMatrixProtocolTests(unittest.TestCase):
    def test_core_proof_accepts_valid_product(self):
        group = make_group("small-subgroup")
        rng = random.Random(17)
        bases = make_bases(group, 2, 3, 2, b"test-core-valid")
        a = random_matrix(2, 3, group.q, rng=rng, max_entry=20)
        b = random_matrix(3, 2, group.q, rng=rng, max_entry=20)
        c = matrix_multiply(a, b, group.q)
        statement, witness = commit_matmul(group, bases, a, b, c)

        proof = prove_core_matmul(group, bases, statement, witness)

        self.assertTrue(verify_core_matmul(group, bases, statement, proof))

    def test_core_proof_rejects_wrong_product(self):
        group = make_group("small-subgroup")
        rng = random.Random(23)
        bases = make_bases(group, 2, 2, 3, b"test-core-invalid")
        a = random_matrix(2, 2, group.q, rng=rng, max_entry=20)
        b = random_matrix(2, 3, group.q, rng=rng, max_entry=20)
        c = matrix_multiply(a, b, group.q)
        c[0][0] = (c[0][0] + 1) % group.q
        statement, witness = commit_matmul(group, bases, a, b, c)

        proof = prove_core_matmul(group, bases, statement, witness)

        self.assertFalse(verify_core_matmul(group, bases, statement, proof))

    def test_zk_wrapper_accepts_valid_product(self):
        group = make_group("small-subgroup")
        rng = random.Random(31)
        bases = make_bases(group, 2, 2, 2, b"test-zk-valid")
        a = random_matrix(2, 2, group.q, rng=rng, max_entry=20)
        b = random_matrix(2, 2, group.q, rng=rng, max_entry=20)
        c = matrix_multiply(a, b, group.q)
        statement, witness = commit_matmul(group, bases, a, b, c, blinded=True, rng=rng)

        proof = prove_zk_matmul(group, bases, statement, witness, rng=rng)

        self.assertTrue(verify_zk_matmul(group, bases, statement, proof))

    def test_zk_wrapper_rejects_wrong_product(self):
        group = make_group("small-subgroup")
        rng = random.Random(43)
        bases = make_bases(group, 2, 2, 2, b"test-zk-invalid")
        a = random_matrix(2, 2, group.q, rng=rng, max_entry=20)
        b = random_matrix(2, 2, group.q, rng=rng, max_entry=20)
        c = matrix_multiply(a, b, group.q)
        c[1][1] = (c[1][1] + 7) % group.q
        statement, witness = commit_matmul(group, bases, a, b, c, blinded=True, rng=rng)

        proof = prove_zk_matmul(group, bases, statement, witness, rng=rng)

        self.assertFalse(verify_zk_matmul(group, bases, statement, proof))

    def test_naive_algorithm_5_wrapper_accepts_valid_product(self):
        group = make_group("small-subgroup")
        rng = random.Random(53)
        bases = make_bases(group, 2, 2, 2, b"test-naive-zk-valid")
        a = random_matrix(2, 2, group.q, rng=rng, max_entry=20)
        b = random_matrix(2, 2, group.q, rng=rng, max_entry=20)
        c = matrix_multiply(a, b, group.q)
        statement, witness = commit_matmul(group, bases, a, b, c, blinded=True, rng=rng)

        proof = prove_naive_zk_matmul(group, bases, statement, witness, rng=rng)

        self.assertTrue(verify_naive_zk_matmul(group, bases, statement, proof))


if __name__ == "__main__":
    unittest.main()
