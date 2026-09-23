#!/usr/bin/env python3
"""G-R4 check, item 4: the three residual figures, recomputed independently.

Independent of the draft's law_and_residual.py: the per-draw distance is
computed here by COUNTING PREIMAGES (not from the closed form), and the
closed form is then compared with it. Exact rational arithmetic
(fractions.Fraction); log2 of a ratio of big integers via math.log2 on each
(Python's math.log2 is exact-rounding for arbitrary-size ints to double
precision, ample for 6 decimals).

Run:  python3 residuals_check.py      (exit 0: ALL ASSERTIONS PASSED)
"""
from fractions import Fraction
import math

P = 2**64 - 2**32 + 1
M = 2**128                      # one fp() draw: a uniform 128-bit integer, reduced mod p


def log2q(x: Fraction) -> float:
    return math.log2(x.numerator) - math.log2(x.denominator)


# 1. TV(U mod p, uniform on Fp) by counting preimages
k, r = divmod(M, P)             # 2^128 = k p + r
assert r == P - 2**32, "2^128 mod p is not p - 2^32"
# residues 0..r-1 have k+1 preimages, residues r..p-1 have k
over = r * (Fraction(k + 1, M) - Fraction(1, P))        # mass above uniform
under = (P - r) * (Fraction(1, P) - Fraction(k, M))     # mass below uniform
assert over == under, "the two halves of the L1 distance differ"
delta = over                                             # TV = half the L1 = the excess mass
closed = Fraction(r * (P - r), P * M)
assert delta == closed, "preimage count disagrees with the closed form r(p-r)/(p 2^128)"
assert delta < Fraction(1, 2**96)
print(f"1. delta = TV(one fp(), U(Fp)) = r(p-r)/(p 2^128) = 2^{log2q(delta):.10f}  (< 2^-96: {delta < Fraction(1, 2**96)})")
print(f"   exactly (1 - 2^32/p) * 2^-96; relative per-outcome bias (k+1)/k - 1 = 2^{math.log2(1 / k):.6f} (the rng.rs '2^-64', not a distance)")

# 2. N: the fp() draw counts (stage 36/46 measured parts, as quoted in the draft and the ledger)
BLOCK = {"toy": 320_908, "rung-G": 687_028, "125M": 9_029_804}
ENDPOINT = {"toy": 3_072, "rung-G": 7_424, "125M": 91_392}
BOUNDARY = {"rung-G": 8_704, "125M": 108_032}
# the 125M endpoint and boundary counts from their geometry: 5 (endpoint) / 6 (boundary) mask
# rows of n = 2^14, plus rows x Q = 256 pads (37 endpoint rows; the boundary commits 38)
assert ENDPOINT["125M"] == 5 * 2**14 + 37 * 256
assert BOUNDARY["125M"] == 6 * 2**14 + 38 * 256
# the toy block: 5,396,672 stream bytes = 320,908 x 16 + 8,192 salts x 32 (claim A-5)
assert 320_908 * 16 + 8_192 * 32 == 5_396_672


def standalone(s):
    return BLOCK[s] + 2 * ENDPOINT[s]


def run(s, l):
    return l * BLOCK[s] + (l - 1) * BOUNDARY[s] + 2 * ENDPOINT[s]


rows = [
    ("toy proof (three generators)", standalone("toy"), -77.68),
    ("125M standalone proof", standalone("125M"), -72.86),
    ("125M run, L = 12", run("125M", 12), -69.29),
    ("rung-G standalone proof", standalone("rung-G"), None),
    ("rung-G run, L = 2", run("rung-G", 2), None),
]
assert standalone("toy") == 327_052 and standalone("125M") == 9_212_588 and run("125M", 12) == 109_728_784
print("2./3. N and the residual N x delta (sub-additivity of TV over independent coordinates, then data processing):")
for label, n, quoted in rows:
    lg = log2q(n * delta)
    lg96 = math.log2(n) - 96
    print(f"   {label:32s} N = {n:>12,}   log2(N delta) = {lg:.6f}   log2(N 2^-96) = {lg96:.6f}" + (f"   quoted 2^{quoted}" if quoted else ""))
    if quoted is not None:
        assert round(lg, 2) == quoted, f"{label}: {lg:.4f} does not round to the quoted {quoted}"
assert run("rung-G", 2) == 1_397_608

# 4. many proofs: valid only under the cross-proof independence named in the check (finding N-1)
print("4. over K proofs (a hybrid over proofs; ONLY under cross-proof independence of the generators):")
for label, n in [("toy proof", standalone("toy")), ("125M standalone proof", standalone("125M")), ("125M run L = 12", run("125M", 12))]:
    for kk in (10**6, 2**30):
        print(f"   {label:24s} K = {kk:>13,}: 2^{log2q(kk * n * delta):.2f}")
assert round(log2q(10**6 * standalone("toy") * delta), 2) == -57.75
assert round(log2q(10**6 * standalone("125M") * delta), 2) == -52.93

# 5. what one repeated key (E-1 failing ACROSS proofs) costs, for contrast: it is not a small
# additive term. Two proofs on one key share every blinding word; the difference of two
# published masked values is the difference of the hidden data -- distinguishing advantage 1.
print("5. a repeated key across two proofs: the two blindings are EQUAL, advantage up to 1 (not a D9-type term)")
print()
print("ALL ASSERTIONS PASSED")
