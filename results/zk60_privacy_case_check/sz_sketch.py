#!/usr/bin/env python3
"""MY OWN SKETCH (not a proof): what a Schwartz-Zippel bound for the
disclosed-dimension statement would look like, and what it would come to.

Shape of the statement, from the reduction the joint-view lane uses:
  disclosed dimension = 256 * k0 + (a u-row term),
  k0 = dim { p in rowspace(rho) : p vanishes on every NON-DATA row }.
For one commitment with G group vectors (groups + the proximity vector) and
R non-data rows, let M(chal) be the R x G matrix whose (r, g) entry is the
combined row weight of group g at row r.  Then
  k0 = G - rank M,     so   k0 = 0  <=>  some G x G minor of M is nonzero.
Each entry is a polynomial in the independent transcript challenges:
  lambda (degree 1) times a claim coefficient built from the terminal-mask
  challenges e through products (1 - e) (degree <= 2 at this profile, at most
  two extension rounds per slot).  Budget: degree <= 3 per entry.
A capture with rank M = G exhibits ONE minor that is nonzero AT THAT POINT,
which is exactly what "not identically zero" needs.  Schwartz-Zippel over the
quadratic extension then bounds the bad set.
"""
import math

P = (1 << 64) - (1 << 32) + 1
F2 = P * P
ENTRY_DEG = 3            # my budget; the write-up must justify it

# (name, G = groups + prox, R = non-data rows)
COMMITMENTS = [("A", 35 + 1, 455 - 213),
               ("H", 9 + 1, 384 - 280),
               ("Input endpoint", 1 + 1, 7 - 2),
               ("Output endpoint", 1 + 1, 7 - 2),
               ("M (50 rows, 46 coefficient rows + b,u)", 46 + 1, 4)]

total = 0.0
print("commitment                                G    R   minor degree   bound")
for name, g, r in COMMITMENTS:
    if r < g:
        print(f"{name:40s} {g:4d} {r:4d}   (R < G: the reduction's k0 = 0 cannot be a"
              f" full-rank condition on this block; the M channel needs its own argument)")
        continue
    deg = g * ENTRY_DEG
    b = deg / F2
    total += b
    print(f"{name:40s} {g:4d} {r:4d} {deg:9d}      2^{math.log2(b):.1f}")
print()
print(f"union over the commitments that fit the shape: 2^{math.log2(total):.1f}")
print(f"with a x100 slack on every degree:            2^{math.log2(total*100):.1f}")
print()
print("For comparison, the terms already on the page:")
print(f"  fp() bias at the toy shape   2^-77.7")
print(f"  LogUp collision (recounted)  2^-112.0")
print("So on this sketch the generic-rank term would NOT dominate: closing U-3(a)")
print("changes a LABEL (computed -> proved), not the size of the bound.")
