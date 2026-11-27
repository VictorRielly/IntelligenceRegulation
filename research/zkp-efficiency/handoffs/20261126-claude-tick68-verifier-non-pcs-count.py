#!/usr/bin/env python3
"""Tick 68, queue item 104: how much of one W16R2_8B diagonal-weight verifier block is not PCS.

Standard library only; arithmetic on counts read from the code (file:line in the handoff) and on rates
that are labelled MEASURED (a retained record), DERIVED or ASSUMED. Nothing here runs the prover.
"""

# ---- 1. sizes at W16R2_8B_T128_H24 (shape.rs:302: width 4096, hidden 14336, q_heads 32, head_dim 128, kv_heads 8)
d_pad = 4096
f_pad = 16384            # 14336.next_power_of_two()
q_pad = 32 * 128         # h_pad 32 x head_dim 128 = 4096, no query padding
kv = 8 * 128             # 1024, Dom::Kv does not pad
words = {
    "wq": q_pad * d_pad, "wo": q_pad * d_pad,
    "wk": kv * d_pad, "wv": kv * d_pad,
    "gamma_a": d_pad, "gamma_m": d_pad,
    "wg_t": d_pad * f_pad, "wu_t": d_pad * f_pad, "wd_t": f_pad * d_pad,
}
total = sum(words.values())
print("padded public int8 words a block:", total, "(A20 README: 243,277,824 B)")
assert total == 243_277_824

# off-support entries scanned by weights_vanish_off_support (private_block.rs:510-548): only Dom::F pads
f_off = f_pad - 14336                      # 2,048 off-support F indices
vanish = d_pad * f_off * 2 + f_off * d_pad  # wg_t, wu_t: every row x 2048 tail; wd_t: 2048 whole rows
print("vanish-scan entries a check_for_shape:", vanish)

# ---- 2. how often each runs on one block, in the D12a serial and the D55 verifier of the 8B test
checks_per_block = 2        # fit_the_stages (run.rs:1131-1133) or preflight (run_fork.rs:1184) + verify_core (protocol.rs:4332)
registry_per_block = 23 + checks_per_block   # define_changed, every slot (argument_accuracy.rs:19), + one inside each check
folds_per_block = 7         # argument.rs:3249 (Q,K,V,O) and :3390 (Gate,Up,Down); verifier mode = fold_with_mode(fast=false)

# ---- 3. rates
# BLAKE3: MEASURED, A21 README 2.1: one-pass digest of the 243 MB block 115.3 ms (0.474 ms/MB, includes byte copies);
# tick 58: 0.53 ms/MB (the spike's absorb record).
b3_lo, b3_hi = 0.474, 0.53
digest_one = (total / 1e6 * b3_lo, total / 1e6 * b3_hi)
print("block digest, one pass one thread: %.1f to %.1f ms (0 in the 8B test: RepeatBlock caches it, run_fork.rs:1109)" % digest_one)

# ASSUMED scan rates (one thread)
minscan_gbs = (8.0, 25.0)          # slice::contains(&i8::MIN) over 1 MiB chunks (private_block.rs:935, accuracy_fold.rs:45-48)
vanish_ns = (0.5, 1.0)             # indexed any() over the 2,048-entry tail, 16.8 M entries (wg_t, wu_t)
vanish_dense_ns = (0.05, 0.2)      # row.iter().any(|v| *v != 0) over the 8.4 M off-support wd_t entries
fold_ns = (0.25, 0.6)              # zero-skip scalar loop of fold_rows_deferred / fold_cols_deferred (mle.rs:245-319), per entry

def ms(x):  # tuple of ns-total -> ms
    return tuple(v / 1e6 for v in x)

# ---- 4. bottom-up, ms a block, one thread
# 4a. the two checks
scan_one = tuple(total / (g * 1e9) * 1e3 for g in reversed(minscan_gbs))        # (fast, slow) -> low, high
vanish_one = (d_pad * f_off * 2 * vanish_ns[0] / 1e6 + f_off * d_pad * vanish_dense_ns[0] / 1e6,
              d_pad * f_off * 2 * vanish_ns[1] / 1e6 + f_off * d_pad * vanish_dense_ns[1] / 1e6)
checks = tuple(checks_per_block * (a + b) for a, b in zip(scan_one, vanish_one))
print("2 checks: min-scan %.1f to %.1f ms, vanish %.1f to %.1f ms (both checks) -> %.1f to %.1f"
      % (scan_one[0] * 2, scan_one[1] * 2, vanish_one[0] * 2, vanish_one[1] * 2, checks[0], checks[1]))

# 4b. check_for_registry x 25: A18 README 2.4 (about 3 ms for 23) to A18 stage-1 profile (0.017 s main line; 2.15 CPU-s a call / 32 = 67 ms)
reg = (3.0 * 25 / 23, 2.15 / 32 * 1e3 * 25 / 23)
print("registry x25: %.1f to %.1f ms (A18: ~3 ms for 23; 2.15 CPU-s/32 blocks = 67 ms; main line 17 ms)" % reg)

# 4c. seven folds: a has_i8_min scan then the zero-skip fold, each over the whole padded matrix
fold_min = scan_one
fold_loop = (total * fold_ns[0] / 1e6, total * fold_ns[1] / 1e6)
folds = (max(fold_min[0] + fold_loop[0], 1.44e3 / 32), fold_min[1] + fold_loop[1])  # floor: A18's 1.44 CPU-s a call / 32 = 45 ms
print("7 folds: min-scan %.1f to %.1f + loop %.1f to %.1f -> %.1f to %.1f ms (floor 45 ms from A18/A14 prover CPU-s)"
      % (fold_min[0], fold_min[1], fold_loop[0], fold_loop[1], folds[0], folds[1]))

# 4d. M opening (zk.rs:1241-1282): 2*23 weight + q + prox encodes of size 4096 = 50 forward NTTs
enc = 2 * 23 + 2 + 2
bf = 12 * 2048
mver = (enc * (bf * 2.11 + 4096 * 1.12) / 1e6, enc * (bf * 2.67 + 4096 * 1.12) / 1e6)
mver = (mver[0] + 0.3, mver[1] + 1.0)   # + weight_polys, hashing 256 columns x 50 words, 256 paths (small; ASSUMED)
print("M opening: %d encodes x %d butterflies; %.1f to %.1f ms" % (enc, bf, mver[0], mver[1]))

low = checks[0] + reg[0] + folds[0] + mver[0]
high = checks[1] + reg[1] + folds[1] + mver[1]
print("bottom-up non-PCS total (checks + registry + folds + M), one thread: %.1f to %.1f ms" % (low, high))

# ---- 5. top-down: the measured total less the PCS parts tick 60 counted
T = 275.5                      # MEASURED, results/zk60_verify_threads_20261125 (sparse column loop, one thread, diagonal weights)
ntt = (75.0, 94.0)             # tick 60 section 3, DERIVED from counts x rates of other loops (not measured on the verifier)
hashing = 6.1                  # tick 60 section 4, columns and paths that stay
absorb = 6.1                   # MEASURED, prover-side absorb of 12.5 MB (tick 58)
inner = 3.7                    # tick 60, 737,280 Fp2 products at 5 ns (ASSUMED)
# sparse column products: at least the 1.43 M proximity products; rate from the measured dense-minus-sparse saving:
dense_minus_sparse = 402.8 - 275.5     # MEASURED 127.3 ms a block
prod_dense, prod_sparse_floor = 33.20e6, 1.43e6
rate_floor = dense_minus_sparse / (prod_dense - prod_sparse_floor) * 1e6      # ns a product, at least
print("measured sparse saving implies >= %.2f ns a column product (tick 60 assumed 2 x 1.12 = 2.24)" % rate_floor)
cols_floor = prod_sparse_floor * rate_floor / 1e6
print("proximity products alone: >= %.1f ms" % cols_floor)
pcs_counted = (ntt[0] + hashing + absorb + inner + cols_floor, ntt[1] + hashing + absorb + inner + cols_floor)
resid = (T - pcs_counted[1], T - pcs_counted[0])
print("PCS parts counted: %.1f to %.1f ms; residual (non-PCS + the nonzero-row column work + whatever is uncounted): %.1f to %.1f ms (width %.1f)"
      % (pcs_counted[0], pcs_counted[1], resid[0], resid[1], resid[1] - resid[0]))

# ---- 6. both together
lo = max(low, 0.0)
hi = min(high, resid[1])
print("non-PCS block time, bottom-up capped by the residual: %.1f to %.1f ms (width %.1f); item's line is under 15 ms wide: %s"
      % (lo, hi, hi - lo, "PASS" if hi - lo < 15 else "FAIL"))
print("share of the measured 275.5 ms: %.0f%% to %.0f%%" % (lo / T * 100, hi / T * 100))
print("tick 60 had 'stays' (non-PCS + hashing) at 6.1 to 23.9 ms; here stays = %.1f to %.1f ms" % (lo + hashing, hi + hashing))

# ---- 7. what B6a would leave of the block, as a consequence (DERIVED, not a claim: rests on the ASSUMED NTT term)
removed = (ntt[0] + absorb + inner + cols_floor, ntt[1] + absorb + inner + cols_floor)
bat_tower = (28.3, 57.2)   # tick 58 section 4 and 3: rational switch row (flat 28.3 to 29.3) to the optimized build at rate 1/2 (57.2)
b6a = (T - removed[1] + bat_tower[0], T - removed[0] + bat_tower[1])
print("one-thread block under B6a: %.0f to %.0f ms; gain over 275.5: x%.2f to x%.2f (tick 58 said x1.6 to x3.1 on the withdrawn 141.9)"
      % (b6a[0], b6a[1], T / b6a[1], T / b6a[0]))

# ---- 8. bytes read a block by the non-PCS scans
mb = (checks_per_block * total + folds_per_block * 0 + total + total + checks_per_block * (16.8e6 + 8.4e6)) / 1e6
print("bytes read a block by the scans: %.0f MB (2 checks' min-scan, the folds' min-scan and loop, 2 x 25.2 MB vanish)" % mb)

# ---- 9. real verifier with the digest: where a source hashes (stack-verify, preflight check_digests=true)
for n in (1, 2):
    print("digest x%d: %.0f to %.0f ms a block" % (n, n * digest_one[0], n * digest_one[1]))
