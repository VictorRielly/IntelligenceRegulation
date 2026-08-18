# U-PERF2 lane J — AVX2 in the packed K-field lane kernels (descent rounds, folds, tree steps, ixf rounds)

Branch `uperf2-j` (worktree /home/victor/wt-uperf2-j), opened at bd5e0dd
on 2026-08-17. Ledger: PROGRESS_UPERF2.md "Lane J" + "Agent J status".
Box: the WSL box (Intel Core Ultra 9 185H — 6 P + 8 E + 2 LP-E cores as
22 threads, 15 GB; AVX2, no AVX-512; the local m125 re-export is here, so
the 3x16 / 12x128 / 12x512 real-data rigs run). Every number carries
`[WSL-BOX 1T|NT, QUIET|NOISY-SHARED]`; lane K (the GPU rung) builds and
runs in its own worktree during this session.

## 0. One paragraph

(SKELETON — filled at close.)

## 1. Plan (the skeleton commit)

1. Profile the K-field lane kernels' inner loops as compiled today
   (`k9_kernel!` bodies under `#[target_feature(enable = "avx2")]`,
   auto-vectorized): a `uperf-j bench` arm times, per pair-block / per
   block, the 16x16 lane MAC (`mac_block`), the deferred reduction
   (`red_block`), the fixed-operand multiply, the fold, the tree step,
   the five-table node loop, the fused FOLD round and the ixf round —
   and says which is MAC-bound and which reduction-bound. Disassembly of
   the current AVX2 instantiation is the second witness.
2. Design (decided by the profile + microbench): the u32 lanes map to
   AVX2 as the natural u64-lane pairs of a row (`vpmuludq` reads the low
   32 bits of each 64-bit lane: the "even" form is the row itself, the
   "odd" form is the row shifted right by 32), operands staged in a
   fixed working lane order obtained by two `vshufps` per row from the
   (2m, 2m+1) block pair, register-resident output-stationary
   accumulation (per output coefficient t: bursts of <= 4 products, each
   < 2^62, summed exactly in u64 and folded once by 2^32 == c32 into a
   single u64 accumulator < 2^46), and hand-written reductions whose
   every output is the canonical representative of the same field
   expression the scalar `red_block` / finalize produce (uniqueness of
   canonical representatives = bit identity). The fixed-operand multiply
   (folds, eq doubling, PL) uses the 16x16 canonical matrix of the
   fixed element (Y^16 = s folded into the matrix), so its reduction has
   no h-step. The persistent node planes keep the scalar lo/hi split
   layout with the SAME exact integer per lane word (finalize input
   identical).
3. Land it behind runtime `is_x86_feature_detected!("avx2")` +
   `ZK_KSIMD=0` (scalar path = today's bodies, the one-binary A/B),
   `asm!("vpmuludq")` as lane I did. NEON mirror only if cheap
   ([UNTESTED-NEON]).
4. Batteries: `uperf-j battery` (random + planted extremes, kernel by
   kernel, scalar == AVX2 bit-for-bit, planes identical per lane word),
   `uperf-a` 18/18, `uperf-g` 22/22, `uperf-h` (24 x 8 ways), `uperf-d`
   30/30 at ZK_THREADS 1/2/7 with and without `ZK_KSIMD=0`; the
   descent-bench digest 47a58a27..; `uperf-pc diff-battery`; freeze rows
   (98, captured BEFORE any change: scratchpad j_freeze_baseline.txt);
   `self-test`. Rigs: REAL 3x16 1T/8T, 12x128 8T, ONE 12x512 8T.
5. This report + "Agent J status" in the ledger. Stop early with the
   finding if a fair attempt buys < 1.3x on the dominant kernel.

## 2. Profile of the kernels as compiled today

(to be filled)

## 3. Method

(to be filled)

## 4. Measurements

(to be filled)

## 5. Differential evidence + gates

(to be filled)

## 6. The REAL rigs

(to be filled)

## 7. What is left

(to be filled)
