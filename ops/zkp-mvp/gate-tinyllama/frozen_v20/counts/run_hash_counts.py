#!/usr/bin/env python3
"""Exact counts for `docs/zkmatrix-poc/ZK60_HASH_LAYER_AND_FS_LIFT_RUN.md`.

Every input is a geometry constant read from a named source line on the lane
`/home/victor/wt-zk60-block125m` at commit 8c5922b.  NOTHING is measured here:
no capture, no witness, no salt, no receipt and no private plane is read, and
nothing was built, proved, verified or benchmarked for this file.  All
arithmetic is exact integer / Fraction arithmetic except the tree-occupancy
expectations, which are floating point and are printed as such.

Discipline: the script FIRST reproduces six already-published figures, and
only then computes anything new.  The controls are

  C1  the toy's 12,288 salts drawn and 327,052 `fp()` draws  (decision D9)
  C2  the toy's per-tree revealed-node table 240.7 / 453.2 / 212.5 / 1,200.6
      / 1,654.8 / 40.4 %        (`ZK60_D8_D11_RESTATEMENT.md` section 3.3,
      reproduced in `ZK60_HASH_LAYER_AND_FS_LIFT.md` section 1.2)
  C3  the run composition memo's per-block / per-boundary / per-endpoint draw
      counts 686,990 / 8,704 / 7,424 (rung-G) and 9,029,742 / 108,032 /
      91,392 (125M), and the run totals 2,093,226 and 109,728,040, with the
      residual 2^-69.3       (`ZK60_JOINT_LAW_COMPOSITION_RUN.md` section 6.1)
  C4  the salt count 2,473,984 for a twelve-block 125M run (same section 3.5)
  C5  the 3,328 opened columns of a three-block run that the run gate
      re-hashed  (`ZK60_PRIVATE_RUN_MULTI_BLOCK_DISPOSITION.md` round 3)
  C6  the input-dependent refusal 2^-118.4 per block and 2^-114.8 for a
      twelve-block 125M run  (`ZK60_GENERIC_RANK_LEMMA_SHAPED_DISPOSITION.md`
      ruling S-4)
  C7  the run gate's own MEASURED squeeze counter and challenge count on four
      three-block bundles, against this script's model of them:
      final_counter == challenges_checked + 64 * (4L+1)

Sources for every constant are in SHAPES below.
"""

import json
import math
from fractions import Fraction

P = (1 << 64) - (1 << 32) + 1          # zkp-core/src/field.rs
P2 = P * P                              # |Fp2|
OPENED = 256                            # opened columns per commitment (Q)
MASK_ROWS = 50                          # layout.rs:930  M_ROWS = 2*N_SLOTS+4
MASK_DOM = 4096                         # wire.rs:18
MASK_VEC = 1024                         # wire.rs:17
N_SLOTS = 23
SH_G, SH_H_PROD, SH_Z = 7, 14, 6        # layout.rs:78-80

# ---------------------------------------------------------------- the shapes
# constructor arguments: shape.rs:327 (toy), :381 (rung_g), :441 (rung_k4),
# :477 (m125).  Row counts: the pinned models MODEL_TOY / MODEL_RUNG_G /
# MODEL_RUNG_K4 / MODEL_M125 in grow_tests.rs:286, :369, :408, :432.
SHAPES = {
    "toy": dict(
        profile="hashline-zk-mr1/private-block-t32-poc/1",
        run_profile=None,                       # the toy is never run-composed
        tokens=32, width=16, hidden=16, q_heads=2, head_dim=8, kv_heads=1,
        log_cols=8, inv_rate=8, endpoint_log_n=8, endpoint_inv_rate=8,
        endpoint_rows=7, frozen_toy=True,
        a_rows=455, a_data=213, a_groups=35, a_sites=120,
        h_rows=384, h_data=280, h_groups=9, h_sites=51,
        published_round_values=721, challenge_draws=184,
    ),
    "rung_g": dict(
        profile="hashline-zk-mr1/private-block-rung-g-t24-dev/1",
        run_profile="hashline-zk-mr1/private-run-rung-g-t24-dev/1",
        tokens=24, width=96, hidden=192, q_heads=6, head_dim=16, kv_heads=2,
        log_cols=10, inv_rate=4, endpoint_log_n=10, endpoint_inv_rate=4,
        endpoint_rows=9, frozen_toy=False,
        a_rows=623, a_data=377, a_groups=36, a_sites=122,
        h_rows=576, h_data=470, h_groups=9, h_sites=52,
        published_round_values=1055, challenge_draws=242,
        # the SAME model BEFORE the stage-20 S19-F1 repair, which is what the
        # run composition memo counted (its section 1.2 table)
        pre_repair=dict(published_round_values=1034, challenge_draws=240),
    ),
    "rung_k4": dict(
        profile="hashline-zk-mr1/private-block-rung-k4-t24-dev/1",
        run_profile="hashline-zk-mr1/private-run-rung-k4-t24-dev/1",
        tokens=24, width=96, hidden=192, q_heads=12, head_dim=8, kv_heads=4,
        log_cols=10, inv_rate=4, endpoint_log_n=10, endpoint_inv_rate=4,
        endpoint_rows=9, frozen_toy=False,
        a_rows=727, a_data=481, a_groups=36, a_sites=122,
        h_rows=720, h_data=614, h_groups=9, h_sites=52,
        published_round_values=1070, challenge_draws=245,
    ),
    "m125": dict(
        profile="hashline-zk-mr1/private-block-m125/1",
        run_profile="hashline-zk-mr1/private-run-m125/1",
        tokens=512, width=768, hidden=2048, q_heads=12, head_dim=64, kv_heads=4,
        log_cols=14, inv_rate=4, endpoint_log_n=14, endpoint_inv_rate=4,
        endpoint_rows=37, frozen_toy=False,
        a_rows=5681, a_data=5435, a_groups=36, a_sites=122,
        h_rows=7120, h_data=7018, h_groups=9, h_sites=50,
        published_round_values=1554, challenge_draws=361,
        pre_repair=dict(published_round_values=1519, challenge_draws=357),
    ),
    # [TINYLLAMA PORT 2026-10-17, privacy-gate lane] the TRAINED TinyLlama
    # T32 shape (`Shape::tinyllama_t32_trained`, trained-1b-review-r2
    # shape.rs:1287) at the pg_rot1 calibration.  Row counts, sites and the
    # round table are READ from the trained capture bundles (run.json shape
    # `slots`; A 1729 / 1487 data / 120 claims, H 1798 / 1698 / 50 claims,
    # per stage), and equal the native lane's counted ladder (A 1729 /
    # H 1798 at lc12).  Its parameter line prints the profile's OWN gate /
    # product / down shifts (protocol.rs `parameter_line`, round 2): 8 / 14 / 5.
    "tinyllama_t32_trained": dict(
        profile="hashline-zk-mr1/private-block-tinyllama-1.1b-t32-trained/1",
        run_profile="hashline-zk-mr1/private-run-tinyllama-1.1b-t32-trained-statement/1",
        tokens=32, width=2048, hidden=5632, q_heads=32, head_dim=64, kv_heads=4,
        log_cols=12, inv_rate=4, endpoint_log_n=12, endpoint_inv_rate=4,
        endpoint_rows=21, frozen_toy=False,
        a_rows=1729, a_data=1487, a_groups=36, a_sites=120,
        h_rows=1798, h_data=1698, h_groups=9, h_sites=50,
        published_round_values=1250, challenge_draws=317,
        shifts=(8, 14, 5),
    ),
}


def nn_block(s):
    """encoded columns of A and H — pcs.rs `enc_cols` = 2^log_cols * inv_rate"""
    return (1 << s["log_cols"]) * s["inv_rate"]


def nn_io(s):
    """encoded columns of an external endpoint or an internal boundary"""
    return (1 << s["endpoint_log_n"]) * s["endpoint_inv_rate"]


def io_data_rows(s):
    """endpoint_g.rs:147 / boundary.rs:180 — endpoint rows minus MASK_ROWS(5)"""
    return s["endpoint_rows"] - 5


def boundary_rows(s):
    """boundary.rs:180-182 — data + 2*sites + 2 with sites = 2"""
    return io_data_rows(s) + 2 * 2 + 2


def sum_mask_lengths(s, pre=False):
    """Sum over the 23 slots of the CFS mask length L_s = rounds_s*d_s + 2
    (`shape.rs:832`, `CfsMask::len`).  Since the pinned model gives
      published_round_values = sum rounds_s*(d_s+1)   and
      challenge_draws       = sum rounds_s,
    we have sum L_s = published - draws + 2*23.  CONTROL: this gives 583 at
    the toy (decision D9's own `2 x 583`) and 1,208 at 125M before the
    stage-20 repair (the run memo's own figure)."""
    d = s["pre_repair"] if pre else s
    return d["published_round_values"] - d["challenge_draws"] + 2 * N_SLOTS


# ------------------------------------------------------- the `fp()` draws
def block_draws(s, pre=False):
    """Every `fp()` draw one BLOCK makes.  Per hiding PCS commitment
    (rows - data)*n + rows*Q  (pads at zkp-core/src/pcs.rs:777 and
    hashline/src/pcs.rs:90), plus H's zero-sum re-draw 2(n-1)
    (protocol.rs:760-768) and the masking commitment's
    2*sum L_s + 46*256 + 4*1024 (zk.rs:434-457)."""
    n = 1 << s["log_cols"]
    a = (s["a_rows"] - s["a_data"]) * n + s["a_rows"] * OPENED
    h = (s["h_rows"] - s["h_data"]) * n + s["h_rows"] * OPENED
    zs = 2 * (n - 1)
    m = 2 * sum_mask_lengths(s, pre) + 46 * OPENED + 4 * MASK_VEC
    return dict(A=a, H=h, H_zero_sum=zs, M=m, total=a + h + zs + m)


def io_draws(s, rows):
    """an endpoint (endpoint_g.rs:231-235) or a boundary (boundary.rs:324-328):
    the reserved rows are filled with rng.fp(), then the PCS pads."""
    n = 1 << s["endpoint_log_n"]
    return (rows - io_data_rows(s)) * n + rows * OPENED


def run_draws(s, L, pre=False):
    b = block_draws(s, pre)["total"]
    bd = io_draws(s, boundary_rows(s))
    ep = io_draws(s, s["endpoint_rows"])
    return dict(per_block=b, per_boundary=bd, per_endpoint=ep,
                total=L * b + (L - 1) * bd + 2 * ep)


# --------------------------------------------------------------- the salts
def run_salts(s, L):
    """One salt per ENCODED column of every commitment (pcs.rs:778,
    zk.rs:513).  4L+1 commitments: 3 per stage (A, H, M), L-1 boundaries and
    2 external endpoints."""
    per_stage = 2 * nn_block(s) + MASK_DOM
    return L * per_stage + (L + 1) * nn_io(s)


def run_commitment_table(s, L):
    """(name, count, encoded columns, tree depth) for every commitment"""
    return [
        ("A", L, nn_block(s), nn_block(s).bit_length() - 1),
        ("H", L, nn_block(s), nn_block(s).bit_length() - 1),
        ("M", L, MASK_DOM, MASK_DOM.bit_length() - 1),
        ("internal boundary", L - 1, nn_io(s), nn_io(s).bit_length() - 1),
        ("external endpoint", 2, nn_io(s), nn_io(s).bit_length() - 1),
    ]


# -------------------------------------------------- tree occupancy (expected)
def tree_occupancy(nn, draws=OPENED):
    """256 indices drawn WITH REPLACEMENT (transcript.rs:136-148).
      distinct opened        = nn (1 - (1-1/nn)^256)
      leaf digests revealed  = nn (1 - (1-2/nn)^256)      (self or sibling hit)
      of them never opened   = nn [(1-1/nn)^256 - (1-2/nn)^256]
      nodes revealed at level l>=1 = (nn/2^l)(1 - (1-2^{l+1}/nn)^256)
    The last line is reported for levels 1..depth-1 and the root separately,
    which is the convention that reproduces the published table exactly."""
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
    total = leaves_revealed + internal + 1.0          # + the root
    return dict(nn=nn, depth=depth, distinct_opened=distinct,
                leaf_digests_revealed=leaves_revealed,
                of_them_never_opened=unopened_revealed,
                internal_nodes_revealed=internal, total_revealed=total,
                fraction_of_tree=total / (2 * nn - 1))


# --------------------------------------------------- transcript operations
def absorbs_per_run(s, L):
    """Every `Transcript::absorb` of a run, from the code.
    header (run.rs:315-320)                          6
    per stage:
      pb-run-stage, pb-run-block (run.rs:494-495)    2
      B root through absorb_root (run.rs:505)        3, on stages k+1<L
      A root through absorb_root (protocol.rs:666)   3
      M root, bare (protocol.rs:676)                 1
      H root through absorb_root (protocol.rs:774)   3
      per slot pb-slot + pb-scalar + pb-term         3 * 23
      sumcheck rounds (sumcheck.rs:109)              challenge_draws
      M opening: mask-q, mask-prox (zk.rs:584,:593)  2
      A opening: a_groups pcs-vec + 1 pcs-prox
      H opening: h_groups pcs-vec + 1 pcs-prox
      incoming opening: groups + 1 (1 at stage 0, 2 at a boundary)
      outgoing endpoint opening at stage L-1:        2
    """
    per_stage_common = (2 + 3 + 1 + 3 + 3 * N_SLOTS + s["challenge_draws"]
                        + 2 + (s["a_groups"] + 1) + (s["h_groups"] + 1))
    total = 6
    for k in range(L):
        t = per_stage_common
        if k + 1 < L:
            t += 3                       # the boundary root it commits
        t += 2 if k == 0 else 3          # the opening it closes
        if k + 1 == L:
            t += 2                       # the external output endpoint
        total += t
    return total


def opening_squeezes(claims, rows):
    """`zk_rhos` (pcs.rs:943-962) draws one Fp2 per CLAIM and then `rows` more
    for the proximity vector; `challenge_indices(256, nn)` (transcript.rs:136)
    takes 64 squeezes, four indices from each 32-byte squeeze."""
    return claims + rows + 64


def counted_squeezes_per_run(s, L):
    """The part of the squeeze count this script COUNTS from the code.  It
    LEAVES OUT the per-slot definition draws (tau, mu, nu, zeta, r_*) of
    argument.rs, which are 23 shape-dependent recipes this script does not
    model.  So this is a LOWER BOUND on the squeezes, and the memo says so."""
    per_stage = (3                                   # beta, gamma, alpha
                 + N_SLOTS                           # one CFS multiplier c
                 + s["challenge_draws"]              # sumcheck rounds
                 + (1 + (2 * N_SLOTS + 2) + 64)      # M: theta, prox rs, idx
                 + opening_squeezes(s["a_sites"], s["a_rows"])
                 + opening_squeezes(s["h_sites"], s["h_rows"]))
    total = 0
    for k in range(L):
        t = per_stage
        if k == 0:
            t += opening_squeezes(1, s["endpoint_rows"])
        else:
            t += opening_squeezes(2, boundary_rows(s))
        if k + 1 == L:
            t += opening_squeezes(1, s["endpoint_rows"])
        total += t
    return total


def tag_squeezes(L):
    """2 clone squeezes per position tag (run.rs:404-411), 2L tags."""
    return 2 * 2 * L


# ----------------------------------------------------------- length classes
def block_parameter_line(s):
    base = ("T{tokens}/d{width}/f{hidden}/H{q_heads}/KV{kv_heads}/dh{head_dim}"
            "/log_cols{log_cols}/inv_rate{inv_rate}/Q256/P1"
            "/sh-g{}-u0-h{}-z{}"
            "/two-private-endpoints/one-proof-one-transcript").format(
                *s.get("shifts", (SH_G, SH_H_PROD, SH_Z)), **s)
    if s["frozen_toy"]:
        return base
    return base + "/endpoint-log_n{}-rate{}-pad256-rows{}".format(
        s["endpoint_log_n"], s["endpoint_inv_rate"], s["endpoint_rows"])


def run_parameter_line(s, L):
    """run.rs:237-245"""
    rows = boundary_rows(s) if L > 1 else 0
    return ("{}/L{}/boundary-log_n{}-rate{}-pad256-rows{}-sites2"
            "/external-rows{}/one-run-one-transcript").format(
        block_parameter_line(s), L, s["endpoint_log_n"],
        s["endpoint_inv_rate"], rows, s["endpoint_rows"])


def unkeyed_input_lengths(s, L):
    """Every input to the UNKEYED BLAKE3 function a TAGGED run still makes.
    The four tagged roles (transcript, column, leaf, node) are keyed and are
    NOT here; `derive_key` is BLAKE3's third mode and is not here either."""
    out = {}
    out["calibration identity (private_block.rs:221-223)"] = 30
    out["generalised-endpoint spec digest (endpoint_g.rs:157-…)"] = 42 + 32 + 8 * 8 + 4
    out["internal-boundary spec digest (boundary.rs:210-229)"] = 43 + 32 + 9 * 8 + 4
    out["run public statement (run.rs:220-227)"] = 29 + 32 * L
    out["generator refill, key||counter (rng.rs:53-58)"] = 40
    # the two schedule digests and the block public digest are length-prefixed
    # concatenations far above 200 bytes; they are reported as lower bounds
    out["run schedule digest (run.rs:285-300), at least"] = 31 + 8 + len(run_parameter_line(s, L))
    out["block schedule digest (layout.rs:1288-1296), at least"] = 33 + 8
    out["block public-statement digest (private_block.rs:512-518), at least"] = 31
    return out


def transcript_function_lengths(s, L):
    """Every input to the run's KEYED TRANSCRIPT function."""
    out = {}
    out["squeeze (transcript.rs:101-111)"] = 47
    out["constructor, run profile (transcript.rs:40-45)"] = 12 + len(s["run_profile"])
    out["constructor, block profile (a standalone block of this shape)"] = 12 + len(s["profile"])
    fixed = [("run-shape", 56), ("expected-IO", 112), ("public-statement", 32),
             ("calibration", 32), ("schedule", 32), ("A", 32), ("H", 32),
             ("B", 32), ("M", 32), ("rows", 8), ("log-cols", 8),
             ("pb-run-stage", 8), ("pb-run-block", 32), ("pb-slot", 8),
             ("pb-scalar", 16)]
    for lab, d in fixed:
        out[f"absorb `{lab}` ({d} B of data)"] = 48 + len(lab) + d
    out["absorb `parameters`, the run's line"] = 48 + len("parameters") + len(run_parameter_line(s, L))
    out["absorb `parameters`, the block's line"] = 48 + len("parameters") + len(block_parameter_line(s))
    out["absorb `pcs-vec`/`pcs-prox`, block geometry"] = 48 + len("pcs-vec") + 16 * ((1 << s["log_cols"]) + OPENED)
    out["absorb `pcs-vec`/`pcs-prox`, endpoint geometry"] = 48 + len("pcs-vec") + 16 * ((1 << s["endpoint_log_n"]) + OPENED)
    out["absorb `mask-q`/`mask-prox`"] = 48 + len("mask-q") + 16 * 2 * MASK_VEC
    return out


# --------------------------------------------------------------- residuals
def lg(x):
    """log2 of a positive Fraction/int/float, exactly enough for a table"""
    if isinstance(x, Fraction):
        return math.log2(x.numerator) - math.log2(x.denominator)
    return math.log2(x)


def residuals(s, L, q_log2=128, pre=False, measured_squeezes=None):
    draws = run_draws(s, L, pre)["total"]
    salts = run_salts(s, L)
    q = Fraction(1 << q_log2)
    two256 = Fraction(1, 1 << 256)
    absorbs = absorbs_per_run(s, L)
    sq_lo = counted_squeezes_per_run(s, L) + tag_squeezes(L)
    if measured_squeezes is not None:
        # the gate's MEASURED live squeeze counter, plus the clone squeezes of
        # the position tags, which the live counter does not see
        tf_bound = absorbs + measured_squeezes + tag_squeezes(L)
    else:
        # the honest transcript-function query BOUND: the counted part, plus a
        # generous allowance of 1,024 per-slot definition draws per stage
        tf_bound = absorbs + sq_lo + 1024 * L
    terms = {}
    terms["sampler bias (D9): draws x 2^-96"] = Fraction(draws, 1 << 96)
    terms["input-dependent refusal (S-4): L x 768 / |Fp2|"] = Fraction(L * 768, P2)
    terms["salt guessing: q x N_leaf x 2^-256"] = q * salts * two256
    terms["leaf-input collision: C(N_leaf,2) x 2^-256"] = Fraction(salts * (salts - 1) // 2) * two256
    terms["transcript pre-query: q x A x 2^-256"] = q * tf_bound * two256
    terms["transcript-input collision: C(A,2) x 2^-256"] = Fraction(tf_bound * (tf_bound - 1) // 2) * two256
    terms["generator, in-model alternative: 6q x 2^-256"] = 6 * q * two256
    terms["key collision: the 4 tag keys against 3 generator keys"] = Fraction(4 * 3) * two256
    total = sum(terms.values())
    liveness = Fraction(3 * L + 1, P)
    return dict(draws=draws, salts=salts, absorbs=absorbs,
                counted_squeezes=sq_lo, transcript_query_bound=tf_bound,
                terms={k: lg(v) for k, v in terms.items()},
                total_log2=lg(total),
                liveness_log2=lg(liveness))


# =========================================================== the controls
def controls():
    out = {}
    toy = SHAPES["toy"]
    # C1 the toy's salts and draws
    toy_salts = 4 * nn_block(toy) + MASK_DOM
    d = block_draws(toy)
    toy_draws = d["total"] + 2 * io_draws(toy, toy["endpoint_rows"])
    out["C1 toy salts drawn"] = dict(got=toy_salts, want=12288, ok=toy_salts == 12288)
    out["C1 toy sum L_s"] = dict(got=sum_mask_lengths(toy), want=583,
                                 ok=sum_mask_lengths(toy) == 583)
    out["C1 toy fp() draws"] = dict(got=toy_draws, want=327052, ok=toy_draws == 327052,
                                    parts=d, endpoints=2 * io_draws(toy, toy["endpoint_rows"]))
    out["C1 toy sampler residual log2"] = dict(got=round(lg(Fraction(toy_draws, 1 << 96)), 2), want=-77.7)
    # C2 the toy's tree table
    t = tree_occupancy(2048)
    out["C2 toy 2048-leaf tree"] = dict(
        got=[round(t["distinct_opened"], 1), round(t["leaf_digests_revealed"], 1),
             round(t["of_them_never_opened"], 1), round(t["internal_nodes_revealed"], 1),
             round(t["total_revealed"], 1), round(100 * t["fraction_of_tree"], 1)],
        want=[240.7, 453.2, 212.5, 1200.6, 1654.8, 40.4])
    tm = tree_occupancy(4096)
    out["C2 toy 4096-leaf M tree"] = dict(
        got=[round(tm["distinct_opened"], 1), round(tm["leaf_digests_revealed"], 1),
             round(tm["of_them_never_opened"], 1), round(tm["internal_nodes_revealed"], 1),
             round(tm["total_revealed"], 1), round(100 * tm["fraction_of_tree"], 1)],
        want=[248.2, 481.4, 233.2, 1653.8, 2136.2, 26.1])
    # C3 the run memo's draw counts, PRE-REPAIR (what it counted)
    g = SHAPES["rung_g"]
    m = SHAPES["m125"]
    rg = run_draws(g, 3, pre=True)
    m12 = run_draws(m, 12, pre=True)
    out["C3 rung-G per block / boundary / endpoint (pre-repair)"] = dict(
        got=[rg["per_block"], rg["per_boundary"], rg["per_endpoint"]],
        want=[686990, 8704, 7424])
    out["C3 rung-G run L=3 total (pre-repair)"] = dict(got=rg["total"], want=2093226)
    out["C3 125M per block / boundary / endpoint (pre-repair)"] = dict(
        got=[m12["per_block"], m12["per_boundary"], m12["per_endpoint"]],
        want=[9029742, 108032, 91392])
    out["C3 125M run L=12 total (pre-repair)"] = dict(got=m12["total"], want=109728040)
    out["C3 125M sum L_s (pre-repair)"] = dict(got=sum_mask_lengths(m, pre=True), want=1208)
    out["C3 125M residual log2 (pre-repair)"] = dict(
        got=round(lg(Fraction(m12["total"], 1 << 96)), 2), want=-69.3)
    # C4 the salts of a twelve-block 125M run
    out["C4 125M L=12 salts drawn"] = dict(got=run_salts(m, 12), want=2473984)
    # C5 the opened columns of a three-block run
    out["C5 three-block run opened columns"] = dict(got=256 * (4 * 3 + 1), want=3328)
    # C6 the refusal figures of ruling S-4
    out["C6 refusal per block log2"] = dict(got=round(lg(Fraction(768, P2)), 1), want=-118.4)
    out["C6 refusal 125M L=12 log2"] = dict(got=round(lg(Fraction(12 * 768, P2)), 1), want=-114.8)
    # C7 the gate's MEASURED transcript figures on four three-block bundles
    # (`/home/victor/wt-zk60-jointview/results/zk60_native_run_gate_*/`,
    #  field `stage2_transcript_replay`).  The model of the squeeze counter is
    #  final_counter = challenges_checked + 64 index squeezes per opening.
    for name, ch, ctr, L in [("run-e-tame-tagged (rung-G, pre-repair)", 6086, 6918, 3),
                             ("run-g-dense-s20 (rung-G)", 6092, 6924, 3),
                             ("run-h-zero-s20 (rung-G, all-zero)", 6092, 6924, 3),
                             ("run-i-dense-k4 (rung-K4)", 6854, 7686, 3),
                             ("run-j-zero-k4 (rung-K4, all-zero)", 6854, 7686, 3)]:
        model = ch + 64 * (4 * L + 1)
        out[f"C7 {name}"] = dict(measured_final_counter=ctr, model=model, ok=model == ctr)
    out["C7 dense and all-zero give the same transcript figures"] = dict(
        rung_g=[6092, 6924], rung_k4=[6854, 7686],
        note="MEASURED by the gate; the number of transcript operations does not move with the hidden input")
    return out


# ============================================================ the new counts
MEASURED_SQUEEZES = {("rung_g", 3): 6924, ("rung_k4", 3): 7686}


def configuration(name, L):
    s = SHAPES[name]
    meas = MEASURED_SQUEEZES.get((name, L))
    cfg = dict(shape=name, L=L, profile=s["profile"], run_profile=s["run_profile"])
    cfg["commitments"] = [dict(kind=k, count=c, encoded_columns=nn, depth=d)
                          for k, c, nn, d in run_commitment_table(s, L)]
    cfg["commitment_total"] = 4 * L + 1
    cfg["openings"] = 4 * L + 1
    cfg["roots_published"] = dict(block_roots=3 * L, boundary_roots=L - 1,
                                  external_roots_in_the_statement=2,
                                  total=4 * L + 1)
    cfg["salts_drawn"] = run_salts(s, L)
    cfg["salt_slots_published"] = OPENED * (4 * L + 1)
    trees = {}
    tot_leaves = tot_distinct = tot_unopened_revealed = tot_revealed = 0.0
    for k, c, nn, d in run_commitment_table(s, L):
        t = tree_occupancy(nn)
        trees[k] = dict(count=c, **{kk: (round(vv, 2) if isinstance(vv, float) else vv)
                                    for kk, vv in t.items()})
        tot_leaves += c * nn
        tot_distinct += c * t["distinct_opened"]
        tot_unopened_revealed += c * t["of_them_never_opened"]
        tot_revealed += c * t["total_revealed"]
    cfg["trees"] = trees
    cfg["leaves_total"] = int(tot_leaves)
    cfg["distinct_opened_expected"] = round(tot_distinct, 1)
    cfg["unopened_leaves_expected"] = round(tot_leaves - tot_distinct, 1)
    cfg["unopened_leaf_digests_published_expected"] = round(tot_unopened_revealed, 1)
    cfg["nodes_revealed_expected"] = round(tot_revealed, 1)
    cfg["path_digest_slots"] = sum(c * OPENED * d for _, c, _, d in run_commitment_table(s, L))
    # the honest prover's queries, per keyed function
    cfg["prover_queries"] = dict(
        column_digest=run_salts(s, L),
        salted_leaf=run_salts(s, L),
        merkle_node=run_salts(s, L) - (4 * L + 1),
        transcript_absorbs=absorbs_per_run(s, L),
        transcript_squeezes_counted_here=counted_squeezes_per_run(s, L),
        transcript_squeezes_measured_by_the_gate=meas,
        per_slot_definition_draws_implied=(None if meas is None
                                           else meas - counted_squeezes_per_run(s, L)),
        transcript_squeezes_from_discarded_clones=tag_squeezes(L),
    )
    cfg["position_tags"] = dict(fields_on_the_wire=2 * L, distinct_values=L + 1,
                                note="trailer of segment k == header tag of segment k+1")
    cfg["framing_bytes"] = 120 * L
    cfg["draws_at_8c5922b"] = run_draws(s, L)
    if "pre_repair" in s:
        cfg["draws_as_the_run_memo_counted"] = run_draws(s, L, pre=True)
    cfg["unkeyed_input_lengths"] = unkeyed_input_lengths(s, L)
    cfg["transcript_function_input_lengths"] = transcript_function_lengths(s, L)
    forty = [k for k, v in cfg["unkeyed_input_lengths"].items()
             if v == 40 and "refill" not in k]
    cfg["another_unkeyed_input_of_40_bytes"] = forty
    fortyseven = [k for k, v in cfg["transcript_function_input_lengths"].items()
                  if v == 47 and "squeeze" not in k]
    cfg["another_transcript_input_of_47_bytes"] = fortyseven
    cfg["residuals_q2^128"] = residuals(s, L, measured_squeezes=meas)
    cfg["residuals_q2^80"] = residuals(s, L, q_log2=80, measured_squeezes=meas)
    return cfg


def many_runs(s, L, k_log2=20):
    """The union bound over k independent runs.  The sampler term is linear;
    the leaf-collision term is quadratic in k."""
    k = 1 << k_log2
    draws = run_draws(s, L)["total"]
    salts = run_salts(s, L)
    two256 = Fraction(1, 1 << 256)
    sampler = Fraction(k * draws, 1 << 96)
    refusal = Fraction(k * L * 768, P2)
    coll = Fraction((k * salts) * (k * salts - 1) // 2) * two256
    q = Fraction(1 << 128)
    saltguess = q * k * salts * two256
    total = sampler + refusal + coll + saltguess
    return dict(k=k, sampler=lg(sampler), refusal=lg(refusal),
                leaf_collision=lg(coll), salt_guessing=lg(saltguess),
                total=lg(total))


def tinyllama_controls(tl):
    """[TINYLLAMA PORT] the model against the trained L = 2 capture: the run
    parameter line, character for character, and the gate's MEASURED replay
    figures (`results/zk60_gate_tinyllama_20261017/l2/tl-dense-a.json`,
    stage2: 9,002 challenges, final counter 9,578; the zero bundle the same)
    against final_counter = challenges + 64 (4L + 1)."""
    import os
    out = {}
    run_json = "/home/victor/zk60-artifacts/tinyllama-trained-capture-dense-l2/run.json"
    if os.path.exists(run_json):
        with open(run_json) as fh:
            declared = json.load(fh)["parameter_line"]
        mine = run_parameter_line(tl, 2)
        out["TL-C1 run parameter line == the bundle's"] = dict(
            got=mine, want=declared, ok=mine == declared)
    model = 9002 + 64 * (4 * 2 + 1)
    out["TL-C2 squeeze counter model"] = dict(
        measured_final_counter=9578, model=model, ok=model == 9578)
    out["TL-C3 sum L_s == the prediction's 979"] = dict(
        got=sum_mask_lengths(tl), want=979, ok=sum_mask_lengths(tl) == 979)
    return out


def main():
    out = {}
    out["controls"] = controls()
    out["configurations"] = {
        "rung_g_L3": configuration("rung_g", 3),
        "rung_k4_L3": configuration("rung_k4", 3),
        "m125_L12": configuration("m125", 12),
    }
    out["many_runs_10^6"] = {
        "rung_g_L3": many_runs(SHAPES["rung_g"], 3),
        "m125_L12": many_runs(SHAPES["m125"], 12),
    }
    # [TINYLLAMA PORT 2026-10-17] the trained TinyLlama shape: the two-block
    # run the gate read, the 22-block stack the native lane proved, and the
    # same many-runs bound; and two controls against the trained bundle
    tl = SHAPES["tinyllama_t32_trained"]
    out["configurations"]["tinyllama_t32_trained_L2"] = configuration("tinyllama_t32_trained", 2)
    out["configurations"]["tinyllama_t32_trained_L22"] = configuration("tinyllama_t32_trained", 22)
    out["many_runs_10^6"]["tinyllama_t32_trained_L22"] = many_runs(tl, 22)
    out["tinyllama_controls"] = tinyllama_controls(tl)
    print(json.dumps(out, indent=1, sort_keys=False))


if __name__ == "__main__":
    main()
