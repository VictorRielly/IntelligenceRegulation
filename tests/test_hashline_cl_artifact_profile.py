"""[ZK60-CL10] Tests for the proof-artifact component profile.

No GPU, no proof generation, no sensitive exports. The artifact sizes used
here are the frozen, published lane-AM values, so these tests pin the model
against numbers that were measured elsewhere and independently.

[round-7, Codex 2026-09-06] The expected W counts below are the ones Codex
recorded from a Rust helper through `ZkLayoutV3::new` (10,752 plain / 10,774
hiding / 22 mask rows / 16,384 columns) and the ones the prover itself prints
in the archived Mistral log; the model no longer contains them as constants,
it derives them, and these tests are what stop the derivation drifting.
"""

import importlib.util
import json
import os
import re
import sys
import unittest

_HERE = os.path.dirname(os.path.abspath(__file__))
_ROOT = os.path.dirname(_HERE)
_SRC = os.path.join(_ROOT, "scripts", "hashline_cl_artifact_profile.py")
_spec = importlib.util.spec_from_file_location("hashline_cl_artifact_profile", _SRC)
prof = importlib.util.module_from_spec(_spec)
sys.modules[_spec.name] = prof
_spec.loader.exec_module(prof)

# Measured, published elsewhere: lane AM rung 2 / CL1 rung 4 (am_r2_mistral.log).
P1_BYTES = 40186228
P3_BYTES = 40251860

# Codex's recorded Rust layout counts (results/zk60_round7_claude_review.json,
# key cl10_rust_layout_counts). Read from the file when it is present so a
# re-recorded count reaches this test without an edit; otherwise the values
# Codex published in the round-7 review are used, cited here as such.
_RECORDED_FALLBACK = {"plain_w_rows": 10752, "private_w_rows": 10774, "w_mask_rows": 22, "w_cols": 16384}


def _recorded_rust_counts():
    for root in (_ROOT, os.path.dirname(_ROOT)):
        p = os.path.join(root, "results", "zk60_round7_claude_review.json")
        if os.path.exists(p):
            with open(p) as fh:
                return json.load(fh)["cl10_rust_layout_counts"], p
    return _RECORDED_FALLBACK, "round-7 review text"


# The archived prover log with the real mask-site dump. Optional: the test
# that reads it is skipped where the archive is not mounted.
_AM_LOG = os.environ.get("HL_AM_R2_MISTRAL_LOG", "/home/victor/wt-uperf3-am/results/am_r2_mistral.log")


class RustMirror(unittest.TestCase):
    """Finding 1: W rows per mode come from a mirror of the Rust layout rule and
    are checked against Rust-recorded counts, not against a constant that was
    pasted into both the model and its test."""

    def test_w_rows_match_the_recorded_rust_layout_counts(self):
        want, source = _recorded_rust_counts()
        plain = prof.w_shape(4096, 14336, 14, hiding=False)
        hiding = prof.w_shape(4096, 14336, 14, hiding=True)
        self.assertEqual(plain["rows"], want["plain_w_rows"], source)
        self.assertEqual(hiding["rows"], want["private_w_rows"], source)
        self.assertEqual(hiding["mask_rows"], want["w_mask_rows"], source)
        self.assertEqual(plain["mask_rows"], 0, "a plain W commitment carries no mask rows")
        self.assertEqual(plain["cols"], want["w_cols"], source)
        self.assertEqual(hiding["cols"], want["w_cols"], source)

    def test_the_declared_layouts_use_those_rows_per_mode(self):
        w1 = next(c for c in prof.get_layout("mistral-v3-layer-P1").commitments if c.role == "W")
        w3 = next(c for c in prof.get_layout("mistral-v3-layer-P3").commitments if c.role == "W")
        self.assertFalse(w1.hiding, "P1's W opening is the plain `Opening`")
        self.assertTrue(w3.hiding, "P3's W opening is `OpeningZk`")
        self.assertEqual((w1.rows, w3.rows), (10752, 10774))
        self.assertEqual(w3.rows - w1.rows, 22, "21 block masks + 1 proximity row")

    def test_the_mirror_is_the_planners_rule_not_a_pasted_constant(self):
        """If W's rows were a constant, a second shape would not move them.
        frugal-lm's 768->2048 ladder shape is the planner's own second case."""
        planner = prof._memory_plan()
        for d, f in ((4096, 14336), (768, 2048), (16, 16)):
            s = planner.weight_shape(d, f, 14)
            self.assertEqual(prof.w_shape(d, f, 14, hiding=False)["rows"], s["data_rows"])
            self.assertEqual(prof.w_shape(d, f, 14, hiding=True)["rows"], s["rows"])
        self.assertEqual(prof.w_shape(768, 2048, 14, hiding=True)["rows"], 298)
        self.assertEqual(prof.w_shape(768, 2048, 14, hiding=False)["rows"], 288)

    @unittest.skipUnless(os.path.exists(_AM_LOG), "archived lane-AM Mistral log not mounted here")
    def test_w_rows_match_the_archived_prover_dump(self):
        """The prover prints its own W layout under P3; the mirror must agree
        with the binary, not merely with another Python file."""
        with open(_AM_LOG, errors="replace") as fh:
            text = fh.read()
        m = re.search(r"W masks \(P3\): commitment (\d+) rows of 2\^(\d+) = (\d+) data \+ (\d+) block masks \+ 1 prox row", text)
        self.assertIsNotNone(m, "the mask-site dump line is not in the log")
        rows, log_n, data, blocks = (int(x) for x in m.groups())
        hiding = prof.w_shape(4096, 14336, 14, hiding=True)
        self.assertEqual((hiding["rows"], hiding["log_cols"], hiding["data_rows"], hiding["mask_rows"]),
                         (rows, log_n, data, blocks + 1))
        for want in (f"proof {P1_BYTES} B", f"proof {P3_BYTES} B"):
            self.assertIn(want, text, "the observed artifact sizes pinned here are the log's")


class ReviewTable(unittest.TestCase):
    """Finding 1, the corrected column attribution — the round-7 table."""

    def test_column_components_match_the_corrected_table(self):
        p1 = prof.profile(prof.get_layout("mistral-v3-layer-P1"), P1_BYTES)["components"]
        p3 = prof.profile(prof.get_layout("mistral-v3-layer-P3"), P3_BYTES)["components"]
        self.assertEqual(p1["opened_column_data_bytes"], 35606528)
        self.assertEqual(p1["opened_column_framing_bytes"], 415744)
        self.assertEqual(p1["opened_columns_total_bytes"], 36022272)
        self.assertEqual(p3["opened_column_data_bytes"], 35651584)
        self.assertEqual(p3["opened_column_framing_bytes"], 423936)
        self.assertEqual(p3["opened_columns_total_bytes"], 36075520)
        self.assertEqual(p3["opened_column_data_bytes"] - p1["opened_column_data_bytes"], 45056)
        self.assertEqual(p3["opened_column_framing_bytes"] - p1["opened_column_framing_bytes"], 8192)
        self.assertEqual(p3["opened_column_salt_bytes"] - p1["opened_column_salt_bytes"], 8192,
                         "the whole framing delta is the 256 W salts P3 adds")
        self.assertEqual(p3["opened_columns_total_bytes"] - p1["opened_columns_total_bytes"], 53248)

    def test_the_residual_delta_after_columns_is_12384_not_65632(self):
        """The review's arithmetic: observed delta 65,632 minus the column delta
        53,248 leaves 12,384 B outside the columns — not the whole delta, as the
        round-6 report claimed."""
        p1 = prof.profile(prof.get_layout("mistral-v3-layer-P1"), P1_BYTES)["components"]
        p3 = prof.profile(prof.get_layout("mistral-v3-layer-P3"), P3_BYTES)["components"]
        outside_columns = (P3_BYTES - P1_BYTES) - (p3["opened_columns_total_bytes"] - p1["opened_columns_total_bytes"])
        self.assertEqual(outside_columns, 12384)


class Vectors(unittest.TestCase):
    """Finding 2: group/proximity vectors are counted explicitly when their
    shapes are declared, and otherwise named as part of the unknown residual."""

    def test_vector_lengths_follow_the_opening_type(self):
        plain = prof.CommitmentOpening(role="W", rows=10752, columns=256, path_len=16, hiding=False, cols=16384, groups=2)
        zk = prof.CommitmentOpening(role="W", rows=10774, columns=256, path_len=16, hiding=True, cols=16384, groups=2)
        self.assertEqual(plain.vector_len(), 16384, "`Opening`: n entries")
        self.assertEqual(zk.vector_len(), 16384 + 256, "`OpeningZk`: n message + Q pad entries")
        self.assertEqual(zk.vector_bytes() - plain.vector_bytes(), 3 * 256 * prof.FP2)

    def test_mistral_vectors_are_counted_and_are_a_tenth_of_the_artifact(self):
        r = prof.profile(prof.get_layout("mistral-v3-layer-P3"), P3_BYTES)
        c = r["components"]
        self.assertEqual(c["vectors_counted_for"], ["W", "A", "H"])
        # W: 2 groups + prox; A, H: 5 groups + prox each; all n+Q = 16,640 Fp2.
        self.assertEqual(c["group_and_proximity_vector_bytes"], (3 + 6 + 6) * 16640 * prof.FP2)
        self.assertGreater(r["shares"]["group_and_proximity_vectors"], 0.09)
        self.assertNotIn("group/proximity", r["residual_note"])

    def test_undeclared_vectors_are_named_in_the_residual_not_silently_zero(self):
        lay = prof.Layout(
            name="partial", mode="P3",
            commitments=(prof.CommitmentOpening(role="W", rows=10774, columns=256, path_len=16, hiding=True, cols=16384),),
            commitment_headers=1, mask_opening=None,
        )
        r = prof.profile(lay, P3_BYTES)
        self.assertEqual(r["components"]["group_and_proximity_vector_bytes"], 0)
        self.assertEqual(r["components"]["vectors_counted_for"], [])
        self.assertIn("group/proximity vectors of W", r["residual_note"])
        self.assertIn("mask opening", r["residual_note"])
        self.assertTrue(r["residual_note"].startswith("UNKNOWN residual"))

    def test_the_residual_is_never_called_a_measurement_of_arguments(self):
        for name, obs in (("mistral-v3-layer-P1", P1_BYTES), ("mistral-v3-layer-P3", P3_BYTES)):
            r = prof.profile(prof.get_layout(name), obs)
            self.assertIn("NOT a measurement", r["residual_note"])
            self.assertIn("sumcheck rounds", r["residual_contents"])
            self.assertIn("unknown_residual", r["shares"])
            self.assertNotIn("residual_arguments", r["shares"])


class Reconciliation(unittest.TestCase):
    def test_each_mode_reconciles_independently_with_a_bounded_residual(self):
        """Each mode against ITS OWN artifact: derived <= observed, exact
        reconciliation, and a residual small enough that a mis-assigned W row
        (2,048 B) or salt block (8,192 B) would be a visible fraction of it."""
        for name, obs in (("mistral-v3-layer-P1", P1_BYTES), ("mistral-v3-layer-P3", P3_BYTES)):
            r = prof.profile(prof.get_layout(name), obs)
            self.assertTrue(r["reconciles_exactly"], name)
            self.assertEqual(r["components"]["derived_total_bytes"] + r["residual_bytes"], obs)
            self.assertGreater(r["residual_bytes"], 0, f"{name}: a zero residual would mean over-modelling")
            self.assertLess(r["residual_bytes"], 10_000, f"{name}: residual {r['residual_bytes']} B")

    def test_opened_column_data_dominates_in_both_modes(self):
        for name, obs in (("mistral-v3-layer-P1", P1_BYTES), ("mistral-v3-layer-P3", P3_BYTES)):
            r = prof.profile(prof.get_layout(name), obs)
            self.assertGreater(r["shares"]["opened_column_data"], 0.88, name)
            self.assertLess(r["shares"]["opened_column_framing"], 0.011, name)


class ModeCrossCheck(unittest.TestCase):
    """Finding 3: a cross-check that CAN detect a mode-dependent misallocation.
    Each component's P3-P1 delta is compared with what the source says P3
    adds, and the residual delta must equal the ONE P3 cost this model does
    not carry as a component: two extra degree-2 sumcheck rounds (96 B)."""

    def _delta(self):
        p1 = prof.profile(prof.get_layout("mistral-v3-layer-P1"), P1_BYTES)
        p3 = prof.profile(prof.get_layout("mistral-v3-layer-P3"), P3_BYTES)
        return prof.mode_delta(p1, p3)

    def test_the_observed_delta_is_explained_component_by_component(self):
        d = self._delta()
        self.assertEqual(d["observed_delta_bytes"], 65632)
        self.assertEqual(d["opened_column_data_bytes"], 22 * 256 * prof.FP, "22 W rows x 256 columns")
        self.assertEqual(d["opened_column_salt_bytes"], 256 * prof.DIGEST, "a salt per opened W column")
        self.assertEqual(d["group_and_proximity_vector_bytes"], 3 * 256 * prof.FP2, "Q pads on W's three vectors")
        self.assertEqual(d["mask_opening_bytes"], 0, "the mask commitment's shape is mode-independent")
        self.assertEqual(d["commitment_header_bytes"], 0)
        self.assertEqual(d["residual_delta_bytes"], prof.p3_extension_round_bytes(), "2 matmul sumchecks x (2+1) Fp2")
        self.assertEqual(d["residual_delta_bytes"], 96)
        self.assertEqual(d["explained_delta_bytes"] + d["residual_delta_bytes"], d["observed_delta_bytes"])

    @staticmethod
    def _round6_model(mode):
        """The model as it stood before the review, rebuilt faithfully: W has
        P3's 10,774 salted rows in BOTH modes, and the group/proximity vectors
        and the mask opening are not counted (they sat inside the residual)."""
        coms = tuple(prof.CommitmentOpening(role=r, rows=n, columns=256, path_len=16, hiding=True, cols=16384)
                     for r, n in (("W", 10774), ("A", 3601), ("H", 3033)))
        return prof.Layout(name=f"round6-{mode}", mode=mode, commitments=coms, commitment_headers=3, mask_opening=None)

    def test_the_cross_check_rejects_the_round_6_misallocation(self):
        """The old model fitted both artifacts (about 4.1 MB of slack, because
        the vectors and the mask opening were uncounted) and put NO delta in
        the columns. This check refuses it: its residual delta is 65,632, not
        the 96 B the source accounts for."""
        d = prof.mode_delta(prof.profile(self._round6_model("P1"), P1_BYTES),
                            prof.profile(self._round6_model("P3"), P3_BYTES))
        self.assertEqual(d["opened_columns_total_bytes"], 0, "the wrong model puts no delta in the columns")
        self.assertEqual(d["residual_delta_bytes"], 65632, "...and all of it in the residual")
        self.assertNotEqual(d["residual_delta_bytes"], prof.p3_extension_round_bytes(), "which this check refuses")

    def test_the_corrected_accounting_cannot_even_fit_the_misallocation(self):
        """Stronger still: once the vectors and the mask opening are counted the
        model is tight enough that giving P1 the hiding W (10,774 salted rows)
        EXCEEDS the P1 artifact by 57,136 B, so `profile` refuses it outright.
        The round-6 slack that let the wrong allocation pass is gone."""
        right_p3 = prof.mistral_v3_layer("P3")
        wrong_p1 = prof.Layout(name="mistral-v3-layer-P1-WRONG", mode="P1", commitments=right_p3.commitments,
                               commitment_headers=3, mask_opening=right_p3.mask_opening)
        with self.assertRaises(prof.ProfileError) as cm:
            prof.profile(wrong_p1, P1_BYTES)
        self.assertIn("EXCEED", str(cm.exception))
        self.assertIn("57136", str(cm.exception))

    def test_why_the_old_cross_check_was_an_identity(self):
        """residual = observed - derived. When two layouts have the same derived
        total, residual_P3 - residual_P1 == observed_P3 - observed_P1 for ANY
        pair of observed sizes, right model or wrong; the old test asserted
        exactly that and so could not fail on the misallocation it was meant to
        catch. Shown on the round-6 model, which passes it for every pair."""
        a_lay, b_lay = self._round6_model("P1"), self._round6_model("P3")
        self.assertEqual(a_lay.derived()["derived_total_bytes"], b_lay.derived()["derived_total_bytes"])
        for observed_pair in ((P1_BYTES, P3_BYTES), (P1_BYTES + 1, P1_BYTES + 12345), (1_000_000_000, 1_000_065_632)):
            a = prof.profile(a_lay, observed_pair[0])
            b = prof.profile(b_lay, observed_pair[1])
            self.assertEqual(b["residual_bytes"] - a["residual_bytes"], observed_pair[1] - observed_pair[0])


class Refusals(unittest.TestCase):
    """CL10: unknown legacy layouts are REFUSED rather than guessed."""

    def test_unknown_layout_is_refused(self):
        with self.assertRaises(prof.ProfileError) as cm:
            prof.get_layout("some-legacy-v1-thing")
        self.assertIn("REFUSED", str(cm.exception))

    def test_unknown_mode_is_refused(self):
        with self.assertRaises(prof.ProfileError):
            prof.mistral_v3_layer("P2")

    def test_underspecified_layout_is_refused(self):
        bad = prof.Layout(
            name="bad", mode="P3",
            commitments=(prof.CommitmentOpening(role="W", rows=0, columns=256, path_len=16, hiding=True, cols=16384),),
            commitment_headers=1,
        )
        with self.assertRaises(prof.ProfileError) as cm:
            prof.profile(bad, 1000)
        self.assertIn("refused, not defaulted", str(cm.exception))

    def test_a_model_that_exceeds_the_artifact_is_refused(self):
        """If the derived components do not fit inside the observed artifact the
        model has drifted; a breakdown that cannot be true must not be printed."""
        with self.assertRaises(prof.ProfileError) as cm:
            prof.profile(prof.get_layout("mistral-v3-layer-P3"), 1_000_000)
        self.assertIn("EXCEED", str(cm.exception))

    def test_the_p3_model_does_not_fit_the_p1_artifact(self):
        """The corrected models are tight enough that the modes are not
        interchangeable: P3's derived total exceeds the P1 artifact."""
        with self.assertRaises(prof.ProfileError):
            prof.profile(prof.get_layout("mistral-v3-layer-P3"), P1_BYTES)

    def test_non_positive_observed_size_is_refused(self):
        with self.assertRaises(prof.ProfileError):
            prof.profile(prof.get_layout("mistral-v3-layer-P3"), 0)


class Components(unittest.TestCase):
    def test_data_and_framing_sum_to_the_column_total(self):
        for hiding in (False, True):
            c = prof.CommitmentOpening(role="W", rows=10774, columns=256, path_len=16, hiding=hiding, cols=16384)
            self.assertEqual(c.data_only_bytes() + c.framing_bytes(), c.column_bytes())

    def test_salt_only_under_the_hiding_opening(self):
        plain = prof.CommitmentOpening(role="W", rows=100, columns=256, path_len=16, hiding=False, cols=16384)
        zk = prof.CommitmentOpening(role="W", rows=100, columns=256, path_len=16, hiding=True, cols=16384)
        self.assertEqual(plain.salt_bytes(), 0)
        self.assertEqual(zk.salt_bytes(), 256 * prof.DIGEST)
        self.assertEqual(zk.framing_bytes() - plain.framing_bytes(), 256 * prof.DIGEST)

    def test_framing_is_independent_of_rows(self):
        """Per-column index + salt + path do not scale with committed rows, so
        framing cannot be reduced by changing the shape — only by opening
        fewer columns, which is a protocol change with a soundness cost."""
        a = prof.CommitmentOpening(role="A", rows=100, columns=256, path_len=16, hiding=True, cols=16384)
        b = prof.CommitmentOpening(role="B", rows=100000, columns=256, path_len=16, hiding=True, cols=16384)
        self.assertEqual(a.framing_bytes(), b.framing_bytes())

    def test_mask_opening_shape_follows_the_zk_constants(self):
        m = prof.MaskOpeningShape(sumchecks=6)
        self.assertEqual(m.rows(), 16, "2 a-rows per sumcheck + b_re, b_im, u_re, u_im")
        self.assertEqual(m.vector_bytes(), 2 * 1024 * prof.FP2, "q' and prox: 2m = 1024 Fp2 each")
        self.assertEqual(m.column_bytes(), 256 * (8 + 16 * 8 + 32 + 12 * 32))
        self.assertEqual(prof.MaskOpeningShape(sumchecks=7).rows(), 18, "function 2 adds the predicate sumcheck")

    def test_profile_output_keeps_bytes_and_time_apart(self):
        r = prof.profile(prof.get_layout("mistral-v3-layer-P1"), P1_BYTES)
        self.assertIn("says nothing about serialization, transfer or allocation time", r["bytes_not_time"])


if __name__ == "__main__":
    unittest.main()
