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


# ===========================================================================
# [ZK60-CL19] The consumer of Codex's HASHLINE_PROOF_SIZE row (schema 1).
#
# The producer — `LayerProofZk::size_breakdown()` in hashline/src/zk_proof_size.rs
# and the CLI row in hashline/src/bin/hashline.rs — is Codex's, read UNCOMMITTED
# from the main checkout at 52a13d1's tree on 2026-09-07. Synthetic rows here
# are DERIVED from the layout mirror in the exact shape of `to_json()`; one
# ACTUAL row (the frozen 12x512 zkv3 layer 0, P1) is pinned verbatim from
# Codex's validation record so the consumer is tested against a real row even
# where that record is not mounted. Tests that read Codex's uncommitted files
# or its /tmp validation logs are skipped where they are absent.
# ===========================================================================

import contextlib
import io
import tempfile

_ROUND10_DIR = os.environ.get("HL_ZK60_ROUND10_DIR", "/tmp/zk60-round10")
_MAIN = os.environ.get("HL_MAIN_CHECKOUT", "/home/victor/IntelligenceRegulation")
_CODEX_MODULE = os.path.join(_MAIN, "hashline", "src", "zk_proof_size.rs")
_VALIDATION_JSON = os.path.join(_MAIN, "results", "zk60_round10_validation.json")
_LANE_P1_LOG = os.path.join(_ROOT, "results", "cl5_r7", "p1cold.1.log")
_LANE_P3_LOG = os.path.join(_ROOT, "results", "cl5_r7", "p3.1.log")

# results/zk60_round10_validation.json -> frozen_size_rows[0] (uncommitted in the
# main checkout when read; file sha256 3239030..5dd273): the row the prover
# printed for layer 0 of the frozen zkv3 fixture (`pass 12 512 --profile v3
# --zk --seed 1 --phase-profile`, CPU, 2 threads), whose file digest is the
# frozen 40eb5479.. / 87,697,008 B. Verbatim, key order as emitted.
ACTUAL_ROW_L0_P1 = (
    '{"schema":1,"unit":"bytes","coverage":"ffn-only","profile":"v3","privacy":"P1","layer":0,"serialized":true,'
    '"pass_verified":true,"sizes":{"total_bytes":7306036,"commitment_headers":132,"mask_root":32,"arguments":['
    '{"name":"gu","claim_or_challenge":16,"round_evaluations":432,"terminals":144},'
    '{"name":"d","claim_or_challenge":16,"round_evaluations":576,"terminals":64},'
    '{"name":"zc20","claim_or_challenge":16,"round_evaluations":1680,"terminals":160},'
    '{"name":"zc17","claim_or_challenge":16,"round_evaluations":1440,"terminals":192},'
    '{"name":"zs","claim_or_challenge":16,"round_evaluations":720,"terminals":16},'
    '{"name":"table","claim_or_challenge":16,"round_evaluations":1088,"terminals":192}],'
    '"mask_opening":{"functional_vector":16384,"proximity_vector":16384,"columns":{"indices":2048,"values":32768,"salts":8192,"authentication_paths":98304}},'
    '"w_plain":{"group_vectors":524288,"proximity_vector":262144,"columns":{"indices":2048,"values":589824,"salts":0,"authentication_paths":131072}},'
    '"w_hiding":{"group_vectors":0,"proximity_vector":0,"columns":{"indices":0,"values":0,"salts":0,"authentication_paths":0}},'
    '"a":{"group_vectors":1331200,"proximity_vector":266240,"columns":{"indices":2048,"values":1144832,"salts":8192,"authentication_paths":131072}},'
    '"h":{"group_vectors":1331200,"proximity_vector":266240,"columns":{"indices":2048,"values":993280,"salts":8192,"authentication_paths":131072}},'
    '"predicate":null}}'
)


def _row(mode="P1", fixture="zkv3-12x512-layer0", **kw):
    return prof.derive_row(prof.get_fixture(fixture), mode, **kw)


def _log(rows, privacy, layer_bytes=None, proof_bytes=None, timing=True, header=True):
    lines = []
    if header:
        lines.append("pass (v3) [ZK, randomness deterministic-test]: 2 layers x 512 tokens of 512 — /x "
                     "(d 768 f 2048; log_cols 14, inv_rate 4, col checks 256, threads 2)")
        lines.append(f"  MODE {privacy} (tier) [v3] header \"x\": ...")
    for r in rows:
        lines.append(f"  layer  {r['layer']}: prove 1.000 s, {(layer_bytes or {}).get(r['layer'], r['sizes']['total_bytes'])} B")
    total = proof_bytes if proof_bytes is not None else sum(r["sizes"]["total_bytes"] for r in rows)
    lines.append(f"PROOF sha256 {'0' * 64} ({total} B) [ZK v3 randomness deterministic-test]")
    if timing:
        lines.append("HASHLINE_TIMING " + json.dumps({"schema": 1, "privacy": privacy, "proof_bytes": total}))
    for r in rows:
        lines.append("HASHLINE_PROOF_SIZE " + json.dumps(r, separators=(",", ":")))
    return "\n".join(lines) + "\n"


class CL19Schema(unittest.TestCase):
    """The section list is Codex's `to_json()`, mirrored verbatim — not an
    invented schema — and every leaf of a row is one schema path."""

    def test_schema_paths_partition_a_row_with_no_duplicates(self):
        paths = prof.schema_paths()
        self.assertEqual(len(paths), len(set(paths)), "a path listed twice would count a section twice")
        self.assertEqual(set(paths), set(prof.flatten_sizes(_row()["sizes"])))
        self.assertEqual(len(paths), 2 + 6 * 3 + 6 + 4 * 6 + 1)

    def test_derived_row_has_codex_key_order_and_argument_order(self):
        row = _row()
        self.assertEqual(tuple(row), prof.ROW_KEYS)
        self.assertEqual(tuple(row["sizes"]), prof.SIZES_KEYS)
        self.assertEqual(tuple(a["name"] for a in row["sizes"]["arguments"]), prof.ARGUMENT_NAMES)
        self.assertEqual(tuple(row["sizes"]["arguments"][0]), prof.ARGUMENT_KEYS)
        self.assertEqual(tuple(row["sizes"]["a"]), prof.OPENING_KEYS)
        self.assertEqual(tuple(row["sizes"]["mask_opening"]), prof.MASK_KEYS)
        self.assertEqual(tuple(row["sizes"]["a"]["columns"]), prof.COLUMN_KEYS)

    def test_the_actual_row_has_exactly_that_key_order(self):
        """The order the prover printed (Codex's evidence) equals the mirror's."""
        actual = prof.loads_strict(ACTUAL_ROW_L0_P1)
        derived = _row()
        self.assertEqual(list(actual), list(derived))
        self.assertEqual(list(actual["sizes"]), list(derived["sizes"]))
        for k in ("mask_opening", "w_plain", "w_hiding", "a", "h"):
            self.assertEqual(list(actual["sizes"][k]), list(derived["sizes"][k]), k)
            self.assertEqual(list(actual["sizes"][k]["columns"]), list(derived["sizes"][k]["columns"]), k)
        self.assertEqual([list(a) for a in actual["sizes"]["arguments"]], [list(a) for a in derived["sizes"]["arguments"]])

    @unittest.skipUnless(os.path.exists(_CODEX_MODULE), "Codex's zk_proof_size.rs not mounted here")
    def test_every_key_name_appears_in_codex_module_when_mounted(self):
        with open(_CODEX_MODULE) as fh:
            src = fh.read()
        for name in set(prof.SIZES_KEYS) | set(prof.OPENING_KEYS) | set(prof.MASK_KEYS) | set(prof.COLUMN_KEYS) | set(prof.ARGUMENT_KEYS):
            self.assertIn(f'\\"{name}\\"', src, f"{name} is not a key `to_json()` writes")
        for name in prof.ARGUMENT_NAMES + (prof.PREDICATE_NAME,):
            self.assertIn(f'"{name}"', src, f"argument name {name} is not one `size_breakdown()` assigns")
        self.assertIn("3 * (32 + 8 + 4)", src, "the 132 B header constant")
        self.assertIn("salts: 0", src, "`OpeningBytes::plain` writes salts: 0 — a placeholder, not a measurement")

    def test_schema_states_owner_status_and_bytes_not_time(self):
        s = prof.schema()
        self.assertIn("Codex", s["owner_producer"])
        self.assertIn("consumes, never re-implements", s["owner_consumer"])
        self.assertIn("in validation", s["status"])
        self.assertIn("not wire offsets", s["not_contiguous"])
        self.assertIn("time", s["bytes_not_time"])

    def test_cli_schema_prints_json_and_exits_zero(self):
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            rc = prof.main(["--schema"])
        self.assertEqual(rc, 0)
        self.assertEqual(json.loads(buf.getvalue())["schema"], 1)


class CL19RowValidation(unittest.TestCase):
    """Complete rows validate and reconcile; verification status is explicit."""

    def test_complete_p1_and_p3_rows_validate_and_reconcile_for_both_fixtures(self):
        for name in prof.FIXTURES:
            fx = prof.get_fixture(name)
            for mode in ("P1", "P3"):
                row = prof.derive_row(fx, mode)
                v = prof.validate_row(row)
                self.assertTrue(v["rankable"], (name, mode))
                self.assertEqual(v["total_bytes"], fx.archived_layer_bytes[mode], (name, mode))
                self.assertEqual(v["leaf_sum_bytes"], v["total_bytes"])
                self.assertTrue(prof.reconcile(row["sizes"], prof.derive_sizes(fx, mode))["agrees"])

    def test_the_actual_layer0_row_validates_and_matches_the_mirror_on_every_leaf(self):
        row = prof.loads_strict(ACTUAL_ROW_L0_P1)
        v = prof.validate_row(row)
        self.assertEqual((v["layer"], v["privacy"], v["total_bytes"], v["rankable"]), (0, "P1", 7306036, True))
        r = prof.reconcile(row["sizes"], prof.derive_sizes(prof.get_fixture("zkv3-12x512-layer0"), "P1"))
        self.assertTrue(r["agrees"], r["disagreeing_leaves"])
        self.assertEqual(r["disagreeing_leaves"], [])
        self.assertEqual(v["category_totals"]["arguments"]["all"], 6800, "CL10's residual, now counted by the prover")
        self.assertEqual(v["category_totals"]["w_plain"], 1509376)
        self.assertEqual(v["category_totals"]["w_hiding"], 0)
        self.assertEqual(v["salt_bytes"], {"mask_opening": 8192, "w_plain": 0, "w_hiding": 0, "a": 8192, "h": 8192})

    def test_pass_verified_false_is_retained_as_a_diagnostic_and_never_rankable(self):
        v = prof.validate_row(_row(pass_verified=False))
        self.assertFalse(v["pass_verified"])
        self.assertFalse(v["rankable"])
        self.assertIn("never rankable", v["status"])
        self.assertEqual(v["total_bytes"], 7306036, "the bytes are still reported")

    def test_predicate_is_counted_separately_and_only_where_present(self):
        plain, pred = _row(), _row(pred=True)
        self.assertIsNone(plain["sizes"]["predicate"])
        self.assertEqual(prof.validate_row(plain)["category_totals"]["predicate"], 0)
        v = prof.validate_row(pred)
        p = pred["sizes"]["predicate"]
        self.assertEqual(p["name"], "predicate")
        # (log_t + log_db + 1) rounds of degree 3, two terminals, one gamma
        self.assertEqual(p["round_evaluations"], (9 + 8 + 1) * 4 * prof.FP2)
        self.assertEqual(p["terminals"], 2 * prof.FP2)
        self.assertEqual(v["category_totals"]["predicate"], 16 + 1152 + 32)
        # The predicate's OWN category is 1,200 B, but a function-2 layer costs
        # more than that: `mask_specs_v3` gains a seventh sumcheck, so the mask
        # commitment has 2*7+4 = 18 rows instead of 16 and every one of the 256
        # opened mask columns carries 2 more Fp (4,096 B in mask_opening.columns
        # .values). Derived from the source; no function-2 row has been measured.
        self.assertEqual(pred["sizes"]["mask_opening"]["columns"]["values"], 256 * 18 * prof.FP)
        self.assertEqual(pred["sizes"]["mask_opening"]["columns"]["values"] - plain["sizes"]["mask_opening"]["columns"]["values"], 4096)
        self.assertEqual(v["total_bytes"] - prof.validate_row(plain)["total_bytes"], 1200 + 4096)

    def test_nested_total_bytes_is_optional_and_checked_when_present(self):
        row = _row()
        cols = row["sizes"]["a"]["columns"]
        cols["total_bytes"] = sum(cols[k] for k in prof.COLUMN_KEYS)
        prof.validate_row(row)
        cols["total_bytes"] += 1
        with self.assertRaises(prof.BreakdownError) as cm:
            prof.validate_row(row)
        self.assertIn("disagrees with its leaves' sum", str(cm.exception))

    def test_validation_output_keeps_bytes_and_time_apart(self):
        self.assertIn("time", prof.validate_row(_row())["bytes_not_time"])


class CL19Refusals(unittest.TestCase):
    """One refusal per way a row can fail to partition its own total or
    contradict its mode. Each would let a wrong breakdown through if absent."""

    def _refused(self, row, fragment):
        with self.assertRaises(prof.BreakdownError) as cm:
            prof.validate_row(row)
        self.assertIn(fragment, str(cm.exception))

    def test_duplicate_json_key_is_refused_not_last_wins(self):
        text = ACTUAL_ROW_L0_P1.replace('"h":{', '"a":{', 1)
        self.assertEqual(text.count('"a":{'), 2)
        with self.assertRaises(prof.BreakdownError) as cm:
            prof.loads_strict(text)
        self.assertIn("duplicate key 'a'", str(cm.exception))
        self.assertEqual(json.loads(text)["sizes"].get("h"), None, "plain json.loads would silently keep the last 'a' and lose 'h'")

    def test_unknown_category_is_refused(self):
        row = _row()
        row["sizes"]["residual"] = 0
        self._refused(row, "unknown key(s) ['residual']")

    def test_omitted_category_is_refused(self):
        row = _row()
        del row["sizes"]["h"]
        self._refused(row, "missing key(s) ['h']")

    def test_duplicate_argument_is_refused(self):
        row = _row()
        row["sizes"]["arguments"][1] = dict(row["sizes"]["arguments"][0])
        self._refused(row, "duplicate argument name(s) ['gu']")

    def test_unknown_argument_name_is_refused(self):
        row = _row()
        row["sizes"]["arguments"][5]["name"] = "tab"
        self._refused(row, "unknown argument name(s) ['tab']")

    def test_omitted_argument_is_refused(self):
        row = _row()
        row["sizes"]["arguments"].pop()
        self._refused(row, "missing argument(s) ['table']")

    def test_argument_order_is_the_serializers(self):
        row = _row()
        row["sizes"]["arguments"].reverse()
        self._refused(row, "out of order")

    def test_claim_bytes_are_fixed_at_16(self):
        row = _row()
        row["sizes"]["arguments"][0]["claim_or_challenge"] = 32
        self._refused(row, "claim_or_challenge=32")

    def test_header_and_mask_root_bytes_are_fixed(self):
        row = _row()
        row["sizes"]["commitment_headers"] = 131
        self._refused(row, "exactly 132")
        row = _row()
        row["sizes"]["mask_root"] = 64
        self._refused(row, "exactly 32")

    def test_leaves_must_sum_exactly_to_total(self):
        """The tamper test at the consumer: one leaf moved by 8 B without the
        total following is refused with the exact discrepancy."""
        row = _row()
        row["sizes"]["a"]["columns"]["values"] += 8
        self._refused(row, "does not partition its own total")
        self._refused(row, "(+8 B)")
        row["sizes"]["total_bytes"] += 8
        prof.validate_row(row)

    def test_p1_row_with_hiding_w_bytes_is_refused(self):
        row = _row("P1")
        row["sizes"]["w_hiding"] = _row("P3")["sizes"]["w_hiding"]
        row["sizes"]["total_bytes"] = sum(prof.flatten_sizes(row["sizes"]).values())
        self._refused(row, "P1 row carries w_hiding bytes")

    def test_p1_row_with_plain_w_salts_is_refused(self):
        row = _row("P1")
        row["sizes"]["w_plain"]["columns"]["salts"] = 256 * prof.DIGEST
        row["sizes"]["total_bytes"] += 256 * prof.DIGEST
        self._refused(row, "a plain `Opening` writes no salt")

    def test_p1_row_with_empty_plain_w_is_refused(self):
        row = _row("P1")
        empty = _row("P3")["sizes"]["w_plain"]
        row["sizes"]["total_bytes"] -= sum(prof.flatten_sizes(row["sizes"])[p] for p in prof.flatten_sizes(row["sizes"]) if p.startswith("w_plain."))
        row["sizes"]["w_plain"] = empty
        self._refused(row, "P1 row has an empty w_plain")

    def test_p3_row_with_plain_w_bytes_is_refused(self):
        row = _row("P3")
        row["sizes"]["w_plain"] = _row("P1")["sizes"]["w_plain"]
        row["sizes"]["total_bytes"] = sum(prof.flatten_sizes(row["sizes"]).values())
        self._refused(row, "P3 row carries w_plain bytes")

    def test_p3_hiding_w_without_salts_is_refused(self):
        row = _row("P3")
        row["sizes"]["w_hiding"]["columns"]["salts"] = 0
        row["sizes"]["total_bytes"] -= 256 * prof.DIGEST
        self._refused(row, "256 opened columns x 32 B")

    def test_salt_bytes_must_be_32_per_opened_column_for_every_salted_opening(self):
        for k in ("a", "h", "mask_opening"):
            row = _row()
            row["sizes"][k]["columns"]["salts"] += 32
            row["sizes"]["total_bytes"] += 32
            self._refused(row, f"sizes.{k}.columns.salts")

    def test_column_index_bytes_must_be_whole_u64s(self):
        row = _row()
        row["sizes"]["a"]["columns"]["indices"] += 4
        row["sizes"]["total_bytes"] += 4
        self._refused(row, "not a multiple of 8")

    def test_negative_or_non_integer_leaf_is_refused(self):
        for bad in (-8, 8.0, "8", True):
            row = _row()
            row["sizes"]["h"]["group_vectors"] = bad
            self._refused(row, "non-negative integer")

    def test_unserialized_row_is_refused(self):
        row = _row()
        row["serialized"] = False
        self._refused(row, "SERIALIZED")

    def test_pass_verified_must_be_an_explicit_boolean(self):
        row = _row()
        row["pass_verified"] = "yes"
        self._refused(row, "explicit boolean")
        del row["pass_verified"]
        self._refused(row, "missing key(s) ['pass_verified']")

    def test_outer_fixed_fields_and_unknown_outer_key(self):
        for k, v in (("schema", 2), ("unit", "bits"), ("coverage", "attn"), ("profile", "v2")):
            row = _row()
            row[k] = v
            self._refused(row, f"row.{k}=")
        row = _row()
        row["privacy"] = "P2"
        self._refused(row, "row.privacy='P2'")
        row = _row()
        row["layer"] = -1
        self._refused(row, "row.layer")
        row = _row()
        row["proof_sha256"] = "00"
        self._refused(row, "unknown key(s) ['proof_sha256']")

    def test_predicate_with_another_name_is_refused(self):
        row = _row(pred=True)
        row["sizes"]["predicate"]["name"] = "pred"
        self._refused(row, "expected 'predicate'")


class CL19Mirror(unittest.TestCase):
    """The CL10 layout mirror, extended to the arguments from `mask_specs_v3`
    and the v3 verifier's terminal rules, derives EVERY category — and the
    four archived per-layer sizes reproduce with no residual at all."""

    def test_derived_totals_equal_the_archived_per_layer_sizes(self):
        for name, fx in prof.FIXTURES.items():
            for mode, want in fx.archived_layer_bytes.items():
                self.assertEqual(prof.derive_sizes(fx, mode)["total_bytes"], want, (name, mode))

    def test_cl10s_unknown_residual_is_exactly_the_derived_arguments(self):
        """CL10 could only subtract: 8,400 / 8,496 B (Mistral), 6,800 / 6,896 B
        (12x512). The arguments derived from the source equal those to the byte,
        so the residual is now a derivation — and, where rows exist, a count."""
        mx = prof.get_fixture("mistral-v3-layer")
        for mode, obs in (("P1", P1_BYTES), ("P3", P3_BYTES)):
            residual = prof.profile(prof.get_layout(f"mistral-v3-layer-{mode}"), obs)["residual_bytes"]
            args = sum(a["claim_or_challenge"] + a["round_evaluations"] + a["terminals"] for a in prof.derive_sizes(mx, mode)["arguments"])
            self.assertEqual(residual, args, mode)
        self.assertEqual(sum(a["claim_or_challenge"] + a["round_evaluations"] + a["terminals"]
                             for a in prof.derive_sizes(prof.get_fixture("zkv3-12x512-layer0"), "P1")["arguments"]), 6800)

    def test_v3_dims_follow_layout_v3_and_zk_layout_v3(self):
        m = prof.v3_dims(4096, 14336, 512, 14)
        self.assertEqual((m["log_t"], m["log_db"], m["log_fb"], m["nb_d"], m["nb_f"]), (9, 12, 11, 1, 7))
        self.assertEqual((m["log_a_min"], m["log_n"], m["log_s"], m["log_wb"], m["log_wn"]), (20, 14, 16, 23, 14))
        s = prof.v3_dims(768, 2048, 512, 14)
        self.assertEqual((s["log_db"], s["log_fb"], s["nb_d"], s["nb_f"], s["log_n"], s["log_s"], s["log_wn"]), (8, 11, 3, 1, 14, 16, 14))
        # T = 16: A/H shrink to n = 2^12 while W keeps 2^14 — the round-10 T16 dump says exactly that
        t = prof.v3_dims(768, 2048, 16, 14)
        self.assertEqual((t["log_t"], t["log_a_min"], t["log_n"], t["log_wn"]), (4, 12, 12, 14))
        with self.assertRaises(prof.ProfileError):
            prof.v3_dims(768, 2048, 500, 14)
        with self.assertRaises(prof.ProfileError):
            prof.v3_dims(8, 2048, 512, 14)

    def test_argument_shapes_from_mask_specs_and_the_verifier(self):
        s = prof.argument_sizes(prof.v3_dims(768, 2048, 512, 14), p3=False)
        self.assertEqual([a["terminals"] // prof.FP2 for a in s], [9, 4, 10, 12, 1, 12], "nb_d 3, nb_f 1")
        self.assertEqual([a["round_evaluations"] for a in s], [9 * 48, 12 * 48, 21 * 80, 18 * 80, 15 * 48, 17 * 64])
        m = prof.argument_sizes(prof.v3_dims(4096, 14336, 512, 14), p3=True)
        self.assertEqual([a["terminals"] // prof.FP2 for a in m], [15, 14, 70, 4, 1, 12], "nb_d 1, nb_f 7")
        self.assertEqual([a["round_evaluations"] for a in m][:2], [14 * 48, 13 * 48], "P3: one more round on gu and d")
        self.assertTrue(all(a["claim_or_challenge"] == 16 for a in s + m))

    def test_p3_minus_p1_by_leaf_for_both_fixtures(self):
        for name, want_values in (("mistral-v3-layer", 22 * 256 * prof.FP), ("zkv3-12x512-layer0", 10 * 256 * prof.FP)):
            fx = prof.get_fixture(name)
            p1, p3 = prof.flatten_sizes(prof.derive_sizes(fx, "P1")), prof.flatten_sizes(prof.derive_sizes(fx, "P3"))
            d = {p: p3[p] - p1[p] for p in p1 if p3[p] != p1[p]}
            w1 = {p: -p1[p] for p in p1 if p.startswith("w_plain.")}
            w3 = {p: p3[p] for p in p3 if p.startswith("w_hiding.")}
            # the W opening moves wholesale from w_plain to w_hiding (w_plain's
            # salts leaf is 0 in both modes, so it is the one W leaf with no delta) ...
            self.assertEqual({p: p3[p] - p1[p] for p in p1 if p.startswith("w_")}, {**w1, **w3})
            self.assertEqual(w1["w_plain.columns.salts"], 0)
            # ... and the NET W change is mask-row values + salts + Q pads on 3 vectors
            net_w = sum(w3.values()) + sum(w1.values())
            self.assertEqual(net_w, want_values + 256 * prof.DIGEST + 3 * 256 * prof.FP2)
            self.assertEqual(p3["w_hiding.columns.values"] - p1["w_plain.columns.values"], want_values)
            self.assertEqual(p3["w_hiding.columns.salts"], 256 * prof.DIGEST)
            self.assertEqual(p3["w_hiding.group_vectors"] - p1["w_plain.group_vectors"], 2 * 256 * prof.FP2)
            self.assertEqual(p3["w_hiding.proximity_vector"] - p1["w_plain.proximity_vector"], 256 * prof.FP2)
            self.assertEqual({p: d[p] for p in d if not p.startswith("w_")},
                             {"arguments.gu.round_evaluations": 48, "arguments.d.round_evaluations": 48})
            self.assertEqual(sum(d.values()), fx.archived_layer_bytes["P3"] - fx.archived_layer_bytes["P1"])
        self.assertEqual(prof.FIXTURES["mistral-v3-layer"].archived_layer_bytes["P3"] - prof.FIXTURES["mistral-v3-layer"].archived_layer_bytes["P1"], 65632)
        self.assertEqual(prof.FIXTURES["zkv3-12x512-layer0"].archived_layer_bytes["P3"] - prof.FIXTURES["zkv3-12x512-layer0"].archived_layer_bytes["P1"], 41056)

    def test_the_frozen_files_have_two_layer_classes_the_dump_cannot_separate(self):
        for mode, (want, sha) in (("P1", (87697008, "40eb5479")), ("P3", (88189680, "be8d13cc"))):
            f = prof.ARCHIVED_FILES["zkv3-12x512"][mode]
            self.assertEqual(sum(f["layer_bytes"].values()), want)
            self.assertEqual(f["bytes"], want)
            self.assertTrue(f["sha256"].startswith(sha))
            l0 = prof.FIXTURES["zkv3-12x512-layer0"].archived_layer_bytes[mode]
            self.assertEqual(f["layer_bytes"][0], l0)
            self.assertEqual({f["layer_bytes"][l] - l0 for l in (1, 2)}, {12288}, "6 rows x 256 columns x 8 B")
            self.assertEqual({f["layer_bytes"][l] - l0 for l in range(3, 12)}, {0})
        p1, p3 = (prof.ARCHIVED_FILES["zkv3-12x512"][m]["layer_bytes"] for m in ("P1", "P3"))
        self.assertEqual({p3[l] - p1[l] for l in range(12)}, {41056}, "the mode delta is the same on every layer")

    def test_unknown_fixture_is_refused(self):
        with self.assertRaises(prof.ProfileError):
            prof.get_fixture("mistral-v3-layer-P1")

    def test_cli_derive_reports_derived_equals_archived(self):
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            rc = prof.main(["--derive", "zkv3-12x512-layer0", "--mode", "P3"])
        self.assertEqual(rc, 0)
        out = json.loads(buf.getvalue())
        self.assertTrue(out["derived_equals_archived"])
        self.assertEqual(out["derived_row"]["sizes"]["total_bytes"], 7347092)
        self.assertIn("DERIVED", out["derived_not_measured"])


class CL19LogRows(unittest.TestCase):
    """Rows extracted from a prover log are pinned to the log's own size lines."""

    def test_synthetic_two_layer_log_validates_pins_and_sums(self):
        rows = [_row(layer=0), _row(layer=1)]
        out = prof.validate_log(_log(rows, "P1"))
        self.assertEqual((out["rows"], out["layers"], out["privacy"], out["rankable"]), (2, [0, 1], "P1", True))
        self.assertEqual(out["rows_total_bytes"], 2 * 7306036)
        self.assertEqual(out["proof_line"]["bytes"], out["rows_total_bytes"])
        self.assertEqual(out["timing_proof_bytes"], out["rows_total_bytes"])
        self.assertTrue(all(p["pinned"] for p in out["pinned_to_layer_lines"]))

    def test_reconcile_auto_declares_the_fixture_from_the_logs_own_dump(self):
        p3 = _row("P3", layer=0)
        text = _log([p3], "P3").replace("  MODE P3", (
            "      W masks (P3): commitment 298 rows of 2^14 = 288 data + 9 block masks + 1 prox row; ...\n"
            "      layout: n = 2^14 columns; table zero-check over 2^16 (the INT16 class spans 4 rows); A 559 rows = 520 data + 21 masks + 18 table/mask rows; H 485 rows = 432 data + 17 masks + 36 helper/mask rows\n"
            "      W: 9 claims in 2 groups\n      A: 26 claims in 5 groups\n      H: 14 claims in 5 groups\n  MODE P3"))
        fx = prof.fixture_from_log(text)
        self.assertEqual((fx.d, fx.f, fx.tokens, fx.a_rows, fx.h_rows, fx.w_groups, fx.a_groups, fx.h_groups), (768, 2048, 512, 559, 485, 2, 5, 5))
        self.assertEqual(fx.archived_layer_bytes, {"P3": 7347092})
        out = prof.validate_log(text, fx)
        self.assertTrue(out["reconciliation"]["per_layer"][0]["agrees"])

    def test_fixture_from_log_refuses_without_the_dump(self):
        with self.assertRaises(prof.BreakdownError) as cm:
            prof.fixture_from_log(_log([_row()], "P1"))
        self.assertIn("declared, never guessed", str(cm.exception))
        self.assertIn("`layout:", str(cm.exception))

    @unittest.skipUnless(os.path.exists(_LANE_P3_LOG) and os.path.exists(_LANE_P1_LOG), "archived cl5_r7 logs not present")
    def test_fixtures_declared_from_the_archived_lane_logs_reproduce_layer_0(self):
        """The lane's own archived 12x512 logs (no rows in them — they predate
        the CLI change) still carry the dump; a fixture declared from each
        derives layer 0's printed size exactly, W groups from the P3 dump line
        and from the function-1 claim structure under P1."""
        with open(_LANE_P3_LOG, errors="replace") as fh:
            p3 = prof.fixture_from_log(fh.read())
        with open(_LANE_P1_LOG, errors="replace") as fh:
            p1 = prof.fixture_from_log(fh.read())
        self.assertEqual(p3.archived_layer_bytes, {"P3": 7347092})
        self.assertEqual(p1.archived_layer_bytes, {"P1": 7306036})
        self.assertEqual(prof.derive_sizes(p3, "P3")["total_bytes"], 7347092)
        self.assertEqual(prof.derive_sizes(p1, "P1")["total_bytes"], 7306036)
        self.assertIn("P3 dump", p3.source)
        self.assertIn("claim structure", p1.source)

    @unittest.skipUnless(os.path.exists(_LANE_P1_LOG), "archived cl5_r7 log not present")
    def test_a_log_without_rows_is_refused_not_inferred(self):
        with open(_LANE_P1_LOG, errors="replace") as fh:
            text = fh.read()
        with self.assertRaises(prof.BreakdownError) as cm:
            prof.validate_log(text)
        self.assertIn("no HASHLINE_PROOF_SIZE rows", str(cm.exception))
        self.assertIn("PENDING actual rows", str(cm.exception))
        self.assertIn("12 `layer N: ... B` line(s)", str(cm.exception))

    def test_row_disagreeing_with_its_layer_line_is_refused(self):
        with self.assertRaises(prof.BreakdownError) as cm:
            prof.validate_log(_log([_row()], "P1", layer_bytes={0: 7306036 + 8}))
        self.assertIn("two counts of one layer disagree", str(cm.exception))

    def test_rows_not_summing_to_the_proof_line_are_refused(self):
        with self.assertRaises(prof.BreakdownError) as cm:
            prof.validate_log(_log([_row(layer=0), _row(layer=1)], "P1", proof_bytes=87697008))
        self.assertIn("do not partition the file", str(cm.exception))

    def test_duplicate_and_missing_layer_rows_are_refused(self):
        with self.assertRaises(prof.BreakdownError) as cm:
            prof.validate_log(_log([_row(layer=0), _row(layer=0)], "P1"))
        self.assertIn("more than one row", str(cm.exception))
        text = _log([_row(layer=0), _row(layer=1)], "P1")
        text = "\n".join(l for l in text.splitlines() if not (l.startswith("HASHLINE_PROOF_SIZE") and '"layer":1' in l))
        text = text.replace(f"({2 * 7306036} B)", f"({7306036} B)").replace(f'"proof_bytes": {2 * 7306036}', f'"proof_bytes": {7306036}')
        with self.assertRaises(prof.BreakdownError) as cm:
            prof.validate_log(text)
        self.assertIn("rows missing for layer(s) [1]", str(cm.exception))

    def test_mixed_privacy_and_timing_disagreement_are_refused(self):
        with self.assertRaises(prof.BreakdownError) as cm:
            prof.validate_log(_log([_row("P1", layer=0), _row("P3", layer=1)], "P1"))
        self.assertIn("disagree on privacy", str(cm.exception))
        text = _log([_row("P1")], "P1").replace('"privacy": "P1"', '"privacy": "P3"')
        with self.assertRaises(prof.BreakdownError) as cm:
            prof.validate_log(text)
        self.assertIn("HASHLINE_TIMING says 'P3'", str(cm.exception))

    def test_cli_from_log_and_validate_breakdown_round_trip(self):
        with tempfile.TemporaryDirectory() as tmp:
            log = os.path.join(tmp, "run.log")
            with open(log, "w") as fh:
                fh.write(_log([_row(layer=0), _row(layer=1)], "P1"))
            buf = io.StringIO()
            with contextlib.redirect_stdout(buf):
                rc = prof.main(["--from-log", log, "--reconcile", "zkv3-12x512-layer0"])
            self.assertEqual(rc, 0)
            out = json.loads(buf.getvalue())
            self.assertEqual(out["rows"], 2)
            self.assertTrue(all(r["agrees"] for r in out["reconciliation"]["per_layer"]))
            one = os.path.join(tmp, "row.json")
            with open(one, "w") as fh:
                fh.write(ACTUAL_ROW_L0_P1)
            buf = io.StringIO()
            with contextlib.redirect_stdout(buf):
                rc = prof.main(["--validate-breakdown", one, "--reconcile", "zkv3-12x512-layer0"])
            self.assertEqual(rc, 0)
            out = json.loads(buf.getvalue())
            self.assertTrue(out["rows"][0]["rankable"])
            self.assertTrue(out["reconciliation"][0]["agrees"])
            bad = os.path.join(tmp, "norows.log")
            with open(bad, "w") as fh:
                fh.write("PASS-V3 ACCEPT\n")
            buf = io.StringIO()
            with contextlib.redirect_stdout(buf):
                rc = prof.main(["--from-log", bad])
            self.assertEqual(rc, 2, "a refusal is exit 2 with a `refused` object, never a breakdown")
            self.assertIn("no HASHLINE_PROOF_SIZE rows", json.loads(buf.getvalue())["refused"])

    @unittest.skipUnless(os.path.exists(os.path.join(_ROUND10_DIR, "frozen_zkv3.log")), "Codex's round-10 validation logs not mounted here")
    def test_actual_round10_frozen_run_when_mounted(self):
        """Codex's actual frozen 12x512 P1 run (uncommitted evidence): all 12
        rows validate, pin to the 12 `layer N` lines, sum to the frozen
        87,697,008 B PROOF line; layer 0 and 3-11 agree with the mirror on
        every leaf; layers 1-2 differ on exactly two leaves — the 12,288 B
        the layer-0 dump could never attribute is 2 more A rows and 4 more
        H rows of opened column values, measured."""
        with open(os.path.join(_ROUND10_DIR, "frozen_zkv3.log"), errors="replace") as fh:
            text = fh.read()
        out = prof.validate_log(text, prof.fixture_from_log(text))
        self.assertEqual((out["rows"], out["privacy"], out["rankable"], out["rows_total_bytes"]), (12, "P1", True, 87697008))
        self.assertTrue(out["proof_line"]["sha256"].startswith("40eb54795e023c77"))
        self.assertTrue(all(p["pinned"] for p in out["pinned_to_layer_lines"]))
        per = {r["layer"]: r for r in out["reconciliation"]["per_layer"]}
        for l in (0, 3, 4, 5, 6, 7, 8, 9, 10, 11):
            self.assertTrue(per[l]["agrees"], l)
        for l in (1, 2):
            self.assertFalse(per[l]["agrees"])
            self.assertEqual({x["path"]: x["delta_measured_minus_derived"] for x in per[l]["disagreeing_leaves"]},
                             {"a.columns.values": 2 * 256 * prof.FP, "h.columns.values": 4 * 256 * prof.FP})
        self.assertEqual({v["total_bytes"] for v in out["per_layer"]}, {7306036, 7318324})

    @unittest.skipUnless(os.path.exists(os.path.join(_ROUND10_DIR, "p3_profile.log")), "Codex's round-10 validation logs not mounted here")
    def test_actual_round10_t16_rows_when_mounted(self):
        with open(os.path.join(_ROUND10_DIR, "p3_profile.log"), errors="replace") as fh:
            p3 = fh.read()
        out = prof.validate_log(p3, prof.fixture_from_log(p3))
        self.assertEqual((out["rows"], out["privacy"], out["rankable"], out["rows_total_bytes"]), (1, "P3", True, 3432468))
        self.assertTrue(out["reconciliation"]["per_layer"][0]["agrees"], "A/H at n = 2^12, W at 2^14: the separated log_n/log_wn rule")
        self.assertEqual(out["per_layer"][0]["category_totals"]["w_plain"], 0)
        self.assertEqual(out["per_layer"][0]["salt_bytes"]["w_hiding"], 8192)
        with open(os.path.join(_ROUND10_DIR, "p1_unverified.log"), errors="replace") as fh:
            p1 = fh.read()
        out = prof.validate_log(p1, prof.fixture_from_log(p1))
        self.assertEqual((out["rows"], out["privacy"], out["rankable"], out["rows_total_bytes"]), (1, "P1", False, 3391412))
        self.assertIn("never rankable", out["per_layer"][0]["status"])
        self.assertTrue(out["reconciliation"]["per_layer"][0]["agrees"])
        with open(os.path.join(_ROUND10_DIR, "p3_default.log"), errors="replace") as fh:
            with self.assertRaises(prof.BreakdownError):
                prof.validate_log(fh.read())

    @unittest.skipUnless(os.path.exists(_VALIDATION_JSON), "Codex's validation record not mounted here")
    def test_actual_validation_record_rows_when_mounted(self):
        with open(_VALIDATION_JSON) as fh:
            rec = json.load(fh)
        rows = rec["frozen_size_rows"]
        self.assertEqual(len(rows), 12)
        self.assertEqual(json.dumps(rows[0], separators=(",", ":")), ACTUAL_ROW_L0_P1, "the pinned row is the record's layer 0")
        totals = {r["layer"]: prof.validate_row(r)["total_bytes"] for r in rows}
        self.assertEqual(totals, prof.ARCHIVED_FILES["zkv3-12x512"]["P1"]["layer_bytes"])
        self.assertEqual(sum(totals.values()), 87697008)


if __name__ == "__main__":
    unittest.main()
