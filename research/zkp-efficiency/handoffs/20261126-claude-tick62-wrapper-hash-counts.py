#!/usr/bin/env python3
"""Tick 62 (queue item 94): counted BLAKE3 compressions of one verification, replacing tick 55's assumed ones.

Standard library only, reads no file, runs well under a second.
Inputs are labelled COUNTED (file:line in the handoff), MEASURED (receipt codec, record cited), [PLAN] (B6a build plan),
ASSUMED (mine). Everything printed is DERIVED from them.

Exact BLAKE3 compression count for an L-byte message (any mode, keyed or not):
  chunks = ceil(L/1024); each chunk costs ceil(len/64) compressions (at least 1); parents = chunks - 1
  (the root compression is the last parent, or the last block of a one-chunk message).
"""
import datetime
import math

print("clock", datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'))


def b3(L):
    if L == 0:
        return 1
    chunks = math.ceil(L / 1024)
    c = 0
    for i in range(chunks):
        ln = min(1024, L - 1024 * i)
        c += max(1, math.ceil(ln / 64))
    return c + chunks - 1


def absorb(label_len, nbytes):
    # transcript.rs:59-75: state(32) | len(label) u64 | label | len(data) u64 | data, one hasher, one finalize
    return b3(32 + 8 + label_len + 8 + nbytes)


SQUEEZE = b3(32 + 7 + 8)   # transcript.rs:120-130: state | b"squeeze" | counter u64 = 47 B -> 1 compression
assert SQUEEZE == 1
assert b3(64) == 1         # salt_leaf (pcs.rs:695-701) and hash_pair (merkle.rs:14-19, :102-109): 64 B each

# ---- 8B W16R2 profile (COUNTED / MEASURED) ----------------------------------------------------------------------------
BLOCKS = 32
N = 2**14                  # shape.rs:302 (log_cols 14), as cited by the B6 study
Q = 280                    # shape.rs:320
ENC = 2**15                # n * inv_rate (2), wire.rs:96 -> path 15
PATH = 15
VEC_BYTES = (N + Q) * 16   # wire.rs:107: vec = n + checks, 16 B per Fp2 = 266,624
A_ROWS, H_ROWS, M_ROWS = 2501, 2602, 50        # MEASURED: receipt codec (A 15,612,928 B etc., targeted_cpu.log:1539)
A_VECS, H_VECS, M_VECS = 37, 10, 2             # groups + 1 (36 / 9), M 2 (zk.rs mask_verify_tagged: mask-q, mask-prox)
M_CHECKS, M_PATH, M_VEC_BYTES = 256, 12, 2 * 512 * 16   # zk.rs:690-692: MASK_LOG_MSG 9, MASK_LOG_DOM 12, MASK_Q 256; q is 2m = 1024 Fp2
B_ROWS, B_VECS = 38, 3                          # boundary: 38 rows, 2 groups + prox (boundary.rs:186, wire.rs)
E_ROWS, E_VECS = 37, 2                          # endpoint opening: 37 rows, 1 group + prox
N_BOUNDARY, N_ENDPOINT = 31, 2

assert VEC_BYTES == 266624
# the receipt codec's own byte counts (MEASURED) are reproduced by wire.rs:107's formula
for name, vecs, rows, want in (("A", A_VECS, A_ROWS, 15612928), ("H", H_VECS, H_ROWS, 8640320)):
    got = vecs * VEC_BYTES + Q * (8 + rows * 8 + 32 + PATH * 32)
    assert got == want, (name, got, want)
assert 2 * M_VEC_BYTES + M_CHECKS * (8 + M_ROWS * 8 + 32 + M_PATH * 32) == 243712
assert B_VECS * VEC_BYTES + Q * (8 + B_ROWS * 8 + 32 + PATH * 32) == 1030592
assert E_VECS * VEC_BYTES + Q * (8 + E_ROWS * 8 + 32 + PATH * 32) == 761728
print("wire formula reproduces A 15,612,928, H 8,640,320, M 243,712, boundary 1,030,592, endpoint 761,728 bytes")


def column_comps(rows, path):
    """one opened column: hash of rows*8 bytes, then the salted leaf (64 B), then one 64 B node per path hop"""
    h = b3(rows * 8)
    return h, 1, path


print("\n== 1. one verification, TODAY, per commitment opening ==")


def opening(label, vecs, vec_labels, vec_bytes, rows, checks, path):
    absorbed = sum(absorb(len(l), vec_bytes) for l in vec_labels)
    h, s, p = column_comps(rows, path)
    cols = checks * (h + s + p)
    print(f"{label:9s} vectors {len(vec_labels):2d} x {vec_bytes:7d} B absorbed = {absorbed:8d} comps | column hash {h:3d} +salt {s} +path {p} "
          f"= {h+s+p:3d} x {checks} = {cols:7d} comps | total {absorbed+cols:8d}")
    return absorbed, cols, h


vl_A = [b"pcs-vec"] * (A_VECS - 1) + [b"pcs-prox"]
vl_H = [b"pcs-vec"] * (H_VECS - 1) + [b"pcs-prox"]
vl_M = [b"mask-q", b"mask-prox"]
a_abs, a_col, a_h = opening("A", A_VECS, vl_A, VEC_BYTES, A_ROWS, Q, PATH)
h_abs, h_col, h_h = opening("H", H_VECS, vl_H, VEC_BYTES, H_ROWS, Q, PATH)
m_abs, m_col, m_h = opening("M", M_VECS, vl_M, M_VEC_BYTES, M_ROWS, M_CHECKS, M_PATH)
blk_abs = a_abs + h_abs + m_abs
blk_col = a_col + h_col + m_col
# transcript traffic that is not an opening vector: index draws, lambda/rho draws, sumcheck rounds (bounded below)
IDX_SQ = math.ceil(Q / 4) * 2 + math.ceil(M_CHECKS / 4)    # challenge_indices: 4 u64 per squeeze
RHO_SQ = (A_VECS + H_VECS + 2)                              # zk_rhos: about one Fp2 draw per group plus prox (ASSUMED order of magnitude)
# slot proofs: 42,064 B a fork [INFERRED, B6 study 2.1]; if every 48 B were one absorbed round message (2 comps) + one squeeze
SLOT_HI = math.ceil(42064 / 48) * (absorb(8, 48) + SQUEEZE)
print(f"transcript misc per block: index draws {IDX_SQ}, lambda/rho draws ~{RHO_SQ} (ASSUMED), slot-proof rounds 0 to {SLOT_HI} (upper bound from the 42,064 B)")
misc_lo, misc_hi = IDX_SQ + RHO_SQ, IDX_SQ + RHO_SQ + SLOT_HI
blk_today_lo = blk_abs + blk_col + misc_lo
blk_today_hi = blk_abs + blk_col + misc_hi
print(f"per block: absorbs {blk_abs}, columns+salts+paths {blk_col}, misc {misc_lo}..{misc_hi}  -> {blk_today_lo} .. {blk_today_hi}")

# join: boundary and endpoint openings, once a request
def join_open(vecs_n, rows, checks=Q, path=PATH):
    ab = absorb(7, VEC_BYTES) * (vecs_n - 1) + absorb(8, VEC_BYTES)
    h, s, p = column_comps(rows, path)
    return ab + checks * (h + s + p)


bnd = join_open(B_VECS, B_ROWS)
end = join_open(E_VECS, E_ROWS)
join = N_BOUNDARY * bnd + N_ENDPOINT * end
print(f"join: boundary opening {bnd} comps x {N_BOUNDARY} + endpoint {end} x {N_ENDPOINT} = {join} comps a request")

req_today_lo = BLOCKS * blk_today_lo + join
req_today_hi = BLOCKS * blk_today_hi + join
print(f"REQUEST TODAY: {BLOCKS} x block + join = {req_today_lo/1e6:.3f} M .. {req_today_hi/1e6:.3f} M compressions (tick 55: 13.42 M, no join)")
print(f"  without the join: {BLOCKS*blk_today_lo/1e6:.3f} M .. {BLOCKS*blk_today_hi/1e6:.3f} M; of which opening vectors {BLOCKS*blk_abs/1e6:.3f} M, "
      f"column hash {BLOCKS*(a_h*Q+h_h*Q+m_h*M_CHECKS)/1e6:.3f} M, salts+paths {BLOCKS*(Q*(1+PATH)*2+M_CHECKS*(1+M_PATH))/1e6:.3f} M")
t55 = {'leaf': 12.0e6 / 64 * 1.06, 'absorb': 12.5e6 / 64 * 1.06, 'paths': 13440}
print(f"tick 55 per block: leaf {t55['leaf']:.0f}, absorb {t55['absorb']:.0f}, paths+salts {t55['paths']} = {sum(t55.values()):.0f}"
      f"; counted per block: leaf {BLOCKS and (a_h*Q+h_h*Q+m_h*M_CHECKS)}, absorb {blk_abs}, paths+salts {Q*(1+PATH)*2+M_CHECKS*(1+M_PATH)}")

# ---- B6a ----------------------------------------------------------------------------------------------------------------
print("\n== 2. B6a (build plan 2.2 to 2.4): A, H, M columns unchanged, no vector absorbs, plus the tower ==")
W_ROWS_FP, W_Q, W_PATH = 96, 138, 17        # [PLAN] 48 Fp2 rows = 96 Fp rows, rate 1/8, N = 2^17, t_W = 138
W2_ROWS_FP, W2_Q, W2_PATH = 34, 120, 15     # [PLAN] W2 34 Fp rows x 2^10 at rate 1/32 (N = 2^15), t = 120
BASE_BYTES = 2**10 * 16                     # [PLAN] last folded row, 2^10 Fp2 in the clear (absorbed ASSUMED: it is a prover message)
W_ALT = (W_ROWS_FP, 169, 16)                # [PLAN] rate 1/4: t_W = 169, N = 2^16


def stage(rows, t, path):
    h, s, p = column_comps(rows, path)
    return t * (h + s + p), h


w_c, w_h = stage(W_ROWS_FP, W_Q, W_PATH)
w2_c, w2_h = stage(W2_ROWS_FP, W2_Q, W2_PATH)
w4_c, _ = stage(*W_ALT)
base = absorb(4, BASE_BYTES)
BAT_SQ = 2 * 47 + (Q + Q) + 8 + 2 * 11 + math.ceil((W_Q + W2_Q) / 4)   # alpha, mu per vector; theta per opened position; fold rounds; indices
FOLD_ABS = 11 * (absorb(8, 48) + SQUEEZE)
tower_misc = BAT_SQ + FOLD_ABS + 2 * absorb(8, 40)     # roots absorbed
print(f"W: {W_Q} cols x ({w_h} hash +1 salt +{W_PATH} path) = {w_c}; W2: {W2_Q} cols x ({w2_h}+1+{W2_PATH}) = {w2_c}; BASE absorb {base}; "
      f"BAT/FOLD/roots transcript ~{tower_misc} (ASSUMED count of draws)")
print(f"rate-1/4 W alternative: 169 cols x (12+1+16) = {w4_c} (instead of {w_c})")
tower = w_c + w2_c + base + tower_misc
blk_b6a_lo = a_col + h_col + m_col + m_abs + misc_lo + tower
blk_b6a_hi = a_col + h_col + m_col + m_abs + misc_hi + tower
print(f"per block B6a: columns {a_col+h_col} + M {m_col+m_abs} + misc {misc_lo}..{misc_hi} + tower {tower} = {blk_b6a_lo} .. {blk_b6a_hi}")
# the join openings: A/H-style boundary openings keep today's form unless B6a's join (W_join) is built; item 101 asks
join_b6a_today_form = join
join_b6a_switched = N_BOUNDARY * (Q * sum(column_comps(B_ROWS, PATH))) + N_ENDPOINT * (Q * sum(column_comps(E_ROWS, PATH)))
print(f"join if the boundary and endpoint openings stay in today's form: {join_b6a_today_form}; if their 33 vectors are switched away "
      f"(columns only, tower of the join NOT counted): {join_b6a_switched}")
req_b6a_lo = BLOCKS * blk_b6a_lo + join_b6a_today_form
req_b6a_hi = BLOCKS * blk_b6a_hi + join_b6a_today_form
req_b6a_sw_lo = BLOCKS * blk_b6a_lo + join_b6a_switched
req_b6a_sw_hi = BLOCKS * blk_b6a_hi + join_b6a_switched
print(f"REQUEST B6a: join in today's form {req_b6a_lo/1e6:.3f} M .. {req_b6a_hi/1e6:.3f} M; join switched {req_b6a_sw_lo/1e6:.3f} M .. {req_b6a_sw_hi/1e6:.3f} M"
      f"  (tick 55: 6.90 M, no join)")
print(f"  without any join: {BLOCKS*blk_b6a_lo/1e6:.3f} M .. {BLOCKS*blk_b6a_hi/1e6:.3f} M")

# ---- 3. compare with tick 55 -------------------------------------------------------------------------------------------
print("\n== 3. against tick 55 (3% test) ==")
for name, mine_lo, mine_hi, theirs in (("today, blocks only", BLOCKS*blk_today_lo, BLOCKS*blk_today_hi, 13.42e6),
                                       ("today, with join", req_today_lo, req_today_hi, 13.42e6),
                                       ("B6a, blocks only", BLOCKS*blk_b6a_lo, BLOCKS*blk_b6a_hi, 6.90e6),
                                       ("B6a, join as today", req_b6a_lo, req_b6a_hi, 6.90e6)):
    print(f"{name:20s} {mine_lo/1e6:6.3f} .. {mine_hi/1e6:6.3f} M against {theirs/1e6:.2f} M: {100*(mine_lo/theirs-1):+5.1f}% .. {100*(mine_hi/theirs-1):+5.1f}%")

# ---- 4. layer 1, recomputed -------------------------------------------------------------------------------------------
print("\n== 4. layer 1 recomputed (Sable's two rates as in tick 55) ==")
CAD = 3.18                    # co-coordinator's correction 2026-11-25: stream of Nov 23, 3.18 s a request (40.2 tokens/s)
CAD_OLD = 3.7455
NS_WORD = 91.46e6 / 83.6e6    # ns per committed word, whole-block device (tick 55)
CELLS = 4096                  # [authors, estimate] cells a compression (Sable naive); tick 94 note: 5,344 measured cells for Sable v2
CELLS_M = 5344                # [authors, measured]: per the co-coordinator's correction of 2026-11-25
for nm, c in (("today (counted, with join)", req_today_lo), ("today (counted, upper)", req_today_hi),
              ("B6a (counted, join as today)", req_b6a_lo), ("B6a (counted, upper)", req_b6a_hi),
              ("B6a (join switched, lower)", req_b6a_sw_lo), ("tick 55's B6a 6.90 M", 6.90e6)):
    lo_s = c * 1.3e-6; hi_s = c * 2.4e-6                    # [authors] measured 1.3 to 2.4 us a compression, no global evaluation proof
    lo2 = c * 2.8e-6; hi2 = c * CELLS * NS_WORD * 1e-9      # tick 55's two methods
    hi3 = c * CELLS_M * NS_WORD * 1e-9
    print(f"{nm:30s} {c/1e6:6.2f} M: tick 55 methods {lo2:5.1f}..{hi2:5.1f} s ({lo2/CAD:4.1f}..{hi2/CAD:4.1f} cadences of {CAD}); "
          f"Sable v2 measured rate {lo_s:5.1f}..{hi_s:5.1f} s; our word rate at 5,344 cells {hi3:5.1f} s")
print(f"for reference the old cadence {CAD_OLD} s: B6a 6.90 M x 2.8 us = {6.9e6*2.8e-6/CAD_OLD:.1f} cadences")
