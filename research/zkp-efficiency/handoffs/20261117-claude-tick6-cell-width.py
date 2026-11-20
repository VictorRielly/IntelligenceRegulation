#!/usr/bin/env python3
"""Tick 6 (2026-11-17 UTC): columns per cell matrix (k) and the honest-cell class of every A plane of one block
(W16R2_8B_T128_H24), then the packed-plus-digits cost against today's A data rows.

Run:  python3 -I research/zkp-efficiency/handoffs/20261117-claude-tick6-cell-width.py
Standard library only, reads no file, writes nothing, under a second.

COUNTED inputs (file:line are in the handoff): plane lists accuracy_layout.rs:122-160 (new_w16), lookups_w16
accuracy_layout.rs:296-343, remainder widths accuracy_precision.rs:55-100, limbs_of range16.rs:114, census rows
results/zk60_effplan_20261105/census.log (A D 608, F 1152, Q 192, Kv 48, S 256, T/Ht/L 8, Tab 15 = 2279).
ASSUMED: the byte-scale window of the smallness test and its z = 6.4 are tick 5's; remainders are uniform;
the plane-to-class table says which planes are certain, conditional or unmeasured.
"""
import math

TAU = 128
BOUND = 2 ** 17
Z = 6.4


def rms_cap(k):
    """max honest RMS of a cell so that 1% of 6.4e7 ternary combinations stay inside +-2^17 (tick 5, DERIVED)."""
    return BOUND / Z / math.sqrt(k / 2)


assert abs(rms_cap(4096) - 452.6) < 1
print("RMS cap: k=4096 %.0f, k=7168 %.0f, k=8191 %.0f, k=1024 %.0f, k=128 %.0f" % tuple(rms_cap(k) for k in (4096, 7168, 8191, 1024, 128)))

# rows per plane by domain (census.log): D 32, Q 32, Kv 8, S 32, F 128
ROWS = {"D": 32, "Q": 32, "Kv": 8, "S": 32, "F": 128}
K_NAT = {"D": 4096, "Q": 4096, "Kv": 1024, "S": 128, "F": 7168}   # columns = per-token channels; F split in two (14336 > 8191)

# class: P pass by range (int8 word or remainder/limb of at most 8 bits), C certain fail (a 16-bit lookup limb: uniform
# centred RMS 2^16/sqrt(12) = 18,919), M conditional (remainder of 9..16 bits; fails from 11 bits), W unmeasured int16 word
PLANES = []


def add(dom, name, cls, n=1):
    for i in range(n):
        PLANES.append((dom, name if n == 1 else f"{name}{i}", cls))


# D: 7 int16 words + 12 limb planes (NR NS MR MS: 24-bit remainders = 16 + 8; RAL: ao 17..24 = 16 + top; RDL: down 17..24)
for w in ("X", "Y", "AO", "X1", "YM", "Z", "X2"):
    add("D", w, "W")
for r in ("NR", "NS", "MR", "MS", "RAL", "RDL"):
    add("D", r + "_low16", "C")
    add("D", r + "_top", "P")
# Q: int8 words Q QR O; RQL (q 9..16), RQRL (rope 7 bits), RO (pv 9..16)
for w in ("Q", "QR", "O"):
    add("Q", w, "P")
add("Q", "RQL", "M"); add("Q", "RQRL", "P"); add("Q", "RO", "M")
for w in ("K", "V", "KR"):
    add("Kv", w, "P")
add("Kv", "RKL", "M"); add("Kv", "RVL", "M"); add("Kv", "RKRL", "P")
# S: S8 int8, ZSEL 0/1, E and P unmeasured, RSL (score 17..24 = 16 + top), division remainders SR SG (width wrho_s <= 16)
add("S", "S8", "P"); add("S", "ZSEL", "P"); add("S", "E", "W"); add("S", "P", "W")
add("S", "RSL_low16", "C"); add("S", "RSL_top", "P"); add("S", "SR", "M"); add("S", "SG", "M")
# F: G8 int8; A_SCALED U H unmeasured int16; RGL (gate 17..24 = 16 + top), RU (9..16), HT (8-bit top limb of H24), RH (16-bit)
add("F", "G8", "P")
for w in ("A_SCALED", "U", "H16"):
    add("F", w, "W")
add("F", "RGL_low16", "C"); add("F", "RGL_top", "P"); add("F", "RU", "M"); add("F", "HT", "P"); add("F", "RH16", "C")

rows = {}
for dom, name, cls in PLANES:
    rows[cls] = rows.get(cls, 0) + ROWS[dom]
total = sum(rows.values())
assert total == 2256
# per-domain plane totals must equal the census: D 19 (7 words + 12), Q 6, Kv 6, S 8, F 9
for dom, n in (("D", 19), ("Q", 6), ("Kv", 6), ("S", 8), ("F", 9)):
    assert sum(1 for d, _, _ in PLANES if d == dom) == n, dom
assert total + 8 + 15 == 2279
print("A cell rows by class (of 2,256; plus 8 T/Ht/L and 15 Tab rows = 2,279):")
for c, label in (("P", "pass by range"), ("C", "certain fail (16-bit limb)"), ("M", "conditional (9..16-bit remainder)"), ("W", "unmeasured int16 word")):
    print("  %s %-36s %4d rows  %5.1f%% of 2,256   %5.1f%% of 2,279" % (c, label, rows[c], 100 * rows[c] / 2256, 100 * rows[c] / 2279))

# uniform centred b-bit remainder RMS vs cap
for b in (8, 9, 10, 11, 12, 16):
    r = 2 ** b / math.sqrt(12)
    print("  uniform centred %2d-bit cell: RMS %7.0f  (cap at k=4096 %.0f, 7168 %.0f)  %s" % (
        b, r, rms_cap(4096), rms_cap(7168), "pass" if r <= rms_cap(7168) else "fail"))

# cost against today's 2,279 A data rows (1 word per cell today); a planar cell costs 1/3 + 2 tau / k words packed
def cost(split_c=2, split_m=1, split_w=1, k_s=128, s_unpacked_if_bad=True):
    tot = 0.0
    for dom, name, cls in PLANES:
        n = ROWS[dom]
        cells = {"P": 1, "C": split_c, "M": split_m, "W": split_w}[cls]
        k = K_NAT[dom] if dom != "S" else k_s
        per = 1 / 3 + 2 * TAU / k
        if per >= 1.0 and s_unpacked_if_bad:   # keep a plane that would cost more than today unpacked
            per = 1.0
            cells = 1
        tot += n * cells * per
    return tot + 8 + 15


print("\nA data rows after packed cells + digits (today 2,279), tau = 128:")
for label, kw in (
    ("optimistic: only certain fails split in two byte cells, S unpacked (k=128)", dict(split_c=2, split_m=1, split_w=1, k_s=128)),
    ("optimistic with S as one 4,096-column matrix (heads in columns)", dict(split_c=2, split_m=1, split_w=1, k_s=4096)),
    ("middle: conditional remainders split in two too", dict(split_c=2, split_m=2, split_w=1, k_s=4096)),
    ("pessimistic: int16 words and conditional remainders all split in two", dict(split_c=2, split_m=2, split_w=2, k_s=4096)),
    ("pessimistic with S unpacked", dict(split_c=2, split_m=2, split_w=2, k_s=128)),
):
    t = cost(**kw)
    print("  %-72s %7.0f rows  = %.3f of today" % (label, t, t / 2279))

# harmonic k and arithmetic k
cells_w = [(K_NAT[d], ROWS[d]) for d, _, _ in PLANES]
mean_k = sum(k * r for k, r in cells_w) / sum(r for _, r in cells_w)
harm_k = sum(r for _, r in cells_w) / sum(r / k for k, r in cells_w)
print("\nrow-weighted mean k = %.0f, harmonic k (what the digit term follows) = %.0f (S at 128)" % (mean_k, harm_k))
cells_w2 = [((K_NAT[d] if d != "S" else 4096), ROWS[d]) for d, _, _ in PLANES]
print("with S at 4,096: mean k = %.0f, harmonic k = %.0f" % (
    sum(k * r for k, r in cells_w2) / sum(r for _, r in cells_w2), sum(r for _, r in cells_w2) / sum(r / k for k, r in cells_w2)))
