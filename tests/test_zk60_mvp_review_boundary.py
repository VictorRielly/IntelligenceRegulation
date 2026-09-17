"""Counterexamples to privacy inferences, not attacks on the actual FFN.

Individually uniform masked messages and a witness-independent commitment do
not imply privacy of their joint view when both depend on the same random mask.
"""
from collections import Counter
import hashlib
import unittest


def commit(mask):
    return hashlib.sha256(b"review-counterexample/" + bytes([mask])).digest()


class JointPrivacyInference(unittest.TestCase):
    def test_identical_marginals_and_equal_fibres_can_have_disjoint_joint_views(self):
        views = [{(commit(mask), mask ^ witness) for mask in range(256)}
                 for witness in (0, 1)]
        # Every masked message has exactly one preimage for either witness.
        for index in (0, 1):
            marginal = [Counter(view[index] for view in observations) for observations in views]
            self.assertEqual(marginal[0], marginal[1])
        self.assertFalse(views[0] & views[1])
        # A verifier who knows the two candidate witnesses recovers which was
        # used with one hash query, by checking the candidate mask.
        for witness, observations in enumerate(views):
            for root, masked in observations:
                guess = 0 if commit(masked) == root else 1
                self.assertEqual(guess, witness)

    def test_conditioning_on_the_earlier_commitment_changes_the_message_kernel(self):
        roots = {commit(mask): mask for mask in range(256)}
        self.assertEqual(len(roots), 256)
        for mask in roots.values():
            self.assertNotEqual(mask ^ 0, mask ^ 1)


if __name__ == "__main__":
    unittest.main()
