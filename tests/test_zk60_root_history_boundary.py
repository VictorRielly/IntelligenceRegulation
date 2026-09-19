"""Regression against the exact rejected Fable hash-layer simulator.

This detects a simulator failure with prior public authentication paths. It
does not recover endpoint data, attack BLAKE3, or certify production privacy.
The reviewed delivery is loaded read-only from an immutable local git object;
an unavailable object is an explicit skip, never a substitute passing model.
"""
import hashlib
from pathlib import Path
import subprocess
import types
import unittest
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[1]
COMMIT = "679ac264c14727e5ea98e499f42f9d1922ece40c"
SOURCE = "scripts/zk60_root_simulator.py"
SOURCE_SHA256 = "248bc58ed0df390487d03581c78e33d539ff7a2acae3833b059dbf59bb334717"


class RootHistoryBoundary(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        try:
            available = subprocess.run(
                ["git", "cat-file", "-e", COMMIT + "^{commit}"], cwd=ROOT,
                stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False,
                timeout=10,
            )
        except FileNotFoundError:
            raise unittest.SkipTest("git unavailable; pinned delivery not exercised")
        if available.returncode:
            raise unittest.SkipTest(
                "local delivery commit " + COMMIT + " unavailable; not exercised"
            )
        source = subprocess.check_output(
            ["git", "show", COMMIT + ":" + SOURCE], cwd=ROOT, timeout=10,
        )
        if hashlib.sha256(source).hexdigest() != SOURCE_SHA256:
            raise AssertionError("reviewed simulator source pin mismatch")
        cls.delivery = types.ModuleType("reviewed_fable_root_simulator")
        cls.delivery.__file__ = COMMIT + ":" + SOURCE
        exec(compile(source, cls.delivery.__file__, "exec"), cls.delivery.__dict__)

    def fixture(self):
        m = self.delivery
        random = m.seeded_bytes(20260918)
        oracle = m.RandomOracle(random)
        owner = m.HonestCommitter(oracle, m.hidden_columns(random))
        observer = m.Distinguisher(oracle)
        observer.receive_root(owner.root)
        return m, oracle, owner, observer

    def test_one_prior_public_path_distinguishes_the_proposed_simulator(self):
        m, oracle, owner, observer = self.fixture()
        # Neither negative-control secret export is available to this observer.
        with patch.object(m.HonestCommitter, "secret_top_pair",
                          side_effect=AssertionError("secret export forbidden")), \
             patch.object(m.HonestCommitter, "secret_values",
                          side_effect=AssertionError("secret export forbidden")):
            genuine_paths = owner.open_once(owner.root, m.query_positions())
            observer.receive_openings(owner.root, genuine_paths[:1])
            self.assertTrue(observer.verify_all())
            prior_preimages = observer.preimages(owner.root)
            self.assertEqual(len(prior_preimages), 1)

            # The existing top pair remains answered; the new top pair is fresh.
            simulator = m.RootOnlySim(oracle, owner.root)
            self.assertNotIn(simulator.programmed_point, prior_preimages)
            observer.receive_openings(
                owner.root, simulator.open_once(owner.root, m.query_positions())
            )
            self.assertTrue(observer.verify_all())
            self.assertEqual(len(observer.preimages(owner.root)), 2)
            self.assertTrue(observer.collision_detected(owner.root))

    def test_more_genuine_paths_keep_the_same_public_top_pair(self):
        m, _, owner, observer = self.fixture()
        paths = owner.open_once(owner.root, m.query_positions())
        observer.receive_openings(owner.root, paths[:1])
        self.assertTrue(observer.verify_all())
        original = observer.preimages(owner.root)
        observer.receive_openings(owner.root, paths[1:])
        self.assertTrue(observer.verify_all())
        self.assertEqual(observer.preimages(owner.root), original)
        self.assertFalse(observer.collision_detected(owner.root))

    def test_root_only_control_without_public_history_has_one_seen_preimage(self):
        m, oracle, owner, observer = self.fixture()
        simulator = m.RootOnlySim(oracle, owner.root)
        observer.receive_openings(
            owner.root, simulator.open_once(owner.root, m.query_positions())
        )
        self.assertTrue(observer.verify_all())
        self.assertEqual(len(observer.preimages(owner.root)), 1)
        self.assertFalse(observer.collision_detected(owner.root))


if __name__ == "__main__":
    unittest.main()
