#!/usr/bin/env python3
"""Round-8 checker (reviewer, 2026-10-19): every relation a per-layer
calibration constant enters, over each constant's whole declared class, at
all six trained profiles. Written from argument.rs of
ops/zkp-mvp/trained-1b-review-r8/:

* SC_DZC c0 (norm quotient): g*x*2cn + D*2^tn - 2^(tn+1)*D*y - nr = 0 with
  g int8 (|g| <= 128), x int16, y int8 (|y| <= 127), nr in [0, 2^wrho);
  c1: ns + nr + 1 - 2^(tn+1)*D = 0 (ns, nr in [0, 2^wrho)); the same for
  norm_m with cn_m.
* SC_TZC isqrt host: sum_i x_i^2 + ceps = D^2 + a1, a1 in [0, 2D].
* the requant hosts 2^sh*out + r - half(sh) - acc over each shift's window
  (qkv, score, pv, ao, gate, product, down), acc over the profile's padded
  axes.

Classes (shape.rs, unchanged since R6): tn 1..=16, cn 1..=2^20, ceps
1..=2^40, wrho = tn + 1 + bits(D_max) <= 32 with D_max = isqrt(ceps +
width*32768^2) (refused at the door otherwise), sh_ao 0..=8, one-limb shifts
1..=8, two-limb 9..=16. The sweep takes EVERY tn, a ceps grid over the whole
class (1, 2^k for k = 1..40, and 2^40), cn at both ends, i.e. a superset of
what the plane-list guard admits per layer. Writes reviewer_nowrap_r8.json."""
import json
import math
import os

P = 2**64 - 2**32 + 1
HALF = P // 2
PROFILES = []
for t in (32, 64, 128):
    PROFILES.append((f"TinyLlama-1.1B T{t}", 2048, 2048, 8192, 64, t))
for t in (32, 64, 128):
    PROFILES.append((f"Llama-3-8B T{t}", 4096, 4096, 16384, 128, t))


def host(window, out_abs, acc_abs):
    return max((2**s) * out_abs + (2**s - 1) + (2 ** (s - 1) if s else 0) + acc_abs for s in window)


def main():
    res = {}
    worst_all = (0, "")
    ceps_grid = [1] + [2**k for k in range(1, 41)]
    for name, width, d_pad, f_pad, hd, t in PROFILES:
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
        hosts = {
            "qkv host (sh_qkv 1..8)": host(range(1, 9), 127, d_pad * 127 * 128),
            "score host (sh_s 1..8)": host(range(1, 9), 127, hd * 127 * 127),
            "pv host (sh_o 9..16)": host(range(9, 17), 127, t * 1023 * 127),
            "ao host (sh_ao 0..8)": host(range(0, 9), 32768, d_pad * 127 * 128),
            "gate host (sh_g 1..8)": host(range(1, 9), 128, d_pad * 127 * 128),
            "product host (sh_h 9..16)": host(range(9, 17), 32768, 32768 * 32768),
            "down host (sh_z 1..8)": host(range(1, 9), 32768, f_pad * 32768 * 128),
        }
        worst.update(hosts)
        for k, v in worst.items():
            assert v < HALF, (name, k)
            if v > worst_all[0]:
                worst_all = (v, f"{name}: {k}")
        res[name] = {"admitted_tn_ceps_points": admitted, "clauses_log2": {k: round(math.log2(v), 3) for k, v in worst.items()}}
    res["worst"] = {"log2": round(math.log2(worst_all[0]), 3), "where": worst_all[1], "half_p_log2": round(math.log2(HALF), 3)}
    with open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "reviewer_nowrap_r8.json"), "w") as fh:
        json.dump(res, fh, indent=1)
    for n in res:
        if n != "worst":
            c = res[n]["clauses_log2"]
            print(n, "admitted (tn, ceps) points", res[n]["admitted_tn_ceps_points"], "| max", max(c.values()), {k: c[k] for k in ("norm quotient c0 / c6", "isqrt host", "down host (sh_z 1..8)")})
    print("WORST", res["worst"])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
