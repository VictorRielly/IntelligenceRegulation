#!/usr/bin/env python3
"""U-3a evidence 4: the numbers.

Three separate quantities, deliberately kept apart because they mean
different things:

  (A) Pr[the good event fails on a NON-REFUSED run]
      -- zero under the lemma of section 3 (the refusal set contains the
         bad set).  Printed as a reminder, not computed.

  (B) Pr[the prover refuses]
      -- the liveness cost of the lemma, not a privacy residual, because
         the refusal predicate is a function of the transcript challenges
         alone (RELIES ON: the random-oracle model, under which the
         challenge law is the same for every witness).

  (C) The Schwartz-Zippel BACKSTOP, i.e. what the bound would be if a
      checker rejected the structural argument of section 3 and only the
      "one capture shows the minor is not identically zero" route stood.
      This is where this draft disagrees with the sketch in
      ZK60_PRIVACY_CASE_FIRST_MVP_CHECK.md section 4: the tool's rank is
      an Fp rank of the REALIFICATION (2 generators per group vector,
      scripts/zk60_native_jv_pcs.py::_p1_rows), the minor is therefore
      2(G+1) x 2(G+1) and its entries are polynomials in the Fp
      COORDINATES of the challenges, so Schwartz-Zippel runs over Fp
      (2^64), not over Fp2 (2^128).

Exact integer arithmetic; log2 by Fraction so nothing is rounded twice.
"""

from fractions import Fraction
import math

P = (1 << 64) - (1 << 32) + 1
P2 = P * P


def bits(x):
    if x == 0:
        return float("-inf")
    return math.log2(x.numerator) - math.log2(x.denominator) if isinstance(x, Fraction) \
        else math.log2(x)


# ------------------------------------------------------------ the profiles
PROFILES = {
    "private-block-t32-poc": dict(
        slots=23,
        ext_draws=25,                      # sum of the slots' extension rounds
        claims=dict(A=120, H=52, Input=1, Output=1),
        groups=dict(A=35, H=9, Input=1, Output=1),
        rows=dict(A=455, H=384, Input=7, Output=7),
        mask_specs=[(10, 3), (10, 3), (6, 3), (10, 4), (12, 3), (5, 2), (5, 2), (5, 2),
                    (5, 2), (7, 2), (5, 2), (5, 2), (5, 2), (5, 2), (10, 4), (10, 4),
                    (9, 4), (12, 4), (10, 4), (9, 3), (9, 2), (10, 2), (10, 2)],
    ),
    "private-attention-t32-poc": dict(
        slots=18,
        ext_draws=20,
        claims=dict(A=75, H=36, Input=1, Output=1),
        groups=dict(A=30, H=8, Input=1, Output=1),
        rows=dict(A=306, H=290, Input=7, Output=7),
        mask_specs=[(10, 3), (6, 3), (10, 3), (12, 3), (5, 2), (5, 2), (5, 2), (5, 2),
                    (7, 2), (5, 2), (10, 4), (10, 4), (9, 4), (12, 4), (9, 3), (9, 2),
                    (10, 2), (10, 2)],
    ),
}

# Pr[wedge(a, b) == 0] for a, b independent uniform in Fp2:
#   a == 0            -> p^2 choices of b
#   a != 0            -> b in Fp*a, p choices
PROX_DEP = Fraction(P2 + (P2 - 1) * P, P2 * P2)

print("Pr[a proximity pair is Fp-dependent], a, b uniform in Fp2")
print(f"  exact = ({P2} + ({P2}-1)*{P}) / {P2*P2}")
print(f"        = 2^{bits(PROX_DEP):.4f}      (1/p would be 2^{bits(Fraction(1, P)):.4f})")
print()

for name, pr in PROFILES.items():
    n_claims = sum(pr["claims"].values())
    n_open = len(pr["claims"])
    print(f"=== {name} ===")
    print(f"  slots {pr['slots']}, extension-round draws {pr['ext_draws']}, "
          f"claims (= lambda draws) {n_claims}, openings {n_open}")

    # ---------------------------------------------------- (B) refusal terms
    t_e = Fraction(2 * pr["ext_draws"], P2)      # e == 0 or e == 1
    t_l = Fraction(n_claims, P2)                 # a batching lambda == 0
    t_c = Fraction(pr["slots"], P2)              # a CFS mask challenge == 0
    t_p = PROX_DEP * n_open                      # a proximity pair dependent
    tot = t_e + t_l + t_c + t_p
    print("  (B) refusal probability, term by term (ideal uniform draws)")
    print(f"      terminal-mask challenge e in {{0,1}} : {2*pr['ext_draws']:5d} draws  "
          f"2^{bits(t_e):8.3f}")
    print(f"      a PCS batching lambda = 0          : {n_claims:5d} draws  "
          f"2^{bits(t_l):8.3f}")
    print(f"      a CFS mask challenge c = 0         : {pr['slots']:5d} draws  "
          f"2^{bits(t_c):8.3f}")
    print(f"      a proximity pair Fp-dependent      : {n_open:5d} pairs  "
          f"2^{bits(t_p):8.3f}   <-- dominant")
    print(f"      TOTAL refusal probability                        "
          f"2^{bits(tot):8.3f}")
    print("      (liveness, not privacy: about one proof in "
          f"{int(1/float(tot)):,} is discarded and re-run)")

    # the sampler's own residual, on the draws this lemma uses
    n_draw = n_claims + sum(pr["rows"].values()) + pr["ext_draws"] + pr["slots"]
    samp = Fraction(n_draw, 1 << 96)
    print(f"  (B') the challenge sampler's residual on these {n_draw} draws, at the "
          f"case's 2^-96 per draw: 2^{bits(samp):.2f}")

    # -------------------------------------------- (C) Schwartz-Zippel backstop
    print("  (C) Schwartz-Zippel backstop, PCS side (over Fp, realified minor)")
    szc = Fraction(0)
    for role in ["A", "H", "Input", "Output"]:
        G = pr["groups"][role]
        g = 2 * (G + 1)
        # 2G rows of entry degree <= 3 (lambda x cm, cm a product of <= 2
        # linear terminal-mask factors), 2 proximity rows of degree 1
        D = 3 * 2 * G + 1 * 2
        b = Fraction(D, P)
        szc += b
        print(f"      {role:7s} G={G:3d}  minor {g:3d}x{g:<3d} total degree <= {D:4d}   "
              f"2^{bits(b):7.3f}")
    print(f"      union over the four openings                        2^{bits(szc):7.3f}")
    print(f"      with a x100 slack on every degree                   "
          f"2^{bits(szc*100):7.3f}")

    print("  (C') Schwartz-Zippel backstop, mask channel (over Fp2, genuine "
          "Fp2 polynomials)")
    szm = Fraction(0)
    worst = None
    for (n, d) in pr["mask_specs"]:
        D = (n * d + 1) * max(d, n)
        b = Fraction(D, P2)
        szm += b
        if worst is None or D > worst[0]:
            worst = (D, n, d)
    print(f"      {len(pr['mask_specs'])} slots, worst minor degree {worst[0]} "
          f"at (N={worst[1]}, d={worst[2]})")
    print(f"      union over the slots                                2^{bits(szm):7.3f}")

    print(f"  (C'') PCS + mask backstop together                      "
          f"2^{bits(szc+szm):7.3f}")
    print()

print("SENSITIVITY: what if a draw this lemma places in Fp2 is really in Fp?")
print(f"  a lambda or a terminal-mask e in the base field: Norm(x) = x^2, so")
print(f"    Pr[Norm = 0] rises from 1/p^2 = 2^{bits(Fraction(1,P2)):.1f} to "
      f"1/p = 2^{bits(Fraction(1,P)):.1f} per draw.")
for name, pr in PROFILES.items():
    n = sum(pr["claims"].values()) + 2 * pr["ext_draws"]
    print(f"    {name:26s}: {n} such draws -> 2^{bits(Fraction(n, P)):.2f} "
          f"(instead of 2^{bits(Fraction(n, P2)):.2f})")
print("  the proximity pair in the base field: wedge(a, b) = a.c0*b.c1 -")
print("    a.c1*b.c0 = 0 identically when both c1 = 0, so the refusal would")
print("    fire on EVERY run and no proof would ever be produced.  The")
print("    extension-field draw at zkp-core/src/pcs.rs:853 is load-bearing")
print("    for completeness, not only for the bound.")
print("  the Schwartz-Zippel backstop (C) is already taken over Fp, so it does")
print("    not move; if a checker argued the realified minor could be treated")
print("    over Fp2 the backstop would improve by 64 bits, to about")
for name, pr in PROFILES.items():
    szc = sum(Fraction(3 * 2 * pr["groups"][r] + 2, P2)
              for r in ["A", "H", "Input", "Output"])
    print(f"    {name:26s}: 2^{bits(szc):.2f}   (THIS DRAFT DOES NOT CLAIM IT)")
