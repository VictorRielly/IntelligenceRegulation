"""Tests for the native joint-view gate (scripts/zk60_native_joint_view.py).

Run:
  python3 -m unittest discover -s tests -p "test_zk60_native_joint_view.py"

The four source-pinned captures are tracked in the repository, so a missing
capture is a FAILURE here, never a silent skip: a green suite must mean the
analysis actually ran on the real captured views.
"""

from __future__ import annotations

import os
import sys
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "scripts"))

CAPTURES = os.path.join(ROOT, "results", "zk60_native_captures_20260919")

from zk60_native_jv_capture import load_all, manifest_check  # noqa: E402
from zk60_native_jv_cfs import CfsView, m_pad_block_rank, mask_len, rank2  # noqa: E402
from zk60_native_jv_field import (  # noqa: E402
    F2_ONE,
    P,
    Ntt,
    Transcript,
    f2_mul,
    f2_inv,
    inv,
    rank,
    two_adic_root,
)
from zk60_native_jv_pcs import RoleView  # noqa: E402
from zk60_native_jv_replay import Replay  # noqa: E402
import zk60_native_jv_smallmodel as smallmodel  # noqa: E402
import zk60_native_joint_view as gate  # noqa: E402

_CAPS = None
_REPLAYS = None


def caps():
    global _CAPS, _REPLAYS
    if _CAPS is None:
        _CAPS = load_all(CAPTURES)
        _REPLAYS = {c.proof_sha256: Replay(c).run() for c in _CAPS}
    return _CAPS, _REPLAYS


class FieldLayer(unittest.TestCase):
    def test_two_adic_root_orders(self):
        self.assertEqual(two_adic_root(1), P - 1)
        r = two_adic_root(32)
        self.assertEqual(pow(r, 1 << 32, P), 1)
        self.assertNotEqual(pow(r, 1 << 31, P), 1)

    def test_ntt_roundtrip_and_convention(self):
        ntt = Ntt(12)
        a = [(i * i + 7) % P for i in range(16)]
        self.assertEqual(ntt.inverse(ntt.forward(a)), a)
        w = two_adic_root(4)
        naive = [sum(a[t] * pow(w, t * j, P) for t in range(16)) % P for j in range(16)]
        self.assertEqual(ntt.forward(a), naive)

    def test_fp2_inverse(self):
        x = (12345, 678)
        self.assertEqual(f2_mul(x, f2_inv(x)), F2_ONE)

    def test_rank_is_exact(self):
        rows = [[1, 2, 3], [2, 4, 6], [0, 1, 1]]
        self.assertEqual(rank(rows, 3), 2)

    def test_transcript_matches_the_rust_construction(self):
        import blake3

        tr = Transcript(domain=b"d")
        h = blake3.blake3()
        h.update(b"hashline-v1/")
        h.update(b"d")
        self.assertEqual(tr.state, h.digest())
        tr.absorb(b"x", b"abc")
        h2 = blake3.blake3()
        h2.update(h.digest())
        h2.update((1).to_bytes(8, "little"))
        h2.update(b"x")
        h2.update((3).to_bytes(8, "little"))
        h2.update(b"abc")
        self.assertEqual(tr.state, h2.digest())
        before = tr.clone()
        self.assertEqual(before.challenge_fp2(), tr.peek_next())


class Captures(unittest.TestCase):
    def test_four_source_pinned_captures_are_present_and_manifested(self):
        cs, _ = caps()
        self.assertEqual(len(cs), 4, "the four retained captures must be present")
        self.assertEqual([c.kind for c in cs].count("block"), 2)
        self.assertEqual([c.kind for c in cs].count("attention"), 2)
        man = manifest_check(CAPTURES, cs)
        self.assertEqual(man["mismatch"], [])
        self.assertEqual(man["checked"], 4)
        self.assertFalse(man["privacy_review_complete"])

    def test_every_capture_pins_the_same_source_commit(self):
        cs, _ = caps()
        pins = {c.doc["source_commit"] for c in cs}
        self.assertEqual(len(pins), 1)
        self.assertEqual(len(pins.pop()), 40)


class Stage1Replay(unittest.TestCase):
    def test_every_checkpoint_and_challenge_is_reproduced(self):
        cs, rp = caps()
        for c in cs:
            s = rp[c.proof_sha256].summary()
            with self.subTest(capture=c.proof_sha256[:12]):
                self.assertEqual(s["failures"], [])
                self.assertTrue(s["ok"])
                self.assertGreaterEqual(s["checkpoints_checked"], 65)
                self.assertGreaterEqual(s["challenges_checked"], 1122)

    def test_counts_are_the_recorded_ones(self):
        cs, rp = caps()
        want = {"block": (80, 1543, 1863), "attention": (65, 1122, 1442)}
        for c in cs:
            s = rp[c.proof_sha256].summary()
            self.assertEqual(
                (s["checkpoints_checked"], s["challenges_checked"], s["final_counter"]),
                want[c.kind],
            )

    def test_altered_capture_bytes_break_the_replay(self):
        cs, rp = caps()
        out = gate.stage1_tamper(cs, rp)
        self.assertTrue(out["ok"], out)
        for row in out["per_capture"]:
            self.assertTrue(row["fired"])
        # the tamper must be undone: the honest replay still passes
        for c in cs:
            self.assertTrue(Replay(c).run().summary()["ok"])


class Stage2CommitmentSide(unittest.TestCase):
    def test_disclosed_dimensions_are_zero_except_the_public_logup_identity(self):
        cs, rp = caps()
        expect = {"A": 0, "H": 2, "Input": 0, "Output": 0}
        for c in cs:
            for role in c.roles:
                rv = RoleView(c, role, rp[c.proof_sha256].role_prox_rhos[role["role"]])
                f = rv.run(rp[c.proof_sha256].role_lambdas[role["role"]])
                with self.subTest(capture=c.proof_sha256[:12], role=role["role"]):
                    self.assertEqual(f["findings"], [])
                    self.assertEqual(f["column_identity_failures"], 0)
                    self.assertEqual(f["group_claim_identity_failures"], 0)
                    self.assertTrue(all(f["reduction_hypotheses"].values()))
                    self.assertEqual(f["disclosed_dimension"], expect[role["role"]])
                    if role["role"] == "H":
                        self.assertTrue(f["u_row_term"]["equals_public_logup_identity"])

    def test_the_pad_budget_is_met_with_a_positive_margin(self):
        cs, rp = caps()
        for c in cs:
            for role in c.roles:
                rv = RoleView(c, role, rp[c.proof_sha256].role_prox_rhos[role["role"]])
                f = rv.run(rp[c.proof_sha256].role_lambdas[role["role"]])
                self.assertLessEqual(f["distinct_columns"], f["q_pad"])
                self.assertGreater(f["pad_margin"], 0)
                self.assertTrue(f["coset_nodes_distinct"])
                self.assertEqual(f["vanishing_Zn_nodes"], 0)

    def test_the_pad_block_has_exactly_full_rank(self):
        cs, rp = caps()
        c = cs[0]
        role = c.role("Input")
        rv = RoleView(c, role, rp[c.proof_sha256].role_prox_rhos["Input"])
        r, d = rv.pad_block_rank()
        self.assertEqual(r, d)


class Stage3MaskingCommitment(unittest.TestCase):
    def test_the_masks_cover_every_consistency_direction(self):
        cs, rp = caps()
        for c in cs:
            f = CfsView(c, rp[c.proof_sha256]).run()
            with self.subTest(capture=c.proof_sha256[:12]):
                self.assertEqual(f["findings"], [])
                self.assertEqual(f["uncovered_consistency_directions"], 0)
                for p in f["per_slot"]:
                    self.assertEqual(p["rank_R"], p["dim_C"])
                    self.assertEqual(p["L"], mask_len(p["n_vars"], p["degree"]))

    def test_the_published_functionals_lie_in_the_round_span(self):
        """The finding of this lane: every M functional is determined by the
        masked rounds (rank_F_mod_rounds == 0), which is why the derived mask
        evaluations must not be counted twice.  Recorded, not explained away."""
        cs, rp = caps()
        for c in cs:
            f = CfsView(c, rp[c.proof_sha256]).run()
            self.assertEqual(f["rank_F_mod_rounds"], 0)
            self.assertEqual(f["functional_round_overlap"], f["rank_F"])
            self.assertTrue(f["theta_combination_in_round_span"])
            self.assertEqual(f["disclosed_opening_only_fp"], 2)
            self.assertEqual(f["disclosed_all_values_fp"], 2 * f["rank_F"])

    def test_the_mask_opening_checks_hold(self):
        cs, rp = caps()
        for c in cs:
            f = CfsView(c, rp[c.proof_sha256]).run()
            self.assertTrue(f["q_public_sum_identity"])
            self.assertGreater(f["m_pad_margin"], 0)
            self.assertTrue(f["m_nodes_distinct"])
            self.assertEqual(f["m_vanishing_Z_nodes"], 0)
            self.assertEqual(f["m_rows"], f["m_expected_rows"])

    def test_the_a_row_pad_block_has_full_rank(self):
        cs, _ = caps()
        r, d = m_pad_block_rank(cs[0])
        self.assertEqual(r, d)


class Stage5ZeroWitness(unittest.TestCase):
    def test_a_zero_data_preimage_exists_in_the_model_on_every_channel(self):
        cs, rp = caps()
        s2 = gate.stage2(cs, rp, pad_rank_check=False)
        s5 = gate.stage5(cs, s2)
        self.assertTrue(s5["ok"])
        for row in s5["per_capture"]:
            self.assertTrue(row["h_sum_claim_value_is_zero"])
            self.assertIn("the three Merkle roots", row["channels_not_covered"])


class Stage6Controls(unittest.TestCase):
    def test_the_reduction_agrees_with_the_brute_force_dense_rank(self):
        ctl = smallmodel.controls()
        self.assertEqual(ctl["honest"]["bruteforce"], ctl["honest"]["reduction"])
        self.assertEqual(ctl["honest"]["bruteforce"], 0)
        self.assertEqual(
            ctl["honest_with_zero_sum_pair"]["bruteforce"],
            ctl["honest_with_zero_sum_pair"]["reduction"],
        )

    def test_every_negative_control_fires(self):
        ctl = smallmodel.controls()
        for name in [
            "masks_removed",
            "two_claims_share_one_pair",
            "commitment_opened_twice",
            "extra_published_helper_sum",
            "one_pad_fewer_than_opened_columns",
        ]:
            with self.subTest(control=name):
                self.assertGreater(ctl[name]["bruteforce"], 0, f"{name} did not fire")

    def test_the_hypothesis_checks_name_the_broken_hypothesis(self):
        ctl = smallmodel.controls()
        self.assertFalse(ctl["masks_removed"]["hypotheses"]["H-pair"])
        self.assertFalse(ctl["two_claims_share_one_pair"]["hypotheses"]["H-pair"])
        self.assertFalse(ctl["commitment_opened_twice"]["hypotheses"]["H-pad"])
        self.assertFalse(ctl["one_pad_fewer_than_opened_columns"]["hypotheses"]["H-pad"])


class GateRecord(unittest.TestCase):
    def test_the_retained_record_matches_a_fresh_run_of_the_stages(self):
        path = os.path.join(ROOT, "results", "zk60_native_joint_view", "joint_view.json")
        self.assertTrue(os.path.exists(path), "run the gate first")
        import json

        with open(path) as fh:
            rec = json.load(fh)
        self.assertTrue(rec["ok"])
        self.assertFalse(rec["privacy_property_established"])
        self.assertFalse(rec["privacy_review_complete"])
        self.assertEqual(rec["tool_sha256"], gate.tool_hashes())
        for row in rec["stage4_stacked"]["per_capture"]:
            self.assertEqual(row["pcs_sum_fp"], 2)
            self.assertEqual(row["joint_opening_only_fp"], 4)


if __name__ == "__main__":
    unittest.main()
