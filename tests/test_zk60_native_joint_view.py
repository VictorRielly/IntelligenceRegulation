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

from zk60_native_jv_capture import (  # noqa: E402
    MANIFEST_NAMES,
    ManifestRefusal,
    load_all,
    manifest_check,
)
from zk60_native_jv_cfs import (  # noqa: E402
    CfsView,
    m_pad_block_rank,
    mask_len,
    rank2,
    terminal_identity,
    terminal_identity_controls,
)
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
import zk60_native_jv_joint as joint  # noqa: E402
import zk60_native_jv_smallmodel as smallmodel  # noqa: E402
import zk60_native_joint_view as gate  # noqa: E402

_CAPS = None
_REPLAYS = None
_VIEWS = None
_CFS = None


def caps():
    global _CAPS, _REPLAYS
    if _CAPS is None:
        _CAPS = load_all(CAPTURES)
        _REPLAYS = {c.proof_sha256: Replay(c).run() for c in _CAPS}
    return _CAPS, _REPLAYS


def views():
    """The four RoleViews of every capture, and the CFS figure, built once."""
    global _VIEWS, _CFS
    if _VIEWS is None:
        cs, rp = caps()
        _VIEWS, _CFS = {}, {}
        for c in cs:
            r = rp[c.proof_sha256]
            vs = []
            for role in c.roles:
                v = RoleView(c, role, r.role_prox_rhos[role["role"]])
                v.run(r.role_lambdas[role["role"]])
                vs.append(v)
            _VIEWS[c.proof_sha256] = vs
            _CFS[c.proof_sha256] = CfsView(c, r).run()["disclosed_opening_only_fp"]
    return _VIEWS, _CFS


def bareiss_det(mat, p):
    """A fraction-free determinant, INDEPENDENT of the tool's own routine.

    `det_mod_p` in the tool eliminates with normalised pivot rows; this is
    the Bareiss recurrence, which never normalises and divides only by the
    previous pivot.  Two different algorithms agreeing on the same 72x72
    matrix is the point.
    """
    n = len(mat)
    a = [[x % p for x in row] for row in mat]
    sign, prev = 1, 1
    for k in range(n - 1):
        if a[k][k] == 0:
            swap = next((i for i in range(k + 1, n) if a[i][k]), None)
            if swap is None:
                return 0
            a[k], a[swap] = a[swap], a[k]
            sign = -sign
        inv_prev = pow(prev, p - 2, p)
        for i in range(k + 1, n):
            for j in range(k + 1, n):
                a[i][j] = (a[i][j] * a[k][k] - a[i][k] * a[k][j]) % p * inv_prev % p
        prev = a[k][k]
    return sign * a[n - 1][n - 1] % p


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


class DerivedMaskEvaluation(unittest.TestCase):
    """Report §3.1: the verifier COMPUTES each slot's mask evaluation from
    published values.  The identity it computes it by is asserted per slot."""

    def test_the_identity_holds_on_every_slot_of_every_capture(self):
        cs, rp = caps()
        want = {"block": 23, "attention": 18}
        for c in cs:
            f = terminal_identity(c, rp[c.proof_sha256])
            with self.subTest(capture=c.proof_sha256[:12]):
                self.assertEqual(f["findings"], [])
                self.assertEqual(f["slots"], want[c.kind])
                self.assertEqual(f["claimed_sum_recomputed"], f["slots"])
                self.assertEqual(f["round_consistency_holds"], f["slots"])
                self.assertEqual(f["final_matches_the_capture"], f["slots"])
                self.assertEqual(f["mask_challenge_nonzero"], f["slots"])
                self.assertEqual(f["derived_mask_evaluation_identity"], f["slots"])
                self.assertTrue(f["ok"])

    def test_every_terminal_is_republished_as_a_pcs_claim_value(self):
        cs, rp = caps()
        want = {"block": 173, "attention": 112}
        for c in cs:
            f = terminal_identity(c, rp[c.proof_sha256])
            self.assertEqual(f["terminals"], want[c.kind])
            self.assertEqual(f["terminals_republished_as_claim_values"], f["terminals"])

    def test_the_strong_form_is_not_claimed(self):
        """The capture stores terminal_polynomial as fin - c*mask_eval and not
        the slot's composition polynomial, so poly_s(terminals_s) cannot be
        recomputed here.  The record must say so rather than imply otherwise."""
        cs, rp = caps()
        for c in cs:
            f = terminal_identity(c, rp[c.proof_sha256])
            self.assertFalse(f["strong_form_available"])
            self.assertIn("def.poly", f["strong_form_missing_input"])

    def test_perturbing_a_published_field_breaks_the_identity(self):
        cs, rp = caps()
        for c in cs:
            out = terminal_identity_controls(c, rp[c.proof_sha256])
            with self.subTest(capture=c.proof_sha256[:12]):
                self.assertTrue(out["last_round_coefficient"])
                self.assertTrue(out["mask_eval"])
                self.assertTrue(out["terminal_polynomial"])
                # the weak identity cannot see a perturbed terminal ...
                self.assertFalse(out["terminal_mask_evaluation_identity"])
                # ... but the terminal's republication as a claim value does
                self.assertTrue(out["terminal_claim_value_cross_check"])
                self.assertTrue(out["honest_again"])
                self.assertTrue(out["ok"])

    def test_a_perturbed_terminal_also_breaks_the_transcript_replay(self):
        cs, rp = caps()
        c = cs[0]
        out = terminal_identity_controls(c, rp[c.proof_sha256], replay_check=True)
        self.assertTrue(out["terminal_transcript_replay"])
        self.assertTrue(Replay(c).run().summary()["ok"])


class PadBudgetBoundary(unittest.TestCase):
    """Report §9b: q_pad == the number of DISTINCT opened positions."""

    def test_the_three_boundary_cases_match_their_predictions(self):
        b = smallmodel.pad_boundary()
        self.assertEqual(b["q_pad_equals_distinct"]["bruteforce_disclosed"], 0)
        self.assertEqual(b["q_pad_equals_distinct_plus_one"]["bruteforce_disclosed"], 0)
        self.assertGreater(b["q_pad_equals_distinct_minus_one"]["bruteforce_disclosed"], 0)
        offset = {
            "q_pad_equals_distinct": 0,
            "q_pad_equals_distinct_plus_one": 1,
            "q_pad_equals_distinct_minus_one": -1,
        }
        for name, off in offset.items():
            with self.subTest(case=name):
                self.assertTrue(b[name]["as_predicted"])
                self.assertEqual(b[name]["q_pad"], b[name]["distinct_opened_positions"] + off)
        self.assertTrue(b["ok"])

    def test_the_group_vectors_consume_no_pad_freedom(self):
        b = smallmodel.pad_boundary()
        for name, case in b.items():
            if name == "ok":
                continue
            g = case["group_vectors"]
            with self.subTest(case=name):
                self.assertEqual(g["pad_freedom_consumed"], 0)
                self.assertEqual(g["k0"], 0)
                self.assertTrue(g["equals_q_pad_times_k0"])

    def test_the_real_pad_block_is_full_rank_with_zero_margin(self):
        """256 pads against 256 DISTINCT opened positions, at the receipts'
        own coset and geometry: the collision-free draw the source allows."""
        cs, rp = caps()
        c = cs[0]
        rv = RoleView(c, c.role("Input"), rp[c.proof_sha256].role_prox_rhos["Input"])
        r, d = rv.pad_block_rank_at_full_budget()
        self.assertEqual(d, 256)
        self.assertEqual(r, 256)


class Stage5ZeroWitness(unittest.TestCase):
    def test_a_zero_data_preimage_exists_in_the_model_on_every_channel(self):
        cs, rp = caps()
        # stage 2 now also hands its RoleView objects to stage 4 (the joint
        # computation of ruling G-1), so it returns a pair.
        s2, _views = gate.stage2(cs, rp, pad_rank_check=False)
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


class Stage4JointComputation(unittest.TestCase):
    """Ruling G-1: stage 4 used to hard-code `joint == sum` and its own
    verdict, so it could not fail.  These tests are about the COMPUTATION
    that replaced the literal."""

    def test_the_joint_is_computed_and_equals_the_sum_at_every_capture(self):
        cs, rp = caps()
        vs, cf = views()
        for c in cs:
            out = joint.joint_view(c, rp[c.proof_sha256], vs[c.proof_sha256],
                                   cf[c.proof_sha256])
            with self.subTest(capture=c.proof_sha256[:12]):
                self.assertTrue(out["ok"], out["findings"])
                self.assertEqual(out["sum_of_parts_fp"], 4)
                self.assertEqual(out["joint_fp"], 4)
                self.assertTrue(out["joint_equals_sum_of_parts"])
                # the joint figure is a rank, not the sum written twice
                self.assertEqual(out["joint_detail"]["k0"], 0)
                self.assertEqual(out["joint_detail"]["u_row_term_fp"], 2)
                self.assertEqual(
                    out["joint_detail"]["rank_all"],
                    out["joint_detail"]["rank_on_non_data"],
                )
                self.assertEqual(out["parts_fp"]["M"], 0)

    def test_the_shared_coordinates_are_the_endpoint_planes_and_nothing_else(self):
        cs, rp = caps()
        vs, cf = views()
        for c in cs:
            out = joint.joint_view(c, rp[c.proof_sha256], vs[c.proof_sha256],
                                   cf[c.proof_sha256])
            sc = out["shared_coordinates"]
            with self.subTest(capture=c.proof_sha256[:12]):
                # two endpoint-equality slots, each identifying one plane
                self.assertEqual(len(sc["endpoint_equality_slots"]), 2)
                self.assertEqual(
                    sorted(s["endpoint"] for s in sc["endpoint_equality_slots"]),
                    ["Input", "Output"],
                )
                self.assertEqual(len(sc["identified_row_pairs"]), 4)
                self.assertEqual(sc["classes_shared_between_roles_data"], 4)
                # NO blinding source is shared: that is what makes joint == sum
                # a theorem about the block structure here
                self.assertEqual(sc["classes_shared_between_roles_non_data"], 0)
                self.assertTrue(sc["non_data_block_is_block_diagonal_by_role"])
                # and the data identification itself costs nothing at these
                # captures: the only disclosed functional lives on H
                self.assertEqual(out["aliasing_lost_to_the_endpoint_identification_fp"], 0)

    def test_the_parts_recomputed_through_the_joint_path_match_stage2(self):
        cs, rp = caps()
        vs, cf = views()
        for c in cs:
            out = joint.joint_view(c, rp[c.proof_sha256], vs[c.proof_sha256],
                                   cf[c.proof_sha256])
            with self.subTest(capture=c.proof_sha256[:12]):
                self.assertTrue(out["parts_recomputed_through_the_joint_path_match_stage2"])
                self.assertEqual(out["stage2_parts_fp"],
                                 {"A": 0, "H": 2, "Input": 0, "Output": 0})

    def test_the_joint_reduction_matches_a_dense_joint_rank_in_the_small_model(self):
        """The receipt's joint rank is a reduction; here the dense rank over
        BOTH toy commitments is computed from the definition and compared."""
        out = smallmodel.joint_controls()
        self.assertTrue(out["ok"])
        for name in ("honest_two_commitments", "one_blinding_row_shared",
                     "one_data_row_shared"):
            with self.subTest(case=name):
                self.assertTrue(out[name]["reduction_agrees_with_bruteforce"])
        self.assertEqual(out["honest_two_commitments"]["joint_minus_sum"], 0)
        # the case the hard-coded stage 4 could not see: both marginals 0,
        # the joint positive
        self.assertEqual(out["one_blinding_row_shared"]["marginals_bruteforce"], [0, 0])
        self.assertGreater(out["one_blinding_row_shared"]["joint_bruteforce"], 0)
        # sharing DATA can only lower the joint, never raise it
        self.assertLessEqual(out["one_data_row_shared"]["joint_minus_sum"], 0)


class Stage4NegativeControls(unittest.TestCase):
    """Each control must make stage 4 FAIL at an HONEST capture.  Every test
    below shows both verdicts: a control that cannot fire is not a control."""

    @classmethod
    def setUpClass(cls):
        cs, rp = caps()
        vs, cf = views()
        cls.cap = cs[0]
        cls.rp = rp[cls.cap.proof_sha256]
        cls.views = vs[cls.cap.proof_sha256]
        cls.cfs = cf[cls.cap.proof_sha256]
        cls.ctl = joint.joint_controls(cls.cap, cls.rp, cls.views, cls.cfs)

    def test_the_honest_capture_passes(self):
        self.assertTrue(self.ctl["honest"]["ok"])
        self.assertEqual(self.ctl["honest"]["joint_fp"], 4)
        self.assertEqual(self.ctl["honest"]["sum_of_parts_fp"], 4)

    def test_a_shared_blinding_source_makes_the_joint_exceed_the_sum(self):
        c = self.ctl["shared_blinding_source"]
        self.assertTrue(c["fires"])
        # the direction: UP.  The marginals do not move at all -- neither
        # commitment discloses anything on its own -- and the joint rises by
        # one whole message row (256 Fp) because a combination of the two
        # commitments' group vectors now cancels on every non-data
        # coordinate and survives on the data rows.
        self.assertTrue(c["parts_unchanged"])
        self.assertEqual(c["parts_fp"], self.ctl["honest"]["parts_fp"])
        self.assertTrue(c["joint_greater_than_sum"])
        self.assertEqual(c["joint_fp"], self.ctl["honest"]["joint_fp"] + 256)
        self.assertEqual(c["joint_k0"], 1)

    def test_removing_one_mask_row_makes_a_part_exceed_its_expected_value(self):
        c = self.ctl["one_mask_row_removed"]
        self.assertTrue(c["fires"])
        # here the marginal moves WITH the joint, so the equality survives
        # and the stage fails on its other arm
        self.assertEqual(c["parts_fp"]["A"], 256)
        self.assertIn("A: 256 > 0", c["exceeds"])
        self.assertEqual(c["joint_fp"], c["sum_of_parts_fp"])

    def test_one_pad_fewer_than_the_distinct_columns_makes_the_stage_refuse(self):
        c = self.ctl["one_pad_fewer_than_the_distinct_opened_columns"]
        self.assertTrue(c["fires"])
        self.assertFalse(c["hypotheses"]["A"])

    def test_a_claim_weight_outside_its_reserved_pair_makes_the_stage_refuse(self):
        c = self.ctl["claim_weight_outside_its_reserved_pair"]
        self.assertTrue(c["fires"])
        self.assertFalse(c["hypotheses"]["A"])

    def test_all_four_controls_fire(self):
        self.assertTrue(self.ctl["all_fire"])
        self.assertTrue(self.ctl["ok"])

    def test_where_the_model_can_and_cannot_see_a_shared_blinding_row(self):
        """The honest limitation, recorded as a test rather than a sentence.

        The rank sees a shared blinding row only where the non-data block is
        TIGHT: a singleton opening group's reserved pair is two generators
        against exactly two columns, so losing one column costs a rank.
        Where a group has several claims the block has slack and the same
        sharing changes no rank at all -- the gate would not see it.  That
        is a limit of this model, not a property of the protocol.
        """
        byname = {v.name: v for v in self.views}
        a_single = joint.singleton_pair_rows(byname["A"])[0]["rows"][0]
        h_single = joint.singleton_pair_rows(byname["H"])[0]["rows"][0]
        h = byname["H"]
        multi = None
        for members in h.groups:
            if len(members) > 1:
                ci = members[0]
                rows = sorted(
                    r for r in h.other_rows
                    if h.rws[ci][r] != (0, 0) and r not in h.u_rows
                )
                multi = rows[0]
                break
        self.assertIsNotNone(multi, "the capture has no multi-claim opening group")
        seen = joint.joint_view(
            self.cap, self.rp, self.views, self.cfs,
            extra_identifications=[(("A", a_single), ("H", h_single))],
        )
        unseen = joint.joint_view(
            self.cap, self.rp, self.views, self.cfs,
            extra_identifications=[(("A", a_single), ("H", multi))],
        )
        self.assertFalse(seen["ok"])
        self.assertTrue(unseen["ok"], "documented blind spot, not a passing property")
        self.assertEqual(unseen["joint_fp"], unseen["sum_of_parts_fp"])


class CertifyingMinor(unittest.TestCase):
    """JOB 3: the generic-rank lemma's good event is `rank(gens | non-data)
    = g`, i.e. some g x g minor is nonsingular.  The gate now names one."""

    def test_every_role_emits_a_nonsingular_g_by_g_minor(self):
        cs, _ = caps()
        vs, _cf = views()
        for c in cs:
            for v in vs[c.proof_sha256]:
                m = v.facts["certifying_minor"]
                with self.subTest(capture=c.proof_sha256[:12], role=v.name):
                    self.assertEqual(m["g"], 2 * (m["G"] + 1))
                    self.assertTrue(m["full_row_rank"])
                    self.assertEqual(m["rank_on_non_data_rows"], m["g"])
                    self.assertEqual(len(m["generator_indices"]), m["g"])
                    self.assertEqual(len(m["non_data_row_indices"]), m["g"])
                    self.assertEqual(len(set(m["non_data_row_indices"])), m["g"])
                    self.assertTrue(m["determinant_nonzero"])
                    self.assertNotEqual(m["determinant"] % P, 0)

    def test_the_determinant_recomputes_independently_from_the_emitted_indices(self):
        cs, _ = caps()
        vs, _cf = views()
        for c in cs:
            for v in vs[c.proof_sha256]:
                m = v.facts["certifying_minor"]
                got = v.rebuild_minor(m["generator_indices"], m["non_data_row_indices"])
                with self.subTest(capture=c.proof_sha256[:12], role=v.name):
                    self.assertEqual(got["determinant"], m["determinant"])
                    self.assertTrue(got["nonsingular"])
                    # and by a different algorithm entirely
                    self.assertEqual(bareiss_det(got["submatrix"], P), m["determinant"])

    def test_a_singular_index_set_fails_the_verification(self):
        cs, _ = caps()
        vs, _cf = views()
        v = vs[cs[0].proof_sha256][1]  # H
        m = v.facts["certifying_minor"]
        rows = list(m["non_data_row_indices"])
        rows[-1] = rows[0]  # a repeated column: singular by construction
        got = v.rebuild_minor(m["generator_indices"], rows)
        self.assertEqual(got["determinant"], 0)
        self.assertFalse(got["nonsingular"])
        self.assertEqual(bareiss_det(got["submatrix"], P), 0)

    def test_the_distinct_opened_columns_fit_in_the_pad_count(self):
        cs, _ = caps()
        vs, _cf = views()
        for c in cs:
            for v in vs[c.proof_sha256]:
                f = v.facts
                with self.subTest(capture=c.proof_sha256[:12], role=v.name):
                    # sampled WITH replacement, so distinct < sampled; the
                    # rank of the pad block is the DISTINCT count and the
                    # budget has no slack beyond that
                    self.assertLess(f["distinct_opened_columns"], f["sampled_columns"])
                    self.assertLessEqual(f["distinct_opened_columns"], f["pad_count"])
                    self.assertTrue(f["distinct_opened_columns_within_pad_count"])


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
            # UPDATED 2026-09-20 (ruling G-1).  `joint_equals_sum_of_parts`
            # was a hard-coded literal until this date, so the old assertion
            # on it asserted nothing; these fields are now computed and the
            # stage can fail.
            self.assertTrue(row["joint_equals_sum_of_parts"])
            self.assertEqual(row["sum_of_parts_fp"], row["joint_fp"])
            self.assertEqual(row["joint_detail"]["k0"], 0)
            self.assertEqual(row["parts_exceeding_their_expected_value"], [])
            self.assertEqual(row["findings"], [])
            self.assertEqual(
                row["shared_coordinates"]["classes_shared_between_roles_non_data"], 0
            )
            self.assertEqual(
                len(row["shared_coordinates"]["endpoint_equality_slots"]), 2
            )
        self.assertTrue(rec["stage4_stacked"]["joint_is_computed_not_assumed"])
        s6 = rec["stage6_negative_controls"]
        self.assertTrue(s6["joint_reduction_against_a_dense_joint_rank"]["ok"])
        self.assertTrue(s6["stage4_joint_controls"]["all_fire"])
        for c in rec["stage2_commitment_side_joint_view"]["per_capture"]:
            for role in c["roles"]:
                self.assertTrue(role["certifying_minor"]["determinant_nonzero"])
                self.assertTrue(role["distinct_opened_columns_within_pad_count"])
        self.assertTrue(
            rec["stage2_commitment_side_joint_view"][
                "certifying_minors_all_nonsingular_within_the_pad_budget"
            ]
        )
        s2 = rec["stage2_commitment_side_joint_view"]
        self.assertTrue(s2["pad_block_at_the_full_budget"]["full_rank"])
        self.assertEqual(s2["pad_block_at_the_full_budget"]["pad_margin"], 0)
        self.assertFalse(s2["group_vectors_consume_pad_freedom"])
        for row in rec["stage3_masking_commitment_view"]["per_capture"]:
            self.assertTrue(row["derived_mask_evaluation"]["ok"])
        self.assertTrue(rec["stage6_negative_controls"]["pad_budget_boundary"]["ok"])


# =====================================================================
#  round 9e (2026-09-22): the manifest cross-check refuses BY NAME
# =====================================================================
class ManifestCheckRefusesByName(unittest.TestCase):
    """`manifest_check` may not skip itself quietly.

    Round 9d replayed a delivered bundle and the gate passed with its
    manifest cross-check silently OFF (`ZK60_NATIVE_D22_REPIN_4751B93.md`
    §8.5 observation 1): the file was called `capture-validation.json` and
    the check knew one name, so it reported `validation_json: absent` and
    the gate ran to the end.  Three neighbouring shapes -- a single
    `accepted` record, an unparsable file, an `accepted` that is neither --
    raised `TypeError`/`JSONDecodeError` naming neither the directory nor
    the file.  These tests pin the fixed behaviour: read BOTH shapes of
    `accepted`, and refuse by name in every case where the cross-check
    cannot be made.

    The synthetic capture below is the smallest document `Capture` accepts;
    `manifest_check` reads only a capture's file name, size, digest and
    `proof_sha256`, so nothing witness-bearing is needed or invented.
    """

    AS_DELIVERED = (
        "/home/victor/IntelligenceRegulation/results/"
        "zk60_security_probe_repin_20260922"
    )
    STEM = "aa" * 32

    def _dir(self, manifest=None, *, name="validation.json", raw=None,
             flip_artifact=False):
        import hashlib
        import json
        import tempfile
        d = tempfile.mkdtemp()
        self.addCleanup(__import__("shutil").rmtree, d)
        os.makedirs(os.path.join(d, "captures"))
        doc = {
            "schema": 3,
            "kind": "zk60-verifier-observations",
            "coverage": "native-all-slots-v1",
            "profile": "hashline-zk-mr1/private-block-t32-poc/1",
            "transcript_domain": "hashline-zk-mr1/private-block-t32-poc/1",
            "proof_sha256": self.STEM,
            "proof_bytes": 2816472,
            "source_commit": "0" * 40,
        }
        p = os.path.join(d, "captures", self.STEM + ".json")
        with open(p, "w") as fh:
            json.dump(doc, fh, indent=1, sort_keys=True)
            fh.write("\n")
        if raw is not None:
            with open(os.path.join(d, name), "w") as fh:
                fh.write(raw)
        elif manifest is not None:
            with open(p, "rb") as fh:
                blob = fh.read()
            man = dict(manifest)
            man["artifacts"] = {
                "captures/" + self.STEM + ".json": {
                    "sha256": ("00" * 32 if flip_artifact
                               else hashlib.sha256(blob).hexdigest()),
                    "bytes": len(blob),
                },
            }
            with open(os.path.join(d, name), "w") as fh:
                json.dump(man, fh, indent=1, sort_keys=True)
                fh.write("\n")
        return d

    def _accepted(self, stem=None):
        return {
            "canonical_capture_reproduced": True,
            "native_reverified": True,
            "proof_sha256": stem or self.STEM,
            "profile": "hashline-zk-mr1/private-block-t32-poc/1",
        }

    # ------------------------------------------------- the two shapes read
    def test_a_single_accepted_record_is_read_and_cross_checked(self):
        """The shape round 9d had to shim around: `accepted` is ONE record."""
        d = self._dir({"accepted": self._accepted(),
                       "source_commit": "1" * 40})
        out = manifest_check(d, load_all(d))
        self.assertEqual(out["validation_json"], "present")
        self.assertEqual(out["checked"], 1)
        self.assertEqual(out["mismatch"], [])
        self.assertEqual(out["source_commit"], "1" * 40)

    def test_the_integrators_delivered_bundle_is_read_and_cross_checked(self):
        """The same, on the real thing: the integrator's bundle of
        2026-09-22, READ-ONLY, under its own name `capture-validation.json`
        with a single `accepted` record.  It is uncommitted in the main
        tree, so its absence is a skip with a reason, never a pass."""
        if not os.path.isdir(self.AS_DELIVERED):
            self.skipTest(
                "the integrator's bundle is uncommitted in the main tree and "
                "is not on this box: " + self.AS_DELIVERED)
        self.assertFalse(
            os.path.exists(os.path.join(self.AS_DELIVERED, "validation.json")),
            "this case exists because the bundle carries NO validation.json",
        )
        self.assertTrue(
            os.path.exists(
                os.path.join(self.AS_DELIVERED, "capture-validation.json")))
        caps = load_all(self.AS_DELIVERED)
        self.assertEqual(len(caps), 1)
        out = manifest_check(self.AS_DELIVERED, caps)
        self.assertEqual(out["validation_json"], "present")
        self.assertEqual(out["checked"], 1)
        self.assertEqual(out["mismatch"], [])
        self.assertEqual(
            out["source_commit"], "4751b93ff4566e16fe07c61bd23d4cc2352f9f0b")

    def test_a_list_of_accepted_records_is_read(self):
        """The shape this lane's own writer produces, unchanged."""
        d = self._dir({"accepted": [self._accepted()]})
        out = manifest_check(d, load_all(d))
        self.assertEqual(out["checked"], 1)
        self.assertEqual(out["mismatch"], [])
        cs, _ = caps()
        of_record = manifest_check(CAPTURES, cs)
        self.assertEqual(of_record["checked"], 4)
        self.assertEqual(of_record["mismatch"], [])

    def test_the_records_of_record_are_answered_exactly_as_before_the_fix(self):
        """The load-bearing compatibility claim, machine-checked against the
        PRE-FIX bytes: on the directory the committed records were produced
        from, the fixed function returns what `d837d50`'s function returned,
        key for key.  This is why the records of record keep passing."""
        import subprocess
        import types
        src = subprocess.run(
            ["git", "--no-pager", "-C", ROOT, "show",
             "d837d50:scripts/zk60_native_jv_capture.py"],
            check=True, capture_output=True, text=True).stdout
        pre = types.ModuleType("jv_capture_pre_fix")
        exec(compile(src, "git:d837d50:zk60_native_jv_capture.py", "exec"),
             pre.__dict__)
        cs, _ = caps()
        self.assertEqual(
            manifest_check(CAPTURES, cs),
            pre.manifest_check(CAPTURES, pre.load_all(CAPTURES)),
            "the fix changed the answer on the directory of record; the "
            "committed records' manifest blocks would move",
        )

    # ------------------------------------------------ the named refusals
    def test_an_absent_validation_file_is_refused_by_name(self):
        d = self._dir()
        with self.assertRaises(ManifestRefusal) as cm:
            manifest_check(d, load_all(d))
        msg = str(cm.exception)
        self.assertIn(d, msg)
        for name in MANIFEST_NAMES:
            self.assertIn(name, msg)

    def test_an_unreadable_validation_file_is_refused_by_name(self):
        d = self._dir(raw="{not json\n")
        with self.assertRaises(ManifestRefusal) as cm:
            manifest_check(d, load_all(d))
        self.assertIn(os.path.join(d, "validation.json"), str(cm.exception))

    def test_an_accepted_that_is_neither_shape_is_refused_by_name(self):
        for bad in ("yes", 3, None):
            with self.subTest(accepted=bad):
                d = self._dir({"accepted": bad})
                with self.assertRaises(ManifestRefusal) as cm:
                    manifest_check(d, load_all(d))
                msg = str(cm.exception)
                self.assertIn(os.path.join(d, "validation.json"), msg)
                self.assertIn("`accepted`", msg)
        d = self._dir({"accepted": [{"no_proof_sha256": True}]})
        with self.assertRaises(ManifestRefusal) as cm:
            manifest_check(d, load_all(d))
        self.assertIn("proof_sha256", str(cm.exception))

    def test_a_manifest_that_disagrees_with_the_bundle_is_refused_by_name(self):
        """Three disagreements, each naming what disagrees.  Before the fix
        the first two came back in a `mismatch` list that NEITHER gate folds
        into its `ok`, so the gate passed on them."""
        d = self._dir({"accepted": [self._accepted()]}, flip_artifact=True)
        with self.assertRaises(ManifestRefusal) as cm:
            manifest_check(d, load_all(d))
        self.assertIn("captures/" + self.STEM + ".json", str(cm.exception))

        d = self._dir({"accepted": [self._accepted("bb" * 32)]})
        with self.assertRaises(ManifestRefusal) as cm:
            manifest_check(d, load_all(d))
        self.assertIn("not in the accepted list", str(cm.exception))
        self.assertIn(self.STEM[:16], str(cm.exception))

        rec = self._accepted()
        rec["native_reverified"] = False
        d = self._dir({"accepted": [rec]})
        with self.assertRaises(ManifestRefusal) as cm:
            manifest_check(d, load_all(d))
        self.assertIn("not reproduced/re-verified", str(cm.exception))

    # --------------------------------------- the one declared way through
    def test_absence_can_be_declared_by_the_caller_and_is_recorded(self):
        d = self._dir()
        out = manifest_check(d, load_all(d), no_validation_file=True)
        self.assertEqual(out["validation_json"], "absent")
        self.assertTrue(out["declared_absent_by_the_caller"])
        self.assertEqual(out["names_looked_for"], list(MANIFEST_NAMES))

    def test_a_declaration_of_absence_that_is_false_is_refused_by_name(self):
        d = self._dir({"accepted": [self._accepted()]})
        with self.assertRaises(ManifestRefusal) as cm:
            manifest_check(d, load_all(d), no_validation_file=True)
        self.assertIn(os.path.join(d, "validation.json"), str(cm.exception))

    # ------------------------------------------------- the two gates' exit
    def test_both_gates_refuse_and_return_3_instead_of_running(self):
        """The callers' half of the fix: the refusal is raised before any
        analysis, so a bundle with no manifest costs nothing and produces NO
        record -- rather than a green one with the check switched off."""
        import contextlib
        import io
        import tempfile
        import zk60_native_privacy_gate as p10
        d = self._dir()
        for name, main in (("joint_view", gate.main), ("privacy_gate", p10.main)):
            with self.subTest(gate=name):
                ev = tempfile.mkdtemp()
                self.addCleanup(__import__("shutil").rmtree, ev)
                err = io.StringIO()
                with contextlib.redirect_stderr(err):
                    rc = main(["--captures", d, "--evidence", ev])
                self.assertEqual(rc, 3)
                self.assertIn("REFUSED (manifest cross-check)", err.getvalue())
                self.assertEqual(os.listdir(ev), [],
                                 "a refused run must write no record")


if __name__ == "__main__":
    unittest.main()
