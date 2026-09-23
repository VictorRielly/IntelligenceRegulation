"""Tests for round 9b: `rung-P2`, the development shape that takes BOTH
arms of the pad rule, and finding M-F1's regression.

Run:
  python3 -m unittest discover -s tests \
      -p "test_zk60_native_run_gate_p2.py"

WHY THERE IS A ROUND 9b.  Round 9's finding M-F1 was a hardcoded
`n_pad = 1` in every zero-check port: a slot whose hosted domain is an
exact power of two draws two definition challenges FEWER -- no extra `mu`
and no `zeta` -- and at the toy and at both development rungs every domain
pads, so the hardcoded 1 was right everywhere the gate had ever run.  It
took a 281 MB bundle and a three-minute pass at the 125M shape to find,
and its control M9-3 existed only there.  `rung-P2` (lane stage 30, commit
`4ccbad1`) is 125M's own padded-domain set at a development size: 32
tokens / width 96 / hidden 256, 12 query heads of 8 over 4 key-value
heads, with `Dom::T` (2^5), `Dom::Kv` (2^10) and `Dom::F` (2^13) sitting
exactly on their pads and `Ht`, `L`, `D`, `Q`, `S`, `Tab` padding.

THREE ARMS.

* A PURE arm that needs no bundle: the pad rule as arithmetic -- which
  domains pad at rung-K4 and at rung-P2, which slot hosts each, and the
  definition draw count each host slot therefore consumes.
* The RECORDED arm, which always runs: every figure this round's report
  quotes, asserted from the tracked evidence under
  `results/zk60_native_run_gate_p2/`, including that the evidence was
  produced by the tool bytes now in the tree.
* The LIVE arm, skipped when the ~16 MB bundles are absent: the terminal
  identity re-run on the bundle for the three unpadded slots, CT-9 (the
  development-shape twin of M9-3) fired in both directions, and the
  repaired M9-3 itself.

Nothing here asserts a privacy property.  A capture carries no witness.
"""

from __future__ import annotations

import json
import os
import sys
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "scripts"))

EVIDENCE = os.path.join(ROOT, "results", "zk60_native_run_gate_p2")
BUNDLES = os.environ.get(
    "ZK60_RUN_BUNDLES",
    "/home/victor/wt-zk60-block125m/results/zk60_run_captures_20260920",
)
RUN_K = os.path.join(BUNDLES, "run-k-dense-p2")
RUN_L = os.path.join(BUNDLES, "run-l-zero-p2")
RUN_I = os.path.join(BUNDLES, "run-i-dense-k4")
HAVE_P2 = os.path.isdir(RUN_K) and os.path.isdir(RUN_L)
HAVE_K4 = os.path.isdir(RUN_I)

import zk60_native_run_gate as gate  # noqa: E402
from zk60_native_rg_bundle import RunBundle  # noqa: E402
from zk60_native_rg_m125controls import (  # noqa: E402
    m9_3_the_unpadded_domains,
)
from zk60_native_rg_planes import plane_index_of  # noqa: E402
from zk60_native_rg_predict import (  # noqa: E402
    HOST_SLOT,
    ZERO_CHECK_SLOTS,
    pad_rule,
    predict,
    true_size,
)
from zk60_native_rg_replay import RunReplay  # noqa: E402
from zk60_native_rg_tcontrols import _pad_rule_controls  # noqa: E402
from zk60_native_rg_terminals import (  # noqa: E402
    PINNED_IF_PRESENT,
    PadGeometry,
    check_terminals,
)
from zk60_native_rg_gqa import ARGUMENT_DEFINITIONS, REPAIRED  # noqa: E402

# The two shapes, written out so the pure arm needs no file.  rung-P2 is
# rung-K4's PADDED layout with two true sizes moved onto their pads.
RUNG_K4_SHAPE = {"tokens": 24, "width": 96, "hidden": 192, "q_heads": 12,
                 "kv_heads": 4, "head_dim": 8, "t_pad": 32, "h_pad": 16,
                 "d_pad": 128, "f_pad": 256}
RUNG_P2_SHAPE = {"tokens": 32, "width": 96, "hidden": 256, "q_heads": 12,
                 "kv_heads": 4, "head_dim": 8, "t_pad": 32, "h_pad": 16,
                 "d_pad": 128, "f_pad": 256}
# the domain logs both shapes declare (identical: the same padded layout)
DOMAIN_LOGS = {"T": 5, "Ht": 9, "L": 10, "D": 12, "Q": 12, "Kv": 10,
               "S": 14, "F": 13, "Tab": 10}

P2_SHAPE_DIGEST = (
    "502ba5caac76bdfd026c77761a7735ccc94cf56a157d8bd0dbfbde6c773dd04b")
P2_ARGUMENT_DIGEST = (
    "ec3f97443245f119dd8adc0739a5df17588dc15bb3730382310a95fb7d2a9f9d")


def _rec(name):
    with open(os.path.join(EVIDENCE, f"{name}.json")) as fh:
        return json.load(fh)


# =====================================================================
#  the PURE arm: the pad rule as arithmetic
# =====================================================================
class ThePadRuleIsArithmetic(unittest.TestCase):
    """`Shape::true_size` against the padded size, at both shapes, with no
    bundle and no port."""

    def test_rung_p2_is_rung_k4s_padded_layout_with_three_domains_exact(self):
        for dom, log in DOMAIN_LOGS.items():
            k4 = true_size(RUNG_K4_SHAPE, dom)
            p2 = true_size(RUNG_P2_SHAPE, dom)
            self.assertLessEqual(k4, 1 << log, dom)
            self.assertLessEqual(p2, 1 << log, dom)
        # at rung-K4 every domain pads
        self.assertEqual(
            sorted(d for d, lg in DOMAIN_LOGS.items()
                   if true_size(RUNG_K4_SHAPE, d) == (1 << lg)), [])
        # at rung-P2 exactly three do not
        self.assertEqual(
            sorted(d for d, lg in DOMAIN_LOGS.items()
                   if true_size(RUNG_P2_SHAPE, d) == (1 << lg)),
            ["F", "Kv", "T"])

    def test_the_three_exact_domains_are_the_ones_125m_has(self):
        """The whole reason the shape exists: the SAME split as 125M."""
        m125 = {"tokens": 512, "width": 768, "hidden": 2048, "q_heads": 12,
                "kv_heads": 4, "head_dim": 64}
        logs = {"T": 9, "Kv": 17, "F": 20}
        for dom, log in logs.items():
            self.assertEqual(true_size(m125, dom), 1 << log, dom)
            self.assertEqual(true_size(RUNG_P2_SHAPE, dom),
                             1 << DOMAIN_LOGS[dom], dom)

    def test_the_host_slot_of_each_unpadded_domain(self):
        self.assertEqual(HOST_SLOT["T"], 2)
        self.assertEqual(HOST_SLOT["Kv"], 16)
        self.assertEqual(HOST_SLOT["F"], 18)
        for slot, (name, *_rest) in ZERO_CHECK_SLOTS.items():
            self.assertIn(slot, (2, 3, 14, 15, 16, 17, 18, 19), name)

    def test_the_draw_count_law_at_both_shapes(self):
        """tau(log dom) + mu(base + n_pad) + nu + zeta(n_pad), with the
        helper counts of this layout (identical at both shapes)."""
        helpers = {"D": 19, "Q": 7, "Kv": 6, "S": 8, "F": 5}
        want_k4 = {2: 15, 3: 12, 14: 46, 15: 24, 16: 21, 17: 32, 18: 26,
                   19: 15}
        want_p2 = {2: 13, 3: 12, 14: 46, 15: 24, 16: 19, 17: 32, 18: 24,
                   19: 15}
        for shape, want in ((RUNG_K4_SHAPE, want_k4), (RUNG_P2_SHAPE, want_p2)):
            for slot, (_n, tau_dom, hosts, uses_help, base, nu) in \
                    ZERO_CHECK_SLOTS.items():
                on = any(true_size(shape, d) != (1 << DOMAIN_LOGS[d])
                         for d in hosts)
                n_pad = 1 if on else 0
                n_help = helpers.get(tau_dom, 0) if uses_help else 0
                got = (DOMAIN_LOGS[tau_dom] + base + n_help + n_pad + nu
                       + n_pad)
                self.assertEqual(got, want[slot], f"slot {slot}")

    def test_the_three_slots_differ_by_exactly_two_draws(self):
        for slot in (2, 16, 18):
            self.assertEqual(
                {2: 15, 16: 21, 18: 26}[slot] - {2: 13, 16: 19, 18: 24}[slot],
                2, f"slot {slot}: one mu and one zeta")


# =====================================================================
#  the RECORDED arm
# =====================================================================
class TheRecordedFiguresAtRungP2(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.d = _rec("run-k-dense-p2")
        cls.z = _rec("run-l-zero-p2")
        cls.p = _rec("prediction_p2")

    def test_the_evidence_came_from_the_tool_bytes_now_in_the_tree(self):
        now = gate.tool_hashes()
        for rec in (self.d, self.z):
            self.assertEqual(rec["tool_sha256"], now, rec["bundle"])

    def test_both_records_pass_every_stage(self):
        for rec in (self.d, self.z):
            self.assertTrue(rec["ok"], rec["bundle"])
            for k in [k for k in rec if k.startswith("stage")]:
                self.assertTrue(rec[k]["ok"], f"{rec['bundle']}: {k}")

    def test_the_headline_all_46_slot_checks_hold(self):
        """23 slots of each of 2 stages, including 02, 16 and 18 -- the
        three whose hosted domain does not pad."""
        for rec in (self.d, self.z):
            t = rec["stage8_plane_index_and_terminals"]["terminal_identity"]
            self.assertEqual(t["slot_checks_expected"], 46)
            self.assertEqual(t["slot_checks_equal"], 46)
            self.assertEqual(t["open_slots"], [])
            self.assertEqual(t["findings"], [])
            for st in t["per_stage"]:
                for slot in (2, 16, 18):
                    self.assertIn(slot, st["equal"],
                                  f"{rec['bundle']} stage {st['stage']}")

    def test_the_replay_and_the_hash_layer(self):
        for rec in (self.d, self.z):
            rp = rec["stage2_transcript_replay"]
            self.assertEqual(rp["positions_checked"], 251)
            self.assertEqual(rp["challenges_checked"], 4560)
            self.assertEqual(rp["not_rederived"], [])
            h = rec["stage9_hash_layer"]
            self.assertEqual((h["openings"], h["columns_checked"],
                              h["bytes_hashed"]), (9, 2304, 6189056))
            self.assertEqual(h["findings"], [])

    def test_every_disclosed_dimension_is_the_law(self):
        want = {"A@0": 0, "A@1": 0, "H@0": 2, "H@1": 2, "E-Input": 0,
                "E-Output": 0, "B0": 0}
        for rec in (self.d, self.z):
            got = {c["role"]: c["disclosed_dimension"]
                   for c in rec["stage3_per_commitment"]["per_commitment"]}
            self.assertEqual(got, want, rec["bundle"])
            for m in rec["stage3_per_commitment"]["masking_commitments"]:
                self.assertEqual((m["rows"], m["disclosed_dimension"]), (50, 0))

    def test_the_rows_groups_and_claims_are_rung_k4s(self):
        """The same PADDED layout, so the same commitment geometry."""
        want = {"A@0": (727, 36, 122), "A@1": (727, 36, 122),
                "H@0": (720, 9, 53), "H@1": (720, 9, 53),
                "E-Input": (9, 1, 1), "E-Output": (9, 1, 1), "B0": (10, 2, 2)}
        for rec in (self.d, self.z):
            got = {c["role"]: (c["rows"], c["groups"], c["claims"])
                   for c in rec["stage3_per_commitment"]["per_commitment"]}
            self.assertEqual(got, want, rec["bundle"])

    def test_the_boundary_and_the_whole_run(self):
        for rec in (self.d, self.z):
            w = rec["stage4_the_boundary"]["whole_run"]
            self.assertEqual((w["identified_rows"], w["sum_of_parts_fp"],
                              w["joint_fp"], w["generators"]),
                             (16, 4, 4, 206), rec["bundle"])
            self.assertTrue(w["joint_equals_sum_of_parts"])
            self.assertTrue(w["non_data_block_is_block_diagonal_by_role"])

    def test_the_full_preimage_and_the_joint_one(self):
        for rec, s11, s13 in ((self.d, 862980, 894880),
                              (self.z, 860852, 892752)):
            a = rec["stage11_full_preimage"]
            self.assertEqual(len(a["exhibited"]), 7)
            self.assertEqual(a["not_exhibited"], [])
            self.assertEqual(a["view_entries_compared"], s11)
            self.assertEqual(a["view_entries_differing"], 0)
            self.assertEqual(a["salted_leaves_authenticated"], 1792)
            self.assertEqual([c["control"] for c in a["controls"]["controls"]],
                             ["P-1", "P-2", "P-3", "P-4", "P-5", "P-6"])
            self.assertTrue(all(c["fires"] for c in a["controls"]["controls"]))
            j = rec["stage13_joint_run_preimage"]
            self.assertEqual(j["entries_compared"], s13)
            self.assertEqual(j["entries_differing"], 0)
            self.assertEqual(j["salted_leaves_authenticated"], 2304)
            self.assertTrue(j["all_four_couplings_respected"])
            c1 = j["couplings"]["C1_shared_planes"]
            self.assertEqual(c1["identified_row_pairs"], 16)
            self.assertEqual(c1["both_sides_are_data_rows"], 16)
            self.assertEqual(c1["pairs_touching_a_blinding_row"], [])

    def test_the_joint_entry_count_is_the_sum_of_the_two_arms(self):
        """Stage 13 RECOMPUTES nothing: it checks the four couplings and
        adds the two arms up.  Said here so the number is never read as a
        third verification."""
        for rec in (self.d, self.z):
            j = rec["stage13_joint_run_preimage"]
            self.assertEqual(
                j["entries_compared"],
                rec["stage11_full_preimage"]["view_entries_compared"]
                + rec["stage12_mask_and_cfs"]["entries_recomputed"])
            self.assertEqual(
                j["salted_leaves_authenticated"],
                rec["stage11_full_preimage"]["salted_leaves_authenticated"]
                + rec["stage12_mask_and_cfs"]["salted_leaves_authenticated"])

    def test_the_masking_layer(self):
        for rec in (self.d, self.z):
            m = rec["stage12_mask_and_cfs"]
            self.assertEqual(m["entries_recomputed"], 31900)
            self.assertEqual(m["entries_differing"], 0)
            self.assertEqual(m["salted_leaves_authenticated"], 512)
            self.assertEqual(m["stages_checked"], 2)

    def test_the_mask_entries_are_25_per_stage_short_of_rung_k4s(self):
        """The same 25 sumcheck rounds that make a segment 400 bytes
        shorter: slots 16 and 18 lose one round value each per round."""
        k4_per_stage = 47925 // 3
        p2_per_stage = self.d["stage12_mask_and_cfs"]["entries_recomputed"] // 2
        self.assertEqual(k4_per_stage - p2_per_stage, 25)

    def test_the_channel_table(self):
        for rec in (self.d, self.z):
            ch = rec["stage7_channels"]
            self.assertEqual(ch["total"], 28)
            # [ROUND 9j, DELIBERATE] status page row 26: the boundary scale
            # channel OPEN -> ARGUED on D12b(3) / ruling R-5 (built, lane stage
            # 21), so argued +1 and open -1; no figure moved
            self.assertEqual(dict(ch["counts"]),
                             {"constructed": 10, "derived": 5, "argued": 5,
                              "open": 8})
            self.assertEqual(ch["grading_failures"], [])

    def test_every_control_family_fires(self):
        for rec in (self.d, self.z):
            ct = rec["stage8_plane_index_and_terminals"]["controls"]
            names = [c["control"] for c in ct["controls"]]
            self.assertEqual(names[:9], ["CT-1", "CT-2", "CT-3", "CT-4",
                                         "CT-5", "CT-6", "CT-7", "CT-8",
                                         "CT-9"])
            self.assertTrue(all(c["fires"] for c in ct["controls"]),
                            [c["control"] for c in ct["controls"]
                             if not c["fires"]])
            gq = rec["stage10_bilinear_group_factor"]["controls"]["controls"]
            self.assertTrue(all(c["fires"] for c in gq))
            s6 = rec["stage6_negative_controls"]
            self.assertTrue(s6["all_fire"])

    def test_CT9_is_the_M9_3_twin_and_the_record_says_which_directions(self):
        for rec in (self.d, self.z):
            ct9 = next(c for c in rec["stage8_plane_index_and_terminals"]
                       ["controls"]["controls"] if c["control"] == "CT-9")
            self.assertEqual(ct9["domains_that_do_not_pad_at_this_shape"],
                             ["F", "Kv", "T"])
            self.assertTrue(ct9["the_M9_3_direction_exists_here"])
            self.assertEqual(ct9["mirror_domain"], "L")
            per = {p["domain"]: p for p in ct9["per_domain"]}
            self.assertEqual(sorted(per), ["F", "Kv", "L", "T"])
            for dom, slot in (("T", 2), ("Kv", 16), ("F", 18), ("L", 3)):
                p = per[dom]
                self.assertEqual(p["slot"], slot)
                self.assertTrue(p["fires"], dom)
                self.assertTrue(p["the_refusal_names_the_two_numbers"], dom)
                self.assertTrue(p["only_this_slot_stopped_being_checked"], dom)
                self.assertIn("definition draws", p["refusal"])

    def test_the_prediction_was_validated_on_three_earlier_shapes(self):
        self.assertTrue(self.p["validation_ok"])
        self.assertEqual(sorted(self.p["validated_on"]),
                         ["m125-capture-dense-l2", "run-g-dense-s20",
                          "run-i-dense-k4"])
        for v in self.p["validation"]:
            self.assertEqual(v["mismatches"], [], v["bundle"])

    def test_the_prediction_derived_the_draw_counts_before_the_run(self):
        pr = self.p["prediction"]["pad_rule"]
        self.assertTrue(pr["all_derived_counts_equal_the_capture"])
        self.assertEqual(pr["domains_that_do_not_pad"], ["F", "Kv", "T"])
        got = {s["slot"]: (s["predicted_definition_draws"],
                           s["declared_by_the_capture"])
               for s in pr["per_zero_check_slot"]}
        self.assertEqual(got[2], (13, 13))
        self.assertEqual(got[16], (19, 19))
        self.assertEqual(got[18], (24, 24))

    def test_the_segment_length_law(self):
        r = self.p["prediction"]["receipt"]
        self.assertEqual(r["segment_bytes_declared"], [4574904, 4765336])
        self.assertEqual(r["rounds_of_slots_16_and_18"], 25)
        # rung-K4's own stages, for the 400-byte difference
        self.assertEqual(4575304 - 4574904, 16 * 25)
        self.assertEqual(4765736 - 4765336, 16 * 25)

    def test_the_pins_this_round_read(self):
        self.assertIn(P2_SHAPE_DIGEST,
                      PINNED_IF_PRESENT["src/private_block/shape.rs"])
        self.assertIn("src/private_block/pad.rs", PINNED_IF_PRESENT)
        self.assertEqual(len(PINNED_IF_PRESENT["src/private_block/pad.rs"]), 3)
        self.assertEqual(ARGUMENT_DEFINITIONS[P2_ARGUMENT_DIGEST][0], REPAIRED)
        for rec in (self.d, self.z):
            sp = rec["run_layer_source_pins"]
            self.assertTrue(sp["ok"], sp["pins_that_moved"])
            self.assertEqual(sp["pins_that_moved"], [])
            self.assertEqual(sp["pins_missing_from_the_bundle"], [])
            sh = sp["shared_files"]
            self.assertTrue(sh["pinned"])
            self.assertEqual(sh["files_pinned"], 23)
            self.assertEqual(sh["at_a_digest_this_gate_read"], 23)

    def test_dense_against_zero(self):
        with open(os.path.join(
                EVIDENCE, "witness_comparison_p2_dense_vs_zero.json")) as fh:
            cmp_ = json.load(fh)
        self.assertEqual(cmp_["figures_compared"], 136)
        self.assertEqual(cmp_["figures_identical"], 120)
        differ = [r for r in cmp_["per_figure"] if not r["identical"]]
        self.assertEqual(len(differ), 16)
        for r in differ:
            self.assertTrue(
                "distinct" in r["figure"] or "pad margin" in r["figure"]
                or "exact rank" in r["figure"], r["figure"])

    def test_the_classified_comparison_has_nothing_unexplained(self):
        with open(os.path.join(EVIDENCE, "comparison_table_p2.json")) as fh:
            tab = json.load(fh)
        self.assertEqual(tab["counts"]["unexplained"], 0)
        self.assertEqual(tab["BROKEN_INVARIANTS"], [])
        self.assertEqual(tab["PREDICTIONS_THAT_MISSED"], [])
        self.assertEqual(tab["counts"]["invariant"], 55)
        self.assertEqual(tab["invariants_that_are_identical_at_all_three_shapes"], 55)
        self.assertTrue(tab["ok"])


# =====================================================================
#  the LIVE arm
# =====================================================================
@unittest.skipUnless(HAVE_P2, "the rung-P2 capture bundles are not on this box")
class TheLiveArmAtRungP2(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.b = RunBundle(RUN_K)
        cls.index, _reason = plane_index_of(cls.b)
        cls.replay = RunReplay(cls.b).run()

    def test_the_bundle_is_the_shape_this_round_is_about(self):
        sh = self.b.shape.raw
        self.assertEqual((sh["tokens"], sh["width"], sh["hidden"]),
                         (32, 96, 256))
        self.assertEqual((sh["q_heads"], sh["kv_heads"], sh["head_dim"]),
                         (12, 4, 8))
        self.assertEqual(self.b.manifest["profile"],
                         "hashline-zk-mr1/private-run-rung-p2-t32-dev/1")
        self.assertEqual(self.b.manifest["source_commit"], "4ccbad1")

    def test_the_port_derives_the_pad_state_and_three_domains_do_not_pad(self):
        geom = PadGeometry(self.b.run["shape"], self.index.domain_log)
        got = sorted(d for d in DOMAIN_LOGS if not geom.pads(d))
        self.assertEqual(got, ["F", "Kv", "T"])

    def test_the_terminal_identity_live_for_the_three_unpadded_slots(self):
        """Seconds, on the bundle: the whole identity, with slots 02, 16
        and 18 taking the `pad_on == false` arm."""
        got = check_terminals(self.b, self.index, replay=self.replay)
        self.assertEqual(got["slot_checks_equal"], 46)
        self.assertEqual(got["slot_checks_expected"], 46)
        for st in got["per_stage"]:
            for slot in (2, 16, 18):
                self.assertIn(slot, st["equal"])
                self.assertIn(slot, st["checked"])

    def test_CT9_fires_live_in_both_directions(self):
        """M9-3's development-shape twin, in the ordinary suite."""
        honest = check_terminals(self.b, self.index, replay=self.replay)
        ct9 = _pad_rule_controls(self.b, self.index, self.replay, honest)[0]
        self.assertTrue(ct9["fires"])
        self.assertEqual(ct9["domains_that_do_not_pad_at_this_shape"],
                         ["F", "Kv", "T"])
        for p in ct9["per_domain"]:
            self.assertTrue(p["fires"], p["domain"])
            self.assertTrue(p["the_refusal_names_the_two_numbers"])
            self.assertIn("the capture declares", p["refusal"])
        # and the honest state is restored: the same check passes again
        again = check_terminals(self.b, self.index, replay=self.replay)
        self.assertEqual(again["slot_checks_equal"], 46)

    def test_the_repaired_M9_3_fires_here(self):
        """Round 9's own control, which until round 9b read `index.geom`
        (a `PlaneIndex` has none) and excused itself as inapplicable at
        every shape -- finding P-F2."""
        out = m9_3_the_unpadded_domains(self.b, self.index, self.replay)
        self.assertIsNone(out["skipped"])
        self.assertEqual(out["domains_that_do_not_pad"], ["F", "Kv", "T"])
        self.assertTrue(out["fires"])
        for p in out["per_domain"]:
            self.assertTrue(p["fires"], p["domain"])
            self.assertIsNotNone(p["refusal"])

    def test_the_prediction_module_on_the_bundle(self):
        p = predict(self.b)
        self.assertEqual(p["pad_rule"]["domains_that_do_not_pad"],
                         ["F", "Kv", "T"])
        self.assertTrue(p["pad_rule"]["all_derived_counts_equal_the_capture"])
        self.assertEqual(p["replay"]["positions_checked"], 251)
        self.assertEqual(p["replay"]["challenges_checked"], 4560)

    @unittest.skipUnless(HAVE_K4, "the rung-K4 bundles are not on this box")
    def test_the_two_shapes_declare_the_same_domain_logs(self):
        k4 = RunBundle(RUN_I)
        logs_k4 = {d["domain"]: d["domain_log"] for d in pad_rule(k4)["domains"]}
        logs_p2 = {d["domain"]: d["domain_log"]
                   for d in pad_rule(self.b)["domains"]}
        self.assertEqual(logs_k4, logs_p2)
        self.assertEqual(logs_p2, DOMAIN_LOGS)
        pads_k4 = {d["domain"]: d["pads"] for d in pad_rule(k4)["domains"]}
        self.assertTrue(all(pads_k4.values()), "every domain pads at rung-K4")

    @unittest.skipUnless(HAVE_K4, "the rung-K4 bundles are not on this box")
    def test_the_segment_lengths_against_rung_k4(self):
        k4 = RunBundle(RUN_I)
        k_segs = [st.doc["segment_bytes"] for st in k4.stages]
        p_segs = [st.doc["segment_bytes"] for st in self.b.stages]
        self.assertEqual(k_segs[0] - p_segs[0], 400)
        self.assertEqual(k_segs[-1] - p_segs[-1], 400)


if __name__ == "__main__":
    unittest.main()
