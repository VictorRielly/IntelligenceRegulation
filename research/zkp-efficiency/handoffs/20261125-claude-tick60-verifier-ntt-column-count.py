#!/usr/bin/env python3
"""Tick 60 (queue item 100): the NTT and column-product work of today's verifier, per block, W16R2_8B.
Standard library only; reads nothing, every constant is cited. Runs in well under a second."""

# ---- geometry (W16R2 8B block) -------------------------------------------------------------
LOG_N = 14                      # shape.rs W16R2_LOG_COLS (row width n = 2^14)
N = 1 << LOG_N
INV_RATE = 2                    # shape.rs W16R2_INV_RATE
NN = N * INV_RATE               # encoded width 2^15
Q = 280                         # shape.rs W16R2_OPENED_COLS = pad entries = opened columns
A_ROWS, H_ROWS = 2501, 2602     # W16R3 design B6, table at :292
A_GROUPS, H_GROUPS = 36, 9      # W16R3 design :228 (shape.rs a_groups, h_groups at 2806-2835)
VEC_A, VEC_H = A_GROUPS + 1, H_GROUPS + 1       # group vectors + the proximity vector
VECS = VEC_A + VEC_H
print("== 1. Vectors and encodes per block (COUNTED: pcs.rs:1290-1303)")
print(f"vectors: A {VEC_A} + H {VEC_H} = {VECS}; each Fp2 vector is encoded twice (re, im): {2 * VECS} encodes")
print(f"vector length n + q = {N + Q}; 47 x {N + Q} x 16 B = {VECS * (N + Q) * 16 / 1e6:.2f} MB (the 12.5 MB)")

# ---- NTT counts ------------------------------------------------------------------------------
inv_bfly = LOG_N * (N // 2)             # inverse NTT of size n  (ntt.rs:69-108: log n stages x n/2)
fwd_bfly = (LOG_N + 1) * (NN // 2)      # forward NTT of size nn
per_encode = inv_bfly + fwd_bfly
enc = 2 * VECS
total_bfly = enc * per_encode
extra_mul = enc * (N + (N + Q))         # ninv scale (ntt.rs:64-66) and the coset pows (pcs.rs:689-691)
swaps = enc * (N // 2 + NN // 2)        # upper bound: at most n/2 bit-reversal swaps a transform
print("\n== 2. NTT work per block (COUNTED)")
print(f"one encode: inverse 2^{LOG_N}: {inv_bfly:,} butterflies; forward 2^{LOG_N + 1}: {fwd_bfly:,}; sum {per_encode:,} "
      f"({per_encode / NN:.1f} per output point)")
print(f"per block: {enc} encodes -> {total_bfly:,} butterflies ({total_bfly / 1e6:.2f} M); extra Fp multiplications "
      f"(ninv scale + coset powers): {extra_mul:,} ({extra_mul / 1e6:.2f} M); bit-reversal swaps <= {swaps / 1e6:.2f} M")
print(f"encoded output held: {enc} x {NN} x 8 B = {enc * NN * 8 / 1e6:.1f} MB")
tick58_pts = 3.08e6
print(f"tick 58 took {tick58_pts / 1e6:.2f} M points x 8 butterflies = {tick58_pts * 8 / 1e6:.1f} M; counted here: "
      f"{total_bfly / 1e6:.1f} M (11.0 per point: the inverse half and 7.5 for the forward half were not both counted)")

# rates, ns per butterfly, one thread
RATES = {
    "W2 commit, size 2^15, NTT row loop serial, all-in (tick 56, MEASURED)": 2.11,
    "same at 1/2 (tick 56)": 2.18,
    "five-thread bridge NTT 5.88 ms x 5 threads / 11.0 M (tick 57), upper bound": 5.88e6 * 5 / 11.0e6,
}
MUL_NS = 1.12   # BAT's per-Fp-multiplication-equivalent (tick 58)
print("\nNTT term per block, ms (butterflies x rate + extra multiplications x 1.12 ns):")
ntt = {}
for k, r in RATES.items():
    ms = total_bfly * r / 1e6 + extra_mul * MUL_NS / 1e6
    ntt[k] = ms
    print(f"  {r:5.2f} ns  {ms:6.1f} ms   {k}")
ntt_lo = min(ntt.values())
ntt_hi = max(ntt.values())
print(f"  range {ntt_lo:.1f} to {ntt_hi:.1f} ms, factor {ntt_hi / ntt_lo:.2f} (pass line: within 1.3)")

# ---- column products -------------------------------------------------------------------------
dense = Q * (VEC_A * A_ROWS + VEC_H * H_ROWS)
prox_only = Q * (A_ROWS + H_ROWS)
print("\n== 3. Column work per block (COUNTED: pcs.rs:1306-1330, a26_combine at :1197)")
print(f"opened columns {Q} per commitment; dense products (every vector over every row): {dense:,} ({dense / 1e6:.2f} M mul_base = 2 Fp muls each)")
print(f"A26 sparse loop is default on (pcs.rs:1175-1178); the two proximity weights stay dense: {prox_only:,} ({prox_only / 1e6:.2f} M)")
col_bytes = Q * (A_ROWS + H_ROWS) * 8
path = NN.bit_length() - 1
print(f"hashed column bytes: {Q} x ({A_ROWS} + {H_ROWS}) x 8 = {col_bytes / 1e6:.2f} MB; BLAKE3 64 B blocks {col_bytes / 64:,.0f} "
      f"plus parents; salted leaf 1 compression x {2 * Q}; Merkle path {path} hops x {2 * Q} = {path * 2 * Q:,} compressions")
print(f"6.4 ms for 12.0 MB (tick 58) -> {6.4 / 12.0 * col_bytes / 1e6:.1f} ms for the counted {col_bytes / 1e6:.2f} MB")
ip = (A_GROUPS + H_GROUPS) * N
print(f"group inner products <v, c> (pcs.rs:1268-1277): {A_GROUPS + H_GROUPS} x {N} = {ip:,} Fp2 multiplications = {ip * 5e-6:.1f} ms at 5 ns")
absorb = 6.1

# ---- the record's cap ------------------------------------------------------------------------
BLOCK = 141.9   # 4.54 s / 32, 2026-11-05, BEFORE the A26 sparse column loop (merged 2026-11-07)
HASH_STAYS = 6.1
cap_removed = BLOCK - HASH_STAYS
print("\n== 4. Joint constraint from the one-thread record (MEASURED 141.9 ms a block, pre-A26)")
for ntt_ms in (ntt_lo, ntt_hi):
    room = BLOCK - ntt_ms - HASH_STAYS - absorb - ip * 5e-6
    print(f"  NTT {ntt_ms:5.1f} ms -> dense columns plus all non-PCS work <= {room:5.1f} ms; as a rate on {dense / 1e6:.1f} M products <= {room * 1e6 / dense:.2f} ns each")
col_floor = dense * 1.0e-6   # 1.0 ns a product (0.5 ns a multiplication), a generous floor
removed_lo = ntt_lo + col_floor + absorb + ip * 5e-6
removed_hi = cap_removed
print(f"removed work, low end: NTT {ntt_lo:.1f} + columns at a 1.0 ns floor {col_floor:.1f} + absorb {absorb} + inner products {ip * 5e-6:.1f} = {removed_lo:.1f} ms")
print(f"removed work, high end: the cap, {BLOCK} - hashing that stays {HASH_STAYS} = {removed_hi:.1f} ms; width {removed_hi - removed_lo:.1f} ms")
other_lo, other_hi = BLOCK - removed_hi, BLOCK - removed_lo
print(f"stays under B6a (hashing + all non-PCS work): {other_lo:.1f} to {other_hi:.1f} ms")

spike_built = {"1/8": 39.4, "1/4": 43.4, "1/2": 57.2}   # tick 58, hostfix, BAT+tower
spike_rat = {"1/8": 28.3, "1/4": 28.5, "1/2": 29.3}
print("\nB6a block, one thread (stays + spike BAT+tower), ms:")
for r in spike_built:
    a0, a1 = other_lo + spike_built[r], other_hi + spike_built[r]
    b0, b1 = other_lo + spike_rat[r], other_hi + spike_rat[r]
    print(f"  rate {r}: as built {a0:5.1f} to {a1:5.1f} (width {a1 - a0:.1f}); rational switch row {b0:5.1f} to {b1:5.1f} (width {b1 - b0:.1f})")

# ---- today's block with A26 ------------------------------------------------------------------
print("\n== 5. Today's block with the A26 sparse loop (default on since 2026-11-07; the 141.9 ms predates it)")
col_hi_by_cap = BLOCK - ntt_lo - HASH_STAYS - absorb - ip * 5e-6
saving_hi = col_hi_by_cap * (1 - prox_only / dense)
saving_lo = col_floor * (1 - prox_only / dense)
print(f"dense column term {col_floor:.0f} to {col_hi_by_cap:.0f} ms; sparse leaves {prox_only / dense:.1%} of the products at most; "
      f"A26 saving {saving_lo:.0f} to {saving_hi:.0f} ms, so today's block {BLOCK - saving_hi:.0f} to {BLOCK - saving_lo:.0f} ms "
      f"(upper end if the supports cover half of each row; 0 saving if the supports are dense)")
print("per request, 32 blocks, one thread, today (pre-A26 record .. with the saving):")
t_hi = 32 * BLOCK / 1e3
t_lo = 32 * (BLOCK - saving_hi) / 1e3
print(f"  today {t_lo:.2f} to {t_hi:.2f} s")
for r in ("1/8", "1/4", "1/2"):
    a0, a1 = 32 * (other_lo + spike_built[r]) / 1e3, 32 * (other_hi + spike_built[r]) / 1e3
    print(f"  B6a as built, rate {r}: {a0:.2f} to {a1:.2f} s; ratio today/B6a {t_lo / a1:.2f} to {t_hi / a0:.2f}")

# ---- verifier-side pruning, for the record ---------------------------------------------------
print("\n== 6. Could the verifier skip the full forward NTT (only 280 outputs are read)?  (DERIVED)")
best = None
for s in range(1, 13):
    classes = min(2 ** s, 2 * 0 + Q)       # at most 280 residue classes hit
    # expected distinct classes hit by Q random positions among 2^s classes
    exp_classes = (2 ** s) * (1 - (1 - 1 / 2 ** s) ** Q)
    first = s * (NN // 2)                  # first s decimation stages on the full vector
    sub_n = NN >> s
    sub = exp_classes * (max(sub_n.bit_length() - 1, 0) * (sub_n // 2))
    tot = first + sub
    if best is None or tot < best[0]:
        best = (tot, s, exp_classes)
print(f"best split: s = {best[1]} stages first, {best[2]:.0f} classes hit, {best[0]:,.0f} butterflies against {fwd_bfly:,} "
      f"({best[0] / fwd_bfly:.2f} of the forward half, {(best[0] + inv_bfly) / per_encode:.2f} of the encode); direct evaluation at 280 points: "
      f"{(N + Q) * Q:,} multiplications a component ({(N + Q) * Q / per_encode:.1f} x the NTT)")
