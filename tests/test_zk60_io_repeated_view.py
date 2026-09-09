import copy
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
import zk60_io_repeated_view as repeated

DIRECTORY = repeated.ROOT / "results/zk60_round22_captures"


@unittest.skipUnless(DIRECTORY.is_dir(), "round-22 fresh captures unavailable")
class RepeatedView(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.captures = [repeated.O.IoCapture(str(path)) for path in sorted(DIRECTORY.glob("*.json"))]
        cls.p1 = [c for c in cls.captures if c.privacy == "P1"]
        cls.p3 = [c for c in cls.captures if c.privacy == "P3"]
        assert len(cls.p1) == len(cls.p3) == 2

    def test_duplicate_and_mixed_mode_proofs_are_refused(self):
        with self.assertRaisesRegex(ValueError, "duplicate proof"):
            repeated.check_pair([self.p1[0], self.p1[0]])
        with self.assertRaisesRegex(ValueError, "mixed privacy"):
            repeated.check_pair([self.p1[0], self.p3[0]])

    def test_different_policy_and_reused_root_are_refused(self):
        changed = copy.copy(self.p1[1])
        changed.expected_policy = dict(changed.expected_policy, context="00" * 32)
        with self.assertRaisesRegex(ValueError, "metadata"):
            repeated.check_pair([self.p1[0], changed])
        changed = copy.copy(self.p1[1])
        changed.mask = dict(changed.mask, root=self.p1[0].mask["root"])
        with self.assertRaisesRegex(ValueError, "reused private root"):
            repeated.check_pair([self.p1[0], changed])

    def test_two_encodings_share_only_data_and_keep_all_proximity_coordinates(self):
        model, meta = repeated.model(self.p1, {"Input"})
        self.assertEqual(model.rows, 12)  # 7 + 7 - two shared data rows
        self.assertEqual(model.nb, 8)  # two groups AND two separate proximity vectors
        self.assertEqual(len(meta["aliases"]), 2)
        for left, right in meta["aliases"]:
            self.assertIn(left[1], (0, 1))
            self.assertEqual(left[1], right[1])
        result = model.analyze(planes=False)
        explicit = model.explicit_per_column()
        self.assertEqual(result["joint"]["disclosed_total"], 0)
        self.assertEqual(result["per_column"]["rank_mask"], explicit["rank_mask"])
        self.assertEqual(result["per_column"]["rank_joint"], explicit["rank_joint"])

    def test_one_leaking_proof_is_not_hidden_by_a_second_honest_proof(self):
        model, _ = repeated.model(self.p1, {"Input"}, ablate_first_input=True)
        self.assertEqual(model.analyze(planes=False)["joint"]["disclosed_total"], 256)

    def test_each_h_retains_its_constraint_without_aliasing_challenge_dependent_data(self):
        model, meta = repeated.model(self.p1, {"H"})
        self.assertEqual(meta["aliases"], [])
        self.assertEqual(model.rows, 2 * 1326)
        self.assertEqual(len(meta["extras"]), 2)
        self.assertEqual(len(meta["identities"]), 2)
        self.assertTrue(set(meta["extras"][0]["coefs"]).isdisjoint(meta["extras"][1]["coefs"]))
        self.assertEqual(model.analyze(planes=False)["joint"]["disclosed_total"], 4)


if __name__ == "__main__":
    unittest.main()
