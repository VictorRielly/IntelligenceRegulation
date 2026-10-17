"""Per-block phase cost model for the native private block (hashline private_block).

Calibration: the per-block averages of the R4-4 phase run (22-block TinyLlama T128 stack,
HL_PB_TIMING=1, RAYON_NUM_THREADS=16, laptop Core Ultra 9 185H, shared box, n=1),
results/zk60_1b_native_20261017/r4/PHASES_T128.md and the per-block tables in
r4/phases-T128-{cpu,gpu}/prove.log.  Work measures come from the exact counted-layout replica
layout.py (checked byte-exact against the Rust counted ladder).

Validation targets (proofs only = prove_run - witness - block loads, per block):
  TinyLlama T32/T64/T128 ladder (r3/LADDER.md) and Llama-3-8B T32 stack (r4/TABLE.md).
One thread, pure float arithmetic, well under a second.
"""
import json
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from layout import tinyllama, llama3_8b  # noqa: E402

BLOCKS_T128 = 22.0
CAL = tinyllama(128, 14).summary()

# ---- measured phase sums over 22 blocks (seconds), PHASES_T128.md ----------------------------
PH = {
    "cpu": dict(witness=13.236, a_alloc=17.67, commit_a=16.56, commit_h=18.13, inv_u8=6.91, inv_pair=1.39,
                zc=dict(D=(27.50, 5.86), F=(17.63, 1.90), S=(11.53, 2.10), Q=(7.95, 1.65), Kv=(4.41, 1.43)),
                open_a=5.15, open_h=3.60, wall=152.2),
    "gpu": dict(witness=15.899, a_alloc=21.19, commit_a=4.00, commit_h=3.62, inv_u8=8.84, inv_pair=1.77,
                zc=dict(D=(25.35, 4.87), F=(19.48, 1.58), S=(11.83, 1.75), Q=(7.95, 1.39), Kv=(3.86, 1.19)),
                open_a=9.18, open_h=2.99, wall=134.8),
}
# block-0 "rest" components (r4/phases-T128-cpu/prove.log, first table), seconds, then scaled
REST0 = dict(Dlin=0.043 + 0.045 + 0.047 + 0.058, Slin=0.075 + 0.019 + 0.017,
             wfold=0.013 + 0.009 + 0.010 + 0.014 + 0.022 + 0.022 + 0.024,
             ncol=0.069 + 0.008 + 0.031, siterows=0.071 + 0.034, u8=0.038 + 0.006, const=0.025 + 0.005 + 0.005)


def padded_weights(sh):
    d, f, kvd = sh.d_pad, sh.f_pad, sh.kv * sh.hd
    return d * d * 2 + d * kvd * 2 + 3 * d * f


def site_rows(sh):
    a, h = sh.claim_sites()
    return 2 * (sum(a) + sum(h))


F0_SLOT = 0.08  # s of size-independent work per zero-check slot (bounded above by the KV slot's 0.106 s), [MODEL]


def coefficients(mode, f0=F0_SLOT):
    p = PH[mode]
    c = {"f0": f0}
    s = CAL
    ah = s["A_elems"] + s["H_elems"]
    c["conv"] = (p["a_alloc"] - p["witness"]) / BLOCKS_T128 / s["A_elems"]
    c["commit"] = (p["commit_a"] + p["commit_h"]) / BLOCKS_T128 / ah
    c["inv_u8"] = p["inv_u8"] / BLOCKS_T128 / s["u8"]
    c["inv_pair"] = p["inv_pair"] / BLOCKS_T128 / (s["exp_pairs"] + s["act_pairs"])
    c["open"] = (p["open_a"] + p["open_h"]) / BLOCKS_T128 / ah
    terms = s["terms"]
    ext_total = sum(v[1] for v in p["zc"].values()) / BLOCKS_T128
    c["ext"] = ext_total / (sum(terms.values()) * s["n"])
    c["zc"] = {k: ((v[0] - v[1]) / BLOCKS_T128 - f0) / s["sizes"][k] / terms[k] for k, v in p["zc"].items()}  # per element-term
    accounted = (p["witness"] + p["a_alloc"] - p["witness"] + p["commit_a"] + p["commit_h"] + p["inv_u8"] + p["inv_pair"]
                 + sum(v[0] for v in p["zc"].values()) + p["open_a"] + p["open_h"]) / BLOCKS_T128
    rest = p["wall"] / BLOCKS_T128 - accounted
    scale = rest / sum(REST0.values())
    sh = tinyllama(128, 14)
    c["rest"] = dict(Dlin=REST0["Dlin"] * scale / s["sizes"]["D"], Slin=REST0["Slin"] * scale / s["sizes"]["S"],
                     wfold=REST0["wfold"] * scale / padded_weights(sh), ncol=REST0["ncol"] * scale / s["n"],
                     siterows=REST0["siterows"] * scale / (site_rows(sh) * s["n"]), u8=REST0["u8"] * scale / s["u8"],
                     const=REST0["const"] * scale)
    c["rest_total_T128"] = rest
    return c


def block_phases(sh, c):
    s = sh.summary()
    ah = s["A_elems"] + s["H_elems"]
    out = {}
    out["conversion"] = c["conv"] * s["A_elems"]
    out["commit"] = c["commit"] * ah
    out["inverses"] = c["inv_u8"] * s["u8"] + c["inv_pair"] * (s["exp_pairs"] + s["act_pairs"])
    zc = {k: c["zc"][k] * s["sizes"][k] * s["terms"][k] + c["ext"] * s["terms"][k] * s["n"] + c["f0"] for k in c["zc"]}
    out["zc_D"], out["zc_F"], out["zc_S"], out["zc_Q"], out["zc_Kv"] = zc["D"], zc["F"], zc["S"], zc["Q"], zc["Kv"]
    out["openings"] = c["open"] * ah
    r = c["rest"]
    out["rest"] = (r["Dlin"] * s["sizes"]["D"] + r["Slin"] * s["sizes"]["S"] + r["wfold"] * padded_weights(sh)
                   + r["ncol"] * s["n"] + r["siterows"] * site_rows(sh) * s["n"] + r["u8"] * s["u8"] + r["const"])
    out["weight_fold_part_of_rest"] = r["wfold"] * padded_weights(sh)
    out["total"] = sum(v for k, v in out.items() if k not in ("weight_fold_part_of_rest",))
    return out


MEASURED = {  # proofs only per block (s): r3/LADDER.md, r4/TABLE.md
    ("TinyLlama", 32, "cpu"): 40.2 / 22, ("TinyLlama", 32, "gpu"): 40.8 / 22,
    ("TinyLlama", 64, "cpu"): 64.8 / 22, ("TinyLlama", 64, "gpu"): 63.5 / 22,
    ("TinyLlama", 128, "cpu"): 136.2 / 22, ("TinyLlama", 128, "gpu"): 107.1 / 22,
    ("Llama-3-8B", 32, "cpu"): 110.2 / 32, ("Llama-3-8B", 32, "gpu"): 117.7 / 32,
}
SHAPES = {("TinyLlama", 32): tinyllama(32, 12), ("TinyLlama", 64): tinyllama(64, 13),
          ("TinyLlama", 128): tinyllama(128, 14), ("Llama-3-8B", 32): llama3_8b(32, 13)}


def gpu_arm_coefficients():
    """GPU arm = the CPU model with the commit replaced by the keyed GPU commit (5.06 ns/element on the
    4070 Laptop, R4-4 GPU phase run); a fixed per-block overhead G0 is added by the caller."""
    c = dict(coefficients("cpu"))
    c["commit"] = coefficients("gpu")["commit"]
    return c


G0 = None  # fitted below as the mean residual over the four GPU-arm points


if __name__ == "__main__":
    res = {"coefficients": {}, "validation": []}
    cg = gpu_arm_coefficients()
    G0 = sum(MEASURED[(m, T, "gpu")] - block_phases(sh, cg)["total"] for (m, T), sh in SHAPES.items()) / len(SHAPES)
    res["gpu_arm_fixed_overhead_s"] = G0
    print("GPU-arm fixed overhead per block (fitted, mean residual): %.3f s" % G0)
    for mode in ("cpu", "gpu"):
        c = coefficients("cpu") if mode == "cpu" else cg
        res["coefficients"][mode] = c
        for (model, T), sh in SHAPES.items():
            ph = block_phases(sh, c)
            if mode == "gpu":
                ph["total"] += G0
            meas = MEASURED[(model, T, mode)]
            err = (ph["total"] - meas) / meas
            res["validation"].append(dict(model=model, T=T, mode=mode, model_s=round(ph["total"], 3),
                                          measured_s=round(meas, 3), error_pct=round(100 * err, 1),
                                          phases={k: round(v, 3) for k, v in ph.items()}))
            print("%-10s T%-4d %s model %.3f s/block  measured %.3f  error %+.1f%%" % (model, T, mode, ph["total"], meas, 100 * err))
    for mode in ("cpu", "gpu"):
        c = res["coefficients"][mode]
        print(mode, "conv %.2f ns commit %.2f ns open %.2f ns inv_u8 %.2f ns inv_pair %.1f ns ext %.0f ns/term-col" % (
            c["conv"] * 1e9, c["commit"] * 1e9, c["open"] * 1e9, c["inv_u8"] * 1e9, c["inv_pair"] * 1e9, c["ext"] * 1e9))
        print(mode, "zc ns per element-term:", {k: round(v * 1e9, 1) for k, v in c["zc"].items()}, "rest T128 %.3f s" % c["rest_total_T128"])
    for (model, T), sh in SHAPES.items():
        s = sh.summary()
        print(model, T, "A+H elems %.1fM" % ((s["A_elems"] + s["H_elems"]) / 1e6), "u8 %.1fM" % (s["u8"] / 1e6), "sizes", s["sizes"], "terms", s["terms"])
    with open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "cost_model_validation.json"), "w") as fh:
        json.dump(res, fh, indent=1, default=float)
