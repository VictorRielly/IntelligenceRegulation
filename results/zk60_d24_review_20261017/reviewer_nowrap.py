#!/usr/bin/env python3
"""Independent no-wrap / uniqueness checker for D24 (reviewer, 2026-10-17).

Written from the Rust sources of ops/zkp-mvp/trained-1b-review-r1/ (argument.rs
SC_TZC / SC_DZC / SC_SZC, layout.rs lookups_at, shape.rs derive_at_width),
NOT from the author's nowrap_check.py. Exact integers only. Writes
reviewer_nowrap.json next to itself.

Adversarial range facts used (each from a lookup or a limb decomposition in
the frozen sources):
  x, x1, x2, ao, z16 in [-32768, 32767]  (c2/c3/c4/c8/c10: v + 32768 = l0 + 256 l1, bytes)
  y, nm, o8 in [-127, 127]                (sym lookups)
  D, a1, a2 (both norms) in [0, 2^24)      (three byte limbs, Dom::L lookups)
  rho, sigma in [0, 2^(8*ln)) = [0, 2^32)  (four byte limbs; the top-limb pin only tightens)
  ral in [0, 256)                          (byte lookup; the scaled lookup only tightens)
  gamma, wo public int8 in [-128, 127]
  dsq is NOT range proved: it is defined by dsq = D^2 (mod p) and eliminated.
"""
import json
import math
import os
import sys

P = 2**64 - 2**32 + 1
INT16_LO, INT16_HI = -32768, 32767
L24 = 2**24 - 1
L32 = 2**32 - 1

CLASS = dict(tn=(1, 16), cn=(1, 2**20), ceps=(1, 2**40), sh_ao=(0, 8), width=(1, 4096))


def isqrt(v):
    return math.isqrt(v)


def bit_length(v):
    return int(v).bit_length()


def derive_at_width(tn, cn_a, cn_m, ceps, sh_ao, width):
    """Re-implementation of NormCalibration::derive_at_width (shape.rs:105-140)."""
    if width == 0 or width > 4096:
        return None, "width"
    if not (1 <= tn <= 16):
        return None, "tn"
    for cn in (cn_a, cn_m):
        if not (1 <= cn <= 2**20):
            return None, "cn"
    if not (1 <= ceps <= 2**40):
        return None, "ceps"
    if sh_ao > 8:
        return None, "sh_ao"
    d_max = isqrt(ceps + width * 32768 * 32768)
    if 2 * d_max >= 2**24:
        return None, "isqrt limbs"
    wrho = tn + 1 + bit_length(d_max)
    if wrho > 32:
        return None, "window > 32"
    if wrho <= 24:
        return None, "window <= 24"
    return (d_max, wrho), "ok"


def interval_abs(terms):
    """terms: list of (lo, hi) integer intervals; returns max |sum|."""
    lo = sum(t[0] for t in terms)
    hi = sum(t[1] for t in terms)
    return max(abs(lo), abs(hi))


def prod_iv(*ivs):
    lo, hi = ivs[0]
    for a, b in ivs[1:]:
        c = [lo * a, lo * b, hi * a, hi * b]
        lo, hi = min(c), max(c)
    return (lo, hi)


def clause_bounds(tn, cn, ceps, sh_ao, width):
    """Max |integer value| of every clause whose coefficients D24 moved, over
    ADVERSARIAL legal values (not honest ones)."""
    d_pad = 1 << (width - 1).bit_length()
    D = (0, L24)
    a1 = (0, L24)
    a2 = (0, L24)
    S = (0, width * 32768 * 32768)  # sum of squares of true columns, x in int16
    x = (INT16_LO, INT16_HI)
    g = (-128, 127)
    y = (-127, 127)
    rho = (0, L32)
    sig = (0, L32)
    out = {}
    # R1 is the definition dsq := D^2 mod p; R4 after substitution:
    #   D^2 + a1 - ceps - S == 0 (mod p)
    D2 = (0, L24 * L24)
    out["R4 D^2+a1-ceps-S"] = interval_abs([D2, a1, (-ceps, -ceps), (-S[1], -S[0])])
    out["R2 D-limbs"] = interval_abs([D, (-L24, 0)])
    out["R3 2D-a1-a2"] = interval_abs([(0, 2 * L24), (-L24, 0), (-L24, 0)])
    # C0: 2 Cn g x + 2^tn D - 2^(tn+1) D y - rho
    t0 = prod_iv((2 * cn, 2 * cn), g, x)
    t1 = prod_iv((2**tn, 2**tn), D)
    t2 = prod_iv((-(2 ** (tn + 1)), -(2 ** (tn + 1))), D, y)
    t3 = (-rho[1], -rho[0])
    out["C0 2Cn g x + 2^tn D - 2^(tn+1) D y - rho"] = interval_abs([t0, t1, t2, t3])
    # C1: sigma + rho + 1 - 2^(tn+1) D
    out["C1 sigma+rho+1-2^(tn+1)D"] = interval_abs([sig, rho, (1, 1), prod_iv((-(2 ** (tn + 1)), -(2 ** (tn + 1))), D)])
    # host SC_WO: 2^sh_ao ao + ral - half - acc ; acc = sum_j o8_j wo_ij over d_pad
    half = 0 if sh_ao == 0 else 2 ** (sh_ao - 1)
    acc = prod_iv((-127, 127), (-128, 127))
    acc = (acc[0] * d_pad, acc[1] * d_pad)
    out["host SC_WO"] = interval_abs([prod_iv((2**sh_ao, 2**sh_ao), x), (0, 255), (-half, -half), (-acc[1], -acc[0])])
    return out


def max_tn(width, ceps):
    d_max = isqrt(ceps + width * 32768 * 32768)
    return max(0, 31 - bit_length(d_max))


def uniqueness_norm(row, g, cn, tn, ceps):
    """Given integer equalities (after no-wrap), enumerate EVERY (D, a1, a2)
    with D, a1, a2 in [0, 2^24) satisfying D^2 + a1 = S + ceps and
    a1 + a2 = 2D, and every (y, rho, sigma) in range satisfying C0/C1: return
    the solution sets (must be singletons)."""
    S = sum(v * v for v in row)
    T = S + ceps
    Ds = []
    lo = max(0, isqrt(max(0, T - 2 * L24)) - 2)
    for Dv in range(lo, min(L24, isqrt(T) + 3) + 1):
        a1v = T - Dv * Dv
        a2v = 2 * Dv - a1v
        if 0 <= a1v <= L24 and 0 <= a2v <= L24:
            Ds.append(Dv)
    sols = []
    for Dv in Ds:
        den = 2 ** (tn + 1) * Dv
        for i, xv in enumerate(row):
            num = 2 * cn * g[i] * xv + 2**tn * Dv
            ys = []
            for yv in range(-127, 128):
                rv = num - den * yv
                sv = den - 1 - rv
                if 0 <= rv <= L32 and 0 <= sv <= L32:
                    ys.append(yv)
            sols.append((Dv, i, ys))
    return Ds, sols


def softmax_bounds(T, f_e, F_P=9):
    """SC_SZC c2: mask*e*2^F_P - p*sum - sr, with e in [0, 2^f_e] (exp table
    structure check), p in [0, 2^(F_P+1)) (lp limbs + top pin), sum in
    [1, T*2^f_e] (row sum of e over T positions), sr in [0, 2^wrho_s),
    wrho_s = ceil(log2 T) + f_e (Shape::new)."""
    wrho_s = (T - 1).bit_length() + f_e
    e_max = 2**f_e
    sum_max = T * 2**f_e
    b = e_max * 2**F_P + (2 ** (F_P + 1) - 1) * sum_max + 2**wrho_s
    return b, wrho_s


def softmax_forgery(T, f_e, F_P=9):
    """Search for a forged (p', sr', sg') at ONE position of the last causal
    row with all scores equal (every e = 2^f_e, sum = T 2^f_e): p' != p with
    c2 == 0 mod P, c3 == 0 over the integers, all ranges legal."""
    wrho_s = (T - 1).bit_length() + f_e
    e = 2**f_e
    total = T * e
    num = e << F_P
    p, sr = divmod(num, total)
    for delta in range(1, 2 ** (F_P + 1)):
        for k in (1, 2, -1, -2):
            p2 = p + delta
            sr2 = sr - delta * total + k * P
            if not (0 <= p2 < 2 ** (F_P + 1)):
                continue
            if not (0 <= sr2 < total):
                continue
            sg2 = total - 1 - sr2
            if not (0 <= sg2 < 2**wrho_s and sr2 < 2**wrho_s):
                continue
            c2 = num - p2 * total - sr2
            assert c2 % P == 0 and c2 != 0
            return dict(p=p, p_forged=p2, sr=sr, sr_forged=sr2, sg_forged=sg2, c2_integer=c2, c2_over_P=c2 // P, wrho_s=wrho_s, total=total)
    return None


def main():
    out = {"P": P, "class": CLASS}
    # ---- 1. validator re-implementation: admitted set and max tn per width
    admitted = []
    widths = [1, 2, 3, 16, 96, 128, 384, 512, 768, 1024, 2047, 2048, 3000, 4095, 4096]
    cepss = [1, 2, 2**20, 129_746_337, 2**32, 2**39, 2**40]
    mt = {}
    for w in widths:
        mt[w] = {str(c): max_tn(w, c) for c in cepss}
        for tn in range(1, 17):
            for c in cepss:
                r, why = derive_at_width(tn, 1, 1, c, 7, w)
                if r:
                    admitted.append((w, tn, c, r[0], r[1]))
    out["max_tn_per_width"] = mt
    assert all(v == 10 for v in mt[2048].values()), mt[2048]
    assert all(v == 9 for v in mt[4096].values()), mt[4096]
    out["admitted_count"] = len(admitted)
    out["admitted_tn_range"] = [min(a[1] for a in admitted), max(a[1] for a in admitted)]
    # every admitted (w, tn, ceps): honest windows fit exactly (completeness)
    for (w, tn, c, d_max, wrho) in admitted:
        assert 2 * d_max < 2**24
        assert 2 ** (tn + 1) * d_max - 1 < 2**wrho, (w, tn, c)
        # tight: the window is not one bit wider than needed
        assert 2 ** (tn + 1) * d_max > 2 ** (wrho - 1) - 2 ** (tn + 1), (w, tn, c)
    # ---- 2. clause bounds over the WHOLE declared class corners (admitted or not)
    worst = {}
    for tn in (1, 16):
        for cn in (1, 2**20):
            for ceps in (1, 2**40):
                for sh_ao in (0, 8):
                    for w in (1, 4096):
                        for k, v in clause_bounds(tn, cn, ceps, sh_ao, w).items():
                            worst[k] = max(worst.get(k, 0), v)
    out["class_corner_clause_bounds"] = {k: [v, round(math.log2(v), 3)] for k, v in worst.items()}
    for k, v in worst.items():
        assert v < P, k
    out["max_log2_over_class"] = round(math.log2(max(worst.values())), 3)
    out["margin_bits_below_p"] = round(64 - math.log2(max(worst.values())), 3)
    # ---- 3. uniqueness on concrete hard rows at the T3 constants and class corners
    import random
    rnd = random.Random(20261017)
    cases = []
    for (w, tn, cn, ceps) in [(2048, 10, 2672, 129_746_337), (2048, 10, 2**20, 2**40), (384, 11, 1, 1), (4096, 9, 2**20, 2**40), (384, 10, 1336, 33_554_467)]:
        rows = [[-32768] * w, [32767] * w, [0] * (w - 1) + [-32768], [rnd.randint(-32768, 32767) for _ in range(w)]]
        for row in rows:
            g = [rnd.choice([-128, 127, -1, 1]) for _ in range(w)]
            # only a sample of columns for C0 (all of them share D)
            cols = [0, w - 1, w // 2]
            S = sum(v * v for v in row)
            Ds, _ = uniqueness_norm([0], [0], cn, tn, 0) if False else (None, None)
            T_ = S + ceps
            Dh = isqrt(T_)
            # the isqrt witness set
            Dset = []
            for Dv in range(max(0, Dh - 3), Dh + 4):
                a1v = T_ - Dv * Dv
                a2v = 2 * Dv - a1v
                if 0 <= a1v <= L24 and 0 <= a2v <= L24 and Dv <= L24:
                    Dset.append(Dv)
            assert Dset == [Dh], (w, tn, cn, ceps, Dset, Dh)
            # far candidates are impossible: a1 = T - D^2 in [0, 2D] has one root
            for i in cols:
                den = 2 ** (tn + 1) * Dh
                num = 2 * cn * g[i] * row[i] + 2**tn * Dh
                ys = [yv for yv in range(-127, 128) if 0 <= num - den * yv <= L32 and 0 <= den - 1 - (num - den * yv) <= L32]
                assert len(ys) <= 1, ys
                if ys:
                    assert ys[0] == num // den
                cases.append(dict(w=w, tn=tn, cn=cn, ceps=ceps, row_kind=rows.index(row), col=i, D=Dh, y=ys))
    out["uniqueness_cases"] = len(cases)
    out["uniqueness_out_of_int8_cases"] = sum(1 for c in cases if not c["y"])
    # ---- 4. the alias D -> k + (p-1)/2 is outside the three-limb pin for every k
    out["alias_min"] = (P - 1) // 2
    assert (P - 1) // 2 > L24
    # ---- 5. softmax (F-1): bounds per f_e at T = 32, and the forgery threshold
    sm = {}
    first_wrap = None
    first_forge = None
    for f_e in range(0, 63):
        b, wrho_s = softmax_bounds(32, f_e)
        fz = softmax_forgery(32, f_e)
        sm[f_e] = dict(bound_log2=round(math.log2(b), 3), wraps=b >= P, wrho_s=wrho_s, limbs_sigma=-(-wrho_s // 8), forgery=fz)
        if b >= P and first_wrap is None:
            first_wrap = f_e
        if fz and first_forge is None:
            first_forge = f_e
    out["softmax_T32"] = {str(k): v for k, v in sm.items()}
    out["softmax_T32_first_f_e_bound_reaches_p"] = first_wrap
    out["softmax_T32_first_f_e_all_equal_row_forgery"] = first_forge
    out["softmax_T32_forgery_at_50"] = sm[50]["forgery"]
    path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "reviewer_nowrap.json")
    with open(path, "w") as f:
        json.dump(out, f, indent=1, default=str)
    print(json.dumps({k: out[k] for k in ["admitted_count", "admitted_tn_range", "class_corner_clause_bounds", "max_log2_over_class", "margin_bits_below_p", "uniqueness_cases", "uniqueness_out_of_int8_cases", "softmax_T32_first_f_e_bound_reaches_p", "softmax_T32_first_f_e_all_equal_row_forgery", "softmax_T32_forgery_at_50"]}, indent=1, default=str))
    print("max_tn 2048:", mt[2048], "4096:", mt[4096], "384:", mt[384])
    return 0


if __name__ == "__main__":
    sys.exit(main())
