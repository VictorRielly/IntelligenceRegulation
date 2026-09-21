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
        is 336 B longer: 176 + 336 = 512 B of slot line. The memo predates the
        repair.

        **Stage 23, the shaped check's finding B-12.** The model also DERIVES
        the endpoint now, instead of declaring the memo's 14 rows at inverse
        rate 4 — a pricing of the TRUE `(24, 96)` plane that `SeamSpec::new`
        refuses outright. The frozen seam carries the PADDED `(32, 128)` plane
        at exactly its 4,096-word ceiling: 16 data rows, 21 commitment rows,
        the seam's frozen inverse rate 8, and 45,056 B more than the memo
        priced. So the one diagnosed difference is 512 + 45,056 = 45,568 B,
        and the model's total is the RUST's to the byte with no correction
        term in between."""
        diffs = M.compare_to_memo("rung", self.m)
        self.assertEqual([d["quantity"] for d in diffs], ["receipt_bytes"])
        self.assertEqual(diffs[0]["delta"], 45_568)
        self.assertEqual(self.m["receipt_bytes"]["total"], 4_218_600)
        self.assertNotIn("UNDIAGNOSED", diffs[0]["cause"])

    def test_the_frozen_seam_endpoint_is_derived_and_is_the_rusts(self):
        """**Stage 23, finding B-12.** Nothing about the rung's endpoint is
        declared any more: the seam is SELECTED by the same derivation
        `Shape::new` uses (a plane within the 4,096-word ceiling, at the
        seam's frozen 8 / 8), and the rows come from the plane and
        `ENDPOINT_MASK_ROWS`."""
        s = self.m["shape"]
        self.assertEqual(s["endpoint_words"], 32 * 128)
        self.assertEqual(s["endpoint_words"], M.SEAM_MAX_WORDS)
        self.assertFalse(s["endpoint_general"], "the rung must ride the FROZEN seam")
        self.assertEqual((s["endpoint_log_n"], s["endpoint_inv_rate"]), (M.SEAM_LOG_COLS, M.SEAM_INV_RATE))
        self.assertEqual(s["endpoint_data_rows"], 16)
        self.assertEqual(s["endpoint_rows"], 16 + M.ENDPOINT_MASK_ROWS)
        self.assertEqual(s["endpoint_rows"], 21)
        self.assertEqual(self.m["receipt_bytes"]["endpoint_openings"], 319_488)

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
        """Every part but the slot line and the endpoint line is the memo's to
        the byte. The slot line carries the stage-20 repair (finding F-1),
        which the memo predates; the endpoint line carries the DERIVED
        geometry of stage 23 (finding B-12), which the memo mispriced."""
        p = self.m["receipt_bytes"]
        self.assertEqual(p["a_opening"], 21_626_880)
        self.assertEqual(p["h_opening"], 17_385_472)
        self.assertEqual(p["endpoint_openings"], 1_499_136)
        self.assertEqual(p["mask_opening"], 243_712)
        self.assertEqual(p["header_and_three_roots"], 136)
        self.assertEqual(p["slots"], 28_016)
        self.assertEqual(p["total"], 40_783_352)

    def test_the_generalised_endpoint_is_derived_and_is_the_rusts(self):
        """**Stage 23, finding B-12.** What an endpoint commits is the PADDED
        `Dom::D` cube — 512 * 1024 = 2^19 words, which IS a power of two, so
        no `mu`-batched multi-block claim is needed (finding S11b-F1) — and
        at `endpoint_log_n = 14` that is 32 data rows and 37 commitment rows.
        The memo's 29 priced the TRUE 393,216-word plane."""
        s = self.m["shape"]
        self.assertEqual(s["endpoint_words"], 512 * 1024)
        self.assertGreater(s["endpoint_words"], M.SEAM_MAX_WORDS)
        self.assertTrue(s["endpoint_general"], "the frozen seam cannot carry this plane")
        self.assertEqual((s["endpoint_log_n"], s["endpoint_inv_rate"]), (14, 4))
        self.assertEqual(s["endpoint_data_rows"], 32)
        self.assertEqual(s["endpoint_rows"], 32 + M.ENDPOINT_MASK_ROWS)
        self.assertEqual(s["endpoint_rows"], 37)

    def test_the_only_difference_against_the_memo_is_the_S20_slot_line(self):
        """**Stage 21, review finding F-1.** The model reproduced the memo to
        the byte while it declared the PRE-repair bilinear schedule. It now
        derives the repaired one, so it is 560 B longer.

        **Stage 23, finding B-12.** It also derives the endpoint, which is
        32,768 B more than the memo's 29-row pricing. 560 + 32,768 = 33,328,
        and that is the WHOLE difference: nothing else about the 125M layout
        moves, and the model's total is now the Rust's to the byte with no
        correction term in between."""
        diffs = M.compare_to_memo("m125", self.m)
        self.assertEqual([d["quantity"] for d in diffs], ["receipt_bytes"])
        self.assertEqual(diffs[0]["delta"], 33_328)
        self.assertEqual(s20_slot_delta(M.M125), 560)
        self.assertEqual(diffs[0]["delta"] - s20_slot_delta(M.M125), 32_768)
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


class RungK4(unittest.TestCase):
    """**Lane stage 22.** rung-G's geometry with the heads recut as 12 query
    heads of 8 over FOUR key-value heads, so ``log2(kv_heads) = 2``: the
    smallest shape at which the repaired bilinear slots sum over more than
    ONE group bit and still produce a receipt a tool can read.  The model is
    the independent oracle for the Rust's ``MODEL_RUNG_K4``."""

    @classmethod
    def setUpClass(cls):
        cls.m = M.model(M.RUNG_K4)
        cls.g = M.model(M.RUNG_G)

    def test_the_geometry(self):
        sh = M.RUNG_K4
        self.assertEqual((sh.tokens, sh.width, sh.hidden), (24, 96, 192))
        self.assertEqual((sh.q_heads, sh.head_dim, sh.kv_heads), (12, 8, 4))
        self.assertEqual((sh.t_pad, sh.d_pad, sh.h_pad, sh.f_pad), (32, 128, 16, 256))
        self.assertEqual(sh.d_pad, sh.h_pad * sh.head_dim)
        self.assertEqual(M.group_sumcheck_bits(M.RUNG_K4), 2)
        # the three domains the bilinear coordinate lists are written at must
        # NOT be lifted by P-3 (the Rust refuses such a shape by name), and
        # Dom::Kv sits exactly AT the row width, which is not a lift
        for dom in ("Q", "Kv", "S"):
            with self.subTest(domain=dom):
                self.assertFalse(sh.lifted(dom))
        self.assertEqual((sh.log("Q"), sh.log("Kv"), sh.log("S")), (12, 10, 14))

    def test_two_group_bits_move_exactly_the_two_bilinear_slots(self):
        s = self.m["slots"]
        self.assertEqual((s[M.SC_SCORE]["main_rounds"], s[M.SC_SCORE]["extension_rounds"], s[M.SC_SCORE]["degree"]), (5, 2, 3))
        self.assertEqual((s[M.SC_PV]["main_rounds"], s[M.SC_PV]["extension_rounds"], s[M.SC_PV]["degree"]), (7, 2, 3))
        self.assertEqual((s[M.SC_SCORE]["L"], s[M.SC_PV]["L"]), (23, 29))
        self.assertEqual([x["slot"] for x in s if x["carries_group_eq"]], [M.SC_SCORE, M.SC_PV])

    def test_the_summary_figures(self):
        ss = self.m["slot_summary"]
        self.assertEqual(ss["main_round_total"], 220)
        self.assertEqual(ss["extension_round_total"], 25)
        self.assertEqual(ss["published_round_values"], 1_070)
        self.assertEqual(ss["sumcheck_challenge_draws"], 245)
        self.assertEqual(ss["largest_L"], 77)
        self.assertTrue(ss["L_plus_256_within_512"])

    def test_the_rows_groups_and_receipt(self):
        r, g = self.m["rows"], self.g["rows"]
        self.assertEqual((r["a_data_rows"], r["h_data_rows"], r["a_rows"], r["h_rows"]), (481, 614, 727, 720))
        self.assertEqual((r["a_sites"], r["h_sites"], r["m_rows"]), (122, 52, 50))
        self.assertEqual((self.m["opening_groups"]["a_groups"], self.m["opening_groups"]["h_groups"]), (36, 9))
        self.assertEqual(self.m["lookups"]["u8_total"], 542_720)
        self.assertEqual((self.m["lookups"]["exp_pairs"], self.m["lookups"]["act_pairs"]), (16_384, 8_192))
        self.assertEqual(self.m["receipt_bytes"]["total"], 4_743_128)
        # the ONE axis that grows is the head axis, and it shows up as Dom::S
        self.assertEqual(self.m["domains"]["S"]["padded"], 2 * self.g["domains"]["S"]["padded"])
        self.assertGreater(r["a_data_rows"], g["a_data_rows"])
        # the endpoint is priced exactly as rung-G's: same padded Dom::D
        # cube, same row width, same rate, so the SAME openings
        self.assertEqual(self.m["receipt_bytes"]["endpoint_openings"], self.g["receipt_bytes"]["endpoint_openings"])


class TheFullTopByteShape(unittest.TestCase):
    """**LANE STAGE 31 — correction C-6, reached by a small shape.**

    `norm_top_is_full_byte` is true when the norm window `NORM_TN + 1 +
    bit_length(D_max)` is a multiple of eight, and `D_max = isqrt(1 + width *
    32767^2)`, so the flag is a function of the WIDTH alone: it turns on the
    moment the width passes 256.  Until this stage the only shape with it on
    was 125M.

    The model is the independent oracle for the difference: `rung_c6` is
    `rung_p2` with the head dimension moved from 8 to 32 and the two axes
    that must follow it, so EVERY lookup family is rung-P2's except
    `Dom::D`, which loses exactly the four `scaled` norm lookups and the two
    helper planes that carried them."""

    @classmethod
    def setUpClass(cls):
        cls.m = M.model(M.RUNG_C6)
        cls.p = M.model(M.RUNG_P2)

    def test_the_geometry(self):
        sh = M.RUNG_C6
        self.assertEqual((sh.tokens, sh.width, sh.hidden), (32, 384, 512))
        self.assertEqual((sh.q_heads, sh.head_dim, sh.kv_heads), (12, 32, 4))
        self.assertEqual((sh.t_pad, sh.d_pad, sh.h_pad, sh.f_pad), (32, 512, 16, 512))
        self.assertEqual(sh.d_pad, sh.h_pad * sh.head_dim)
        self.assertEqual(sh.width, sh.q_heads * sh.head_dim)
        self.assertEqual(M.group_sumcheck_bits(M.RUNG_C6), 2)
        # the bilinear domains are not P-3 lifted (the Rust refuses that by
        # name, ruling F-2), and the table domain sits AT the row width
        # (ruling S-1)
        for dom in ("Q", "Kv", "S"):
            with self.subTest(domain=dom):
                self.assertFalse(sh.lifted(dom))
        self.assertEqual((sh.log("Q"), sh.log("Kv"), sh.log("S")), (14, 12, 14))
        self.assertEqual(sh.log("Tab"), sh.log_cols)
        self.assertLess(sh.head_dim, 1 << sh.log_cols)

    def test_the_width_is_what_turns_the_flag_on(self):
        """The threshold, walked: at this head axis the width is `12 *
        head_dim`, and the window crosses from 31 to 32 bits between 256 and
        257.  8 and 16 are the two head dimensions the filter already has,
        and neither reaches it; 32 is the smallest that does."""
        self.assertTrue(M.RUNG_C6.norm_top_is_full_byte)
        for head_dim, width, wrho, flag in ((8, 96, 31, False), (16, 192, 31, False),
                                            (32, 384, 32, True), (64, 768, 32, True)):
            with self.subTest(head_dim=head_dim):
                s = M.Shape("probe", tokens=32, width=width, hidden=512, q_heads=12,
                            head_dim=head_dim, kv_heads=4, log_cols=10, inv_rate=4, f_e=12)
                self.assertEqual(s.width, 12 * head_dim)
                self.assertEqual(s.norm_wrho, wrho)
                self.assertEqual(s.norm_top_is_full_byte, flag)
        # the exact boundary, on the window arithmetic alone
        for width, wrho in ((256, 31), (257, 32), (1024, 32), (1025, 33)):
            with self.subTest(width=width):
                s = M.Shape("probe", tokens=32, width=width, hidden=512, q_heads=12,
                            head_dim=32, kv_heads=4, log_cols=10, inv_rate=4, f_e=12)
                self.assertEqual(s.norm_wrho, wrho)

    def test_C6_drops_four_lookups_and_two_helpers_and_nothing_else(self):
        """THE EXPLICIT DIFFERENCE the stage exists to pin, against
        `rung_p2` — the shape whose byte-limb counts (`ln` 4, `ls` 3, `lp` 2)
        are identical, so the only thing that can move a lookup count is
        C-6 itself."""
        c6, p2 = M.RUNG_C6, M.RUNG_P2
        self.assertEqual((c6.limbs_norm, c6.limbs_sigma_s, c6.limbs_p),
                         (p2.limbs_norm, p2.limbs_sigma_s, p2.limbs_p))
        self.assertEqual((p2.norm_top_is_full_byte, c6.norm_top_is_full_byte), (False, True))
        lk_c6, lk_p2 = M.lookup_counts(c6), M.lookup_counts(p2)
        hp_c6, hp_p2 = M.helpers(c6), M.helpers(p2)
        self.assertEqual({d: lk_p2[d] - lk_c6[d] for d in M.LOOKUP_DOMS},
                         {"L": 0, "D": 4, "F": 0, "Q": 0, "Kv": 0, "S": 0})
        self.assertEqual({d: hp_p2[d] - hp_c6[d] for d in M.LOOKUP_DOMS},
                         {"L": 0, "D": 2, "F": 0, "Q": 0, "Kv": 0, "S": 0})
        self.assertEqual((lk_p2["D"], lk_c6["D"]), (38, 34))
        self.assertEqual((hp_p2["D"], hp_c6["D"]), (19, 17))
        # the four dropped lookups are the ONLY difference in the H plane
        # list, and the A plane list does not move at all (the limbs are
        # still committed; it is the lookups ON the top limb that go)
        self.assertEqual((len(M.a_planes(p2)), len(M.a_planes(c6))), (83, 83))
        self.assertEqual((len(M.h_planes(p2)), len(M.h_planes(c6))), (52, 50))
        self.assertEqual(self.p["rows"]["h_sites"] - self.m["rows"]["h_sites"], 2)
        # and the dropped lookup's coefficient is 1 — `scaled(top, 1)` IS
        # `byte(top)`, which is why dropping it takes no obligation away
        self.assertEqual(1 << (8 * c6.limbs_norm - c6.norm_wrho), 1)
        self.assertEqual(1 << (8 * p2.limbs_norm - p2.norm_wrho), 2)

    def test_it_also_keeps_the_three_unpadded_domains(self):
        sh = M.RUNG_C6
        unpadded = [d for d in M.ALL_DOMS if sh.size(d) == sh.true_size(d)]
        self.assertEqual(unpadded, ["T", "Kv", "F"])
        self.assertEqual(unpadded, [d for d in M.ALL_DOMS
                                    if M.M125.size(d) == M.M125.true_size(d)])
        self.assertEqual(M.padded_domains(sh), M.padded_domains(M.M125))

    def test_the_rows_groups_and_receipt(self):
        r = self.m["rows"]
        self.assertEqual((r["a_data_rows"], r["h_data_rows"], r["a_rows"], r["h_rows"]),
                         (1091, 1306, 1337, 1408))
        self.assertEqual((r["a_sites"], r["h_sites"], r["m_rows"]), (122, 50, 50))
        self.assertEqual((self.m["opening_groups"]["a_groups"],
                          self.m["opening_groups"]["h_groups"]), (36, 9))
        self.assertEqual(self.m["lookups"]["u8_total"], 1_214_464)
        self.assertEqual(self.m["receipt_bytes"]["total"], 7_452_040)
        self.assertEqual(self.m["slot_summary"]["largest_L"], 77)
        self.assertTrue(self.m["slot_summary"]["L_plus_256_within_512"])
        # the unpadded arm, unchanged from stage 30: slots 16 and 18 carry no
        # support indicator and are a degree below the all-padded pattern
        carriers = [s["slot"] for s in self.m["slots"] if s["carries_support_indicator"]]
        self.assertNotIn(M.SC_KVZC, carriers)
        self.assertNotIn(M.SC_FZC, carriers)
        self.assertEqual((self.m["slots"][M.SC_KVZC]["degree"],
                          self.m["slots"][M.SC_FZC]["degree"]), (4, 4))


class TheRowWidthShape(unittest.TestCase):
    """**LANE STAGE 32 — the 125M ROW WIDTH, HEAD SIZE and ENDPOINT LOG,
    reached by a small shape.**

    `rung_w14` is 125M's head axis — twelve query heads of 64 over four
    key-value heads, so width 768 — at the smallest token count the row
    width admits.  The model is the independent oracle for what that buys:
    which of 125M's numbers this shape SHARES (everything that is a
    function of the head axis, the row geometry or the calibration windows)
    and which it does not (everything that is a function of the token
    count)."""

    @classmethod
    def setUpClass(cls):
        cls.w = M.model(M.RUNG_W14)
        cls.m = M.model(M.M125)

    def test_the_geometry(self):
        sh = M.RUNG_W14
        self.assertEqual((sh.tokens, sh.width, sh.hidden), (64, 768, 1024))
        self.assertEqual((sh.q_heads, sh.head_dim, sh.kv_heads), (12, 64, 4))
        self.assertEqual((sh.t_pad, sh.d_pad, sh.h_pad, sh.f_pad), (64, 1024, 16, 1024))
        self.assertEqual(sh.d_pad, sh.h_pad * sh.head_dim)
        self.assertEqual(sh.width, sh.q_heads * sh.head_dim)
        self.assertEqual(M.group_sumcheck_bits(sh), 2)
        self.assertEqual((sh.log_cols, sh.inv_rate, sh.opened_cols), (14, 4, 256))
        # the bilinear domains are not P-3 lifted (ruling F-2) and the table
        # domain sits AT the row width (ruling S-1)
        for dom in ("Q", "Kv", "S"):
            with self.subTest(domain=dom):
                self.assertFalse(sh.lifted(dom))
        self.assertEqual((sh.log("Q"), sh.log("Kv"), sh.log("S")), (16, 14, 16))
        self.assertEqual(sh.log("Tab"), sh.log_cols)
        self.assertLess(sh.head_dim, 1 << sh.log_cols)

    def test_F2_is_what_forces_sixty_four_tokens(self):
        """`Dom::Kv = tokens * kv_heads * head_dim = 256 * tokens` must reach
        the row width 2^14, or the P-3 lift makes the bilinear slots
        unserveable (the Rust refuses such a shape BY NAME).  So the token
        count cannot go below 64, and at 64 the domain sits exactly at the
        row width."""
        for tokens, lifted in ((16, True), (32, True), (64, False), (128, False)):
            with self.subTest(tokens=tokens):
                s = M.Shape("probe", tokens=tokens, width=768, hidden=1024, q_heads=12,
                            head_dim=64, kv_heads=4, log_cols=14, inv_rate=4, f_e=12)
                self.assertEqual(s.true_size("Kv"), 256 * tokens)
                self.assertEqual(s.lifted("Kv"), lifted)
        self.assertEqual(M.RUNG_W14.size("Kv"), 1 << 14)

    def test_what_it_shares_with_125M_exactly(self):
        """Every quantity that is a function of the head axis, the row
        geometry or the calibration windows — and NOT of the token count."""
        w, m = M.RUNG_W14, M.M125
        self.assertEqual((w.q_heads, w.head_dim, w.kv_heads), (m.q_heads, m.head_dim, m.kv_heads))
        self.assertEqual((w.width, w.d_pad, w.h_pad), (m.width, m.d_pad, m.h_pad))
        self.assertEqual((w.log_cols, w.inv_rate, w.opened_cols), (m.log_cols, m.inv_rate, m.opened_cols))
        self.assertEqual((w.d_max, w.norm_wrho, w.limbs_norm), (m.d_max, m.norm_wrho, m.limbs_norm))
        self.assertEqual((w.wrho_s, w.limbs_sigma_s, w.limbs_p), (m.wrho_s, m.limbs_sigma_s, m.limbs_p))
        self.assertEqual(w.norm_top_is_full_byte, m.norm_top_is_full_byte)
        self.assertEqual(M.lookup_counts(w), M.lookup_counts(m))
        self.assertEqual(M.helpers(w), M.helpers(m))
        self.assertEqual(len(M.a_planes(w)), len(M.a_planes(m)))
        self.assertEqual(len(M.h_planes(w)), len(M.h_planes(m)))
        self.assertEqual([s["degree"] for s in M.slots(w)], [s["degree"] for s in M.slots(m)])
        self.assertEqual(M.padded_domains(w), M.padded_domains(m))
        self.assertEqual(M.opening_groups(w)["a_groups"], M.opening_groups(m)["a_groups"])
        self.assertEqual((self.w["rows"]["a_sites"], self.w["rows"]["h_sites"], self.w["rows"]["m_rows"]),
                         (self.m["rows"]["a_sites"], self.m["rows"]["h_sites"], self.m["rows"]["m_rows"]))
        # the P-3 table lift is 125M's OWN distance: 2^8 -> 2^14, a factor
        # of 64, where every other shape lifts by 4 or less
        self.assertEqual((w.natural_log("Tab"), w.log("Tab")), (8, 14))
        self.assertEqual((m.natural_log("Tab"), m.log("Tab")), (8, 14))
        self.assertEqual((w.endpoint_log_n, w.endpoint_inv_rate, w.endpoint_general),
                         (m.endpoint_log_n, m.endpoint_inv_rate, m.endpoint_general))

    def test_what_it_does_not_share_and_why(self):
        """Everything that scales with the TOKEN COUNT: the domain sizes, the
        row counts, the lookup work, the endpoint's data rows and the
        receipt."""
        w, m = M.RUNG_W14, M.M125
        self.assertEqual((w.tokens, m.tokens), (64, 512))
        self.assertEqual([w.log(d) for d in M.ALL_DOMS], [6, 10, 14, 16, 16, 14, 16, 16, 14])
        self.assertEqual([m.log(d) for d in M.ALL_DOMS], [9, 13, 14, 19, 19, 17, 22, 20, 14])
        self.assertEqual((self.w["rows"]["a_rows"], self.m["rows"]["a_rows"]), (527, 5681))
        self.assertEqual((self.w["rows"]["h_rows"], self.m["rows"]["h_rows"]), (436, 7120))
        self.assertEqual((self.w["lookups"]["u8_total"], self.m["lookups"]["u8_total"]),
                         (4_882_432, 98_598_912))
        # the endpoint: 125M's LOG over a quarter of 125M's cube, so four
        # data rows and nine commitment rows against 32 and 37
        self.assertEqual((w.endpoint_words, w.endpoint_data_rows, w.endpoint_rows), (65_536, 4, 9))
        self.assertEqual((m.endpoint_words, m.endpoint_data_rows, m.endpoint_rows), (524_288, 32, 37))
        # 32 data rows at an endpoint log of 14 need a 2^19-word padded cube,
        # and the width is capped at 1,024 by the four-norm-limb refusal
        # (norm_wrho reaches 33 at width 1,025), so that means 512 tokens —
        # 125M itself
        self.assertEqual(m.t_pad * m.d_pad, 1 << 19)
        self.assertEqual(M.Shape("probe", tokens=32, width=1025, hidden=1024, q_heads=1025,
                                 head_dim=1, kv_heads=1, log_cols=14, inv_rate=4, f_e=12).norm_wrho, 33)

    def test_the_rows_groups_and_receipt(self):
        r = self.w["rows"]
        self.assertEqual((r["a_data_rows"], r["h_data_rows"], r["a_rows"], r["h_rows"]),
                         (281, 334, 527, 436))
        self.assertEqual((r["a_sites"], r["h_sites"], r["m_rows"]), (122, 50, 50))
        self.assertEqual((self.w["opening_groups"]["a_groups"],
                          self.w["opening_groups"]["h_groups"]), (36, 9))
        self.assertEqual(self.w["lookups"]["u8_total"], 4_882_432)
        self.assertEqual(self.w["receipt_bytes"]["total"], 16_421_048)
        self.assertEqual(self.w["slot_summary"]["largest_L"], 87)
        self.assertTrue(self.w["slot_summary"]["L_plus_256_within_512"])
        # it keeps both earlier arms: the unpadded one (slots 16 and 18 carry
        # no support indicator) and C-6 (Dom::D at 34 lookups, 17 helpers)
        carriers = [s["slot"] for s in self.w["slots"] if s["carries_support_indicator"]]
        self.assertNotIn(M.SC_KVZC, carriers)
        self.assertNotIn(M.SC_FZC, carriers)
        self.assertEqual((M.lookup_counts(M.RUNG_W14)["D"], M.helpers(M.RUNG_W14)["D"]), (34, 17))


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
        for sh in (M.TOY, M.RUNG, M.RUNG_G, M.RUNG_K4, M.M125):
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
        self.assertEqual((M.RUNG_C6.norm_wrho, M.RUNG_C6.wrho_s), (32, 17))
        self.assertEqual([s.limbs_sigma_s for s in (M.TOY, M.RUNG, M.M125)], [2, 3, 3])
        # **LANE STAGE 31.** The norm window fills its top byte at 125M and,
        # since stage 31, at `rung_c6` — and nowhere else — which is what
        # drops the FOUR redundant `scaled` lookups (C-6). Before stage 31
        # the True column of this census had one entry and it belonged to a
        # shape no ordinary test proves at.
        # **LANE STAGE 32** adds `rung_w14`, whose width is 125M's own 768,
        # so its norm window is 125M's 32 and it is on the C-6 arm too; its
        # softmax window is 125M's 18 as well, by the other route
        # (clog2(64) + 12 against clog2(512) + 9).
        self.assertEqual((M.RUNG_W14.norm_wrho, M.RUNG_W14.wrho_s), (32, 18))
        self.assertEqual(M.RUNG_W14.d_max, M.M125.d_max)
        every = (M.TOY, M.RUNG, M.RUNG_G, M.RUNG_K4, M.RUNG_P2, M.RUNG_C6, M.RUNG_W14, M.M125)
        self.assertEqual([s.norm_top_is_full_byte for s in every],
                         [False, False, False, False, False, True, True, True])
        self.assertEqual([s.norm_wrho for s in every], [29, 31, 31, 31, 31, 32, 32, 32])
        self.assertEqual([M.lookup_counts(s)["D"] for s in every],
                         [38, 38, 38, 38, 38, 34, 34, 34])
        self.assertEqual([M.helpers(s)["D"] for s in every], [19, 19, 19, 19, 19, 17, 17, 17])
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


class DerivedEndpoints(unittest.TestCase):
    """**LANE STAGE 23 — the shaped check's finding B-12.**

    The model used to DECLARE every shape's endpoint row count, and two of
    the four declarations were stale: 14 rows for the frozen-seam rung where
    the code has 21, and 29 for 125M where the code has 37. Each was hidden
    behind a NAMED CORRECTION TERM on the Rust side (`+45,056 B` and
    `+32,768 B` in `grow_tests::MODEL_RUNG` and `MODEL_M125`), so the two
    counts never actually met.

    The model now derives the whole endpoint geometry — which endpoint
    carries the plane, how many data rows it has, how many commitment rows —
    from the shape alone, by the rule the code uses. **Both correction terms
    are gone**, and these are the five totals with nothing in between."""

    # The RUST's own counted frame length at each shape
    # (`grow_tests::MODEL_*.receipt_total`, `rung_tests`, `k4_tests`,
    # `tests.rs:108`). The model must now produce each one from its own
    # arithmetic, with no adjustment on either side.
    RUST_RECEIPT_BYTES = {
        "toy": 2_816_472,
        "rung": 4_218_600,
        "rung_g": 4_234_984,
        "rung_k4": 4_743_128,
        "rung_p2": 4_742_728,
        "rung_c6": 7_452_040,
        "rung_w14": 16_421_048,
        "m125": 40_783_352,
    }

    # (words in the padded Dom::D cube, endpoint_log_n, endpoint_inv_rate,
    #  rides the generalised endpoint, data rows, commitment rows)
    ENDPOINTS = {
        "toy": (512, 8, 8, False, 2, 7),
        "rung": (4096, 8, 8, False, 16, 21),
        "rung_g": (4096, 10, 4, True, 4, 9),
        "rung_k4": (4096, 10, 4, True, 4, 9),
        "rung_p2": (4096, 10, 4, True, 4, 9),
        # LANE STAGE 31: the head dimension is 32, so `d_pad` is 512 and the
        # padded Dom::D cube is 2^14 words — sixteen data rows at the block's
        # own row width, and twenty-one commitment rows. That is the frozen
        # seam's row count reached on the GENERALISED endpoint.
        "rung_c6": (16_384, 10, 4, True, 16, 21),
        # LANE STAGE 32: 125M's endpoint LOG at a quarter of 125M's cube.
        # The padded Dom::D cube is 64 * 1024 = 2^16 words, so at
        # endpoint_log_n = 14 it is FOUR data rows and nine commitment rows
        # — the row count of the three 10-log rungs, at 125M's log.
        "rung_w14": (65_536, 14, 4, True, 4, 9),
        "m125": (524_288, 14, 4, True, 32, 37),
    }

    def test_the_model_totals_are_the_rusts_at_every_shape(self):
        for name, want in self.RUST_RECEIPT_BYTES.items():
            with self.subTest(shape=name):
                self.assertEqual(M.model(M.SHAPES[name])["receipt_bytes"]["total"], want)

    def test_every_endpoint_is_derived_from_the_padded_cube_and_the_mask_rows(self):
        for name, (words, log_n, rate, general, data, rows) in self.ENDPOINTS.items():
            with self.subTest(shape=name):
                s = M.SHAPES[name]
                self.assertEqual(s.endpoint_words, s.t_pad * s.d_pad)
                self.assertEqual(s.endpoint_words, words)
                self.assertEqual((s.endpoint_log_n, s.endpoint_inv_rate), (log_n, rate))
                self.assertEqual(s.endpoint_general, general)
                self.assertEqual(s.endpoint_data_rows, max(1, words >> log_n))
                self.assertEqual(s.endpoint_data_rows, data)
                self.assertEqual(s.endpoint_rows, data + M.ENDPOINT_MASK_ROWS)
                self.assertEqual(s.endpoint_rows, rows)

    def test_the_frozen_seam_is_selected_by_the_same_derivation_the_rust_uses(self):
        """`Shape::new` derives `endpoint_general` from three conditions and
        never from a flag: a plane within the seam's 4,096-word ceiling, at
        the seam's frozen `LOG_COLS = 8` and `INV_RATE = 8`. Exactly the two
        shapes that meet all three ride the seam."""
        for name, s in M.SHAPES.items():
            with self.subTest(shape=name):
                seam = (s.endpoint_words <= M.SEAM_MAX_WORDS
                        and s.endpoint_log_n == M.SEAM_LOG_COLS
                        and s.endpoint_inv_rate == M.SEAM_INV_RATE)
                self.assertEqual(s.endpoint_general, not seam)
        self.assertEqual(sorted(n for n, s in M.SHAPES.items() if not s.endpoint_general),
                         ["rung", "toy"])

    def test_no_shape_declares_its_endpoint_row_count_any_more(self):
        """The regression guard on the defect itself: an `endpoint_rows`
        keyword would be a declaration, and the constructor no longer takes
        one."""
        import inspect

        self.assertNotIn("endpoint_rows", inspect.signature(M.Shape.__init__).parameters)


class TheTokenCountRefusal(unittest.TestCase):
    """**LANE STAGE 33, RULING S-6 — the model mirrors the Rust's refusal.**

    A shape whose PADDED token count is at or above the row width is the
    family that reaches `a_groups`'s first arm, which no registered shape
    reaches.  The Rust refuses it at construction by name; the model must
    refuse the same shapes, by the same name, or it would price a geometry
    the prover will not build."""

    def test_a_padded_token_count_at_the_row_width_is_refused_by_name(self):
        with self.assertRaises(ValueError) as cm:
            M.Shape("probe", tokens=256, width=16, hidden=16, q_heads=2,
                    head_dim=8, kv_heads=1, log_cols=8, inv_rate=8, f_e=9)
        msg = str(cm.exception)
        self.assertIn("ruling S-6", msg)
        self.assertIn("token count", msg)
        self.assertIn("a_groups", msg)

    def test_the_boundary_is_the_padded_count_and_nothing_else(self):
        """128 tokens at a row width of 2^8 construct; 129 pad to 256 and are
        refused.  The same sweep the Rust runs, on the same axes."""
        for tokens, refused in ((32, False), (64, False), (128, False), (129, True),
                                (192, True), (256, True), (257, True), (512, True)):
            with self.subTest(tokens=tokens):
                mk = lambda: M.Shape("probe", tokens=tokens, width=16, hidden=16,
                                     q_heads=2, head_dim=8, kv_heads=1, log_cols=8,
                                     inv_rate=8, f_e=9)
                if refused:
                    with self.assertRaises(ValueError) as cm:
                        mk()
                    self.assertIn("ruling S-6", str(cm.exception))
                else:
                    s = mk()
                    self.assertLess(s.natural_log("T"), s.log_cols)

    def test_no_registered_shape_is_refused_and_none_reaches_the_first_arm(self):
        for name, s in M.SHAPES.items():
            with self.subTest(shape=name):
                self.assertLess(s.natural_log("T"), s.log_cols)

    def test_the_two_arms_of_the_tzc_term_agree_on_the_refused_family(self):
        """Why the arm may stay where it is: on exactly the refused family
        `t_pad` is a multiple of the row width (it is a power of two), so the
        live arm's deduplicated offset set is `{0}` and it returns the first
        arm's own 1."""
        for log_cols in range(2, 17):
            n = 1 << log_cols
            for e in range(log_cols, log_cols + 5):
                t_pad = 1 << e
                offs = {(k * t_pad) % n for k in range(3 * M.LIMBS_ISQRT)} | {0}
                with self.subTest(log_cols=log_cols, t_pad=t_pad):
                    self.assertEqual(len(offs), 1)


if __name__ == "__main__":
    unittest.main()
