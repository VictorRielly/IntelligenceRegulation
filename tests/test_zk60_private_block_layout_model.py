#!/usr/bin/env python3
"""ACCEPTANCE of the independent layout model `scripts/zk60_private_block_layout_model.py`.

The contract: the model reproduces the TOY shape's numbers EXACTLY — every one
the Rust asserts about itself — or it says nothing about any other shape.  Each
toy number below is the Rust's own, quoted with its source line; none of them
is imported from the crate, so a model that drifted would fail here.

The rung and 125M sections are NOT a check of the model against the memo: they
pin what the model computes and, where it differs from the memo's [COUNTED]
figures, they pin the difference and its diagnosed cause.  A difference is a
result.  Nothing in the model is tuned to remove one.
"""

import os
import sys
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "scripts"))

import zk60_private_block_layout_model as M  # noqa: E402


# The Rust's own declared slot table, `private_block/layout.rs:438-462`:
# (main rounds, extension rounds, degree), in transcript order.
RUST_SLOTS = [
    (9, 1, 3), (9, 1, 3), (5, 1, 3), (9, 1, 4), (11, 1, 3), (4, 1, 2), (4, 1, 2),
    (4, 1, 2), (3, 2, 2), (5, 2, 2), (4, 1, 2), (4, 1, 2), (4, 1, 2), (4, 1, 2),
    (9, 1, 4), (9, 1, 4), (8, 1, 4), (11, 1, 4), (9, 1, 4), (8, 1, 3), (8, 1, 2),
    (9, 1, 2), (9, 1, 2),
]
# `layout.rs:512-513`
RUST_A_SITES = [1, 1, 22, 2, 2, 1, 1, 1, 2, 2, 1, 1, 1, 1, 37, 8, 7, 13, 11, 3, 0, 1, 1]
RUST_H_SITES = [0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 19, 7, 6, 8, 6, 3, 1, 0, 0]
# the domain logs of `layout.rs:97-110` at the toy geometry
RUST_TOY_DOM_LOG = {"T": 5, "Ht": 6, "L": 9, "D": 9, "Q": 9, "Kv": 8, "S": 11, "F": 9, "Tab": 8}


def s20_slot_delta(sh):
    """The bytes the stage-20 repair of S19-F1 adds to a frame's slot line at
    `sh`, recomputed HERE from the shape's own axes so the test does not lean
    on the model's arithmetic: each bilinear slot gains `lkv` main rounds and
    (when `lkv > 0`) one degree, and a round message is `degree + 1` Fp2
    words of 16 B."""
    lkv = M.clog2(sh.kv_heads)
    if lkv == 0:
        return 0
    total = 0
    for old_main in (M.clog2(sh.head_dim), M.clog2(sh.t_pad)):
        ext = 2
        total += (old_main + lkv + ext) * 4 - (old_main + ext) * 3
    return 16 * total


class ToyReproduction(unittest.TestCase):
    """Only if the toy reproduces EXACTLY do the other shapes mean anything."""

    @classmethod
    def setUpClass(cls):
        cls.m = M.model(M.TOY)

    def test_every_number_the_rust_asserts_about_itself(self):
        m = self.m
        got = {
            "a_data_rows": m["rows"]["a_data_rows"], "a_rows": m["rows"]["a_rows"],
            "h_data_rows": m["rows"]["h_data_rows"], "h_rows": m["rows"]["h_rows"],
            "m_rows": m["rows"]["m_rows"], "a_sites": m["rows"]["a_sites"],
            "h_sites": m["rows"]["h_sites"], "a_groups": m["opening_groups"]["a_groups"],
            "h_groups": m["opening_groups"]["h_groups"], "n_slots": M.N_SLOTS,
            "functionals": M.N_FUNCTIONALS, "a_planes": m["a_planes"]["total"],
            "h_planes": m["h_planes"]["total"],
            "per_domain_u8": m["lookups"]["per_domain_u8_list"],
            "u8_total": m["lookups"]["u8_total"], "exp_pairs": m["lookups"]["exp_pairs"],
            "act_pairs": m["lookups"]["act_pairs"], "largest_L": m["slot_summary"]["largest_L"],
            "main_round_total": m["slot_summary"]["main_round_total"],
            "extension_round_total": m["slot_summary"]["extension_round_total"],
            "receipt_bytes": m["receipt_bytes"]["total"],
            "f_domain_a_planes": m["a_planes"]["by_domain"]["F"]["planes"],
            "f_domain_h_planes": m["h_planes"]["by_domain"]["F"]["planes"],
        }
        self.assertEqual(set(got), set(M.TOY_RUST_FACTS))
        for k, want in M.TOY_RUST_FACTS.items():
            with self.subTest(quantity=k):
                self.assertEqual(got[k], want)

    def test_the_toy_receipt_is_the_measured_2816472_bytes(self):
        self.assertEqual(self.m["receipt_bytes"]["total"], 2_816_472)

    def test_the_nine_domain_logs_are_the_rusts(self):
        for dom, log in RUST_TOY_DOM_LOG.items():
            with self.subTest(domain=dom):
                self.assertEqual(M.TOY.log(dom), log)
                self.assertEqual(M.TOY.natural_log(dom), log, "no lift applies at the toy")

    def test_the_slot_schedule_is_the_rusts_slot_for_slot(self):
        got = [(s["main_rounds"], s["extension_rounds"], s["degree"]) for s in self.m["slots"]]
        self.assertEqual(got, RUST_SLOTS)

    def test_the_claim_sites_are_the_rusts_slot_for_slot(self):
        self.assertEqual(self.m["claim_sites"]["a"], RUST_A_SITES)
        self.assertEqual(self.m["claim_sites"]["h"], RUST_H_SITES)

    def test_only_Dom_L_pads_at_the_toy_and_no_slot_carries_an_indicator(self):
        """Every toy AXIS is already a power of two (T 32, d 16, f 16, 2 heads),
        so seven of the nine shape-driven domains are exact. `Dom::L` is the
        exception and it pads TODAY: nine of its sixteen limb sub-planes carry
        the isqrt witness and seven are empty, which the memo notes ("its pad is
        not new: the toy already leaves seven of sixteen limb sub-planes empty,
        and the honest prover already writes zeros there", §2.3). `SC_LZC` takes
        no support indicator — it is homogeneous — so no slot's degree moves and
        the toy's schedule is the base one."""
        self.assertEqual(self.m["padded_domains"], ["L"])
        self.assertEqual((M.TOY.true_size("L"), M.TOY.size("L")), (288, 512))
        self.assertFalse(any(s["carries_support_indicator"] for s in self.m["slots"]))
        self.assertNotIn(M.SC_LZC, M.INDICATOR_SLOT_DOMAIN)

    def test_the_toy_needs_no_P3_lift_and_its_sum_claim_has_one_key(self):
        self.assertFalse(any(M.TOY.lifted(d) for d in M.ALL_DOMS))
        self.assertEqual(len(M.logup_sum_claim_keys(M.TOY, lift=False)), 1)


class Rung(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.m = M.model(M.RUNG)

    def test_the_counted_totals_of_section_9a(self):
        m = self.m
        self.assertEqual(m["a_planes"]["total"], 83)
        self.assertEqual(m["h_planes"]["total"], 52)
        self.assertEqual(m["rows"]["a_data_rows"], 377)
        self.assertEqual(m["rows"]["h_data_rows"], 470)
        self.assertEqual((m["rows"]["a_rows"], m["rows"]["h_rows"], m["rows"]["m_rows"]), (623, 576, 50))
        self.assertEqual((m["rows"]["a_sites"], m["rows"]["h_sites"]), (122, 52))
        self.assertEqual((m["opening_groups"]["a_groups"], m["opening_groups"]["h_groups"]), (36, 9))
        self.assertEqual(m["lookups"]["u8_total"], 419_840)
        self.assertEqual((m["lookups"]["exp_pairs"], m["lookups"]["act_pairs"]), (8_192, 8_192))
        self.assertEqual(m["slot_summary"]["largest_L"], 72)

    def test_every_one_of_the_nine_domains_pads(self):
        self.assertEqual(sorted(self.m["padded_domains"]), sorted(M.ALL_DOMS))

    def test_the_only_difference_against_the_memo_is_the_diagnosed_receipt_line(self):
        """**Stage 21, review finding F-1.** The delta was 176 B while the model
        still declared the PRE-repair bilinear schedule. The model now derives
        the repaired one itself (`group_sumcheck_bits`), so the rung's receipt
        is 336 B longer and the one diagnosed difference against the memo is
        176 + 336 = 512 B. The memo predates the repair."""
        diffs = M.compare_to_memo("rung", self.m)
        self.assertEqual([d["quantity"] for d in diffs], ["receipt_bytes"])
        self.assertEqual(diffs[0]["delta"], 512)
        self.assertEqual(self.m["receipt_bytes"]["total"], 4_173_544)
        self.assertNotIn("UNDIAGNOSED", diffs[0]["cause"])

    def test_the_512_bytes_are_SC_KVZCs_indicator_plus_the_S20_group_rounds(self):
        """The rung's Dom::Kv pads (768 of 1,024), so the model gives SC_KVZC
        the indicator and one more degree; that is 11 rounds x 1 Fp2 = 176 B.
        The two bilinear slots then carry the S19-F1 repair's group rounds and
        group `eq` degree: 336 B. Removing BOTH reproduces the memo's
        19,552-byte slot line exactly."""
        kvzc = self.m["slots"][M.SC_KVZC]
        self.assertTrue(self.m["domains"]["Kv"]["pads"])
        self.assertTrue(kvzc["carries_support_indicator"])
        rounds = kvzc["main_rounds"] + kvzc["extension_rounds"]
        self.assertEqual(rounds * 16, 176)
        self.assertEqual(self.m["receipt_bytes"]["slots"] - rounds * 16 - s20_slot_delta(M.RUNG), 19_552)
        self.assertEqual(s20_slot_delta(M.RUNG), 336)

    def test_the_bilinear_slots_carry_the_group_rounds_and_the_group_eq(self):
        """F-1: derived by the MODEL from `kv_heads`, not copied from Rust."""
        self.assertEqual(M.group_sumcheck_bits(M.RUNG), 1)
        score, pv = self.m["slots"][M.SC_SCORE], self.m["slots"][M.SC_PV]
        self.assertEqual((score["main_rounds"], score["extension_rounds"], score["degree"]), (5, 2, 3))
        self.assertEqual((pv["main_rounds"], pv["extension_rounds"], pv["degree"]), (6, 2, 3))
        self.assertEqual((score["L"], pv["L"]), (23, 26))
        self.assertTrue(score["carries_group_eq"] and pv["carries_group_eq"])
        self.assertEqual(self.m["slot_summary"]["main_round_total"], 217)
        self.assertEqual(self.m["slot_summary"]["published_round_values"], 1_055)
        self.assertEqual(self.m["slot_summary"]["sumcheck_challenge_draws"], 242)
        self.assertEqual(self.m["slot_summary"]["largest_L"], 72, "the worst slot is not a bilinear one")

    def test_the_lift_is_what_makes_the_sum_claim_instantiable(self):
        """B-3: without the P-3 lift the rung's H domains raise THREE distinct
        column-weight keys and `check_opening` refuses before any byte."""
        self.assertEqual(len(M.logup_sum_claim_keys(M.RUNG, lift=False)), 3)
        self.assertEqual(len(M.logup_sum_claim_keys(M.RUNG, lift=True)), 1)
        self.assertTrue(self.m["opening_groups"]["logup_sum_claim_instantiable"])


class M125(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.m = M.model(M.M125)

    def test_the_counted_totals_of_sections_2_and_7(self):
        m = self.m
        self.assertEqual((m["a_planes"]["total"], m["h_planes"]["total"]), (83, 50))
        self.assertEqual((m["rows"]["a_data_rows"], m["rows"]["h_data_rows"]), (5_435, 7_018))
        self.assertEqual((m["rows"]["a_rows"], m["rows"]["h_rows"], m["rows"]["m_rows"]), (5_681, 7_120, 50))
        self.assertEqual((m["rows"]["a_sites"], m["rows"]["h_sites"]), (122, 50))
        self.assertEqual((m["opening_groups"]["a_groups"], m["opening_groups"]["h_groups"]), (36, 9))
        self.assertEqual(m["lookups"]["u8_total"], 98_598_912)
        self.assertEqual(m["slot_summary"]["largest_L"], 117)
        self.assertLessEqual(m["slot_summary"]["worst_L_plus_256"], 512)

    def test_the_receipt_is_the_memos_final_figure_part_by_part(self):
        """Every part but the slot line is the memo's to the byte; the slot
        line carries the stage-20 repair (finding F-1), which the memo
        predates."""
        p = self.m["receipt_bytes"]
        self.assertEqual(p["a_opening"], 21_626_880)
        self.assertEqual(p["h_opening"], 17_385_472)
        self.assertEqual(p["endpoint_openings"], 1_466_368)
        self.assertEqual(p["mask_opening"], 243_712)
        self.assertEqual(p["header_and_three_roots"], 136)
        self.assertEqual(p["slots"], 28_016)
        self.assertEqual(p["total"], 40_750_584)

    def test_the_only_difference_against_the_memo_is_the_S20_slot_line(self):
        """**Stage 21, review finding F-1.** The model reproduced the memo to
        the byte while it declared the PRE-repair bilinear schedule. It now
        derives the repaired one, so it is 560 B longer — and that is the WHOLE
        difference: nothing else about the 125M layout moves."""
        diffs = M.compare_to_memo("m125", self.m)
        self.assertEqual([d["quantity"] for d in diffs], ["receipt_bytes"])
        self.assertEqual(diffs[0]["delta"], 560)
        self.assertEqual(s20_slot_delta(M.M125), 560)
        self.assertNotIn("UNDIAGNOSED", diffs[0]["cause"])

    def test_the_bilinear_slots_carry_two_group_bits_at_125M(self):
        self.assertEqual(M.group_sumcheck_bits(M.M125), 2)
        score, pv = self.m["slots"][M.SC_SCORE], self.m["slots"][M.SC_PV]
        self.assertEqual((score["main_rounds"], score["extension_rounds"], score["degree"]), (8, 2, 3))
        self.assertEqual((pv["main_rounds"], pv["extension_rounds"], pv["degree"]), (11, 2, 3))
        self.assertEqual((score["L"], pv["L"]), (32, 41))
        self.assertEqual(self.m["slot_summary"]["main_round_total"], 336)
        self.assertEqual(self.m["slot_summary"]["published_round_values"], 1_554)
        self.assertEqual(self.m["slot_summary"]["sumcheck_challenge_draws"], 361)
        self.assertLessEqual(max(score["L"], pv["L"]) + 256, 512)

    def test_the_lift_is_what_makes_the_sum_claim_instantiable(self):
        self.assertEqual(len(M.logup_sum_claim_keys(M.M125, lift=False)), 3)
        self.assertEqual(len(M.logup_sum_claim_keys(M.M125, lift=True)), 1)

    def test_Kv_and_F_do_not_pad_at_125M_so_their_zero_checks_carry_no_indicator(self):
        self.assertFalse(self.m["domains"]["Kv"]["pads"])
        self.assertFalse(self.m["domains"]["F"]["pads"])
        self.assertFalse(self.m["slots"][M.SC_KVZC]["carries_support_indicator"])
        self.assertFalse(self.m["slots"][M.SC_FZC]["carries_support_indicator"])


class RungG(unittest.TestCase):
    """**Stage 21.** The rung's geometry with the GENERALISED endpoint (S11b) —
    the profile every shaped proof, run and capture of this lane is actually
    taken at. It had no model of its own, so the Rust's 4,234,984-byte figure
    had no independent witness at all."""

    @classmethod
    def setUpClass(cls):
        cls.m = M.model(M.RUNG_G)
        cls.rung = M.model(M.RUNG)

    def test_only_the_endpoint_line_differs_from_the_frozen_seam_rung(self):
        a, b = self.m["receipt_bytes"], self.rung["receipt_bytes"]
        for part in ("header_and_three_roots", "slots", "mask_opening", "a_opening", "h_opening"):
            with self.subTest(part=part):
                self.assertEqual(a[part], b[part])
        self.assertNotEqual(a["endpoint_openings"], b["endpoint_openings"])
        self.assertEqual(a["endpoint_openings"], 335_872)
        self.assertEqual(a["total"], 4_234_984)

    def test_the_schedule_is_the_rungs_and_carries_the_group_rounds(self):
        self.assertEqual([(s["main_rounds"], s["extension_rounds"], s["degree"]) for s in self.m["slots"]],
                         [(s["main_rounds"], s["extension_rounds"], s["degree"]) for s in self.rung["slots"]])
        self.assertEqual(M.group_sumcheck_bits(M.RUNG_G), 1)
        self.assertEqual(self.m["slot_summary"]["main_round_total"], 217)
        self.assertEqual(self.m["slot_summary"]["published_round_values"], 1_055)
        self.assertEqual(self.m["slot_summary"]["sumcheck_challenge_draws"], 242)
        self.assertEqual(self.m["slot_summary"]["largest_L"], 72)

    def test_the_rows_and_groups_are_the_rungs(self):
        for key in ("a_data_rows", "h_data_rows", "a_rows", "h_rows", "a_sites", "h_sites", "m_rows"):
            with self.subTest(quantity=key):
                self.assertEqual(self.m["rows"][key], self.rung["rows"][key])
        self.assertEqual((self.m["opening_groups"]["a_groups"], self.m["opening_groups"]["h_groups"]), (36, 9))


class TheToyPaysNothing(unittest.TestCase):
    """**Stage 21, review finding F-1.** The repaired model must leave the
    BYTE-FROZEN toy profile alone, which is the whole reason the repair is
    expressed as `lkv = log2(kv_heads)` and not as a flag."""

    def test_the_toy_has_no_group_bits_and_no_group_eq(self):
        self.assertEqual(M.TOY.kv_heads, 1)
        self.assertEqual(M.group_sumcheck_bits(M.TOY), 0)
        self.assertEqual(s20_slot_delta(M.TOY), 0)
        m = M.model(M.TOY)
        self.assertFalse(any(s["carries_group_eq"] for s in m["slots"]))
        self.assertEqual(m["receipt_bytes"]["total"], 2_816_472)

    def test_the_repair_is_a_pure_function_of_kv_heads(self):
        """One key-value head: nothing moves. More: exactly the two bilinear
        slots move, and nothing else in the schedule does."""
        for sh in (M.TOY, M.RUNG, M.RUNG_G, M.M125):
            with self.subTest(shape=sh.name):
                moved = [s["slot"] for s in M.slots(sh) if s["carries_group_eq"]]
                self.assertEqual(moved, [] if sh.kv_heads == 1 else [M.SC_SCORE, M.SC_PV])


class PadTable(unittest.TestCase):
    """What §3.7a's table ACTUALLY contains, counted from its own rows."""

    @classmethod
    def setUpClass(cls):
        cls.r = M.pad_table_recount()

    def test_the_real_tally(self):
        r = self.r
        self.assertEqual(r["planes_classified_total"], 100)
        self.assertEqual(r["by_rule"]["ZERO"], 64)
        self.assertEqual(r["by_rule"]["EXEMPT"], 35)
        self.assertEqual(r["by_rule"]["NO PAD RULE"], 1)
        self.assertEqual(sum(r["by_rule"].values()), r["planes_classified_total"])

    def test_the_summary_figures_each_count_a_different_population(self):
        """62 / 61 / 35 do not add up because they are not one tally: 62 and 61
        are A planes only, 35 spans both commitments."""
        r = self.r
        self.assertEqual(r["a_planes_on_padded_domains"], 62)
        self.assertEqual(r["by_commitment"]["A"]["ZERO"], 61)
        self.assertEqual(r["by_commitment"]["A"]["EXEMPT"], 1)     # A_E, the exponential pair
        self.assertEqual(r["by_commitment"]["H"]["EXEMPT"], 34)    # the lookup reciprocals
        self.assertEqual(r["by_commitment"]["H"]["ZERO"], 3)       # the three table helpers
        self.assertEqual(r["h_planes_on_padded_domains"], 38)
        self.assertNotEqual(61 + 35, 62)

    def test_the_table_covers_exactly_the_planes_the_model_puts_on_padded_domains(self):
        """'Planes not classified here: none.' — checked against the model's own
        125M plane list, domain by domain, for both commitments."""
        m125 = M.model(M.M125)
        padded = set(m125["padded_domains"])
        want_a, want_h = {}, {}
        for dom, _ in M.a_planes(M.M125):
            if dom in padded:
                want_a[dom] = want_a.get(dom, 0) + 1
        for dom, _ in M.h_planes(M.M125):
            if dom in padded:
                want_h[dom] = want_h.get(dom, 0) + 1
        got_a, got_h = {}, {}
        for dom, cm, _e, count, _rule in M.PAD_TABLE_ROWS:
            (got_a if cm == "A" else got_h)[dom] = (got_a if cm == "A" else got_h).get(dom, 0) + count
        self.assertEqual(got_a, want_a)
        self.assertEqual(got_h, want_h)


class Rules(unittest.TestCase):
    def test_padding_and_logs(self):
        self.assertEqual([M.npot(v) for v in (1, 2, 3, 24, 96, 192, 512, 768, 2048)],
                         [1, 2, 4, 32, 128, 256, 512, 1024, 2048])
        self.assertEqual([M.clog2(v) for v in (1, 2, 3, 24, 1024)], [0, 1, 2, 5, 10])

    def test_the_two_integer_windows_are_derived_not_assumed(self):
        """NORM_WRHO and WRHO_S come from the shape: the toy's 29/14, the
        rung's 31/17 and 125M's 32/18 are all computed, and the two limb counts
        follow (`ZK60_PRIVATE_BLOCK_125M_LAYOUT.md` §3.3, §3.4, §9a)."""
        self.assertEqual((M.TOY.norm_wrho, M.TOY.wrho_s), (29, 14))
        self.assertEqual((M.RUNG.norm_wrho, M.RUNG.wrho_s), (31, 17))
        self.assertEqual((M.M125.norm_wrho, M.M125.wrho_s), (32, 18))
        self.assertEqual([s.limbs_sigma_s for s in (M.TOY, M.RUNG, M.M125)], [2, 3, 3])
        # only at 125M does the norm window fill its top byte, which is what
        # drops the FOUR redundant `scaled` lookups (C-6)
        self.assertEqual([s.norm_top_is_full_byte for s in (M.TOY, M.RUNG, M.M125)],
                         [False, False, True])
        self.assertEqual([M.lookup_counts(s)["D"] for s in (M.TOY, M.RUNG, M.M125)], [38, 38, 34])
        self.assertEqual([M.helpers(s)["D"] for s in (M.TOY, M.RUNG, M.M125)], [19, 19, 17])
        self.assertEqual([M.lookup_counts(s)["S"] for s in (M.TOY, M.RUNG, M.M125)], [13, 15, 15])

    def test_the_Q_D_coincidence_holds_at_all_three_shapes(self):
        """`d_pad = H_pad * d_h`, which the Wo matmul depends on (§2.3)."""
        for s in (M.TOY, M.RUNG, M.M125):
            with self.subTest(shape=s.name):
                self.assertEqual(s.d_pad, s.h_pad * s.head_dim)

    def test_the_mask_budget_holds_at_all_three_shapes(self):
        for name, s in M.SHAPES.items():
            with self.subTest(shape=name):
                self.assertTrue(all(x["L"] + 256 <= 512 for x in M.slots(s)))

    def test_M_is_shape_independent(self):
        for name, s in M.SHAPES.items():
            with self.subTest(shape=name):
                self.assertEqual(M.model(s)["rows"]["m_rows"], 50)
                self.assertEqual(M.model(s)["receipt_bytes"]["mask_opening"], 243_712)


if __name__ == "__main__":
    unittest.main()
