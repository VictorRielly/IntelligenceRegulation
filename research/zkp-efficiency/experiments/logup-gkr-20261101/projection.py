"""Kill-rule accounting and per-block projection for LogUp-GKR vs committed W16 helpers.

Inputs:
  * results.json (this experiment, MEASURED on the shared M3 Ultra, medians);
  * native phase rows QUOTED from results/zk60_limb16_20261031/logs/g_phases2.log
    (the W16_SHIELD_T128_H24 prove-cpu pass, wall 3.049 s, and the warm
    prove-metal pass, wall 0.578 s) and the W16 shape counts (shape.rs).
Everything derived from those rows by table-count or word-count attribution is
an ESTIMATE, labelled as such in projection.json.
"""
import json
import pathlib

HERE = pathlib.Path(__file__).resolve().parent
R = json.loads((HERE / "results.json").read_text())

LOOKUPS = 32_276_480          # W16 counted lookup words per T128 block (DESIGN.md)
H_WORDS = 42_696_704          # H words in the measured run
LEAVES = 1 << 25              # GKR tree for one block (lookups + table + pads)
LOG = "results/zk60_limb16_20261031/logs/g_phases2.log"

# helpers / tables per domain zero-check (W16: helpers = ceil(lookups/2); tables from PB-SLOTSTEP builds)
DOM = {  # name: (helpers, tables, cpu_s, metal_warm_s)
    "D": (10, 37, 0.643, 0.054),
    "Q": (3, 15, 0.239, 0.029),
    "Kv": (3, 15, 0.133, 0.013),
    "S": (4, 19, 0.297, 0.025),
    "F": (4, 19, 0.623, 0.072),
}
CPU = {"open_H": 0.022, "commit_H": 0.218, "helper_inverses": 0.024, "TAB": 0.215, "wall": 3.049, "warm_cpu_block_DESIGN": 1.54}
METAL = {"open_H": 0.021, "commit_H": 0.045, "helper_inverses": 0.009, "TAB": 0.008, "M_commit_50_rows": 0.009,
         "wall_instrumented": 0.578, "warm_block": 0.47, "exp_act_inverses": 0.020}
METAL_GL_MUL_PER_S = 88.0e9   # results/zk60_metal_20261031/kbench/gl_mul_bench_run.log: 87.8-96.5 Gmul/s; the lower end
METAL_BW = 800e9                               # nominal unified-memory bandwidth (spec), bytes/s
ROUND_FLOOR_S = (0.30e-3, 0.35e-3)             # warm Metal: 3-table 2^19 slots 00/01/21 take 6-7 ms over 19 rounds


def g25(run="t32"):
    return R["runs"][run]["sizes"]["25"]


def main():
    out = {}
    g = g25()["gkr"]
    h = g25()["helper"]
    # ---------------- CPU, per lookup ----------------
    gkr_ns = g["prove_s_median"] / LOOKUPS * 1e9                     # MEASURED (tree of 2^25 leaves)
    hw_ns = h["gather_write_s_median"] * 1e9 / LEAVES                 # MEASURED per helper word (1 word / lookup)
    hc_ns = h["commit_s_median"] * 1e9 / LEAVES                       # MEASURED per committed word
    share = LOOKUPS / H_WORDS
    open_ns = CPU["open_H"] * share * 1e9 / LOOKUPS                   # ESTIMATE (native, word share)
    zc_loaded = sum(hh / tt * cpu for hh, tt, cpu, _ in DOM.values())  # ESTIMATE (native, table share)
    scale = CPU["warm_cpu_block_DESIGN"] / CPU["wall"]
    zc_ns = (zc_loaded * scale * 1e9 / LOOKUPS, zc_loaded * 1e9 / LOOKUPS)
    leaf_term_loaded = sum(cpu / tt for _, tt, cpu, _ in DOM.values())  # ESTIMATE: +1 table-equivalent per domain
    leaf_ns = (leaf_term_loaded * scale * 1e9 / LOOKUPS, leaf_term_loaded * 1e9 / LOOKUPS)
    helper_full = (hw_ns + hc_ns + open_ns + zc_ns[0], hw_ns + hc_ns + open_ns + zc_ns[1])
    gkr_full = (gkr_ns + leaf_ns[0], gkr_ns + leaf_ns[1])
    ratio_full = (gkr_full[0] / helper_full[1], gkr_full[1] / helper_full[0])
    ratio_measured_only = gkr_ns / (hw_ns + hc_ns)
    # bytes per lookup, the same counting convention (main-memory arrays read + written)
    gkr_bytes = (g["bytes_rd_per_leaf_COUNTED"] + g["bytes_wr_per_leaf_COUNTED"]) * LEAVES / LOOKUPS
    helper_bytes = {"write (vals 4 rd + helper 8 wr)": 12, "commit (8 rd + 32 encoded wr + 32 hash rd)": 72,
                    "zero-check (build 8 rd + 8 wr, rounds 16 rd + 8 wr)": 40, "opening combination (8 rd)": 8}
    hb = sum(helper_bytes.values())
    out["cpu_per_lookup_ns"] = {
        "gkr_prove_MEASURED": gkr_ns, "helper_gather_write_MEASURED": hw_ns, "helper_commit_MEASURED": hc_ns,
        "helper_open_share_ESTIMATE": open_ns, "helper_zero_check_share_ESTIMATE_range": zc_ns,
        "gkr_leaf_claim_terms_ESTIMATE_range": leaf_ns,
        "helper_path_total_range": helper_full, "gkr_path_total_range": gkr_full,
        "ratio_gkr_over_helper_full_range": ratio_full, "ratio_measured_parts_only": ratio_measured_only,
        "note": "zero-check shares attribute the native CPU pass by tables per domain; the low end rescales the "
                "3.049 s pass to DESIGN's 1.54 s CPU block; TAB slot (0.215 s CPU) excluded",
    }
    out["bytes_per_lookup_COUNTED"] = {"gkr": gkr_bytes, "helper": hb, "helper_parts": helper_bytes}
    out["fp2_equiv_mul_per_lookup_COUNTED"] = {
        "gkr": g["fp2_equiv_mul_per_leaf_COUNTED"] * LEAVES / LOOKUPS,
        "helper_commit": 43 / 5, "helper_gather": 0.0,
        "note": "commit: inverse NTT 2^14 + coset scaling + forward NTT 2^16 per row = ~43 base products per word "
                "(+ BLAKE3 over 32 B/word); zero-check helper terms not counted",
    }
    kill_ratio = ratio_full[0] >= 0.7
    kill_bytes = gkr_bytes >= hb
    out["kill_rule"] = {
        "rule": "kill if GKR >= 0.7x the helper path per lookup on the CPU AND >= the same counted bytes per lookup",
        "ratio_clause_full_accounting": kill_ratio, "ratio_clause_measured_parts_only": ratio_measured_only >= 0.7,
        "bytes_clause": kill_bytes,
        "verdict": "NOT KILLED (bytes clause holds, ratio clause fails under the full accounting)" if not (kill_ratio and kill_bytes) else "KILLED",
    }
    # ---------------- Metal, per block (ESTIMATE) ----------------
    hm = {"helper_inverses (native, measured phase)": METAL["helper_inverses"],
          "H commit, helper word share": METAL["commit_H"] * share,
          "open H, helper word share": METAL["open_H"] * share,
          "zero-check helper table share": sum(hh / tt * mt for hh, tt, _, mt in DOM.values()),
          "TAB slot (table helpers)": METAL["TAB"]}
    helper_metal = sum(hm.values())
    base_muls = g["fp2_equiv_mul_per_leaf_COUNTED"] * 5 * LEAVES
    compute = (base_muls / (METAL_GL_MUL_PER_S * 0.6), base_muls / (METAL_GL_MUL_PER_S * 0.3))
    bw = (g["bytes_rd_per_leaf_COUNTED"] + g["bytes_wr_per_leaf_COUNTED"]) * LEAVES / (METAL_BW * 0.5)
    gpu_rounds = g["parallel_rounds"]
    latency_today = (gpu_rounds * ROUND_FLOOR_S[0], gpu_rounds * ROUND_FLOOR_S[1])
    latency_lowlat = gpu_rounds * 30e-6
    t32 = R["runs"]["t32"]["sizes"]["25"]["gkr"]["last_layers_rep0_k_secs_parallel_rounds"]
    small_cpu = (0.005, 0.016)
    leaf_terms_metal = sum(mt / tt for _, tt, _, mt in DOM.values())
    gkr_metal = (max(compute[0], bw) + latency_lowlat + small_cpu[0], max(compute[1], bw) + latency_today[1] + small_cpu[1])
    saving = (helper_metal - gkr_metal[1] - leaf_terms_metal, helper_metal - gkr_metal[0] - leaf_terms_metal)
    out["metal_per_block_ESTIMATE"] = {
        "helper_path_parts_s": hm, "helper_path_s": helper_metal,
        "gkr_base_muls": base_muls, "gkr_compute_s_at_60_30pct_of_kbench": compute, "gkr_bandwidth_s_at_50pct": bw,
        "gkr_gpu_scale_rounds": gpu_rounds, "round_latency_today_s": latency_today, "round_latency_30us_s": latency_lowlat,
        "gkr_cpu_small_rounds_s": small_cpu, "gkr_metal_s_range": gkr_metal,
        "leaf_claim_terms_s": leaf_terms_metal,
        "net_saving_s_range": saving,
        "block_speedup_range_on_0.47s": (METAL["warm_block"] / (METAL["warm_block"] - max(saving[0], 0.0)),
                                          METAL["warm_block"] / (METAL["warm_block"] - saving[1])),
        "if_all_lookups_retire_H_extra_s": {
            "rest of H commit": METAL["commit_H"] * (1 - share), "rest of open H": METAL["open_H"] * (1 - share),
            "exp/act helper inverses": METAL["exp_act_inverses"],
            "exp/act helper zero-check share": 0.025 / 19 + 0.072 / 19, "ZS slot": 0.002,
            "minus: 2^22 more GKR leaves (generic leaves, ~1/8 of the tree)": -(gkr_metal[0] + gkr_metal[1]) / 2 / 8,
        },
        "M_rows_extra_s_if_on_critical_path": (METAL["M_commit_50_rows"] * 48 / 50, METAL["M_commit_50_rows"] * 144 / 50),
        "prototype_rep0_last_layers_k_secs_parallel_rounds": t32,
    }
    e = out["metal_per_block_ESTIMATE"]["if_all_lookups_retire_H_extra_s"]
    extra = sum(e.values())
    out["metal_per_block_ESTIMATE"]["all_lookups_net_saving_s_range"] = (saving[0] + extra, saving[1] + extra)
    out["labels"] = {"MEASURED": "this experiment's guarded runs (shared host, medians)",
                     "QUOTED": LOG, "ESTIMATE": "every attribution, projection and range above"}
    (HERE / "projection.json").write_text(json.dumps(out, indent=1) + "\n")
    print(json.dumps(out, indent=1))


if __name__ == "__main__":
    main()
