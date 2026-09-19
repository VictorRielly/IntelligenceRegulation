"""Tests for scripts/zk60_attention_cfs_slots.py: the eighteen-slot attention CFS
tables, FA6's criterion standalone and on the host groups (default and SMHOST
variants), the M layout and functional order, the R7 extension-round check, the
negative controls and the CLI.  Owner: Claude Fable 5.1, 2026-09-16.

    python3 -m unittest discover -s tests -p 'test_zk60_attention_cfs_slots.py' -v
"""
import importlib.util
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts/zk60_attention_cfs_slots.py"
INVENTORY = ROOT / "results/zk60_opus_attention_inventory.json"

SPEC = importlib.util.spec_from_file_location("attention_cfs_slots", SCRIPT)
M = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(M)
C = M.C
ONE, ZERO = M.ONE, M.ZERO

REPORT = None
INV = None


def setUpModule():
    global REPORT, INV
    with open(INVENTORY) as f:
        INV = json.load(f)
    REPORT = M.build_report(INVENTORY, seed=60)


def copy_default_hosts():
    return json.loads(json.dumps(M.DEFAULT_HOSTS))


class SlotTables(unittest.TestCase):
    def test_eighteen_slots_in_transcript_order_P1_P3(self):
        for mode in ("P1", "P3"):
            table = M.build_slot_table(INV, mode)
            self.assertEqual(len(table), 18)
            self.assertEqual([r["slot"] for r in table], M.TRANSCRIPT_ORDER)
            self.assertEqual([r["index"] for r in table], list(range(18)))
            roles = {r["slot"]: r["role"] for r in table}
            for a in M.ADDED_SLOTS:
                self.assertEqual(roles[a["slot"]], "public-zero standalone")
            self.assertEqual(sum(r["private"] for r in table), 8)     # 00, 06, 08Q, 08K, 08V, 09, 10, 11
            for r in table:
                self.assertEqual(r["len"], M.cfs_len(r["n_vars"], r["degree"]))
                self.assertEqual(r["main_rounds"], r["n_vars"] - r["ext_rounds"])
                self.assertEqual(r["dim_S_expected"], r["n_vars"] * r["degree"] + 1)

    def test_split_and_two_extension_shapes(self):
        for mode, (n, d, e) in M.SPLIT_SHAPE.items():
            by = {r["slot"]: r for r in M.build_slot_table(INV, mode)}
            for s in ("SC_ATTN_08Q", "SC_ATTN_08K", "SC_ATTN_08V"):
                self.assertEqual((by[s]["n_vars"], by[s]["degree"], by[s]["ext_rounds"]), (n, d, e), (mode, s))
                self.assertTrue(by[s]["private"])
                self.assertEqual(by[s]["split_of"], "SC_ATTN_08")
            self.assertNotIn("SC_ATTN_08", by)
            self.assertEqual((by["SC_ATTN_09"]["n_vars"], by["SC_ATTN_09"]["degree"], by["SC_ATTN_09"]["ext_rounds"]), (5, 3, 2))
            self.assertEqual((by["SC_ATTN_10"]["n_vars"], by["SC_ATTN_10"]["degree"], by["SC_ATTN_10"]["ext_rounds"]), (7, 3, 2))
            self.assertEqual((by["SC_ATTN_TAB"]["n_vars"], by["SC_ATTN_TAB"]["degree"]), (17, 3))
            self.assertEqual((by["SC_ATTN_ZS"]["n_vars"], by["SC_ATTN_ZS"]["degree"]), (9, 2))
            self.assertEqual((by["SC_ATTN_IO_IN"]["n_vars"], by["SC_ATTN_IO_IN"]["degree"]), (10, 2))
            self.assertEqual((by["SC_ATTN_IO_OUT"]["n_vars"], by["SC_ATTN_IO_OUT"]["degree"]), (10, 2))
            # the P3 rule touches only the two weight matmuls (split Q/K/V and Wo)
            self.assertEqual(by["SC_ATTN_11"]["n_vars"], n)

    def test_row_budget_and_largest(self):
        for mode in ("P1", "P3"):
            table = M.build_slot_table(INV, mode)
            self.assertTrue(all(r["len"] + 256 <= 512 for r in table))
            big = M.largest_slot(table)
            self.assertEqual((big["slot"], big["len"], big["headroom_coefficients"]), ("SC_ATTN_05", 62, 194))
        self.assertEqual(M.check_row_budget("x", 12, 5), 62)
        self.assertEqual(M.check_row_budget("x", 50, 5), 252)     # 252 + 256 = 508 <= 512
        with self.assertRaises(ValueError):
            M.check_row_budget("x", 51, 5)                         # 257 + 256 > 512
        bad = json.loads(json.dumps(INV))
        for e in bad["A2_cfs_slots"]["P1"]:
            if e["slot"] == "SC_ATTN_05":
                e["n_vars"] = 51
        with self.assertRaises(ValueError):
            M.build_slot_table(bad, "P1")

    def test_host_mapping_validation(self):
        table = M.build_slot_table(INV, "P1")
        self.assertEqual(M.validate_hosts(table, M.DEFAULT_HOSTS), [])
        h = copy_default_hosts()
        h["hosts"]["SC_ATTN_02"] = []                              # SC_ATTN_11 unhosted
        errs = M.validate_hosts(table, h)
        self.assertTrue(any("SC_ATTN_11 is not hosted" in e for e in errs), errs)
        h = copy_default_hosts()
        h["hosts"]["SC_ATTN_02"] = ["SC_ATTN_11", "SC_ATTN_07"]    # hosting a public-zero slot
        self.assertTrue(any("public-zero" in e for e in M.validate_hosts(table, h)))
        h = copy_default_hosts()
        h["hosts"]["SC_ATTN_02"] = ["SC_ATTN_11", "SC_ATTN_00"]    # hosted twice
        self.assertTrue(any("hosted twice" in e for e in M.validate_hosts(table, h)))
        h = copy_default_hosts()
        h["hosts"]["SC_ATTN_00"] = ["SC_ATTN_06"]                  # a private slot as host
        self.assertTrue(any("must have a public claimed sum" in e for e in M.validate_hosts(table, h)))
        h = copy_default_hosts()
        h["hosts"]["SC_ATTN_99"] = ["SC_ATTN_11"]
        self.assertTrue(any("not a slot" in e for e in M.validate_hosts(table, h)))
        with self.assertRaises(ValueError):
            M.build_slot_table(INV, "P1", h)
        # the SMHOST alternative is a valid mapping with nineteen slots and its host right after its hosted slots
        alt = M.build_slot_table(INV, "P1", M.SMHOST_HOSTS)
        order = [r["slot"] for r in alt]
        self.assertEqual(len(alt), 19)
        self.assertEqual(order.index("SC_ATTN_SMHOST"), order.index("SC_ATTN_06") + 1)
        self.assertEqual({r["slot"]: r["role"] for r in alt}["SC_ATTN_01"], "public-zero standalone")


class Standalone(unittest.TestCase):
    def test_fa6_criterion_every_slot(self):
        for mode in ("P1", "P3"):
            sa = REPORT["standalone"][mode]
            self.assertEqual(set(sa), set(M.TRANSCRIPT_ORDER))
            for s, v in sa.items():
                exp = v["n_vars"] * v["degree"] + 1
                self.assertEqual(v["rank_map"], exp, (mode, s))
                self.assertEqual(v["dim_consistency_subspace"], exp, (mode, s))
                self.assertTrue(v["image_inside_subspace"], (mode, s))
                self.assertEqual(v["leaked_dim_fp2"], 0, (mode, s))
                self.assertEqual(v["kernel_dim_fp2"], 1, (mode, s))
                self.assertTrue(all(v["m_functionals_in_view_span"].values()), (mode, s))
                self.assertTrue(v["theta_combination_in_view_span"], (mode, s))
                self.assertTrue(v["pass"], (mode, s))
        # P3 only changes the split slots and Wo
        p1, p3 = REPORT["standalone"]["P1"], REPORT["standalone"]["P3"]
        for s in M.TRANSCRIPT_ORDER:
            if s in ("SC_ATTN_08Q", "SC_ATTN_08K", "SC_ATTN_08V", "SC_ATTN_11"):
                self.assertEqual(p3[s]["rank_map"], p1[s]["rank_map"] + 2)
            else:
                self.assertEqual(p3[s]["rank_map"], p1[s]["rank_map"])


class HostGroups(unittest.TestCase):
    def test_default_and_smhost_groups(self):
        for label, hosts_spec in (("default", M.DEFAULT_HOSTS), ("smhost", M.SMHOST_HOSTS)):
            rv = REPORT["host_variants"][label]
            self.assertEqual(rv["mapping"]["hosts"], hosts_spec["hosts"])
            for mode in ("P1", "P3"):
                m = rv[mode]
                self.assertEqual(set(m["groups"]), set(hosts_spec["hosts"]))
                for host, g in m["groups"].items():
                    k = len(g["hosted"])
                    self.assertEqual(g["hosted"], hosts_spec["hosts"][host])
                    self.assertEqual(g["rank_map"], g["sum_L"] - (k + 1), (label, mode, host))
                    self.assertEqual(g["dim_consistency_subspace"], g["sum_L"] - (k + 1), (label, mode, host))
                    self.assertEqual(g["kernel_dim_fp2"], k + 1, (label, mode, host))
                    self.assertEqual(g["leaked_dim_fp2"], 0, (label, mode, host))
                    self.assertTrue(g["image_inside_subspace"])
                    self.assertTrue(all(g["m_functionals_in_view_span"].values()))
                    self.assertTrue(g["theta_combination_in_view_span"])
                    self.assertTrue(g["relabelling"]["pass"], g["relabelling"])
                    self.assertTrue(g["f_part_round0"]["consistent"], g["f_part_round0"])
                    self.assertEqual(g["hosted_after_host_in_transcript"], [], (label, mode, host))
                    self.assertTrue(g["pass"])
                for s, g in m["public_standalone"].items():
                    self.assertTrue(g["pass"], (label, mode, s))
                self.assertTrue(m["all_pass"])
            self.assertEqual(rv["P1"]["n_slots"], 18 if label == "default" else 19)
        # the two variants differ exactly in who hosts the two sum claims
        d5 = REPORT["host_variants"]["default"]["P1"]["groups"]["SC_ATTN_05"]
        a5 = REPORT["host_variants"]["smhost"]["P1"]["groups"]["SC_ATTN_05"]
        self.assertEqual(d5["hosted"], ["SC_ATTN_06", "SC_ATTN_09"])
        self.assertEqual(a5["hosted"], ["SC_ATTN_09"])
        self.assertEqual(REPORT["host_variants"]["smhost"]["P1"]["groups"]["SC_ATTN_SMHOST"]["hosted"], ["SC_ATTN_00", "SC_ATTN_06"])
        self.assertIn("SC_ATTN_01", REPORT["host_variants"]["smhost"]["P1"]["public_standalone"])

    def test_system_hosted_direct(self):
        table = M.build_slot_table(INV, "P1")
        slots = M.slots_dict(table)
        rng = M.Rng(7)
        ch, meta = M.system_hosted(slots, "SC_ATTN_04", ["SC_ATTN_08K", "SC_ATTN_08V"], rng)
        self.assertEqual(ch.n_unk, 38 + 12 + 12)
        self.assertEqual(len(ch.view_rows), (1 + 5 * 3) * 2 + (1 + 9 * 5))
        self.assertEqual(len(ch.cons), 5 + 5 + 9)
        res = M.analyze_hosted(ch, meta, slots)
        self.assertEqual((res["rank_map"], res["dim_consistency_subspace"], res["kernel_dim_fp2"], res["leaked_dim_fp2"]), (59, 59, 3, 0))
        # Gamma's row is exactly the host sum row minus sum_i nu_i (claim row i)
        recon = list(meta["host_sum_row"])
        for s in meta["hosted"]:
            recon = ch.row_add(recon, [C.f2_mul(C.f2_neg(meta["nu"][s]), x) for x in meta["claim_rows"][s]])
        self.assertEqual(recon, meta["gamma_row"])
        self.assertTrue(res["relabelling"]["pass"])
        # the host's round-0 relation references sum_i nu_i claim_i + Gamma
        c0 = ch.cons[[i for i, n in enumerate(ch.cons_names) if n == "SC_ATTN_04.h0(0)+h0(1)=claim"][0]]
        for s in meta["hosted"]:
            self.assertEqual(c0[meta["claim_idx"][s]], C.f2_neg(meta["nu"][s]))
        self.assertEqual(c0[meta["gamma_idx"]], C.f2_neg(ONE))
        # the f-part of the host's claimed sum is sum_i nu_i s_i
        self.assertEqual(meta["host_f_total"], {f"s_{s}": meta["nu"][s] for s in meta["hosted"]})
        # generalises FA6's pair: k = 1 reproduces system_batched_pair's numbers on the FFN-like shapes
        ffn = C._finish({"SC_GU": {"n_vars": 5, "degree": 2, "ext_rounds": 1}, "SC_ZC20": {"n_vars": 6, "degree": 4, "ext_rounds": 1}})
        ch1, meta1 = C.system_batched_pair(ffn, "SC_GU", "SC_ZC20", M.Rng(3))
        r1 = C.analyze_system(ch1, meta1)
        ch2, meta2 = M.system_hosted(ffn, "SC_ZC20", ["SC_GU"], M.Rng(3))
        r2 = M.analyze_hosted(ch2, meta2, ffn)
        for k in ("n_unknowns_fp2", "n_view_fp2", "rank_map", "dim_consistency_subspace", "kernel_dim_fp2", "leaked_dim_fp2"):
            self.assertEqual(r1[k], r2[k], k)


class MLayout(unittest.TestCase):
    def test_rows_and_functionals(self):
        for label, n_slots in (("default", 18), ("smhost", 19)):
            for mode in ("P1", "P3"):
                lay = REPORT["m_layout"][label][mode]
                self.assertEqual(lay["n_rows"], 2 * n_slots + 4)
                a_rows = [r for r in lay["rows"] if r["slot"] is not None]
                self.assertEqual(len(a_rows), 2 * n_slots)
                for r in a_rows:
                    self.assertEqual(r["pads"], 256)
                    self.assertEqual(r["coefficients"] + r["pads"] + r["zeros"], 512)
                self.assertEqual([r["name"] for r in lay["rows"][-4:]], ["b_re", "b_im", "u_re", "u_im"])
                self.assertEqual(lay["largest"]["len"], 62)
                fs = lay["mask_functionals"]
                self.assertEqual([f["index"] for f in fs], list(range(len(fs))))
                evals = [f for f in fs if f["kind"] == "eval"]
                gammas = [f for f in fs if f["kind"] == "gamma"]
                batched = [f for f in fs if f["kind"] == "gamma_batched"]
                self.assertEqual(len(evals) + len(gammas) + len(batched), len(fs))
                self.assertEqual([f["slots"][0] for f in evals], REPORT["host_variants"][label][mode]["slot_order"])
                hosts = REPORT["host_variants"][label]["mapping"]["hosts"]
                order = REPORT["host_variants"][label][mode]["slot_order"]
                self.assertEqual([f["slots"][0] for f in batched], sorted(hosts, key=order.index))
                for f in batched:
                    self.assertEqual(f["slots"][1:], hosts[f["slots"][0]])
                    self.assertIn("sum_weights", f["weights"])
                    self.assertIn("-nu_", f["weights"])
                roles = REPORT["host_variants"][label][mode]["roles"]
                self.assertEqual({f["slots"][0] for f in gammas}, {s for s, r in roles.items() if r == "public-zero standalone"})
                # a slot's Sigma-type functional (when it has one) precedes its eval; the batched Gammas come last
                for f in gammas:
                    self.assertEqual(fs[f["index"] + 1]["kind"], "eval")
                    self.assertEqual(fs[f["index"] + 1]["slots"], f["slots"])
                self.assertTrue(all(f["kind"] == "gamma_batched" for f in fs[len(fs) - len(batched):]))
                self.assertEqual(lay["n_functionals"], 28 if label == "default" else 30)
        # the kinds are the round-2 tool's FUNCTIONAL_ASSIGNMENT vocabulary (gamma_pair generalised to gamma_batched)
        spec = importlib.util.spec_from_file_location("joint_cfs_view", ROOT / "scripts/zk60_joint_cfs_view.py")
        J = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(J)
        kinds = {f["kind"] for f in J.FUNCTIONAL_ASSIGNMENT}
        self.assertEqual(kinds, {"eval", "gamma", "gamma_pair"})
        pair = [f for f in J.FUNCTIONAL_ASSIGNMENT if f["kind"] == "gamma_pair"][0]
        self.assertIn("-nu0 c_gu sum_weights", pair["weights"])


class R7(unittest.TestCase):
    def test_extension_round_check(self):
        r7 = REPORT["r7_extension_check"]
        self.assertTrue(r7["pass"])
        self.assertTrue(r7["one_private_public_extends_to_zero"]["s_at_1_is_zero"])
        self.assertTrue(r7["one_private_public_extends_to_zero"]["one_minus_x_divides_s"])
        two = r7["two_private_public_factor_is_one_single_round"]
        self.assertFalse(two["s_at_1_is_zero"])
        self.assertTrue(two["s_at_1_equals_extA_extB"])
        self.assertFalse(two["one_minus_x_divides_s"])
        self.assertTrue(r7["two_private_with_public_factor_extending_to_zero"]["s_at_1_is_zero"])
        tr = r7["two_private_two_rounds_one_per_side"]
        self.assertTrue(tr["round_k_s_at_1_is_zero"] and tr["round_k_plus_1_s_at_1_is_zero"])
        self.assertTrue(tr["chain_s_k_at_e1_equals_s_k1_0_plus_s_k1_1"])
        # deterministic under another seed and with three main rounds; the model equals the Rust extension_round on a product poly
        r = M.r7_extension_check(M.Rng(5), n_main=3)
        self.assertTrue(r["pass"])
        rng = M.Rng(9)
        finals = [rng.fp2() for _ in range(3)]
        exts = [ZERO, rng.fp2(), rng.fp2()]
        vals = M.extension_round_values(list(zip(finals, exts)), 3)
        for x in range(4):
            v = [C.f2_add(f, C.f2_mul(M.f2(x), C.f2_sub(e, f))) for f, e in zip(finals, exts)]
            self.assertEqual(vals[x], C.f2_mul(v[0], C.f2_mul(v[1], v[2])))
        self.assertEqual(vals[1], ZERO)


class NegativeControls(unittest.TestCase):
    def test_each_control(self):
        for mode in ("P1", "P3"):
            nc = REPORT["negative_controls"][mode]
            self.assertTrue(nc["all_pass"])
            cz = nc["nc_hosted_c_zero"]
            self.assertTrue(cz["refused_by_the_tool_like_the_code"])
            self.assertEqual(cz["forced"]["leaked_dim_fp2"], 31)          # dim S of SC_ATTN_00 (10, 3)
            self.assertTrue(cz["forced"]["image_inside_subspace"])
            nz = nc["nc_host_nu_zero"]
            self.assertEqual(nz["criterion"]["leaked_dim_fp2"], 0)
            self.assertFalse(nz["host_f_total_contains_hosted_sum"])
            ed = nc["nc_extension_degree_exceeds_mask"]
            self.assertEqual(ed["criterion"]["leaked_dim_fp2"], 1)
            self.assertEqual(list(ed["leaked_functionals"][0]), ["SC_ATTN_01.h5(4)"])   # the clear top value of the (6, 3) host's last round
            u = nc["nc_qkv_unsplit"]
            self.assertTrue(u["pass"])
            a = u["a_one_scalar_two_hosts"]
            self.assertEqual(a["mask_channel"]["leaked_dim_fp2"], 0)
            self.assertFalse(a["honest_f_part_in_S"])
            self.assertEqual(a["data_relations_rank"], 2)
            self.assertEqual(set(a["f_part_residual_Q_host"]), {"acc_k", "acc_v"})
            self.assertEqual(set(a["f_part_residual_KV_host"]), {"acc_q"})
            b = u["b_two_scalars_one_mask_total"]
            self.assertEqual(b["mask_channel"]["leaked_dim_fp2"], 1)
            self.assertTrue(b["phi_kills_every_mask"] and b["phi_not_a_verifier_relation"])
            self.assertEqual(set(b["phi_of_data"]), {"acc_q", "acc_k", "acc_v"})
            self.assertTrue(u["c_split_three_scalars"]["Q_host"]["pass"] and u["c_split_three_scalars"]["KV_host"]["pass"])
            self.assertTrue(nc["nc_row_budget_exceeded"]["refused"])
            self.assertEqual(nc["nc_sigma_functional_for_private_slot"]["criterion"]["leaked_dim_fp2"], 1)
            self.assertEqual(nc["nc_sigma_functional_for_host_slot"]["criterion"]["leaked_dim_fp2"], 1)

    def test_controls_direct_small(self):
        # the same machinery on a tiny hosted group: c = 0 forced leaks the hosted slot's dim S; nu = 0 is blind
        slots = C._finish({"H": {"n_vars": 4, "degree": 3, "ext_rounds": 1}, "S": {"n_vars": 3, "degree": 2, "ext_rounds": 1}})
        with self.assertRaises(ValueError):
            M.system_hosted(slots, "H", ["S"], M.Rng(1), cs={"S": ZERO})
        ch, meta = M.system_hosted(slots, "H", ["S"], M.Rng(1), cs={"S": ZERO}, refuse_zero_c=False)
        r = M.analyze_hosted(ch, meta, slots)
        self.assertEqual(r["leaked_dim_fp2"], 3 * 2 + 1)
        ch, meta = M.system_hosted(slots, "H", ["S"], M.Rng(1), nus={"S": ZERO})
        r = M.analyze_hosted(ch, meta, slots)
        self.assertEqual(r["leaked_dim_fp2"], 0)
        self.assertEqual(meta["host_f_total"], {})
        ch, meta = M.system_hosted(slots, "H", ["S"], M.Rng(1), last_round_degree={"S": 3})
        r = M.analyze_hosted(ch, meta, slots)
        self.assertEqual(r["leaked_dim_fp2"], 1)
        self.assertEqual(list(r["leaked_functionals"][0]), ["S.h2(3)"])


class Cli(unittest.TestCase):
    def test_roundtrip_exit_zero_and_json(self):
        with tempfile.TemporaryDirectory() as td:
            out = Path(td) / "cfs.json"
            proc = subprocess.run([sys.executable, str(SCRIPT), "--inventory", str(INVENTORY), "--out", str(out), "--seed", "60"],
                                  capture_output=True, text=True, timeout=600)
            self.assertEqual(proc.returncode, 0, proc.stderr + proc.stdout[-2000:])
            self.assertIn("all_pass=True", proc.stdout)
            with open(out) as f:
                rep = json.load(f)
            self.assertTrue(rep["all_checks_pass"])
            self.assertEqual(rep["n_checks"], REPORT["n_checks"])
            self.assertEqual(rep["inventory_sha256"], REPORT["inventory_sha256"])
            self.assertEqual(len(rep["slot_tables"]["P1"]), 18)
            self.assertEqual(rep["m_layout"]["default"]["P1"]["n_rows"], 40)
            self.assertEqual(rep["m_layout"]["smhost"]["P1"]["n_rows"], 42)
            # same seed -> same ranks as the in-process report
            for mode in ("P1", "P3"):
                for s, v in rep["standalone"][mode].items():
                    self.assertEqual(v["rank_map"], REPORT["standalone"][mode][s]["rank_map"])
            # --hosts with the dumped default reproduces the default variant
            hosts_path = Path(td) / "hosts.json"
            self.assertEqual(M.main(["--inventory", str(INVENTORY), "--out", str(out), "--dump-hosts", str(hosts_path)]), 0)
            with open(hosts_path) as f:
                self.assertEqual(json.load(f)["hosts"], M.DEFAULT_HOSTS["hosts"])

    def test_exit_nonzero_on_oversize_inventory(self):
        with tempfile.TemporaryDirectory() as td:
            bad = json.loads(json.dumps(INV))
            for e in bad["A2_cfs_slots"]["P3"]:
                if e["slot"] == "SC_ATTN_05":
                    e["n_vars"] = 51        # L = 257: mask_commit's assert
            inv = Path(td) / "inv.json"
            with open(inv, "w") as f:
                json.dump(bad, f)
            out = Path(td) / "out.json"
            self.assertEqual(M.main(["--inventory", str(inv), "--out", str(out)]), 1)
            self.assertFalse(out.exists())

    def test_exit_nonzero_on_bad_hosts(self):
        with tempfile.TemporaryDirectory() as td:
            h = copy_default_hosts()
            del h["hosts"]["SC_ATTN_02"]     # SC_ATTN_11 left unhosted
            hp = Path(td) / "hosts.json"
            with open(hp, "w") as f:
                json.dump(h, f)
            out = Path(td) / "out.json"
            self.assertEqual(M.main(["--inventory", str(INVENTORY), "--out", str(out), "--hosts", str(hp)]), 1)
            self.assertFalse(out.exists())


if __name__ == "__main__":
    unittest.main()
