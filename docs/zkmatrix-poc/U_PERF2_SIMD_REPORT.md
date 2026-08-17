# U-PERF2 lane I — SIMD Goldilocks NTT (the length-128 transform every NTT-domain kernel pays)

Branch `uperf2-i` (worktree /home/victor/wt-uperf2-i), opened at d38e9ce
on 2026-08-17. Ledger: PROGRESS_UPERF2.md "Lane I" + "Agent I status".
Box: the WSL box (Intel Core Ultra 9 185H — 6 P + 8 E + 2 LP-E cores as
22 threads, 15 GB; AVX2 + BMI2 + ADX, NO AVX-512 / IFMA per
`/proc/cpuinfo`; the local m125 re-export is here, so the 3x16 and 12x64
real-data rigs run). Lane H (descent tree memory) builds and runs its
rigs concurrently: every number below is `[WSL-BOX ... NOISY-SHARED]`
unless marked QUIET; the scalar/SIMD pairs are taken back-to-back in
ONE process (`uperf-i bench`), so the ratios are trustworthy while the
absolute microseconds move between repeats.

## 0. One paragraph

(status: SKELETON — filled in as steps land)

## 1. Plan (skeleton commit)

1. `aux_ntt_core.rs` (additive): `ntt_fwd_avx2` / `ntt_inv_avx2` —
   the SAME DIT forward / GS inverse of length 128 (same butterflies,
   same twiddle order, same output order, final scale by 1/n) on 4 x
   u64 AVX2 lanes: the 64x64 -> 128 product from four `_mm256_mul_epu32`
   32-bit partial products, the Goldilocks reduction
   `lo + EPS*hi_lo - hi_hi` with the compare-based branchless
   conditional subtracts of the scalar `gl_*` forms (unsigned u64
   compare = signed compare on sign-flipped values), every op yielding
   the CANONICAL value in [0, p) — so the vector transform's values are
   identical to `ntt_fwd_fast` / `ntt_inv_fast` by the uniqueness of
   canonical representatives, not by luck. Twiddle layout: stages with
   few distinct twiddles broadcast one twiddle per group (hoisted
   `w`, `w >> 32`); the last two forward stages (32 and 64 twiddles,
   pairs inside a 4-lane vector) run on a permute2x128 / unpack lane
   split with contiguous loads from SIMD-layout twiddle tables built
   once in `NttTables`. NEON (`cfg(target_arch = "aarch64")`, 2 x u64,
   `vmull_u32`) mirrors the same structure — [UNTESTED-NEON], compiled
   out on x86. Dispatch `ntt_fwd_best` / `ntt_inv_best`:
   `is_x86_feature_detected!("avx2")` (a compile-time `true` under this
   crate's `target-cpu=native`) AND `ZK_NTT_SIMD != 0` (the one-binary
   A/B knob), else the scalar `ntt_fwd_fast`.
2. The 7 call lines in `eval_proof.rs` (`ntt_gemm_modq_small_gen`
   forward + flush inverse; `fwd_small`, `fwd_modq`, `fwd_modq_limbs`
   x2, `flush_split`) switch to `_best`; nothing else there.
3. `uperf-i battery`: fwd/inv identity vs `ntt_fwd_fast`/`ntt_inv_fast`
   on planted extremes (all-0, all-1, all-(p-1), 2^32, 2^32-1, EPS
   multiples, mixed) + 4096 random rings, round-trip; at ZK_THREADS 1.
4. `uperf-i bench`: us per transform scalar vs SIMD (1e5 rings) +
   `uperf-pc kernel-bench 64 8192 noref`, `uperf-pc kpass-bench 512 2048
   noref`, `uperf-c bench` under `ZK_NTT_SIMD=0/1`, then the REAL rigs
   3x16 (1T/8T) and 12x64 (8T) with digests.
5. Gates at HEAD: `uperf-i battery`, `uperf-pc diff-battery`, `uperf-c
   diff-battery`, `uperf-f diff-battery`, freeze-check 98 rows ==
   baseline (captured from the d38e9ce binary before any code change:
   scratchpad/i_freeze_baseline.txt), `self-test`, rig digests.
6. Stop rule: if AVX2 buys < 1.3x on the transform after a fair
   attempt, report the finding and stop.

## 2. What landed

(pending)

## 3. Differential evidence

(pending)

## 4. Measurements

(pending)

## 5. What is left / honest state

(pending)
