"""Tests for round 8: the masking commitment `M` and the masked-sumcheck
(CFS) channel at the SHAPED layouts -- the largest channel round 7 left open.

Run:
  python3 -m unittest discover -s tests \
      -p "test_zk60_native_run_gate_mask.py"

FOUR ARMS, as round 7 has.

* A PURE arm that needs nothing: every arithmetic object of the new module
  really IS the toy records' object (identity, not a copy), this file
  defines no `def`/`class` of those names, and the four maps --
  `LAYOUT_SPECIFIC`, `IMPORTED_OBJECTS`, `DERIVED_FROM`, `NEW_HERE` -- are
  complete accounts rather than decoration.
* An EQUIVALENCE arm on the TOY captures, which are tracked here: the
  driver run at the toy's widths must reproduce the TOY GATE's own
  committed figures -- including the two exhibited-randomness digests -- to
  the byte.  This is the evidence that round 8 is not a second solver.
* The RECORDED arm, skipped when round 8's evidence is absent: every figure
  the report quotes, asserted from `results/zk60_native_run_gate_mask/`.
* The LIVE arm, skipped when the ~41 MB bundles are absent: one stage
  solved and verified from scratch, the pad budget, and each of the six
  controls -- plus the assertion that no captured byte moved.

Nothing here asserts a privacy property.  A constructed preimage says the
captured masking view is reproducible from a FIXED, public element of the
channel's data space with suitable coefficients and blinding; it says
nothing about the LAW of that blinding, and the fixed transcript is not the
zero witness's own.
"""

from __future__ import annotations

import hashlib
import json
import os
import re
import sys
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "scripts"))

EVIDENCE = os.path.join(ROOT, "results", "zk60_native_run_gate_mask")
TOY = os.path.join(ROOT, "results", "zk60_native_captures_20260919", "captures")
TOY_BLOCK = os.path.join(
    TOY, "40083e7ac8f3f6c749f12de31ddd9c0e779a016c33fb50180003c60d7cf0716b.json")
BUNDLES = os.environ.get(
    "ZK60_RUN_BUNDLES",
    "/home/victor/wt-zk60-block125m/results/zk60_run_captures_20260920",
)
RUN_G = os.path.join(BUNDLES, "run-g-dense-s20")
RUN_I = os.path.join(BUNDLES, "run-i-dense-k4")
HAVE_BUNDLES = os.path.isdir(RUN_G) and os.path.isdir(RUN_I)
HAVE_TOY = os.path.isfile(TOY_BLOCK)
RECORDS = sorted(
    f for f in (os.listdir(EVIDENCE) if os.path.isdir(EVIDENCE) else [])
    if f.endswith(".json") and f.startswith("run-")
)
HAVE_RECORDS = bool(RECORDS)
EQ_RECORD = os.path.join(EVIDENCE, "toy_equivalence.json")
HAVE_EQ = os.path.isfile(EQ_RECORD)

import zk60_native_mask_commit as toy_mask  # noqa: E402
import zk60_native_pg_cfs as toy_cfs  # noqa: E402
import zk60_native_rg_mask as rgm  # noqa: E402
import zk60_native_rg_mcontrols as rgc  # noqa: E402
import zk60_native_run_gate as gate  # noqa: E402

_STATE = {}


def live(which=RUN_G):
    """The bundle and its replay, built once per process."""
    if which not in _STATE:
        from zk60_native_rg_bundle import RunBundle
        from zk60_native_rg_replay import RunReplay

        b = RunBundle(which)
        _STATE[which] = (b, RunReplay(b).run())
    return _STATE[which]


def record(name):
    with open(os.path.join(EVIDENCE, name)) as fh:
        return json.load(fh)


# ============================================================ the PURE arm
class TestNotAFork(unittest.TestCase):
    """The new module borrows the toy records; it does not copy them."""

    def test_every_imported_object_is_the_toy_module_s_own(self):
        import importlib

        for mod_name, names in rgm.IMPORTED_OBJECTS.items():
            mod = importlib.import_module(mod_name)
            for n in names:
                self.assertIs(
                    getattr(rgm, n), getattr(mod, n),
                    f"{n} in zk60_native_rg_mask is not {mod_name}.{n}",
                )

    def test_the_new_module_defines_none_of_those_names(self):
        with open(os.path.join(ROOT, "scripts", "zk60_native_rg_mask.py")) as fh:
            src = fh.read()
        for names in rgm.IMPORTED_OBJECTS.values():
            for n in names:
                self.assertIsNone(
                    re.search(rf"^(def|class)\s+{re.escape(n)}\b", src, re.M),
                    f"zk60_native_rg_mask re-implements {n}",
                )

    def test_layout_specific_has_exactly_the_five(self):
        self.assertEqual(
            sorted(rgm.LAYOUT_SPECIFIC),
            sorted([
                "the Merkle layer",
                "the Rust pins",
                "the capture and replay types",
                "the cross-check against a shape",
                "the three domain constants",
            ]),
        )
        for k, v in rgm.LAYOUT_SPECIFIC.items():
            self.assertIn("Supplied", v, f"{k} does not say what replaces it")

    def test_new_here_covers_every_public_function_this_module_defines(self):
        with open(os.path.join(ROOT, "scripts", "zk60_native_rg_mask.py")) as fh:
            src = fh.read()
        defined = {
            m.group(2)
            for m in re.finditer(r"^(def|class)\s+(\w+)", src, re.M)
        }
        mapped = set(rgm.NEW_HERE) | {
            k.split("/")[0] for k in rgm.DERIVED_FROM
        }
        # helpers, the control arithmetic and the CLI are named separately
        allowed = {
            "check_specs_against_shape", "disclosed_with_identification",
            "theta_weight_of", "batched_value", "permuted_weights",
            "one_functional", "f2_of", "main", "compare_with_the_toy_record",
            "_coef_digest", "_entries", "_hash_layer",
        }
        missing = {d for d in defined if not d.startswith("_")} - mapped - allowed
        self.assertEqual(missing, set(), f"unmapped definitions: {missing}")

    def test_the_pin_tables_carry_a_reading_for_every_digest(self):
        for path, table in rgm.MASK_LAYER_PINS.items():
            for sha, ent in table.items():
                self.assertEqual(len(sha), 64)
                self.assertTrue(ent["reading"], f"{path}/{sha}: no reading")
                self.assertTrue(ent["commits"])
                self.assertTrue(ent["bundles"])
        for path, ent in rgm.NOT_PINNABLE_FROM_A_BUNDLE.items():
            self.assertTrue(ent["reading"], f"{path}: no reading")
            self.assertTrue(ent["why_not_pinnable"])
            self.assertEqual(len(ent["toy_pin"]), 64)
            self.assertEqual(len(ent["at_the_capture_commits"]), 64)

    def test_the_gate_hashes_the_new_tools_and_the_two_toy_records(self):
        for t in ("zk60_native_rg_mask.py", "zk60_native_rg_mcontrols.py",
                  "zk60_native_pg_cfs.py", "zk60_native_mask_commit.py"):
            self.assertIn(t, gate.TOOLS)

    def test_the_arm_is_off_by_default(self):
        self.assertFalse(gate.MASK_CFS_OFF["requested"])
        self.assertIn("--mask-cfs", gate.MASK_CFS_OFF["why_off"])

    def test_the_two_toy_records_are_not_edited_by_this_lane(self):
        """Their bytes are what the whole 'not a fork' claim rests on."""
        for name, want in (
            ("zk60_native_mask_commit.py",
             "fae15b4927b76f47a380050a66acdce245746db779b03b7f96d66061920334f1"),
            ("zk60_native_pg_cfs.py",
             "4ee924228f3248f965dc8dce5c5f88fac0131b11ee4ede5ec72b2c3dac7d8302"),
        ):
            p = os.path.join(ROOT, "scripts", name)
            with open(p, "rb") as fh:
                got = hashlib.sha256(fh.read()).hexdigest()
            self.assertEqual(
                got, want,
                f"{name} changed: round 8 must not edit the toy records",
            )


# ===================================================== the EQUIVALENCE arm
@unittest.skipUnless(HAVE_TOY, "the tracked toy captures are absent")
class TestEquivalenceToTheToyGate(unittest.TestCase):
    """The driver at the toy's widths reproduces the toy gate's figures."""

    @classmethod
    def setUpClass(cls):
        from zk60_native_jv_capture import Capture
        from zk60_native_jv_replay import Replay

        cls.cap = Capture(TOY_BLOCK)
        cls.rp = Replay(cls.cap).run()
        cls.eq = rgm.toy_equivalence(cls.cap, cls.rp)

    def test_every_figure_equals_the_toy_gate_s_committed_record(self):
        cmp = rgm.compare_with_the_toy_record(self.eq)
        self.assertEqual(cmp["differences"], [])
        self.assertEqual(cmp["equal"], cmp["figures_compared"])
        self.assertGreaterEqual(cmp["figures_compared"], 19)

    def test_the_two_exhibited_randomness_digests_are_the_toy_s(self):
        for tag, want in rgm.TOY_BLOCK_EXPECTED[
                "exhibited_randomness_sha256"].items():
            self.assertEqual(
                self.eq["preimages"][tag]["exhibited_randomness_sha256"], want)

    def test_the_join_also_works_at_the_toy(self):
        """The CFS-solved coefficients reproduce the toy's M opening too."""
        v = self.eq["joined_preimage_at_the_toy"]
        self.assertIsNotNone(v)
        self.assertTrue(v["all_entries_equal"])
        self.assertEqual(v["column_mismatches"], 0)

    def test_the_toy_model_object_is_the_toy_module_s_class(self):
        mm = toy_mask.MaskModel(self.cap, self.rp)
        self.assertIs(type(mm), toy_mask.MaskModel)
        self.assertIs(rgm.MaskModel, toy_mask.MaskModel)
        self.assertIs(rgm.CfsPreimage, toy_cfs.CfsPreimage)


# ======================================================== the RECORDED arm
@unittest.skipUnless(HAVE_EQ, "round 8's equivalence record is absent")
class TestEquivalenceRecord(unittest.TestCase):
    def test_the_record_says_every_figure_is_equal(self):
        with open(EQ_RECORD) as fh:
            r = json.load(fh)
        self.assertTrue(r["ok"])
        self.assertTrue(r["against_the_toy_record"]["ok"])
        self.assertEqual(r["against_the_toy_record"]["differences"], [])
        self.assertFalse(r["privacy_property_established"])
        self.assertFalse(r["privacy_acceptance"])


@unittest.skipUnless(HAVE_RECORDS, "round 8's evidence is absent")
class TestTheRecord(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.recs = {n[:-5]: record(n) for n in RECORDS}

    def test_four_bundles_with_the_arm_on(self):
        self.assertEqual(
            sorted(self.recs),
            ["run-g-dense-s20", "run-h-zero-s20",
             "run-i-dense-k4", "run-j-zero-k4"],
        )
        for name, r in self.recs.items():
            self.assertTrue(r["stage12_mask_and_cfs"]["requested"], name)

    def test_every_stage_of_every_bundle_was_exhibited_and_verified(self):
        for name, r in self.recs.items():
            s = r["stage12_mask_and_cfs"]
            self.assertEqual(s["stages_checked"], 3, name)
            self.assertEqual(s["entries_differing"], 0, name)
            self.assertTrue(s["ok"], name)
            for st in s["per_stage"]:
                self.assertTrue(st["preimage"]["preimage_exhibited"])
                self.assertTrue(
                    st["cfs"]["verification"]["all_entries_equal"])
                self.assertEqual(
                    st["cfs"]["functional_values"]["mismatches"], 0)
                self.assertTrue(st["hash_layer"]["ok"])
                self.assertEqual(st["hash_layer"]["path_levels"], 12)

    def test_M_has_fifty_rows_and_thirty_four_functionals_at_both_rungs(self):
        for name, r in self.recs.items():
            s = r["stage12_mask_and_cfs"]
            self.assertEqual(s["mask_rows"], 50, name)
            self.assertEqual(s["functional_count"], 34, name)

    def test_the_mask_lengths_are_the_shape_s(self):
        g = self.recs["run-g-dense-s20"]["stage12_mask_and_cfs"]["mask_lengths"]
        k = self.recs["run-i-dense-k4"]["stage12_mask_and_cfs"]["mask_lengths"]
        self.assertEqual(max(g), 72)
        self.assertEqual(max(k), 77)
        self.assertEqual((g[8], g[9]), (23, 26))
        self.assertEqual((k[8], k[9]), (23, 29))

    def test_the_disclosed_dimension_is_two_everywhere(self):
        for name, r in self.recs.items():
            for st in r["stage12_mask_and_cfs"]["per_stage"]:
                self.assertEqual(st["disclosed"]["disclosed_fp_computed"], 2)
                self.assertTrue(st["disclosed"]["matches_prediction"])
                self.assertFalse(
                    st["off_the_V_plane_has_no_preimage"]["preimage_exhibited"])

    def test_every_control_fired_on_every_bundle(self):
        for name, r in self.recs.items():
            c = r["stage12_mask_and_cfs"]["controls"]
            self.assertTrue(c["all_fire"], f"{name}: {c.get('control_names')}")
            self.assertEqual(len(c["control_names"]), 6, name)

    def test_the_channel_table_moved_and_by_how_much(self):
        for name, r in self.recs.items():
            ch = r["stage7_channels"]
            self.assertEqual(ch["total"], 28, name)
            self.assertEqual(
                ch["counts"],
                {"constructed": 10, "derived": 5, "argued": 4, "open": 9},
                name,
            )
            self.assertEqual(ch["grading_failures"], [], name)

    def test_the_joint_run_preimage_and_its_four_couplings(self):
        for name, r in self.recs.items():
            j = r["stage13_joint_run_preimage"]
            self.assertTrue(j["requested"], name)
            self.assertTrue(j["ok"], name)
            self.assertEqual(j["entries_differing"], 0, name)
            self.assertTrue(j["all_four_couplings_respected"], name)
            c1 = j["couplings"]["C1_shared_planes"]
            self.assertEqual(c1["pairs_touching_a_blinding_row"], [], name)
            self.assertEqual(
                c1["identified_row_pairs"], c1["both_sides_are_data_rows"], name)
            self.assertGreater(c1["identified_row_pairs"], 0, name)
            self.assertFalse(
                j["couplings"]["C4_the_terminal_identity"]["linear_models_see_it"])
            self.assertTrue(
                j["couplings"]["C4_the_terminal_identity"][
                    "respected_only_in_that_narrow_sense"])
            self.assertFalse(j["privacy_property_established"], name)

    def test_no_record_claims_a_privacy_property(self):
        for name, r in self.recs.items():
            self.assertFalse(r["privacy_property_established"], name)
            self.assertFalse(r["privacy_acceptance"], name)
            self.assertFalse(r["privacy_review_complete"], name)
            self.assertFalse(
                r["stage12_mask_and_cfs"]["privacy_property_established"], name)


# ============================================================= the LIVE arm
@unittest.skipUnless(HAVE_BUNDLES, "the run bundles are absent")
class TestLive(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.b, cls.rp = live(RUN_G)
        cls.rec = rgm.mask_cfs_stage(cls.b, cls.rp, 0)

    def test_the_pins_accept_this_bundle(self):
        p = rgm.check_mask_layer_pins(self.b)
        self.assertTrue(p["ok"], p["refusals"])
        self.assertEqual(p["checked"], 3)
        self.assertEqual(p["not_pinnable_count"], 8)

    def test_the_mask_domain_is_derived_from_the_bundle_and_agrees(self):
        d = self.rec["mask_domain"]
        self.assertTrue(d["ok"], d["refusals"])
        self.assertEqual(d["declared_by_the_bundle"]["log_dom"], 12)
        self.assertEqual(d["declared_by_the_bundle"]["columns"], 256)
        self.assertEqual(d["msg_width_from_q"], 512)

    def test_the_specs_are_the_shape_s(self):
        s = self.rec["specs_against_the_shape"]
        self.assertTrue(s["ok"], s["failures"])
        self.assertEqual(s["bilinear_slots"], [8, 9])
        self.assertEqual(s["bilinear_mask_lengths"], {8: 23, 9: 26})

    def test_the_slot_row_map_covers_every_row_of_M(self):
        rows = set()
        for e in self.rec["slot_row_map"]:
            rows.update(e["rows"])
        self.assertEqual(rows, set(range(50)))

    def test_one_stage_is_constructed_and_verified(self):
        self.assertTrue(self.rec["ok"])
        e = self.rec["entries_recomputed"]
        self.assertEqual(e["differing"], 0)
        self.assertEqual(e["q_entries"], 1024)
        self.assertEqual(e["prox_entries"], 1024)
        self.assertEqual(e["column_entries"], 12800)
        self.assertEqual(e["salted_leaves_authenticated"], 256)
        self.assertEqual(e["functional_values"], 34)

    def test_the_pad_budget(self):
        p = self.rec["pad_budget"]
        self.assertTrue(p["ok"])
        self.assertEqual(p["pads_per_a_row"], 256)
        self.assertGreaterEqual(p["margin"], 0)
        self.assertLessEqual(p["largest_L_plus_Q"], p["message_width"])

    def test_the_fixed_transcript_is_named_and_is_not_the_witness_s(self):
        c = self.rec["cfs"]
        self.assertIn("flat honest transcript", c["fixed_transcript"])
        self.assertTrue(c["zero_transcript_is_infeasible"])

    def test_the_declared_order_is_thirty_four_of_thirty_four(self):
        d = self.rec["declared_order"]
        self.assertEqual(
            (d["position_matches"], d["value_matches"], d["weight_matches"]),
            (34, 34, 34),
        )
        self.assertTrue(d["host_gammas_last"])

    def test_a_stage_that_refuses_zeroes_its_counts_and_does_not_crash(self):
        """A REFUSAL IS NEVER A CRASH -- round 5's finding K4-F1, kept.

        The CFS side is made to refuse; every key a caller reads must be
        present, the counts must be zero, the zeros must SAY they are an
        absence, and the run-level and channel-level summaries must sum
        them without raising.
        """
        import unittest.mock as mock

        def _refuse(stage, acc, which="all"):
            return None, None, {"solved": False, "findings": ["forced refusal"]}

        with mock.patch.object(rgm, "joined_coefficients", _refuse):
            rec = rgm.mask_cfs_stage(self.b, self.rp, 0)
            run = rgm.mask_cfs_run(self.b, self.rp)
        self.assertFalse(rec["ok"])
        self.assertFalse(rec["preimage"]["preimage_exhibited"])
        self.assertIn("forced refusal", rec["preimage"]["why"])
        self.assertEqual(rec["entries_recomputed"]["total"], 0)
        self.assertIn("these_zeros_are_an_absence", rec["entries_recomputed"])
        self.assertFalse(rec["hash_layer"]["checked"])
        self.assertFalse(run["ok"])
        self.assertEqual(run["entries_recomputed"], 0)
        self.assertEqual(run["stages_that_refused"], [0, 1, 2])
        # and the channel summary, which is where the crash would have been
        fake = {
            "stage3_per_commitment": {"per_commitment": []},
            "stage5_zero_data_preimage": {"per_commitment": []},
            "stage12_mask_and_cfs": dict(run, requested=True),
        }
        stages = [
            (st.get("entries_recomputed") or {}).get("masked_round_entries", 0)
            for st in fake["stage12_mask_and_cfs"]["per_stage"]
        ]
        self.assertEqual(stages, [0, 0, 0])

    def test_a_mask_domain_that_moved_is_refused_by_name(self):
        class _B:
            pass

        fake = _B()
        fake.run = dict(self.b.run)
        fake.run["mask_domain"] = {"log_dom": 13, "columns": 255}
        d = rgm.derive_mask_domain(fake, self.b.stages[0])
        self.assertFalse(d["ok"])
        self.assertEqual(len(d["refusals"]), 2)
        self.assertIn("log_dom", d["refusals"][0])


@unittest.skipUnless(HAVE_BUNDLES, "the run bundles are absent")
class TestLiveControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.b, cls.rp = live(RUN_G)
        cls.c = rgc.mask_controls_at_shape(cls.b, cls.rp, 0)

    def test_all_six_fire_and_the_honest_case_passes(self):
        self.assertTrue(self.c["ok"])
        self.assertTrue(self.c["all_fire"])
        self.assertEqual(len(self.c["control_names"]), 6)
        self.assertTrue(self.c["honest"]["M_preimage_exhibited"])
        self.assertEqual(self.c["honest"]["M_column_mismatches"], 0)

    def test_M1_names_the_round_from_the_arithmetic(self):
        m = self.c["M1_one_masked_round_value_moved"]
        self.assertTrue(m["fires"])
        self.assertEqual(m["rounds_whose_removal_restores_feasibility"], [0])
        self.assertIn("slot 0", m["refusal"])

    def test_M2_fires_on_the_b_and_u_rows_of_the_moved_column(self):
        m = self.c["M2_one_opened_column_entry_moved"]
        self.assertEqual(m["at_a_b_row"]["column_mismatches"], 1)
        self.assertEqual(m["at_an_a_row"]["column_mismatches"], 4)
        self.assertEqual(m["at_an_a_row"]["first_mismatch"]["row"], 46)
        self.assertTrue(m["fires"])

    def test_M3_the_order_is_pinned_by_the_columns_not_only_the_sum(self):
        m = self.c["M3_declared_functional_order_permuted"]
        self.assertTrue(m["batched_value_changed"])
        self.assertFalse(m["same_coefficients_b_admissible"])
        self.assertTrue(m["forced_b_admissible"])
        self.assertGreater(m["forced_column_mismatches"], 0)
        self.assertTrue(m["fires"])

    def test_M4_hits_both_repaired_bilinear_slots(self):
        m = self.c["M4_a_slot_mask_length_declared_one_short"]
        self.assertEqual(m["bilinear_slots"], [8, 9])
        self.assertEqual([e["slot"] for e in m["per_slot"]], [8, 9])
        for e in m["per_slot"]:
            self.assertEqual(e["declared_L"], e["true_L"] - 1)
            self.assertFalse(e["weights_vanish_above_L"])
            self.assertFalse(e["preimage_exhibited"])
            self.assertTrue(e["spec_refusal_example"])

    def test_M5_is_the_masking_layer_s_P5(self):
        m = self.c["M5_one_coefficient_shared_between_two_slots"]
        f = m["flavours"]
        self.assertTrue(f["free_coordinate"]["the_two_slots_can_agree_there"])
        self.assertFalse(f["forced_coordinate"]["the_two_slots_can_agree_there"])
        self.assertEqual(f["forced_coordinate"]["slot_a_free_fp_there"], 0)
        self.assertEqual(f["forced_coordinate"]["slot_b_free_fp_there"], 0)
        # M's own disclosure does not move; the unknown space and fibre do
        self.assertEqual(f["forced_coordinate"]["disclosed_fp_after"],
                         m["rank_statement"]["disclosed_fp_before"])
        self.assertEqual(
            f["forced_coordinate"]["coefficient_unknowns_fp_after"],
            m["rank_statement"]["coefficient_unknowns_fp_before"] - 2)
        self.assertTrue(m["fires"])

    def test_M6_takes_the_pad_margin_away(self):
        m = self.c["M6_one_pad_fewer_than_the_distinct_opened_columns"]
        self.assertTrue(m["fires"])
        self.assertGreater(m["column_mismatches"], 0)

    def test_no_captured_byte_moved(self):
        """The perturbations are in memory; the bundle directory is intact."""
        h = hashlib.sha256()
        for n in sorted(os.listdir(RUN_G)):
            with open(os.path.join(RUN_G, n), "rb") as fh:
                h.update(hashlib.sha256(fh.read()).digest())
        from zk60_native_rg_bundle import RunBundle

        fresh = RunBundle(RUN_G)
        self.assertEqual(fresh.run_sha256, self.b.run_sha256)
        for a, c in zip(fresh.stages, self.b.stages):
            self.assertEqual(a.sha256, c.sha256)


@unittest.skipUnless(HAVE_BUNDLES, "the run bundles are absent")
class TestLiveK4(unittest.TestCase):
    """The rung-K4 shape moves the mask lengths and nothing else."""

    def test_the_bilinear_slots_move_and_M_keeps_fifty_rows(self):
        b, rp = live(RUN_I)
        rec = rgm.mask_cfs_stage(b, rp, 0)
        self.assertTrue(rec["ok"])
        s = rec["specs_against_the_shape"]
        self.assertEqual(s["bilinear_mask_lengths"], {8: 23, 9: 29})
        self.assertEqual(s["largest_mask_length"], 77)
        self.assertEqual(rec["shape"]["rows"], 50)
        self.assertEqual(rec["declared_order"]["captured_functionals"], 34)


if __name__ == "__main__":
    unittest.main()
