"""Tests for round 4: the REPAIRED bilinear attention slots (finding
S19-F1) and the first NON-DEGENERATE witness this gate has read.

Run:
  python3 -m unittest discover -s tests \
      -p "test_zk60_native_run_gate_s20.py"

THREE ARMS, as rounds 2 and 3 used.

* A PURE arm that needs no bundle: the geometry `lkv = clog2(kv_heads)`,
  each bilinear slot's derived `(main, extension, degree)` and definition
  draws under BOTH definitions, both private factors' coordinate
  schedules written out, and the one property the repair had to keep --
  at `kv_heads == 1` the two definitions are the SAME schedule, the same
  dimensions and no public table, which is why the frozen toy did not
  move a byte.
* The RECORDED arm, which always runs: every figure the report quotes,
  asserted from the tracked evidence under
  `results/zk60_native_run_gate_s20/`, including that the evidence was
  produced by the tool bytes now in the tree, the dense-against-zero
  comparison, and the six older bundles' diffs.
* The LIVE arm, skipped when the ~41 MB bundles are absent: the group
  point derived from the transcript and compared, the two directions of
  that comparison perturbed in memory, the other definition forced, an
  unknown `argument.rs` digest, and the pre-repair polynomial measured on
  a repaired bundle's own terminals.

Nothing here asserts a privacy property.  A capture carries no witness,
so no test here can say what was proved -- only that the verifier's view
is self-consistent at the run's real challenges under the definition the
bundle's own source pin names.
"""

from __future__ import annotations

import copy
import json
import os
import sys
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "scripts"))

EVIDENCE = os.path.join(ROOT, "results", "zk60_native_run_gate_s20")
BUNDLES = os.environ.get(
    "ZK60_RUN_BUNDLES",
    "/home/victor/wt-zk60-block125m/results/zk60_run_captures_20260920",
)
RUN_G = os.path.join(BUNDLES, "run-g-dense-s20")
RUN_H = os.path.join(BUNDLES, "run-h-zero-s20")
RUN_E = os.path.join(BUNDLES, "run-e-tame-tagged")
HAVE_S20 = os.path.isdir(RUN_G) and os.path.isdir(RUN_H)
HAVE_E = os.path.isdir(RUN_E)

import zk60_native_run_gate as gate  # noqa: E402
from zk60_native_rg_bundle import RunBundle  # noqa: E402
from zk60_native_rg_gcontrols import (  # noqa: E402
    group_controls,
    pre_repair_polynomial_on_this_bundle,
)
from zk60_native_rg_gqa import (  # noqa: E402
    ARGUMENT_DEFINITIONS,
    BILINEAR_SLOTS,
    FACTORS,
    PRE_REPAIR,
    REPAIRED,
    GroupFactors,
    Geometry,
    clog2,
    definition_of_pin,
    lg,
)
from zk60_native_rg_planes import plane_index_of  # noqa: E402
from zk60_native_rg_replay import RunReplay  # noqa: E402
from zk60_native_rg_terminals import check_terminals  # noqa: E402

# the development rung's shape, written out so the pure arm needs no file
RUNG_G_SHAPE = {"tokens": 24, "width": 96, "hidden": 192, "q_heads": 6,
                "kv_heads": 2, "head_dim": 16, "t_pad": 32, "d_pad": 128,
                "h_pad": 8, "f_pad": 256}
# the frozen toy: ONE key-value head
TOY_SHAPE = dict(RUNG_G_SHAPE, q_heads=2, kv_heads=1, h_pad=2)

_STATE = {}


def loaded(which=RUN_G):
    if which not in _STATE:
        b = RunBundle(which)
        rp = RunReplay(b).run()
        index, _why = plane_index_of(b)
        _STATE[which] = (b, index, rp)
    return _STATE[which]


# =====================================================================
#  the pure arm
# =====================================================================
class TestTheGeometry(unittest.TestCase):
    def test_clog2_and_lg(self):
        self.assertEqual([clog2(n) for n in (1, 2, 3, 4, 5, 8)],
                         [0, 1, 2, 2, 3, 3])
        self.assertEqual([lg(n) for n in (1, 2, 8, 32)], [0, 1, 3, 5])
        with self.assertRaises(ValueError):
            lg(6)

    def test_the_rung_geometry_is_read_from_the_shape(self):
        g = Geometry(RUNG_G_SHAPE)
        self.assertEqual((g.lt, g.lh, g.ldh, g.lkv), (5, 3, 4, 1))

    def test_the_derived_dimensions_of_both_definitions(self):
        g = Geometry(RUNG_G_SHAPE)
        # the repair adds lkv main rounds and one degree, and nothing else
        self.assertEqual(g.dims(8, PRE_REPAIR), (4, 2, 2))
        self.assertEqual(g.dims(8, REPAIRED), (5, 2, 3))
        self.assertEqual(g.dims(9, PRE_REPAIR), (5, 2, 2))
        self.assertEqual(g.dims(9, REPAIRED), (6, 2, 3))
        # the definition DRAWS are the same either way: r_h, r_t, r_j / r_i
        self.assertEqual(g.n_definition_challenges(8), 13)
        self.assertEqual(g.n_definition_challenges(9), 12)

    def test_one_key_value_head_reduces_the_repair_to_the_old_path(self):
        """The property the repair had to keep: at `kv_heads == 1` there is
        no variable, no public table and no degree, so the frozen toy's
        schedule is byte-identical under both definitions."""
        g = Geometry(TOY_SHAPE)
        self.assertEqual(g.lkv, 0)
        self.assertFalse(g.has_group_table(REPAIRED))
        self.assertFalse(g.has_group_table(PRE_REPAIR))
        for slot in BILINEAR_SLOTS:
            self.assertEqual(g.dims(slot, REPAIRED), g.dims(slot, PRE_REPAIR))
            self.assertEqual(g.coordinate_schedule(slot, REPAIRED),
                             g.coordinate_schedule(slot, PRE_REPAIR))

    def test_the_repaired_coordinate_schedule_written_out(self):
        """`SC_SCORE`: A_QR8 at fixed(r_t) | rho(0..lkv) | fixed(r_hj) |
        rho(lkv..lkv+ldh); A_KR8 at fixed(r_j) | rho(0..lkv) |
        rho(lkv..lkv+ldh).  With lh = 3 and lkv = 1, r_h is dc[0:3],
        r_t is dc[3:8] and r_j is dc[8:13]."""
        g = Geometry(RUNG_G_SHAPE)
        qr, kr = g.coordinate_schedule(8, REPAIRED)
        self.assertEqual(qr, [("dc", 3), ("dc", 4), ("dc", 5), ("dc", 6),
                              ("dc", 7), ("rho", 0), ("dc", 1), ("dc", 2),
                              ("rho", 1), ("rho", 2), ("rho", 3), ("rho", 4)])
        self.assertEqual(kr, [("dc", 8), ("dc", 9), ("dc", 10), ("dc", 11),
                              ("dc", 12), ("rho", 0),
                              ("rho", 1), ("rho", 2), ("rho", 3), ("rho", 4)])
        pp, vv = g.coordinate_schedule(9, REPAIRED)
        self.assertEqual(pp, [("rho", 0), ("dc", 1), ("dc", 2), ("dc", 3),
                              ("dc", 4), ("dc", 5), ("dc", 6), ("dc", 7),
                              ("rho", 1), ("rho", 2), ("rho", 3), ("rho", 4),
                              ("rho", 5)])
        self.assertEqual(vv, [("rho", 1), ("rho", 2), ("rho", 3), ("rho", 4),
                              ("rho", 5), ("rho", 0),
                              ("dc", 8), ("dc", 9), ("dc", 10), ("dc", 11)])

    def test_the_group_is_a_summed_variable_of_BOTH_factors_only_after_the_repair(self):
        """The whole finding, as a property of the two schedules: before the
        repair the group bits appear as FIXED coordinates in both factors;
        after it they appear as the SAME summed rho in both."""
        g = Geometry(RUNG_G_SHAPE)
        for slot in BILINEAR_SLOTS:
            old_a, old_b = g.coordinate_schedule(slot, PRE_REPAIR)
            new_a, new_b = g.coordinate_schedule(slot, REPAIRED)
            # r_g is dc[0:lkv] = dc0
            self.assertIn(("dc", 0), old_a + old_b,
                          f"slot {slot}: the group bit is not fixed before the repair")
            self.assertNotIn(("dc", 0), new_a,
                             f"slot {slot}: the group bit is still fixed after it")
            self.assertNotIn(("dc", 0), new_b)
            self.assertIn(("rho", 0), new_a)
            self.assertIn(("rho", 0), new_b)

    def test_both_argument_digests_are_definitions_this_port_has_read(self):
        self.assertEqual(len(ARGUMENT_DEFINITIONS), 2)
        names = sorted(v[0] for v in ARGUMENT_DEFINITIONS.values())
        self.assertEqual(names, [PRE_REPAIR, REPAIRED])
        self.assertEqual(definition_of_pin("0" * 64), (None, None))

    def test_the_factor_names_are_the_push_order(self):
        self.assertEqual(FACTORS[8], ("A_QR8", "A_KR8"))
        self.assertEqual(FACTORS[9], ("A_P", "A_V8"))


# =====================================================================
#  the recorded arm
# =====================================================================
class TestRecordedEvidence(unittest.TestCase):
    def records(self):
        out = {}
        for name in ("run-g-dense-s20", "run-h-zero-s20"):
            path = os.path.join(EVIDENCE, f"{name}.json")
            self.assertTrue(os.path.exists(path), f"{path} is missing")
            with open(path) as fh:
                out[name] = json.load(fh)
        return out

    def test_the_evidence_was_produced_by_the_tools_now_in_the_tree(self):
        want = gate.tool_hashes()
        for name, rec in self.records().items():
            self.assertEqual(
                rec["tool_sha256"], want,
                f"{name}: the record was produced by different tool bytes; "
                "re-run the gate and refresh the evidence",
            )

    def test_both_records_pass_and_claim_no_privacy_property(self):
        for name, rec in self.records().items():
            self.assertTrue(rec["ok"], name)
            self.assertFalse(rec["privacy_property_established"], name)
            self.assertFalse(rec["privacy_acceptance"], name)
            self.assertFalse(rec["privacy_review_complete"], name)
            for k in [k for k in rec if k.startswith("stage")]:
                self.assertTrue(rec[k]["ok"], f"{name}: {k} is not ok")

    def test_the_replay_under_the_repaired_schedule(self):
        """Six more challenges than round 3 -- `lkv` per bilinear slot per
        stage, 1 * 2 * 3 -- and nothing else moved."""
        for name, rec in self.records().items():
            r = rec["stage2_transcript_replay"]
            self.assertTrue(r["run_binding_reproduced"], name)
            self.assertEqual(r["positions_checked"], 375, name)
            self.assertEqual(r["challenges_checked"], 6092, name)
            self.assertEqual(r["final_counter"], 6924, name)
            self.assertEqual(r["not_rederived"], [], name)
            self.assertEqual(r["failures"], [], name)
            self.assertEqual(len(r["segment_position_tags"]), 3, name)
            self.assertTrue(all(t["start_tag_ok"] and t["end_tag_ok"]
                                for t in r["segment_position_tags"]), name)

    def test_the_twenty_three_slot_terminal_identity(self):
        for name, rec in self.records().items():
            t = rec["stage8_plane_index_and_terminals"]["terminal_identity"]
            self.assertEqual(len(t["covered_slots"]), 23, name)
            self.assertEqual(t["slot_checks_expected"], 69, name)
            self.assertEqual(t["slot_checks_equal"], 69, name)
            self.assertEqual(
                t["slot_checks_matching_the_stored_terminal_polynomial"], 69, name)
            self.assertEqual(t["open_slots"], [], name)
            self.assertEqual(t["findings"], [], name)
            self.assertEqual(t["derived_group_points_used_and_compared"], 6, name)
            self.assertEqual(
                t["source_pins"]["bilinear_definition_selected_by_the_argument_pin"],
                REPAIRED, name)

    def test_the_group_factor_is_derived_and_compared(self):
        for name, rec in self.records().items():
            gf = rec["stage10_bilinear_group_factor"]["group_factor"]
            self.assertTrue(gf["ok"], name)
            self.assertEqual(gf["definition_in_force"], REPAIRED, name)
            self.assertFalse(gf["superseded"], name)
            self.assertEqual(gf["geometry"]["lkv = clog2(kv_heads)"], 1, name)
            c = gf["counts"]
            self.assertEqual(c["slots_examined"], 6, name)
            self.assertEqual(c["dimension_sets_derived_and_compared"], 6, name)
            self.assertEqual(c["group_points_derived_and_compared"], 6, name)
            self.assertEqual(c["group_point_entries_compared"], 6, name)
            self.assertEqual(c["coordinate_lists_rederived_and_compared"], 12, name)
            self.assertEqual(c["coordinate_entries_compared"], 135, name)
            self.assertEqual(
                c["fixed_coordinates_compared_with_a_rederived_challenge"], 69, name)
            self.assertEqual(gf["slots_with_a_derived_group_point"], 6, name)
            self.assertIn("transcript replay", gf["group_point_derived_from"])

    def test_round_fours_six_controls_all_fire(self):
        # [ROUND 5, 2026-09-20] Round 4's six became NINE at this shape and
        # the assertion is updated deliberately, not relaxed.  `GQ-3` and
        # `GQ-4` are now FAMILIES, one member per bilinear slot per group
        # coordinate: at `lkv = 1` that is `GQ-3.08.0` and `GQ-3.09.0`
        # (round 4 ran only the slot-08 one, and one slot passing was never
        # evidence for the other).  `GQ-7` -- the declared point's group
        # coordinates SWAPPED -- does not exist at one group bit and is
        # NAMED AND SKIPPED, which is why `controls_total` is 9 while
        # `controls_live` and `controls_that_fire` are 8.  Round 4's own
        # figures are all still asserted below.
        for name, rec in self.records().items():
            c = rec["stage10_bilinear_group_factor"]["controls"]
            self.assertTrue(c["ok"], name)
            self.assertEqual(c["controls_total"], 9, name)
            self.assertEqual(c["controls_live"], 8, name)
            self.assertEqual(c["controls_that_fire"], 8, name)
            self.assertEqual(c["controls_skipped"], ["GQ-7"], name)
            got = {x["control"]: x for x in c["controls"]}
            self.assertEqual(
                sorted(got),
                ["GQ-1", "GQ-2", "GQ-3.08.0", "GQ-3.09.0",
                 "GQ-4.08.0", "GQ-4.09.0", "GQ-5", "GQ-6", "GQ-7"], name)
            self.assertIn("lkv = 1", got["GQ-7"]["skipped"], name)
            self.assertTrue(got["GQ-1"]["fails_at_exactly_the_perturbed_slot"])
            self.assertTrue(got["GQ-2"]["fails_at_exactly_the_perturbed_slot"])
            for slot in ("08", "09"):
                self.assertIn("not r_g", got[f"GQ-3.{slot}.0"]["refusal"])
                self.assertTrue(
                    got[f"GQ-4.{slot}.0"]["the_slot_is_not_evaluated"])
            self.assertTrue(got["GQ-5"]["both_slots_refused_in_every_stage"])
            self.assertTrue(got["GQ-5"]["the_other_21_slots_are_unaffected"])

    def test_the_pre_repair_polynomial_fails_on_both_repaired_bundles(self):
        """And it fails on the DENSE one exactly as it fails on the zero
        one -- the gate cannot see the defect, and the record says so."""
        for name, rec in self.records().items():
            m = rec["stage10_bilinear_group_factor"]["controls"][
                "pre_repair_polynomial_measured"]
            self.assertEqual(m["slot_instances"], 6, name)
            self.assertEqual(m["the_repaired_definition_holds"], 6, name)
            self.assertEqual(m["the_pre_repair_definition_holds"], 0, name)
            self.assertEqual(m["group_factors_equal_to_one"], 0, name)
            self.assertEqual(m["terminal_products_that_are_zero"], 0, name)
            # and the record says, in its own words, that it cannot see the
            # defect and cannot tell the two witnesses apart
            said = [x for x in rec["what_it_does_not_show"]
                    if "CANNOT TELL A DENSE WITNESS" in x]
            self.assertEqual(len(said), 1, name)
            self.assertIn("cannot reproduce finding S19-F1", said[0], name)

    def test_the_round_one_to_three_figures_are_re_established(self):
        for name, rec in self.records().items():
            s3 = rec["stage3_per_commitment"]
            self.assertTrue(s3["ok"], name)
            for row in s3["per_commitment"]:
                self.assertTrue(row["meets_expectation"],
                                f"{name}: {row['stage']}:{row['site_role']}")
                self.assertTrue(row["distinct_opened_columns_within_pad_count"])
            self.assertEqual(len(s3["per_commitment"]), 10, name)
            for m in s3["masking_commitments"]:
                self.assertEqual(m["disclosed_dimension"], 0, name)
            pad = s3["pad_block_exact_rank_cross_check"]
            self.assertTrue(pad["full_rank"], name)
            s4 = rec["stage4_the_boundary"]
            self.assertTrue(s4["ok"], name)
            self.assertEqual(len(s4["per_boundary"]), 2, name)
            for b in s4["per_boundary"]:
                self.assertEqual(
                    b["restricted_to_the_reserved_rows"][
                        "disclosed_on_the_reserved_block_fp"], 0, name)
                th = b["three_roles_of_the_plane"]
                self.assertEqual(th["joint_fp"], th["sum_of_parts_fp"], name)
                self.assertIn("ruling R-3", th["ruling_R3"], name)
            w = s4["whole_run"]
            self.assertEqual(w["matrix"], "308 x 3761", name)
            self.assertEqual(w["joint_fp"], 6, name)
            self.assertEqual(w["sum_of_parts_fp"], 6, name)
            self.assertIn("ruling R-3", w["ruling_R3"], name)
            self.assertIn("ruling R-3", s4["ruling_R3"], name)

    def test_the_hash_layer_and_the_round_three_controls_still_fire(self):
        for name, rec in self.records().items():
            s9 = rec["stage9_hash_layer"]
            self.assertTrue(s9["ok"], name)
            self.assertEqual(s9["openings"], 13, name)
            self.assertEqual(s9["columns_checked"], s9["columns_authenticated"])
            self.assertTrue(s9["controls"]["ok"], name)
            ct = rec["stage8_plane_index_and_terminals"]["controls"]
            self.assertTrue(ct["ok"], name)
            self.assertEqual(sum(1 for c in ct["controls"] if c["fires"]),
                             len(ct["controls"]), name)
            s6 = rec["stage6_negative_controls"]
            self.assertTrue(s6["all_fire"], name)

    def test_the_channel_table_recounted_from_the_tools_own_array(self):
        for name, rec in self.records().items():
            ch = rec["stage7_channels"]
            # [ROUND 8] the array gained M's three own channels, all OPEN
            # with both arms off, so 25 -> 28 and 14 -> 17 open.  No figure
            # moved: three entries were ADDED.
            self.assertEqual(ch["total"], 28, name)
            self.assertEqual(ch["counts"]["open"], 17, name)
            self.assertEqual(ch["counts"]["derived"], 5, name)
            self.assertEqual(ch["counts"]["constructed"], 2, name)
            self.assertEqual(ch["counts"]["argued"], 4, name)
            self.assertEqual(len(ch["channels"]), ch["total"], name)
            joint = [c for c in ch["channels"]
                     if c["channel"].startswith("the cross-block joint law")]
            self.assertEqual(len(joint), 1, name)
            self.assertIn("ruling R-3", joint[0]["reason"], name)

    def test_the_dense_and_the_zero_witness_are_compared_figure_by_figure(self):
        path = os.path.join(EVIDENCE, "witness_comparison_dense_vs_zero.json")
        self.assertTrue(os.path.exists(path), f"{path} is missing")
        with open(path) as fh:
            c = json.load(fh)
        self.assertEqual(c["labels"], ["run-g-dense-s20", "run-h-zero-s20"])
        self.assertGreater(c["figures_compared"], 150)
        # EVERY figure that differs is a count of DISTINCT sampled columns
        # (or the pad margin, which is 256 minus it, or the pad block's rank,
        # which is the number of distinct columns).  The columns are sampled
        # from the transcript, so they move with the randomness and not with
        # the witness.  Not one rank, disclosed dimension, joint figure,
        # challenge count, slot check or control figure differs.
        for d in c["figures_that_differ"]:
            self.assertTrue(
                d["figure"].startswith("distinct opened columns/")
                or d["figure"].startswith("pad margin/")
                or d["figure"].startswith("pad block/"),
                f"a figure moved between the dense and the zero witness: {d}",
            )

    def test_the_six_older_bundles_are_unchanged_where_it_matters(self):
        path = os.path.join(EVIDENCE, "old", "old_bundles_unchanged.json")
        self.assertTrue(os.path.exists(path), f"{path} is missing")
        with open(path) as fh:
            s = json.load(fh)
        self.assertEqual(s["unclassified"], [])
        self.assertTrue(s["no_measured_figure_moved"])
        self.assertEqual(len(s["per_bundle"]), 6)
        for row in s["per_bundle"]:
            self.assertGreater(row["identical_leaves"], 2000, row["bundle"])

    def test_the_four_pre_repair_bundles_are_recorded_as_superseded(self):
        """a-f are IN scope and replayed under the definition that made
        their bytes, marked SUPERSEDED for the two slots -- the treatment
        round 3 gave a pre-tag hash rule."""
        for d, names in (
            ("zk60_native_run_gate", ("run-a-tame", "run-b-zero")),
            ("zk60_native_run_gate_planeindex", ("run-c-tame", "run-d-zero")),
            ("zk60_native_run_gate_tagged",
             ("run-e-tame-tagged", "run-f-zero-tagged")),
        ):
            for n in names:
                path = os.path.join(ROOT, "results", d, f"{n}.json")
                self.assertTrue(os.path.exists(path), f"{path} is missing")
                with open(path) as fh:
                    rec = json.load(fh)
                self.assertTrue(rec["ok"], n)
                gf = rec["stage10_bilinear_group_factor"]["group_factor"]
                self.assertEqual(gf["definition_in_force"], PRE_REPAIR, n)
                self.assertTrue(gf["superseded"], n)
                self.assertTrue(gf["ok"], n)
                self.assertIn("SUPERSEDED", gf["superseded_note"], n)
                self.assertIn("source pin", gf["definition_selected_by"], n)


# =====================================================================
#  the live arm
# =====================================================================
@unittest.skipUnless(HAVE_S20, "the stage-20 run bundles are not on this box")
class TestLive(unittest.TestCase):
    def test_the_group_point_is_the_transcripts_and_the_bundle_only_agrees(self):
        b, _i, rp = loaded()
        g = GroupFactors(b, replay=rp)
        s = g.summary()
        self.assertTrue(s["ok"], s["failures"])
        for st in range(b.blocks):
            for slot in BILINEAR_SLOTS:
                pt = g.point(st, slot)
                self.assertIsNotNone(pt, (st, slot))
                # it IS the leading lkv re-derived definition challenges
                self.assertEqual(pt, rp.stages[st]["def_challenges"][slot][:1])

    def test_a_declared_group_point_that_differs_is_refused_by_name(self):
        b, index, rp = loaded()
        docs = [copy.deepcopy(st.doc) if st.index == 0 else st.doc
                for st in b.stages]
        tab = docs[0]["arguments"][8]["tables"][0]
        self.assertEqual(tab["kind"], "eq")
        tab["point"][0][0] = (tab["point"][0][0] + 1) % (2 ** 64 - 2 ** 32 + 1)
        g = GroupFactors(b, replay=rp, stage_docs=docs)
        s = g.summary()
        self.assertFalse(s["ok"])
        self.assertTrue(any("not r_g" in f for f in s["failures"]), s["failures"])
        self.assertIsNone(g.point(0, 8))
        got = check_terminals(b, index, replay=rp, stage_docs=docs, group=g)
        self.assertFalse(got["ok"])
        why = [e["why"] for r in got["per_stage"] for e in r["not_checked"]
               if e["slot"] == 8]
        self.assertTrue(any("no group point was DERIVED" in w for w in why), why)
        # and the bundle's own dictionaries were never touched
        self.assertNotEqual(b.stages[0].doc["arguments"][8]["tables"][0]["point"],
                            tab["point"])

    def test_a_derived_group_point_that_differs_is_refused_too(self):
        """The comparison is two-sided: this tool is not the authority
        either."""
        b, index, rp = loaded()
        g = GroupFactors(b, replay=rp, perturb_derived_point=(1, 9))
        s = g.summary()
        self.assertFalse(s["ok"])
        self.assertEqual(s["slots_with_a_derived_group_point"], 5)
        got = check_terminals(b, index, replay=rp, group=g)
        self.assertFalse(got["ok"])
        failed = [(r["stage"], e["slot"]) for r in got["per_stage"]
                  for e in r["not_checked"] if e["slot"] in BILINEAR_SLOTS]
        self.assertEqual(failed, [(1, 9)])

    def test_the_pre_repair_definition_forced_is_refused_at_both_slots(self):
        b, index, rp = loaded()
        g = GroupFactors(b, replay=rp, definition=PRE_REPAIR)
        s = g.summary()
        self.assertFalse(s["ok"])
        self.assertTrue(any("is not the (4, 2, 2)" in f for f in s["failures"]))
        self.assertTrue(any("no public group table" in f for f in s["failures"]))
        got = check_terminals(b, index, replay=rp, group=g)
        # the two bilinear slots are refused in all three stages; the other
        # twenty-one are unaffected
        self.assertEqual(got["slot_checks_equal"], 69 - 6)
        refused = sorted((r["stage"], e["slot"]) for r in got["per_stage"]
                         for e in r["not_checked"])
        self.assertEqual(refused, [(s_, sl) for s_ in range(3)
                                   for sl in BILINEAR_SLOTS])

    @unittest.skipUnless(HAVE_E, "run-e-tame-tagged is not on this box")
    def test_the_repaired_definition_forced_on_a_pre_repair_bundle_is_refused(self):
        b, index, rp = loaded(RUN_E)
        g = GroupFactors(b, replay=rp, definition=REPAIRED)
        s = g.summary()
        self.assertFalse(s["ok"])
        got = check_terminals(b, index, replay=rp, group=g)
        self.assertEqual(got["slot_checks_equal"], 69 - 6)
        why = [e["why"] for r in got["per_stage"] for e in r["not_checked"]]
        self.assertTrue(any("exactly one public group table" in w for w in why), why)

    def test_an_unknown_argument_digest_makes_every_slot_not_checked(self):
        b, index, rp = loaded()
        keep = b.manifest["source_pins"]
        moved = copy.deepcopy(keep)
        for p in moved:
            if p["file"].endswith("argument.rs"):
                p["sha256"] = "0" * 64
        b.manifest["source_pins"] = moved
        try:
            got = check_terminals(b, index, replay=rp)
            g = GroupFactors(b, replay=rp)
        finally:
            b.manifest["source_pins"] = keep
        self.assertFalse(got["ok"])
        self.assertEqual(got["slot_checks_attempted"], 0)
        self.assertTrue(any("source pins" in f for f in got["findings"]))
        self.assertFalse(g.summary()["ok"])
        self.assertTrue(any("never read" in r for r in g.summary()["refusals"]))

    def test_the_pre_repair_polynomial_on_the_dense_and_the_zero_bundle(self):
        """The same answer on both, which is the honest limit: a capture
        carries no witness, so a gate cannot see the defect."""
        for which in (RUN_G, RUN_H):
            b, index, rp = loaded(which)
            g = GroupFactors(b, replay=rp)
            m = pre_repair_polynomial_on_this_bundle(b, index, rp, g)
            self.assertEqual(m["the_repaired_definition_holds"], 6, which)
            self.assertEqual(m["the_pre_repair_definition_holds"], 0, which)
            self.assertEqual(m["group_factors_equal_to_one"], 0, which)

    def test_the_controls_run_live_on_both_bundles(self):
        for which in (RUN_G, RUN_H):
            b, index, rp = loaded(which)
            c = group_controls(b, index, replay=rp)
            self.assertTrue(c["ok"], (which, c.get("controls")))
            # [round 5] eight live at one group bit; GQ-7 is skipped by name
            self.assertEqual(c["controls_that_fire"], 8, which)
            self.assertEqual(c["controls_skipped"], ["GQ-7"], which)


if __name__ == "__main__":
    unittest.main()
