#!/usr/bin/env python3
"""Tick 63 (queue item 106): can one opening group carry a block's seven committed-weight claims, and what are the bytes
if not. Standard library only, reads no file. The wire formula is tick 54's / tick 59's / tick 61's, unchanged
(wire.rs:106-108 as cited there): (G+1)(n+qpad)*16 + Q*(8 + 8*rows + 32 + 32*path), n = 2^16, rate 1/4, k = 16, Q = 172.
Sections:
  A. which coordinates of a claim point can be common to the seven matmuls (bit counts from shape.rs:2683-2693 and
     the 8B profile: d_pad 4096, q_pad 4096, kv width 1024, f_pad 16384)
  B. receipt bytes at G = 1, 4, 7 groups a block, dense and padded layout, 8B (32 blocks) and the classifier (26 blocks)
  C. the cost of one more group a block, and the column-part lower bound if the tail may use only verifier-drawn bits
  D. the once-a-request embedding and head openings of tick 59, restated with their group count
"""
import math

n, rate, k, Q = 1 << 16, 4, 16, 172
qpad = k * Q
path = int(math.log2(rate * n))


def wire(rows, G, n=n, Q=Q):
    qp = k * Q
    pth = int(math.log2(rate * n))
    vec = (G + 1) * (n + qp) * 16          # G group vectors + the proximity vector, each n + q_pad Fp2 (16 B)
    col = Q * 8 * rows                     # opened columns, 8 B per row
    rest = Q * (8 + 32 + 32 * pth)         # position, salt, path
    return vec + col + rest


# ---------------------------------------------------------------------------------------------------------- A
print("== A. bits of each matmul's claim point (8B profile; log2 of the padded axes: d 12, q 12, kv 10, f 14)")
lg = lambda x: int(math.log2(x))
d, q, kv, f = 4096, 4096, 1024, 16384
mats = [  # name, output bits (r_j, drawn by the verifier BEFORE the slot's sumcheck), inner bits (rho, the slot's own challenges)
    ("Wq", lg(q), lg(d)), ("Wk", lg(kv), lg(d)), ("Wv", lg(kv), lg(d)), ("Wo", lg(d), lg(q)),
    ("Wg", lg(f), lg(d)), ("Wu", lg(f), lg(d)), ("Wd", lg(d), lg(f)),
]
for name, ob, ib in mats:
    print(f"  {name}: r_j {ob:>2} bits (verifier draw), rho {ib:>2} bits (sumcheck end), claim point {ob+ib} bits")
min_out = min(ob for _, ob, _ in mats)
print(f"  smallest output axis {min_out} bits: a tail made only of r_j bits can be at most 2^{min_out} columns wide")
print(f"  at n = 2^16 the tail is 16 coordinates; a matrix with an inner axis of 12 bits supplies 12 rho coordinates and "
      f"{16-12} r_j coordinates; Wd (inner 14) supplies 14 rho coordinates, 2 more than the others share, "
      f"which can sit on the ROW axis (row weights are general vectors, pcs.rs:957-964)")

# ---------------------------------------------------------------------------------------------------------- B
print("\n== B. receipt bytes added by a committed-weight opening, n = 2^16, rate 1/4, k = 16, Q' = 172")
profiles = [
    # name, blocks, today's receipt bytes, rows dense (true words), rows padded
    ("8B W16R2 (32 blocks)", 32, 818_728_672, 3328, 3712),
    ("classifier W16R2 Shieldstral (26 blocks)", 26, 669_600_000, 1776, 3712),
]
table = {}
for name, blocks, today, rd, rp in profiles:
    print(f"\n  {name}; today's receipt {today/1e6:.1f} MB")
    print(f"  {'groups a block':>15} | {'dense rows '+str(rd):>20} | {'padded rows '+str(rp):>20}")
    for G in (1, 2, 4, 7):
        a = wire(rd, G) * blocks
        b = wire(rp, G) * blocks
        table[(name, G)] = (a, b)
        print(f"  {G:>15} | {a/1e6:>9.1f} MB x{1+a/today:.2f}   | {b/1e6:>9.1f} MB x{1+b/today:.2f}")
    # the four figures the queue item asks for: dense and padded at G = 1 and G = 7
    a1, b1 = table[(name, 1)]
    a7, b7 = table[(name, 7)]
    print(f"  the four figures: dense G=1 {a1/1e6:.1f}, dense G=7 {a7/1e6:.1f}, padded G=1 {b1/1e6:.1f}, padded G=7 {b7/1e6:.1f} MB")
    print(f"  ratio G=7 / G=1: dense x{a7/a1:.2f}, padded x{b7/b1:.2f}")

# ---------------------------------------------------------------------------------------------------------- C
print("\n== C. marginal cost of one more group, and the narrow-row lower bound")
vec_per_group = (n + qpad) * 16
print(f"  one more group = one more vector of n + q_pad = {n+qpad:,} Fp2 = {vec_per_group:,} B a block "
      f"= {vec_per_group*32/1e6:.2f} MB at 32 blocks, {vec_per_group*26/1e6:.2f} MB at 26 blocks")
# a tail made only of verifier-drawn bits needs n <= 2^10 (section A); count only the column part, with Q' = 172 held
# (a LOWER bound: Q' for a narrower row is larger, tick 54 table)
for nn in (1 << 10,):
    rows = 218_103_808 // nn
    colpart = 172 * 8 * rows
    print(f"  n = 2^10: rows a block {rows:,}; column part alone at Q' = 172 (a lower bound) = {colpart/1e6:.1f} MB a block, "
          f"{colpart*32/1e9:.1f} GB at 32 blocks")

# ---------------------------------------------------------------------------------------------------------- D
print("\n== D. tick 59's once-a-request embedding and head openings, restated with their group count")
for name, rows in (("embedding 8B", 8016), ("head 8B", 8016), ("embedding classifier", 6144)):
    one = wire(rows, 1)
    print(f"  {name}: {rows} rows at G = 1 (ASSUMED one claim, one group; the head claim form was not read) {one/1e6:.2f} MB; "
          f"at G = 2 {wire(rows,2)/1e6:.2f} MB")
