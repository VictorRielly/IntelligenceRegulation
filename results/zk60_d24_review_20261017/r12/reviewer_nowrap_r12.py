#!/usr/bin/env python3
"""Round-10 (R12) no-wrap checker (reviewer, 2026-10-26), from round 8's
(reviewer_nowrap_r8.py) with the R12 changes read from argument.rs of
ops/zkp-mvp/trained-1b-review-r12/:

* Wq folds over the MODEL axis d_pad (unchanged); Wo now folds over the
  QUERY axis q_pad (SC_WO inner = clog2(q_pad)), so the ao host's
  accumulator is q_pad * 127 * 128;
* the PV host sums over t_pad positions (T256 is a new trained T);
* the DD division clauses (R9) at the T of each profile: c2 = e 2^F_P -
  P Sum - rho with P < 2^(F_P+1), rho, sigma < 2^wrho_s, Sum < 2^(wrho_s+1);
  wrho_s = clog2(T) + f_e over the f_e class (clog2 T + f_e <= 24, CHECK.md
  S-1), F_P = 9.

Profiles: Shieldstral T128 / T256 (registered) and T512 (counted only):
width 3072, d_pad 4096, q_pad 4096, f_pad 16384, head_dim 128; the
decoupled-head rung: width 192, d_pad 256, q_pad 512, f_pad 512, head_dim
64, T32. Classes as round 8 (tn 1..=16, cn 1..=2^20, ceps 1..=2^40, wrho =
tn + 1 + bits(D_max) <= 32 with D_max = isqrt(ceps + width * 32768^2)).
Writes reviewer_nowrap_r12.json."""
import json
import math
import os

P = 2**64 - 2**32 + 1
HALF = P // 2
F_P = 9
PROFILES = [
    ("Shieldstral T128", 3072, 4096, 4096, 16384, 128, 128),
    ("Shieldstral T256", 3072, 4096, 4096, 16384, 128, 256),
    ("Shieldstral T512 (counted only)", 3072, 4096, 4096, 16384, 128, 512),
    ("rung-HD T32", 192, 256, 512, 512, 64, 32),
]


def host(window, out_abs, acc_abs):
    return max((2**s) * out_abs + (2**s - 1) + (2 ** (s - 1) if s else 0) + acc_abs for s in window)


def main():
    res = {}
    worst_all = (0, "")
    ceps_grid = [1] + [2**k for k in range(1, 41)]
    for name, width, d_pad, q_pad, f_pad, hd, t in PROFILES:
        worst = {}
        admitted = 0
        for tn in range(1, 17):
            for ceps in ceps_grid:
                d_max = math.isqrt(ceps + width * 32768 * 32768)
                wrho = tn + 1 + d_max.bit_length()
                if wrho > 32:
                    continue
                admitted += 1
                for cn in (1, 2**20):
                    c0 = 128 * 32768 * 2 * cn + d_max * 2**tn + 2 ** (tn + 1) * d_max * 127 + 2**wrho
                    c1 = 2 * 2**wrho + 1 + 2 ** (tn + 1) * d_max
                    iq = width * 32768 * 32768 + ceps + d_max * d_max + 2 * d_max
                    for k, v in (("norm quotient c0 / c6", c0), ("norm complement c1 / c7", c1), ("isqrt host", iq)):
                        worst[k] = max(worst.get(k, 0), v)
        lt = max(1, (t - 1).bit_length())
        dd = 0
        for f_e in range(8, 25 - lt):
            wrho_s = lt + f_e
            c2 = (2**f_e) * 2**F_P + (2 ** (F_P + 1)) * (2 ** (wrho_s + 1)) + 2**wrho_s
            dd = max(dd, c2, 2 * 2**wrho_s + 1 + 2 ** (wrho_s + 1))
        worst.update({
            "qkv host (sh_qkv 1..8; Wq over d_pad)": host(range(1, 9), 127, d_pad * 127 * 128),
            "score host (sh_s 1..8)": host(range(1, 9), 127, hd * 127 * 127),
            "pv host (sh_o 9..16; over t_pad)": host(range(9, 17), 127, t * 1023 * 127),
            "ao host (sh_ao 0..8; Wo over q_pad)": host(range(0, 9), 32768, q_pad * 127 * 128),
            "gate host (sh_g 1..8)": host(range(1, 9), 128, d_pad * 127 * 128),
            "product host (sh_h 9..16)": host(range(9, 17), 32768, 32768 * 32768),
            "down host (sh_z 1..8)": host(range(1, 9), 32768, f_pad * 32768 * 128),
            "DD division c2 / c3 (f_e class at this T)": dd,
        })
        for k, v in worst.items():
            assert v < HALF, (name, k)
            if v > worst_all[0]:
                worst_all = (v, f"{name}: {k}")
        res[name] = {"admitted_tn_ceps_points": admitted, "clauses_log2": {k: round(math.log2(v), 3) for k, v in worst.items()}}
    res["worst"] = {"log2": round(math.log2(worst_all[0]), 3), "where": worst_all[1], "half_p_log2": round(math.log2(HALF), 3)}
    with open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "reviewer_nowrap_r12.json"), "w") as fh:
        json.dump(res, fh, indent=1)
    for n in res:
        if n != "worst":
            c = res[n]["clauses_log2"]
            print(n, "| admitted", res[n]["admitted_tn_ceps_points"], "| max", max(c.values()), "| ao", c["ao host (sh_ao 0..8; Wo over q_pad)"], "| pv", c["pv host (sh_o 9..16; over t_pad)"], "| dd", c["DD division c2 / c3 (f_e class at this T)"])
    print("WORST", res["worst"])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
