from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
import zk60_endpoint_simulation as sim


class DeferredPreparation(unittest.TestCase):
    def setUp(self):
        self.oracle = sim.RandomOracle()
        self.owner = sim.PreparedSimulation(self.oracle)
        self.indices = [i % 128 for i in range(256)]
        self.columns = [[i + row for row in range(7)] for i in self.indices]

    def test_early_root_and_answers_stay_fixed_through_adaptive_column_choice(self):
        root = self.owner.root
        prior = dict(self.oracle.table)
        # The values depend on the root, so they could not be fixed before prep.
        self.columns = [[(word + root[0]) % sim.P for word in col] for col in self.columns]
        opened = self.owner.open_once(root, self.indices, self.columns)
        self.assertEqual(root, self.owner.root)
        self.assertTrue(all(sim.verify(self.oracle, root, *op) for op in opened))
        self.assertTrue(all(self.oracle.table[key] == value for key, value in prior.items()))
        self.assertEqual(len(self.oracle.programmed), 128)
        self.assertEqual(opened[0], opened[128])

    def test_external_root_is_refused_and_failure_consumes_owner(self):
        foreign = sim.PreparedSimulation(self.oracle).root
        with self.assertRaisesRegex(sim.Refused, "not issued"):
            self.owner.open_once(foreign, self.indices, self.columns)
        with self.assertRaisesRegex(sim.Refused, "consumed"):
            self.owner.open_once(self.owner.root, self.indices, self.columns)

    def test_reusing_owner_is_refused_after_success(self):
        self.owner.open_once(self.owner.root, self.indices, self.columns)
        with self.assertRaisesRegex(sim.Refused, "consumed"):
            self.owner.open_once(self.owner.root, self.indices, self.columns)

    def test_conflicting_duplicate_does_not_return_an_opening(self):
        self.columns[128] = [99] * 7
        with self.assertRaisesRegex(sim.Refused, "duplicate"):
            self.owner.open_once(self.owner.root, self.indices, self.columns)
        self.assertTrue(self.owner.spent)

    def test_programming_rejects_prequeried_leaf_point(self):
        salt = b"s" * 32
        inner = self.oracle.query(sim.column_bytes(self.columns[0]))
        answer = self.oracle.query(inner + salt)
        self.oracle.random_bytes = lambda count: salt
        with self.assertRaisesRegex(sim.Refused, "already answered"):
            self.owner.open_once(self.owner.root, self.indices, self.columns)
        self.assertEqual(self.oracle.table[inner + salt], answer)

    def test_node_query_and_salted_leaf_programming_are_not_independent(self):
        left, right = b"a" * 32, b"b" * 32
        answer = sim.node(self.oracle, left, right)
        with self.assertRaisesRegex(sim.Refused, "already answered"):
            self.oracle.program_fresh(left + right, b"c" * 32)
        self.assertEqual(self.oracle.query(left + right), answer)

    def test_tampered_column_path_and_root_reject(self):
        op = self.owner.open_once(self.owner.root, self.indices, self.columns)[0]
        index, values, salt, path = op
        self.assertFalse(sim.verify(self.oracle, self.owner.root, index, [v + 1 for v in values], salt, path))
        self.assertFalse(sim.verify(self.oracle, self.owner.root, index ^ 1, values, salt, path))
        self.assertFalse(sim.verify(self.oracle, b"x" * 32, *op))

    def test_query_budget_and_noncanonical_words_refuse(self):
        with self.assertRaisesRegex(sim.Refused, "256"):
            self.owner.open_once(self.owner.root, self.indices + [0], self.columns + [[0] * 7])
        for value in (True, -1, sim.P):
            with self.subTest(value=value), self.assertRaisesRegex(sim.Refused, "canonical"):
                sim.column_bytes([value] * 7)


if __name__ == "__main__":
    unittest.main()
