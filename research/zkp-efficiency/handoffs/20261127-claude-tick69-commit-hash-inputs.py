#!/usr/bin/env python3
"""Tick 69 (queue item 109): what the commitment hash kernel reads at the W16R2 block, and the
rates that follow. Pure arithmetic over counted shapes and cited measurements; nothing is run on the GPU.

Inputs and where each comes from:
  rows A, H = 2504, 2606      MEASURED: `commit rows=...` trace detail, results/zk60_w16r2_shield_block_20261120/summary.json
                              (a_commit_rows 2504, other_commit_rows [2606]); census model says 2501 / 2602 (census.log:218)
  n = 2^14, nn = 2^15         COUNTED: log line `commit 2504 x 2^14 -> 2^15`; pcs params
  diag hash A, H (ms)         MEASURED: tick 21 (1.660, 1.727; old k_hash_cols form, W16R2_8B arm)
  diag forward A, H (ms)      MEASURED: tick 21 (6.90, 7.13; MODE_PLAIN, pruned head)
  bench at classifier A shape MEASURED: results/zk60_a28_app_20261107/nb3.log (4577 rows x 2^14 -> 2^16)
"""
import math

W = 8  # bytes per Goldilocks word


def blocks_and_parents(rows):
    total = rows * W
    chunks = -(-total // 1024)
    last = total - (chunks - 1) * 1024
    blocks = (chunks - 1) * 16 + -(-last // 64)
    parents = chunks - 1
    return total, chunks, blocks, parents, blocks + parents


print("== 1. words the kernel hashes a block ==")
nn = 1 << 15
tot_words = 0
tot_comp = 0
tot_cvs = 0
for name, rows in (("A", 2504), ("H", 2606)):
    total, chunks, blocks, parents, comp = blocks_and_parents(rows)
    words = rows * nn
    tot_words += words
    tot_comp += comp * nn
    cvs = nn * chunks * 32
    tot_cvs += cvs
    perm = math.ceil(rows / 8)  # Poseidon2-style sponge, rate 8, one permutation per 8 words
    print(f"  {name}: rows {rows}, column {total} B = {chunks} chunks, {blocks} blocks + {parents} parents = {comp} compressions a column;"
          f" words {words:,} ({words*W/1e6:.1f} MB); chunk-pass threads {nn*chunks:,}; cvs buffer {cvs/1e6:.2f} MB; sponge permutations a column {perm}")
print(f"  total words {tot_words:,} = {tot_words/1e6:.2f} M ; bytes {tot_words*W/1e6:.1f} MB ; vs 167.22 M: {100*(tot_words/167.22e6-1):+.2f}%")
print(f"  BLAKE3 compressions a block (columns only) {tot_comp:,}")
cens_words = (2501 + 2602) * nn
print(f"  census rows 2501+2602 -> {cens_words:,} words ({100*(cens_words/tot_words-1):+.2f}% vs traced rows)")
print(f"  extra traffic of the two-pass form: cvs written then read: 2 x {tot_cvs/1e6:.1f} = {2*tot_cvs/1e6:.1f} MB ({100*2*tot_cvs/(tot_words*W):.1f}% of the column bytes); leaves 2 x {nn*32/1e6:.2f} MB")
sponge_perm = sum(math.ceil(r / 8) * nn for r in (2504, 2606))
print(f"  sponge permutations a block at rate 8 (columns only): {sponge_perm:,}")
mults = sponge_perm * 736
print(f"  multiplications at 736 a permutation (ASSUMED count, structure of width-12 x^7 Poseidon2): {mults/1e9:.2f} G")

print("\n== 2. bytes a second ==")
bytes_ah = tot_words * W
hash_old = 1.660 + 1.727
print(f"  diag old form (k_hash_cols), tick 21 W16R2 arm: {hash_old:.3f} ms -> {bytes_ah/hash_old/1e6:.0f} GB/s; per row A {1.660/2504*1e3:.3f} us, H {1.727/2606*1e3:.3f} us (linear in rows)")
print(f"    compressions a second: {tot_comp/hash_old/1e6:.2f} G/s")
# classifier-shape bench
rows_c, nn_c = 4577, 1 << 16
tot_c, ch_c, bl_c, pa_c, comp_c = blocks_and_parents(rows_c)
bytes_c = rows_c * nn_c * W
print(f"  bench (nb3.log): {rows_c} rows x 2^16 cols = {bytes_c/1e6:.1f} MB, {ch_c} chunks a column, {comp_c} compressions a column, {comp_c*nn_c/1e6:.2f} M compressions")
for lab, ms in (("old k_hash_cols", 5.469), ("two-pass chunk+merge", 4.237), ("chunk pass only", 3.951)):
    print(f"    {lab}: {ms} ms -> {bytes_c/ms/1e6:.0f} GB/s, {comp_c*nn_c/ms/1e6:.2f} G compressions/s")
ratio = 4.237 / 5.469
print(f"  two-pass / old ratio at the bench shape {ratio:.3f}")
two_lo = bytes_ah / (bytes_c / 4.237)  # ms, at the bench's two-pass byte rate
print(f"  production two-pass at W16R2 (not measured here), three ways:")
print(f"    (a) old diag x ratio: {hash_old*ratio:.2f} ms -> {bytes_ah/(hash_old*ratio)/1e6:.0f} GB/s")
print(f"    (b) at the bench two-pass byte rate ({bytes_c/4.237/1e6:.0f} GB/s): {two_lo:.2f} ms")
print(f"    (c) at the README's 'about 500 GB/s': {bytes_ah/500e9*1e3:.2f} ms")
print(f"    against the 700 GB/s copy roofline: floor {bytes_ah/700e9*1e3:.2f} ms; old diag at {100*bytes_ah/hash_old/1e6/700:.0f}% of it, two-pass {100*bytes_ah/(hash_old*ratio)/1e6/700:.0f}%")
print(f"  tick 67's 3.9 ms (scaled share of a trace's 29.15 ms): {bytes_ah/3.9/1e6:.0f} GB/s")

print("\n== 3. the forward NTT behind the 14.0 ms ==")
fwd = 6.90 + 7.13
rows_ah = 2504 + 2606
bf_full = rows_ah * (1 << 14) * 15
print(f"  rows {rows_ah} (2504 + 2606) x 2^15 points: {bf_full/1e6:.1f} M butterflies unpruned; diag forward {fwd:.2f} ms -> {bf_full/fwd/1e6:.1f} G/s")
bf_pr = bf_full * 13 / 15
print(f"  diag is MODE_PLAIN, the A28 pruned head applies (extent 2^14 <= 2^14): at most 2 of 15 stages skipped -> >= {bf_pr/1e6:.0f} M butterflies, {bf_pr/fwd/1e6:.1f} G/s; so 78 to 90 G/s")
bf_b = rows_c * (nn_c // 2) * 11
print(f"  bench: head 11 of 16 stages = {bf_b/1e6:.1f} M butterflies; head 19.588 ms -> {bf_b/19.588/1e6:.1f} G/s; pruned 16.907 -> {bf_b/16.907/1e6:.1f}")
for lab, ms in (("butterfly mul+add+sub, in registers", 15.723), ("add+sub only", 10.355), ("mul only (gl_mul + one xor)", 13.155)):
    print(f"    probe {lab}: {ms} ms -> {bf_b/ms/1e6:.1f} G/s")

print("\n== 4. what the measured rates do to tick 67 section 3 ==")
b3 = 2.4
for lab, rate in (("478 G/s ASSUMED hardware ceiling (tick 67 low end)", 478e9), ("125.4 G/s measured gl_mul alone", bf_b / 13.155 * 1e3),
                  ("105 G/s measured butterfly in registers", bf_b / 15.723 * 1e3), ("84 G/s measured forward head", bf_b / 19.588 * 1e3), ("89.6 G/s diag-implied (tick 67)", 89.6e9)):
    ms = mults / rate * 1e3
    print(f"  {lab}: {ms:.0f} ms a block; extra over a 2.4 to 2.7 ms BLAKE3 pass {ms-2.7:.0f} to {ms-2.4:.0f} ms; x32 blocks {32*(ms-2.7)/1e3:.1f} to {32*(ms-2.4)/1e3:.1f} s a request")
print(f"  share of 91.46 ms block GPU at 123 ms: {100*123/91.46:.0f}%; at 183 ms: {100*183/91.46:.0f}%")
print(f"  host Merkle build and salted leaves a block (both commits): {2*(nn + (nn-1))/1e3:.1f} K compressions = {100*2*(2*nn-1)/tot_comp:.2f}% of the kernel's (host, not in this kernel)")
