#!/usr/bin/env python3
"""Tests for O4's attention inventory tool (`scripts/zk60_opus_attention_inventory.py`).

The tool's whole value is that its model of `attn_argument` is pinned to
constants the Rust source fixes independently (public_block_wire.rs's
ATTN_SC / collapse rounds / commitment rows / claim count, A01's executed
event counts, FA5's lookup total).  These tests assert those pins, the
structural facts the inventory reports, and that the FA6 criterion is applied
by IMPORTING Fable's tool rather than re-deriving its algebra.

Nothing here asserts a privacy property of attention.  Attention is a
public/P0 argument at this pin.
"""
import hashlib
import importlib.util
import json
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TOOL = ROOT / "scripts" / "zk60_opus_attention_inventory.py"
RECORD = ROOT / "results" / "zk60_opus_attention_inventory.json"

_SPEC = importlib.util.spec_from_file_location("zk60_opus_attention_inventory", TOOL)
T = importlib.util.module_from_spec(_SPEC)
_SPEC.loader.exec_module(T)


class Layout(unittest.TestCase):
    """The port of `AttnLayout::new` against the numbers the source fixes."""

    @classmethod
    def setUpClass(cls):
        cls.lay = T.Layout(T.PROFILE)

    def test_domain_logs_of_the_fixed_profile(self):
        l = self.lay
        self.assertEqual(
            (l.log_t, l.log_dp, l.log_hp, l.log_qp, l.log_vp, l.log_hd, l.log_kp),
            (5, 4, 1, 4, 3, 3, 0))
        self.assertEqual((l.log_d, l.log_q, l.log_kv, l.log_s), (9, 9, 8, 11))
        self.assertEqual((l.log_sm, l.log_lm, l.cols_log), (9, 9, 8))

    def test_commitment_rows_match_the_wire_codec(self):
        l = self.lay
        self.assertEqual(l.rows(l.w_len), 4)     # public_block_wire.rs:117
        self.assertEqual(l.rows(l.a_len), 108)   # public_block_wire.rs:118
        self.assertEqual(l.rows(l.h_len), 106)   # public_block_wire.rs:119

    def test_short_w_adapter_preconditions(self):
        """public_block_oracle.rs:196-205 asserts exactly these five values."""
        l = self.lay
        self.assertEqual((l.cols_log, l.log_wkv, l.wk, l.wv, l.w_len),
                         (8, 7, 256, 384, 1024))

    def test_helper_pair_counts(self):
        l = self.lay
        self.assertEqual(l.n_d, 9)
        self.assertEqual(len(l.h_q), 3)
        self.assertEqual(len(l.h_kv), 3)
        self.assertEqual(len(l.h_s), 3)

    def test_packed_small_sub_rows_are_disjoint_and_aligned(self):
        l = self.lay
        offs = [l.sm_m(), l.sm_sum()] + [l.sm_row(s, k) for s in range(2)
                                         for k in range(4)]
        self.assertEqual(len(set(offs)), len(offs))
        for o in offs:
            self.assertEqual((o - l.sm) % l.t, 0)
            self.assertLess(o - l.sm, 1 << l.log_sm)


class Schedule(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.lay = T.Layout(T.PROFILE)
        cls.slots, cls.claims, cls.meta = T.build_schedule(cls.lay)
        cls.plan = T.collapse_plan(cls.lay)

    def test_twelve_sumchecks_match_ATTN_SC(self):
        got = [(s.main_rounds, s.degree + 1) for s in self.slots]
        self.assertEqual(got, T.SOURCE_CONSTANTS["attn_sc"])

    def test_four_collapse_blocks_match_the_wire_codec(self):
        self.assertEqual([log for _, log in self.plan],
                         T.SOURCE_CONSTANTS["collapse_rounds"])
        self.assertEqual(sum(1 << log for _, log in self.plan), self.lay.a_len)

    def test_claim_counts_133_and_135(self):
        n_block = self.meta["n_block_claims"]
        self.assertEqual(n_block, 133)           # public_block_wire.rs:106
        self.assertEqual(len(self.claims), 135)  # public_block_receipt.rs:300

    def test_per_commitment_counts_match_A01(self):
        cs = self.claims[:self.meta["n_block_claims"]]
        self.assertEqual(sum(1 for c in cs if c.com == "A"), 89)
        self.assertEqual(sum(1 for c in cs if c.com == "W"), 6)
        self.assertEqual(sum(1 for c in cs if c.com == "H" and not c.is_sum), 19)
        self.assertEqual(sum(1 for c in cs if c.com == "H" and c.is_sum), 19)

    def test_terminal_descriptor_count_matches_A01(self):
        self.assertEqual(sum(len(s.terminals) for s in self.slots), 99)

    def test_lookup_totals_match_FA5(self):
        tables = T.lookup_tables(self.lay, T.PROFILE)
        self.assertEqual(len(tables), 10)
        self.assertEqual(sum(t["required_total"] for t in tables), 26624)

    def test_every_claim_point_has_the_arity_of_its_slice(self):
        """zkp-core/src/pcs.rs:217 asserts point arity == slice log_size."""
        for c in self.claims:
            if c.is_sum:
                self.assertEqual(c.point, ())
            else:
                self.assertEqual(len(c.point), c.log_size, c.site)

    def test_the_two_short_w_claims_are_lifted_into_one_row(self):
        lifted = [c for c in self.claims if c.lifted]
        self.assertEqual(len(lifted), 2)
        for c in lifted:
            self.assertEqual(c.raw_log_size, 7)
            self.assertEqual(c.log_size, 8)
            self.assertEqual(c.offset, 256)
        self.assertEqual({c.raw_offset for c in lifted}, {256, 384})

    def test_seam_claims_open_xm8_and_z16c_at_the_same_point(self):
        seam = [c for c in self.claims if "Seam" in c.site]
        self.assertEqual(len(seam), 2)
        self.assertEqual({c.offset for c in seam}, {self.lay.xm8, self.lay.z16c})
        self.assertEqual(seam[0].point, seam[1].point)

    def test_seam_rows_are_also_opened_by_the_D_zero_check(self):
        """The aliasing FA3 section 2.3 item 4 / U12 is about."""
        for off in (self.lay.xm8, self.lay.z16c):
            pts = {c.point for c in self.claims if c.offset == off and not c.is_sum}
            self.assertGreaterEqual(len(pts), 2, off)

    def test_matmul_and_row_sum_slots_have_private_claimed_sums(self):
        private = [s.name for s in self.slots
                   if s.claimed_sum_kind.startswith("derived-from-claims")]
        self.assertEqual(set(private),
                         {"SS row sums", "row sums", "QKV matmul", "score matmul",
                          "PV matmul", "Wo matmul"})

    def test_score_and_pv_have_no_vanishing_public_factor_at_kv1(self):
        """log_kp = 0 makes eq(r_hi, rg) the constant 1 (FA5 R22)."""
        for name in ("score matmul", "PV matmul"):
            s = next(s for s in self.slots if s.name == name)
            self.assertIn("CONSTANT 1", s.public_factor)
            self.assertEqual(s.private_factors, 2)


class Groups(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.lay = T.Layout(T.PROFILE)
        cls.slots, cls.claims, cls.meta = T.build_schedule(cls.lay)

    def _groups(self, com, upto):
        keys, members = [], []
        for c in self.claims[:upto]:
            if c.com != com:
                continue
            k = c.group_key(self.lay.cols_log)
            if k in keys:
                members[keys.index(k)].append(c)
            else:
                keys.append(k)
                members.append([c])
        return list(zip(keys, members))

    def test_all_helper_sum_claims_form_one_group(self):
        """col_key is None for every sum claim (zkp-core/src/pcs.rs:232-234)."""
        gs = self._groups("H", self.meta["n_block_claims"])
        sums = [m for k, m in gs if k is None]
        self.assertEqual(len(sums), 1)
        self.assertEqual(len(sums[0]), 19)

    def test_group_counts(self):
        n = self.meta["n_block_claims"]
        self.assertEqual(len(self._groups("A", n)), 39)
        self.assertEqual(len(self._groups("W", n)), 6)
        self.assertEqual(len(self._groups("H", n)), 6)

    def test_every_W_claim_is_its_own_group(self):
        n = self.meta["n_block_claims"]
        gs = self._groups("W", n)
        self.assertTrue(all(len(m) == 1 for _, m in gs))

    def test_seventeen_A_groups_are_singletons(self):
        """FA2 section 14.1's worst shape: a one-member group under a single
        base mask row discloses the whole plane per column."""
        n = self.meta["n_block_claims"]
        gs = self._groups("A", n)
        self.assertEqual(sum(1 for _, m in gs if len(m) == 1), 17)

    def test_the_receipt_binding_adds_two_singleton_A_groups(self):
        block = self._groups("A", self.meta["n_block_claims"])
        full = self._groups("A", len(self.claims))
        self.assertEqual(len(full) - len(block), 2)
        for _, m in full[len(block):]:
            self.assertEqual(len(m), 1)


class CfsSlots(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.lay = T.Layout(T.PROFILE)
        cls.slots, _, _ = T.build_schedule(cls.lay)
        cls.p1 = T.cfs_slot_table(cls.lay, cls.slots, p3=False)
        cls.p3 = T.cfs_slot_table(cls.lay, cls.slots, p3=True)
        cls.col = T.collapse_cfs_slots(T.collapse_plan(cls.lay))

    def test_n_vars_is_main_rounds_plus_extensions(self):
        for row in self.p1 + self.p3 + self.col:
            self.assertEqual(row["n_vars"], row["main_rounds"] + row["ext_rounds"])
            self.assertEqual(row["cfs_len"], row["n_vars"] * row["degree"] + 2)

    def test_bilinear_private_rounds_need_two_extensions(self):
        for row in self.p1:
            if row["name"] in ("score matmul", "PV matmul"):
                self.assertEqual(row["ext_rounds"], 2, row["name"])
            elif row["name"] in ("QKV matmul", "Wo matmul"):
                self.assertEqual(row["ext_rounds"], 1, row["name"])

    def test_p3_gives_the_public_weight_matmuls_a_second_extension(self):
        by = {r["name"]: r for r in self.p3}
        self.assertEqual(by["QKV matmul"]["ext_rounds"], 2)
        self.assertEqual(by["Wo matmul"]["ext_rounds"], 2)

    def test_every_slot_fits_the_mask_commitment_row(self):
        """zk.rs:442 -- coefficients + 256 pads must fit 512 message positions."""
        for row in self.p1 + self.p3 + self.col:
            self.assertLessEqual(row["cfs_len"] + T.SOURCE_CONSTANTS["mask_q"],
                                 T.SOURCE_CONSTANTS["mask_msg"], row["slot"])

    def test_the_largest_attention_slot_is_the_softmax_zero_check(self):
        big = max(self.p1, key=lambda r: r["cfs_len"])
        self.assertEqual(big["name"], "zero-check S")
        self.assertEqual((big["n_vars"], big["degree"], big["cfs_len"]), (12, 5, 62))


class Fa6Criterion(unittest.TestCase):
    """FA6's algebra is IMPORTED, never re-derived (queue instruction)."""

    @classmethod
    def setUpClass(cls):
        cls.fa6 = T.load_fa6()
        cls.lay = T.Layout(T.PROFILE)
        cls.slots, _, _ = T.build_schedule(cls.lay)

    def test_the_imported_module_is_fables_pinned_tool(self):
        path = ROOT / "scripts" / "zk60_fable_cfs_channel.py"
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        self.assertEqual(
            digest,
            "ba05f0d140d72f67d69bbf48f4336d08a83cd99fbd01d2c49c417ec120066437")
        self.assertTrue(hasattr(self.fa6, "system_single"))
        self.assertTrue(hasattr(self.fa6, "analyze_system"))

    def test_every_derived_attention_slot_is_surjective_onto_S(self):
        table = T.cfs_slot_table(self.lay, self.slots, p3=False)
        rows = T.run_fa6_criterion(self.fa6, table)
        self.assertEqual(len(rows), 12)
        for r in rows:
            self.assertTrue(r["image_inside_subspace"], r["slot"])
            self.assertEqual(r["leaked_dim_fp2"], 0, r["slot"])
            self.assertEqual(r["rank_map"], r["dim_consistency_subspace"], r["slot"])
            self.assertEqual(r["kernel_dim_fp2"], 1, r["slot"])   # the a' direction
            self.assertTrue(r["theta_combination_in_view_span"], r["slot"])

    def test_dim_S_is_N_times_d_plus_one(self):
        table = T.cfs_slot_table(self.lay, self.slots, p3=False)
        rows = T.run_fa6_criterion(self.fa6, table)
        for r in rows:
            self.assertEqual(r["dim_consistency_subspace"],
                             r["n_vars"] * r["degree"] + 1, r["slot"])

    def test_a_deficient_control_is_still_detected(self):
        """Negative control: c = 0 puts the whole f-part in the clear
        (FA6 `nc_mask_challenge_zero`). The criterion must SEE that."""
        slots = {"S": {"n_vars": 6, "degree": 3, "claim": "public 0", "ext_rounds": 1}}
        self.fa6._finish(slots)
        rng = self.fa6.Rng(6)
        ch = self.fa6.Channel()
        ch.add_mask("S", 6, 3)
        zero = self.fa6.ZERO
        g = ch.add_view("Gamma", ch.mask_row("S", self.fa6.cfs_sum_weights(6, 3), zero))
        ch.add_masked_sumcheck("S", zero, {g: self.fa6.ONE}, rng, "S")
        res = ch.analyze(want_witness=False)
        self.assertGreater(res["leaked_dim_fp2"], 0)


class Record(unittest.TestCase):
    def test_archived_record_is_bound_to_its_tool_and_source(self):
        if not RECORD.exists():
            self.skipTest("record not generated yet")
        rec = json.loads(RECORD.read_text())
        self.assertEqual(rec["tool_sha256"],
                         hashlib.sha256(TOOL.read_bytes()).hexdigest())
        # O4 is an archived inventory, not a claim about every later checkout.
        # The fresh IO profile changes shared zk/private_seam source; rewriting
        # O4's hashes would incorrectly relabel its historical review evidence.
        self.assertEqual(rec["source_commit"], "b41d036")
        for rel, digest in rec["source_sha256"].items():
            source = subprocess.check_output(
                ["git", "show", rec["source_commit"] + ":" + rel], cwd=ROOT)
            self.assertEqual(hashlib.sha256(source).hexdigest(), digest, rel)
        self.assertTrue(rec["all_checks_pass"])
        self.assertTrue(all(c["pass"] for c in rec["checks"]))

    def test_record_states_its_limits(self):
        if not RECORD.exists():
            self.skipTest("record not generated yet")
        rec = json.loads(RECORD.read_text())
        joined = " ".join(rec["limits"]).lower()
        self.assertIn("p0", joined)
        self.assertIn("no repair", joined)
        self.assertIn("blocker", joined)

    def test_record_is_deterministic(self):
        rep = T.build_report(run_ranks=False)
        again = T.build_report(run_ranks=False)
        self.assertEqual(json.dumps(rep, sort_keys=True),
                         json.dumps(again, sort_keys=True))


if __name__ == "__main__":
    unittest.main()
