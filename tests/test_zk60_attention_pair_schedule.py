#!/usr/bin/env python3
"""Tests for `scripts/zk60_attention_pair_schedule.py` (the attention A / H / W pair schedule
and its rank verdict; inventory items O-1 / O-2).

What is asserted: the opening groups rebuilt from the inventory equal the inventory's counts
and member lists; the schedule covers every claim exactly once with disjoint mask rows; the
positive rank results (0 everywhere, 2 = the public LogUp identity on H); every negative
control; a tiny hand-checkable geometry brute-forced over F_11^2 against the engine; the
sparse engine against FA2's dense one; determinism under a fixed seed; the committed
schedule record is the one this tool produces.

Nothing here is a privacy result about the attention argument at the source pin (P0); the
verdicts are FA2's linear model on a DESIGN (numerical rank, not a simulation proof).
"""
import importlib.util
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TOOL = ROOT / "scripts" / "zk60_attention_pair_schedule.py"
INVENTORY = ROOT / "results" / "zk60_opus_attention_inventory.json"
SCHEDULE = ROOT / "docs" / "zkmatrix-poc" / "zk60_private_attention_schedule.json"
SEED = 2026

_SPEC = importlib.util.spec_from_file_location("zk60_attention_pair_schedule", TOOL)
T = importlib.util.module_from_spec(_SPEC)
_SPEC.loader.exec_module(T)
FA2 = T.FA2

_CACHE = {}


def results():
    """run_all once per test process (about 15 s), shared by the classes below."""
    if "run" not in _CACHE:
        _CACHE["run"] = T.run_all(str(INVENTORY), seed=SEED, n_values=4, brute_force=False)
    return _CACHE["run"]


def inventory():
    if "inv" not in _CACHE:
        _CACHE["inv"] = T.load_inventory(str(INVENTORY))
    return _CACHE["inv"]


class GroupReconstruction(unittest.TestCase):
    """The opening groups rebuilt by pcs::group_claims' rule equal the inventory."""

    def test_block_profile_counts_and_members(self):
        claims = T.claims_for_profile(inventory(), "block")
        self.assertEqual(len(claims), 133)
        groups = T.build_groups(claims)
        self.assertEqual({cm: len(groups[cm]) for cm in "AHW"}, {"A": 39, "H": 6, "W": 6})
        self.assertEqual({cm: sum(1 for g in groups[cm] if g["singleton"]) for cm in "AHW"}, {"A": 17, "H": 1, "W": 6})
        xc = T.cross_check_groups(groups, inventory(), "block")
        self.assertTrue(xc["all_pass"], xc)

    def test_receipt_profile_counts_and_members(self):
        claims = T.claims_for_profile(inventory(), "receipt")
        self.assertEqual(len(claims), 135)
        groups = T.build_groups(claims)
        self.assertEqual({cm: len(groups[cm]) for cm in "AHW"}, {"A": 41, "H": 6, "W": 6})
        self.assertEqual({cm: sum(1 for g in groups[cm] if g["singleton"]) for cm in "AHW"}, {"A": 19, "H": 1, "W": 6})
        self.assertTrue(T.cross_check_groups(groups, inventory(), "receipt")["all_pass"])

    def test_seam_group_and_sum_group(self):
        groups = T.build_groups(T.claims_for_profile(inventory(), "block"))
        seam = [g for g in groups["A"] if g["seam"]]
        self.assertEqual(len(seam), 1)
        self.assertEqual((seam[0]["group"], seam[0]["m"]), (38, 2))
        self.assertEqual(sorted(seam[0]["sites"]), ["xm8 (SeamXm8[0])", "z16c (SeamZ16c[0])"])
        sums = [g for g in groups["H"] if g["sum_group"]]
        self.assertEqual([g["m"] for g in sums], [19])
        # the seam claims alias the rho_D openings of the same rows (FA2 U12)
        by_index = {c["index"]: c for c in T.claims_for_profile(inventory(), "block")}
        rho_d = next(g for g in groups["A"] if g["m"] == 18)
        seam_rows = {(by_index[i]["row0"], by_index[i]["rows"]) for i in seam[0]["members"]}
        rho_d_rows = {(by_index[i]["row0"], by_index[i]["rows"]) for i in rho_d["members"]}
        self.assertTrue(seam_rows <= rho_d_rows)


class Schedule(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        cls.block = T.build_schedule(inventory(), "block")
        cls.receipt = T.build_schedule(inventory(), "receipt")
        cls.exempt = T.build_schedule(inventory(), "receipt", endpoints="exempt")

    def test_every_claim_covered_exactly_once_with_disjoint_mask_rows(self):
        for s in (self.block, self.receipt, self.exempt):
            cov = T.schedule_coverage_checks(s)
            self.assertTrue(cov["all_pass"], cov)

    def test_every_plane_site_is_a_pair_and_prox_is_a_pair(self):
        for s in (self.block, self.receipt):
            for cm in "AHW":
                for site in s["commitments"][cm]["sites"]:
                    self.assertTrue(site["mask_kind"].startswith("pair"), site["role"])
                    self.assertEqual(len(site["mask_rows"]), 2, site["role"])
                self.assertTrue(s["commitments"][cm]["prox"]["mask_kind"].startswith("prox_pair"))
        for site in self.exempt["commitments"]["A"]["sites"]:
            if site.get("receipt_only"):
                self.assertTrue(site["mask_kind"].startswith("none"))
                self.assertEqual(site["mask_rows"], [])

    def test_histogram_slots_follow_the_block_or_pair_rule(self):
        hm = self.block["commitments"]["A"]["histogram_masks"]
        self.assertEqual(len(hm), 10)
        self.assertEqual(sum(1 for h in hm if h["mask_kind"] == "pair"), 5)
        for h in hm:
            self.assertEqual(len(h["mask_rows"]), 2 if h["data_rows"] == 1 else h["data_rows"])
        self.assertEqual(self.block["commitments"]["A"]["histogram_data_rows_total"], 585)
        gt = self.block["commitments"]["H"]["g_T_sites"]
        self.assertEqual(sum(len(g["mask_rows"]) for g in gt), 1170)
        self.assertEqual(self.block["commitments"]["H"]["g_T_data_rows_total"], 1170)

    def test_added_sites_and_their_grouping(self):
        self.assertEqual(len(self.block["commitments"]["A"]["added_sites"]), 12)
        self.assertEqual({cm: len(self.block["groups"][cm]) for cm in "AHW"}, {"A": 43, "H": 6, "W": 6})
        self.assertEqual(sum(1 for g in self.block["groups"]["A"] if g["singleton"]), 13)
        rho2 = [g for g in self.block["groups"]["A"] if g["key"] and "rho_Dsq[0]" in g["key"]]
        self.assertEqual([g["m"] for g in rho2], [2] * 8)
        forced = T.build_schedule(inventory(), "block", force_singletons=True)
        self.assertEqual(len(forced["groups"]["A"]), 51)
        self.assertEqual(sum(1 for g in forced["groups"]["A"] if g["singleton"]), 29)
        self.assertEqual(T.row_cost(forced)["A"]["rows"], T.row_cost(self.block)["A"]["rows"])

    def test_row_cost(self):
        rc = T.row_cost(self.block)
        self.assertEqual((rc["A"]["rows"], rc["H"]["rows"], rc["W"]["P3_rows"], rc["W"]["P1_rows"]), (1487, 2490, 18, 4))
        self.assertEqual(rc["A"]["seam_pairs"], 4)
        self.assertEqual(rc["A"]["claim_pairs_added_sub_row_sites"], 24)
        self.assertEqual(rc["A"]["claim_pairs_inventory"], 174)
        self.assertEqual(rc["H"]["helper_pairs"], 38)
        self.assertEqual(rc["H"]["sum_claims_replaced"], 19)
        self.assertEqual(rc["bytes_per_row"], 20480)
        self.assertEqual(T.row_cost(self.receipt)["A"]["rows"], 1491)
        self.assertEqual(T.row_cost(self.exempt)["A"]["rows"], 1487)

    def test_u_replaces_the_19_sum_claims(self):
        H = self.block["commitments"]["H"]
        self.assertEqual(len(H["replaced_sum_claims"]), 19)
        self.assertEqual(H["h_u"]["mask_kind"], "zero_sum_pair")
        self.assertEqual(H["h_up"]["mask_kind"], "pair")
        self.assertEqual(len(H["sites"]), 19)

    def test_committed_schedule_record_is_this_tools_output(self):
        """docs/zkmatrix-poc/zk60_private_attention_schedule.json is what the tool writes now."""
        self.assertTrue(SCHEDULE.exists(), "run the tool first")
        on_disk = json.loads(SCHEDULE.read_text())
        _, record = results()
        self.assertEqual(json.dumps(on_disk, sort_keys=True), json.dumps(record, sort_keys=True))


class Engine(unittest.TestCase):
    """The sparse engine equals FA2's dense `analyze` (ranks and functional space)."""

    def test_on_fa2_fixtures(self):
        for model in (FA2.fixture_singleton()[0], FA2.fixture_pair(), FA2.fixture_pair(degenerate=True), FA2.fixture_two_rows()[0], FA2.fixture_reuse(), FA2.fixture_reuse(reuse=False),
                      FA2.group_with_values(7, 4, ["pairmask"] * 7, seed=1, with_prox=True, prox_pair=True), FA2.group_with_values(3, 4, ["base1"] * 3, seed=2, with_prox=True), FA2.fixture_logup_sum(4, 2, 1, seed=94, prox_pair=True)[0]):
            self.assertTrue(T.engines_agree(model)["agree"], model.name)

    def test_on_the_whole_attention_A_per_column(self):
        sched = T.build_schedule(inventory(), "block")
        for kind in (None, "base1", "none"):
            groups = T.a_model_groups(sched) if kind is None else T.a_model_groups(sched, kind_for=lambda s, k=kind: k, tables_kind=(None if kind == "base1" else "none"))
            model, _ = T.build_model("A", groups, 1, 7, False, prox="pair" if kind != "none" else "none")
            self.assertTrue(T.engines_agree(model)["agree"], kind)


class PositiveVerdicts(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        cls.res, cls.rec = results()
        cls.blk = cls.res["profiles"]["block"]["rank_verdicts"]

    def test_every_group_alone_is_covered(self):
        for key in ("block", "receipt_pair"):
            rv = self.res["profiles"][key]["rank_verdicts"]
            groups = [k for k in rv if k.startswith("group_")]
            self.assertGreaterEqual(len(groups), 43 + 6 + 6)
            for k in groups:
                self.assertEqual(rv[k]["disclosed_dim"], 0, k)
                if "rank_mask_formula_2m+2n-2+2n" in rv[k]:
                    self.assertTrue(rv[k]["rank_mask_formula_2m+2n-2+2n"], k)

    def test_whole_commitments_per_column(self):
        for key in ("block", "receipt_pair"):
            rv = self.res["profiles"][key]["rank_verdicts"]
            for k in ("whole_A_per_column_P1", "whole_A_per_column_P3", "whole_H_per_column", "whole_W_P3_per_column"):
                self.assertEqual(rv[k]["disclosed_dim"], 0, (key, k))
                self.assertTrue(rv[k]["sparse_engine_equals_FA2_analyze"], (key, k))
            self.assertTrue(rv["whole_A_per_column_P1"]["FA2_builder_agrees"])
            self.assertTrue(rv["whole_W_P3_per_column"]["FA2_builder_agrees"])
            self.assertEqual(rv["whole_A_per_column_P1"]["rank_mask"], 2 * rv["whole_A_per_column_P1"]["groups"] + 2)

    def test_whole_A_with_values(self):
        for key in ("block", "receipt_pair"):
            rv = self.res["profiles"][key]["rank_verdicts"]
            v = rv["whole_A_with_values_n4_P1"]
            self.assertEqual(v["disclosed_dim"], 0)
            self.assertEqual(v["trivial_identities"], 2 * v["groups"])
            self.assertTrue(v["FA2_builder_agrees"])
            self.assertEqual(rv["whole_A_with_values_n4_P3"]["disclosed_dim"], 0)

    def test_exempt_endpoints_disclose_only_the_public_boundary_rows(self):
        rv = self.res["profiles"]["receipt_exempt"]["rank_verdicts"]
        for k in ("whole_A_per_column_P1", "whole_A_with_values_n4_P1"):
            self.assertGreater(rv[k]["disclosed_dim"], 0, k)
            self.assertTrue(rv[k]["disclosed_confined_to_public_boundary_rows"], k)
            self.assertEqual(rv[k]["verdict"], "PASS")

    def test_one_zero_sum_construction_covers_all_19_helper_sums(self):
        for k in ("whole_H_with_values_n4", "whole_H_with_values_n8", "FA2_fixture_logup_sum_19_helpers_10_tables_n4", "FA2_fixture_logup_sum_19_helpers_10_tables_n8"):
            v = self.blk[k]
            self.assertEqual(v["disclosed_dim"], 2, k)
            self.assertEqual((v["rank_F"], v["rank_I"], v["rank_F_union_I"]), (2, 2, 2), k)
            self.assertTrue(v["residual_is_exactly_the_public_identity"], k)
        self.assertTrue(self.blk["whole_H_with_values_n4"]["sparse_engine_equals_FA2_analyze"])

    def test_forced_singleton_grouping_and_alternatives(self):
        forced = self.res["profiles"]["block"]["added_sites_forced_singletons"]
        self.assertEqual(forced["group_counts"]["A"], 51)
        self.assertEqual(forced["whole_A_per_column"]["disclosed_dim"], 0)
        self.assertEqual(self.blk["alternative_tables_all_pairs_per_column"]["disclosed_dim"], 0)
        alt = self.blk["alternative_multi_row_planes_as_base_blocks_per_column"]
        self.assertEqual(alt["disclosed_dim"], 2)
        self.assertTrue(alt["leaked_rows_are_exactly_the_sm_rows"])

    def test_no_failures(self):
        self.assertEqual(self.res["failures"], [])
        self.assertEqual(self.res["summary"]["groups_with_nonzero_disclosure"], {})


class NegativeControls(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        cls.nc = results()[0]["profiles"]["block"]["negative_controls"]

    def test_legacy_no_mask_is_a_large_disclosure(self):
        self.assertGreaterEqual(self.nc["legacy_no_mask_A_per_column"]["disclosed_dim"], 40)
        self.assertGreaterEqual(self.nc["legacy_no_mask_A_with_values_n4"]["disclosed_dim"], 200)
        self.assertGreaterEqual(self.nc["legacy_no_mask_H_with_values_n4"]["disclosed_dim"], 38)

    def test_single_base_row_on_a_singleton_leaks_the_whole_plane(self):
        v = self.nc["single_base_row_per_claim_A_per_column"]
        self.assertEqual(v["disclosed_dim"], 10)  # 13 singletons, four of them on the same sm row 104
        self.assertTrue(v["every_singleton_row_disclosed"])
        self.assertEqual(self.nc["single_base_row_singleton_g19_with_values_n4"]["disclosed_dim"], 4)
        self.assertTrue(self.nc["single_base_row_singleton_g19_with_values_n4"]["full_plane_from_one_proof"])
        self.assertEqual(self.nc["single_base_row_singleton_g14_with_values_n4"]["disclosed_dim"], 4)
        self.assertEqual(self.nc["same_singleton_g19_with_pair"]["disclosed_dim"], 0)
        self.assertEqual(self.nc["same_singleton_g14_with_pair"]["disclosed_dim"], 0)
        self.assertEqual(self.nc["single_base_row_per_claim_W_P3_per_column"]["disclosed_dim"], 4)
        self.assertEqual(len(self.nc["single_base_row_per_claim_W_P3_per_column"]["w_rows_recovered"]), 4)

    def test_single_prox_row_instead_of_a_pair(self):
        self.assertEqual(self.nc["single_prox_row_singleton_pair_claim_per_column"]["disclosed_dim"], 1)
        self.assertEqual(self.nc["prox_pair_singleton_pair_claim_per_column"]["disclosed_dim"], 0)
        self.assertEqual(self.nc["single_prox_row_W_P3_per_column"]["disclosed_dim"], 1)
        self.assertIn("composition_covers", self.nc["single_prox_row_whole_A_per_column"])

    def test_one_seam_pair_dropped_leaks(self):
        self.assertEqual(self.nc["seam_pair_dropped_with_values_n4"]["disclosed_dim"], 2)
        self.assertEqual(self.nc["seam_pairs_both_with_values_n4"]["disclosed_dim"], 0)

    def test_nineteen_helper_sums_published_individually(self):
        v = self.nc["nineteen_helper_sums_published_n4"]
        self.assertEqual(v["rank_of_the_19_sums"], 38)
        self.assertTrue(v["nineteen_sums_disclosed"])
        self.assertGreaterEqual(v["disclosed_dim"], 38)

    def test_zero_sum_row_without_its_fresh_pair_leaks(self):
        self.assertGreater(self.nc["zero_sum_row_without_fresh_pair_n4"]["disclosed_dim"], 2)

    def test_flipped_rope_claim_sharing_its_pair_leaks(self):
        for plane in ("q8", "k8"):
            self.assertEqual(self.nc[f"flipped_rope_{plane}_sharing_pair_with_values_n4"]["disclosed_dim"], 2, plane)
            self.assertEqual(self.nc[f"flipped_rope_{plane}_own_pair_with_values_n4"]["disclosed_dim"], 0, plane)

    def test_every_control_verdict_passes(self):
        for k, v in self.nc.items():
            self.assertEqual(v["verdict"], "PASS", k)


class TinyGeometryBruteForce(unittest.TestCase):
    """One group, two columns, F_11^2: every mask assignment enumerated; the observation
    distributions of two data vectors are identical iff the engine says disclosed_dim = 0."""

    def check(self, kinds, data_rows, with_values, expect_engine):
        b = T.brute_force_hiding(kinds, 2, with_values, seed=3, data_rows=data_rows)
        e = T.engine_on_tiny_geometry(kinds, 2, with_values, seed=3, data_rows=data_rows)
        self.assertEqual(e["disclosed_dim"], expect_engine, (kinds, data_rows, with_values))
        self.assertTrue(e["engines_agree"])
        self.assertEqual(b["distinguishable"], expect_engine > 0, (kinds, data_rows, with_values, b["assignments"]))

    def test_pair_is_a_one_time_pad(self):
        self.check(["pair"], 1, True, 0)

    def test_single_base_row_and_no_mask_are_distinguishable(self):
        self.check(["base1"], 1, True, 2)
        self.check(["none"], 1, True, 2)
        self.check(["base1"], 2, True, 2)

    def test_two_base_members_leak_only_through_the_values(self):
        self.check(["base1", "base1"], 1, False, 0)
        self.check(["base1", "base1"], 1, True, 2)


class Determinism(unittest.TestCase):

    def test_same_seed_same_output(self):
        res1, rec1 = results()
        res2, rec2 = T.run_all(str(INVENTORY), seed=SEED, n_values=4, brute_force=False)
        self.assertEqual(json.dumps(res1, sort_keys=True), json.dumps(res2, sort_keys=True))
        self.assertEqual(json.dumps(rec1, sort_keys=True), json.dumps(rec2, sort_keys=True))

    def test_other_seed_same_verdicts(self):
        sched = T.build_schedule(inventory(), "block")
        a = T.run_positive(sched, SEED, p3_modes=(False,))
        b = T.run_positive(sched, SEED + 1, p3_modes=(False,))
        self.assertEqual({k: v.get("disclosed_dim") for k, v in a.items()}, {k: v.get("disclosed_dim") for k, v in b.items()})
        na = T.run_negative(sched, SEED)
        nb = T.run_negative(sched, SEED + 1)
        self.assertEqual({k: v["disclosed_dim"] for k, v in na.items()}, {k: v["disclosed_dim"] for k, v in nb.items()})


class CLI(unittest.TestCase):

    def test_cli_exit_zero_and_outputs(self):
        with tempfile.TemporaryDirectory() as d:
            out, sch = os.path.join(d, "r.json"), os.path.join(d, "s.json")
            p = subprocess.run([sys.executable, str(TOOL), "--inventory", str(INVENTORY), "--out", out, "--schedule-out", sch, "--seed", str(SEED), "--no-brute-force"], capture_output=True, text=True, timeout=600)
            self.assertEqual(p.returncode, 0, p.stdout + p.stderr)
            with open(out) as f:
                r = json.load(f)
            self.assertEqual(r["failures"], [])
            self.assertEqual(r["summary"]["disclosed_dim_per_commitment_per_column"]["A_block_P1"], 0)
            self.assertEqual(r["summary"]["disclosed_dim_per_commitment_with_values"]["H_n8"], 2)
            with open(sch) as f:
                s = json.load(f)
            self.assertEqual(len(s["commitments"]["A"]["sites"]), 101)
            self.assertEqual(len(s["commitments"]["H"]["sites"]), 19)
            self.assertEqual(len(s["commitments"]["W"]["sites"]), 6)


if __name__ == "__main__":
    unittest.main()
