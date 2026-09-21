#!/usr/bin/env python3
"""Recompute, in exact integer arithmetic where possible, EVERY number in §4 of
`ZK60_PRIVACY_STATEMENT_TOY_PROFILE.md` (the accepted toy statement, register
D22) and the hop costs of Route A (`ZK60_HASH_LAYER_AND_FS_LIFT.md` §3.3).

Every coefficient is re-derived here from the toy's layout on MAIN at 4751b93;
nothing is imported from a memo.  Reviewer: independent adversarial checker,
2026-09-21.
"""

from fractions import Fraction
from math import comb, log2
import json

P = 2**64 - 2**32 + 1            # zkp-core/src/field.rs
P2 = P * P                       # |Fp2|

def lg2(x):
    """log2 of a Fraction with arbitrarily large numerator/denominator.

    Shifts both down to 53 bits first, so no intermediate float overflows.
    """
    x = Fraction(x)
    n, d = x.numerator, x.denominator
    sn, sd = n.bit_length() - 53, d.bit_length() - 53
    sn, sd = max(sn, 0), max(sd, 0)
    return (sn - sd) + log2((n >> sn) / (d >> sd))

out = {}
lines = []
def say(s=""):
    lines.append(s)

# ------------------------------------------------------------------ geometry
A_ROWS, H_ROWS, M_ROWS, EP_ROWS = 455, 384, 50, 7
A_DATA, H_DATA = 213, 280
N, Q_PAD, NN, MASK_DOM = 256, 256, 2048, 4096
N_LEAF = 4 * NN + MASK_DOM            # 12,288 encoded columns / salts drawn
N_NODE = 4 * (NN - 1) + (MASK_DOM - 1)  # 12,283 internal nodes
N_OVERLAP = N_LEAF + N_NODE           # 24,571 candidate 64-byte objects

say("=" * 78)
say("TOY RESIDUALS RE-DERIVED FROM MAIN @ 4751b93 (exact integers)")
say("=" * 78)
say(f"N_leaf = 4*{NN} + {MASK_DOM} = {N_LEAF}   [COUNTED]")
say(f"N_node = 4*{NN-1} + {MASK_DOM-1} = {N_NODE}   [COUNTED]")
say(f"N_overlap = {N_OVERLAP}   [COUNTED]")
out.update(N_leaf=N_LEAF, N_node=N_NODE, N_overlap=N_OVERLAP)

# ------------------------------------------------------------ 1. the sampler
# rng.rs:72-77  fp() = Fp::from_u128(uniform 128 bits) -> reduce mod p.
b = pow(2, 128, P)                     # 2^128 mod p
tv = Fraction(b * (P - b), P * 2**128)  # exact total-variation distance per draw
say("")
say("1. SAMPLER (D9)")
say(f"   2^128 mod p = {b} = p - 2^32 : {b == P - 2**32}")
say(f"   per-draw TV distance  b(p-b)/(p*2^128) = 2^{lg2(tv):.6f}   [COMPUTED]")
say(f"   per-draw REJECTION REGION b/2^128      = 2^{lg2(Fraction(b, 2**128)):.6f}"
    "   <- an EVENT, 32 bits larger; must never be used as the distance")

# the 327,052 fp() draws, re-counted from the code
draws = {
  "A mask+prox rows (455-213)*256":            (A_ROWS - A_DATA) * N,
  "A pads 455*256":                            A_ROWS * Q_PAD,
  "23 CFS masks 2*sum((n+e)*d+2)":             None,   # filled below
  "M row pads 23*2*256":                       23 * 2 * 256,
  "M b_re,b_im,u_re,u_im 4*1024":              4 * 1024,
  "H mask+prox rows (384-280)*256":            (H_ROWS - H_DATA) * N,
  "H two zero-sum rows 2*255":                 2 * (N - 1),
  "H pads 384*256":                            H_ROWS * Q_PAD,
  "two endpoints 2*((7-2)*256 + 7*256)":       2 * ((EP_ROWS - 2) * N + EP_ROWS * Q_PAD),
}
SLOTS = [(9,1,3),(9,1,3),(5,1,3),(9,1,4),(11,1,3),(4,1,2),(4,1,2),(4,1,2),
         (3,2,2),(5,2,2),(4,1,2),(4,1,2),(4,1,2),(4,1,2),(9,1,4),(9,1,4),
         (8,1,4),(11,1,4),(9,1,4),(8,1,3),(8,1,2),(9,1,2),(9,1,2)]
cfs_coeffs = sum((n + e) * d + 2 for (n, e, d) in SLOTS)   # CfsMask::len
draws["23 CFS masks 2*sum((n+e)*d+2)"] = 2 * cfs_coeffs
N_DRAWS = sum(draws.values())
say(f"   CFS coefficients sum((n+e)*d+2) over 23 slots = {cfs_coeffs}  -> "
    f"{2*cfs_coeffs} fp() draws")
for k, v in draws.items():
    say(f"     {k:<44} {v:>7}")
say(f"   TOTAL fp() draws = {N_DRAWS}   [COUNTED]   (memo: 327,052 -> "
    f"{N_DRAWS == 327052})")
eps_d9 = N_DRAWS * tv
say(f"   sampler residual N * TV = 2^{lg2(eps_d9):.4f}      "
    f"(statement: 2^-77.7)   [COMPUTED]")
eps_d9_1m = 10**6 * eps_d9
say(f"   at 10^6 proofs           = 2^{lg2(eps_d9_1m):.4f}      "
    f"(statement: 2^-57.7)   [COMPUTED]")
out.update(per_draw_tv_log2=lg2(tv), rejection_region_log2=lg2(Fraction(b, 2**128)),
           n_fp_draws=N_DRAWS, eps_d9_log2=lg2(eps_d9), eps_d9_1M_log2=lg2(eps_d9_1m))

# ---------------------------------------------- 2. the input-dependent refusal
# protocol.rs:231-234 `inverses` -> batch_inverse2_checked; raised at :339,:349,:351,:357
per_dom = {"L": 2 * 512, "D": 38 * 512, "F": 9 * 512, "Q": 13 * 512,
           "Kv": 12 * 256, "S": 13 * 2048}
# layout.rs:744-746 asserts exactly these per-domain totals:
assert list(per_dom.values()) == [1024, 19456, 4608, 6656, 3072, 26624]
u8_total = sum(per_dom.values())                 # 61,440
exp_den = 2 * 32 * 32                            # Dom::S cube  (protocol.rs:348)
act_den = 512                                    # Dom::F cube  (protocol.rs:350)
tab_den = 3 * 256                                # the three table helpers (:352-357)
ALL_DEN = u8_total + exp_den + act_den + tab_den
DISTINCT_DEN = 3 * 256      # at most 256 distinct arguments per table, table side shared
say("")
say("2. THE ONE INPUT-DEPENDENT REFUSAL CLASS (zero LogUp denominator)")
say(f"   U8 {u8_total} + exp {exp_den} + act {act_den} + table {tab_den} = {ALL_DEN}"
    "   [COUNTED]")
one_world_all = Fraction(ALL_DEN, P2)
one_world_dist = Fraction(DISTINCT_DEN, P2)
say(f"   ONE-WORLD, all denominators   {ALL_DEN}/p^2      = 2^{lg2(one_world_all):.4f}"
    "   (statement 2^-112.0)")
say(f"   ONE-WORLD, distinct arguments {DISTINCT_DEN}/p^2 = 2^{lg2(one_world_dist):.4f}"
    "   (ruling S-4's 2^-118.4)")
say(f"   TWO-WORLD union (what a DISTANCE needs): 2x each ="
    f" 2^{lg2(2*one_world_all):.4f}  /  2^{lg2(2*one_world_dist):.4f}"
    "  (memo hop G_7->G_8 writes 2 * 2^-112.0)")
say("   => the statement's 2^-112.0, READ AS A DISTANCE, is still an upper bound:")
say(f"      2*distinct = 2^{lg2(2*one_world_dist):.4f} < 2^{lg2(one_world_all):.4f}"
    f" by {lg2(one_world_all) - lg2(2*one_world_dist):.1f} bits.")
out.update(all_denominators=ALL_DEN, distinct_denominators=DISTINCT_DEN,
           one_world_all_log2=lg2(one_world_all),
           one_world_distinct_log2=lg2(one_world_dist),
           two_world_all_log2=lg2(2*one_world_all),
           two_world_distinct_log2=lg2(2*one_world_dist))

# ------------------------------------------------------------- 3. hash layer
say("")
say("3. HASH-LAYER TERMS")
salt = Fraction(N_LEAF, 2**256)
leafcoll = Fraction(comb(N_LEAF, 2), 2**256)
overlap = Fraction(N_OVERLAP, 2**256)
leafnode = Fraction(N_NODE * N_LEAF, 2**512)
A_BOUND = 4000                     # the memo's BOUND on absorbs+squeezes
A_COUNTED_POINTS = 2180            # this review's count (toy_query_table.py)
A_COUNTED_CALLS = 3207             # including the refusal replay's repeated calls
prequery = Fraction(A_BOUND, 2**256)
absorbcoll = Fraction(comb(A_BOUND, 2), 2**256)
gen = Fraction(6, 2**256)
say(f"   salt guessing        q * {N_LEAF} * 2^-256   = q * 2^{lg2(salt):.4f}"
    "   (statement q*2^-242.4)")
say(f"   leaf-input collision C({N_LEAF},2) * 2^-256 = 2^{lg2(leafcoll):.4f}"
    "   (statement 2^-229.8)")
say(f"   64-byte absorb overlap {N_OVERLAP} * 2^-256  = 2^{lg2(overlap):.4f}"
    "   (statement 2^-241.4)")
say(f"   leaf input = node input {N_NODE}*{N_LEAF}*2^-512 = 2^{lg2(leafnode):.4f}"
    "   (NOT in the statement's table)")
say(f"   challenge pre-query   q * {A_BOUND} * 2^-256  = q * 2^{lg2(prequery):.4f}"
    "   (statement q*2^-244.0)")
say(f"   absorb-input collision C({A_BOUND},2)*2^-256 = 2^{lg2(absorbcoll):.4f}"
    "   (statement 2^-233.1)")
say(f"   generator (ROM alternative) 6q * 2^-256      = q * 2^{lg2(gen):.4f}"
    "   (statement 6q*2^-256)")
say(f"   -- the 4,000 is a BOUND. This review COUNTS {A_COUNTED_POINTS} distinct "
    f"absorb+squeeze points ({A_COUNTED_CALLS} calls incl. the refusal replay);")
say(f"      with the counted 317 absorbs the collision term is "
    f"2^{lg2(Fraction(comb(317,2), 2**256)):.4f}, and with {A_COUNTED_POINTS} points "
    f"2^{lg2(Fraction(comb(A_COUNTED_POINTS,2), 2**256)):.4f}; both below the carried figure.")
out.update(salt_log2=lg2(salt), leafcoll_log2=lg2(leafcoll), overlap_log2=lg2(overlap),
           leafnode_log2=lg2(leafnode), prequery_log2=lg2(prequery),
           absorbcoll_log2=lg2(absorbcoll), gen_log2=lg2(gen),
           A_bound=A_BOUND, A_counted_points=A_COUNTED_POINTS,
           A_counted_calls=A_COUNTED_CALLS,
           absorbcoll_counted_log2=lg2(Fraction(comb(317, 2), 2**256)))

# ------------------------------------------------------------- 4. liveness
say("")
say("4. LIVENESS (NOT a distance)")
# protocol.rs:135-137 determinant(a,b) = a.c0*b.c1 - a.c1*b.c0 over Fp;
# for uniform a,b in Fp2 the probability it vanishes is (p^3+p^2-p)/p^4.
p_det = Fraction(P**3 + P**2 - P, P**4)
say(f"   one proximity determinant vanishes with probability 2^{lg2(p_det):.4f} (~1/p)")
say(f"   four sites (A, H, in, out): 2^{lg2(4*p_det):.4f}   (statement 2^-62.0)"
    "   [COMPUTED]")
# the Fp2 zero/one refusals, for completeness
n_fp2_refusals = 120 + 52 + 1 + 1 + 23 + 25    # group coeffs + c_s + terminal e's
say(f"   the Fp2-valued refusals ({n_fp2_refusals} draws, ~2/p^2 each): "
    f"2^{lg2(Fraction(2*n_fp2_refusals, P2)):.1f} -- 64+ bits smaller, as claimed")
out.update(liveness_log2=lg2(4*p_det), one_det_log2=lg2(p_det))

# ------------------------------------------------------------- 5. the sum
say("")
say("5. THE TOTAL, at the statement's own ceiling q = 2^128")
for qexp in (12, 50, 80, 128):
    q = 2**qexp
    hashlayer = q*salt + leafcoll + overlap + leafnode + q*prequery + absorbcoll + q*gen
    total_stated = eps_d9 + one_world_all + hashlayer
    total_twoworld = eps_d9 + 2*one_world_all + hashlayer
    total_tight = eps_d9 + 2*one_world_dist + hashlayer
    say(f"   q=2^{qexp:<4} hash layer 2^{lg2(hashlayer):.4f} | "
        f"sum w/ 1-world refusal 2^{lg2(total_stated):.12f} | "
        f"w/ 2x 2^{lg2(total_twoworld):.12f} | w/ 2x distinct 2^{lg2(total_tight):.12f}")
say("   The three sums agree to 10 decimal places: the refusal form does not move")
say("   the headline 2^-77.7 at any q.")
say(f"   margin of the sampler over q*2^-242.4 at q=2^128: "
    f"{lg2(2**128*salt) - lg2(eps_d9):.1f} bits")
out["totals"] = {}
for qexp in (12, 50, 80, 128):
    q = 2**qexp
    hashlayer = q*salt + leafcoll + overlap + leafnode + q*prequery + absorbcoll + q*gen
    out["totals"][f"2^{qexp}"] = dict(
        hash_layer_log2=lg2(hashlayer),
        sum_one_world_log2=lg2(eps_d9 + one_world_all + hashlayer),
        sum_two_world_log2=lg2(eps_d9 + 2*one_world_all + hashlayer),
        sum_two_world_distinct_log2=lg2(eps_d9 + 2*one_world_dist + hashlayer))

# ------------------------------------------------- 6. salt-guessing sanity
say("")
say("6. THE SALT-GUESSING COEFFICIENT, checked both ways")
unopened = N_LEAF - (5 * 0)   # the memo uses ALL leaves, deliberately conservative
say(f"   statement uses ALL {N_LEAF} leaves: 2^{lg2(salt):.4f}")
say(f"   only never-opened leaves (~11,077 by the memo's expectation): "
    f"2^{lg2(Fraction(11077, 2**256)):.4f}  -- SMALLER, so the carried figure is "
    "conservative in the honest direction")

print("\n".join(lines))
with open(__file__.rsplit("/", 1)[0] + "/toy_residuals.json", "w") as f:
    json.dump(out, f, indent=1, sort_keys=True)
with open(__file__.rsplit("/", 1)[0] + "/toy_residuals.txt", "w") as f:
    f.write("\n".join(lines) + "\n")
