#!/usr/bin/env python3
"""NATIVE R8: the no-wrap clauses of every relation a PER-LAYER calibration
constant enters, over each constant's whole declared class (unchanged from
R6), at all six trained profiles (TinyLlama-1.1B and Llama-3-8B at T 32 /
64 / 128). Every relation is block-local (one stage = one block = one shape),
so a bound over the class holds for whichever member a layer chooses.

Conservative ranges: int8 entries at magnitude 128, int16 at 32768; the
requant host `2^sh out + r - half(sh) - acc` with r in [0, 2^sh) over the
shift's window: qkv (d_pad; 1..8), score (head_dim; 1..8), pv (T keys,
p < 2^10; o 9..16), ao (d_pad, int16 out; 0..8), gate (d_pad; 1..8), product
(int16 x int16, int16 out; 9..16), down (f_pad, int16 out; 1..8). The norm
quotient `2 x g Cn + D 2^tn - 2 q D 2^tn - rho` with Cn <= 2^20 and the
four-limb window tn + 1 + bits(D_max) <= 32 (so D 2^tn < 2^31, rho < 2^32);
the isqrt `ss - D^2 - a1` with Ceps <= 2^40. Writes r8_nowrap_classes.json."""
import json
import math
import os

P = 2**64 - 2**32 + 1
HALF = P // 2
I8, I16 = 128, 32768
CN_MAX, CEPS_MAX = 2**20, 2**40
PROFILES = []
for t in (32, 64, 128):
    PROFILES.append((f"TinyLlama-1.1B T{t}", 2048, 2048, 8192, 64, t))
for t in (32, 64, 128):
    PROFILES.append((f"Llama-3-8B T{t}", 4096, 4096, 16384, 128, t))


def host(window, out_max, acc_max):
    return max((2**s) * out_max + (2**s - 1) + (2 ** (s - 1) if s else 0) + acc_max for s in window)


out = {"field_half_log2": round(math.log2(HALF), 3), "profiles": {}}
worst = 0
for name, width, d_pad, f_pad, hd, t in PROFILES:
    rows = {
        "qkv (sh_qkv 1..8)": host(range(1, 9), I8, d_pad * I8 * I8),
        "score (sh_s 1..8)": host(range(1, 9), I8, hd * I8 * I8),
        "pv (sh_o 9..16)": host(range(9, 17), I8, t * 1024 * I8),
        "ao (sh_ao 0..8)": host(range(0, 9), I16, d_pad * I8 * I8),
        "gate (sh_g 1..8)": host(range(1, 9), I8, d_pad * I8 * I8),
        "product (sh_h 9..16)": host(range(9, 17), I16, I16 * I16),
        "down (sh_z 1..8)": host(range(1, 9), I16, f_pad * I16 * I8),
        "norm quotient (tn, cn_a, cn_m, ceps)": 2 * I16 * I8 * CN_MAX + 2**31 + 2 * 127 * 2**31 + 2**32,
        "norm isqrt (ceps)": CEPS_MAX + width * I16 * I16 + 3 * 2**24,
    }
    for k, v in rows.items():
        assert v < HALF, (name, k, v)
        worst = max(worst, v)
    out["profiles"][name] = {k: round(math.log2(v), 3) for k, v in rows.items()}
out["worst_log2"] = round(math.log2(worst), 3)
out["verdict"] = "every clause below p/2 at all six trained profiles over every class (margin about 2^%d)" % int(math.log2(HALF) - math.log2(worst))
json.dump(out, open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "r8_nowrap_classes.json"), "w"), indent=1)
print(out["verdict"], "worst 2^%s" % out["worst_log2"])
for n, r in out["profiles"].items():
    print(n, max(r.values()))
