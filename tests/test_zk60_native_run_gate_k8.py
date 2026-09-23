"""Tests for round 9i: THREE key-value group bits (the rung-K8 development
shape, `lkv = 3`), the pins stages 35-37 moved, and the one control that
had been written for exactly two group bits.

Run:
  python3 -m unittest discover -s tests \
      -p "test_zk60_native_run_gate_k8.py"

WHY THERE IS A ROUND 9i.  R5.8 item 3: every shape this gate had read had
`lkv <= 2`.  Rung-K8 -- 24 tokens, width 128, hidden 192, 16 query heads of
8 over 8 key-value heads, rung-K4's padded layout -- is lane stage 37's
test-only shape, and the first with a THIRD group bit.  Only `lkv` moves
among the four axes the bilinear slots read (`lt`, `lh`, `ldh` are
rung-K4's); separately the key-value width doubles, so `Dom::Kv` goes from
`2^10` to `2^11`.

FOUR ARMS, as round 5's file.

* A PURE arm: the K8 geometry, both bilinear slots' dimensions and
  definition draws, both factors' coordinate schedules written out at
  THREE group bits, the counts the gate reports derived from the two
  geometries, and the pin readings this round added -- including that a
  digest nobody read is STILL refused.
* A GENERIC arm: `eq` over three variables on random field elements.
* The RECORDED arm: every figure the ledger quotes, from the tracked
  evidence under `results/zk60_native_run_gate_k8/`, including that it was
  produced by the tool bytes now in the tree.
* The LIVE arm, skipped when the ~47 MB bundles are absent: the group point
  derived at three coordinates and compared, and the new reorder control.

Nothing here asserts a privacy property.
"""

from __future__ import annotations

import json
import os
import random
import sys
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "scripts"))

EVIDENCE = os.path.join(ROOT, "results", "zk60_native_run_gate_k8")
K8_BUNDLES = os.environ.get(
    "ZK60_K8_BUNDLES",
    "/home/victor/wt-zk60-block125m/results/zk60_run_captures_20260922_k8",
)
RUN_S = os.path.join(K8_BUNDLES, "run-s-dense-k8")
RUN_T = os.path.join(K8_BUNDLES, "run-t-zero-k8")
HAVE_K8 = os.path.isdir(RUN_S) and os.path.isdir(RUN_T)

import zk60_native_run_gate as gate  # noqa: E402
import zk60_native_rg_mask as rgm  # noqa: E402
import zk60_native_rg_runpins as runpins  # noqa: E402
import zk60_native_rg_terminals as term  # noqa: E402
from zk60_native_jv_field import (  # noqa: E402
    F2_ONE,
    F2_ZERO,
    P,
    eq_table_msb,
    f2_add,
    f2_mul,
    f2_sub,
)
from zk60_native_rg_gqa import (  # noqa: E402
    ARGUMENT_DEFINITIONS,
    BILINEAR_SLOTS,
    PRE_REPAIR,
    REPAIRED,
    Geometry,
    definition_of_pin,
    eq_point,
)

RUNG_K4_SHAPE = {"tokens": 24, "width": 96, "hidden": 192, "q_heads": 12,
                 "kv_heads": 4, "head_dim": 8, "t_pad": 32, "h_pad": 16}
RUNG_K8_SHAPE = {"tokens": 24, "width": 128, "hidden": 192, "q_heads": 16,
                 "kv_heads": 8, "head_dim": 8, "t_pad": 32, "h_pad": 16}

# the digests stages 35-37 moved, read in round 9i (R9i.5 of the ledger)
ARGUMENT_K8 = "f7fa2ad4213d925b2d8dcb8d8273b92c6af2e9f90f94978da8630cc123fcef3d"
PROTOCOL_K8 = "e0e617be617a548641cb33c8564cee86ee7d2af90f9c6487b5fb7af30113d45b"
RNG_K8 = "b9920aeb3a12c2fd45e7f50f701852086cdf8bf73530de4f7658d4b4c09c3b9f"
TRANSCRIPT_K8 = "b8a228d9b33f7dbf19cd631c7b9a08eb9465b56ab3c32ea40c06fee2416adad4"
CAPTURE_COMMIT = "99a8de832a6322c94bf951f0f443b96e1dc63cb8"


class _Manifest:
    """The one attribute the pin checks read, so a pure test can hand them
    a declared pin set without a bundle on disk."""

    def __init__(self, pins, name="shadow"):
        self.manifest = {"source_pins": [{"file": f, "sha256": d}
                                         for f, d in pins.items()]}
        self.name = name


# =====================================================================
#  the PURE arm
# =====================================================================
class TheK8GeometryIsDerived(unittest.TestCase):

    def setUp(self):
        self.k4 = Geometry(RUNG_K4_SHAPE)
        self.k8 = Geometry(RUNG_K8_SHAPE)

    def test_three_group_bits_and_nothing_else_moves(self):
        self.assertEqual(self.k8.lkv, 3)
        self.assertEqual(self.k4.lkv, 2)
        for ax in ("lt", "lh", "ldh"):
            self.assertEqual(getattr(self.k8, ax), getattr(self.k4, ax), ax)

    def test_two_heads_per_group_and_no_padded_head_slot(self):
        """16 query heads over 8 groups in 16 slots: `head_slot` is the
        identity, so the within-group head axis is ONE bit and there is no
        padded slot -- where rung-K4 had {3, 7, 11, 15}."""
        geom = term.PadGeometry(dict(RUNG_K8_SHAPE, d_pad=128, f_pad=256), {})
        self.assertEqual([geom.head_slot(h) for h in range(16)],
                         list(range(16)))
        self.assertEqual(self.k8.lh - self.k8.lkv, 1)

    def test_the_bilinear_slot_dimensions_at_three_group_bits(self):
        self.assertEqual(self.k8.dims(8, REPAIRED), (6, 2, 3))
        self.assertEqual(self.k8.dims(9, REPAIRED), (8, 2, 3))
        self.assertEqual(self.k8.dims(8, PRE_REPAIR), (3, 2, 2))
        self.assertEqual(self.k8.dims(9, PRE_REPAIR), (5, 2, 2))

    def test_the_definition_draws_do_not_move_with_lkv(self):
        """The third group bit is a SUMCHECK variable, not a draw."""
        for slot in BILINEAR_SLOTS:
            self.assertEqual(self.k8.n_definition_challenges(slot),
                             self.k4.n_definition_challenges(slot))
        self.assertEqual(self.k8.n_definition_challenges(8), 4 + 5 + 5)
        self.assertEqual(self.k8.n_definition_challenges(9), 4 + 5 + 3)

    def test_both_factors_coordinate_schedules_written_out_at_lkv_3(self):
        dc = lambda i: ("dc", i)          # noqa: E731
        rho = lambda i: ("rho", i)        # noqa: E731
        qr, kr = self.k8.coordinate_schedule(8, REPAIRED)
        self.assertEqual(qr, [dc(4), dc(5), dc(6), dc(7), dc(8)]
                         + [rho(0), rho(1), rho(2)]
                         + [dc(3)]
                         + [rho(3), rho(4), rho(5)])
        self.assertEqual(kr, [dc(9), dc(10), dc(11), dc(12), dc(13)]
                         + [rho(0), rho(1), rho(2)]
                         + [rho(3), rho(4), rho(5)])
        pp, vv = self.k8.coordinate_schedule(9, REPAIRED)
        self.assertEqual(pp, [rho(0), rho(1), rho(2)] + [dc(3)]
                         + [dc(4), dc(5), dc(6), dc(7), dc(8)]
                         + [rho(3), rho(4), rho(5), rho(6), rho(7)])
        self.assertEqual(vv, [rho(3), rho(4), rho(5), rho(6), rho(7)]
                         + [rho(0), rho(1), rho(2)]
                         + [dc(9), dc(10), dc(11)])

    def test_every_group_bit_is_summed_in_both_factors(self):
        for slot in BILINEAR_SLOTS:
            pre = self.k8.coordinate_schedule(slot, PRE_REPAIR)
            rep = self.k8.coordinate_schedule(slot, REPAIRED)
            for b in range(3):
                self.assertTrue(all(("dc", b) in f for f in pre))
                self.assertTrue(all(("rho", b) in f for f in rep))
                self.assertFalse(any(("dc", b) in f for f in rep))

    def test_the_counts_the_gate_reports_are_predicted(self):
        """138 / 66 at rung-K4 -> 144 / 60 at rung-K8: per stage the two
        Kv-side factors gain a summed group coordinate and the two Q-side
        factors trade a fixed head coordinate for one."""
        def counts(geom):
            ent = fixed = 0
            for slot in BILINEAR_SLOTS:
                for f in geom.coordinate_schedule(slot, REPAIRED):
                    ent += len(f)
                    fixed += sum(1 for t in f if t[0] == "dc")
            return ent * 3, fixed * 3
        self.assertEqual(counts(self.k4), (138, 66))
        self.assertEqual(counts(self.k8), (144, 60))


class ThePinsRoundNineIRead(unittest.TestCase):
    """Each moved digest is accepted only with a written reading, and a
    digest nobody read is still refused -- a re-pin is not a weakening."""

    def test_the_stage_35_argument_digest_selects_the_repaired_definition(self):
        name, why = definition_of_pin(ARGUMENT_K8)
        self.assertEqual(name, REPAIRED)
        self.assertIn("SC_DZC", why)
        self.assertIn("SC_SZC", why)
        self.assertIn("byte-identical", why)
        # every earlier definition is still there, unchanged in kind
        self.assertEqual(
            {d[:12]: v[0] for d, v in ARGUMENT_DEFINITIONS.items()},
            {"909670c96562": PRE_REPAIR, "dd8469cb0279": REPAIRED,
             "ec3f97443245": REPAIRED, "f7fa2ad4213d": REPAIRED})

    def test_an_argument_digest_nobody_read_is_still_refused(self):
        self.assertEqual(definition_of_pin("0" * 64), (None, None))
        got = term.check_source_pins(_Manifest(
            {"src/private_block/argument.rs": "1" * 64,
             "src/private_block/layout.rs": term.PORTED_FROM[
                 "src/private_block/layout.rs"],
             "src/private_block/protocol.rs": PROTOCOL_K8,
             "src/private_block/plane_index.rs": term.PORTED_FROM[
                 "src/private_block/plane_index.rs"]}))
        self.assertFalse(got["ok"])
        self.assertTrue(any("argument.rs" in m for m in got["pins_that_moved"]))

    def test_the_stage_36_protocol_digest_is_a_read_second_value(self):
        table = term.ALSO_ACCEPTED["src/private_block/protocol.rs"]
        self.assertIn(PROTOCOL_K8, table)
        self.assertIn("check_opening_challenges", table[PROTOCOL_K8])
        self.assertIn("cargo test", table[PROTOCOL_K8])
        got = term.check_source_pins(_Manifest(
            {"src/private_block/argument.rs": ARGUMENT_K8,
             "src/private_block/layout.rs": term.PORTED_FROM[
                 "src/private_block/layout.rs"],
             "src/private_block/protocol.rs": "2" * 64,
             "src/private_block/plane_index.rs": term.PORTED_FROM[
                 "src/private_block/plane_index.rs"]}))
        self.assertFalse(got["ok"], "an unread protocol.rs must be refused")

    def test_the_mask_port_accepts_the_k8_argument_digest_with_a_reading(self):
        ent = rgm.MASK_LAYER_PINS["src/private_block/argument.rs"][ARGUMENT_K8]
        self.assertEqual(ent["commits"], (CAPTURE_COMMIT,))
        self.assertEqual(ent["bundles"], ("run-s-dense-k8", "run-t-zero-k8"))
        self.assertIn("N_FUNCTIONALS", ent["reading"])

    def test_the_shared_second_digests_are_read_and_a_third_is_not(self):
        base = {f: v["sha256"] for f, v in runpins.SHARED_LAYER_PINS.items()}
        honest = dict(base)
        honest["../zkp-core/src/rng.rs"] = RNG_K8
        honest["../zkp-core/src/transcript.rs"] = TRANSCRIPT_K8
        got = runpins.check_shared_pins(_Manifest(honest))
        self.assertTrue(got["ok"])
        self.assertEqual(got["pins_that_moved"], [])
        self.assertEqual(got["at_a_digest_this_gate_read"], 23)
        self.assertEqual(got["pins_at_an_accepted_second_digest"],
                         ["../zkp-core/src/rng.rs",
                          "../zkp-core/src/transcript.rs"])
        # round 8's bytes list is about round 8's bytes: the two are NOT in it
        self.assertNotIn("../zkp-core/src/rng.rs",
                         got["equal_to_the_bytes_round_8_read"])
        self.assertEqual(len(got["equal_to_the_bytes_round_8_read"]), 6)
        # a THIRD digest of either is still reported moved
        bad = dict(honest)
        bad["../zkp-core/src/rng.rs"] = "3" * 64
        got3 = runpins.check_shared_pins(_Manifest(bad))
        self.assertFalse(got3["ok"])
        self.assertTrue(any("rng.rs" in m for m in got3["pins_that_moved"]))

    def test_a_bundle_at_the_first_digests_gains_no_new_key(self):
        """A record of a bundle at round 8's bytes is leaf-for-leaf what it
        was: the second-digest keys appear only when one is in play."""
        base = {f: v["sha256"] for f, v in runpins.SHARED_LAYER_PINS.items()}
        got = runpins.check_shared_pins(_Manifest(base))
        self.assertNotIn("pins_at_an_accepted_second_digest", got)
        self.assertTrue(all("accepted_second_digest" not in e
                            for e in got["per_file"]))
        self.assertEqual(len(got["equal_to_the_bytes_round_8_read"]), 8)

    def test_the_run_layer_pins_name_the_k8_capture_commit(self):
        for path, digest in (
                ("src/private_block/run_capture.rs",
                 "d09f385315cac8e7b7fb16a65b0243219e4ba78c09af99b88a84782fe8082dd6"),
                ("src/private_block/run.rs",
                 "f39aec7925ba27d51361cd3935e874b1301d7595be81f3199d9d2941c0f818e0"),
                ("src/private_block/boundary.rs",
                 "5b1c85feefacf61fd97fa6e60b9f72d737f1dd56349ecaa650fc93d3ad0e6581")):
            ent = runpins.RUN_LAYER_PINS[path][digest]
            self.assertIn(CAPTURE_COMMIT, ent["commits"], path)
            self.assertIn("run-s-dense-k8", ent["bundles"], path)
            self.assertIn("run-t-zero-k8", ent["bundles"], path)


# =====================================================================
#  the GENERIC arm -- random field elements, several seeds
# =====================================================================
class TheGroupFactorAtThreeBits(unittest.TestCase):

    SEEDS = (1, 2, 3, 5, 8, 13, 21)

    def _r(self, rng):
        return (rng.randrange(P), rng.randrange(P))

    def test_eq_point_agrees_with_the_msb_first_table_at_n_3(self):
        for seed in self.SEEDS:
            rng = random.Random(seed)
            r = [self._r(rng) for _ in range(3)]
            tab = eq_table_msb(r)
            self.assertEqual(len(tab), 8)
            for i in range(8):
                pt = [F2_ONE if (i >> (2 - k)) & 1 else F2_ZERO
                      for k in range(3)]
                self.assertEqual(tab[i], eq_point(r, pt), f"seed {seed} {i}")

    def test_the_repaired_sum_picks_out_one_of_eight_groups(self):
        for seed in self.SEEDS:
            rng = random.Random(seed)
            r = [self._r(rng) for _ in range(3)]
            f = [self._r(rng) for _ in range(8)]
            lhs = F2_ZERO
            for e, v in zip(eq_table_msb(r), f):
                lhs = f2_add(lhs, f2_mul(e, v))
            rhs = F2_ZERO
            for i, v in enumerate(f):
                t = v
                for k in range(3):
                    t = f2_mul(t, r[k] if (i >> (2 - k)) & 1
                               else f2_sub(F2_ONE, r[k]))
                rhs = f2_add(rhs, t)
            self.assertEqual(lhs, rhs, f"seed {seed}")

    def test_every_coordinate_and_every_adjacent_swap_matters(self):
        """The value perturbations GQ-3 / GQ-4 make, and the two reorders
        GQ-7 and GQ-7.1.2 make, each change `eq(r_g, .)` at three bits."""
        for seed in self.SEEDS:
            rng = random.Random(seed)
            r = [self._r(rng) for _ in range(3)]
            base = eq_table_msb(r)
            for j in range(3):
                bad = list(r)
                bad[j] = f2_add(bad[j], F2_ONE)
                self.assertNotEqual(eq_table_msb(bad), base, f"{seed} {j}")
            for a, b in ((0, 1), (1, 2)):
                sw = list(r)
                sw[a], sw[b] = sw[b], sw[a]
                self.assertNotEqual(eq_table_msb(sw), base, f"{seed} {a}{b}")


# =====================================================================
#  the RECORDED arm
# =====================================================================
def _rec(name):
    with open(os.path.join(EVIDENCE, name + ".json")) as fh:
        return json.load(fh)


class TheRecordedFiguresAtRungK8(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        cls.s = _rec("run-s-dense-k8")
        cls.t = _rec("run-t-zero-k8")
        cls.both = (("run-s", cls.s), ("run-t", cls.t))

    def test_the_evidence_came_from_the_tool_bytes_now_in_the_tree(self):
        want = gate.tool_hashes()
        for name, rec in self.both:
            self.assertEqual(rec["tool_sha256"], want, name)

    def test_both_records_pass_every_stage_and_claim_no_privacy(self):
        for name, rec in self.both:
            self.assertTrue(rec["ok"], name)
            for k in [k for k in rec if k.startswith("stage")]:
                self.assertTrue(rec[k]["ok"], f"{name}: {k}")
            self.assertFalse(rec["privacy_property_established"], name)
            self.assertFalse(rec["privacy_acceptance"], name)
            self.assertFalse(rec["privacy_review_complete"], name)

    def test_the_profile_the_rule_and_the_pins(self):
        for name, rec in self.both:
            r = rec["stage2_transcript_replay"]
            self.assertEqual(r["profile"],
                             "hashline-zk-mr1/private-run-rung-k8-t24-dev/1")
            self.assertEqual(r["hash_rule"], "blake3-keyed/1")
            self.assertEqual(rec["hash_rule"]["block_profile"],
                             "hashline-zk-mr1/private-block-rung-k8-t24-dev/1")
            rl = rec["run_layer_source_pins"]
            self.assertTrue(rl["ok"], name)
            self.assertEqual(rl["pins_that_moved"], [], name)
            sf = rl["shared_files"]
            self.assertTrue(sf["ok"], name)
            self.assertEqual(sf["pins_at_an_accepted_second_digest"],
                             ["../zkp-core/src/rng.rs",
                              "../zkp-core/src/transcript.rs"])
            sp = rec["stage8_plane_index_and_terminals"]["terminal_identity"][
                "source_pins"]
            self.assertTrue(sp["ok"], name)
            self.assertEqual(sp["bilinear_definition_selected_by_the_argument_pin"],
                             REPAIRED)

    def test_the_geometry_and_the_group_counts(self):
        for name, rec in self.both:
            gf = rec["stage10_bilinear_group_factor"]["group_factor"]
            g = gf["geometry"]
            self.assertEqual(g["lkv = clog2(kv_heads)"], 3, name)
            self.assertEqual((g["lt = lg(t_pad)"], g["lh = lg(h_pad)"],
                              g["ldh = lg(head_dim)"]), (5, 4, 3), name)
            self.assertEqual((g["q_heads"], g["kv_heads"]), (16, 8), name)
            c = gf["counts"]
            self.assertEqual(c["group_points_derived_and_compared"], 6)
            self.assertEqual(c["group_point_entries_compared"], 18)
            self.assertEqual(c["coordinate_lists_rederived_and_compared"], 12)
            self.assertEqual(c["coordinate_entries_compared"], 144)
            self.assertEqual(
                c["fixed_coordinates_compared_with_a_rederived_challenge"], 60)
            self.assertEqual(gf["slots_with_a_derived_group_point"], 6)
            for row in gf["per_slot"]:
                self.assertEqual(row["derived_point_len"], 3)
                self.assertTrue(row["group_point_matches_the_rederived_r_g"])
                self.assertEqual(tuple(row["declared"]),
                                 (6, 2, 3) if row["slot"] == 8 else (8, 2, 3))

    def test_the_replay(self):
        for name, rec in self.both:
            r = rec["stage2_transcript_replay"]
            self.assertTrue(r["run_binding_reproduced"])
            self.assertEqual(r["positions_checked"], 375)
            self.assertEqual(r["challenges_checked"], 6926)
            self.assertEqual(r["final_counter"], 7758)
            self.assertEqual(r["not_rederived"], [])
            self.assertTrue(all(t["start_tag_ok"] and t["end_tag_ok"]
                                for t in r["segment_position_tags"]))

    def test_all_sixty_nine_slot_checks(self):
        for name, rec in self.both:
            t = rec["stage8_plane_index_and_terminals"]["terminal_identity"]
            self.assertEqual(t["slot_checks_expected"], 69, name)
            self.assertEqual(t["slot_checks_equal"], 69, name)
            self.assertEqual(
                t["slot_checks_matching_the_stored_terminal_polynomial"], 69)
            self.assertEqual(t["open_slots"], [])
            self.assertEqual(t["findings"], [])
            self.assertEqual(t["derived_group_points_used_and_compared"], 6)
            self.assertEqual(t["public_tables_rebuilt_and_digest_matched"], 16)
            self.assertEqual(t["public_tables_taken_from_the_capture"], 15)
            self.assertEqual(t["public_table_structure_checks"], 45)

    def test_disclosure_is_rung_k4_s_and_only_data_rows_grow(self):
        want = {"A": (246, 74, 0, 487, 733), "H": (108, 20, 2, 624, 732)}
        for name, rec in self.both:
            for pc in rec["stage3_per_commitment"]["per_commitment"]:
                kind = pc["role"][0]
                if kind in want:
                    nd, rk, disc, data, rows = want[kind]
                    self.assertEqual(
                        (pc["non_data_rows"], pc["rank_P1"],
                         pc["disclosed_dimension"], pc["data_rows"],
                         pc["rows"]), (nd, rk, disc, data, rows), pc["role"])
                else:
                    self.assertEqual(pc["disclosed_dimension"], 0, pc["role"])

    def test_the_boundary_and_the_whole_run(self):
        for name, rec in self.both:
            s4 = rec["stage4_the_boundary"]
            for b in s4["per_boundary"]:
                res = b["restricted_to_the_reserved_rows"]
                self.assertEqual((res["rows"], res["generators"],
                                  res["rank_on_the_reserved_block"],
                                  res["disclosed_on_the_reserved_block_fp"]),
                                 (10, 6, 6, 0))
                self.assertEqual(
                    b["three_roles_of_the_plane"]["generators"], 154)
            w = s4["whole_run"]
            self.assertEqual(w["generators"], 308)
            self.assertEqual((w["joint_fp"], w["sum_of_parts_fp"]), (6, 6))
            self.assertEqual(w["identified_rows"], 24)
            self.assertIn("ruling R-3", w["ruling_R3"])

    def test_the_hash_layer_the_arms_and_the_channels(self):
        for name, rec in self.both:
            h = rec["stage9_hash_layer"]
            self.assertEqual((h["openings"], h["columns_checked"],
                              h["columns_authenticated"], h["bytes_hashed"]),
                             (13, 3328, 3328, 9385984), name)
            s11 = rec["stage11_full_preimage"]
            self.assertTrue(s11["requested"])
            self.assertEqual(s11["view_entries_differing"], 0)
            self.assertEqual(s11["salted_leaves_authenticated"], 2560)
            s12 = rec["stage12_mask_and_cfs"]
            self.assertTrue(s12["requested"])
            self.assertEqual((s12["mask_rows"], s12["functional_count"],
                              s12["stages_checked"]), (50, 34, 3))
            self.assertEqual(s12["entries_recomputed"], 47967)
            self.assertEqual(s12["entries_differing"], 0)
            self.assertEqual(s12["salted_leaves_authenticated"], 768)
            s13 = rec["stage13_joint_run_preimage"]
            self.assertTrue(s13["all_four_couplings_respected"])
            self.assertEqual(s13["salted_leaves_authenticated"], 3328)
            self.assertEqual(
                s13["couplings"]["C1_shared_planes"]["identified_row_pairs"], 24)
            self.assertEqual(rec["stage7_channels"]["counts"],
                             {"constructed": 10, "derived": 5, "argued": 4,
                              "open": 9})
            self.assertEqual(rec["stage7_channels"]["total"], 28)

    def test_every_control_fires_and_the_group_family_has_eighteen(self):
        for name, rec in self.both:
            gc = rec["stage10_bilinear_group_factor"]["controls"]
            named = [c["control"] for c in gc["controls"]]
            self.assertEqual(
                set(named),
                {"GQ-1", "GQ-2", "GQ-5", "GQ-6", "GQ-7", "GQ-7.1.2"}
                | {f"GQ-{n}.{s:02d}.{c}" for n in (3, 4)
                   for s in (8, 9) for c in (0, 1, 2)}, name)
            self.assertEqual((gc["controls_total"], gc["controls_live"],
                              gc["controls_that_fire"]), (18, 18, 18), name)
            self.assertEqual(gc["controls_skipped"], [], name)
            gq6 = [c for c in gc["controls"] if c["control"] == "GQ-6"][0]
            self.assertEqual((gq6["the_repaired_definition_holds"],
                              gq6["the_pre_repair_definition_holds"]), (6, 0))
            ct = rec["stage8_plane_index_and_terminals"]["controls"]
            self.assertTrue(ct["ok"], name)
            self.assertEqual([c["control"] for c in ct["controls"]],
                             [f"CT-{i}" for i in range(1, 10)])
            self.assertTrue(all(c["fires"] for c in ct["controls"]), name)
            hc = rec["stage9_hash_layer"]["controls"]
            self.assertTrue(hc["ok"], name)
            ch7 = [c for c in hc["controls"] if c["control"] == "CH-7"][0]
            self.assertTrue(ch7["fires"], name)
            self.assertEqual((ch7["a_under_bs_keys"], ch7["b_under_as_keys"]),
                             (0, 0))
            self.assertTrue(rec["stage6_negative_controls"]["all_fire"], name)
            self.assertTrue(rec["stage11_full_preimage"]["controls"]["ok"])
            self.assertTrue(rec["stage12_mask_and_cfs"]["controls"]["all_fire"])

    def test_dense_against_zero_moves_only_sampled_column_counts(self):
        with open(os.path.join(
                EVIDENCE, "witness_comparison_k8_dense_vs_zero.json")) as fh:
            cmp_ = json.load(fh)
        self.assertGreater(cmp_["figures_identical"], 0)
        for row in cmp_["per_figure"]:
            if row["identical"]:
                continue
            self.assertTrue(
                row["figure"].startswith("distinct opened columns/")
                or row["figure"].startswith("pad margin/")
                or row["figure"].startswith("pad block/"),
                "a figure that is NOT a transcript-drawn column count moved "
                "with the witness: " + row["figure"])

    def test_the_comparison_against_rung_k4_has_nothing_unexplained(self):
        with open(os.path.join(EVIDENCE, "comparison_table_k8.json")) as fh:
            tab = json.load(fh)
        self.assertEqual(tab["unexplained"], [])
        self.assertEqual(tab["BROKEN_INVARIANTS"], [])
        self.assertEqual(tab["PREDICTIONS_THAT_MISSED"], [])
        self.assertTrue(tab["ok"])


# =====================================================================
#  the LIVE arm
# =====================================================================
@unittest.skipUnless(HAVE_K8, "the rung-K8 bundles are absent")
class TheLiveRungK8Bundle(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        from zk60_native_rg_bundle import RunBundle
        from zk60_native_rg_replay import RunReplay
        cls.b = RunBundle(RUN_S)
        cls.rp = RunReplay(cls.b).run()

    def test_the_bundle_pins_exactly_the_digests_this_round_read(self):
        pins = {p["file"]: p["sha256"]
                for p in self.b.manifest["source_pins"]}
        self.assertEqual(pins["src/private_block/argument.rs"], ARGUMENT_K8)
        self.assertEqual(pins["src/private_block/protocol.rs"], PROTOCOL_K8)
        self.assertEqual(pins["../zkp-core/src/rng.rs"], RNG_K8)
        self.assertEqual(pins["../zkp-core/src/transcript.rs"], TRANSCRIPT_K8)
        self.assertEqual(self.b.manifest["source_commit"], "99a8de8")

    def test_the_group_point_is_derived_at_three_coordinates(self):
        from zk60_native_rg_gqa import GroupFactors
        gf = GroupFactors(self.b, replay=self.rp)
        s = gf.summary()
        self.assertTrue(s["ok"], s["failures"] + s["refusals"])
        self.assertEqual(s["counts"]["group_point_entries_compared"], 18)
        for (stage, slot), pt in gf.points.items():
            dc = self.rp.stages[stage]["def_challenges"][slot]
            self.assertEqual(list(pt), list(dc[:3]))

    def test_the_prediction_reproduces_the_record(self):
        from zk60_native_rg_predict import predict, validate
        v = validate(predict, RUN_S,
                     os.path.join(EVIDENCE, "run-s-dense-k8.json"))
        self.assertTrue(v["ok"], v["mismatches"])


if __name__ == "__main__":
    unittest.main()
