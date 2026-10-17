"""Adversarial check of the token I/O design: independent arithmetic (paper only).

Written by the checker lane from DESIGN.md's text and the read-only Rust sources, NOT
from token_io_count.py (nothing is imported from the design's directory). One thread,
pure integers / floats, well under a second. Writes check_arith.json beside itself.

Sections
  A. no-wrap clauses of the output stage, both models (exact integers)
  B. keyed argmax: randomised exhaustive check over every candidate index j that the
     only j admitting a witness (A1..A6, delta in 6 byte limbs, with and without the
     pin) is numpy's first maximum; extreme logits included
  C. committed elements, re-derived plane by plane: stage IN (b), stage OUT mode (i)
     and mode (ii), plus the variants this check recommends (no pin, wider stage IN)
  D. per-opening proximity term of the ZK commitment, (1 - delta/3)^Q with the code
     RS(n + Q, n * inv_rate) (zkp-core/src/pcs.rs: "distance 1 - (n + Q)/nn"), and
     the whole-proof commitment term with the design's geometry vs the repaired one
Labels: everything here is [COUNTED] (exact arithmetic on stated geometry).
"""
import json
import math
import os
import random

P = (1 << 64) - (1 << 32) + 1
Q = 256          # opened columns = pad symbols per row (ZkOpts::standard)
OUT = {}


def clog2(x):
    return (x - 1).bit_length()


def npow2(x):
    return 1 << clog2(x)


MODELS = {"TinyLlama-1.1B": dict(d=2048, V=32000), "Llama-3-8B": dict(d=4096, V=128256)}

# ------------------------------------------------------------------ A. no-wrap clauses
A = {}
for name, m in MODELS.items():
    d, V = m["d"], m["V"]
    Vp = npow2(V)
    v = clog2(Vp)
    r = {"V_pad": Vp, "v": v}
    for wmax, tag in ((127, "w127"), (128, "w128")):
        B = d * 127 * wmax                      # |l| <= d * max|y| * max|W'|, y in [-127, 127]
        rhs = (2 * B << v) + (V - 1)            # |2^v (l_j - l_i) + (i - j)| maximum
        r[tag] = dict(B=B, B_log2=math.log2(B), keyed_rhs_max=rhs, keyed_rhs_log2=math.log2(rhs),
                      keyed_bits_needed=rhs.bit_length(),
                      pinless_margin_ok=((1 << 48) + rhs < P),
                      step_rhs_max=2 * B + 1, step_bits=(2 * B).bit_length())
    # final norm clauses inside D24's declared class (tn per width, Cn <= 2^20, Ceps <= 2^40, g0 <= 127)
    tn = 10 if d == 2048 else 9
    S_max = d * 32768 ** 2 + (1 << 40)          # sum x^2 + Ceps, int16 incl. -32768
    D_max = math.isqrt(S_max)
    clauses = {
        "num 2*g0*Cn*|x|": 2 * 127 * (1 << 20) * 32768,
        "D * 2^tn": D_max << tn,
        "2^(tn+1) * D * |y|": (D_max << (tn + 1)) * 127,
        "nr, ns (window)": 1 << (tn + 1 + D_max.bit_length()),
        "Dsq + a1 (= S)": S_max + 2 * D_max,
    }
    r["final_norm"] = dict(tn=tn, D_max_class_edge=D_max, D_bits=D_max.bit_length(),
                           window_bits=tn + 1 + D_max.bit_length(),
                           clause_log2={k: round(math.log2(x), 2) for k, x in clauses.items()},
                           all_below_p_half=all(x < P // 2 for x in clauses.values()))
    A[name] = r
OUT["A_no_wrap"] = A

# ------------------------------------------------------------------ B. keyed argmax
def admissible(l, j, v, limb_bits=48, pin_bits=None):
    """Does a witness exist with e one-hot at j?  A3: tok = j.  A6: delta_j = 0 -> M = l_j
    (2^v invertible).  A5: delta_i = 2^v (M - l_i) + (i - tok) mod p for every true i.
    A4: delta_i in [0, 2^limb_bits) (six byte limbs), and if pinned, in [0, 2^pin_bits)."""
    M = l[j]
    top = (1 << pin_bits) if pin_bits else (1 << limb_bits)
    for i, li in enumerate(l):
        dlt = (((M - li) << v) + (i - j)) % P
        if not (0 <= dlt < top):
            return False
    return True


def first_argmax(l):
    mx = max(l)
    return l.index(mx)


rng = random.Random(20261017)
B_res = {}
for name, m in MODELS.items():
    d, V = m["d"], m["V"]
    v = clog2(npow2(V))
    Bnd = d * 127 * 128
    w = A[name]["w127"]["keyed_bits_needed"]
    trials, bad = 0, 0
    for trial in range(300):
        n = rng.choice([2, 3, 5, 17, 40])
        kind = trial % 4
        if kind == 0:          # uniform extremes
            l = [rng.choice([-Bnd, Bnd, rng.randint(-Bnd, Bnd)]) for _ in range(n)]
        elif kind == 1:        # forced ties at the max
            base = [rng.randint(-Bnd, Bnd) for _ in range(n)]
            mx = max(base)
            for k in rng.sample(range(n), min(n, rng.randint(2, 4))):
                base[k] = mx
            l = base
        elif kind == 2:        # near-ties (difference 1)
            mx = rng.randint(-Bnd + 1, Bnd)
            l = [rng.choice([mx, mx - 1, -Bnd]) for _ in range(n)]
        else:                  # all equal
            c = rng.randint(-Bnd, Bnd)
            l = [c] * n
        want = first_argmax(l)
        for pin in (None, w):
            ok = [j for j in range(n) if admissible(l, j, v, 48, pin)]
            trials += 1
            if ok != [want]:
                bad += 1
    B_res[name] = dict(v=v, trials=trials, mismatches=bad, window_bits=w)
OUT["B_keyed_argmax"] = B_res

# ------------------------------------------------------------------ C. committed elements
def rows_of(size, lc):
    return max(1, size >> lc)


def lift(size, lc):
    return max(size, 1 << lc)


def stage_in(m, T, lc):
    """DESIGN 2.3: A_in = tok (T, lifted with h_q), m (V_pad); H_in = h_q (T lifted), h_tab (V_pad),
    u (Tab lifted); sites A 3 (tok x2, m), H 3 (h_q, h_tab, u)."""
    Vp, Tp = npow2(m["V"]), npow2(T)
    a = rows_of(lift(Tp, lc), lc) + rows_of(Vp, lc)
    h = 2 * (rows_of(lift(Tp, lc), lc) + rows_of(Vp, lc) + rows_of(lift(256, lc), lc))
    A_rows, H_rows = a + 2 * 3 + 2, h + 2 * 3 + 2
    return dict(lc=lc, A_rows=A_rows, H_rows=H_rows, elems=(A_rows + H_rows) << lc)


def stage_out(m, T_out, lc, limb_bits=8, pin=True, selector_T=None, shift=False):
    """DESIGN 3.2 (U8 keyed): A planes To x4 (D, Dsq, tok, M), Lo x1, Do x12 (x, xl0, xl1, y,
    rho x4, sigma x4), Vo x(1 + limbs) (e, lambda_k), Tab x1 (+ Tab16 x1 for U16), Ts x1 for the
    selector.  Lookups: Do 12 per entry, Lo 1, Vo limbs (+1 pin).  H: one Fp2 helper per two
    lookups per domain, Tab: table helper + u (+ U16 table helper).  A sites 47 (+1 selector,
    +1 shift), H sites 1 + 6 + hv + tables + 1."""
    d, V = m["d"], m["V"]
    Vp, dp = npow2(V), npow2(d)
    v = clog2(Vp)
    if limb_bits == 16:
        lc = max(lc, 16)
    w = ((2 * d * 127 * 127) << v) + (V - 1)
    w = w.bit_length()
    nl = -(-w // limb_bits)
    pin_n = 1 if (pin and nl * limb_bits != w) else 0
    Top = npow2(T_out)
    Do, Lo, Vo = Top * dp, 16 * Top, Top * Vp
    vplanes = 1 + nl
    lk_v = nl + pin_n
    hv = (lk_v + 1) // 2
    a = 4 * rows_of(Top, lc) + rows_of(lift(Lo, lc), lc) + 12 * rows_of(lift(Do, lc), lc) \
        + vplanes * rows_of(lift(Vo, lc), lc) + rows_of(lift(256, lc), lc)
    if limb_bits == 16:
        a += rows_of(1 << 16, lc)
    if selector_T:
        a += rows_of(npow2(selector_T), lc)
    a_sites = 1 + 1 + 11 + 1 + 1 + 13 + (vplanes + 2) + (vplanes + 1) + 1 + 1
    a_sites += (1 if selector_T else 0) + (1 if shift else 0)
    h = 2 * (rows_of(lift(Lo, lc), lc) + 6 * rows_of(lift(Do, lc), lc) + hv * rows_of(lift(Vo, lc), lc)
             + 2 * rows_of(lift(256, lc), lc))
    tabs = 1
    if limb_bits == 16:
        h += 2 * rows_of(1 << 16, lc)
        tabs = 2
    h_sites = 1 + 6 + hv + tabs + 1
    A_rows, H_rows = a + 2 * a_sites + 2, h + 2 * h_sites + 2
    lookups = 12 * lift(Do, lc) + lift(Lo, lc) + lk_v * lift(Vo, lc)
    return dict(lc=lc, window_bits=w, limbs=nl, pin=pin_n, A_rows=A_rows, H_rows=H_rows,
                a_sites=a_sites, h_sites=h_sites, elems=(A_rows + H_rows) << lc, byte_lookups=lookups)


C = {}
L8, TL = MODELS["Llama-3-8B"], MODELS["TinyLlama-1.1B"]
C["8B T32 stage IN (b) @2^11 (design)"] = stage_in(L8, 32, 11)
C["8B T32 stage IN (b) @2^12 (soundness floor)"] = stage_in(L8, 32, 12)
C["Tiny T32 stage IN (b) @2^10 (design)"] = stage_in(TL, 32, 10)
C["Tiny T32 stage IN (b) @2^12 (soundness floor)"] = stage_in(TL, 32, 12)
C["8B mode(i) OUT public row @2^12 (design)"] = stage_out(L8, 1, 12)
C["8B mode(i) OUT public row @2^12, no pin"] = stage_out(L8, 1, 12, pin=False)
C["8B mode(i) OUT hidden selector T32 @2^12"] = stage_out(L8, 1, 12, selector_T=32)
C["Tiny mode(i) OUT public row @2^11 (design)"] = stage_out(TL, 1, 11)
C["Tiny mode(i) OUT public row @2^12 (soundness floor)"] = stage_out(TL, 1, 12)
C["8B T512 mode(ii) OUT U8 keyed @2^16 (design)"] = stage_out(L8, 512, 16, shift=True)
C["8B T512 mode(ii) OUT U8 keyed @2^16, no pin"] = stage_out(L8, 512, 16, pin=False, shift=True)
C["8B T512 mode(ii) OUT U16 keyed @2^16 (design)"] = stage_out(L8, 512, 16, limb_bits=16, shift=True)
C["8B T512 mode(ii) OUT U16 keyed @2^16, no pin"] = stage_out(L8, 512, 16, limb_bits=16, pin=False, shift=True)
C["8B T32 total mode(i) (design)"] = dict(elems=C["8B T32 stage IN (b) @2^11 (design)"]["elems"] + C["8B mode(i) OUT public row @2^12 (design)"]["elems"])
C["8B T32 total mode(i) (repaired: IN @2^12, no pin)"] = dict(elems=C["8B T32 stage IN (b) @2^12 (soundness floor)"]["elems"] + C["8B mode(i) OUT public row @2^12, no pin"]["elems"])
OUT["C_elements"] = C

# ------------------------------------------------------------------ D. proximity terms
def per_opening_log2(log_n, inv_rate, q=Q):
    n = 1 << log_n
    delta = 1 - (n + q) / (n * inv_rate)
    return q * math.log2(1 - delta / 3)


D = {"per_opening_log2": {}}
for ln in range(8, 17):
    D["per_opening_log2"]["log_n %d rate 1/4" % ln] = round(per_opening_log2(ln, 4), 2)
D["per_opening_log2"]["log_n 8 rate 1/8 (frozen seam / toy endpoint)"] = round(per_opening_log2(8, 8), 2)
D["per_opening_log2"]["log_n 9 rate 1/8"] = round(per_opening_log2(9, 8), 2)
D["per_opening_log2"]["D15 convention (3/4)^256 (pads ignored)"] = round(256 * math.log2(0.75), 2)


def total_log2(terms):
    return math.log2(sum(2.0 ** t for t in terms))


conv = 256 * math.log2(0.75)
for label, n_old, new in (
    ("8B T32, design geometry (IN 2^11, OUT 2^12, token endpoints 2^8 rate 1/4)", 192,
     [per_opening_log2(11, 4)] * 2 + [per_opening_log2(12, 4)] * 2 + [per_opening_log2(8, 4)] * 2 + [conv] * 2),
    ("8B T32, design's own accounting (every new opening at (3/4)^256)", 192, [conv] * 8),
    ("8B T32, token endpoints at rate 1/8 but design stage widths (IN 2^11, OUT 2^12)", 192,
     [per_opening_log2(11, 4)] * 2 + [per_opening_log2(12, 4)] * 2 + [per_opening_log2(8, 8)] * 2 + [conv] * 2),
    ("Tiny T32, token endpoints at rate 1/8 but design stage widths (IN 2^10, OUT 2^11)", 132,
     [per_opening_log2(10, 4)] * 2 + [per_opening_log2(11, 4)] * 2 + [per_opening_log2(8, 8)] * 2 + [conv] * 2),
    ("8B T32, repaired (IN and OUT 2^12, token endpoints 2^8 rate 1/8)", 192,
     [per_opening_log2(12, 4)] * 4 + [per_opening_log2(8, 8)] * 2 + [conv] * 2),
    ("Tiny T32, design geometry (IN 2^10, OUT 2^11, token endpoints 2^8 rate 1/4)", 132,
     [per_opening_log2(10, 4)] * 2 + [per_opening_log2(11, 4)] * 2 + [per_opening_log2(8, 4)] * 2 + [conv] * 2),
    ("Tiny T32, repaired (IN and OUT 2^12, token endpoints 2^8 rate 1/8)", 132,
     [per_opening_log2(12, 4)] * 4 + [per_opening_log2(8, 8)] * 2 + [conv] * 2),
):
    base = total_log2([conv] * n_old)
    D[label] = dict(stack_alone_log2=round(base, 2), with_token_io_log2=round(total_log2([conv] * n_old + new), 2))
OUT["D_proximity"] = D

with open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "check_arith.json"), "w") as fh:
    json.dump(OUT, fh, indent=1)
print(json.dumps(OUT, indent=1))
