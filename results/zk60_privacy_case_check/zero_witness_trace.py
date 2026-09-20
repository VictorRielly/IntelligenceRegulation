#!/usr/bin/env python3
"""Paper trace of `private_block::witness::build` on the ALL-ZERO input.

A transcription of hashline/src/private_block/witness.rs (read at the lines
named in the check document) with the input fixed to zero and the public
statement left SYMBOLIC wherever the zero input makes it irrelevant.  The
question: does the honest witness builder accept the all-zero input for EVERY
public statement that `AttentionPublic::new` / `FeedForwardPublic::new` admit?

This is a paper check, not a run of the Rust code.  No witness value of any
real input appears here; the only "witness" is the all-zero one.
"""
import math

# calibration constants, layout.rs:40-70
T, D, H, DH, KV, F = 32, 16, 2, 8, 8, 16
NORM_TN, NORM_CN, NORM_CEPS, NORM_WRHO = 11, 1024, 1, 29
SH_QKV, SH_ROPE, SH_S, SH_O, SH_AO = 7, 7, 6, 9, 7
F_E, F_P, WRHO_S, MASK_SCORE = 9, 9, 14, -127
SH_G, SH_H_PROD, SH_Z = 7, 14, 6

fails = []
notes = []
def check(cond, what):
    if not cond:
        fails.append(what)
    return cond

def limbs(v, count):
    return [(v >> (8*k)) if k+1 == count else ((v >> (8*k)) & 255) for k in range(count)]

def half(sh):
    return 0 if sh == 0 else 1 << (sh-1)

def requant(acc, sh):
    y = (acc + half(sh)) >> sh
    return y, acc - (y << sh)

print("== the all-zero input through witness::build ==")

# ---- rms_norm on an all-zero row (used for norm_a and, on xres1 = 0, norm_m)
ss = NORM_CEPS + 0
d = math.isqrt(ss)
a1 = ss - d*d
a2 = 2*d - a1
check(d < (1 << 24) and 0 <= a1 < (1 << 24) and 0 <= a2 < (1 << 24), "norm denominator range")
dv = d << NORM_TN
den = 2*dv
check(den > 0, "norm denominator > 0  [THE zero-input trap: it needs NORM_CEPS >= 1]")
num = 2*0*0*NORM_CN + dv          # row[i] = 0, so gamma drops out entirely
q = num // den
rho = num % den
sigma = den - 1 - rho
check(-127 <= q <= 127, "norm quotient class")
check(rho < (1 << NORM_WRHO) and sigma < (1 << NORM_WRHO), "norm rho/sigma window")
print(f"  ss={ss} D={d} a1={a1} a2={a2} den={den} y={q} rho={rho} sigma={sigma}")
print(f"  D limbs {limbs(d,3)}, a1 {limbs(a1,3)}, a2 {limbs(a2,3)} -> all bytes: "
      f"{all(0 <= x < 256 for x in limbs(d,3)+limbs(a1,3)+limbs(a2,3))}")
rl, sl = limbs(rho, 4), limbs(sigma, 4)
scale = 1 << (32 - NORM_WRHO)
check(all(0 <= x < 256 for x in rl+sl) and scale*rl[3] < 256 and scale*sl[3] < 256,
      "norm limb lookups inside the U8 table")
print(f"  rho limbs {rl} sigma limbs {sl}; top-limb lookups {scale*rl[3]}, {scale*sl[3]}")

# ---- every quantize site: the accumulator is 0 because the input is 0
print("  quantize sites at acc = 0 (y, biased remainder, and its U8 lookups):")
for name, sh, lo, hi, lookups in [
    ("Q/K/V",  SH_QKV, -127, 127, [("byte", 1), ("scaled", 2)]),
    ("QR/KR",  SH_ROPE, -127, 127, [("byte", 1), ("scaled", 2)]),
    ("score",  SH_S, -127, 127, [("byte", 1), ("scaled", 4)]),
    ("O",      SH_O, -127, 127, [("limb0", 1), ("limb1", 1), ("limb1x128", 128)]),
    ("AO",     SH_AO, -32768, 32767, [("byte", 1), ("scaled", 2)]),
    ("gate",   SH_G, -128, 127, [("byte", 1), ("scaled", 2)]),
    ("product", SH_H_PROD, -32768, 32767, [("limb0", 1), ("limb1", 1), ("limb1x4", 4)]),
    ("down",   SH_Z, -32768, 32767, [("byte", 1), ("scaled", 4)]),
]:
    y, rem = requant(0, sh)
    biased = rem + half(sh)
    two = limbs(biased, 2)
    vals = []
    for kind, k in lookups:
        v = {"byte": biased, "scaled": k*biased, "limb0": two[0],
             "limb1": two[1], "limb1x128": 128*two[1], "limb1x4": 4*two[1]}[kind]
        vals.append(v)
    ok = lo <= y <= hi and all(0 <= v < 256 for v in vals)
    check(ok, f"{name} quantize at zero")
    print(f"    {name:8s} sh={sh:2d} y={y} biased_rem={biased:5d} lookups {vals} -> {'ok' if ok else 'FAIL'}")

# ---- causal softmax at all-zero scores.  exp[0] is PINNED to 2^F_E by
#      AttentionPublic::new (private_block.rs:138) - this is what makes the
#      zero input valid for every admissible public statement.
one_e = 1 << F_E
worst = []
for t in range(T):
    masked = [0 if j <= t else MASK_SCORE for j in range(T)]
    best = max(masked)
    arg = masked.index(best)
    check(arg <= t, "causal maximum attainment at zero")
    deltas = [best - m for m in masked]
    check(all(0 <= dl < 256 for dl in deltas), "exp difference window at zero")
    total = (t+1)*one_e                      # E[delta=0] = exp[0] = 2^F_E
    check((1 << F_E) <= total <= (T << F_E), "softmax denominator window at zero")
    for j in range(T):
        if j <= t:
            num = one_e << F_P
            qq, rr = num // total, num % total
        else:
            qq, rr = 0, 0
        sg = total - 1 - rr
        ok = 0 <= sg < (1 << WRHO_S) and 0 <= qq <= (1 << F_P)
        check(ok, f"softmax quotient/remainder at zero (t={t}, j={j})")
        pl, rl2, sl2 = limbs(qq, 2), limbs(rr, 2), limbs(sg, 2)
        lk = [pl[0], pl[1], 64*pl[1], rl2[0], rl2[1], 4*rl2[1], sl2[0], sl2[1], 4*sl2[1]]
        check(all(0 <= v < 256 for v in lk), f"softmax U8 lookups at zero (t={t}, j={j})")
        worst.append((sg, 4*sl2[1], qq, 64*pl[1]))
msig = max(w[0] for w in worst)
print(f"  softmax: max sigma_s = {msig} of the window {1 << WRHO_S} "
      f"(headroom {(1 << WRHO_S) - 1 - msig}); max scaled top limb {max(w[1] for w in worst)} of 255")
print(f"  softmax: max p = {max(w[2] for w in worst)} of the window {1 << F_P}; "
      f"max 64*p_limb1 = {max(w[3] for w in worst)} of 255")

# ---- feed-forward: gate 0 -> a16 = act[128] (ARBITRARY i16, adversary's choice),
#      up = 0, product = a16 * 0 = 0, down = 0, residual 2 = 0.
for a128 in (-32768, -1, 0, 1, 32767):
    hacc = a128 * 0
    h16, rh = requant(hacc, SH_H_PROD)
    check(-32768 <= h16 <= 32767, "FFN product class at zero")
    check(h16 == 0, "FFN product is zero whatever act[128] is")
print("  feed-forward: a16 = act[128] is arbitrary but multiplies u16 = 0, so h16 = z16 = 0")

print()
if fails:
    print("REFUSED at:", *fails, sep="\n  ")
else:
    print("RESULT: the all-zero input passes every range refusal of witness::build,")
    print("        for EVERY public statement the two constructors admit.")
    print("        The load-bearing public-statement facts are:")
    print("          * NORM_CEPS = 1 (layout.rs:54): ss = 1 > 0, so D = 1 and den = 4096 > 0.")
    print("            At NORM_CEPS = 0 the zero input is REFUSED ('norm denominator').")
    print("          * exp[0] == 2^F_E, enforced by AttentionPublic::new (private_block.rs:138).")
    print("            With exp[0] = 0 the zero input is REFUSED ('softmax denominator').")
    print("          * MASK_SCORE = -127, so the masked delta 127 stays inside [0, 256).")
