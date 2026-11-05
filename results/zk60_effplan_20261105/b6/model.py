"""B6 design study (recursive openings, FlashProve fold-and-hop): the scratch model.

Run:  python3 -I results/zk60_effplan_20261105/b6/model.py > results/zk60_effplan_20261105/b6/model_output.json

Standard library only; no file is read. Everything printed is labelled:
  CODE      a count or formula read off the sources (file:line in the comments);
  MEASURED  quoted from a log (path in the comments);
  INFERRED  derived from a MEASURED total and CODE formulas (a residual);
  MODEL     derived by a stated rule;
  ESTIMATE  a judgement range.

Sections:
  1. the census of today's W16R2 8B T128 D55 receipt (818,728,672 B), reproduced from the encoder's formulas;
  2. the receipt under B6 (variants B6a and B6b), with the scaling rule;
  3. per-round soundness errors and the zone sum (units of 2^-110, as in the Lean bounds);
  4. the time model (ranges);
  5. a toy-field joint-view rank test of the B6a construction, with controls that must fail.
"""
import json
import math
import random

OUT = {}

# ----------------------------------------------------------------------------------------------------
# 1. Today's receipt, from the encoder's own formulas
# ----------------------------------------------------------------------------------------------------
# CODE: ops/zkp-mvp/gpu-metal/hashline/src/private_block/wire.rs:96-117 (Dim, opening_len)
#   opening_len(groups, rows) = (groups + 1)(n + Q)16 + Q(8 + 8 rows + 32 + 32 path)
# CODE: shape.rs:302 (log_cols 14), shape.rs:320 (W16R2_OPENED_COLS = 280); rate 1/2 (D59) so path = 15.
N_MSG = 1 << 14
Q = 280
PATH = 15
VEC = N_MSG + Q                      # one clear vector: n message entries then Q pad entries, in Fp2 (16 B)
# CODE: results/zk60_effplan_20261105/census.log: A rows 2501, H rows 2602 (data + 2 per site + 2)
A_ROWS, H_ROWS = 2501, 2602
# CODE: shape.rs:2808-2840 (a_groups = tzc + 27, h_groups = 9); the values 36 and 9 reproduce the logged A/H bytes below.
A_GROUPS, H_GROUPS = 36, 9
# CODE: zk.rs:391-393, wire.rs:23-32: M opens 2 vectors of 2 << 9 Fp2 words, 256 columns, tree depth 12;
#       shape.rs m_rows = 2 * 23 + 4 = 50.
M_VEC, M_CHECKS, M_PATH, M_ROWS = 2 << 9, 256, 12, 50
# CODE: run.rs:743 (declared_rows = endpoint_rows + 1), boundary.rs:186 (data + 2 sites + 2), run.rs:50 (2 sites)
B_ROWS, B_SITES = 38, 2
# INFERRED: endpoint rows 37, from the logged endpoint opening of 761,728 B (Q 280) and 744,768 B (Q 260)
E_ROWS = 37
L = 32
MEASURED_D55_TOTAL = 818_728_672     # MEASURED: results/zk60_effplan_20261105/a12merge_d55.log:233
MEASURED_BLOCK = dict(total=26_046_904, A=15_612_928, H=8_640_320, M=243_712, endpoint=761_728)
# MEASURED: results/zk60_w16r2_q280_20261103/logs/targeted_cpu.log:1539 (the block codec, encoded_len = receipt_bytes().total)


def opening_len(groups, rows, n=N_MSG, q=Q, path=PATH):
    return (groups + 1) * (n + q) * 16 + q * (8 + rows * 8 + 32 + path * 32)


def opening_parts(groups, rows, n=N_MSG, q=Q, path=PATH):
    return dict(vectors=(groups + 1) * (n + q) * 16, column_data=q * rows * 8,
                paths=q * path * 32, salts=q * 32, indices=q * 8)


A_OPEN = opening_len(A_GROUPS, A_ROWS)
H_OPEN = opening_len(H_GROUPS, H_ROWS)
M_OPEN = 2 * M_VEC * 16 + M_CHECKS * (8 + M_ROWS * 8 + 32 + M_PATH * 32)
B_OPEN = opening_len(B_SITES, B_ROWS)
E_OPEN = opening_len(1, E_ROWS)
assert A_OPEN == MEASURED_BLOCK["A"] and H_OPEN == MEASURED_BLOCK["H"]
assert M_OPEN == MEASURED_BLOCK["M"] and E_OPEN == MEASURED_BLOCK["endpoint"]

# CODE: run_fork_wire.rs:82-99 (head_len, fork_len, tail_len)
HEAD = 8 + 32 + 8 + 32 * (L - 1) + 32
FORK_FIXED = 8 + 32 + 8 + 8 + 32 + 3 * 32 + 32
TAIL_FIXED = 8 + 32 + 8 + 32 + 32
known = HEAD + L * (FORK_FIXED + M_OPEN + A_OPEN + H_OPEN) + TAIL_FIXED + (L - 1) * B_OPEN + 2 * E_OPEN
SLOTS = (MEASURED_D55_TOTAL - known) // L       # INFERRED: the slot proofs of one fork frame
assert known + L * SLOTS == MEASURED_D55_TOTAL and SLOTS % 16 == 0

pa, ph = opening_parts(A_GROUPS, A_ROWS), opening_parts(H_GROUPS, H_ROWS)
pb, pe = opening_parts(B_SITES, B_ROWS), opening_parts(1, E_ROWS)
pm = dict(vectors=2 * M_VEC * 16, column_data=M_CHECKS * M_ROWS * 8, paths=M_CHECKS * M_PATH * 32,
          salts=M_CHECKS * 32, indices=M_CHECKS * 8)
kinds = {}
for k in ("vectors", "column_data", "paths", "salts", "indices"):
    kinds[k] = L * (pa[k] + ph[k] + pm[k]) + (L - 1) * pb[k] + 2 * pe[k]
kinds["slots_and_frames"] = L * (SLOTS + FORK_FIXED) + HEAD + TAIL_FIXED
assert sum(kinds.values()) == MEASURED_D55_TOTAL
OUT["census_today"] = {
    "label": "CODE formulas + MEASURED totals; slots INFERRED as the residual",
    "per_block_fork_frame": dict(A_opening=A_OPEN, A_parts=pa, H_opening=H_OPEN, H_parts=ph, M_opening=M_OPEN,
                                 M_parts=pm, slot_proofs=SLOTS, fixed=FORK_FIXED,
                                 total=FORK_FIXED + SLOTS + M_OPEN + A_OPEN + H_OPEN),
    "join_tail": dict(boundary_opening_each=B_OPEN, boundary_parts=pb, boundaries=(L - 1) * B_OPEN,
                      endpoint_opening_each=E_OPEN, endpoints=2 * E_OPEN, fixed=TAIL_FIXED,
                      total=TAIL_FIXED + (L - 1) * B_OPEN + 2 * E_OPEN),
    "head": HEAD,
    "total": MEASURED_D55_TOTAL,
    "by_kind": kinds,
    "by_kind_share": {k: round(v / MEASURED_D55_TOTAL, 4) for k, v in kinds.items()},
    "clear_vectors_per_block": A_GROUPS + 1 + H_GROUPS + 1,
}

# ----------------------------------------------------------------------------------------------------
# 2. The receipt under B6
# ----------------------------------------------------------------------------------------------------
P_GOLD = (1 << 64) - (1 << 32) + 1
LOG_P2 = 2 * math.log2(P_GOLD)
PARITY_BITS = 113.93     # today's regular-opening column term (Q 280, rate 1/2, delta/2; D59 / F2 ruling)


def column_term_bits(N, K, t):
    """-log2 of (1 - (e + 1)/N)^t, e = floor((N - K)/2): the delta/2 column test (SoundColumnTest)."""
    e = (N - K) // 2
    if e < 0:
        return 0.0
    return -t * math.log2(1 - (e + 1) / N)


def t_for(N, msg, bits=PARITY_BITS):
    """The least t with q_pad = t (K = msg + t) whose column term reaches `bits`."""
    for t in range(1, N):
        if column_term_bits(N, msg + t, t) >= bits:
            return t
    return None


assert t_for(1 << 15, 1 << 14) == 280  # reproduces W16R2's Q at T128 under the parity target


def merkle_auth_nodes(t, depth):
    """Expected authentication nodes of a batched (deduplicated) opening of t uniform leaves of 2^depth."""
    def distinct(level):
        width = 1 << (depth - level)
        return width * (1 - (1 - 1 / width) ** t)
    return sum(2 * distinct(i + 1) - distinct(i) for i in range(depth))


def stage_bytes(t, log_n, entry_bytes, trees=1, multiproof=False):
    """One list of t positions read on `trees` Merkle trees (one index per position, one salt and path per tree)."""
    if multiproof:
        paths = trees * merkle_auth_nodes(t, log_n) * 32
    else:
        paths = t * trees * log_n * 32
    return int(t * (8 + trees * 32 + entry_bytes) + paths)


def tower(m0, rows0_fp2, c0, plan, multiproof=False, base_rows=2):
    """A FOLD/CS tower on a committed Fp2 matrix of rows0 rows, message 2^m0, rate 2^-c0 (stage 2 of B6a, or
    stage 2 onwards of B6b). `plan`: [(k, c), ...] for every later stage: 2^k rows (k = 0 for the last), rate
    2^-c. Masks ride in each stage's tree (FlashProve iopp.h:47-56): +2 Fp2 rows (fresh mask, masking oracle).
    BASE sends M' and R' for the main row and the fresh mask (FlashProve base_case.h:9-14)."""
    out, total = [], 0
    stages, m = [(m0, rows0_fp2, c0)], m0
    for k_next, c_next in plan:            # the CS after stage j puts the folded row into 2^k rows (+ a rest row)
        m -= k_next
        stages.append((m, (1 << k_next) + (1 if k_next else 0), c_next))
    for idx, (m, rows, c) in enumerate(stages):
        n_code = m + c
        t = t_for(1 << n_code, 1 << m)
        if t is None:
            return None, None          # the pads leave no room at this rate: plan rejected
        b = stage_bytes(t, n_code, (rows + 2) * 16, multiproof=multiproof)
        k_fold = math.ceil(math.log2(rows)) if rows > 1 else 0
        fold_msgs = (2 * k_fold + 1) * 16
        out.append(dict(rows_fp2=rows, log_msg=m, log_N=n_code, t=t, opened_bytes=b, fold_rounds=k_fold,
                        fold_msg_bytes=fold_msgs, column_term_bits=round(column_term_bits(1 << n_code, (1 << m) + t, t), 2)))
        total += b + fold_msgs + 32  # + the stage's root
        if idx == len(stages) - 1:
            base = base_rows * ((1 << m) + t) * 16 + 16
            out.append(dict(base_sent_bytes=base))
            total += base
    return total, out


def best_tower(m0, rows0, c0, multiproof=False):
    best = None
    for k2 in range(2, 7):
        for c2 in (2, 3, 4, 5):
            for k3 in range(0, 6):
                for c3 in (3, 4, 5, 6, 7):
                    plans = [[(k2, c2), (0, c3)]] if k3 == 0 else [[(k2, c2), (k3, c3), (0, c3)]]
                    for plan in plans:
                        if m0 - sum(k for k, _ in plan) < 4:
                            continue
                        tb, det = tower(m0, rows0, c0, plan, multiproof)
                        if tb is not None and (best is None or tb < best[0]):
                            best = (tb, plan, det)
    return best


def b6a(a_rows=A_ROWS, h_rows=H_ROWS, a_groups=A_GROUPS, h_groups=H_GROUPS, c_w=3, multiproof=False, label=""):
    """B6a: each opening's clear vectors are committed (code-switched, Orion-style) into one small matrix W per
    block instead of being sent; W's claims (the old <v, c> checks and the column checks as generator claims)
    are proved by a FOLD/CS/BASE tower. Stage 1 (A, H, Q = 280 columns, D59's independent weights) is unchanged."""
    vecs = a_groups + 1 + h_groups + 1
    w_rows = vecs + 1                                  # + one row for every vector's 280 pad entries
    stage1 = Q * (8 + a_rows * 8 + 32 + PATH * 32) + Q * (8 + h_rows * 8 + 32 + PATH * 32)
    tb, plan, det = best_tower(14, w_rows, c_w, multiproof)
    per_block = stage1 + tb + 32 + M_OPEN + SLOTS + FORK_FIXED
    # the join: the boundaries' and endpoints' vectors switched into one W_join; their columns as today
    j_vecs = (L - 1) * (B_SITES + 1) + 2 * 2
    jb, jplan, jdet = best_tower(14, j_vecs + 1, c_w, multiproof)
    join = (L - 1) * Q * (8 + B_ROWS * 8 + 32 + PATH * 32) + 2 * Q * (8 + E_ROWS * 8 + 32 + PATH * 32) + jb + 32 + TAIL_FIXED
    total = HEAD + L * per_block + join
    return dict(label=label, per_block=per_block, stage1_columns=stage1, tower_bytes=tb, tower_plan=plan,
                tower=det, join=join, join_tower=jb, total=total, vs_today=round(total / MEASURED_D55_TOTAL, 4))


def b6b(ell, a_data=2279, h_data=2514, multiproof=False, label=""):
    """B6b: B6a plus wide rows (2^ell message entries), compact site masks (sub-row slices; possible only once
    no clear vector is sent), A and H read at ONE list of positions and folded together (a stage-1 FOLD), and
    every boundary in ONE commitment opened with both endpoints at the join."""
    rows_a = math.ceil(a_data * N_MSG / (1 << ell)) + 1    # + one row of compact mask slices (ESTIMATE)
    rows_h = math.ceil(h_data * N_MSG / (1 << ell)) + 1
    t1 = t_for(1 << (ell + 1), 1 << ell)
    s1 = stage_bytes(t1, ell + 1, (rows_a + rows_h) * 8, trees=2, multiproof=multiproof)
    k1 = math.ceil(math.log2(rows_a + rows_h))
    fold1 = (2 * k1 + 1) * 16
    best = None
    for k2 in range(3, 9):
        for c2 in (2, 3, 4, 5):
            for k3 in range(0, 7):
                for c3 in (3, 4, 5, 6, 7):
                    plan_rest = [(0, c3)] if k3 == 0 else [(k3, c3), (0, c3)]
                    if ell - k2 - sum(k for k, _ in plan_rest) < 4:
                        continue
                    tb, det = tower(ell - k2, (1 << k2) + 1, c2, plan_rest, multiproof)
                    if tb is not None and (best is None or tb < best[0]):
                        best = (tb, [(k2, c2)] + plan_rest, det)
    tb, plan, det = best
    per_block = s1 + fold1 + tb + M_OPEN + SLOTS + FORK_FIXED + 32
    rows_b = math.ceil((L - 1) * (1 << 19) / (1 << ell)) + 1
    rows_e = math.ceil((1 << 19) / (1 << ell)) + 1
    tj = t_for(1 << (ell + 1), 1 << ell)
    sj = stage_bytes(tj, ell + 1, (rows_b + 2 * rows_e) * 8, trees=3, multiproof=multiproof)
    kj = math.ceil(math.log2(rows_b + 2 * rows_e))
    join = sj + (2 * kj + 1) * 16 + tb + TAIL_FIXED
    head = 8 + 32 + 8 + 32 + 32                         # one boundary root instead of 31
    total = head + L * per_block + join
    return dict(label=label, ell=ell, t1=t1, stage1_rows=rows_a + rows_h, stage1_bytes=s1, stage1_fold_rounds=k1,
                tower_bytes=tb, tower_plan=plan, tower=det, M_opening=M_OPEN, per_block=per_block, join=join,
                join_rows=rows_b + 2 * rows_e, join_fold_rounds=kj, total=total,
                vs_today=round(total / MEASURED_D55_TOTAL, 4))


variants = {
    "B6a_W16R2": b6a(label="B6a on W16R2 rows (2,501 / 2,602; 36 / 9 groups)"),
    "B6a_W16R3": b6a(2397, 2462, 34, 7, label="B6a on Sol's B1-B3 rows (2,397 / 2,462; 34 / 7 groups)"),
    "B6a_W16R3_multiproof": b6a(2397, 2462, 34, 7, multiproof=True, label="the same, deduplicated Merkle paths"),
}
for ell in (16, 18, 20, 22):
    variants[f"B6b_ell{ell}"] = b6b(ell, 2135, 2354, label=f"B6b, rows of 2^{ell}, B1-B3 data rows")
    variants[f"B6b_ell{ell}_multiproof"] = b6b(ell, 2135, 2354, multiproof=True, label=f"B6b, rows of 2^{ell}, deduplicated paths")
OUT["receipt_B6"] = {
    "label": "MODEL (byte counts from the stated layouts; t from the delta/2 column test at today's 2^-113.93 per list)",
    "scaling_rule": ("receipt = 32 x [t1 x (stage-1 rows x 8 B + per-tree 40 B + per-tree path 32 B x depth) + tower + M + slots]"
                     " + join; the stage-1 column data is t1 x 8 B x (committed entries / 2^ell); paths grow with ell"),
    "variants": variants,
}

# ----------------------------------------------------------------------------------------------------
# 3. Per-round soundness errors and the zone sum, in units of 2^-110 (the Lean bounds' unit)
# ----------------------------------------------------------------------------------------------------
U110 = 2.0 ** -110


def bits(x):
    return round(-math.log2(x), 2)


def fold_round_err(log_n):          # mca_rsCode (Code/Half.lean:132-137): at most N bad values on a line, delta/2
    return 2.0 ** log_n / 2.0 ** LOG_P2


today = dict(logup=136 * U110, M=2.0 ** -106, slots=2.0 ** -111, openings_4=4 * 2.0 ** -111)
zone_today = sum(today.values())


def zone_b6a(v):
    # stage 1 unchanged: A, H, B_{k-1}, B_k keep their prox field term and column term (4 x 2^-111);
    # the block's tower and the join's tower each add their fold rounds, positions and batching
    def tower_err(det):
        e = 0.0
        for st in det:
            if "log_N" in st:
                e += st["fold_rounds"] * (fold_round_err(st["log_N"]) + 2 / 2.0 ** LOG_P2)
                e += 2.0 ** -st["column_term_bits"]
                e += 3 / 2.0 ** LOG_P2               # BAT, the hiding combination, BASE's lambda
        return e
    return zone_today + tower_err(v["tower"]) + tower_err(best_tower(14, (L - 1) * 3 + 5, 3)[2])


def zone_b6b(v):
    ell = v["ell"]
    e = zone_today - 4 * 2.0 ** -111                  # the four regular openings are replaced
    s1 = v["stage1_fold_rounds"] * (fold_round_err(ell + 1) + 2 / 2.0 ** LOG_P2)
    s1 += 2.0 ** -column_term_bits(1 << (ell + 1), (1 << ell) + v["t1"], v["t1"])
    sj = v["join_fold_rounds"] * fold_round_err(ell + 1) + 2.0 ** -column_term_bits(1 << (ell + 1), (1 << ell) + v["t1"], v["t1"])
    tw = 0.0
    for st in v["tower"]:
        if "log_N" in st:
            tw += st["fold_rounds"] * fold_round_err(st["log_N"]) + 2.0 ** -st["column_term_bits"] + 3 / 2.0 ** LOG_P2
    return e + s1 + sj + 2 * tw


rounds = {
    "today": {"LogUp alpha (the rate)": 102.93, "LogUp beta,gamma": 110.04, "M opening (assumed)": 106.0,
              "regular opening: field N/p^2": 113.0, "regular opening: column term": 113.93,
              "sumcheck round d=5": 125.68},
}
b6a_v = variants["B6a_W16R3"]
rounds["B6a_new"] = {
    "W tower BAT (product coefficients, 2/p^2)": bits(2 / 2.0 ** LOG_P2),
    "FOLD hiding combination eps (1/p^2)": bits(1 / 2.0 ** LOG_P2),
    "FOLD sumcheck round, degree 2 (2/p^2)": bits(2 / 2.0 ** LOG_P2),
    "FOLD line, mutual correlated agreement N_W/p^2 (W at rate 1/8, N = 2^17)": bits(fold_round_err(b6a_v["tower"][0]["log_N"])),
    "CS / BASE positions, (1 - (e+1)/N)^t": min(st["column_term_bits"] for st in b6a_v["tower"] if "log_N" in st),
    "BASE lambda (1/p^2)": bits(1 / 2.0 ** LOG_P2),
}
for ell in (18, 20):
    rounds[f"B6b_ell{ell}_new"] = {
        f"stage-1 FOLD line N/p^2 (N = 2^{ell + 1})": bits(fold_round_err(ell + 1)),
        "stage-1 column term at t1": round(column_term_bits(1 << (ell + 1), (1 << ell) + variants[f'B6b_ell{ell}']['t1'],
                                                            variants[f'B6b_ell{ell}']['t1']), 2),
    }
zones = {"today (Lean zone_budget_le: 155/2^110)": zone_today / U110,
         "B6a (W16R3 rows)": zone_b6a(b6a_v) / U110}
for ell in (18, 20):
    zones[f"B6b ell {ell}"] = zone_b6b(variants[f"B6b_ell{ell}"]) / U110
OUT["soundness"] = {
    "label": "MODEL; today's figures from ZK60_LEAN_L3_FINDINGS_20261104.md Part 7 V2 and Part 9 W2",
    "per_round_bits": rounds,
    "rate_bits": {"today": 102.93, "B6a": 102.93, "B6b ell 18": 102.93, "B6b ell 20": 102.93},
    "zone_units_of_2^-110": {k: round(v, 1) for k, v in zones.items()},
    "zone_bits": {k: round(110 - math.log2(v), 2) for k, v in zones.items()},
}

# ----------------------------------------------------------------------------------------------------
# 4. The time model (ranges; every input labelled)
# ----------------------------------------------------------------------------------------------------
TIME = {
    "inputs": {
        "forks_phase_s_N6": ("MEASURED", 3.76, "results/zk60_effplan_20261105/README.md:404 (A8 A/B)"),
        "gpu_busy_s_N6": ("MEASURED/INFERRED", 2.75, "README.md:345 (the GPU-busy bound)"),
        "uncontended_block_gpu_ms": ("MEASURED", {"sumcheck": 68, "commitments": 31}, "README.md:175 (A7)"),
        "A1_openings_A_H_M_ms": ("MEASURED", 44, "README.md:45 (A1, serial block)"),
        "A8_store_fold_ms_6thread_pool": ("MEASURED", {"A": 10.1, "H": 19.3}, "README.md:367"),
        "absorb_of_clear_vectors_MB": ("CODE", round(47 * VEC * 16 / 1e6, 1), "pcs.rs:1049-1052; 9.9 MB for A in README.md:427"),
        "verify_s_32_blocks_6_threads": ("MEASURED", [2.31, 2.84], "a12merge_d55_ab.log (diagonal synthetic weights)"),
        "verify_s_32_blocks_D12a_one_block_at_a_time": ("MEASURED", 4.53, "a12merge_d55_ab.log"),
    },
}
# per-block deltas, ms: (GPU lo, GPU hi, host lo, host hi)
TIME["B6a_per_block_ms"] = {
    "W commit (48 Fp2 rows x 2^17 at rate 1/8: 7.5% of A+H's encoded points)": ("ESTIMATE", 2.0, 4.0, 0.0, 0.5),
    "tower stages 2.. (W2, BASE; under 1% of A's points)": ("ESTIMATE", 0.2, 1.0, 0.5, 2.0),
    "BAT coefficient rows (Gamma = sum theta_x G(x): 280 x 16,664 Fp2) and W's FOLD (dense c, 48 x 2^14)": ("ESTIMATE", 0.0, 1.0, 2.0, 8.0),
    "no absorb of the 47 clear vectors (12.5 MB of BLAKE3 on one thread)": ("ESTIMATE", 0.0, 0.0, -10.0, -4.0),
    "clear-vector folds: unchanged (A8's store fold produces W's rows)": ("CODE", 0.0, 0.0, 0.0, 0.0),
}
TIME["B6b_per_block_ms_ell18"] = {
    "stage-1 FOLD on A u H (dense coefficient table 84 M Fp2; ~1 G base products at 30-60% of 149 G/s)": ("ESTIMATE", 11.0, 30.0, 0.0, 2.0),
    "forward NTT at 2^19 instead of 2^15 (x19/15 butterflies, multipass)": ("ESTIMATE", 4.0, 12.0, 0.0, 0.0),
    "compact site masks (-310 of 5,103 rows of 2^14, -6% of commit points)": ("ESTIMATE", -2.0, -1.0, -1.0, 0.0),
    "tower, absorb as in B6a": ("ESTIMATE", 0.2, 1.0, -9.0, -2.0),
}


def sums(d):
    lo_g = sum(v[1] for v in d.values()); hi_g = sum(v[2] for v in d.values())
    lo_h = sum(v[3] for v in d.values()); hi_h = sum(v[4] for v in d.values())
    return dict(gpu_ms=[round(lo_g, 1), round(hi_g, 1)], host_ms=[round(lo_h, 1), round(hi_h, 1)])


TIME["B6a_sum"] = sums(TIME["B6a_per_block_ms"])
TIME["B6b_ell18_sum"] = sums(TIME["B6b_per_block_ms_ell18"])
for key in ("B6a_sum", "B6b_ell18_sum"):
    s = TIME[key]
    # run-level bounds at N = 6: GPU-serialised (32 x dGPU) and host-bound (32 x dhost / 6 workers)
    s["forks_phase_delta_s_if_gpu_bound"] = [round(32 * s["gpu_ms"][0] / 1000, 3), round(32 * s["gpu_ms"][1] / 1000, 3)]
    s["forks_phase_delta_s_if_host_bound"] = [round(32 * s["host_ms"][0] / 6000, 3), round(32 * s["host_ms"][1] / 6000, 3)]
    s["forks_phase_ratio_range"] = [round((3.76 + min(s["forks_phase_delta_s_if_gpu_bound"][0], s["forks_phase_delta_s_if_host_bound"][0])) / 3.76, 3),
                                    round((3.76 + max(s["forks_phase_delta_s_if_gpu_bound"][1], s["forks_phase_delta_s_if_host_bound"][1])) / 3.76, 3)]

# The verifier: operation counts per block (CODE: pcs.rs:1072-1165 verify_zk)
def verifier_counts(variant):
    if variant == "today":
        ntt_points = 47 * 2 * (1 << 15)                        # every clear vector re-encoded, two Fp parts
        col_mults = Q * (37 * A_ROWS + 10 * H_ROWS)            # each column against each group's row weights
        hashed = Q * (A_ROWS + H_ROWS) * 8 + 2 * Q * PATH * 64
        absorbed = 47 * VEC * 16
    elif variant == "B6a":
        ntt_points = 4 * (1 << 10)                             # BASE re-encodes short rows only
        col_mults = Q * (A_ROWS + H_ROWS) + 47 * (A_ROWS + H_ROWS)   # one batched row-weight vector per column
        hashed = Q * (A_ROWS + H_ROWS) * 8 + 2 * Q * PATH * 64 + 200_000
        absorbed = 20_000
    else:  # B6b at ell 18
        v = variants["B6b_ell18"]
        ntt_points = 4 * (1 << 10)
        col_mults = v["t1"] * v["stage1_rows"]
        hashed = v["stage1_bytes"] * 2 + 200_000
        absorbed = 20_000
    return dict(ntt_points=ntt_points, column_mults=col_mults, hashed_bytes=hashed, absorbed_bytes=absorbed)


vc = {k: verifier_counts(k) for k in ("today", "B6a", "B6b")}


def cpu_s(c):  # ESTIMATE per-operation costs: 4 ns per Fp2xFp product, 3 ns per NTT point x log, 1 ns per hashed byte
    return (c["column_mults"] * 4e-9 + c["ntt_points"] * 15 * 3e-9 + (c["hashed_bytes"] + c["absorbed_bytes"]) * 1e-9)


calib = (2.31 * 6 / 32) / cpu_s(vc["today"])
TIME["verifier"] = {
    "counts_per_block": vc,
    "modelled_cpu_s_per_block": {k: round(cpu_s(v) * calib, 4) for k, v in vc.items()},
    "calibration_factor (today's modelled PCS work scaled to the measured 2.31 s x 6 threads / 32)": round(calib, 2),
    "receipt_verify_s_6_threads": {k: round(cpu_s(v) * calib * 32 / 6, 3) for k, v in vc.items()},
    "note": "the measured verifier ran on diagonal synthetic weights, so its time is mostly PCS work; dense public weights add weight-MLE folds that B6 does not touch",
}
OUT["time"] = TIME

# ----------------------------------------------------------------------------------------------------
# 5. A toy-field joint-view rank test of B6a, with controls
# ----------------------------------------------------------------------------------------------------
# Over F_65537. For FIXED challenges every value the verifier sees is a linear form in (witness, randomness).
# The view is independent of the witness (perfect HVZK at those challenges) iff the witness columns of the view
# matrix lie in the span of its randomness columns: rank(R) == rank([R | W]). Merkle salts and roots are
# abstracted away (HidingMerkle covers them). The construction: stage 1 = a hiding coset RS commitment in
# coefficient form (B1) with q_pad = t pads; the clear vectors committed in W (code switch); W's claims
# batched (BAT), folded with a hiding polynomial U (FOLD, FlashProve fold_rounds.h:9-21) and closed by BASE
# with a masking oracle (FlashProve base_case.h:9-14).
FQ = 65537


class Lin:
    """Linear forms over the unknowns, as dense lists."""
    def __init__(self, dim):
        self.dim = dim
        self.n = 0
        self.names = []

    def new(self, name, count, kind):
        out = []
        for i in range(count):
            v = [0] * self.dim
            v[self.n] = 1
            self.names.append((name, i, kind))
            self.n += 1
            out.append(v)
        return out

    def zero(self):
        return [0] * self.dim


def add(a, b):
    return [(x + y) % FQ for x, y in zip(a, b)]


def sc(a, s):
    s %= FQ
    return [(x * s) % FQ for x in a]


def lsum(vs, dim):
    out = [0] * dim
    for v in vs:
        out = add(out, v)
    return out


def rank_mod(rows):
    m = [r[:] for r in rows if any(r)]
    r, ncols = 0, (len(m[0]) if m else 0)
    for c in range(ncols):
        piv = next((i for i in range(r, len(m)) if m[i][c] % FQ), None)
        if piv is None:
            continue
        m[r], m[piv] = m[piv], m[r]
        inv = pow(m[r][c], FQ - 2, FQ)
        m[r] = [(x * inv) % FQ for x in m[r]]
        for i in range(len(m)):
            if i != r and m[i][c]:
                f = m[i][c]
                m[i] = [(x - f * y) % FQ for x, y in zip(m[i], m[r])]
        r += 1
    return r


def root_of_unity(order):
    g = 3  # a generator of F_65537^*
    return pow(g, (FQ - 1) // order, FQ)


def gen_row(n, q, N, x):
    """The generator row at position x of the coefficient-form hiding code (B1):
    f(z) = sum_i d_i z^i + (z^n - 1) sum_j g_j z^j at z = 3 * w_N^x (3 is not in G_N)."""
    z = 3 * pow(root_of_unity(N), x, FQ) % FQ
    zn1 = (pow(z, n, FQ) - 1) % FQ
    return [pow(z, i, FQ) for i in range(n)] + [zn1 * pow(z, j, FQ) % FQ for j in range(q)]


def enc_at(msg, pad, N, x, dim):
    g = gen_row(len(msg), len(pad), N, x)
    return lsum([sc(v, c) for v, c in zip(msg + pad, g)], dim)


def eq_vec(point, nbits):
    out = []
    for b in range(1 << nbits):
        p = 1
        for i, r in enumerate(point):
            p = p * (r if (b >> i) & 1 else (1 - r)) % FQ
        out.append(p)
    return out


def run_toy(rng, cfg):
    """Returns (view, witness_idx, randomness_idx, completeness_ok)."""
    n, qa, na, ta = 8, cfg.get("qa", 3), 16, cfg.get("ta", 3)
    nw, qw, nnw, tw = 16, cfg.get("qw", 3), 64, cfg.get("tw", 3)
    compact = cfg["compact"]
    dim = 400
    lin = Lin(dim)
    D = [lin.new("D1", n, "w"), lin.new("D2", n, "w")]
    if compact:
        # a compact mask slice: two random entries (one per published value), the rest of the row zero; no
        # prox mask row (B6a never sends the prox vector)
        Sx = lin.new("Sx", 2, "r") + [lin.zero() for _ in range(n - 2)]
        maskrows = [Sx]
        rows = D + maskrows
    else:
        maskrows = [lin.new("S1", n, "r"), lin.new("S2", n, "r")]  # today's full-row site masks
        Pm = lin.new("Pm", n, "r")                                 # today's prox mask row
        rows = D + maskrows + [Pm]
    pads = [lin.new(f"padA{i}", qa, "r") for i in range(len(rows))]
    ch = lambda: rng.randrange(1, FQ)
    # claims (public coefficients), two groups
    a = [[ch(), ch()] for _ in range(2)]
    rpt = [[ch() for _ in range(3)] for _ in range(2)]
    cw = [eq_vec(rpt[i], 3) for i in range(2)]
    rho_p = [ch() for _ in rows]
    view, checks = [], []

    def dot(cvec, lvec):
        return lsum([sc(v, c) for v, c in zip(lvec, cvec)], dim)

    want = []
    for i in range(2):
        val = lsum([sc(dot(cw[i], D[b]), a[i][b]) for b in range(2)], dim)
        if cfg.get("mask_values", True):
            val = add(val, maskrows[0][i] if compact else dot(cw[i], maskrows[i]))
        want.append(val)
    view += want
    # the vectors (row weights over all rows) of every column key
    def rw_vec(weights):
        return [lsum([sc(rows[b][j], weights[b]) for b in range(len(rows))], dim) for j in range(n)] + \
               [lsum([sc(pads[b][j], weights[b]) for b in range(len(rows))], dim) for j in range(qa)]
    if compact:
        wts = [[a[0][0], a[0][1], 0], [a[1][0], a[1][1], 0], [0, 0, 1], rho_p]
    else:
        wts = [[a[0][0], a[0][1], 1, 0, 0], [a[1][0], a[1][1], 0, 1, 0], rho_p]
    V = [rw_vec(w) for w in wts]
    pos_a = rng.sample(range(na), ta)
    cols = {x: [enc_at(rows[b], pads[b], na, x, dim) for b in range(len(rows))] for x in pos_a}
    for x in pos_a:
        view += cols[x]
    if cfg["mode"] == "today":
        for v in V:
            view += v
        for k, v in enumerate(V):   # today's verifier: <v, cw> and the column check
            for x in pos_a:
                checks.append(add(enc_at(v[:n], v[n:], na, x, dim), sc(dot(wts[k], cols[x]), FQ - 1)))
        return view, lin, checks
    # ---- B6a: W holds the vectors (message: v then uniform fill), with its own pads
    fill = [lin.new(f"fillW{k}", nw - (n + qa), "r") if cfg.get("fill", True) else [lin.zero()] * (nw - n - qa) for k in range(len(V))]
    Wm = [V[k] + fill[k] for k in range(len(V))]
    Wp = [lin.new(f"padW{k}", qw, "r") for k in range(len(V))]
    while len(Wm) < 4:
        Wm.append([lin.zero()] * nw); Wp.append([lin.zero()] * qw)
    # BAT: value claims and generator claims, independent coefficients
    claims = []   # (row -> coefficient vector over nw, value)
    for i in range(2):
        coef = {i: cw[i] + [0] * (nw - n)}
        if compact and cfg.get("mask_values", True):
            e = [0] * nw; e[i] = 1
            coef[2] = e
        claims.append((coef, want[i]))
    for k in range(len(V)):
        for x in pos_a:
            g = gen_row(n, qa, na, x)
            claims.append(({k: g + [0] * (nw - n - qa)}, dot(wts[k], cols[x])))
    beta = [ch() for _ in claims]
    c = [[0] * nw for _ in range(4)]
    T = lin.zero()
    for (coef, val), bt in zip(claims, beta):
        for r_, vec in coef.items():
            c[r_] = [(u + bt * w) % FQ for u, w in zip(c[r_], vec)]
        T = add(T, sc(val, bt))
    # FOLD over the 2 row bits, with U(X1,X2) = (u11 X1 + u12 X1^2) X2 + u21 X2 + u22 X2^2 + c0
    use_u = cfg.get("use_u", True)
    Uc = lin.new("U", 5, "r") if use_u else [lin.zero()] * 5
    eps = ch()

    def Uval(x1, x2):
        return lsum([sc(Uc[0], x1 * x2), sc(Uc[1], x1 * x1 * x2), sc(Uc[2], x2), sc(Uc[3], x2 * x2), Uc[4]], dim)

    def fold_rows(mats, x1, x2, width, lin_rows):
        e = [(1 - x1) * (1 - x2), x1 * (1 - x2), (1 - x1) * x2, x1 * x2]
        if lin_rows:
            return [lsum([sc(mats[b][j], e[b]) for b in range(4)], dim) for j in range(width)]
        return [sum(e[b] * mats[b][j] for b in range(4)) % FQ for j in range(width)]

    def H(x1, x2):
        cx = fold_rows(c, x1, x2, nw, False)
        wx = fold_rows(Wm, x1, x2, nw, True)
        return add(Uval(x1, x2), sc(dot(cx, wx), eps))

    S_U = lsum([Uval(x1, x2) for x1 in (0, 1) for x2 in (0, 1)], dim)
    view.append(S_U)
    q1 = [lsum([H(y, x2) for x2 in (0, 1)], dim) for y in (0, 1, 2)]
    inv2 = pow(2, FQ - 2, FQ)
    def coeffs(qv):
        a0 = qv[0]
        a2 = sc(add(add(qv[2], sc(qv[1], FQ - 2)), qv[0]), inv2)
        a1 = add(add(qv[1], sc(qv[0], FQ - 1)), sc(a2, FQ - 1))
        return a0, a1, a2
    a0, a1, a2 = coeffs(q1)
    view += [a0, a2]
    checks.append(add(add(add(sc(a0, 2), a1), a2), sc(add(S_U, sc(T, eps)), FQ - 1)))   # q1(0)+q1(1) = S_U + eps T
    g1 = ch()
    q1g = add(add(a0, sc(a1, g1)), sc(a2, g1 * g1))
    q2 = [H(g1, y) for y in (0, 1, 2)]
    b0, b1, b2 = coeffs(q2)
    view += [b0, b2]
    checks.append(add(add(add(sc(b0, 2), b1), b2), sc(q1g, FQ - 1)))
    g2 = ch()
    q2g = add(add(b0, sc(b1, g2)), sc(b2, g2 * g2))
    u_m = fold_rows(Wm, g1, g2, nw, True)
    u_p = fold_rows(Wp, g1, g2, qw, True)
    cg = fold_rows(c, g1, g2, nw, False)
    eU = [g1 * g2 % FQ, g1 * g1 * g2 % FQ, g2, g2 * g2 % FQ, 1]
    Fm = Uc + (lin.new("fillF", nw - 5, "r") if use_u else [lin.zero()] * (nw - 5))
    Fp = lin.new("padF", qw, "r") if use_u else [lin.zero()] * qw
    final = add(sc(dot(cg, u_m), eps), dot(eU, Fm[:5]))
    checks.append(add(final, sc(q2g, FQ - 1)))
    # BASE
    use_g = cfg.get("use_gstar", True)
    Msu = lin.new("Mstar_u", nw, "r") if use_g else [lin.zero()] * nw
    Rsu = lin.new("Rstar_u", qw, "r") if use_g else [lin.zero()] * qw
    MsF = lin.new("Mstar_F", nw, "r") if use_g else [lin.zero()] * nw
    RsF = lin.new("Rstar_F", qw, "r") if use_g else [lin.zero()] * qw
    tstar = add(sc(dot(cg, Msu), eps), dot(eU, MsF[:5]))
    view.append(tstar)
    lam = ch()
    Mpu = [add(s, sc(v, lam)) for s, v in zip(Msu, u_m)]
    Rpu = [add(s, sc(v, lam)) for s, v in zip(Rsu, u_p)]
    MpF = [add(s, sc(v, lam)) for s, v in zip(MsF, Fm)]
    RpF = [add(s, sc(v, lam)) for s, v in zip(RsF, Fp)]
    view += Mpu + Rpu + MpF + RpF
    checks.append(add(add(sc(dot(cg, Mpu), eps), dot(eU, MpF[:5])), sc(add(tstar, sc(q2g, lam)), FQ - 1)))
    pos_w = rng.sample(range(nnw), tw)
    e4 = [(1 - g1) * (1 - g2) % FQ, g1 * (1 - g2) % FQ, (1 - g1) * g2 % FQ, g1 * g2 % FQ]
    for y in pos_w:
        wcols = [enc_at(Wm[b], Wp[b], nnw, y, dim) for b in range(4)]
        view += [wcols[b] for b in range(len(V))]
        fy = enc_at(Fm, Fp, nnw, y, dim)
        gu, gF = enc_at(Msu, Rsu, nnw, y, dim), enc_at(MsF, RsF, nnw, y, dim)
        view += [fy, gu, gF]
        uy = lsum([sc(wcols[b], e4[b]) for b in range(4)], dim)
        checks.append(add(enc_at(Mpu, Rpu, nnw, y, dim), sc(add(gu, sc(uy, lam)), FQ - 1)))
        checks.append(add(enc_at(MpF, RpF, nnw, y, dim), sc(add(gF, sc(fy, lam)), FQ - 1)))
    return view, lin, checks


def joint_view_test(cfg, seeds):
    passes, complete = 0, 0
    for s in seeds:
        rng = random.Random(s)
        view, lin, checks = run_toy(rng, cfg)
        complete += all(not any(ch) for ch in checks)
        w_idx = [i for i, (_, _, k) in enumerate(lin.names) if k == "w"]
        r_idx = [i for i, (_, _, k) in enumerate(lin.names) if k == "r"]
        R = [[v[i] for i in r_idx] for v in view]
        RW = [[v[i] for i in r_idx + w_idx] for v in view]
        passes += rank_mod(R) == rank_mod(RW)
    return dict(witness_hidden=f"{passes}/{len(seeds)}", verifier_equations_hold=f"{complete}/{len(seeds)}")


SEEDS = [11, 12, 13]
TOY = {
    "P1 today's opening, full-row site masks (sanity)": dict(mode="today", compact=False),
    "N1 today's opening with compact masks (clear vectors leak)": dict(mode="today", compact=True),
    "P2 B6a, today's full-row site masks": dict(mode="b6a", compact=False),
    "P3 B6a, compact masks, every tower mask on": dict(mode="b6a", compact=True),
    "N2 P3 but W opened at t_W = 9 > q_pad_W + uniform fill (3 + 5)": dict(mode="b6a", compact=True, tw=9),
    "I1 P3 with W's unused message entries zero (t_W = q_pad_W = 3)": dict(mode="b6a", compact=True, fill=False),
    "N3 P3 with zero fill and t_W = q_pad_W + 1": dict(mode="b6a", compact=True, fill=False, tw=4),
    "N4 P3 without the hiding polynomial U": dict(mode="b6a", compact=True, use_u=False),
    "N5 P3 without BASE's masking oracle": dict(mode="b6a", compact=True, use_gstar=False),
    "N6 P3 with stage 1 opened at t_A = q_pad_A + 1": dict(mode="b6a", compact=True, ta=4),
    "N7 P3 without the masks on the published values": dict(mode="b6a", compact=True, mask_values=False),
    "I2 P2 (full-row masks) without U and without BASE's masking oracle": dict(mode="b6a", compact=False, use_u=False, use_gstar=False),
    "I3 P2 with a plain tower: no W pads, zero fill, no U, no masking oracle": dict(mode="b6a", compact=False, use_u=False, use_gstar=False, fill=False, qw=0),
    "N8 I3's plain tower with compact masks": dict(mode="b6a", compact=True, use_u=False, use_gstar=False, fill=False, qw=0),
}
OUT["toy_joint_view"] = {
    "label": "MODEL (toy field F_65537; exact rank arithmetic; 3 challenge draws each)",
    "parameters": "stage 1: 2 witness rows + masks, n 8, q_pad 3, N 16, t 3; W: n 16, q_pad 3, N 64, t 3; FOLD over 2 row bits",
    "results": {k: joint_view_test(v, SEEDS) for k, v in TOY.items()},
}

print(json.dumps(OUT, indent=1))
