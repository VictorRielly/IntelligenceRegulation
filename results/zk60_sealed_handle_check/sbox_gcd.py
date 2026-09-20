#!/usr/bin/env python3
"""Independent arithmetic check for the sealed-handle literature review.

Question: is x^d a permutation of GF(p) for the Goldilocks prime
p = 2^64 - 2^32 + 1?  x^d permutes GF(p)^* iff gcd(d, p-1) == 1.

Also checks the S-box-count arithmetic claimed for Poseidon2 at width 12.
"""

from math import gcd

p = 2**64 - 2**32 + 1
pm1 = p - 1

print("p      = 2^64 - 2^32 + 1 =", p)
print("p - 1  = 2^64 - 2^32     =", pm1)
print("p - 1  = 2^32 * (2^32 - 1) ?", pm1 == 2**32 * (2**32 - 1))

# Factor p-1 = 2^32 * (2^32 - 1); and 2^32 - 1 = 3 * 5 * 17 * 257 * 65537
# (product of the five known Fermat primes F0..F4).
fermat = [3, 5, 17, 257, 65537]
prod = 1
for f in fermat:
    prod *= f
print("2^32 - 1 =", 2**32 - 1, "= 3*5*17*257*65537 =", prod,
      "->", (2**32 - 1) == prod)

# Full factorisation of p-1, verified by trial reconstruction.
factors = {2: 32, 3: 1, 5: 1, 17: 1, 257: 1, 65537: 1}
recon = 1
for base, e in factors.items():
    recon *= base**e
print("factorisation of p-1: 2^32 * 3 * 5 * 17 * 257 * 65537 =", recon,
      "->", recon == pm1)

print()
for d in (2, 3, 5, 7, 11, 13):
    g = gcd(d, pm1)
    print(f"gcd({d:2d}, p-1) = {g:5d}   -> x^{d} is "
          f"{'A PERMUTATION' if g == 1 else 'NOT a permutation'} of GF(p)")

print()
print("Poseidon2 S-box-count arithmetic (R_F full rounds hit all t "
      "elements, R_P partial rounds hit 1):")
for (t, rf, rp) in [(12, 8, 22), (8, 8, 22), (12, 8, 21), (16, 8, 22),
                    (12, 8, 13), (12, 8, 14), (8, 8, 13)]:
    print(f"  t={t:2d} R_F={rf} R_P={rp}: {rf}*{t} + {rp} = "
          f"{rf * t + rp} S-boxes/permutation")

print()
print("Rescue-Prime style RAW S-box evaluations (S-box on the FULL state "
      "in BOTH half-rounds: 2*N*t):")
for (t, n) in [(12, 7), (12, 8), (16, 7), (16, 8), (12, 9)]:
    print(f"  t={t:2d} N={n}: 2*{n}*{t} = {2 * n * t} S-box evals/permutation")
print("  NB: the ARITHMETISATION is cheaper -- Monolith App. D.2 reports a")
print("  degree-7 constraint spanning a WHOLE Rescue round, so N*t, not 2*N*t.")
for (t, n) in [(12, 7), (12, 8)]:
    print(f"  t={t:2d} N={n}: {n}*{t} = {n * t} degree-7 constraints/permutation")

print()
print("Sponge security from the flat-sponge / indifferentiability bound "
      "p^(c/2) >= 2^kappa, i.e. kappa = c*log2(p)/2, for log2(p)=64:")
for c in (4, 6, 8):
    print(f"  capacity c={c}: {c}*64/2 = {c * 64 // 2} bits")

print()
print("Per-absorbed-field-element cost, from Monolith (eprint 2023/1025) "
      "Table 4 (per permutation) divided by the sponge rate r:")
# (name, lookups, nonlinear constraints, witness size, rate)
table4 = [
    ("Monolith-64-sponge  (t=12)", 192, 64, 480, 8),
    ("Tip5                (t=16)", 160, 60, 380, 10),
    ("Tip4'               (t=12)", 160, 40, 360, 8),
    ("Poseidon/Poseidon2  (t=12)", 0, 118, 118, 8),
    ("Rescue-Prime        (t=12)", 0, 96, 96, 8),
]
for name, lk, nc, w, r in table4:
    print(f"  {name}: {lk:3d} lookups /{r} = {lk / r:5.1f}   "
          f"witness {w:3d}/{r} = {w / r:5.2f} committed values per element")

print()
print("Reconstruction of the Table-4 witness sizes from Monolith App. D.2:")
print("  Tip5: per round 4 split-and-lookup S-boxes * 8 bytes * 2 vars "
      f"= {4 * 8 * 2} lookup vars, + 12 power-map outputs = {4 * 8 * 2 + 12};"
      f" * 5 rounds = {(4 * 8 * 2 + 12) * 5}")
print("  Monolith-64 formula 6*(2us+u) + 5t + u with u=4, s=8:")
for t in (8, 12):
    print(f"    t={t:2d}: {6 * (2 * 4 * 8 + 4) + 5 * t + 4} "
          f"(Table 4 prints {460 if t == 8 else 480} -- 8 higher)")
print(f"  Poseidon2 t=12: 8*12 + 22 = {8 * 12 + 22} degree-7 S-boxes, "
      "one witness each")
print(f"  Rescue-Prime t=12, N=8: 8*12 = {8 * 12} degree-7 constraints")

print()
print("Poseidon2 Eq.(1) round formula, ignoring the R_GB term:")
print("  R_P >= ceil(1.075 * (min(kappa,log2 p)/log2(d) + log_d(t) - 5))")
import math
for (n, t, d, paper_rp) in [(64, 8, 7, 22), (64, 12, 7, 22), (31, 16, 5, 14),
                            (31, 24, 5, 22), (256, 2, 5, 56), (256, 3, 5, 56)]:
    k = min(128, n)
    v = 1.075 * (k / math.log2(d) + math.log(t, d) - 5)
    print(f"  (n={n:3d}, t={t:2d}, d={d}): {v:6.3f} -> ceil {math.ceil(v):2d}"
          f"   paper Table 1 R_P = {paper_rp}"
          f"{'  <- formula alone is LOWER; the R_GB term dominates' if math.ceil(v) < paper_rp else ''}")
