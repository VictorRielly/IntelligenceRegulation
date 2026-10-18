#!/usr/bin/env python3
"""Round-5 checker (reviewer, 2026-10-18): the integer clauses at the NEW
Llama-3-8B T64 / T128 trained shapes (and T32 for reference), written from
argument.rs (SC_SZC c0..c4, the score / PV / AO hosts) and layout.rs (the U8
lookups and their top-limb pins: p < 2^(F_P+1) via scaled(pl_top, 2^(8 lp -
10)); sr, sg < 2^wrho_s via scaled(top, 2^(8 ls - wrho_s))) of
ops/zkp-mvp/trained-1b-review-r5/.

Adversarial facts: e in [0, 2^f_e] (exp table structure); Sum = sum over the
T key positions of e, so Sum in [0, T 2^f_e]; p in [0, 2^10); sr, sg in
[0, 2^wrho_s); v8, q8, k8 in [-127, 127]; one-limb remainders in [0, 2^sh),
two-limb in [0, 2^sh); every shift over its whole window; f_e over 9..=16;
wrho_s = log2(T) + f_e <= 24. Each clause must stay below p/2 so that it
holds over the integers; then (c2, c3) force p = floor(e 2^F_P / Sum),
sr = remainder, and Sum >= 1. Honest completeness: Sum - 1 < 2^wrho_s.
Writes reviewer_nowrap_r5.json."""
import json
import math
import os
import sys

P = 2**64 - 2**32 + 1
HALF = P // 2
F_P = 9


def mag(*terms):
    """max |sum of intervals|"""
    lo = sum(t[0] for t in terms)
    hi = sum(t[1] for t in terms)
    return max(abs(lo), abs(hi))


def prod(a, b):
    c = [a[0] * b[0], a[0] * b[1], a[1] * b[0], a[1] * b[1]]
    return (min(c), max(c))


def sc(iv, k):
    a, b = iv[0] * k, iv[1] * k
    return (min(a, b), max(a, b))


I8S = (-127, 127)
I16 = (-32768, 32767)


def geometry(T, d=4096, f=14336, q=32, kv=8, hd=128):
    lt = (T - 1).bit_length()
    d_pad, f_pad = 1 << (d - 1).bit_length(), 1 << (f - 1).bit_length()
    res = {"softmax": {}, "hosts": {}}
    worst = 0
    for f_e in range(9, 17):
        wrho_s = lt + f_e
        if wrho_s > 24:
            res["softmax"][f_e] = "f_e outside the class at this T (refused by check_f_e_class)"
            continue
        e = (0, 2**f_e)
        S = (0, T * 2**f_e)
        p = (0, 2 ** (F_P + 1) - 1)
        sr = sg = (0, 2**wrho_s - 1)
        mask = (0, 1)
        c2 = mag(sc(prod(mask, e), 2**F_P), sc(prod(p, S), -1), sc(sr, -1))
        c3 = mag(sg, sr, (1, 1), sc(S, -1))
        # c0 = zsel^2 - zsel, c1 = zsel * delta: zsel is a committed plane forced
        # boolean by c0; delta = max - masked score in [-254, 254] before the
        # exp lookup pins it to [0, 255]
        c1 = 255
        acc_pv = sc(prod(p, I8S), T)  # PV accumulator over T keys
        pv_host = max(mag(sc(I8S, 2**sh), (0, 2**sh - 1), (-(2 ** (sh - 1)), 0), sc(acc_pv, -1)) for sh in range(9, 17))
        honest_ok = T * 2**f_e - 1 < 2**wrho_s
        row = {"wrho_s": wrho_s, "limbs": math.ceil(wrho_s / 8), "c2_log2": round(math.log2(c2), 3), "c3_log2": round(math.log2(c3), 3), "pv_acc_log2": round(math.log2(max(abs(acc_pv[0]), abs(acc_pv[1]))), 3), "pv_host_log2": round(math.log2(pv_host), 3), "honest_sum_fits_window": honest_ok}
        assert c2 < HALF and c3 < HALF and pv_host < HALF and honest_ok, (T, f_e, row)
        worst = max(worst, c2, c3, pv_host, c1)
        res["softmax"][f_e] = row
    # T-independent hosts at width 4096 (whole shift windows)
    one = lambda acc, outc: max(mag(sc(outc, 2**sh), (0, 2**sh - 1), (-(2 ** (sh - 1)), 0), sc(acc, -1)) for sh in range(1, 9))
    two = lambda acc, outc: max(mag(sc(outc, 2**sh), (0, 2**sh - 1), (-(2 ** (sh - 1)), 0), sc(acc, -1)) for sh in range(9, 17))
    h = res["hosts"]
    h["score (sum over head_dim, sh_s 1..8)"] = one(sc(prod(I8S, I8S), hd), I8S)
    h["Q/K/V (sum over d_pad, sh_qkv 1..8)"] = one(sc(prod(I8S, (-128, 127)), d_pad), I8S)
    h["AO (sum over d_pad, sh_ao 0..8)"] = max(mag(sc(I16, 2**sh), (0, 2**sh - 1), (-(2 ** max(sh - 1, 0)), 0), sc(sc(prod(I8S, (-128, 127)), d_pad), -1)) for sh in range(0, 9))
    h["gate (sum over d_pad, sh_g 1..8)"] = one(sc(prod(I8S, (-128, 127)), d_pad), (-128, 127))
    h["h product (sh_h 9..16)"] = two(prod(I16, I16), I16)
    h["down (sum over f_pad, sh_z 1..8)"] = one(sc(prod(I16, (-128, 127)), f_pad), I16)
    for k, v in list(h.items()):
        assert v < HALF, k
        worst = max(worst, v)
        h[k] = round(math.log2(v), 3)
    doms = {"D": T * d_pad, "Q": T * q * hd, "Kv": T * kv * hd, "S": q * T * T, "F": T * f_pad}
    res["domains_log2"] = {k: math.log2(v) for k, v in doms.items()}
    res["lookups_upper_bound_log2"] = round(math.log2(32 * sum(doms.values())), 3)
    res["worst_geometry_clause_log2"] = round(math.log2(worst), 3)
    return res


def main():
    out = {}
    for T in (32, 64, 128):
        out[f"Llama-3-8B T{T}"] = geometry(T)
    # the norm at width 4096 is T-independent (round 3: C0 2^48.039, D_max
    # 2,097,152..2,344,687 over the ceps class, tn <= 9)
    out["norm (width 4096, T-independent)"] = "see reviewer_nowrap_r3.json (C0 2^48.039 < p/2; tn <= 9; window 32)"
    path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "reviewer_nowrap_r5.json")
    with open(path, "w") as fh:
        json.dump(out, fh, indent=1)
    for k, v in out.items():
        if isinstance(v, dict):
            sm = v["softmax"]
            top = sm[max(sm)]
            print(k, "worst geometry clause 2^%s;" % v["worst_geometry_clause_log2"], "f_e 16:", top if isinstance(top, str) else {kk: top[kk] for kk in ("wrho_s", "c2_log2", "c3_log2", "pv_host_log2")}, "| hosts", v["hosts"])
        else:
            print(k, v)
    return 0


if __name__ == "__main__":
    sys.exit(main())
