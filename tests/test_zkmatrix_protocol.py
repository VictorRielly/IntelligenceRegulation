import dataclasses
import random
import unittest
from hashlib import sha256

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
from zk_matrix.protocol import commit_matrix
from zk_matrix.transcript import transcript_bytes


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

    def test_zk_wrapper_accepts_valid_rectangular_product(self):
        # Rectangular claim: A 2x4, B 4x8, C 2x8. The reference bases carry
        # (rows, inner, cols) natively; this locks the rectangular path so
        # it stays a valid differential oracle for the native backends.
        group = make_group("small-subgroup")
        rng = random.Random(47)
        bases = make_bases(group, 2, 4, 8, b"test-zk-rect-valid")
        a = random_matrix(2, 4, group.q, rng=rng, max_entry=20)
        b = random_matrix(4, 8, group.q, rng=rng, max_entry=20)
        c = matrix_multiply(a, b, group.q)
        statement, witness = commit_matmul(group, bases, a, b, c, blinded=True, rng=rng)

        proof = prove_zk_matmul(group, bases, statement, witness, rng=rng)

        self.assertTrue(verify_zk_matmul(group, bases, statement, proof))

    def test_zk_wrapper_rejects_wrong_rectangular_product(self):
        group = make_group("small-subgroup")
        rng = random.Random(59)
        bases = make_bases(group, 2, 4, 8, b"test-zk-rect-invalid")
        a = random_matrix(2, 4, group.q, rng=rng, max_entry=20)
        b = random_matrix(4, 8, group.q, rng=rng, max_entry=20)
        c = matrix_multiply(a, b, group.q)
        c[1][3] = (c[1][3] + 5) % group.q
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

    def _valid_zk_setup(self, seed=71, label=b"test-zk-tamper"):
        group = make_group("small-subgroup")
        rng = random.Random(seed)
        bases = make_bases(group, 2, 2, 2, label)
        a = random_matrix(2, 2, group.q, rng=rng, max_entry=20)
        b = random_matrix(2, 2, group.q, rng=rng, max_entry=20)
        c = matrix_multiply(a, b, group.q)
        statement, witness = commit_matmul(group, bases, a, b, c, blinded=True, rng=rng)
        proof = prove_zk_matmul(group, bases, statement, witness, rng=rng)
        return group, bases, statement, proof

    def test_zk_proof_rejects_tampering_with_each_subproof(self):
        group, bases, statement, proof = self._valid_zk_setup()
        self.assertTrue(verify_zk_matmul(group, bases, statement, proof))

        def tampered_projection(sub):
            return dataclasses.replace(
                sub, mask_commitment=group.scale(sub.mask_commitment, 2)
            )

        tampered_proofs = [
            # Each of the four sub-proofs, tampered independently.
            dataclasses.replace(
                proof, c_projection_proof=tampered_projection(proof.c_projection_proof)
            ),
            dataclasses.replace(
                proof, a_projection_proof=tampered_projection(proof.a_projection_proof)
            ),
            dataclasses.replace(
                proof, b_projection_proof=tampered_projection(proof.b_projection_proof)
            ),
            dataclasses.replace(
                proof,
                product_projection_proof=dataclasses.replace(
                    proof.product_projection_proof,
                    alpha_commitment=group.scale(
                        proof.product_projection_proof.alpha_commitment, 2
                    ),
                ),
            ),
            # Response blinds, independently per sub-proof family.
            dataclasses.replace(
                proof,
                c_projection_proof=dataclasses.replace(
                    proof.c_projection_proof,
                    response_blind=(proof.c_projection_proof.response_blind + 1)
                    % group.q,
                ),
            ),
            dataclasses.replace(
                proof,
                product_projection_proof=dataclasses.replace(
                    proof.product_projection_proof,
                    output_response_blind=(
                        proof.product_projection_proof.output_response_blind + 1
                    )
                    % group.q,
                ),
            ),
            # Top-level linking commitments.
            dataclasses.replace(
                proof, d_commitment=group.scale(proof.d_commitment, 2)
            ),
            dataclasses.replace(
                proof, ay_commitment=group.scale(proof.ay_commitment, 2)
            ),
            dataclasses.replace(
                proof, by_commitment=group.scale(proof.by_commitment, 2)
            ),
        ]
        for index, tampered in enumerate(tampered_proofs):
            with self.subTest(tamper=index):
                self.assertFalse(verify_zk_matmul(group, bases, statement, tampered))

    def test_zk_proof_rejects_swapped_subproof_components(self):
        # Square shape so the a- and b-projection components have equal sizes;
        # swapping them across sub-proofs must still fail.
        group, bases, statement, proof = self._valid_zk_setup(seed=73)
        swapped = dataclasses.replace(
            proof,
            a_projection_proof=dataclasses.replace(
                proof.a_projection_proof,
                mask_commitment=proof.b_projection_proof.mask_commitment,
            ),
            b_projection_proof=dataclasses.replace(
                proof.b_projection_proof,
                mask_commitment=proof.a_projection_proof.mask_commitment,
            ),
        )
        self.assertFalse(verify_zk_matmul(group, bases, statement, swapped))

    def test_zero_blind_commitment_matches_unblinded(self):
        # Blinding is applied unconditionally; a zero blind must produce the
        # same commitment value as omitting the blinding term entirely.
        group = make_group("small-subgroup")
        bases = make_bases(group, 2, 2, 2, b"test-zero-blind")
        matrix = [[3, 5], [7, 11]]
        unblinded = commit_matrix(group, matrix, bases.a_bases)
        zero_blinded = commit_matrix(
            group, matrix, bases.a_bases, bases.blind_base, 0
        )
        self.assertEqual(unblinded, zero_blinded)

    def test_transcript_kat_locks_decoupling_challenges(self):
        # Known-answer test over the full proof transcript. This digest was
        # recorded after the fresh decoupling challenge x was added to all
        # four sub-proofs (review note P0); it fails if the challenge
        # derivation or the combined-commitment structure regresses.
        group = make_group("toy")
        rng = random.Random(2026)
        bases = make_bases(group, 2, 2, 2, b"test-kat")
        a = random_matrix(2, 2, group.q, rng=rng, max_entry=20)
        b = random_matrix(2, 2, group.q, rng=rng, max_entry=20)
        c = matrix_multiply(a, b, group.q)
        statement, witness = commit_matmul(group, bases, a, b, c)
        core_proof = prove_core_matmul(group, bases, statement, witness)
        self.assertTrue(verify_core_matmul(group, bases, statement, core_proof))
        digest = sha256(transcript_bytes(statement, core_proof)).hexdigest()
        self.assertEqual(digest, CORE_PROOF_KAT_DIGEST)


CORE_PROOF_KAT_DIGEST = (
    "ec778c373cede567cd920f10608f8659de0b46c1c1320fd5c3c3aa16838b6180"
)


if __name__ == "__main__":
    unittest.main()
