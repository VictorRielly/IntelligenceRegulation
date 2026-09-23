"""Tests for round 5: TWO key-value group bits (the rung-K4 development
shape) and the controls re-aimed at the third and fourth group.

Run:
  python3 -m unittest discover -s tests \
      -p "test_zk60_native_run_gate_k4.py"

WHY THERE IS A ROUND 5.  Every group figure this gate has ever reported
was taken at `kv_heads = 2`, i.e. ONE key-value group bit, where the
repaired bilinear slots' public factor `eq(r_g, .)` carries a one-element
point and the sum over groups has two terms.  The port CLAIMS to be
shape-driven.  Rung-K4 -- 24 tokens, width 96, hidden 192, 12 query heads
of 8 over 4 key-value heads, padded head slots {3, 7, 11, 15}, which is
the 125M model's own head geometry -- is the first shape that tests the
claim, and it differs from rung-G in more than `lkv`: `lh` goes 3 -> 4
and `ldh` goes 4 -> 3, so a port that had quietly assumed six heads or a
sixteen-wide head would fail here too.

FOUR ARMS.

* A PURE arm that needs no bundle: the K4 geometry derived from the shape
  alone, both bilinear slots' dimensions and definition draws, both
  private factors' coordinate schedules written out AT TWO GROUP BITS,
  and the scaling laws the two shapes must obey relative to each other.
* A GENERIC arm: the algebraic pieces the two-group case newly exercises
  -- `eq_point` over two variables against the msb-first `eq` table, and
  the identity that makes the repair a repair (summing the group factor
  against a multilinear extension picks out that group's value) -- on
  RANDOM field elements over several seeds, never on the shaped
  instances, so the port is not tested only where it is used.
* The RECORDED arm, which always runs: every figure the report quotes,
  asserted from the tracked evidence under
  `results/zk60_native_run_gate_k4/`, including that the evidence was
  produced by the tool bytes now in the tree.
* The LIVE arm, skipped when the ~46 MB bundles are absent: the group
  point derived at two coordinates and compared, each coordinate
  perturbed on both sides, the two coordinates swapped, and the
  cross-profile key control on real captured columns.

Nothing here asserts a privacy property.  A capture carries no witness,
so no test here can say what was proved -- only that the verifier's view
is self-consistent at the run's real challenges.
"""

from __future__ import annotations

import json
import os
import random
import sys
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "scripts"))

EVIDENCE = os.path.join(ROOT, "results", "zk60_native_run_gate_k4")
BUNDLES = os.environ.get(
    "ZK60_RUN_BUNDLES",
    "/home/victor/wt-zk60-block125m/results/zk60_run_captures_20260920",
)
RUN_I = os.path.join(BUNDLES, "run-i-dense-k4")
RUN_J = os.path.join(BUNDLES, "run-j-zero-k4")
RUN_G = os.path.join(BUNDLES, "run-g-dense-s20")
HAVE_K4 = os.path.isdir(RUN_I) and os.path.isdir(RUN_J)
HAVE_G = os.path.isdir(RUN_G)

import zk60_native_run_gate as gate  # noqa: E402
from zk60_native_jv_field import (  # noqa: E402
    F2_ONE,
    F2_ZERO,
    P,
    eq_table_msb,
    f2_add,
    f2_mul,
    f2_sub,
)
from zk60_native_rg_bundle import RunBundle  # noqa: E402
from zk60_native_rg_gcontrols import group_controls  # noqa: E402
from zk60_native_rg_gqa import (  # noqa: E402
    BILINEAR_SLOTS,
    PRE_REPAIR,
    REPAIRED,
    GroupFactors,
    Geometry,
    clog2,
    eq_point,
)
from zk60_native_rg_hashrule import HashRule  # noqa: E402
from zk60_native_rg_hcontrols import cross_profile_key_control  # noqa: E402
from zk60_native_rg_planes import plane_index_of  # noqa: E402
from zk60_native_rg_replay import RunReplay  # noqa: E402
from zk60_native_rg_terminals import (  # noqa: E402
    PINNED_IF_PRESENT,
    check_terminals,
)

# the two shapes, written out so the pure arm needs no file
RUNG_G_SHAPE = {"tokens": 24, "width": 96, "hidden": 192, "q_heads": 6,
                "kv_heads": 2, "head_dim": 16, "t_pad": 32, "h_pad": 8}
RUNG_K4_SHAPE = {"tokens": 24, "width": 96, "hidden": 192, "q_heads": 12,
                 "kv_heads": 4, "head_dim": 8, "t_pad": 32, "h_pad": 16}

K4_SHAPE_DIGEST = (
    "07a0547f06602bc27cbad1658a7cc0079f2ac1158d2bb372e24096e930e6a7fd")


# =====================================================================
#  the PURE arm
# =====================================================================
class TheK4GeometryIsDerived(unittest.TestCase):
    """Everything about rung-K4 that the shape alone decides."""

    def setUp(self):
        self.g = Geometry(RUNG_G_SHAPE)
        self.k = Geometry(RUNG_K4_SHAPE)

    def test_two_group_bits_at_rung_k4_and_one_at_rung_g(self):
        self.assertEqual(self.k.lkv, 2)
        self.assertEqual(self.g.lkv, 1)
        self.assertEqual(clog2(4), 2)
        self.assertEqual(clog2(3), 2, "clog2 is a CEILING log, not a floor")
        self.assertEqual(clog2(1), 0)

    def test_the_head_axis_moves_in_three_ways_not_one(self):
        """If anything in the port had assumed six heads or a sixteen-wide
        head rather than reading the shape, this is where it would show."""
        self.assertEqual((self.g.lh, self.g.ldh), (3, 4))
        self.assertEqual((self.k.lh, self.k.ldh), (4, 3))
        self.assertEqual(self.g.lt, self.k.lt, "the token axis does NOT move")

    def test_the_padded_head_slots_are_the_125m_geometry(self):
        """12 query heads of 8 over 4 key-value heads with `h_pad = 16`
        puts ONE padded slot at the end of each group's own block --
        {3, 7, 11, 15} -- which a contiguous padded tail can never
        produce.  `head_slot` is the port's own, read from the shape."""
        import zk60_native_rg_terminals as term
        geom = term.PadGeometry(dict(RUNG_K4_SHAPE, d_pad=128, f_pad=256),
                                {})
        live = {geom.head_slot(h) for h in range(RUNG_K4_SHAPE["q_heads"])}
        self.assertEqual(sorted(set(range(16)) - live), [3, 7, 11, 15])
        # rung-G's padded slots are a contiguous TAIL, which is the case
        # that could hide an off-by-one in the group arithmetic
        gg = term.PadGeometry(dict(RUNG_G_SHAPE, d_pad=128, f_pad=256), {})
        liveg = {gg.head_slot(h) for h in range(RUNG_G_SHAPE["q_heads"])}
        self.assertEqual(sorted(set(range(8)) - liveg), [3, 7])

    def test_the_bilinear_slot_dimensions_at_two_group_bits(self):
        self.assertEqual(self.k.dims(8, REPAIRED), (5, 2, 3))
        self.assertEqual(self.k.dims(9, REPAIRED), (7, 2, 3))
        # the pre-repair arm loses lkv main rounds and one degree
        self.assertEqual(self.k.dims(8, PRE_REPAIR), (3, 2, 2))
        self.assertEqual(self.k.dims(9, PRE_REPAIR), (5, 2, 2))
        for slot in BILINEAR_SLOTS:
            rep = self.k.dims(slot, REPAIRED)
            pre = self.k.dims(slot, PRE_REPAIR)
            self.assertEqual(rep[0] - pre[0], self.k.lkv)
            self.assertEqual(rep[2] - pre[2], 1)

    def test_the_definition_draws_at_both_shapes(self):
        # SC_SCORE draws r_h, r_t, r_j; SC_PV draws r_h, r_t, r_i
        self.assertEqual(self.k.n_definition_challenges(8), 4 + 5 + 5)
        self.assertEqual(self.k.n_definition_challenges(9), 4 + 5 + 3)
        self.assertEqual(self.g.n_definition_challenges(8), 3 + 5 + 5)
        self.assertEqual(self.g.n_definition_challenges(9), 3 + 5 + 4)

    def test_both_factors_coordinate_schedules_written_out_at_lkv_2(self):
        """The whole point of the repair, at two group bits: the SAME two
        summed variables `rho(0)` and `rho(1)` appear in BOTH factors, and
        the within-group head bits stay FIXED."""
        qr, kr = self.k.coordinate_schedule(8, REPAIRED)
        dc = lambda i: ("dc", i)          # noqa: E731
        rho = lambda i: ("rho", i)        # noqa: E731
        # A_QR8 on Dom::Q = (t, head slot, c); head slot = (g, r_hj)
        self.assertEqual(qr, [dc(4), dc(5), dc(6), dc(7), dc(8)]
                         + [rho(0), rho(1)]
                         + [dc(2), dc(3)]
                         + [rho(2), rho(3), rho(4)])
        # A_KR8 on Dom::Kv = (j, group, c): the SAME summed group
        self.assertEqual(kr, [dc(9), dc(10), dc(11), dc(12), dc(13)]
                         + [rho(0), rho(1)]
                         + [rho(2), rho(3), rho(4)])
        pp, vv = self.k.coordinate_schedule(9, REPAIRED)
        self.assertEqual(pp, [rho(0), rho(1)] + [dc(2), dc(3)]
                         + [dc(4), dc(5), dc(6), dc(7), dc(8)]
                         + [rho(2), rho(3), rho(4), rho(5), rho(6)])
        self.assertEqual(vv, [rho(2), rho(3), rho(4), rho(5), rho(6)]
                         + [rho(0), rho(1)]
                         + [dc(9), dc(10), dc(11)])

    def test_the_group_bits_are_summed_in_both_factors_at_lkv_2(self):
        """The property finding S19-F1 names: BEFORE the repair the group
        bits are FIXED coordinates of both factors; AFTER it they are the
        same SUMMED variables.  Round 4 checked this at one bit; at two
        bits it has to hold for each of them."""
        for slot in BILINEAR_SLOTS:
            pre = self.k.coordinate_schedule(slot, PRE_REPAIR)
            rep = self.k.coordinate_schedule(slot, REPAIRED)
            for b in range(self.k.lkv):
                self.assertTrue(all(("dc", b) in f for f in pre),
                                f"slot {slot}: group bit {b} is not fixed in "
                                "both pre-repair factors")
                self.assertTrue(all(("rho", b) in f for f in rep),
                                f"slot {slot}: group bit {b} is not summed in "
                                "both repaired factors")
                self.assertFalse(any(("dc", b) in f for f in rep))

    def test_the_lengths_scale_exactly_as_the_two_shapes_predict(self):
        """The coordinate-entry counts the gate reports, derived here from
        the two geometries alone, so the measured 135 -> 138 and 69 -> 66
        are predictions and not observations."""
        def counts(geom):
            ent = fixed = 0
            for slot in BILINEAR_SLOTS:
                for f in geom.coordinate_schedule(slot, REPAIRED):
                    ent += len(f)
                    fixed += sum(1 for t in f if t[0] == "dc")
            return ent * 3, fixed * 3          # three stages
        self.assertEqual(counts(self.g), (135, 69))
        self.assertEqual(counts(self.k), (138, 66))

    def test_the_shape_digest_of_rung_k4_is_a_read_second_value(self):
        """`shape.rs` moved for the K4 bundles, and the port accepts the
        new digest only because it is in `PINNED_IF_PRESENT` with a written
        reason.  A digest with no reason is a refusal."""
        table = PINNED_IF_PRESENT["src/private_block/shape.rs"]
        self.assertIn(K4_SHAPE_DIGEST, table)
        self.assertIn("rung_k4", table[K4_SHAPE_DIGEST])
        self.assertNotIn("de" + "adbeef" * 8, table)


# =====================================================================
#  the GENERIC arm -- random field elements, several seeds
# =====================================================================
class TheGroupFactorOnGenericInstances(unittest.TestCase):
    """The algebra the two-group case newly exercises, on RANDOM points.

    A port that is only ever run on the shaped instance is not tested, so
    these use uniformly drawn `Fp2` elements over several seeds and never
    the bundles' own values.
    """

    SEEDS = (1, 2, 3, 5, 8, 13, 21)

    def _rand_f2(self, rng):
        return (rng.randrange(P), rng.randrange(P))

    def test_eq_point_agrees_with_the_msb_first_table_at_every_arity(self):
        """`eq(r, .)` built as a TABLE over 2^n points and evaluated
        point-by-point must agree entry for entry.  The gate builds the
        table; the identity checks the evaluation.  n = 2 is the new case
        and n = 1 is round 4's, so both are covered."""
        for seed in self.SEEDS:
            rng = random.Random(seed)
            for n in (1, 2, 3):
                r = [self._rand_f2(rng) for _ in range(n)]
                tab = eq_table_msb(r)
                self.assertEqual(len(tab), 1 << n)
                for i in range(1 << n):
                    bits = [((i >> (n - 1 - k)) & 1) for k in range(n)]
                    pt = [F2_ONE if b else F2_ZERO for b in bits]
                    self.assertEqual(
                        tab[i], eq_point(r, pt),
                        f"seed {seed}, n {n}, index {i}",
                    )

    def test_the_group_factor_sums_to_one_over_the_boolean_cube(self):
        """`sum over g in {0,1}^n of eq(r, g) == 1` for every `r`: the
        property that makes `eq(r_g, .)` a selector and the repaired sum a
        sum over key-value groups rather than a rescaling of it."""
        for seed in self.SEEDS:
            rng = random.Random(seed)
            for n in (1, 2, 3):
                r = [self._rand_f2(rng) for _ in range(n)]
                acc = F2_ZERO
                for v in eq_table_msb(r):
                    acc = f2_add(acc, v)
                self.assertEqual(acc, F2_ONE, f"seed {seed}, n {n}")

    def test_the_repaired_sum_picks_out_one_group(self):
        """The identity the repair rests on, stated generically: for any
        table `f` over the group cube,

            sum_g eq(r, g) * f(g)  ==  fhat(r)

        where `fhat` is `f`'s multilinear extension.  At n = 1 a product
        that shares the variable happens to agree with this for a CONSTANT
        `f`, which is exactly why the defect was invisible on a degenerate
        witness; at n = 2 with a non-constant `f` it does not, and this
        test states both halves."""
        for seed in self.SEEDS:
            rng = random.Random(seed)
            for n in (1, 2):
                r = [self._rand_f2(rng) for _ in range(n)]
                f = [self._rand_f2(rng) for _ in range(1 << n)]
                eq = eq_table_msb(r)
                lhs = F2_ZERO
                for e, v in zip(eq, f):
                    lhs = f2_add(lhs, f2_mul(e, v))
                # the multilinear extension of f at r, built independently
                rhs = F2_ZERO
                for i, v in enumerate(f):
                    term = v
                    for k in range(n):
                        b = (i >> (n - 1 - k)) & 1
                        term = f2_mul(term, r[k] if b
                                      else f2_sub(F2_ONE, r[k]))
                    rhs = f2_add(rhs, term)
                self.assertEqual(lhs, rhs, f"seed {seed}, n {n}")
                # a CONSTANT f: the sum is that constant whatever r is,
                # which is the degeneracy the defect hid behind
                c = self._rand_f2(rng)
                acc = F2_ZERO
                for e in eq:
                    acc = f2_add(acc, f2_mul(e, c))
                self.assertEqual(acc, c)

    def test_a_perturbed_group_coordinate_changes_the_factor(self):
        """Every coordinate of `r_g` matters, one at a time: flipping any
        single entry by +1 changes `eq(r_g, g)` for at least one `g`.  At
        lkv = 2 that has to be true of the SECOND coordinate too, which is
        the one no control before round 5 could reach."""
        for seed in self.SEEDS:
            rng = random.Random(seed)
            n = 2
            r = [self._rand_f2(rng) for _ in range(n)]
            base = eq_table_msb(r)
            for j in range(n):
                bad = list(r)
                bad[j] = f2_add(bad[j], F2_ONE)
                self.assertNotEqual(eq_table_msb(bad), base,
                                    f"seed {seed}, coordinate {j}")
            # and the SWAP, which only exists at n >= 2
            self.assertNotEqual(eq_table_msb([r[1], r[0]]), base,
                                f"seed {seed}: the swapped point")


# =====================================================================
#  the RECORDED arm
# =====================================================================
def _rec(name):
    with open(os.path.join(EVIDENCE, name + ".json")) as fh:
        return json.load(fh)


class TheRecordedFigures(unittest.TestCase):
    """Every figure round 5's report quotes, from the tracked evidence."""

    @classmethod
    def setUpClass(cls):
        cls.i = _rec("run-i-dense-k4")
        cls.j = _rec("run-j-zero-k4")

    def test_the_evidence_was_produced_by_the_tools_now_in_the_tree(self):
        want = gate.tool_hashes()
        for name, rec in (("run-i", self.i), ("run-j", self.j)):
            self.assertEqual(rec["tool_sha256"], want, name)

    def test_both_bundles_pass_every_stage_and_claim_no_privacy(self):
        for name, rec in (("run-i", self.i), ("run-j", self.j)):
            self.assertTrue(rec["ok"], name)
            self.assertFalse(rec["privacy_property_established"], name)
            self.assertFalse(rec["privacy_acceptance"], name)
            self.assertFalse(rec["privacy_review_complete"], name)

    def test_the_profile_and_the_keyed_rule_are_the_k4_ones(self):
        for rec in (self.i, self.j):
            self.assertEqual(
                rec["stage2_transcript_replay"]["profile"],
                "hashline-zk-mr1/private-run-rung-k4-t24-dev/1")
            self.assertEqual(
                rec["stage2_transcript_replay"]["hash_rule"], "blake3-keyed/1")
            self.assertEqual(
                rec["hash_rule"]["block_profile"],
                "hashline-zk-mr1/private-block-rung-k4-t24-dev/1")

    def test_the_geometry_of_record(self):
        for rec in (self.i, self.j):
            g = rec["stage10_bilinear_group_factor"]["group_factor"]["geometry"]
            self.assertEqual(g["lkv = clog2(kv_heads)"], 2)
            self.assertEqual(g["lh = lg(h_pad)"], 4)
            self.assertEqual(g["ldh = lg(head_dim)"], 3)
            self.assertEqual(g["lt = lg(t_pad)"], 5)
            self.assertEqual((g["q_heads"], g["kv_heads"]), (12, 4))

    def test_the_group_counts_of_record_double_with_lkv(self):
        for rec in (self.i, self.j):
            c = rec["stage10_bilinear_group_factor"]["group_factor"]["counts"]
            self.assertEqual(c["slots_examined"], 6)
            self.assertEqual(c["group_points_derived_and_compared"], 6)
            self.assertEqual(c["group_point_entries_compared"], 12)
            self.assertEqual(c["coordinate_lists_rederived_and_compared"], 12)
            self.assertEqual(c["coordinate_entries_compared"], 138)
            self.assertEqual(
                c["fixed_coordinates_compared_with_a_rederived_challenge"], 66)

    def test_the_replay_of_record(self):
        for rec in (self.i, self.j):
            r = rec["stage2_transcript_replay"]
            self.assertTrue(r["run_binding_reproduced"])
            self.assertEqual(r["positions_checked"], 375)
            self.assertEqual(r["challenges_checked"], 6854)
            self.assertEqual(r["final_counter"], 7686)
            self.assertEqual(r["not_rederived"], [])
            self.assertEqual(len(r["segment_position_tags"]), 3)
            self.assertTrue(all(t["start_tag_ok"] and t["end_tag_ok"]
                                for t in r["segment_position_tags"]))

    def test_the_twenty_three_slots_of_record(self):
        for rec in (self.i, self.j):
            t = rec["stage8_plane_index_and_terminals"]["terminal_identity"]
            self.assertEqual(t["slot_checks_attempted"], 69)
            self.assertEqual(t["slot_checks_equal"], 69)
            self.assertEqual(t["slot_checks_expected"], 69)
            self.assertEqual(
                t["slot_checks_matching_the_stored_terminal_polynomial"], 69)
            self.assertEqual(t["open_slots"], [])
            self.assertEqual(t["derived_group_points_used_and_compared"], 6)
            self.assertEqual(t["public_tables_rebuilt_and_digest_matched"], 16)
            self.assertEqual(t["public_table_structure_checks"], 45)

    def test_the_disclosure_and_rank_figures_are_rung_gs(self):
        """The headline: the blinding structure does not move with the head
        cut.  Only the DATA rows grow."""
        want = {"A": (246, 74, 0, 481, 727), "H": (108, 20, 2, 612, 720)}
        for rec in (self.i, self.j):
            for pc in rec["stage3_per_commitment"]["per_commitment"]:
                kind = pc["role"][0]
                if kind in want:
                    nd, rk, disc, data, rows = want[kind]
                    self.assertEqual(pc["non_data_rows"], nd, pc["role"])
                    self.assertEqual(pc["rank_P1"], rk, pc["role"])
                    self.assertEqual(pc["disclosed_dimension"], disc, pc["role"])
                    self.assertEqual(pc["data_rows"], data, pc["role"])
                    self.assertEqual(pc["rows"], rows, pc["role"])
                else:
                    self.assertEqual(pc["disclosed_dimension"], 0, pc["role"])

    def test_the_boundary_and_the_whole_run(self):
        for rec in (self.i, self.j):
            s4 = rec["stage4_the_boundary"]
            for b in s4["per_boundary"]:
                res = b["restricted_to_the_reserved_rows"]
                self.assertEqual(res["rows"], 10)
                self.assertEqual(res["generators"], 6)
                self.assertEqual(res["rank_on_the_reserved_block"], 6)
                self.assertEqual(res["disclosed_on_the_reserved_block_fp"], 0)
                self.assertEqual(
                    b["three_roles_of_the_plane"]["generators"], 154)
            w = s4["whole_run"]
            self.assertEqual(w["generators"], 308)
            self.assertEqual(w["matrix"], "308 x 4505")
            self.assertEqual(w["joint_fp"], 6)
            self.assertEqual(w["sum_of_parts_fp"], 6)
            self.assertTrue(w["joint_equals_sum_of_parts"])
            self.assertIn("ruling R-3", w["ruling_R3"])

    def test_the_hash_layer_and_the_channel_count(self):
        for rec in (self.i, self.j):
            h = rec["stage9_hash_layer"]
            self.assertEqual(h["hash_rule"], "blake3-keyed/1")
            self.assertEqual(h["openings"], 13)
            self.assertEqual(h["columns_checked"], 3328)
            self.assertEqual(h["columns_authenticated"], 3328)
            self.assertEqual(h["bytes_hashed"], 9275392)
            chans = rec["stage7_channels"]["channels"]
            # [ROUND 8] 25 -> 28, the three added entries OPEN with both
            # arms off.
            self.assertEqual(len(chans), 28)
            by = {}
            for c in chans:
                by[c["status"]] = by.get(c["status"], 0) + 1
            # [ROUND 9j, DELIBERATE] status page row 26: the boundary scale
            # channel OPEN -> ARGUED on D12b(3) / ruling R-5 (built, lane stage
            # 21), so argued +1 and open -1; no figure moved
            self.assertEqual(by, {"constructed": 2, "derived": 5,
                                  "argued": 5, "open": 16})

    def test_every_control_of_record_fires(self):
        for name, rec in (("run-i", self.i), ("run-j", self.j)):
            gc = rec["stage10_bilinear_group_factor"]["controls"]
            self.assertEqual(gc["controls_total"], 13, name)
            self.assertEqual(gc["controls_live"], 13, name)
            self.assertEqual(gc["controls_that_fire"], 13, name)
            self.assertEqual(gc["controls_skipped"], [], name)
            named = {c["control"] for c in gc["controls"]}
            self.assertEqual(
                named,
                {"GQ-1", "GQ-2", "GQ-5", "GQ-6", "GQ-7"}
                | {f"GQ-{n}.{s:02d}.{c}" for n in (3, 4)
                   for s in (8, 9) for c in (0, 1)},
                name)
            hc = rec["stage9_hash_layer"]["controls"]
            self.assertTrue(hc["ok"], name)
            self.assertEqual({c["control"] for c in hc["controls"]},
                             {f"CH-{i}" for i in range(1, 8)}, name)
            ch7 = [c for c in hc["controls"] if c["control"] == "CH-7"][0]
            self.assertTrue(ch7["fires"], name)
            self.assertEqual(ch7["a_under_bs_keys"], 0)
            self.assertEqual(ch7["b_under_as_keys"], 0)
            self.assertEqual(ch7["a_under_its_own_keys"], ch7["of_columns_a"])
            self.assertEqual(ch7["b_under_its_own_keys"], ch7["of_columns_b"])
            self.assertTrue(all(ch7["the_two_key_sets_differ_in_every_role"]
                                .values()))

    def test_the_dense_against_zero_comparison_of_record(self):
        with open(os.path.join(
                EVIDENCE, "witness_comparison_k4_dense_vs_zero.json")) as fh:
            cmp_ = json.load(fh)
        self.assertEqual(cmp_["figures_compared"], 173)
        self.assertEqual(cmp_["figures_identical"], 153)
        for row in cmp_["per_figure"]:
            if row["identical"]:
                continue
            self.assertTrue(
                row["figure"].startswith("distinct opened columns/")
                or row["figure"].startswith("pad margin/")
                or row["figure"].startswith("pad block/"),
                "a figure that is NOT a transcript-drawn column count moved "
                "with the witness: " + row["figure"],
            )

    def test_the_shape_comparison_of_record(self):
        with open(os.path.join(
                EVIDENCE, "shape_comparison_k4_vs_rungg.json")) as fh:
            cmp_ = json.load(fh)
        self.assertEqual(cmp_["figures_compared"], 173)
        self.assertEqual(cmp_["figures_identical"], 134)
        moved = {r["figure"] for r in cmp_["per_figure"]
                 if not r["identical"]}
        # every figure that MUST be invariant across the two shapes
        for fig in ("disclosed dimension/0:A", "disclosed dimension/0:H",
                    "rank_P1/0:A", "rank_P1/0:H",
                    "whole run/joint (Fp)", "whole run/sum of the parts (Fp)",
                    "terminal identity/slot checks equal",
                    "channels/open"):
            if any(r["figure"] == fig for r in cmp_["per_figure"]):
                self.assertNotIn(fig, moved, fig + " moved with the shape")
        # and the ones that MUST move
        self.assertIn("group factor/lkv", moved)
        self.assertIn("group factor/group_point_entries_compared", moved)

    def test_the_eight_older_records_were_refreshed_without_a_figure_moving(self):
        with open(os.path.join(
                EVIDENCE, "old", "old_bundles_unchanged.json")) as fh:
            old = json.load(fh)
        self.assertTrue(old["no_measured_figure_moved"])
        self.assertEqual(len(old["per_bundle"]), 8)
        for row in old["per_bundle"]:
            self.assertEqual(row.get("unclassified", []), [], row["bundle"])


# =====================================================================
#  the LIVE arm
# =====================================================================
@unittest.skipUnless(HAVE_K4, "the rung-K4 bundles are not on this box")
class TheLiveK4Bundle(unittest.TestCase):
    """The group factor, the controls and the cross-profile keys, on the
    real bundles."""

    @classmethod
    def setUpClass(cls):
        cls.b = RunBundle(RUN_I)
        cls.replay = RunReplay(cls.b).run()
        cls.index, _ = plane_index_of(cls.b)

    def test_the_group_point_is_two_entries_and_is_derived_not_read(self):
        g = GroupFactors(self.b, replay=self.replay)
        s = g.summary()
        self.assertTrue(s["ok"], s["failures"][:2])
        self.assertEqual(s["definition_in_force"], REPAIRED)
        self.assertEqual(s["slots_with_a_derived_group_point"], 6)
        self.assertIn("transcript replay", s["group_point_derived_from"])
        for stage in range(self.b.blocks):
            for slot in BILINEAR_SLOTS:
                self.assertEqual(len(g.point(stage, slot)), 2)

    def test_each_group_coordinate_is_compared_on_both_sides(self):
        """The two halves of the derive-and-compare rule, once per group
        coordinate.  Entry 1 is the one that only exists at lkv = 2."""
        for entry in (0, 1):
            bad = GroupFactors(self.b, replay=self.replay,
                               perturb_derived_point=(0, 8),
                               perturb_derived_entry=entry)
            s = bad.summary()
            self.assertFalse(s["ok"], f"entry {entry}")
            self.assertTrue(any("not r_g" in f for f in s["failures"]))
            self.assertIsNone(bad.point(0, 8))
            # and the other five slot instances are untouched
            self.assertEqual(s["slots_with_a_derived_group_point"], 5)

    def test_a_coordinate_out_of_range_is_refused_rather_than_ignored(self):
        with self.assertRaises(ValueError):
            GroupFactors(self.b, replay=self.replay,
                         perturb_derived_point=(0, 8),
                         perturb_derived_entry=2)

    def test_all_thirteen_group_controls_fire_live(self):
        out = group_controls(self.b, self.index, replay=self.replay)
        self.assertTrue(out["ok"], out.get("skipped"))
        self.assertEqual(out["controls_live"], 13)
        self.assertEqual(out["controls_that_fire"], 13)

    def test_the_terminal_identity_holds_on_the_live_bundle(self):
        got = check_terminals(self.b, self.index, replay=self.replay)
        self.assertTrue(got["ok"], got["findings"][:2])
        self.assertEqual(got["slot_checks_equal"], 69)

    @unittest.skipUnless(HAVE_G, "the rung-G bundle is not on this box")
    def test_the_two_profiles_keys_do_not_authenticate_each_others_columns(self):
        other = RunBundle(RUN_G)
        out = cross_profile_key_control(self.b, other)
        self.assertTrue(out["fires"], out)
        self.assertEqual(out["a_under_bs_keys"], 0)
        self.assertEqual(out["b_under_as_keys"], 0)
        self.assertGreater(out["a_under_its_own_keys"], 0)

    @unittest.skipUnless(HAVE_G, "the rung-G bundle is not on this box")
    def test_the_two_profiles_derive_four_different_keys(self):
        a = HashRule.for_profile(self.b.run["shape"]["profile"])
        b = HashRule.for_profile(
            RunBundle(RUN_G).run["shape"]["profile"])
        self.assertFalse(a.is_legacy)
        self.assertFalse(b.is_legacy)
        for role in a.keys:
            self.assertNotEqual(a.keys[role], b.keys[role], role)

    def test_a_same_profile_pair_is_named_and_skipped_not_passed(self):
        out = cross_profile_key_control(self.b, RunBundle(RUN_J))
        self.assertIn("skipped", out)
        self.assertFalse(out["fires"])

    # ---------------------------------------------------- finding K4-F1
    def test_a_moved_source_pin_is_reported_and_does_not_crash_the_gate(self):
        """**Finding K4-F1.**  Until round 5 the moved-pin arm of
        `check_terminals` returned a dict without `slot_checks_expected`,
        so stage 8 and the terminal controls died with a `KeyError` and
        the gate printed a traceback instead of the refusal it had
        correctly computed.  No bundle had ever moved a pin, so the
        refusal path had never been exercised end to end; the rung-K4
        bundles moved two.  A refusal path that crashes is not a refusal
        path."""
        import copy as _copy
        from zk60_native_rg_tcontrols import terminal_controls
        keep = self.b.manifest
        try:
            bad = _copy.deepcopy(keep)
            for p in bad["source_pins"]:
                if p["file"].endswith("shape.rs"):
                    p["sha256"] = "00" * 32
            self.b.manifest = bad
            got = check_terminals(self.b, self.index, replay=self.replay)
            self.assertFalse(got["ok"])
            self.assertFalse(got["source_pins"]["ok"])
            self.assertTrue(any("shape.rs" in m
                                for m in got["source_pins"]["pins_that_moved"]))
            # every key a caller reads is present, and the counts are zero
            for key in ("slot_checks_expected", "slot_checks_attempted",
                        "slot_checks_equal", "per_stage", "findings",
                        "derived_group_points_used_and_compared",
                        "rebuilt_public_tables", "captured_public_tables",
                        "public_table_structure_detail",
                        "bilinear_group_factor"):
                self.assertIn(key, got, key)
            self.assertEqual(got["slot_checks_attempted"], 0)
            self.assertEqual(got["slot_checks_expected"], 69)
            self.assertIn("absence of a check",
                          got["refused_before_any_slot_was_evaluated"])
            # and the controls that read it do not raise
            ctl = terminal_controls(self.b, self.index, replay=self.replay)
            self.assertFalse(ctl.get("ok", False))
        finally:
            self.b.manifest = keep


if __name__ == "__main__":
    unittest.main()
