"""O11 -- independent structural controls on the two-proof repeated view.

Reviewer: Claude Opus 5, 2026-09-09 (task O11 of docs/zkmatrix-poc/ZK60_OPUS_QUEUE.md).

These tests do NOT modify scripts/zk60_io_repeated_view.py.  They check the
model's *structural* premises -- which rows alias, which roles exist, what
check_pair refuses -- because those are cheap and are what the rank result
rests on.  The rank and disclosure expectations themselves are recomputed
separately (they take minutes); their outcome is recorded in
results/zk60_opus_repeated_view_review.json and asserted here against that
record rather than recomputed per test run.

The capture directory is resolved from ZK60_IO_CAPTURES, defaulting to the
persisted round-22 workspace directory rather than a /tmp path, so a reboot
does not silently turn these into skips (see the O10 review).
"""
import json
import os
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))

CAPTURES = Path(os.environ.get(
    "ZK60_IO_CAPTURES",
    "/home/victor/IntelligenceRegulation/results/zk60_round22_captures"))
RECORD = ROOT / "results/zk60_opus_repeated_view_review.json"


def _load():
    import zk60_opus_io_capture as O
    caps = [O.IoCapture(str(p)) for p in sorted(CAPTURES.glob("*.json"))]
    return O, caps


@unittest.skipUnless(CAPTURES.is_dir() and any(CAPTURES.glob("*.json")),
                     f"IO captures absent ({CAPTURES})")
class AliasHygiene(unittest.TestCase):
    """Only witness data may alias across attempts.  A mask, pad or proximity
    row that aliased would merge two independent secrets and would make the
    model understate disclosure."""

    @classmethod
    def setUpClass(cls):
        cls.O, cls.caps = _load()
        import zk60_io_repeated_view as RV
        cls.RV = RV

    def _model(self, privacy):
        caps = [c for c in self.caps if c.privacy == privacy]
        self.assertEqual(len(caps), 2)
        return self.RV.model(caps, None, True)

    def test_every_cross_attempt_alias_joins_two_data_rows(self):
        for privacy in ("P1", "P3"):
            with self.subTest(privacy=privacy):
                _, meta = self._model(privacy)
                kind = {(o.role, r): k
                        for o in meta["observations"]
                        for r, k in enumerate(o.row_kind)}
                cross = [a for a in meta["aliases"]
                         if a[0][0].split("@")[1] != a[1][0].split("@")[1]]
                self.assertTrue(cross)
                self.assertEqual({(kind[a[0]], kind[a[1]]) for a in cross},
                                 {("data", "data")})

    def test_H_never_aliases_across_attempts(self):
        for privacy in ("P1", "P3"):
            with self.subTest(privacy=privacy):
                _, meta = self._model(privacy)
                cross = [a for a in meta["aliases"]
                         if a[0][0].split("@")[1] != a[1][0].split("@")[1]]
                self.assertEqual(
                    [a for a in cross
                     if a[0][0].startswith("H") or a[1][0].startswith("H")], [])

    def test_P3_shares_private_W_data_and_P1_has_no_private_W(self):
        _, p1 = self._model("P1")
        _, p3 = self._model("P3")
        roles = lambda meta: {o.role.split("@")[0] for o in meta["observations"]}
        self.assertNotIn("W", roles(p1))
        self.assertIn("W", roles(p3))
        cross = lambda meta: [a for a in meta["aliases"]
                              if a[0][0].split("@")[1] != a[1][0].split("@")[1]]
        # P3's only extra cross-attempt aliases are its private W data rows.
        extra = len(cross(p3)) - len(cross(p1))
        w_rows = [a for a in cross(p3) if a[0][0].startswith("W")]
        self.assertEqual(len(w_rows), extra)
        self.assertGreater(extra, 0)


@unittest.skipUnless(CAPTURES.is_dir() and any(CAPTURES.glob("*.json")),
                     f"IO captures absent ({CAPTURES})")
class PairAdmission(unittest.TestCase):
    """check_pair is the gate that keeps the fresh-owner model honest."""

    @classmethod
    def setUpClass(cls):
        cls.O, cls.caps = _load()
        import zk60_io_repeated_view as RV
        cls.RV = RV

    def test_the_same_proof_twice_is_refused(self):
        one = [c for c in self.caps if c.privacy == "P1"][0]
        with self.assertRaisesRegex(Exception, "duplicate proof"):
            self.RV.check_pair([one, one])

    def test_mixed_privacy_modes_are_refused(self):
        p1 = [c for c in self.caps if c.privacy == "P1"][0]
        p3 = [c for c in self.caps if c.privacy == "P3"][0]
        with self.assertRaisesRegex(Exception, "mixed privacy|different"):
            self.RV.check_pair([p1, p3])

    def test_a_pair_must_be_exactly_two(self):
        with self.assertRaisesRegex(Exception, "exactly two"):
            self.RV.check_pair([c for c in self.caps if c.privacy == "P1"][:1])

    def test_every_private_root_is_distinct_in_the_delivered_pairs(self):
        for privacy in ("P1", "P3"):
            with self.subTest(privacy=privacy):
                caps = [c for c in self.caps if c.privacy == privacy]
                roots = [role.root for cap in caps for role in cap.roles]
                roots += [cap.mask["root"] for cap in caps]
                self.assertEqual(len(roots), len(set(roots)))


@unittest.skipUnless(CAPTURES.is_dir() and any(CAPTURES.glob("*.json")),
                     f"IO captures absent ({CAPTURES})")
class ProofLocalityEvidence(unittest.TestCase):
    """The model does not alias H because H's data depends on each proof's
    beta/gamma/alpha.  Those come from the transcript, which absorbs the
    112-byte policy -- including the two fresh endpoint roots -- before any
    challenge.  This checks the recorded evidence for that: every role's
    transcript state differs between the two attempts."""

    def test_transcript_states_and_roots_differ_at_every_role(self):
        O, caps = _load()
        for privacy in ("P1", "P3"):
            with self.subTest(privacy=privacy):
                a, b = [c for c in caps if c.privacy == privacy]
                for ra, rb in zip(a.roles, b.roles):
                    self.assertEqual(ra.role, rb.role)
                    self.assertNotEqual(ra.before_state, rb.before_state)
                    self.assertNotEqual(ra.root, rb.root)


@unittest.skipUnless(RECORD.exists(), f"review record absent ({RECORD})")
class RecordedExpectations(unittest.TestCase):
    """The rank results are recomputed offline; this pins their interpretation
    so a later change to the tool cannot quietly move them."""

    def setUp(self):
        self.record = json.loads(RECORD.read_text())

    def test_each_H_zero_sum_constraint_contributes_two_base_coordinates(self):
        for case in self.record["independent_recomputation"]["cases"]:
            with self.subTest(privacy=case["privacy"]):
                self.assertEqual(
                    [s["disclosed_total"] for s in case["zero_sum_step_function"]],
                    [0, 2, 4])
                self.assertEqual(case["base_coords_per_zero_sum_constraint"], 2)

    def test_public_logup_identities_add_no_rank(self):
        for case in self.record["independent_recomputation"]["cases"]:
            with self.subTest(privacy=case["privacy"]):
                self.assertEqual(case["public_H_identities_rank_increment"], 0)

    def test_the_endpoint_mask_pair_ablation_discloses_one_coordinate_per_column(self):
        ab = self.record["ablation"]
        self.assertEqual(ab["single_mask_disclosed_per_column"], 1)
        self.assertEqual(ab["columns"], 256)
        self.assertEqual(ab["single_mask_disclosed_total"], 256)
        self.assertEqual(ab["paired_disclosed_total"], 0)


if __name__ == "__main__":
    unittest.main()
