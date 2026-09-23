#!/usr/bin/env python3
"""Exact counts for `docs/zkmatrix-poc/ZK60_HASH_LAYER_STANDALONE_TAGGED_BLOCK.md`.

A STANDALONE tagged shaped block: one proof, one transcript under the BLOCK
profile's domain and keys, five commitments (A, H, M and the two external
endpoints), five openings in the order M, A, H, Input, Output.

Every code constant is quoted from the lane `/home/victor/wt-zk60-block125m`
at commit 544fbaf (read-only).  MEASURED figures are read from the run gate's
round-9j records on `/home/victor/wt-zk60-jointview` (read-only) and from the
lane's stage-36 ledger table; both are named where they are used.  Nothing is
built, proved, verified or benchmarked here.  Arithmetic is exact integer /
Fraction arithmetic, except the tree-occupancy EXPECTATIONS (floating point,
printed as such) and the final log2 of an exact rational.

Discipline (as in `results/zk60_hash_layer_fs_lift_run/run_hash_counts.py`):
CONTROLS FIRST -- published figures reproduced before anything new is computed.

  C1  the toy's 327,052 fp() draws and 12,288 salts, 2^-77.68 (D9, D22 §4;
      MEASURED by lane stage 36: 320,908 + 3,072 + 3,072)
  C2  rung-K4: 750,540 fp() draws per block (MEASURED, stage 36) and 7,424 per
      endpoint (MEASURED on the stage-36 replica, finding S36-F2)
  C3  the run memo's accepted figures: 109,728,784 draws / 2^-69.2906 and
      2,473,984 salts at 125M L=12; 2,093,340 / 2^-75.0026 at rung-G L=3; its
      absorb counts 1,129 / 5,932; its residual rows (salt guessing -112.30 /
      -106.76, leaf collision -225.60 / -214.52, pre-query -115.02 / -110.52,
      absorb collision -231.05 / -222.04, B10 -128.00)
  C4  the gate's per-commitment blinding-unknown counts on the four REAL
      standalone block bundles (round 9j, stage 11 / stage 12 of each record)
      against this script's per-commitment draw model
  C5  the gate's MEASURED transcript counter on the four block bundles:
      final_counter == challenges_checked + 64 * 5 (five openings)
  C6  ruling S-4's 2^-118.4 per block
  C7  the per-draw reduction bias of fp() is at most 2^-96 (exact)
  C8  the opened-column bytes the gate re-hashed (2,594,816 / 26,470,400) and
      the expected distinct opened columns against the gate's measured
      distinct_salted_leaves
"""

import json
import math
import os
from fractions import Fraction

# ------------------------------------------------------------------ constants
P = 0xFFFF_FFFF_0000_0001               # zkp-core/src/field.rs:10
P2 = P * P                               # |Fp2|
OPENED = 256                             # Q256 in the parameter line (protocol.rs:128-148)
IDX_SQUEEZES = OPENED // 4               # transcript.rs:136-148: 4 indices per 32-byte squeeze
N_SLOTS = 23
MASK_ROWS = 50                           # 2*N_SLOTS + 4 (zk.rs:486)
MASK_DOM = 1 << 12                       # zk.rs:374 MASK_LOG_DOM = 12
MASK_Q = 256                             # zk.rs:375
MASK_M = 1 << 9                          # zk.rs:373 MASK_LOG_MSG = 9
EP_MASK_ROWS = 5                         # endpoint_g.rs:92

# Shape constructor arguments: shape.rs:766-785 (rung_g), :1141-1144 (m125);
# the rows / round counts are the pinned models grow_tests.rs:369-391
# (MODEL_RUNG_G), :408-423 (MODEL_RUNG_K4), :432-447 (MODEL_M125), :286-301
# (MODEL_TOY).  Group counts: the gate's MEASURED roles[*].groups (A 36, H 9,
# endpoint 1), equal to the pinned a_groups / h_groups.
SHAPES = {
    "toy": dict(profile="hashline-zk-mr1/private-block-t32-poc/1",
                log_cols=8, inv_rate=8, endpoint_log_n=8, endpoint_inv_rate=8,
                endpoint_rows=7, a_rows=455, a_data=213, h_rows=384, h_data=280,
                published_round_values=721, challenge_draws=184,
                a_groups=35, h_groups=9, a_claims=120, h_claims=52),
    "rung_g": dict(profile="hashline-zk-mr1/private-block-rung-g-t24-dev/1",
                   run_profile="hashline-zk-mr1/private-run-rung-g-t24-dev/1",
                   log_cols=10, inv_rate=4, endpoint_log_n=10, endpoint_inv_rate=4,
                   endpoint_rows=9, a_rows=623, a_data=377, h_rows=576, h_data=470,
                   published_round_values=1055, challenge_draws=242,
                   a_groups=36, h_groups=9, a_claims=122, h_claims=53),
    "rung_k4": dict(profile="hashline-zk-mr1/private-block-rung-k4-t24-dev/1",
                    log_cols=10, inv_rate=4, endpoint_log_n=10, endpoint_inv_rate=4,
                    endpoint_rows=9, a_rows=727, a_data=481, h_rows=720, h_data=614,
                    published_round_values=1070, challenge_draws=245,
                    a_groups=36, h_groups=9, a_claims=122, h_claims=53),
    "m125": dict(profile="hashline-zk-mr1/private-block-m125/1",
                 run_profile="hashline-zk-mr1/private-run-m125/1",
                 log_cols=14, inv_rate=4, endpoint_log_n=14, endpoint_inv_rate=4,
                 endpoint_rows=37, a_rows=5681, a_data=5435, h_rows=7120, h_data=7018,
                 published_round_values=1554, challenge_draws=361,
                 a_groups=36, h_groups=9, a_claims=122, h_claims=51),
}

# The block parameter line (protocol.rs:128-148), SH_G/SH_H_PROD/SH_Z = 7/14/6.
TOKENS = {"rung_g": (24, 96, 192, 6, 2, 16), "m125": (512, 768, 2048, 12, 4, 64)}

# MEASURED by the run gate, round 9j (records on the joint-view branch,
# results/zk60_native_run_gate_block/block-*.json, stage2_transcript_replay).
GATE = "/home/victor/wt-zk60-jointview/results/zk60_native_run_gate_block"
MEASURED_REPLAY = {  # (challenges_checked, final_counter)
    "block-rung-g-dense": (2036, 2356), "block-rung-g-zero": (2036, 2356),
    "block-m125-dense": (13932, 14252), "block-m125-zero": (13932, 14252),
}
MEASURED_DISTINCT = {  # stage9_hash_layer.distinct_salted_leaves
    "block-rung-g-dense": 1244, "block-rung-g-zero": 1240,
    "block-m125-dense": 1270, "block-m125-zero": 1267,
}
MEASURED_HASHED_BYTES = {"rung_g": 2594816, "m125": 26470400}
# stage 11 fibre blinding_unknowns per commitment (A, H, E-In, E-Out) and
# stage 12 CFS coefficient unknowns / shape blinding unknowns of M
MEASURED_UNKNOWNS = {
    "rung_g": dict(A=411392, H=258046, E_in=7424, E_out=7424, M_coef=1718, M_free_pads=15870),
    "m125": dict(A=5484800, H=3526654, E_in=91392, E_out=91392, M_coef=2478, M_free_pads=15870),
}
# lane stage 36 (z36-pinned.log), MEASURED on real single-block proofs
STAGE36 = {"toy": dict(block_fp=320908, block_salts=8192, both_endpoints_fp=6144),
           "rung_k4": dict(block_fp=750540, block_salts=12288, both_endpoints_fp=14848)}

# Tagged block profiles registered at 544fbaf: shape.rs:158 REGISTERED_BLOCK_SHAPES
# (nine constructors, two legacy: shape.rs:1213-1215) -> seven tagged; plus the
# test-only rung-K8 (k8_tests.rs:74).  Four keys each (hashtag.rs:92-101).
TAGGED_PRODUCTION = 7
TAGGED_WITH_TEST_ONLY = 8
M_RUN_MEMO = 12   # the run memo's m at 8c5922b


def lg(x):
    if isinstance(x, Fraction):
        return math.log2(x.numerator) - math.log2(x.denominator)
    return math.log2(x)


def nn_block(s):
    return (1 << s["log_cols"]) * s["inv_rate"]


def nn_io(s):
    return (1 << s["endpoint_log_n"]) * s["endpoint_inv_rate"]


def sum_mask_lengths(s):
    """sum_s L_s = published - draws + 2*23 (the run script's identity)."""
    return s["published_round_values"] - s["challenge_draws"] + 2 * N_SLOTS


# ------------------------------------------------------------ fp() draws
def draws_A(s):
    """protocol.rs:1002-1004 (mask rows from a_mask_base = a_data, layout.rs:1085)
    + zkp-core pcs.rs:777 (rows*q pads)."""
    n = 1 << s["log_cols"]
    return (s["a_rows"] - s["a_data"]) * n + s["a_rows"] * OPENED


def draws_H(s):
    """protocol.rs:1115-1117 (mask rows from h_mask_base = h_data, layout.rs:1096)
    + :1118-1126 (the two zero-sum rows, layout.rs:1281-1284, n-1 each)
    + zkp-core pcs.rs:777."""
    n = 1 << s["log_cols"]
    return (s["h_rows"] - s["h_data"]) * n + 2 * (n - 1) + s["h_rows"] * OPENED


def draws_M(s):
    """zk.rs:485 (CfsMask::random: 2*L_s per slot), :496 (46 rows x MASK_Q pads),
    :503-508 (b_re, b_im, u_re, u_im: 4 x 2m)."""
    return 2 * sum_mask_lengths(s) + 2 * N_SLOTS * MASK_Q + 4 * 2 * MASK_M


def draws_endpoint(s):
    """endpoint_g.rs:276-278 (the five reserved rows) + zkp-core pcs.rs:777."""
    n = 1 << s["endpoint_log_n"]
    return EP_MASK_ROWS * n + s["endpoint_rows"] * OPENED


def block_stream(s):
    fp = draws_A(s) + draws_H(s) + draws_M(s)
    salts = 2 * nn_block(s) + MASK_DOM          # pcs.rs:778 twice, zk.rs:513
    return dict(fp=fp, salts=salts, bytes=16 * fp + 32 * salts)


def endpoint_stream(s):
    fp = draws_endpoint(s)
    salts = nn_io(s)
    return dict(fp=fp, salts=salts, bytes=16 * fp + 32 * salts)


def proof_draws(s):
    b, e = block_stream(s), endpoint_stream(s)
    return dict(block_stream=b, endpoint_stream_each=e,
                fp_total=b["fp"] + 2 * e["fp"], salts_total=b["salts"] + 2 * e["salts"],
                parts=dict(A=draws_A(s), H=draws_H(s), M=draws_M(s),
                           E_in=draws_endpoint(s), E_out=draws_endpoint(s)))


# ------------------------------------------------------------ the trees
def commitments(s):
    """(name, encoded columns) of the five commitments of ONE standalone block"""
    return [("M", MASK_DOM), ("A", nn_block(s)), ("H", nn_block(s)),
            ("Input", nn_io(s)), ("Output", nn_io(s))]


def tree_occupancy(nn, draws=OPENED):
    """256 indices WITH replacement (transcript.rs:136-148); the run script's
    formulas, which reproduce the toy's published table."""
    depth = nn.bit_length() - 1
    q1 = (1.0 - 1.0 / nn) ** draws
    q2 = (1.0 - 2.0 / nn) ** draws
    distinct = nn * (1.0 - q1)
    leaves_revealed = nn * (1.0 - q2)
    unopened_revealed = nn * (q1 - q2)
    internal = 0.0
    for l in range(1, depth):
        m = min(1 << (l + 1), nn)
        internal += (nn >> l) * (1.0 - (1.0 - m / nn) ** draws)
    total = leaves_revealed + internal + 1.0
    return dict(nn=nn, depth=depth, distinct_opened=distinct,
                leaf_digests_revealed=leaves_revealed,
                of_them_never_opened=unopened_revealed,
                internal_nodes_revealed=internal, total_revealed=total,
                fraction_of_tree=total / (2 * nn - 1))


# ------------------------------------------------------------ transcript
def block_absorbs(s, rounds=None, groups=None):
    """Every Transcript::absorb of ONE standalone block, from the code at 544fbaf:
      header, protocol.rs:116-121                                  5
      A root + rows + log-cols, protocol.rs:1013 -> :150-153       3
      M root, bare, protocol.rs:1023                               1
      H root + rows + log-cols, protocol.rs:1132                   3
      per slot: pb-slot argument.rs:475, pb-scalar :530,
                pb-term :592                                        3 x 23
      per sumcheck round: sc-round -- main rounds zkp-core
        sumcheck.rs:109 through the masker (zk.rs:1082-1083),
        extension rounds zk.rs:1099                                 sum rounds
      M opening: mask-q zk.rs:584, mask-prox zk.rs:593             2
      per PCS opening (A, H, Input, Output): one pcs-vec per group
        + pcs-prox, zkp-core pcs.rs:1033, :1035                    groups + 1
    No run-shape, no pb-run-stage / pb-run-block, no B root."""
    r = s["challenge_draws"] if rounds is None else rounds
    g = [s["a_groups"], s["h_groups"], 1, 1] if groups is None else groups
    return 5 + 3 + 1 + 3 + 3 * N_SLOTS + r + 2 + sum(x + 1 for x in g)


def modelled_squeezes(s):
    """the squeeze channels named in the capture's transcript_program; the 23
    slots' own DEFINITION draws are not modelled (they are what the measured
    counter minus this is)."""
    return (3 + N_SLOTS + s["challenge_draws"]
            + (1 + (2 * N_SLOTS + 2) + IDX_SQUEEZES)
            + (s["a_claims"] + s["a_rows"] + IDX_SQUEEZES)
            + (s["h_claims"] + s["h_rows"] + IDX_SQUEEZES)
            + 2 * (1 + s["endpoint_rows"] + IDX_SQUEEZES))


def block_parameter_line(name):
    s = SHAPES[name]
    t, d, f, h, kv, dh = TOKENS[name]
    base = (f"T{t}/d{d}/f{f}/H{h}/KV{kv}/dh{dh}/log_cols{s['log_cols']}/inv_rate{s['inv_rate']}"
            f"/Q256/P1/sh-g7-u0-h14-z6/two-private-endpoints/one-proof-one-transcript")
    return base + f"/endpoint-log_n{s['endpoint_log_n']}-rate{s['endpoint_inv_rate']}-pad256-rows{s['endpoint_rows']}"


def transcript_input_lengths(name):
    """every input layout to the block's KEYED transcript function F_T
    (transcript.rs:40-45 constructor, :59-68 absorb, :101-111 squeeze)"""
    s = SHAPES[name]
    out = {"squeeze (transcript.rs:101-111)": 47,
           "constructor, BLOCK profile (protocol.rs:115)": 12 + len(s["profile"])}
    fixed = [("expected-IO", 112), ("public-statement", 32), ("calibration", 32),
             ("schedule", 32), ("A", 32), ("H", 32), ("M", 32), ("rows", 8),
             ("log-cols", 8), ("pb-slot", 8), ("pb-scalar", 16)]
    for lab, dlen in fixed:
        out[f"absorb `{lab}` ({dlen} B)"] = 48 + len(lab) + dlen
    out["absorb `parameters`, the block line"] = 48 + len("parameters") + len(block_parameter_line(name))
    return out


def unkeyed_input_lengths(name):
    """every input to UNKEYED BLAKE3 (F_U) on a standalone tagged block's path"""
    return {
        "calibration identity (private_block.rs:365-367)": len(b"B3 public fixed calibration v1"),
        "generalised-endpoint spec digest, x2 (endpoint_g.rs:197-206)": len(b"hashline/private-block/general-endpoint/v1") + 32 + 8 * 8 + 4,
        "block public-statement digest (private_block.rs:755-761), at least": len(b"hashline/private-block-public/1"),
        "block schedule digest (layout.rs), at least": 33 + 8,
        "generator refill key||counter (rng.rs:53-61)": 40,
    }


# ------------------------------------------------------------ residuals
def residuals(fp_draws, n_leaf, a_queries, m_keys, blocks=1, q_log2=128):
    q = Fraction(1 << q_log2)
    two256 = Fraction(1, 1 << 256)
    t = {}
    t["sampler bias (D9): draws x 2^-96"] = Fraction(fp_draws, 1 << 96)
    t["LogUp refusal (S-4), one-sided: blocks x 768/|Fp2|"] = Fraction(blocks * 768, P2)
    t["salt guessing: q N_leaf 2^-256"] = q * n_leaf * two256
    t["leaf-input collision: C(N_leaf,2) 2^-256"] = Fraction(n_leaf * (n_leaf - 1) // 2) * two256
    t["challenge pre-query (B5): q A 2^-256"] = q * a_queries * two256
    t["absorb-input collision (B6): C(A,2) 2^-256"] = Fraction(a_queries * (a_queries - 1) // 2) * two256
    t["constructor-vs-absorb (B10): (A+q) 2^-256"] = (a_queries + q) * two256
    t["tag-key collision: C(m,2) 2^-256"] = Fraction(m_keys * (m_keys - 1) // 2) * two256
    t["tag key = a generator key: 3 x 4 x 2^-256"] = 12 * two256
    t["generator, in-model alternative: 6q 2^-256"] = 6 * q * two256
    total = sum(t.values())
    sampler = t["sampler bias (D9): draws x 2^-96"]
    hash_terms = {k: v for k, v in t.items() if not k.startswith("sampler") and not k.startswith("LogUp")}
    largest_hash = max(hash_terms.values())
    return dict(terms={k: round(lg(v), 4) for k, v in t.items()},
                total_log2=round(lg(total), 4),
                total_minus_sampler_log2=round(lg(total - sampler), 4),
                gap_sampler_to_largest_hash_term_bits=round(lg(sampler) - lg(largest_hash), 2),
                largest_hash_term=max(hash_terms, key=hash_terms.get))


# =================================================================== controls
def controls():
    out = {}
    toy = SHAPES["toy"]
    d = proof_draws(toy)
    out["C1 toy fp() draws per proof"] = dict(got=d["fp_total"], want=327052, ok=d["fp_total"] == 327052)
    out["C1 toy block-stream fp / salts (stage 36)"] = dict(
        got=[d["block_stream"]["fp"], d["block_stream"]["salts"]], want=[320908, 8192],
        ok=[d["block_stream"]["fp"], d["block_stream"]["salts"]] == [320908, 8192])
    out["C1 toy salts per proof"] = dict(got=d["salts_total"], want=12288, ok=d["salts_total"] == 12288)
    out["C1 toy sampler log2"] = dict(got=round(lg(Fraction(d["fp_total"], 1 << 96)), 2), want=-77.68)
    k4 = SHAPES["rung_k4"]
    dk = proof_draws(k4)
    out["C2 rung-K4 block stream fp / salts (stage 36, MEASURED)"] = dict(
        got=[dk["block_stream"]["fp"], dk["block_stream"]["salts"]], want=[750540, 12288],
        ok=[dk["block_stream"]["fp"], dk["block_stream"]["salts"]] == [750540, 12288])
    out["C2 rung-K4 both endpoints fp (stage 36 replica, MEASURED)"] = dict(
        got=2 * dk["endpoint_stream_each"]["fp"], want=14848, ok=2 * dk["endpoint_stream_each"]["fp"] == 14848)
    # C3 the run memo's accepted figures, recomputed here from the same model
    g, m = SHAPES["rung_g"], SHAPES["m125"]
    # boundary draws (the run memo's model): rows = data + 2*2 + 2, the
    # reserved rows filled with fp() plus rows x Q pads
    def boundary_draws(s):
        n = 1 << s["endpoint_log_n"]
        data = s["endpoint_rows"] - EP_MASK_ROWS
        rows = data + 2 * 2 + 2
        return (rows - data) * n + rows * OPENED
    def run_total(s, L):
        return L * block_stream(s)["fp"] + (L - 1) * boundary_draws(s) + 2 * draws_endpoint(s)
    def run_salts(s, L):
        return L * (2 * nn_block(s) + MASK_DOM) + (L + 1) * nn_io(s)
    def run_absorbs(s, L):
        per = 2 + 3 + 1 + 3 + 3 * N_SLOTS + s["challenge_draws"] + 2 + (s["a_groups"] + 1) + (s["h_groups"] + 1)
        tot = 6
        for k in range(L):
            t = per + (3 if k + 1 < L else 0) + (2 if k == 0 else 3) + (2 if k + 1 == L else 0)
            tot += t
        return tot
    out["C3 run 125M L=12 draws / sampler"] = dict(
        got=[run_total(m, 12), round(lg(Fraction(run_total(m, 12), 1 << 96)), 4)],
        want=[109728784, -69.2906])
    out["C3 run rung-G L=3 draws / sampler"] = dict(
        got=[run_total(g, 3), round(lg(Fraction(run_total(g, 3), 1 << 96)), 4)],
        want=[2093340, -75.0026])
    out["C3 run 125M L=12 salts"] = dict(got=run_salts(m, 12), want=2473984)
    out["C3 run absorbs rung-G L=3 / 125M L=12"] = dict(got=[run_absorbs(g, 3), run_absorbs(m, 12)], want=[1129, 5932])
    rg_A = 1129 + 6924 + 12
    m_A = 5932 + 164560 + 48 + 1024 * 12
    rr = residuals(run_total(g, 3), run_salts(g, 3), rg_A, M_RUN_MEMO, blocks=3)["terms"]
    rm = residuals(run_total(m, 12), run_salts(m, 12), m_A, M_RUN_MEMO, blocks=12)["terms"]
    out["C3 run residual rows rung-G L=3 (salt, leaf coll., pre-query, absorb coll., B10, tag-key)"] = dict(
        got=[round(rr[k], 2) for k in ["salt guessing: q N_leaf 2^-256", "leaf-input collision: C(N_leaf,2) 2^-256",
                                       "challenge pre-query (B5): q A 2^-256", "absorb-input collision (B6): C(A,2) 2^-256",
                                       "constructor-vs-absorb (B10): (A+q) 2^-256", "tag-key collision: C(m,2) 2^-256"]],
        want=[-112.30, -225.60, -115.02, -231.05, -128.00, -249.96])
    out["C3 run residual rows 125M L=12 (same order)"] = dict(
        got=[round(rm[k], 2) for k in ["salt guessing: q N_leaf 2^-256", "leaf-input collision: C(N_leaf,2) 2^-256",
                                       "challenge pre-query (B5): q A 2^-256", "absorb-input collision (B6): C(A,2) 2^-256",
                                       "constructor-vs-absorb (B10): (A+q) 2^-256", "tag-key collision: C(m,2) 2^-256"]],
        want=[-106.76, -214.52, -110.52, -222.04, -128.00, -249.96])
    # C4 the gate's per-commitment counts on the real bundles
    for name in ("rung_g", "m125"):
        s = SHAPES[name]
        u = MEASURED_UNKNOWNS[name]
        model = dict(A=draws_A(s), H=draws_H(s), E_in=draws_endpoint(s), E_out=draws_endpoint(s),
                     M_coef=2 * sum_mask_lengths(s), M_free_pads=2 * N_SLOTS * MASK_Q + 4 * 2 * MASK_M - 2)
        out[f"C4 {name}: gate blinding unknowns vs this model"] = dict(
            gate=u, model=model, ok=all(u[k] == model[k] for k in u),
            note="M_free_pads = 46*256 pads + 4*1024 (b,u) minus the two drawn-then-overwritten b[m] entries (zk.rs:505-506); the fp() DRAW count of M is 2*sum L_s + 46*256 + 4*1024")
    # C5 the gate's measured counter model
    for rec, (ch, ctr) in MEASURED_REPLAY.items():
        out[f"C5 {rec}: final_counter == challenges + 64*5"] = dict(got=ch + IDX_SQUEEZES * 5, want=ctr, ok=ch + IDX_SQUEEZES * 5 == ctr)
    out["C5 dense == zero (transcript operation count does not move with the hidden input)"] = dict(
        rung_g=MEASURED_REPLAY["block-rung-g-dense"] == MEASURED_REPLAY["block-rung-g-zero"],
        m125=MEASURED_REPLAY["block-m125-dense"] == MEASURED_REPLAY["block-m125-zero"])
    # C6
    out["C6 S-4 per block log2"] = dict(got=round(lg(Fraction(768, P2)), 2), want=-118.42)
    # C7 exact bias of one fp() draw: X uniform on [0, 2^128), X mod p
    two128 = 1 << 128
    r = two128 % P
    sd = Fraction(r * (P - r), P * two128)
    out["C7 fp() per-draw statistical distance (exact)"] = dict(
        r_equals_p_minus_2_32=(r == P - (1 << 32)), log2=round(lg(sd), 8),
        at_most_2_96=sd <= Fraction(1, 1 << 96))
    # C8 hashed bytes and distinct opened columns
    for name in ("rung_g", "m125"):
        s = SHAPES[name]
        cols = [("M", MASK_ROWS), ("A", s["a_rows"]), ("H", s["h_rows"]),
                ("Input", s["endpoint_rows"]), ("Output", s["endpoint_rows"])]
        b = sum(OPENED * rows * 8 for _, rows in cols)
        out[f"C8 {name}: opened-column bytes"] = dict(got=b, want=MEASURED_HASHED_BYTES[name], ok=b == MEASURED_HASHED_BYTES[name])
        exp = sum(tree_occupancy(nn)["distinct_opened"] for _, nn in commitments(s))
        key = "rung-g" if name == "rung_g" else "m125"
        out[f"C8 {name}: expected distinct opened columns vs MEASURED"] = dict(
            expected=round(exp, 1), measured=[MEASURED_DISTINCT[f"block-{key}-dense"], MEASURED_DISTINCT[f"block-{key}-zero"]])
    return out


# ================================================== cross-check from the bundles
BUNDLES = {
    "rung_g": "/home/victor/wt-zk60-block125m/results/zk60_block_captures_20260923/rung-g/rung-g-dense/observations.json",
    "m125": "/home/victor/zk60-artifacts/block-captures-20260923/m125-dense/observations.json",
}


def from_bundle(name):
    """Reads ONLY public structure of the capture's observations.json: the
    number of sumcheck rounds per slot and the number of groups / claims / rows
    per opening role.  No column, salt, path or field value is read."""
    path = BUNDLES[name]
    if not os.path.exists(path):
        return dict(available=False, path=path)
    o = json.load(open(path))
    rounds = sum(len(a["rounds"]) for a in o["arguments"])
    roles = [(r["role"], len(r["groups"]), len(r["claims"]) if isinstance(r["claims"], list) else r["claims"])
             for r in o["roles"]]
    groups = [g for _, g, _ in roles]
    return dict(available=True, path=path, opening_order=o["opening_order"], slots=len(o["arguments"]),
                sumcheck_rounds=rounds, roles=roles,
                absorbs_from_the_capture=block_absorbs(SHAPES[name], rounds=rounds, groups=groups))


# ============================================================== configurations
def configuration(name, gate_prefix):
    s = SHAPES[name]
    d = proof_draws(s)
    trees = {c: tree_occupancy(nn) for c, nn in commitments(s)}
    n_leaf = sum(nn for _, nn in commitments(s))
    distinct = sum(t["distinct_opened"] for t in trees.values())
    ch, ctr = MEASURED_REPLAY[f"{gate_prefix}-dense"]
    absorbs = block_absorbs(s)
    a_queries = absorbs + ctr + 1          # + the constructor query
    cfg = dict(profile=s["profile"], commitments=[c for c, _ in commitments(s)],
               openings_in_order=["M", "A", "H", "Input", "Output"],
               encoded_columns={c: nn for c, nn in commitments(s)},
               N_leaf_salts_drawn=n_leaf, salt_slots_published=5 * OPENED,
               distinct_opened_expected=round(distinct, 1),
               distinct_opened_measured=[MEASURED_DISTINCT[f"{gate_prefix}-dense"], MEASURED_DISTINCT[f"{gate_prefix}-zero"]],
               unopened_leaves_expected=round(n_leaf - distinct, 1),
               unopened_leaves_measured=[n_leaf - MEASURED_DISTINCT[f"{gate_prefix}-dense"], n_leaf - MEASURED_DISTINCT[f"{gate_prefix}-zero"]],
               unopened_leaf_digests_published_expected=round(sum(t["of_them_never_opened"] for t in trees.values()), 1),
               nodes_revealed_expected=round(sum(t["total_revealed"] for t in trees.values()), 1),
               path_digest_slots=sum(OPENED * t["depth"] for t in trees.values()),
               trees={c: {k: (round(v, 2) if isinstance(v, float) else v) for k, v in t.items()} for c, t in trees.items()},
               draws=d,
               sampler_log2=round(lg(Fraction(d["fp_total"], 1 << 96)), 4),
               prover_queries=dict(F_C_column_digests=n_leaf, F_L_salted_leaves=n_leaf,
                                   F_N_inner_nodes=n_leaf - 5, F_T_absorbs=absorbs,
                                   F_T_live_squeezes_MEASURED=ctr, F_T_constructor=1,
                                   F_T_position_tag_squeezes=0,
                                   F_T_total_A=a_queries,
                                   challenges_checked_MEASURED=ch,
                                   modelled_squeeze_channels=modelled_squeezes(s),
                                   implied_slot_definition_draws=ctr - modelled_squeezes(s)),
               transcript_input_lengths=transcript_input_lengths(name),
               unkeyed_input_lengths=unkeyed_input_lengths(name),
               bundle_cross_check=from_bundle(name))
    cfg["another_transcript_input_of_47_bytes"] = [k for k, v in cfg["transcript_input_lengths"].items() if v == 47 and "squeeze" not in k]
    cfg["another_unkeyed_input_of_40_bytes"] = [k for k, v in cfg["unkeyed_input_lengths"].items() if v == 40 and "refill" not in k]
    for label, m_keys in [("m=28 (production registry at 544fbaf)", 4 * TAGGED_PRODUCTION),
                          ("m=32 (with the test-only rung-K8)", 4 * TAGGED_WITH_TEST_ONLY)]:
        cfg[f"residuals q=2^128, {label}"] = residuals(d["fp_total"], n_leaf, a_queries, m_keys)
    cfg["residuals q=2^80, m=32"] = residuals(d["fp_total"], n_leaf, a_queries, 4 * TAGGED_WITH_TEST_ONLY, q_log2=80)
    cfg["two-world LogUp term (2 x 768/|Fp2|) log2"] = round(lg(Fraction(2 * 768, P2)), 4)
    cfg["liveness: 4 PCS-opening determinants / p, log2"] = round(lg(Fraction(4, P)), 4)
    k = 10 ** 6
    two256 = Fraction(1, 1 << 256)
    q = Fraction(1 << 128)
    many = dict(sampler=Fraction(k * d["fp_total"], 1 << 96), refusal=Fraction(k * 768, P2),
                leaf_collision=Fraction((k * n_leaf) * (k * n_leaf - 1) // 2) * two256,
                salt_guessing=q * k * n_leaf * two256)
    many["total"] = sum(many.values())
    cfg["a million proofs (10^6, not 2^20)"] = {kk: round(lg(v), 2) for kk, v in many.items()}
    return cfg


def main():
    out = dict(controls=controls())
    out["configurations"] = {"rung_g_standalone_block": configuration("rung_g", "block-rung-g"),
                             "m125_standalone_block": configuration("m125", "block-m125")}
    # rung-K4 standalone, as a MEASURED anchor (stage 36)
    k4 = proof_draws(SHAPES["rung_k4"])
    out["rung_k4_standalone_block_sampler"] = dict(fp_total=k4["fp_total"],
                                                   label="block stream MEASURED (stage 36), endpoints MEASURED on the replica",
                                                   sampler_log2=round(lg(Fraction(k4["fp_total"], 1 << 96)), 4))
    out["tag_keys"] = {f"C({m},2) 2^-256 log2": round(lg(Fraction(m * (m - 1) // 2, 1 << 256)), 2)
                       for m in (8, M_RUN_MEMO, 4 * TAGGED_PRODUCTION, 4 * TAGGED_WITH_TEST_ONLY)}
    print(json.dumps(out, indent=1))


if __name__ == "__main__":
    main()
