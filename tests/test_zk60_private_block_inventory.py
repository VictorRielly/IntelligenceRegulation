"""Tests for scripts/zk60_private_block_inventory.py — the three committed leak-checking tools
re-run on the REAL Rust of `hashline/src/private_block/` (disposition condition 4).

Four layers:
  1. the committed parser alone must FAIL on the block's Rust, and each adapter must be needed
     (otherwise the adapters would be decoration and the report would be misleading);
  2. one end-to-end run of the driver's own `main`, green, with the `.done` marker and the log;
  3. every count against the DESIGN, every disclosed dimension, every host group, every slot
     length, every negative control including the two owed ones, and the paper comparison;
  4. a deliberately wrong expectation must make the driver fail (the gate is not vacuous).

Run:
    python3 -m unittest tests.test_zk60_private_block_inventory
    python3 -m unittest discover -s /home/victor/wt-zk60-private-block/tests \\
        -p 'test_zk60_private_block_inventory.py' -v
"""
import copy
import importlib.util
import json
import os
import shutil
import tempfile
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRIPT = os.path.join(ROOT, "scripts", "zk60_private_block_inventory.py")
COMMITTED = os.path.join(ROOT, "scripts", "zk60_attention_native_inventory.py")

_spec = importlib.util.spec_from_file_location("zk60_private_block_inventory", SCRIPT)
PB = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(PB)

BLOCK = os.path.join(ROOT, "hashline", "src", "private_block")
LAYOUT_RS = os.path.join(BLOCK, "layout.rs")
ARGUMENT_RS = os.path.join(BLOCK, "argument.rs")
PROTOCOL_RS = os.path.join(BLOCK, "protocol.rs")

HAVE_SOURCE = all(os.path.exists(p) for p in (LAYOUT_RS, ARGUMENT_RS, PROTOCOL_RS))

# The DESIGN's headline numbers, restated here so the test does not merely agree with the
# driver's own table (ZK60_PRIVATE_BLOCK_CONSTRUCTION_TIER2_CHECK.md section 5.2).
DESIGN = {
    "a_rows": 455, "a_data_rows": 213, "a_site_pair_rows": 240,
    "h_rows": 384, "h_data_rows": 280, "h_site_pair_rows": 102,
    "A_sites": 120, "H_sites": 51,
    "A_groups_derived": 35, "H_groups_derived": 9,
    "n_slots": 23, "n_hosts": 6,
    "M_ROWS": 50, "N_FUNCTIONALS": 34, "largest_L": 50,
    "U8_lookups": 61440, "exp_lookups": 2048, "act_lookups": 512,
    "main_rounds_total": 159, "ext_rounds_total": 25,
    "sum_main_ext_times_degree_plus_1": 721, "terminals": 173,
}
DESIGN_HOST_SUM_L = {"SC_TZC": 84, "SC_DZC": 66, "SC_QZC": 70, "SC_KVZC": 62, "SC_SZC": 100,
                     "SC_FZC": 66}
DESIGN_HOST_RANK = {"SC_TZC": 81, "SC_DZC": 63, "SC_QZC": 67, "SC_KVZC": 59, "SC_SZC": 97,
                    "SC_FZC": 63}
DESIGN_STANDALONE = {"SC_SS": 31, "SC_SSM": 31, "SC_TZC": 19, "SC_LZC": 41, "SC_RS": 37,
                     "SC_QMM": 11, "SC_KMM": 11, "SC_VMM": 11, "SC_SCORE": 11, "SC_PV": 15,
                     "SC_WO": 11, "SC_GMM": 11, "SC_UMM": 11, "SC_DMM": 11, "SC_DZC": 41,
                     "SC_QZC": 41, "SC_KVZC": 37, "SC_SZC": 49, "SC_FZC": 41, "SC_TAB": 28,
                     "SC_ZS": 19, "SC_IO_IN": 21, "SC_IO_OUT": 21}
OWED_SHARING = ["A_H16_shares_A_U16_pair_with_values_n4",
                "A_YM_shares_A_Y_pair_with_values_n4"]
OWED_POSITIVE = ["A_H16_own_pair_not_A_U16_pair_with_values_n4",
                 "A_YM_own_pair_not_A_Y_pair_with_values_n4"]


def _committed():
    spec = importlib.util.spec_from_file_location("zk60_attention_native_inventory_probe",
                                                  COMMITTED)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


# ---------------------------------------------------------------------------
# 1. the adapters are load-bearing
# ---------------------------------------------------------------------------


@unittest.skipUnless(HAVE_SOURCE, "hashline/src/private_block is not present")
class TestAdaptersAreNeeded(unittest.TestCase):
    """Each adapter exists because the committed tool, unchanged, cannot read the block's Rust.
    If any of these stops raising, the corresponding adapter has become dead and the run's
    report of it would be false."""

    @classmethod
    def setUpClass(cls):
        cls.INV = _committed()
        with open(LAYOUT_RS) as f:
            cls.layout_src = f.read()
        with open(ARGUMENT_RS) as f:
            cls.argument_src = f.read()
        with open(PROTOCOL_RS) as f:
            cls.protocol_src = f.read()

    def test_layout_rs_parses_with_the_committed_class(self):
        """Only `define` and `logup_sum_claim` need adapters; layout.rs itself does not."""
        lay = self.INV.Layout(self.layout_src)
        self.assertEqual(lay.n_slots, 23)
        self.assertEqual(lay.a_rows, DESIGN["a_rows"])
        self.assertEqual(lay.h_rows, DESIGN["h_rows"])

    def test_committed_define_parser_fails_on_the_block(self):
        lay = self.INV.Layout(self.layout_src)
        with self.assertRaises(self.INV.RustParseError):
            self.INV.DefineParser(lay, self.argument_src).parse()

    def test_committed_logup_parser_fails_on_the_block(self):
        lay = self.INV.Layout(self.layout_src)
        with self.assertRaises(self.INV.RustParseError):
            self.INV.parse_logup_sum(self.protocol_src, lay)

    def test_adapted_parser_reads_every_site(self):
        lay = PB.BlockLayout(self.INV, self.layout_src)
        parser = PB.make_block_define_parser(self.INV)(lay, self.argument_src)
        sites = parser.parse()
        n_a = sum(1 for s in range(lay.n_slots) for x in sites[s] if x.cm == "A")
        n_h = sum(1 for s in range(lay.n_slots) for x in sites[s] if x.cm == "H")
        self.assertEqual(n_a, DESIGN["A_sites"])
        self.assertEqual(n_h, DESIGN["H_sites"])
        for s in range(lay.n_slots):
            self.assertEqual(sum(1 for x in sites[s] if x.cm == "A"), lay.a_sites[s],
                             lay.slot_name_of[s])
            self.assertEqual(sum(1 for x in sites[s] if x.cm == "H"), lay.h_sites[s],
                             lay.slot_name_of[s])
        self.assertEqual(sorted(parser.adapters_used), ["B-1", "B-2", "B-3"])

    def test_logup_adapter_finds_the_three_table_helpers(self):
        lay = PB.BlockLayout(self.INV, self.layout_src)
        src, rec = PB.normalise_logup_source(self.INV, self.protocol_src, self.layout_src)
        self.assertEqual(rec["h_is_table_planes"], ["H_GU8", "H_GEXP", "H_GACT"])
        got = self.INV.parse_logup_sum(src, lay)
        self.assertEqual(got["planes"], lay.n_h)
        self.assertEqual(got["value"], 0)
        self.assertEqual(got["negated_planes"],
                         sorted(lay.consts[p] for p in ("H_GU8", "H_GEXP", "H_GACT")))

    def test_logup_adapter_refuses_an_unexpected_layout_body(self):
        broken = self.layout_src.replace("matches!(plane, H_GU8 | H_GEXP | H_GACT)",
                                         "plane > 46 && plane < 50")
        self.assertNotEqual(broken, self.layout_src)
        with self.assertRaises(self.INV.RustParseError):
            PB.normalise_logup_source(self.INV, self.protocol_src, broken)

    def test_limb_off_m_matches_layout_arithmetic(self):
        lay = PB.BlockLayout(self.INV, self.layout_src)
        for k in range(lay.consts["N_LIMBS"]):
            self.assertEqual(lay.limb_off_m(k),
                             lay.a_off[lay.consts["A_LIMBM"]] + k * lay.consts["T"])


# ---------------------------------------------------------------------------
# 2 + 3. the end-to-end run
# ---------------------------------------------------------------------------


@unittest.skipUnless(HAVE_SOURCE, "hashline/src/private_block is not present")
class TestEndToEnd(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.mkdtemp(prefix="zk60-private-block-tools-")
        cls.rc = PB.main(["--repo", ROOT, "--out-dir", cls.tmp])
        with open(os.path.join(cls.tmp, "zk60_private_block_summary.json")) as f:
            cls.s = json.load(f)

    @classmethod
    def tearDownClass(cls):
        shutil.rmtree(cls.tmp, ignore_errors=True)

    def _load(self, name):
        with open(os.path.join(self.tmp, name)) as f:
            return json.load(f)

    # ---- the run itself --------------------------------------------------
    def test_exit_code_and_done_marker(self):
        self.assertEqual(self.rc, 0)
        with open(os.path.join(self.tmp, "zk60_private_block_inventory.done")) as f:
            self.assertEqual(f.read().strip(), "0")

    def test_every_record_is_written(self):
        for name in ("zk60_private_block_inventory.json", "zk60_private_block_hosts.json",
                     "zk60_private_block_pair_schedule.json", "zk60_private_block_schedule.json",
                     "zk60_private_block_cfs_slots.json", "zk60_private_block_summary.json",
                     "zk60_private_block_inventory.log",
                     "zk60_private_block_inventory.done"):
            self.assertTrue(os.path.exists(os.path.join(self.tmp, name)), name)
        log = open(os.path.join(self.tmp, "zk60_private_block_inventory.log")).read()
        self.assertIn("failures: none", log)
        self.assertIn("CAVEAT:", log)

    def test_no_failures(self):
        self.assertEqual(self.s["failures"], [])
        self.assertTrue(self.s["all_pass"])

    def test_the_accepted_attention_verdict_reproduces(self):
        sc = self.s["self_check_accepted_attention"]
        self.assertEqual(sc["n_cross_checks"], 29)
        self.assertEqual(sc["n_cross_checks_pass"], 29)
        self.assertEqual(sc["failures"], [])
        self.assertTrue(sc["all_pass"])
        self.assertTrue(sc["reproduced_the_accepted_verdict"])
        # the accepted component's own derived numbers, unmoved
        self.assertEqual(sc["A_sites"], 75)
        self.assertEqual(sc["H_sites"], 35)
        self.assertEqual(sc["A_groups"], 30)
        self.assertEqual(sc["H_groups"], 8)

    # ---- the counts ------------------------------------------------------
    def test_every_derived_count_equals_the_design(self):
        bad = [c for c in self.s["derived_vs_design"] if not c["pass"]]
        self.assertEqual(bad, [], "counts that disagree with the design")
        self.assertGreaterEqual(len(self.s["derived_vs_design"]), 40)

    def test_headline_counts_against_the_design_restated_here(self):
        c = self.s["derived_counts"]
        for k, want in DESIGN.items():
            self.assertEqual(c[k], want, k)
        self.assertEqual(c["A_GROUPS_declared"], DESIGN["A_groups_derived"])
        self.assertEqual(c["H_GROUPS_declared"], DESIGN["H_groups_derived"])
        self.assertEqual(c["slot_kinds"], {"Private": 12, "Standalone": 5, "Host": 6})
        self.assertEqual(c["hosts_by_index"],
                         {"2": [0, 1], "14": [10, 13], "15": [5, 9], "16": [6, 7],
                          "17": [4, 8], "18": [11, 12]})
        # the row arithmetic must close on itself, not only against the memo
        self.assertEqual(c["a_rows"], c["a_data_rows"] + c["a_site_pair_rows"] + 2)
        self.assertEqual(c["h_rows"], c["h_data_rows"] + c["h_site_pair_rows"] + 2)
        self.assertEqual(c["a_site_pair_rows"], 2 * c["A_sites"])
        self.assertEqual(c["h_site_pair_rows"], 2 * c["H_sites"])

    def test_inventory_is_shaped_for_both_tools(self):
        inv = self._load("zk60_private_block_inventory.json")
        claims = inv["A1_schedule"]["claims"]
        self.assertEqual(len(claims), DESIGN["A_sites"] + DESIGN["H_sites"] + 1)
        for i, c in enumerate(claims):
            self.assertEqual(c["index"], i)
            if not c["sum_claim"]:
                self.assertEqual(c["data_rows"], 1 << (c["log_size"] - 8))
        p1 = inv["A2_cfs_slots"]["P1"]
        self.assertEqual(len(p1), DESIGN["n_slots"])
        for s in p1:
            self.assertEqual(s["n_vars"], s["main_rounds"] + s["ext_rounds"])
            self.assertEqual(s["cfs_len"], s["n_vars"] * s["degree"] + 2)
        tables = {t["table"] for t in inv["A1_schedule"]["logup_tables"]}
        self.assertEqual(tables, {"U8", "exp", "act"})

    def test_schedule_rows_are_the_layouts_rows(self):
        sch = self._load("zk60_private_block_schedule.json")
        self.assertEqual(sch["A"]["rows_total"], DESIGN["a_rows"])
        self.assertEqual(sch["H"]["rows_total"], DESIGN["h_rows"])

    # ---- the rank verdicts ------------------------------------------------
    def test_disclosed_dimensions(self):
        r = self._load("zk60_private_block_pair_schedule.json")["rank_verdicts"]
        self.assertEqual(r["whole_A_per_column"]["disclosed_dim"], 0)
        self.assertEqual(r["whole_A_with_values_n4"]["disclosed_dim"], 0)
        self.assertEqual(r["whole_H_per_column"]["disclosed_dim"], 0)
        a_groups = {k: v["disclosed_dim"] for k, v in r.items() if k.startswith("group_A_")}
        h_groups = {k: v["disclosed_dim"] for k, v in r.items() if k.startswith("group_H_")}
        self.assertEqual(len(a_groups), DESIGN["A_groups_derived"])
        # the tool models 7 of the 9 derived H groups: it builds the SC_ZS site and the sum
        # group itself (committed adaptation R-4), the same offset of 2 as on the paper run
        self.assertEqual(len(h_groups), DESIGN["H_groups_derived"] - 2)
        self.assertEqual(sorted(set(a_groups.values())), [0])
        self.assertEqual(sorted(set(h_groups.values())), [0])
        eps = {k: v["disclosed_dim"] for k, v in r.items() if k.startswith("endpoint_")}
        self.assertEqual(eps, {"endpoint_In_with_values_n4": 0,
                               "endpoint_Out_with_values_n4": 0})

    def test_whole_H_residual_is_exactly_the_public_identity(self):
        r = self._load("zk60_private_block_pair_schedule.json")["rank_verdicts"]
        for n in (4, 8):
            v = r[f"whole_H_with_values_n{n}"]
            self.assertEqual(v["disclosed_dim"], 2, n)
            self.assertTrue(v["residual_is_exactly_the_public_identity"], n)
            self.assertEqual(v["verdict"], "PASS", n)

    def test_every_all_pair_A_group_satisfies_the_FA2_rank_mask_formula(self):
        f = self.s["rank_summary"]["fa2_rank_mask_formula_all_pair_groups"]
        self.assertEqual(len(f), DESIGN["A_groups_derived"])
        self.assertTrue(all(f.values()), [k for k, v in f.items() if not v])

    # ---- the CFS verdicts -------------------------------------------------
    def test_host_groups(self):
        c = self._load("zk60_private_block_cfs_slots.json")
        self.assertEqual(len(c["host_groups"]), DESIGN["n_hosts"])
        for h, v in c["host_groups"].items():
            k = len(v["hosted"])
            self.assertEqual(k, 2, h)
            self.assertEqual(v["rank_map"], v["sum_L"] - (k + 1), h)
            self.assertEqual(v["dim_consistency_subspace"], v["rank_map"], h)
            self.assertEqual(v["kernel_dim_fp2"], 3, h)
            self.assertEqual(v["leaked_dim_fp2"], 0, h)
            self.assertTrue(v["pass"], h)
            self.assertFalse(v["hosted_after_host_in_transcript"], h)
        self.assertEqual({h: v["sum_L"] for h, v in c["host_groups"].items()},
                         DESIGN_HOST_SUM_L)
        self.assertEqual({h: v["rank_map"] for h, v in c["host_groups"].items()},
                         DESIGN_HOST_RANK)

    def test_standalone_slots(self):
        c = self._load("zk60_private_block_cfs_slots.json")
        self.assertEqual(len(c["standalone"]), DESIGN["n_slots"])
        for s, v in c["standalone"].items():
            self.assertEqual(v["rank_map"], v["n_vars"] * v["degree"] + 1, s)
            self.assertEqual(v["dim_consistency_subspace"], v["rank_map"], s)
            self.assertEqual(v["leaked_dim_fp2"], 0, s)
            self.assertEqual(v["kernel_dim_fp2"], 1, s)
            self.assertTrue(v["pass"], s)
        self.assertEqual({s: v["dim_consistency_subspace"] for s, v in c["standalone"].items()},
                         DESIGN_STANDALONE)

    def test_slot_lengths_fit_the_mask_budget(self):
        c = self._load("zk60_private_block_cfs_slots.json")
        self.assertEqual(len(c["slot_table"]), DESIGN["n_slots"])
        for r in c["slot_table"]:
            self.assertLessEqual(r["len"] + 256, 512, r["slot"])
        self.assertEqual(c["largest_slot"]["slot"], "SC_SZC")
        self.assertEqual(c["largest_slot"]["len"], DESIGN["largest_L"])
        self.assertEqual(c["m_layout"]["n_rows"], DESIGN["M_ROWS"])
        self.assertEqual(c["m_layout"]["n_functionals"], DESIGN["N_FUNCTIONALS"])
        self.assertTrue(c["all_checks_pass"], [x for x in c["checks"] if not x["pass"]])

    # ---- the negative controls -------------------------------------------
    def test_every_rank_negative_control_fires(self):
        nc = self._load("zk60_private_block_pair_schedule.json")["rank_verdicts"]["negative_controls"]
        self.assertGreaterEqual(len(nc), 15)
        for k, v in nc.items():
            self.assertEqual(v["verdict"], "PASS", f"{k}: {v}")
        # the accepted eleven, with the values the paper whole-block run measured
        self.assertGreaterEqual(nc["no_mask_A_per_column"]["disclosed_dim"], 30)
        self.assertGreaterEqual(nc["no_mask_A_with_values_n4"]["disclosed_dim"],
                                2 * DESIGN["A_sites"])
        self.assertEqual(nc["single_prox_row_singleton_pair_claim_per_column"]["disclosed_dim"], 1)
        self.assertEqual(nc["prox_pair_singleton_pair_claim_per_column"]["disclosed_dim"], 0)
        self.assertGreater(nc["zero_sum_row_without_fresh_pair_n4"]["disclosed_dim"], 2)
        for s in ("SC_QZC", "SC_KVZC"):
            self.assertGreaterEqual(
                nc[f"flipped_rope_{s}_sharing_pair_with_values_n4"]["disclosed_dim"], 2)
            self.assertEqual(
                nc[f"flipped_rope_{s}_own_pair_with_values_n4"]["disclosed_dim"], 0)

    def test_the_two_owed_negative_controls_fire(self):
        nc = self._load("zk60_private_block_pair_schedule.json")["rank_verdicts"]["negative_controls"]
        for k in OWED_SHARING:
            self.assertIn(k, nc)
            self.assertGreaterEqual(nc[k]["disclosed_dim"], 2, k)
            self.assertEqual(nc[k]["verdict"], "PASS", k)
        for k in OWED_POSITIVE:
            self.assertEqual(nc[k]["disclosed_dim"], 0, k)
            self.assertEqual(nc[k]["verdict"], "PASS", k)
        self.assertEqual(
            sorted(self._load("zk60_private_block_pair_schedule.json")["owed_negative_controls"]),
            sorted(OWED_SHARING + OWED_POSITIVE))

    def test_every_cfs_negative_control_fires(self):
        c = self._load("zk60_private_block_cfs_slots.json")
        nc = {k: v for k, v in c["negative_controls"].items()
              if isinstance(v, dict) and "pass" in v}
        self.assertEqual(len(nc), 7)
        for k, v in nc.items():
            self.assertTrue(v["pass"], k)
        self.assertTrue(c["r7_extension_check"]["pass"])

    # ---- the gates, the paper comparison, the caveat ----------------------
    def test_every_gate_passes(self):
        bad = [g["name"] for g in self.s["gates"] if not g["pass"]]
        self.assertEqual(bad, [])
        self.assertGreaterEqual(len(self.s["gates"]), 10)

    def test_paper_comparison_has_no_difference(self):
        cmpn = self.s["paper_comparison"]
        self.assertTrue(cmpn["available"], "the paper whole-block summary was not found")
        self.assertEqual(cmpn["differences"], [])
        self.assertGreaterEqual(cmpn["n_agree"], 60)
        # the only items absent from the paper run are the four the paper could not wire
        self.assertEqual(sorted(x["item"].rsplit("/", 1)[-1]
                                for x in cmpn["only_in_this_run"]),
                         sorted(OWED_SHARING + OWED_POSITIVE))

    def test_the_summary_carries_the_caveat_and_the_adapters(self):
        self.assertIn("LINEAR-ALGEBRA MODEL", self.s["caveat"])
        self.assertIn("NOTHING here establishes a privacy property", self.s["caveat"])
        self.assertTrue(self.s["not_established"])
        self.assertEqual(sorted(self.s["adapters_used_by_the_define_parser"]),
                         ["B-1", "B-2", "B-3"])
        self.assertTrue(any(a.startswith("B-4") for a in self.s["adapters"]))
        ids = [f["id"] for f in self.s["findings"]]
        for i in ("B-F0", "B-F1", "B-F2", "B-F3", "B-F4", "B-F5"):
            self.assertIn(i, ids)


# ---------------------------------------------------------------------------
# 4. a deliberately wrong expectation must make the run fail
# ---------------------------------------------------------------------------


@unittest.skipUnless(HAVE_SOURCE, "hashline/src/private_block is not present")
class TestWrongExpectationFails(unittest.TestCase):
    def test_cross_checks_catch_a_wrong_expectation(self):
        INV = _committed()
        with open(LAYOUT_RS) as f:
            lay = PB.BlockLayout(INV, f.read())
        with open(ARGUMENT_RS) as f:
            sites = PB.make_block_define_parser(INV)(lay, f.read()).parse()
        with open(PROTOCOL_RS) as f:
            protocol_src = f.read()
        with open(LAYOUT_RS) as f:
            logup_src, _ = PB.normalise_logup_source(INV, protocol_src, f.read())
        inv = INV.build_inventory(lay, sites, {}, ROOT, protocol_src=logup_src)

        good = PB.block_cross_checks(INV, lay, inv, PB.BLOCK_EXPECT)
        self.assertEqual([c["name"] for c in good if not c["pass"]], [])

        for key, wrong, name in (("A_rows", 456, "A rows"),
                                 ("A_GROUPS", 34, "A opening groups (derived from the PCS "
                                                  "key rule)"),
                                 ("act_lookups", 511, "act lookups"),
                                 ("N_FUNCTIONALS", 33, "N_FUNCTIONALS declared in layout.rs")):
            expect = copy.deepcopy(PB.BLOCK_EXPECT)
            expect[key] = wrong
            bad = [c for c in PB.block_cross_checks(INV, lay, inv, expect) if not c["pass"]]
            self.assertTrue(bad, f"a wrong {key} was not caught")
            self.assertIn(name, [c["name"] for c in bad], key)

    def test_the_driver_fails_end_to_end_on_a_wrong_expectation(self):
        tmp = tempfile.mkdtemp(prefix="zk60-private-block-wrong-")
        try:
            expect = copy.deepcopy(PB.BLOCK_EXPECT)
            expect["A_rows"] = 456                      # the design says 455
            expect["host_rank"] = dict(expect["host_rank"], SC_FZC=64)   # the design says 63
            s = PB.build_all(ROOT, tmp, seed=2026, expect=expect, self_check=False)
            self.assertFalse(s["all_pass"])
            self.assertIn("count/A rows", s["failures"])
            self.assertIn("gate/host sum L / rank match the design", s["failures"])
            f0 = next(f for f in s["findings"] if f["id"] == "B-F0")
            self.assertEqual(f0["severity"], "MISMATCH")
            self.assertEqual(f0["mismatches"][0]["derived_from_the_rust"], 455)
            self.assertEqual(f0["mismatches"][0]["design_says"], 456)
        finally:
            shutil.rmtree(tmp, ignore_errors=True)


if __name__ == "__main__":
    unittest.main()
