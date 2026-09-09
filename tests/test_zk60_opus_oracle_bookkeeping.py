"""O10 -- independent adversarial controls on the endpoint oracle bookkeeping.

Reviewer: Claude Opus 5, 2026-09-09 (task O10 of docs/zkmatrix-poc/ZK60_OPUS_QUEUE.md).

These tests do NOT modify scripts/zk60_endpoint_simulation.py.  They probe the
bookkeeping from outside for properties the delivered suite does not assert, and
they record, as executable facts, the events a whole-view bound must cover.

Each test states what it would mean if it FAILED, so a later reader can tell a
coverage control from a defect report.  All of them pass at the review baseline;
none of them recovers a private endpoint value.
"""
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
import zk60_endpoint_simulation as sim


def _cols(indices):
    return [[(i + row) % sim.P for row in range(7)] for i in indices]


class HighIndexPaths(unittest.TestCase):
    """The delivered suite only ever opens indices < 241, so the top three of
    the eleven path levels are always taken on the same side.  Failure here
    would mean the path/sibling bit handling is wrong for high indices."""

    def test_paths_verify_at_the_top_of_the_index_domain(self):
        oracle = sim.RandomOracle()
        owner = sim.PreparedSimulation(oracle)
        # 2047, 2046, 1024 and 1023 flip every level, including bits 8, 9, 10.
        indices = [2047, 2046, 1024, 1023] + [i for i in range(252)]
        self.assertEqual(len(indices), 256)
        opened = owner.open_once(owner.root, indices, _cols(indices))
        for op in opened:
            self.assertTrue(sim.verify(oracle, owner.root, *op))
        self.assertEqual(len(oracle.programmed), 256)

    def test_a_sibling_swap_at_the_highest_level_is_rejected(self):
        oracle = sim.RandomOracle()
        owner = sim.PreparedSimulation(oracle)
        indices = [2047] + list(range(255))
        opened = owner.open_once(owner.root, indices, _cols(indices))
        index, values, salt, path = opened[0]
        tampered = list(path)
        tampered[10] = bytes(b ^ 1 for b in tampered[10])
        self.assertFalse(sim.verify(oracle, owner.root, index, values, salt, tampered))


class VerificationIsNotReadOnly(unittest.TestCase):
    """`verify` answers through the same table, so a distinguisher's own
    verification attempts consume oracle points.  Failure would mean the tool
    keeps a separate verification oracle, which the production code does not."""

    def test_verifying_a_forged_opening_populates_the_shared_table(self):
        oracle = sim.RandomOracle()
        owner = sim.PreparedSimulation(oracle)
        before = len(oracle.table)
        forged_path = [bytes([i]) * 32 for i in range(11)]
        self.assertFalse(
            sim.verify(oracle, owner.root, 5, [7] * 7, b"z" * 32, forged_path)
        )
        # one inner column hash, one salted leaf, eleven nodes
        self.assertEqual(len(oracle.table) - before, 13)

    def test_a_guessed_salt_blocks_the_programming_of_that_leaf(self):
        """The only thing separating a distinguisher's pre-query from a refusal
        is salt unpredictability -- exactly the q/2^256 event.  Here the salt is
        forced, so the refusal fires and the earlier answer is preserved."""
        oracle = sim.RandomOracle()
        owner = sim.PreparedSimulation(oracle)
        indices = list(range(256))
        columns = _cols(indices)
        salt = b"guessed-salt" .ljust(32, b"\0")
        inner = oracle.query(sim.column_bytes(columns[3]))
        planted = oracle.query(inner + salt)
        oracle.random_bytes = lambda count: salt
        with self.assertRaisesRegex(sim.Refused, "already answered"):
            owner.open_once(owner.root, indices, columns)
        self.assertEqual(oracle.table[inner + salt], planted)
        self.assertTrue(owner.spent)


class UnopenedLeavesAreUnexplained(unittest.TestCase):
    """In the real world every one of the 2048 leaves is the oracle image of
    (inner column hash || salt).  In the simulation only the 256 opened ones
    are.  The remaining 1792 are free handles, so a whole-view bound needs a
    union over all 2048 leaves per endpoint, not over the programmed ones."""

    def test_only_the_opened_leaves_are_images_of_any_queried_point(self):
        oracle = sim.RandomOracle()
        owner = sim.PreparedSimulation(oracle)
        indices = list(range(256))
        owner.open_once(owner.root, indices, _cols(indices))
        images = set(oracle.table.values())
        opened_leaves = {owner.levels[0][i] for i in indices}
        self.assertTrue(opened_leaves <= images)
        unopened = [owner.levels[0][j] for j in range(2048) if j not in set(indices)]
        self.assertEqual(len(unopened), 1792)
        self.assertEqual(len(oracle.programmed), 256)
        # Not one unopened leaf is explained as the image of a queried point.
        self.assertEqual(sum(1 for leaf in unopened if leaf in images), 0)


class DomainSeparationIsDimensional(unittest.TestCase):
    """salt_leaf and hash_pair inputs are both 64 untagged bytes; the inner
    column hash is separated from them only by its length, 8*rows.  At rows == 8
    that separation disappears.  `column_bytes` pins seven words, so the tool
    never reaches the degenerate case -- and that guard is the only thing
    standing in the way."""

    def test_seven_words_stay_clear_of_the_sixty_four_byte_domain(self):
        self.assertEqual(len(sim.column_bytes([1] * 7)), 56)
        with self.assertRaisesRegex(sim.Refused, "seven"):
            sim.column_bytes([1] * 8)

    def test_an_eight_word_column_would_alias_a_node_input(self):
        oracle = sim.RandomOracle()
        left, right = b"L" * 32, b"R" * 32
        answer = sim.node(oracle, left, right)
        eight_words = b"".join(
            v.to_bytes(8, "little")
            for v in [int.from_bytes((left + right)[i:i + 8], "little") for i in range(0, 64, 8)]
        )
        # The same 64 bytes, reachable as a column encoding and as a node input.
        self.assertEqual(eight_words, left + right)
        self.assertEqual(oracle.query(eight_words), answer)
        with self.assertRaisesRegex(sim.Refused, "already answered"):
            oracle.program_fresh(eight_words, b"X" * 32)


class AbortSemantics(unittest.TestCase):
    """A refused attempt must publish nothing and program nothing, while still
    consuming the owner.  Failure would mean an abort either leaks a partial
    opening or leaves the owner reusable."""

    def test_a_wrong_root_burns_the_owner_without_touching_the_oracle(self):
        oracle = sim.RandomOracle()
        owner = sim.PreparedSimulation(oracle)
        indices = list(range(256))
        before_table = dict(oracle.table)
        before_programmed = set(oracle.programmed)
        with self.assertRaisesRegex(sim.Refused, "not issued"):
            owner.open_once(b"\xff" * 32, indices, _cols(indices))
        self.assertTrue(owner.spent)
        self.assertEqual(oracle.table, before_table)
        self.assertEqual(oracle.programmed, before_programmed)

    def test_a_conflicting_duplicate_leaves_earlier_programming_in_place(self):
        """The refusal happens mid-loop, so points programmed before the
        conflict stay programmed. A bound must treat a refused attempt as
        having consumed those points, not as a no-op."""
        oracle = sim.RandomOracle()
        owner = sim.PreparedSimulation(oracle)
        indices = list(range(128)) + list(range(128))
        columns = _cols(indices)
        columns[200] = [1234] * 7  # index 72 seen earlier with different words
        with self.assertRaisesRegex(sim.Refused, "duplicate"):
            owner.open_once(owner.root, indices, columns)
        self.assertTrue(owner.spent)
        self.assertEqual(len(oracle.programmed), 128)


if __name__ == "__main__":
    unittest.main()
