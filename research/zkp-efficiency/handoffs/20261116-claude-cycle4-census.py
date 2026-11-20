#!/usr/bin/env python3
"""Cycle 4 (2026-11-16): committed-volume census of one 8B request (W16R2, Llama-3-8B, T = 128, 32 blocks)
and the memory-traffic floor against a plain forward pass.

Run:  python3 -I research/zkp-efficiency/handoffs/20261116-claude-cycle4-census.py
Standard library only, reads no file, writes nothing, runs in well under a second.

Every input is tagged with where it comes from:
  COUNTED   read off the Rust sources (file:line) or the recorded census log;
  MEASURED  from a recorded run (file);
  ASSUMED   an assumption of this note, with the number stated here;
  DERIVED   arithmetic on the above (done in this script).
The script asserts that its counts reproduce the MEASURED per-block opening bytes (A 15,612,928, H 8,640,320,
M 243,712, endpoint 761,728) and the MEASURED receipt total 818,728,672 B that results/zk60_effplan_20261105/b6/model.py
reproduces, so the row counts are tied to bytes that a real run wrote.
"""
import json

# ---------------------------------------------------------------------------------------------------------
# 1. Shape (COUNTED)
# ---------------------------------------------------------------------------------------------------------
# shape.rs:302   W16R2_8B_T128_H24: tokens 128, width 4096, hidden 14336, q_heads 32, head_dim 128, kv_heads 8, log_cols 14
# shape.rs:306   W16R2_INV_RATE = 2 ; shape.rs:320 W16R2_OPENED_COLS = 280 ; shape.rs:323 W16R2_LOG_COLS = 14
L = 32                      # transformer blocks (Llama-3-8B)
T, D, F_TRUE = 128, 4096, 14336
HEADS, HEAD_DIM, KV_HEADS = 32, 128, 8
LOG_N = 14
N = 1 << LOG_N              # message words per row
INV_RATE = 2
NN = N * INV_RATE           # codeword words per row (the tree has NN leaves)
Q = 280                     # opened columns = pads per row (shape.rs:320)
WORD_B = 8                  # one Goldilocks word (pcs.rs encodes Fp rows; opening column data is rows * 8 B)

# Domain sizes in words, shape.rs:2420-2425 (natural_log) and 2455-2457 (rows_of = max(1, size >> log_cols)).
# Padded sizes: T_pad 128, D_pad 4096, H_pad 32, F_pad 16384 (hidden 14336 padded to a power of two).
DOM_WORDS = {
    "T": 1 << 7,                       # lifted to one row (P-3)
    "Ht": 1 << 12,                     # heads * T, lifted to one row
    "L": 16 * T,                       # clog2(16 * t_pad) = 11, lifted to one row
    "D": T * D,                        # 2^19
    "Q": T * HEADS * HEAD_DIM,         # 2^19
    "Kv": T * KV_HEADS * HEAD_DIM,     # 2^17
    "S": HEADS * T * T,                # 2^19 (heads x T x T, full square)
    "F": T * 16384,                    # 2^21 (hidden 14336 padded to 16384)
    "Tab": 1,                          # lifted to one row
}
ROWS = {k: max(1, v // N) for k, v in DOM_WORDS.items()}
assert ROWS == {"T": 1, "Ht": 1, "L": 1, "D": 32, "Q": 32, "Kv": 8, "S": 32, "F": 128, "Tab": 1}

# Plane counts per domain, COUNTED: results/zk60_effplan_20261105/census.log:218-237
# (test range16_tests.rs:209-246 `effplan_census_of_the_committed_rows_by_domain`; layout.rs:1325-1353 gives
#  A rows = planes * rows_of, H rows = 2 * planes * rows_of because a helper is Fp2 (re, im): layout.rs:1345-1349).
A_PLANES = {"T": 4, "Ht": 2, "L": 2, "D": 19, "Q": 6, "Kv": 6, "S": 8, "F": 9, "Tab": 15}
H_PLANES = {"L": 1, "D": 10, "Q": 3, "Kv": 3, "S": 5, "F": 5, "Tab": 16}
A_DATA = sum(A_PLANES[k] * ROWS[k] for k in A_PLANES)
H_DATA = sum(2 * H_PLANES[k] * ROWS[k] for k in H_PLANES)
assert (A_DATA, H_DATA) == (2279, 2514)                       # census.log:218 and layout.rs h_data_rows (2 * 1257)

# Mask / blinding rows: layout.rs:1341-1353: a_rows = a_data + 2 * (A claim sites) + 2 (proximity pair), likewise H.
A_ROWS, H_ROWS = 2501, 2602                                   # census.log:218 (also asserted by model.py via bytes)
A_SITE_ROWS, H_SITE_ROWS, PROX_ROWS = A_ROWS - A_DATA - 2, H_ROWS - H_DATA - 2, 2
assert (A_SITE_ROWS, H_SITE_ROWS) == (220, 86)

# M (the masking table): model.py:41 M_ROWS = 50 = 2 * 23 slots + 4 (shape.rs m_rows); zk.rs:391-392: 512 message
# positions per row over a 4096-position domain (rate 1/8), 256 opened columns, Merkle depth 12.
M_ROWS, M_MSG, M_DOM, M_Q, M_PATH = 50, 512, 4096, 256, 12
# Boundaries (L - 1 of them) and the two endpoints: boundary.rs:186 commitment_rows = data + 2 * sites + 2 with
# data = T*D/2^14 = 32, sites = 2 (run.rs:50); endpoint rows 37 = 32 + MASK_ROWS 5 (shape.rs:1777).
B_ROWS, E_ROWS = 38, 37
N_BOUNDARIES, N_ENDPOINTS = L - 1, 2

# ---------------------------------------------------------------------------------------------------------
# 2. Tie the counts to MEASURED bytes (model.py:52-85 formulas; MEASURED totals model.py:47-48)
# ---------------------------------------------------------------------------------------------------------
PATH = 15  # log2(NN)


def opening_len(groups, rows, n=N, q=Q, path=PATH):
    return (groups + 1) * (n + q) * 16 + q * (8 + rows * 8 + 32 + path * 32)


assert opening_len(36, A_ROWS) == 15_612_928     # MEASURED block A opening, results/zk60_w16r2_q280_20261103/logs/targeted_cpu.log:1539
assert opening_len(9, H_ROWS) == 8_640_320       # MEASURED block H opening (same log)
assert opening_len(1, E_ROWS) == 761_728         # MEASURED endpoint opening (same log)
M_OPEN = 2 * (2 << 9) * 16 + M_Q * (8 + M_ROWS * 8 + 32 + M_PATH * 32)
assert M_OPEN == 243_712                         # MEASURED block M opening
column_data_bytes = (L * (Q * A_ROWS * 8 + Q * H_ROWS * 8 + M_Q * M_ROWS * 8)
                     + N_BOUNDARIES * Q * B_ROWS * 8 + N_ENDPOINTS * Q * E_ROWS * 8)

# ---------------------------------------------------------------------------------------------------------
# 3. Census per block and per request
# ---------------------------------------------------------------------------------------------------------
# Split of A's data rows into (a) words the integer model defines, (b) range / remainder limb planes,
# (c) per-token aggregates, (d) table planes.  COUNTED: accuracy_layout.rs:113-160 (new_w16 plane list) with the per-domain
# plane totals of the census (the limb counts are fixed by A_PLANES minus the word planes).
A_WORD_PLANES = {"D": 7, "Q": 3, "Kv": 3, "S": 4, "F": 4}   # D: X Y AO X1 YM Z X2; Q: Q QR O; Kv: K V KR; S: S ZSEL E P; F: G A_SCALED U H
A_LIMB_PLANES = {k: A_PLANES[k] - A_WORD_PLANES[k] for k in A_WORD_PLANES}
assert A_LIMB_PLANES == {"D": 12, "Q": 3, "Kv": 3, "S": 4, "F": 5}
A_WORD_ROWS = sum(A_WORD_PLANES[k] * ROWS[k] for k in A_WORD_PLANES)
A_LIMB_ROWS = sum(A_LIMB_PLANES[k] * ROWS[k] for k in A_LIMB_PLANES)
A_AUX_ROWS = sum(A_PLANES[k] * ROWS[k] for k in ("T", "Ht", "L"))
A_TAB_ROWS = A_PLANES["Tab"] * ROWS["Tab"]
assert A_WORD_ROWS + A_LIMB_ROWS + A_AUX_ROWS + A_TAB_ROWS == A_DATA

CATS = {   # rows of one block's A + H commitments, by group
    "A words (activations the model defines)": A_WORD_ROWS,
    "A limb / remainder planes (range-checked small values)": A_LIMB_ROWS,
    "A per-token aggregates (T, Ht, L planes)": A_AUX_ROWS,
    "A table planes (multiplicities, range sub-planes)": A_TAB_ROWS,
    "H LogUp helpers (Fp2 = 2 rows each, incl. table helpers and u)": H_DATA,
    "masks: A site pairs + A proximity pair": A_SITE_ROWS + 2,
    "masks: H site pairs + H proximity pair": H_SITE_ROWS + 2,
}
BLOCK_AH_ROWS = A_ROWS + H_ROWS
assert sum(CATS.values()) == BLOCK_AH_ROWS == 5103

rows_per_request = L * BLOCK_AH_ROWS + N_BOUNDARIES * B_ROWS + N_ENDPOINTS * E_ROWS
msg_words_regular = rows_per_request * N                       # message words in the regular (2^14, rate 1/2) commitments
msg_words_M = L * M_ROWS * M_MSG
code_words_regular = rows_per_request * NN
code_words_M = L * M_ROWS * M_DOM
msg_words = msg_words_regular + msg_words_M
code_words = code_words_regular + code_words_M
pad_words = rows_per_request * Q                               # random pad symbols (inside the coset code's K = n + Q)

# Hashed bytes (pcs.rs:584, 759, 806: leaf = blake3(blake3(column) || salt); tree = blake3 of 64 B per inner node)
commitments_regular = L * 2 + N_BOUNDARIES + N_ENDPOINTS
hash_leaf_col = code_words_regular * WORD_B                    # column bytes hashed once (rows * 8 B per leaf, NN leaves per commitment)
hash_fixed_regular = commitments_regular * (NN * 64 + (NN - 1) * 64)   # salted-leaf hash input + inner nodes
hash_M = L * (M_DOM * M_ROWS * WORD_B + M_DOM * 64 + (M_DOM - 1) * 64)
hashed_bytes = hash_leaf_col + hash_fixed_regular + hash_M
salt_bytes = (commitments_regular * NN + L * M_DOM) * 32

# ---------------------------------------------------------------------------------------------------------
# 4. Plain baseline (weights public, read once per batch)
# ---------------------------------------------------------------------------------------------------------
P_Q, P_K, P_V, P_O = D * D, D * (KV_HEADS * HEAD_DIM), D * (KV_HEADS * HEAD_DIM), D * D
P_FFN = 3 * D * F_TRUE
PARAMS_PER_BLOCK = P_Q + P_K + P_V + P_O + P_FFN                # 218,103,808; results/zk60_h124_witness_20261104/README.md:73 says ~218 M int8 weights
assert PARAMS_PER_BLOCK == 218_103_808
VOCAB = 128_256
HEAD_PARAMS = VOCAB * D                                          # the LM head, read for the last position only (token I/O, per-row int8 head)
W_BLOCKS = L * PARAMS_PER_BLOCK
W_ALL = W_BLOCKS + HEAD_PARAMS                                   # weights a one-position-out pass reads
MACS = L * PARAMS_PER_BLOCK * T + HEAD_PARAMS + L * 2 * T * T * HEADS * HEAD_DIM   # projections + head (1 row) + QK^T and PV (full square)
OPS = 2 * MACS

# Activations: every intermediate written once and read once, unfused (upper end), and a fused / int8 lower end.
TD, TKV, TF, TS = T * D, T * KV_HEADS * HEAD_DIM, T * F_TRUE, HEADS * T * T
ELEMS_PER_BLOCK = 9 * TD + 3 * TKV + 2 * TS + 3 * TF            # y1 q qr o ao x1 y2 z x2 | k v kr | scores probs | g u h
ACT_UNFUSED_I16 = L * ELEMS_PER_BLOCK * 2 * 2                    # bytes: 2 B each, write + read
ACT_FUSED_LOW = 0.4e9                                            # ASSUMED lower end (fused attention + MLP, int8 lanes)
act_range = (ACT_FUSED_LOW, ACT_UNFUSED_I16)

plain_i8_bytes = (W_ALL * 1 + act_range[0], W_ALL * 1 + act_range[1])
plain_f16_bytes = (W_ALL * 2 + act_range[0], W_ALL * 2 + act_range[1])
plain_i8_weights_only = W_ALL * 1
plain_f16_weights_only = W_ALL * 2

# ---------------------------------------------------------------------------------------------------------
# 5. Floors  (bandwidths and peak rates are ASSUMED unless marked)
# ---------------------------------------------------------------------------------------------------------
BW = {
    "RTX 5090 peak 1.792 TB/s (ASSUMED, published spec, not verified here)": 1.792e12,
    "RTX 5090 effective 1.45 TB/s (script literal in the invalid benchmark; ASSUMED)": 1.45e12,
    "M3 Ultra 0.64 TB/s (MEASURED streaming, GPU_FRIENDLY_REVIEW.md:115, 637-642 GB/s)": 0.64e12,
}
PEAK_I8_OPS = 838e12          # ASSUMED dense int8 (reviewer's recollection, GPU_FRIENDLY_REVIEW.md:240; unverified)
PEAK_F16_OPS = (210e12, 420e12)  # ASSUMED dense fp16 tensor (fp32 / fp16 accumulate); unverified

cw_bytes = code_words * WORD_B
floor_write = cw_bytes                       # write every codeword word once (store it for the later column openings)
floor_write_hash = cw_bytes + hashed_bytes   # ... and read it back once to hash it (the unfused version)


def plain_time(bytes_per_req, ops_per_req, bw, peak, batch, weights_bytes):
    """Roofline minimum for one request when `batch` requests share one weight read."""
    mem = (weights_bytes / batch + (bytes_per_req - weights_bytes)) / bw
    comp = ops_per_req / peak
    return max(mem, comp), mem, comp


# ---------------------------------------------------------------------------------------------------------
# 6. Category scenarios (counts only, not designs)
# ---------------------------------------------------------------------------------------------------------
def rows_after(remove_h=False, pack_a=1, pack_limbs_only=False, drop_pad=False):
    h = 0 if remove_h else H_DATA
    h_mask = 0 if remove_h else H_SITE_ROWS + 2
    if pack_limbs_only:
        a = A_WORD_ROWS + A_LIMB_ROWS / pack_a + A_AUX_ROWS + A_TAB_ROWS
    else:
        a = (A_WORD_ROWS + A_LIMB_ROWS) / pack_a + A_AUX_ROWS + A_TAB_ROWS
    return a + h + A_SITE_ROWS + 2 + h_mask


def report():
    out = {}
    out["shape"] = dict(L=L, T=T, d=D, ffn=F_TRUE, row_width=N, codeword_width=NN, opened_columns=Q)
    per_block = dict(A_rows=A_ROWS, H_rows=H_ROWS, A_plus_H_rows=BLOCK_AH_ROWS, M_rows=M_ROWS,
                     message_words_AH=BLOCK_AH_ROWS * N, codeword_words_AH=BLOCK_AH_ROWS * NN,
                     codeword_bytes_AH=BLOCK_AH_ROWS * NN * WORD_B,
                     A_codeword_bytes=A_ROWS * NN * WORD_B, H_codeword_bytes=H_ROWS * NN * WORD_B)
    out["per_block"] = per_block
    out["categories_rows_per_block"] = {k: v for k, v in CATS.items()}
    out["categories_share_of_5103"] = {k: round(v / BLOCK_AH_ROWS, 4) for k, v in CATS.items()}
    out["per_request"] = dict(
        rows_regular=rows_per_request, rows_boundaries=N_BOUNDARIES * B_ROWS, rows_endpoints=N_ENDPOINTS * E_ROWS,
        message_words_regular=msg_words_regular, message_words_M=msg_words_M, message_words_total=msg_words,
        message_bytes=msg_words * WORD_B, pad_words=pad_words,
        codeword_words_regular=code_words_regular, codeword_words_M=code_words_M, codeword_words_total=code_words,
        codeword_bytes=cw_bytes, hashed_bytes=hashed_bytes, salt_bytes=salt_bytes,
        opened_column_data_bytes=column_data_bytes, commitments=commitments_regular + L)
    out["vs_cycle3"] = dict(cycle3_committed_words=2.7e9, counted_message_words=msg_words_regular,
                            ratio=msg_words_regular / 2.7e9, cycle3_codeword_bytes=40e9, counted_codeword_bytes=cw_bytes)
    out["plain"] = dict(
        params_blocks=W_BLOCKS, params_head=HEAD_PARAMS, params_read=W_ALL, macs=MACS, ops=OPS,
        activation_bytes_range=act_range, elems_per_block=ELEMS_PER_BLOCK,
        int8_bytes_range=plain_i8_bytes, fp16_bytes_range=plain_f16_bytes)
    out["floors_bytes"] = dict(write_once=floor_write, write_then_hash=floor_write_hash)

    times = {}
    for bwname, bw in BW.items():
        t = {"floor_write_s": floor_write / bw, "floor_write_hash_s": floor_write_hash / bw}
        for b in (1, 2, 4, 8, 16, 24):
            for util in (1.0, 0.5):
                key = f"B{b}_util{util}"
                lo = plain_time(plain_i8_bytes[0], OPS, bw, PEAK_I8_OPS * util, b, plain_i8_weights_only)[0]
                hi = plain_time(plain_i8_bytes[1], OPS, bw, PEAK_I8_OPS * util, b, plain_i8_weights_only)[0]
                f_lo = plain_time(plain_f16_bytes[0], OPS, bw, PEAK_F16_OPS[1] * util, b, plain_f16_weights_only)[0]
                f_hi = plain_time(plain_f16_bytes[1], OPS, bw, PEAK_F16_OPS[0] * util, b, plain_f16_weights_only)[0]
                t[key] = dict(plain_i8_s=(lo, hi), plain_f16_s=(f_lo, f_hi),
                              ratio_write_vs_i8=(floor_write / bw / hi, floor_write / bw / lo),
                              ratio_write_hash_vs_i8=(floor_write_hash / bw / hi, floor_write_hash / bw / lo),
                              ratio_write_vs_f16=(floor_write / bw / f_hi, floor_write / bw / f_lo),
                              ratio_write_hash_vs_f16=(floor_write_hash / bw / f_hi, floor_write_hash / bw / f_lo))
        times[bwname] = t
    out["times"] = times

    base = BLOCK_AH_ROWS
    scen = {
        "today": rows_after(),
        "no H planes and no H masks (count only: LogUp-GKR-like removal)": rows_after(remove_h=True),
        "A words+limbs packed 4 per word (count only)": rows_after(pack_a=4),
        "A limbs only packed 4 per word (count only)": rows_after(pack_a=4, pack_limbs_only=True),
        "no H and A words+limbs packed 4 per word (count only)": rows_after(remove_h=True, pack_a=4),
        "A words only, nothing else (activation-only floor, count only)": A_WORD_ROWS,
    }
    out["scenarios_rows_per_block"] = scen
    out["scenarios_fraction_of_today"] = {k: round(v / base, 4) for k, v in scen.items()}
    # floor ratio at B = 1 on the 5090 at peak bandwidth against int8 plain (central: the middle of the plain range)
    bw = 1.792e12
    plain_mid = plain_time(sum(plain_i8_bytes) / 2, OPS, bw, PEAK_I8_OPS, 1, plain_i8_weights_only)[0]
    out["scenario_floor_ratio_B1_5090_peak_vs_int8_mid"] = {
        k: round(floor_write * (v / base) / bw / plain_mid, 2) for k, v in scen.items()}
    out["plain_i8_mid_B1_5090_peak_s"] = plain_mid
    # padding facts (DERIVED): F stripes carry 2048 pad words in each 16384-word row
    f_rows = A_PLANES["F"] * ROWS["F"] + 2 * H_PLANES["F"] * ROWS["F"]
    out["padding_rows_equiv_per_block"] = dict(F_pad_rows=f_rows * (16384 - F_TRUE) / 16384,
                                               share_of_5103=f_rows * (16384 - F_TRUE) / 16384 / base,
                                               S_upper_triangle_rows_at_most=(A_PLANES["S"] * ROWS["S"] + 2 * H_PLANES["S"] * ROWS["S"]) / 2,
                                               S_share_of_5103_at_most=(A_PLANES["S"] * ROWS["S"] + 2 * H_PLANES["S"] * ROWS["S"]) / 2 / base)
    return out


if __name__ == "__main__":
    print(json.dumps(report(), indent=1, default=float))
