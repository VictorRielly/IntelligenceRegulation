"""The small model with real opening GROUPS (review change R-8).

Run:
  python3 -m unittest discover -s tests -p "test_zk60_native_small_model_groups.py"

WHAT WAS NEVER VALIDATED BEFORE.  The joint-view gate validates its stage-2
reduction against a brute-force dense rank on a toy instance
(`zk60_native_jv_smallmodel`) that has ONE OPENING GROUP PER CLAIM.  The real
receipts batch several claims with the same column-weight key into one group
with a challenge coefficient `lambda_c` per member.  The independent review
of the terminal-surjection step (2026-09-20,
`docs/zkmatrix-poc/ZK60_TERMINAL_SURJECTION_REVIEW.md`) found that the
batched case -- the whole subject of that step -- had never been
machine-validated inside the gate, and neither had a group whose members
share a reserved mask pair.  Change R-8 was accepted by the security owner
(`ZK60_JOINT_LAW_COMPOSITION_DISPOSITION.md`, ruling block "J-2 is
resolved").  These tests are that validation.

EVERY TEST ASSERTS THE ACTUAL BEHAVIOUR, including where the behaviour is a
finding about the tool: `test_the_reduction_does_not_see_one_position_beyond
_the_pad_budget` is an expected failure of the reduction, recorded as such,
with the guard that now refuses it asserted beside it.

NO TEST HERE ESTABLISHES A PRIVACY PROPERTY.  Every number is a rank of an
explicitly stated linear model on a synthetic instance whose data and
blinding are both known and both public.
"""

from __future__ import annotations

import os
import sys
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "scripts"))

from zk60_native_jv_field import F2_ZERO, rank  # noqa: E402
import zk60_native_jv_groups as groups  # noqa: E402
import zk60_native_jv_smallmodel as smallmodel  # noqa: E402

N = groups.N


class TheModelIsTheToolsOwn(unittest.TestCase):
    """The point of subclassing: the reduction and the dense map under test
    are the gate's code, not a second implementation that could agree with
    the first by sharing a bug."""

    def test_the_grouped_view_inherits_the_tools_reduction_and_dense_map(self):
        v = groups.multi_member(m=3, seed=1)
        self.assertIsInstance(v, smallmodel.ToyView)
        # inherited verbatim
        for name in ("observation_rows", "data_columns", "disclosed_bruteforce"):
            self.assertIs(
                getattr(type(v), name), getattr(smallmodel.ToyView, name), name
            )
        # overridden only to put the pad-budget guard in front of it: inside
        # the budget the two answers are the same object's answer
        self.assertIsNot(
            type(v).disclosed_reduction, smallmodel.ToyView.disclosed_reduction
        )
        self.assertEqual(
            v.disclosed_reduction(), smallmodel.ToyView.disclosed_reduction(v)
        )
        self.assertEqual(
            v.disclosed_reduction_unguarded(), smallmodel.ToyView.disclosed_reduction(v)
        )

    def test_one_group_per_claim_still_reproduces_the_old_small_models_answer(self):
        """A grouped view with every group a singleton is the old toy's shape,
        and must give the old toy's answer: nothing disclosed, both ways."""
        claims = [groups.Claim(site=c) for c in range(3)]
        gs = [groups.Group([c]) for c in range(3)]
        v = groups.GroupedToyView(claims, gs, seed=1).build()
        self.assertEqual(v.disclosed_bruteforce(), 0)
        self.assertEqual(v.disclosed_reduction()[0], 0)
        self.assertEqual(len(v.rhos), 4)  # three groups and the proximity vector


class CaseAMultiMemberGroup(unittest.TestCase):
    """(a) m >= 3 claims batched by lambda_c into ONE group.

    This is the case the real receipts use (A's largest group has 35 members)
    and the case the gate's small model never carried.  The reduction drops
    the individual claim values and keeps only the group combinations; the
    dense map keeps everything.  They must agree, and at 0."""

    def test_the_reduction_equals_the_dense_rank_at_several_m_and_several_draws(self):
        out = groups.case_a_multi_member(ms=(3, 4, 5), seeds=(1, 2, 3, 4))
        self.assertTrue(out["ok"])
        self.assertEqual(len(out["runs"]), 12)
        for r in out["runs"]:
            with self.subTest(m=r["m"], seed=r["seed"]):
                self.assertEqual(r["group_sizes"], [r["m"]])
                self.assertEqual(r["dense_disclosed_fp"], 0)
                self.assertEqual(r["reduction_disclosed_fp"], 0)
                self.assertTrue(r["agree"])
                self.assertTrue(r["hypotheses"]["H-pair"])
                self.assertTrue(r["hypotheses"]["groups_pairwise_disjoint_off_data"])

    def test_the_blinding_rank_is_the_reviews_closed_form(self):
        """The review's annihilator proof gives rank = 2(n + m) - 2 over Fp for
        EVERY m: the observation space (the group vector's message half, 2n,
        plus 2 per member) less the verifier's own identity, and nothing
        else.  Here n = 4, so the rank is 6 + 2m."""
        for m in (1, 2, 3, 4, 5, 6):
            v = groups.multi_member(m=m, seed=5)
            sysm = v.per_group_systems()[0]
            with self.subTest(m=m):
                self.assertEqual(sysm["observations_fp"], 2 * N + 2 * m)
                self.assertEqual(sysm["blinding_rank"], 2 * (N + m) - 2)
                self.assertTrue(sysm["rank_equals_2_n_plus_m_minus_2"])
                # codimension exactly 2: the one Fp2 identity <v, cw> = sum l y
                self.assertEqual(
                    sysm["observations_fp"] - sysm["blinding_rank"], 2
                )
                self.assertEqual(sysm["disclosed_fp"], 0)

    def test_the_group_vector_really_is_the_lambda_batch_of_its_members(self):
        """rho_g = sum_c lambda_c rw_c, as pcs.rs::zk_rhos and RoleView.run do
        it -- otherwise the test above would be about a different object."""
        from zk60_native_jv_field import f2_add, f2_mul

        v = groups.multi_member(m=4, seed=9)
        want = [F2_ZERO] * v.rows
        for m, lam in zip(v.group_specs[0].members, v.lambdas[0]):
            for i in range(v.rows):
                want[i] = f2_add(want[i], f2_mul(lam, v.rw[m][i]))
        self.assertEqual(v.rhos[0], want)
        self.assertEqual(len(v.lambdas[0]), 4)
        self.assertTrue(all(lam != F2_ZERO for lam in v.lambdas[0]))


class CaseBSharedPair(unittest.TestCase):
    """(b) two ordinary terminals on ONE reserved pair.

    The project's counterexample, now inside the gate's own model: every
    MARGINAL is still uniform and the JOINT law is not.  This is why the
    surjection step has to be stated jointly and not claim by claim."""

    @classmethod
    def setUpClass(cls):
        cls.out = groups.case_b_shared_pair(seed=1)
        cls.v = groups.shared_pair_in_one_group(m=3, seed=1)

    def test_every_marginal_is_unchanged_and_discloses_nothing(self):
        for c in (0, 1):
            law = self.v.terminal_law([c])
            with self.subTest(terminal=c):
                # one Fp2 terminal = 2 Fp observations, blinded to full rank
                self.assertEqual(law["observations_fp"], 2)
                self.assertEqual(law["support_dim"], 2)
                self.assertTrue(law["full_support"])
                self.assertEqual(law["surviving_data_functionals"], 0)
                # and no data vector can be told from another by it alone
                self.assertFalse(
                    self.v.law_separates_two_data_vectors([c])["supports_disjoint"]
                )

    def test_the_joint_law_is_short_and_moves_with_the_data(self):
        law = self.v.terminal_law([0, 1])
        self.assertEqual(law["observations_fp"], 4)
        self.assertEqual(law["support_dim"], 2)  # not 4: the pair is spent twice
        self.assertFalse(law["full_support"])
        self.assertEqual(law["annihilator_dim"], 2)
        self.assertEqual(law["surviving_data_functionals"], 2)
        # two data vectors, two DISJOINT supports: the joint law is a different
        # measure for each, while both marginals are the same measure
        sep = self.v.law_separates_two_data_vectors([0, 1])
        self.assertTrue(sep["supports_disjoint"])
        self.assertIsNotNone(sep["separating_coordinate"])
        self.assertIn(sep["separating_coordinate_row"], self.v.data_rows)

    def test_the_gate_refuses_it_and_the_dense_rank_sees_it(self):
        """The gate's H-pair check is what catches this: the reduction alone
        does NOT, because it drops the individual claim values and the group
        vector is unharmed by the sharing.  The reduction is sound only
        BEHIND that check, and this is the machine proof of it."""
        fig = self.out["in_one_group"]
        self.assertEqual(fig["dense_disclosed_fp"], 2)
        self.assertEqual(fig["reduction_disclosed_fp"], 0)  # the finding
        self.assertFalse(fig["agree"])
        self.assertFalse(fig["hypotheses"]["H-pair"])
        self.assertEqual(fig["hypotheses"]["claims_sharing_a_pair"], [[0, 1]])
        self.assertTrue(self.out["ok"])

    def test_across_two_groups_the_per_group_figure_misses_it_as_well(self):
        """Sharing WITHIN one group is caught by that group's own system (the
        review's control C1).  Sharing ACROSS two groups is not: each group in
        isolation looks perfect.  Only the joint rank sees it."""
        fig = self.out["across_two_groups"]
        self.assertEqual(fig["dense_disclosed_fp"], 2)
        self.assertEqual(fig["per_group_step_figure_fp"], 0)
        self.assertEqual(self.out["in_one_group"]["per_group_step_figure_fp"], 2)
        self.assertFalse(fig["hypotheses"]["groups_pairwise_disjoint_off_data"])
        self.assertEqual(fig["hypotheses"]["group_pairs_that_overlap_off_data"], [[0, 1]])


class CaseCHStyleSharing(unittest.TestCase):
    """(c) the one LEGITIMATE sharing: H's two opening groups on the zero-sum
    pair, tied by a public identity.

    WHY THE EXCEPTION EXISTS.  The surjection step models a reserved pair as
    two unconstrained uniform rows, so it concludes that any group whose
    members each carry a well-shaped pair discloses nothing.  The zero-sum
    pair is not two unconstrained rows: the layout publishes the constraint
    sum_t msg_u[t] = 0, and the sum claim's column weights are all-ones, so
    the pair's contribution to that claim's value vanishes IDENTICALLY and
    the value is pure data.  The step's per-group figure is therefore 0 and
    the truth is 2 -- which is why H has to be ranked jointly, with the
    exception written down."""

    @classmethod
    def setUpClass(cls):
        cls.out = groups.case_c_h_style(seed=1)
        cls.v = groups.h_style_sharing(seed=1)

    def test_ranked_jointly_the_only_disclosure_is_the_public_identity(self):
        self.assertEqual(self.out["ranked_jointly_fp"], 2)
        self.assertEqual(self.out["the_tools_reduction_fp"], 2)
        ident = self.out["the_disclosure_is_the_public_identity"]
        self.assertEqual(ident["rank_disclosed"], 2)
        self.assertEqual(ident["rank_public_identity"], 2)
        self.assertEqual(ident["rank_of_both_together"], 2)
        self.assertTrue(ident["spans_are_equal"])
        self.assertTrue(self.out["ok"])

    def test_ranked_per_group_the_figure_is_wrong(self):
        self.assertEqual(self.out["per_group_step_figure_fp"], 0)
        self.assertNotEqual(
            self.out["per_group_step_figure_fp"], self.out["ranked_jointly_fp"]
        )
        self.assertTrue(self.out["per_group_step_figure_is_wrong"])
        # and it becomes right again the moment the public constraint is put
        # back into the per-group system -- which is what the step omits
        self.assertEqual(
            self.out["figures"]["per_group_figure_with_the_public_constraint_fp"], 2
        )

    def test_the_gates_own_pair_check_does_not_notice_the_sharing(self):
        """The review's section 3.4 finding, reproduced: `audit_claims` (and
        `RoleView._check_pair_schedule`, which this model copies line for
        line) allows a claim to EVALUATE the zero-sum rows as well as carry
        its own pair, so the two groups' keys differ and nothing fires.  The
        premise that actually fails is the assembly premise (a), pairs
        disjoint ACROSS groups."""
        hyp = self.out["figures"]["hypotheses"]
        self.assertTrue(hyp["H-pair"])
        self.assertEqual(hyp["claims_sharing_a_pair"], [])
        self.assertFalse(hyp["groups_pairwise_disjoint_off_data"])
        self.assertEqual(hyp["group_pairs_that_overlap_off_data"], [[0, 1]])

    def test_the_two_groups_really_do_share_the_zero_sum_pair(self):
        u = set(self.v.u_rows)
        self.assertEqual(len(u), 2)
        for gi, spec in enumerate(self.v.group_specs):
            support = set()
            for m in spec.members:
                support |= {r for r in self.v.other_rows if self.v.rw[m][r] != F2_ZERO}
            with self.subTest(group=gi):
                self.assertTrue(u & support)
        # the sum claim's group carries the all-ones column weight, which is
        # what makes its pair's contribution vanish under the constraint
        self.assertEqual(self.v.group_cw[1], [(1, 0)] * N)


class CaseDWrongPairShape(unittest.TestCase):
    """(d) base-field-dependent pair weights with cm != 0.

    The review's correction R-1: the condition that carries privacy is the
    SHAPE of the pair's weights, (cm, cm*U) -- an Fp-basis of Fp2 -- and not
    merely cm != 0.  With the two weights Fp-dependent the pair still moves,
    but only through an n-dimensional Fp-subspace of Fp2^n instead of all
    2n."""

    @classmethod
    def setUpClass(cls):
        cls.out = groups.case_d_wrong_pair_shape(seed=1)

    def test_a_singleton_group_discloses_one_message_width_although_cm_is_nonzero(self):
        fig = self.out["singleton_fp_dependent"]
        self.assertEqual(fig["dense_disclosed_fp"], N)  # 256 Fp at the real scale
        self.assertEqual(fig["reduction_disclosed_fp"], N)
        self.assertTrue(fig["agree"])
        self.assertGreater(fig["dense_disclosed_fp"], 0)
        # cm is nonzero: the determinant check, not a zero coefficient, is
        # what refuses this
        self.assertFalse(fig["hypotheses"]["H-pair"])
        self.assertEqual(fig["hypotheses"]["claims_whose_pair_is_not_an_Fp_basis"], [0])
        self.assertEqual(fig["hypotheses"]["claims_with_no_reserved_pair"], [])

    def test_removing_the_pair_discloses_the_whole_message_half(self):
        fig = self.out["singleton_pair_removed"]
        self.assertEqual(fig["dense_disclosed_fp"], 2 * N)  # 512 Fp at real scale
        self.assertEqual(fig["reduction_disclosed_fp"], 2 * N)
        self.assertEqual(fig["hypotheses"]["claims_with_no_reserved_pair"], [0])

    def test_in_a_multi_member_group_the_other_members_cover_the_loss(self):
        """The review's control C8: the same broken shape in a 35-member group
        discloses nothing, because the other members' pairs already span the
        group vector's message half.  Only the singleton exposes it -- which
        is why the condition has to be in the STATEMENT and not inferred from
        a figure."""
        fig = self.out["multi_member_fp_dependent"]
        self.assertEqual(fig["dense_disclosed_fp"], 0)
        self.assertEqual(fig["reduction_disclosed_fp"], 0)
        self.assertEqual(fig["group_sizes"], [4])
        # the hypothesis check still fires: the figure is 0, the shape is wrong
        self.assertFalse(fig["hypotheses"]["H-pair"])
        self.assertTrue(self.out["ok"])


class CaseEZeroLambda(unittest.TestCase):
    """(e) lambda_c = 0 on one member of a batch.

    The review's correction R-1 again, the other way round: `lambda_c != 0`
    is refused by `check_opening_challenges` for SOUNDNESS (it stops a prover
    discarding a claim from the batch) and is NOT a privacy condition.  With
    it set to zero the member's pair simply drops out of the group vector
    while still blinding that member's own published value."""

    def test_zero_lambda_discloses_nothing_at_several_m_and_several_draws(self):
        out = groups.case_e_zero_lambda(ms=(3, 5), seeds=(1, 2, 3))
        self.assertTrue(out["ok"])
        self.assertEqual(len(out["runs"]), 6)
        for r in out["runs"]:
            with self.subTest(m=r["m"], seed=r["seed"]):
                self.assertTrue(r["lambda_0_is_zero"])
                self.assertEqual(r["dense_disclosed_fp"], 0)
                self.assertEqual(r["reduction_disclosed_fp"], 0)
                self.assertTrue(r["agree"])
                # every structural hypothesis still holds: nothing to refuse
                self.assertTrue(r["hypotheses"]["H-pair"])
                self.assertTrue(r["hypotheses"]["H-pad"])

    def test_the_zeroed_member_is_absent_from_the_group_vector(self):
        v = groups.multi_member(m=3, seed=1, zero_lambda=0)
        self.assertEqual(v.lambdas[0][0], F2_ZERO)
        pair = v.site_rows[0]
        for r in pair:
            self.assertEqual(v.rhos[0][r], F2_ZERO)
        # but the member's own claim value is still published and still blinded
        law = v.terminal_law([0])
        self.assertTrue(law["full_support"])
        self.assertEqual(law["surviving_data_functionals"], 0)


class CaseFBeyondThePadBudget(unittest.TestCase):
    """(f) one opened position more than there are pads.

    A FINDING ABOUT THE TOOL, and the guard added for it.  The reduction is a
    message-half reduction: it never looks at the opened columns, so it
    cannot see a leak that comes from them.  Inside the pad budget that is
    licensed (the pad block has rank equal to the number of distinct opened
    positions, so no functional of the columns is supported on the message
    positions); one position beyond it, it is not."""

    @classmethod
    def setUpClass(cls):
        cls.out = groups.case_f_beyond_the_pad_budget(seeds=(1, 2, 3))

    def test_the_dense_rank_sees_the_disclosure(self):
        for r in self.out["runs"]:
            with self.subTest(seed=r["seed"]):
                self.assertEqual(r["distinct_opened_positions"], r["pads"] + 1)
                self.assertGreater(r["dense_disclosed_fp"], 0)
                self.assertFalse(r["hypotheses"]["H-pad"])

    @unittest.expectedFailure
    def test_the_reduction_does_not_see_one_position_beyond_the_pad_budget(self):
        """EXPECTED FAILURE, recorded as the finding it is.

        With the guard removed, the reduction answers 0 on an instance whose
        dense rank is positive.  It is not a wrong rank: it is the right rank
        of the wrong system, because the reduction of the full view to the
        message-half system is valid only under H-pad.  The review's own
        small model fired the same control against its own reduction
        (section 3.5, addendum A5).  This test asserts the equality that
        SHOULD hold and fails, so the finding cannot be lost by someone
        reading a green suite."""
        v = groups.beyond_the_pad_budget(m=3, seed=1, q_pad=4, extra=1)
        self.assertEqual(v.disclosed_reduction_unguarded()[0], v.disclosed_bruteforce())

    def test_the_guard_refuses_exactly_outside_the_budget(self):
        """The guard added by this lane.  Its condition is the one the
        real-capture path already carries
        (`zk60_native_jv_pcs.RoleView._check_pad_budget`, fact
        `distinct_opened_columns_within_pad_count`, which feeds stage 2's
        verdict); until now the small-model path did not go through it."""
        for r in self.out["runs"]:
            with self.subTest(seed=r["seed"]):
                self.assertTrue(r["reduction_refused"])
                self.assertIsNone(r["reduction_disclosed_fp"])
                self.assertEqual(r["reduction_disclosed_fp_unguarded"], 0)
        inside = self.out["at_the_budget"]
        self.assertFalse(inside["reduction_refused"])
        self.assertEqual(inside["distinct_opened_positions"], inside["pads"])
        self.assertEqual(inside["reduction_disclosed_fp"], 0)
        self.assertEqual(inside["dense_disclosed_fp"], 0)
        self.assertTrue(self.out["ok"])

    def test_the_refusal_is_raised_and_names_the_budget(self):
        v = groups.beyond_the_pad_budget(m=3, seed=2, q_pad=4, extra=2)
        with self.assertRaises(groups.PadBudgetRefusal) as cm:
            v.disclosed_reduction()
        self.assertIn("pads", str(cm.exception))
        self.assertIn("6 distinct opened positions", str(cm.exception))


class TheRecord(unittest.TestCase):
    def test_all_six_cases_run_and_the_record_is_self_consistent(self):
        rec = groups.run_cases()
        self.assertTrue(rec["ok"])
        self.assertFalse(rec["privacy_property_established"])
        for key in (
            "a_multi_member_group",
            "b_shared_pair",
            "c_h_style_legitimate_sharing",
            "d_wrong_pair_shape",
            "e_zero_lambda",
            "f_beyond_the_pad_budget",
        ):
            with self.subTest(case=key):
                self.assertTrue(rec[key]["ok"], key)

    def test_the_retained_evidence_matches_a_fresh_run(self):
        import json

        path = os.path.join(
            ROOT,
            "results",
            "zk60_native_small_model_groups",
            "small_model_groups.json",
        )
        self.assertTrue(os.path.exists(path), "run scripts/zk60_native_jv_groups.py first")
        with open(path) as fh:
            kept = json.load(fh)
        self.assertTrue(kept["ok"])
        fresh = groups.run_cases()
        # the model is seeded, so a fresh run must reproduce the record exactly
        self.assertEqual(
            json.dumps(kept["cases"], sort_keys=True), json.dumps(fresh, sort_keys=True)
        )

    def test_the_disclosed_space_basis_agrees_with_the_dense_figure(self):
        """A cross-check of the machinery the H-style identity test rests on:
        the rank of the explicit basis of F intersect T must be the dense
        disclosed dimension computed the other way."""
        for v in (
            groups.multi_member(m=3, seed=2),
            groups.shared_pair_in_one_group(m=3, seed=2),
            groups.h_style_sharing(seed=2),
            groups.wrong_pair_shape(m=1, seed=2),
        ):
            basis, dlist = v.disclosed_space()
            with self.subTest(view=type(v).__name__ + str(v.rows)):
                self.assertEqual(rank(basis, len(dlist)) if basis else 0,
                                 v.disclosed_bruteforce())


class TheExistingSmallModelIsUntouched(unittest.TestCase):
    """The gate writes the SHA-256 of `zk60_native_jv_smallmodel.py` into its
    record and a test compares it, so this lane may not edit that file.  These
    two assertions make an accidental edit fail here as well."""

    def test_the_old_controls_still_report_what_the_gate_expects(self):
        ctl = smallmodel.controls()
        self.assertEqual(ctl["honest"]["bruteforce"], 0)
        self.assertEqual(ctl["honest"]["reduction"], 0)
        for name in (
            "masks_removed",
            "two_claims_share_one_pair",
            "commitment_opened_twice",
            "extra_published_helper_sum",
            "one_pad_fewer_than_opened_columns",
        ):
            with self.subTest(control=name):
                self.assertGreater(ctl[name]["bruteforce"], 0)

    def test_the_base_class_now_carries_the_guard_too(self):
        """The owed one-line follow-up, taken 2026-09-20.

        `ToyView.disclosed_reduction` used to answer 0 on an instance beyond
        the pad budget without refusing; the guard lived only in the subclass,
        because editing this module changes the hash recorded in evidence
        already committed.  The evidence has now been regenerated, so the
        guard is in the base class and the UNGUARDED entry point is the only
        way to see the wrong answer -- which the dense rank contradicts.
        """
        v = smallmodel.ToyView(seed=6, n_cols=4, q_pad=3).build()
        self.assertFalse(v.hypotheses()["H-pad"])
        with self.assertRaises(smallmodel.PadBudgetRefusal) as cm:
            v.disclosed_reduction()
        self.assertIn("exceed the 3 pads", str(cm.exception))
        self.assertEqual(v.disclosed_reduction_unguarded()[0], 0)
        self.assertGreater(v.disclosed_bruteforce(), 0)

    def test_the_two_refusal_classes_are_one_class(self):
        """`groups.PadBudgetRefusal` is an alias, so every existing
        `except`/`assertRaises` against either name catches both paths."""
        self.assertIs(groups.PadBudgetRefusal, smallmodel.PadBudgetRefusal)
        v = groups.beyond_the_pad_budget(m=3, seed=2, q_pad=4, extra=2)
        with self.assertRaises(smallmodel.PadBudgetRefusal):
            v.disclosed_reduction()
        with self.assertRaises(groups.PadBudgetRefusal):
            smallmodel.ToyView.disclosed_reduction(v)


if __name__ == "__main__":
    unittest.main()
