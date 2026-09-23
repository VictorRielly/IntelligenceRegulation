#!/usr/bin/env python3
"""G-R4, the LAW of the blinding: the sampler residual in exact arithmetic,
the draw counts re-derived from the segment formulas and compared with the
lane's MEASURED parts, and four exact small models of what is and is not
load-bearing for the law.

Evidence for docs/zkmatrix-poc/ZK60_BLINDING_LAW_GR4.md (sections 4 and 2).

Sources transcribed (nothing is imported from another script):

  zkp-core/src/field.rs:10      P = 0xFFFF_FFFF_0000_0001
  zkp-core/src/field.rs:36-38   Fp::from_u128(v) = v % P   (REDUCTION)
  zkp-core/src/rng.rs:73-77     fp() = from_u128((hi << 64) | lo), two
                                next_u64 = one uniform 128-bit integer
  (identical in the main tree at 980edc7 and on the lane at 2ea7221 --
   the production part of rng.rs, lines 1-100, diffs empty)

  Segment formulas: ZK60_JOINT_SENTENCE_AND_QUERY_CLASSES.md A-4 (read at
  8c5922b), re-read here at lane 2ea7221:
    protocol.rs:1002-1004  A mask + proximity rows   (a_rows - a_data) * n
    zkp-core pcs.rs:777    pads                      rows * Q
    zkp-core pcs.rs:778    salts (bytes32, EXACTLY uniform, no D9 term)  nn
    zk.rs:485              CFS coefficients          2 * sum_Ls  (fp2 = 2 fp)
    zk.rs:496              M per-row pads            46 * 256
    zk.rs:503-508          b_re, b_im, u_re, u_im    4 * 1024
    zk.rs:513              M salts                   4096
    protocol.rs:1115-1117  H mask + proximity rows   (h_rows - h_data) * n
    protocol.rs:1118-1126  H zero-sum rows           2 * (n - 1)
    endpoint_g.rs:276-280  endpoint: 5 mask rows * ne + e_rows * Q; salts nne
    boundary.rs:346-350    boundary: 6 mask rows * ne + (e_rows+1) * Q; nne
  Shape constants: stream_positions.py (results/zk60_joint_sentence_query_
  classes/, transcribed there from shape.rs / layout.rs at 8c5922b); they
  are re-validated HERE against the lane's stage-46 MEASURED parts (ledger
  ZK60_BLOCK125M_LANE_PROGRESS.md, "Stage 46 -- CLOSED", at 2ea7221).

Run:  python3 law_and_residual.py      (exits 0 and prints ALL ASSERTIONS PASSED)
"""

from fractions import Fraction as Fr
import itertools
import math

# ---------------------------------------------------------------------------
# 1. the per-draw distance, exactly
# ---------------------------------------------------------------------------

P = 0xFFFF_FFFF_0000_0001
N128 = 1 << 128
k = N128 // P
r = N128 - k * P
assert P == (1 << 64) - (1 << 32) + 1
assert r == P - (1 << 32), "2^128 mod p is not p - 2^32"

# law of (U mod p), U uniform on [0, 2^128): r residues get k+1 preimages,
# p - r residues get k.
tv_direct = (Fr(r) * (Fr(k + 1, N128) - Fr(1, P)) + Fr(P - r) * (Fr(1, P) - Fr(k, N128))) / 2
delta = Fr(r * (P - r), P * N128)
assert tv_direct == delta, "the closed form r(p-r)/(p 2^128) is not the total-variation distance"
assert delta < Fr(1, 1 << 96), "one draw is not within 2^-96"


def log2_fr(x: Fr) -> float:
    """log2 of a positive rational, exact enough for 10 decimals (big ints)."""
    return math.log2(x.numerator) - math.log2(x.denominator)


print("1. ONE fp() DRAW")
print(f"   p = {P}")
print(f"   2^128 mod p = r = {r} = p - 2^32")
print(f"   TV(one draw, uniform on Fp) = r(p-r)/(p 2^128) = 2^{log2_fr(delta):.10f}   (< 2^-96)")
print(f"   rejection-region mass r/2^128 = 2^{log2_fr(Fr(r, N128)):.10f}   (the 2^-64 of the rng.rs:72 comment; NOT a distance)")
print(f"   bytes32() salts: 4 x next_u64, no reduction -> exactly uniform in the ideal stream; they carry NO D9 term")

# ---------------------------------------------------------------------------
# 2. the draw counts: segment formulas vs the lane's MEASURED parts
# ---------------------------------------------------------------------------

Q = 256
MASK_Q, MASK_M, MASK_DOM, N_SLOTS = 256, 512, 4096, 23

SHAPES = {
    "toy":     dict(log_cols=8,  inv_rate=8, a_rows=455,  a_data=213,  h_rows=384,  h_data=280,  sum_Ls=583,  e_log=8,  e_rate=8, e_rows=7),
    "rung-G":  dict(log_cols=10, inv_rate=4, a_rows=623,  a_data=377,  h_rows=576,  h_data=470,  sum_Ls=859,  e_log=10, e_rate=4, e_rows=9),
    "rung-K4": dict(log_cols=10, inv_rate=4, a_rows=727,  a_data=481,  h_rows=720,  h_data=614,  sum_Ls=871,  e_log=10, e_rate=4, e_rows=9),
    "125M":    dict(log_cols=14, inv_rate=4, a_rows=5681, a_data=5435, h_rows=7120, h_data=7018, sum_Ls=1239, e_log=14, e_rate=4, e_rows=37),
}

# MEASURED by the lane (stage 36 for the toy and rung-K4 block streams,
# stage 46 for rung-G and 125M; endpoints on the REPLICA, S36-F2, and at
# stage 46 also READ in situ off the real owners; the 125M boundary measured
# on the production boundary::prepare outside a run).
MEASURED = {
    #            block fp, block salts, endpoint fp (each), endpoint salts (each), boundary fp, boundary salts
    "toy":     (320_908,   8_192,       3_072,              2_048,                 None,        None),
    "rung-G":  (687_028,   12_288,      7_424,              4_096,                 8_704,       4_096),
    "rung-K4": (750_540,   12_288,      7_424,              4_096,                 None,        None),
    "125M":    (9_029_804, 135_168,     91_392,             65_536,                108_032,     65_536),
}


def block_counts(s):
    n = 1 << s["log_cols"]
    nn = n * s["inv_rate"]
    segs = [
        ("A mask + proximity rows", "fp", (s["a_rows"] - s["a_data"]) * n),
        ("A pads", "fp", s["a_rows"] * Q),
        ("A salts", "salt", nn),
        ("M CFS coefficients", "fp", 2 * s["sum_Ls"]),
        ("M per-row pads", "fp", 2 * N_SLOTS * MASK_Q),
        ("M b_re, b_im, u_re, u_im", "fp", 4 * 2 * MASK_M),
        ("M salts", "salt", MASK_DOM),
        ("H mask + proximity rows", "fp", (s["h_rows"] - s["h_data"]) * n),
        ("H zero-sum rows", "fp", 2 * (n - 1)),
        ("H pads", "fp", s["h_rows"] * Q),
        ("H salts", "salt", nn),
    ]
    fp = sum(c for _, kd, c in segs if kd == "fp")
    salts = sum(c for _, kd, c in segs if kd == "salt")
    return segs, fp, salts


def endpoint_counts(s):
    ne = 1 << s["e_log"]
    return 5 * ne + s["e_rows"] * Q, ne * s["e_rate"]


def boundary_counts(s):
    ne = 1 << s["e_log"]
    return 6 * ne + (s["e_rows"] + 1) * Q, ne * s["e_rate"]


print()
print("2. DRAW COUNTS: segment formulas (COUNTED) against the lane's MEASURED parts")
for name, s in SHAPES.items():
    segs, fp, salts = block_counts(s)
    efp, esalt = endpoint_counts(s)
    m = MEASURED[name]
    assert (fp, salts) == (m[0], m[1]), f"{name}: block {fp}/{salts} != measured {m[0]}/{m[1]}"
    assert (efp, esalt) == (m[2], m[3]), f"{name}: endpoint {efp}/{esalt} != measured {m[2]}/{m[3]}"
    line = f"   {name:8s} block {fp:>10,} fp / {salts:>8,} salts   endpoint {efp:>7,} / {esalt:>6,} each"
    if m[4] is not None:
        bfp, bsalt = boundary_counts(s)
        assert (bfp, bsalt) == (m[4], m[5]), f"{name}: boundary {bfp}/{bsalt} != measured {m[4]}/{m[5]}"
        line += f"   boundary {bfp:>7,} / {bsalt:>6,}"
    print(line + "   = MEASURED")
# the discarded draws: b_re[m], b_im[m] are drawn and overwritten (zk.rs:505-506)
print("   (the two overwritten b entries per M are INCLUDED: they are drawn, and a discarded draw costs its 2^-96 too)")

# ---------------------------------------------------------------------------
# 3. the residual N * delta per object of record
# ---------------------------------------------------------------------------


def per_proof(name):
    _, fp, _ = block_counts(SHAPES[name])
    efp, _ = endpoint_counts(SHAPES[name])
    return fp + 2 * efp


def per_run(name, L):
    _, fp, _ = block_counts(SHAPES[name])
    efp, _ = endpoint_counts(SHAPES[name])
    bfp, _ = boundary_counts(SHAPES[name])
    return L * fp + (L - 1) * bfp + 2 * efp


OBJECTS = [
    ("toy proof (three generators)", per_proof("toy"), 327_052, "D9 / D22 figure; stage 36 MEASURED"),
    ("rung-G standalone proof", per_proof("rung-G"), 701_876, "stage 46 MEASURED (endpoints: replica + in-situ objects)"),
    ("rung-K4 standalone proof", per_proof("rung-K4"), 765_388, "stage 36 block + replica endpoints"),
    ("125M standalone proof", per_proof("125M"), 9_212_588, "stage 46 MEASURED (endpoints: replica + in-situ objects)"),
    ("rung-G run L=2", per_run("rung-G", 2), 1_397_608, "stage 46 MEASURED in situ on the run stream (1,382,760) + endpoints"),
    ("rung-G run L=3", per_run("rung-G", 3), 2_093_340, "H-6; stage 46 sum of measured parts"),
    ("125M run L=12", per_run("125M", 12), 109_728_784, "H-6; stage 46 sum of measured parts (not a measured run)"),
]
print()
print("3. THE SAMPLER RESIDUAL  N x TV(one draw)   [exact rational; log2 printed]")
print(f"   {'object':32s} {'N (fp draws)':>14s}   {'log2(N*delta)':>14s}   {'log2(N*2^-96)':>14s}   provenance")
fig = {}
for label, n_counted, n_record, prov in OBJECTS:
    assert n_counted == n_record, f"{label}: counted {n_counted} != figure of record {n_record}"
    e_exact = log2_fr(n_counted * delta)
    e_bound = math.log2(n_counted) - 96
    fig[label] = e_exact
    print(f"   {label:32s} {n_counted:>14,}   {e_exact:>14.6f}   {e_bound:>14.6f}   {prov}")

# the brief's figures, to the precision they are quoted at
assert round(fig["toy proof (three generators)"], 2) == -77.68      # "2^-77.7"
assert round(fig["125M standalone proof"], 2) == -72.86              # "2^-72.86"
assert round(fig["125M run L=12"], 2) == -69.29                      # "2^-69.3"
assert round(fig["rung-G standalone proof"], 2) == -76.58
# the pre-repair run count some pages still quote
pre = 109_728_040
assert per_run("125M", 12) - pre == 12 * 62
print(f"   {'125M run L=12, PRE-repair count':32s} {pre:>14,}   {log2_fr(pre * delta):>14.6f}   (744 = 12 x 62 below H-6; the residual does not move at 2 decimals)")
assert round(log2_fr(pre * delta), 2) == -69.29

print()
print("   Over many proofs (a hybrid over proofs; VALID ONLY IF the proofs' blinding is independent across proofs):")
for label in ["toy proof (three generators)", "125M standalone proof"]:
    n = dict((o[0], o[1]) for o in OBJECTS)[label]
    print(f"   {label:32s} x 10^6 proofs: 2^{log2_fr(10**6 * n * delta):.2f}")

# ---------------------------------------------------------------------------
# 4. four exact small models: what is load-bearing for the LAW
# ---------------------------------------------------------------------------
#
# Field F_5, an ideal stream of four uniform symbols s = (s0, s1, s2, s3)
# (i.e. the world AFTER the generator hop and the sampler hop).  Two roles,
# A and H, each with one blinding coordinate that masks one data value:
#   published view  V = (dA + bA, dH + bH)
# Two worlds: data (dA, dH) = (0, 0) and (1, 0).  A challenge rho in F_5 is
# drawn independently (the fixed-challenge experiment).  "accept" is the
# event the prover does not refuse.  We compare law(V | world, accept).

F = 5
STREAMS = list(itertools.product(range(F), repeat=4))
WORLDS = {"w0": (0, 0), "w1": (1, 0)}


def law(assign, refuse, world):
    """exact law of V given world and acceptance, over s uniform and rho uniform"""
    dA, dH = WORLDS[world]
    counts = {}
    total = 0
    for s in STREAMS:
        for rho in range(F):
            bA, bH = assign(s, world)
            if refuse(s, rho, world):
                continue
            v = ((dA + bA) % F, (dH + bH) % F)
            counts[v] = counts.get(v, 0) + 1
            total += 1
    return {v: Fr(c, total) for v, c in counts.items()}


honest = lambda s, w: (s[0], s[2])                                   # disjoint positions, fixed order
order_by_data = lambda s, w: (s[0], s[2]) if w == "w0" else (s[3], s[1])  # ORDER depends on the hidden world, still injective
reuse = lambda s, w: (s[0], s[0])                                    # one drawn value used by two roles
no_refusal = lambda s, rho, w: False
refuse_on_public = lambda s, rho, w: rho == 0                       # a challenge-only refusal
refuse_on_data_and_rho = lambda s, rho, w: rho == WORLDS[w][0]       # depends on (w, rho), never on s
refuse_on_blinding = lambda s, rho, w: s[0] == 0                     # a refusal that READS the blinding

cases = [
    ("honest discipline, no refusal", honest, no_refusal, True),
    ("honest, challenge-only refusal", honest, refuse_on_public, True),
    ("honest, refusal on (w, rho) -- LogUp-like", honest, refuse_on_data_and_rho, True),
    ("ORDER chosen by the hidden data (injective)", order_by_data, no_refusal, True),
    ("CONTROL: one value reused by two roles", reuse, no_refusal, False),
    ("CONTROL: a refusal that reads the blinding", honest, refuse_on_blinding, False),
]
print()
print("4. EXACT SMALL MODELS over F_5 (ILLUSTRATION): is law(V | world, accept) the same in both worlds?")
for label, assign, refuse, expect_equal in cases:
    l0, l1 = law(assign, refuse, "w0"), law(assign, refuse, "w1")
    equal = l0 == l1
    uniform = all(x == Fr(1, F * F) for x in l0.values()) and len(l0) == F * F
    assert equal == expect_equal, f"model '{label}': expected equal={expect_equal}, got {equal}"
    tv = sum(abs(l0.get(v, 0) - l1.get(v, 0)) for v in set(l0) | set(l1)) / 2
    print(f"   {label:46s} equal={str(equal):5s}  uniform(w0)={str(uniform):5s}  TV={tv}")
print("   Reading: a refusal measurable in (w, rho) and a data-chosen but injective ORDER leave the law exact;")
print("   REUSE of a drawn value and a refusal that READS a drawn value break it.  The load-bearing code")
print("   facts are therefore injectivity of use and 'no control flow reads a drawn value'; a public ORDER is")
print("   sufficient, checkable by counting, and fixes N -- but it is not what makes the law exact.")

print()
print("ALL ASSERTIONS PASSED")
