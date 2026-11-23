"""Tick 46 (queue item 75): thread-group memory per kernel, bytes per thread, the T-occ elasticity and the
ceilings of the two proposed tests. Standard library only; reads no file; prints every number in the handoff.
Run: python3 -I -B 20261123-claude-tick46-tg-memory.py
"""
import math

# ---- COUNTED (metal_kernels.metal, metal.rs, metal_slot.rs; lines in the handoff) -----------------------------
TILE = 2048
rows = [
    # name, bytes per group, threads per group
    ("k_fold_sparse_partial, A (k=37)", 37 * 32 * 16, 32),
    ("k_fold_sparse_partial, H (k=10)", 10 * 32 * 16, 32),
    ("k_ntt_head_t / k_ntt_tail / k_inv_fwd_fused_t", TILE * 8, 512),
    ("k_sc_fs_step (one group)", 2 * 256 * 8 + 16 * 8, 256),
    ("k_sc_round0 / k_sc_round (generated)", 0, 64),
    ("k_sc_part_reduce, k_fold_tables_dev3, k_hash_cols", 0, 0),
]
print("bytes per group and per thread")
for n, b, t in rows:
    print(f"  {n:52s} {b:7d} B  threads {t:4d}  B/thread {b / t if t else float('nan'):7.1f}")
wp_sg = (64 * 32 + 64 * 32 + 32 * 64 + 8 * 64) * 4
wp_int = 2 * 32 * 64 * 4
print(f"  wprod sg kernels {wp_sg} B, wprod int kernel {wp_int} B (sealing products, outside tick 40's list)")

# ---- MEASURED (coordination 2026-11-23T07:19:57Z, T-occ) ------------------------------------------------------
tH_small, tH_big = 1.861, 6.057       # ms, H capture, 5,120 B and 18,944 B allocation
ratio_t = tH_big / tH_small
ratio_b = 18944 / 5120
el = math.log(ratio_t) / math.log(ratio_b)
print(f"\nT-occ: time ratio {ratio_t:.3f}, allocation ratio {ratio_b:.3f}, elasticity {el:.2f}")

# ---- DERIVED: what each test's pass line is worth ---------------------------------------------------------------
D1 = 98.541                    # ms one-lane device demand per block (tick 40)
ntt = 14.0 + 8.3               # ms per block, forward + inverse NTT (tick 21 diag split, 8B)
print(f"\nNTT ms per block {ntt:.1f} = {100 * ntt / D1:.1f}% of D1 {D1}")
for r in (1.15, 1.25, 1.30, 1.50):
    g = ntt * (1 - 1 / r)
    print(f"  doubling the allocation costs x{r:.2f} -> ceiling saved by halving it (ASSUMED symmetric) {g:.2f} ms = {100 * g / D1:.1f}% of D1")
five = 0.05 * D1
r5 = 1 / (1 - five / ntt)
print(f"  5% of D1 = {five:.2f} ms; r at which the NTT ceiling reaches it: {r5:.3f}")

zc = 21.42 + 16.31 + 7.63 + 5.68 + 3.05 + 1.91 + 4.03   # slots 18, 14, 17, 15, 16, 0, 19 one lane (tick 40 table)
print(f"\nzero-check round slots 18,14,17,15,16,0,19: {zc:.2f} ms = {100 * zc / D1:.1f}% of D1")
for r in (1.05, 1.10, 1.25):
    g = zc * (1 - 1 / r)
    print(f"  ladder ratio x{r:.2f} at 32 KB -> if all of it were removable {g:.2f} ms = {100 * g / D1:.1f}% of D1 (an upper bound, not a promise)")
for L in (2048, 4096, 8192, 16384, 32768):
    print(f"  ladder L={L:6d} B per 64-thread group = {L / 64:6.1f} B/thread")

# ---- COUNTED barriers per launch -------------------------------------------------------------------------------
print("\nbarriers per launch")
head = 1 + 5 + 1
print(f"  head, L=11, r4, plain: {head}; pruned: {head - 1}")
for G in (1, 2, 3, 4):
    print(f"  tail, G={G}: {1 + G // 2 + G % 2}")
for n_sub in (2, 4):
    print(f"  fused, n_sub={n_sub}: {7 + 5 * n_sub + (n_sub - 1)}")
for d1 in (4, 5, 6):
    print(f"  k_sc_fs_step at tgw=256, d1={d1}: {d1 * (1 + int(math.log2(256)) + 1)} barriers per round")
