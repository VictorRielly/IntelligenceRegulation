#!/usr/bin/env python3
"""Tick 50 (queue item 23, H156): relaxed-cell wrap count. Standard library only, under a second.

Question: the smallness test only proves committed cells in (-2^18, 2^18). For each hosted sum or
degree-2 clause of the W16R2 8B block, how large can the integer behind the field value get if the
consumed word is rebuilt from relaxed cells, against the Lean premise 2^62 (CircuitMatmul.lean) and
the true wrap limit p/2 (about 2^63)?

Inputs are COUNTED from: formal/ZK60Formal/CircuitMatmul.lean 117-171 (class bounds),
CircuitNorm.lean 32, 96-97 (IsqrtRel, NormDivRel), CircuitSoftmax.lean 36 (SoftmaxDivRel),
accuracy_precision.rs 96 (multiplier_bits [5,5,6,8,6,4,6] for q,k,v,o,gate,up,down; order from
accuracy_public.rs 118-142), accuracy_public.rs 10-28 (geometry class), shape.rs 227 (8B geometry).
"""
from math import log2

P = 2**64 - 2**32 + 1
CELL = 2**18  # the smallness test's bound, |cell| < 2^18


def lg(x):
    return log2(x)


def word(n_bytes):
    """integer bound of a word rebuilt from n byte cells at radix 2^8, each cell < 2^18"""
    return CELL * sum(2 ** (8 * j) for j in range(n_bytes))


W16 = word(2)   # int16 word (or 13-bit quotient P) as two byte cells
W24 = word(3)   # 24-bit product word as three byte cells (or 16-bit low + top byte: same bound)
print("relaxed word bound: 2 byte cells 2^%.4f, 3 byte cells 2^%.4f" % (lg(W16), lg(W24)))
print("honest: int16 2^15, 24-bit 2^23, P 2^12; relaxed/honest: int16 x2^%.2f, 24-bit x2^%.2f\n"
      % (lg(W16) - 15, lg(W24) - 23))

LIM62, LIM63 = 2**62, P // 2
print("limits: Lean premise 2^62; wrap limit p/2 = 2^%.4f\n" % lg(LIM63))

# site: (label, class value, 8B value, relaxed-words value, cells-as-inputs value)
# cells-as-inputs = every operand of the product is a single cell at 2^18 (matmul per byte plane).
rows = []

def add(label, cls, b8, relaxed, cells):
    rows.append((label, cls, b8, relaxed, cells))

# hosted matmul sums: N * X * W * M, W = 127
add("Q,K,V  (N 4096, M<=2^6 8B / 2^14 class)", 4096 * 2**15 * 127 * 2**14,
    4096 * 2**15 * 127 * 2**6, 4096 * W16 * 127 * 2**14, 4096 * CELL * 127 * 2**14)
add("O      (N 4096, M<=2^8)", 4096 * 2**15 * 127 * 2**14,
    4096 * 2**15 * 127 * 2**8, 4096 * W16 * 127 * 2**14, 4096 * CELL * 127 * 2**14)
add("gate,up (N 4096, M<=2^6)", 4096 * 2**15 * 127 * 2**14,
    4096 * 2**15 * 127 * 2**6, 4096 * W16 * 127 * 2**14, 4096 * CELL * 127 * 2**14)
add("down   (N 14336 / 16384 class, H 24-bit, M<=2^6)", 16384 * 2**23 * 127 * 2**14,
    14336 * 2**23 * 127 * 2**6, 16384 * W24 * 127 * 2**14, 16384 * CELL * 127 * 2**14)
# private-by-private
add("score  (N 128 head dim / 4096 class, int16 x int16)", 4096 * 2**15 * 2**15,
    128 * 2**15 * 2**15, 4096 * W16 * W16, 4096 * CELL * CELL)
add("PV     (N 128 tokens / 2^24 class, P<=2^12 x int16)", 2**24 * 2**12 * 2**15,
    128 * 2**12 * 2**15, 2**24 * W16 * W16, 2**24 * CELL * CELL)
add("SC_SS  (N 4096, x*x, + ceps 2^24)", 4096 * 2**30 + 2**24,
    4096 * 2**30 + 2**24, 4096 * W16 * W16 + 2**24, 4096 * CELL * CELL + 2**24)
# degree-2 clauses
add("RoPE   (2 * 2^7 * x)", 2 * 2**7 * 2**15, 2 * 2**7 * 2**15, 2 * 2**7 * W16, 2 * 2**7 * CELL)
add("SiLU product a*u (|a|<=2^31 from the ACT table)", 2**31 * 2**15, 2**31 * 2**15, 2**31 * W16, 2**31 * CELL)
add("NormDiv 2^(tn+1)*d*y, d<2^24, tn<=16 class / 10 (ASSUMED)", 2**17 * 2**24 * 2**15,
    2**11 * 2**24 * 2**15, 2**17 * 2**24 * W16, 2**17 * 2**24 * CELL)
add("NormDiv g*x*2cn (g 127, cn<=2^24)", 127 * 2**15 * 2**25, 127 * 2**15 * 2**25, 127 * W16 * 2**25,
    127 * CELL * 2**25)
add("SoftmaxDiv P*sum (sum<=2^24)", 2**12 * 2**24, 2**12 * 2**24, W16 * 2**24, CELL * 2**24)

hdr = "%-58s %7s %7s | %9s %9s | %s" % ("site", "class", "8B", "relaxed", "cells@2^18", "verdict (relaxed words)")
print(hdr)
print("-" * len(hdr))
bad = []
for label, cls, b8, rel, cells in rows:
    v = "OK (%.1f bits under 2^62)" % (62 - lg(rel)) if rel <= LIM62 else (
        "over 2^62 but under p/2" if rel < LIM63 else "WRAPS (over p/2 by %.1f bits)" % (lg(rel) - lg(LIM63)))
    if rel > LIM62:
        bad.append(label)
    print("%-58s 2^%-5.1f 2^%-5.1f | 2^%-7.1f 2^%-7.1f | %s" % (label, lg(cls), lg(b8), lg(rel), lg(cells), v))

print("\nworst 'cells at 2^18 as every operand' value: 2^%.2f (limit 2^62: %s)" %
      (max(lg(r[4]) for r in rows), "never reached" if max(r[4] for r in rows) <= LIM62 else "reached"))
print("sites over 2^62 once words are rebuilt from relaxed cells:", len(bad))
for b in bad:
    print("  -", b)

# On the 8B shape, same table with relaxed words but 8B inner sizes and registered multipliers.
print("\nRelaxed words at the 8B shape (N and M as built, not class):")
r8 = [
    ("Q,K,V", 4096 * W16 * 127 * 2**6), ("O", 4096 * W16 * 127 * 2**8), ("gate", 4096 * W16 * 127 * 2**6),
    ("up", 4096 * W16 * 127 * 2**4), ("down", 14336 * W24 * 127 * 2**6), ("score", 128 * W16 * W16),
    ("PV", 128 * W16 * W16), ("SC_SS", 4096 * W16 * W16 + 2**24), ("NormDiv 2^(tn+1) d y, tn=10", 2**11 * 2**24 * W16),
]
for label, val in r8:
    print("  %-30s 2^%-6.2f %s" % (label, lg(val), "ok" if val <= LIM62 else ("<p/2" if val < LIM63 else "WRAPS")))

# Packing injectivity at the relaxed bound (authors' f1): three lanes, radix 2^20, cells in (-2^18, 2^18)
lane = 2**20
tot = (CELL - 1) * (1 + lane + lane**2)
print("\npacking (f1) at the relaxed bound: sum |cell|*radix^j < 2^%.3f; need < p/2 = 2^%.3f: %s; lane gap: |cell|<2^18 < radix/2 = 2^19: %s"
      % (lg(tot), lg(LIM63), tot < LIM63, CELL < lane // 2))

# Exactness (not wrap): a remainder of s bits is certified by its range lookup only.
print("\nexactness, not wrap: a remainder R rebuilt from relaxed byte cells reaches |R| < 2^%.1f (2 cells) / 2^%.1f (3 cells);"
      % (lg(W16), lg(W24)))
print("the floor identity 2^s q + R - 2^(s-1) = hosted fixes q only when R lies in [0, 2^s): s runs 8 to 24, so every remainder needs its exact range lookup.")

# TOY (explicit witness): SC_SS at the 8B shape. N = 4096 words, each rebuilt from two relaxed byte cells, so
# |x| < 2^26.0056, with sum x^2 = p + r for a small r. The field sees ss = r, an honest-looking sum of squares.
N = 4096
maxx = W16 - 1
v = 2**26 - 1
S0 = N * v * v
D = P - S0                       # distance from S0 up to p
xs = [v] * N
rem = D
for i in range(N):
    # largest d with (v+d)^2 - v^2 <= rem, within the cell bound
    d = 0
    lo, hi = 0, maxx - v
    while lo < hi:
        mid = (lo + hi + 1) // 2
        if 2 * v * mid + mid * mid <= rem:
            lo = mid
        else:
            hi = mid - 1
    d = lo
    xs[i] = v + d
    rem -= 2 * v * d + d * d
    if rem < 2 * v + 1:
        break
if rem > 0:
    # overshoot p by less than 2v+1 with one more entry still at v: residue r is then small and positive
    j = max(i for i, x in enumerate(xs) if x == v)
    xs[j] = v + 1
tot = sum(x * x for x in xs)
r = tot - P
print("\nTOY SC_SS witness: %d entries, max |x| = %d (< 2^%.4f, cell-bound ok: %s)" % (N, max(xs), lg(max(xs)), max(xs) < W16))
print("  sum x^2 = p + %d  (honest ss window is below 2^42; this residue is 2^%.1f), so ss mod p = %d" % (r, lg(max(r, 1)), r))
print("  honest int16 inputs could never give this: max honest sum of squares is 2^%.1f" % lg(N * 2**30))
