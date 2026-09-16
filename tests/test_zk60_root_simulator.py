"""Ideal-oracle bookkeeping for the joint and root-only endpoint simulators.

Exercises scripts/zk60_root_simulator.py: path verification in both worlds,
programmed-point counts, the two negative controls (collision detection that fires
only when the distinguisher holds the honest top pair; refusal of a pre-answered
top pair), secrecy of the honest committer's state, and the refusal discipline.
Nothing here is a statement about BLAKE3 or about the whole proof.
"""
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
import zk60_root_simulator as rs


class SharedFixture(unittest.TestCase):
    def setUp(self):
        self.random_bytes = rs.seeded_bytes(7)
        self.oracle = rs.RandomOracle(self.random_bytes)
        self.indices = rs.query_positions()
        self.assertEqual(len(self.indices), 256)
        self.assertEqual(len(set(self.indices)), 240)


class BothWorldsVerify(SharedFixture):
    def test_joint_paths_verify_under_issued_roots_including_duplicates(self):
        sims, dist = rs.run_joint(self.oracle, self.indices)
        self.assertEqual(len(dist.openings), 512)
        self.assertTrue(dist.verify_all())
        for sim in sims:
            opened = [op for root, op in dist.openings if root == sim.root]
            self.assertEqual(opened[0], opened[240])  # duplicate index, identical answer
            self.assertEqual(len({op[0] for op in opened}), 240)
            self.assertTrue(all(op[1] == [0] * 7 for op in opened))

    def test_root_only_paths_verify_under_the_fixed_honest_roots(self):
        committers, sims, dist = rs.run_root_only(self.oracle, self.indices, self.random_bytes)
        self.assertEqual([s.root for s in sims], [c.root for c in committers])
        self.assertEqual(len(dist.openings), 512)
        self.assertTrue(dist.verify_all())
        for sim in sims:
            opened = [op for root, op in dist.openings if root == sim.root]
            self.assertEqual(opened[0], opened[240])
            # Every path's last sibling is one half of the programmed top pair.
            halves = {sim.programmed_point[:32], sim.programmed_point[32:]}
            self.assertTrue(all(op[3][-1] in halves for op in opened))

    def test_verify_rejects_tampering_in_both_worlds(self):
        _, joint_dist = rs.run_joint(self.oracle, self.indices)
        _, _, root_dist = rs.run_root_only(self.oracle, self.indices, self.random_bytes)
        for dist in (joint_dist, root_dist):
            root, (index, values, salt, path) = dist.openings[3]
            self.assertFalse(rs.verify(self.oracle, root, index, [v + 1 for v in values], salt, path))
            self.assertFalse(rs.verify(self.oracle, root, index ^ 1, values, salt, path))
            self.assertFalse(rs.verify(self.oracle, root, index, values, bytes(32), path))
            self.assertFalse(rs.verify(self.oracle, bytes(32), index, values, salt, path))


class ProgrammedPointCounts(SharedFixture):
    def test_joint_programs_nothing(self):
        sims, _ = rs.run_joint(self.oracle, self.indices)
        self.assertEqual(len(self.oracle.programmed), 0)
        self.assertEqual([s.programmed_points for s in sims], [0, 0])

    def test_root_only_programs_exactly_one_point_per_root(self):
        committers, sims, _ = rs.run_root_only(self.oracle, self.indices, self.random_bytes)
        self.assertEqual(len(self.oracle.programmed), 2)
        self.assertEqual([s.programmed_points for s in sims], [1, 1])
        for committer, sim in zip(committers, sims):
            self.assertIn(sim.programmed_point, self.oracle.programmed)
            self.assertEqual(len(sim.programmed_point), 64)
            self.assertEqual(self.oracle.table[sim.programmed_point], committer.root)
            left, right = committer.secret_top_pair()
            self.assertNotEqual(sim.programmed_point, left + right)

    def test_salted_leaf_and_node_share_the_table(self):
        inner, salt = b"i" * 32, b"s" * 32
        answer = rs.salt_leaf(self.oracle, inner, salt)
        self.assertEqual(rs.node(self.oracle, inner, salt), answer)
        with self.assertRaisesRegex(rs.Refused, "already answered"):
            self.oracle.program_fresh(inner + salt, bytes(32))
        with self.assertRaisesRegex(rs.Refused, "64-byte"):
            self.oracle.program_fresh(b"x" * 56, bytes(32))


class CollisionDetectionNegativeControl(SharedFixture):
    """The detection fires only when the distinguisher holds the honest top pair, and only in the simulated world."""

    def setUp(self):
        super().setUp()
        self.committer = rs.HonestCommitter(self.oracle, rs.hidden_columns(self.random_bytes))
        self.root = self.committer.root

    def _serve_simulated(self, dist):
        sim = rs.RootOnlySim(self.oracle, self.root)
        dist.receive_openings(self.root, sim.open_once(self.root, self.indices))
        self.assertTrue(dist.verify_all())

    def test_informed_distinguisher_detects_two_preimages_in_the_simulated_world(self):
        dist = rs.Distinguisher(self.oracle)
        left, right = self.committer.secret_top_pair()
        self.assertEqual(dist.query(left + right), self.root)   # queried BEFORE the simulation
        self.assertFalse(dist.collision_detected(self.root))    # one preimage so far
        self._serve_simulated(dist)
        self.assertTrue(dist.collision_detected(self.root))
        self.assertEqual(len(dist.preimages(self.root)), 2)

    def test_uninformed_distinguisher_sees_one_preimage_in_the_simulated_world(self):
        dist = rs.Distinguisher(self.oracle)
        self._serve_simulated(dist)
        self.assertFalse(dist.collision_detected(self.root))
        self.assertEqual(len(dist.preimages(self.root)), 1)

    def test_informed_distinguisher_sees_one_preimage_in_the_real_world(self):
        dist = rs.Distinguisher(self.oracle)
        left, right = self.committer.secret_top_pair()
        dist.query(left + right)
        dist.receive_openings(self.root, self.committer.open_once(self.root, self.indices))
        self.assertTrue(dist.verify_all())
        self.assertFalse(dist.collision_detected(self.root))
        self.assertEqual(dist.preimages(self.root), {left + right})

    def test_no_collision_in_the_joint_world_even_when_informed_about_other_roots(self):
        dist = rs.Distinguisher(self.oracle)
        left, right = self.committer.secret_top_pair()
        dist.query(left + right)
        for sim in (rs.JointSim(self.oracle), rs.JointSim(self.oracle)):
            dist.receive_openings(sim.root, sim.open_once(sim.root, self.indices))
        self.assertTrue(dist.verify_all())
        self.assertFalse(any(dist.collision_detected(r) for r in dist.roots + [self.root]))


class PreAnsweredTopPairRefuses(SharedFixture):
    def test_program_fresh_refuses_when_the_fresh_top_pair_is_already_answered(self):
        committer = rs.HonestCommitter(self.oracle, rs.hidden_columns(self.random_bytes))
        fixed = lambda count: b"s" * count
        prior = rs.JointSim(self.oracle, salt_bytes=fixed)  # ordinary root query answers the same top pair
        top_pair = prior._levels[rs.DEPTH - 1][0] + prior._levels[rs.DEPTH - 1][1]
        before = dict(self.oracle.table)
        with self.assertRaisesRegex(rs.Refused, "already answered"):
            rs.RootOnlySim(self.oracle, committer.root, salt_bytes=fixed)
        self.assertEqual(self.oracle.table[top_pair], before[top_pair])  # never changed
        self.assertEqual(len(self.oracle.programmed), 0)
        self.assertTrue(all(self.oracle.table[k] == v for k, v in before.items()))

    def test_fresh_salts_program_successfully_against_the_same_root(self):
        committer = rs.HonestCommitter(self.oracle, rs.hidden_columns(self.random_bytes))
        rs.JointSim(self.oracle, salt_bytes=lambda count: b"s" * count)
        sim = rs.RootOnlySim(self.oracle, committer.root)  # fresh salts: a fresh point
        self.assertEqual(sim.programmed_points, 1)


class HonestSecretsStayHidden(SharedFixture):
    def test_simulated_world_reveals_nothing_of_the_committer_but_the_root(self):
        committers, _, dist = rs.run_root_only(self.oracle, self.indices, self.random_bytes)
        visible = dist.visible_values()
        for committer in committers:
            self.assertIn(committer.root, visible)
            self.assertFalse(committer.secret_values() & visible)

    def test_real_world_openings_reveal_no_unopened_column_or_salt(self):
        committer = rs.HonestCommitter(self.oracle, rs.hidden_columns(self.random_bytes))
        dist = rs.Distinguisher(self.oracle)
        dist.receive_openings(committer.root, committer.open_once(committer.root, self.indices))
        self.assertTrue(dist.verify_all())
        unopened = committer.secret_values(unopened_only_from=self.indices)
        self.assertEqual(len(unopened), 2 * (2048 - 240))
        self.assertFalse(unopened & dist.visible_values())


class RefusalDiscipline(SharedFixture):
    def test_root_only_refuses_a_different_root_and_failure_consumes(self):
        committer = rs.HonestCommitter(self.oracle, rs.hidden_columns(self.random_bytes))
        other = rs.JointSim(self.oracle)
        sim = rs.RootOnlySim(self.oracle, committer.root)
        with self.assertRaisesRegex(rs.Refused, "not issued"):
            sim.open_once(other.root, self.indices)
        with self.assertRaisesRegex(rs.Refused, "consumed"):
            sim.open_once(committer.root, self.indices)

    def test_second_use_after_success_refuses_in_both_worlds(self):
        joint = rs.JointSim(self.oracle)
        joint.open_once(joint.root, self.indices)
        with self.assertRaisesRegex(rs.Refused, "consumed"):
            joint.open_once(joint.root, self.indices)
        committer = rs.HonestCommitter(self.oracle, rs.hidden_columns(self.random_bytes))
        sim = rs.RootOnlySim(self.oracle, committer.root)
        sim.open_once(committer.root, self.indices)
        with self.assertRaisesRegex(rs.Refused, "consumed"):
            sim.open_once(committer.root, self.indices)

    def test_position_count_and_index_domain(self):
        sim = rs.JointSim(self.oracle)
        with self.assertRaisesRegex(rs.Refused, "256"):
            sim.open_once(sim.root, self.indices[:255])
        sim = rs.JointSim(self.oracle)
        with self.assertRaisesRegex(rs.Refused, "domain"):
            sim.open_once(sim.root, self.indices[:255] + [2048])
        with self.assertRaisesRegex(rs.Refused, "32-byte root"):
            rs.RootOnlySim(self.oracle, b"short")
        for value in (True, -1, rs.P):
            with self.subTest(value=value), self.assertRaisesRegex(rs.Refused, "canonical"):
                rs.column_bytes([value] * 7)

    def test_cli_experiment_counts_and_reproducibility(self):
        first = rs.experiment(rs.seeded_bytes(3))
        second = rs.experiment(rs.seeded_bytes(3))
        first.pop("tool_sha256"), second.pop("tool_sha256")
        self.assertEqual(first, second)
        self.assertEqual(first["experiments"]["joint_preparation_and_proof"]["programmed_points"], 0)
        self.assertEqual(first["experiments"]["external_statement_root_only"]["programmed_points"], 2)
        self.assertFalse(first["experiments"]["external_statement_root_only"]["honest_secrets_visible_to_distinguisher"])
        self.assertTrue(first["experiments"]["external_statement_root_only"]["collision_detected_holding_honest_top_pair"])
        self.assertEqual(sum(first["refusals_exercised"].values()), 6)
        self.assertEqual(first["geometry"]["distinct_positions"], 240)


if __name__ == "__main__":
    unittest.main()
