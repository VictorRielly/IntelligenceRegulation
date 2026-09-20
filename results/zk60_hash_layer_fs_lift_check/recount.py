#!/usr/bin/env python3
"""INDEPENDENT recomputation of every number in ZK60_HASH_LAYER_AND_FS_LIFT.md.

Written from the SOURCE LINES, not from the draft's script.  Exact rational /
integer arithmetic where it matters (Fraction), log2 only for display.

Geometry, each constant re-read by the checker at the line named:

    A    455 rows, n=256, nn=2048, depth 11   layout.rs:590 A_ROWS (test :703)
    H    384 rows, n=256, nn=2048, depth 11   layout.rs:591 H_ROWS (test :704)
    In   7   rows, n=256, nn=2048, depth 11   protocol.rs:187 ENDPOINT_ROWS
    Out  7   rows, n=256, nn=2048, depth 11
    M    50  rows (2*23+4), m=512, nn=4096, depth 12  zk.rs:429 n_base
    256 opened columns per commitment, WITH REPLACEMENT  transcript.rs:119-131
    salt = 32 bytes per ENCODED column                   pcs.rs:673-674
    p = 2^64 - 2^32 + 1

NOTHING here reads a capture, a witness, a salt or a private plane.
"""

from fractions import Fraction
import json
import math
import os

Q_OPEN = 256
BITS = 256
P = (1 << 64) - (1 << 32) + 1

TREES = [("A", 455, 2048), ("H", 384, 2048), ("In", 7, 2048), ("Out", 7, 2048), ("M", 50, 4096)]


def lg(x):
    return math.log2(float(x)) if x > 0 else float("-inf")


def ancestors(nn, level, draws=Q_OPEN):
    blocks = nn // (2 ** level)
    return blocks * (1.0 - (1.0 - 1.0 / blocks) ** draws)


def tree(nn):
    depth = int(math.log2(nn))
    a = [ancestors(nn, j) for j in range(depth + 1)]
    leaf_digests = 2 * a[1]
    internal = sum(2 * a[j + 1] for j in range(1, depth))
    return {
        "depth": depth,
        "distinct_opened": a[0],
        "leaf_digests_revealed": leaf_digests,
        "unopened_leaf_digests_revealed": leaf_digests - a[0],
        "internal_revealed": internal,
        "total_revealed": leaf_digests + internal + 1,
        "nodes_in_tree": 2 * nn - 1,
        "fraction": (leaf_digests + internal + 1) / (2 * nn - 1),
    }


out = {"per_tree": {}, "totals": {}, "lengths": {}, "terms": {}, "checks": {}}

leaves = 0
inodes = 0
for name, rows, nn in TREES:
    t = tree(nn)
    t["rows"] = rows
    t["hash_column_input_bytes"] = 8 * rows
    out["per_tree"][name] = t
    leaves += nn
    inodes += nn - 1

out["totals"] = {
    "encoded_columns": leaves,
    "internal_nodes": inodes,
    "node_plus_leaf_inputs": inodes + leaves,
    "distinct_published_salts": sum(out["per_tree"][n]["distinct_opened"] for n, _, _ in TREES),
    "nodes_revealed": sum(out["per_tree"][n]["total_revealed"] for n, _, _ in TREES),
    "unopened_leaves": leaves - sum(out["per_tree"][n]["distinct_opened"] for n, _, _ in TREES),
    "unopened_leaf_digests_published": sum(out["per_tree"][n]["unopened_leaf_digests_revealed"] for n, _, _ in TREES),
}

# ---------------------------------------------------------------- length classes
# Every blake3 call site on the toy-block path, re-derived by the checker.
# absorb input = state(32) + le64(|label|)(8) + label + le64(|data|)(8) + data
AB = lambda label, data: 48 + len(label) + data
PROFILE = b"hashline-zk-mr1/private-block-t32-poc/1"
SEAM_DOMAIN = b"experimental-private-seam/v1"
RECEIPT_DOMAIN = b"zk60-public-block-receipt-v1"
PARAMS_LIT = (b"T32/d16/f16/H2/KV1/dh8/log_cols8/inv_rate8/Q256/P1/"
              b"sh-g7-u0-h14-z6/two-private-endpoints/one-proof-one-transcript")
CAL_LIT = b"B3 public fixed calibration v1"

out["lengths"] = {
    "squeeze (transcript.rs:86-89) state32+squeeze7+le64": 32 + 7 + 8,
    "merkle hash_pair (merkle.rs:15-18)": 64,
    "salt_leaf (pcs.rs:641-644)": 64,
    "rng refill key||le64(counter) (rng.rs:54-56)": 40,
    "rng keyed key-derivation block (rng.rs:47-49)": 22 + len(PROFILE),
    "rng keyed key-derivation seam (rng.rs:47-49)": 22 + len(SEAM_DOMAIN),
    "rng NEW (fixtures, rng.rs:21-24) block domain": 24 + len(PROFILE),
    "Transcript::new block (transcript.rs:26-28)": 12 + len(PROFILE),
    "Transcript::new SEAM (private_seam.rs:245)": 12 + len(SEAM_DOMAIN),
    "Transcript::new public_block_receipt.rs:178": 12 + len(RECEIPT_DOMAIN),
    "calibration_identity (private_block.rs:95)": len(CAL_LIT),
    "SeamSpec::digest (private_seam.rs:116-131)": 28 + 32 + 8 * 8 + 4,
    "hash_column A": 8 * 455,
    "hash_column H": 8 * 384,
    "hash_column M": 8 * 50,
    "hash_column endpoint": 8 * 7,
    "absorb expected-IO": AB(b"expected-IO", 112),
    "absorb public-statement": AB(b"public-statement", 32),
    "absorb parameters": AB(b"parameters", len(PARAMS_LIT)),
    "absorb calibration": AB(b"calibration", 32),
    "absorb schedule": AB(b"schedule", 32),
    "absorb A/M/H root": AB(b"A", 32),
    "absorb rows": AB(b"rows", 8),
    "absorb log-cols  <-- THE 64-BYTE ONE": AB(b"log-cols", 8),
    "absorb pb-slot": AB(b"pb-slot", 8),
    "absorb pb-scalar": AB(b"pb-scalar", 16),
    "absorb sc-round (deg d, d+1 Fp2)": AB(b"sc-round", 16 * 3),
    "absorb pb-term (173 Fp2)": AB(b"pb-term", 16 * 173),
    "absorb mask-q (1024 Fp2)": AB(b"mask-q", 16 * 1024),
    "absorb mask-prox (1024 Fp2)": AB(b"mask-prox", 16 * 1024),
    "absorb pcs-vec (512 Fp2)": AB(b"pcs-vec", 16 * 512),
    "absorb pcs-prox (512 Fp2)": AB(b"pcs-prox", 16 * 512),
}
out["checks"]["classes_equal_47"] = sorted(k for k, v in out["lengths"].items() if v == 47)
out["checks"]["classes_equal_40"] = sorted(k for k, v in out["lengths"].items() if v == 40)
out["checks"]["classes_equal_64"] = sorted(k for k, v in out["lengths"].items() if v == 64)
# a commitment with `rows` rows has an 8*rows-byte column-hash input
out["checks"]["rows_giving_40"] = 40 // 8
out["checks"]["rows_giving_47"] = "none (47 not a multiple of 8)"
out["checks"]["rows_giving_64"] = 64 // 8
# SeamSpec::new: len a power of two in [2, 4096], LOG_COLS=8, MASK_ROWS=5
seam_rows = sorted({(1 << k) // 256 + (1 if (1 << k) % 256 else 0) + 5 for k in range(1, 13)})
out["checks"]["possible_endpoint_commitment_rows"] = seam_rows

# ---------------------------------------------------------------- residual terms
one = Fraction(1)
two256 = Fraction(1, 1 << BITS)

N_leaf = leaves                       # 12288
N_overlap = inodes + leaves           # 24571
A_TR = 4000                           # the draft's BOUND on absorbs+squeezes

terms = {}
terms["salt_guess_per_q"] = Fraction(N_leaf) * two256
terms["leaf_input_collision"] = Fraction(N_leaf * (N_leaf - 1), 2) * two256
terms["absorb64_overlap"] = Fraction(N_overlap) * two256
terms["absorb64_overlap_BOTH_HALVES"] = Fraction(N_overlap) * two256 * two256
terms["leaf_vs_node_input"] = Fraction(inodes * leaves) * two256 * two256   # omitted by the draft
terms["generator_key_per_q"] = Fraction(3) * two256
terms["generator_key_and_entropy_per_q"] = Fraction(6) * two256
terms["challenge_prequery_per_q"] = Fraction(A_TR) * two256
terms["absorb_collision"] = Fraction(A_TR * (A_TR - 1), 2) * two256
terms["node_guess_per_q"] = Fraction(inodes) * two256 * two256

out["terms"] = {k: {"value_log2": lg(v)} for k, v in terms.items()}

# the fp() reduction bias, exactly:  TV = b(p-b)/(p*2^128), b = 2^128 mod p
N128 = 1 << 128
b = N128 % P
tv_fp = Fraction(b * (P - b), P * N128)

# --- the 327,052 fp() draws of one toy proof, DERIVED BY THE CHECKER from the
#     call sites (the draft and its script hard-code the number with no source)
CFS_COEFFS = sum((n + e) * d + 2 for (n, e, d) in [
    (9, 1, 3), (9, 1, 3), (5, 1, 3), (9, 1, 4), (11, 1, 3), (4, 1, 2), (4, 1, 2),
    (4, 1, 2), (3, 2, 2), (5, 2, 2), (4, 1, 2), (4, 1, 2), (4, 1, 2), (4, 1, 2),
    (9, 1, 4), (9, 1, 4), (8, 1, 4), (11, 1, 4), (9, 1, 4), (8, 1, 3), (8, 1, 2),
    (9, 1, 2), (9, 1, 2)])          # layout.rs:438-462 SLOTS; sumcheck.rs:197-203
draw_sites = {
    "A mask+prox rows (protocol.rs:317)  (455-213)*256": (455 - 213) * 256,
    "A pads (pcs.rs:673)  455*256": 455 * 256,
    "M CfsMask coefficients (zk.rs:433) 2 Fp per Fp2": 2 * CFS_COEFFS,
    "M row pads (zk.rs:444) 23*2*256": 23 * 2 * 256,
    "M b_re,b_im,u_re,u_im (zk.rs:450-455) 4*1024": 4 * 1024,
    "H mask+prox rows (protocol.rs:362) (384-280)*256": (384 - 280) * 256,
    "H zero-sum rows (protocol.rs:365-372) 2*(256-1)": 2 * 255,
    "H pads (pcs.rs:673) 384*256": 384 * 256,
    "2 endpoints: mask rows + pads 2*((7-2)*256 + 7*256)": 2 * ((7 - 2) * 256 + 7 * 256),
}
DRAWS = sum(draw_sites.values())
out["fp_draw_accounting"] = dict(draw_sites, TOTAL=DRAWS, cfs_fp2_coefficients=CFS_COEFFS,
                                 draft_figure=327052, agrees=(DRAWS == 327052))
out["terms"]["fp_reduction_bias_per_draw"] = {"value_log2": lg(tv_fp), "b": b, "p_minus_b": P - b}
out["terms"]["fp_bias_327052_draws"] = {"value_log2": lg(tv_fp * DRAWS)}
out["terms"]["fp_bias_327052_draws_at_2^-96"] = {"value_log2": lg(Fraction(DRAWS) * two256 * (1 << 160))}

# ---------------------------------------------------------------- the sum
D9 = Fraction(2) ** -777 * Fraction(10) ** 0  # placeholder, replaced below
def pow2f(x):
    """2**x for real x as a Fraction, to 200 bits."""
    num = int(round((2.0 ** (x - math.floor(x))) * (1 << 120)))
    e = int(math.floor(x))
    return Fraction(num, 1 << 120) * (Fraction(2) ** e if e >= 0 else Fraction(1, 2 ** (-e)))

SAMPLER = pow2f(-77.7)
LOGUP = pow2f(-112.0)

sums = {}
for qlog in (0, 12, 50, 80, 128):
    q = Fraction(2) ** qlog
    parts = {
        "sampler_D9": SAMPLER,
        "logup_refusal": LOGUP,
        "salt_guess": q * terms["salt_guess_per_q"],
        "leaf_input_collision": terms["leaf_input_collision"],
        "absorb64_overlap": terms["absorb64_overlap"],
        "challenge_prequery": q * terms["challenge_prequery_per_q"],
        "absorb_collision": terms["absorb_collision"],
        "generator": q * terms["generator_key_per_q"],
    }
    tot = sum(parts.values())
    hash_only = tot - SAMPLER - LOGUP
    sums[f"q=2^{qlog}"] = {
        "parts_log2": {k: lg(v) for k, v in parts.items()},
        "sum_log2": lg(tot),
        "hash_layer_only_log2": lg(hash_only),
        "sum_over_sampler_minus_1": float(tot / SAMPLER - 1),
        "sum_log2_full_precision": f"{lg(tot):.12f}",
    }
out["sum"] = sums

# many proofs
many = {}
for klog in (1, 10, 20):
    k = 1 << klog
    many[f"k=2^{klog}"] = {
        "sampler_k_log2": lg(Fraction(k) * SAMPLER),
        "cross_proof_leaf_collision_log2": lg(Fraction(k * N_leaf * (k * N_leaf - 1), 2) * two256),
    }
out["many_proofs"] = many

here = os.path.dirname(os.path.abspath(__file__))
with open(os.path.join(here, "recount.json"), "w") as f:
    json.dump(out, f, indent=2, sort_keys=True, default=str)

print("== per tree ==")
for n, t in out["per_tree"].items():
    print(f"{n:4s} rows={t['rows']:4d} depth={t['depth']} opened={t['distinct_opened']:7.1f} "
          f"leafdig={t['leaf_digests_revealed']:7.1f} unopened_leafdig={t['unopened_leaf_digests_revealed']:7.1f} "
          f"internal={t['internal_revealed']:8.1f} total={t['total_revealed']:8.1f}/{t['nodes_in_tree']} "
          f"({100*t['fraction']:.1f}%) colhash={t['hash_column_input_bytes']}B")
print("\n== totals ==")
for k, v in out["totals"].items():
    print(f"  {k}: {v}")
print("\n== length classes ==")
for k, v in sorted(out["lengths"].items(), key=lambda kv: kv[1]):
    print(f"  {v:8d}  {k}")
print("\n== uniqueness checks ==")
for k, v in out["checks"].items():
    print(f"  {k}: {v}")
print("\n== terms (log2) ==")
for k, v in out["terms"].items():
    print(f"  {k}: 2^{v['value_log2']:.4f}")
print("\n== sums ==")
for k, v in out["sum"].items():
    print(f"  {k}: total 2^{v['sum_log2_full_precision']}  hash-layer-only 2^{v['hash_layer_only_log2']:.4f}"
          f"  (sum/sampler - 1 = {v['sum_over_sampler_minus_1']:.3e})")
print("\n== many proofs ==")
for k, v in out["many_proofs"].items():
    print(f"  {k}: sampler 2^{v['sampler_k_log2']:.4f}  cross-proof leaf collision 2^{v['cross_proof_leaf_collision_log2']:.4f}")
