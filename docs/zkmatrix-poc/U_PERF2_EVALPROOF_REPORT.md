# U-PERF2 lane C — eval-proof leftovers (fold NTT, transport limb-split NTT, compute_psi, digit-split threads) and the transform finding

Status: CLOSED 2026-08-17 (all deliverables landed; commits ed5b3b0,
b707af1, fa3340f + the report commit on uperf2-c). Written by lane C of the U-PERF2 round (ledger:
PROGRESS_UPERF2.md, "Lane C — EVAL-PROOF LEFTOVERS" + "Agent C status").
Worktree /home/victor/wt-uperf2-c, branch uperf2-c, opened at c46483a.
Every number below is labeled [WSL-BOX <n>T, QUIET|NOISY-SHARED]; the
WSL box is Intel Core Ultra 9 185H (3.07 GHz as seen by WSL), 22
threads, 15 GB, no m125 export — nothing here is a rig number, and the
Mac projections are [MODEL]. Lane A built and benched concurrently for
most of the session, so the 1T kernel timings carry NOISY-SHARED unless
stated; the RATIOS (fast vs oracle in the same run) are what to read.

The rule (unchanged from Phase 0): every optimization is DIFFERENTIAL —
the pre-change body stays reachable as `*_ref` and under
`ZK_UPERF_ORACLE=1`; the outputs are byte-identical; the battery holds
at ZK_THREADS 1/2/7; freeze-check's 98 on-box rows are identical to the
pre-change capture.

## 0. Items and where they land

| item | function (eval_proof.rs) | oracle | call sites | status |
|---|---|---|---|---|
| T7 fold | `fold_chunks_ntt` | `fold_chunks_ref` (the `poly_mul_small` loop) | `bg_fold`, `agg_fold` (bin) | LANDED |
| T3b transport | `transport_level_from_psi` -> `transport_level_from_psi_fast` + `ntt_combine_general` | `transport_level_from_psi_ref`, `ntt_combine_general_ref` | prover levels >= 1 (`transport_level`), verifier level 1 (`transport_level_from_psi`) and deeper | LANDED |
| psi | `compute_psi` -> `compute_psi_ntt` | `compute_psi_ref` | prover `transport_level`, verifier floor psi, batteries | LANDED |
| digit splits | `decompose_polys_modq` / `decompose_polys_small` (parallel over rings, order preserved) | the per-ring `decompose_poly_*` serial loops | `bg_matvec_chunks`, `bg_level_h`, `bg_fold`, `agg_level_t`, `agg_level_h`, `agg_fold` | LANDED |
| **the transform** (finding, Section 1) | aux_ntt_core.rs `gl_add/gl_sub/gl_reduce128/gl_mul`, `ntt_fwd_fast/ntt_inv_fast` (additive) | `add_p/sub_p/reduce128/mul_p`, `ntt_fwd/ntt_inv` (untouched) | EVERY eval_proof.rs NTT-domain kernel incl. Phase 0's `ntt_gemm_modq_small` | LANDED |

Harness: `ring_matmul uperf-c diff-battery | bench [r] [chunk] [noref] |
ntt-bench [n]` (bin section `// [UPERF2-C]`).

## 1. FINDING (load-bearing for every NTT-domain kernel): the length-128 Goldilocks transform cost 4.35 us, not ~0.35 us

`uperf-c ntt-bench 200000` [WSL-BOX 1T, NOISY-SHARED], per ring:

| primitive | before | after (branchless) | note |
|---|---:|---:|---|
| `ntt_fwd` (aux) | 4.35 - 5.04 us | `ntt_fwd_fast` **1.50 us** | identical values (battery leg, 504 rings incl. all-0 / all-(p-1) / all-1 / all-EPS) |
| `ntt_inv` (aux) | 5.15 - 5.55 us | `ntt_inv_fast` **2.07 us** | identical values; round trip asserted |
| split-halves MAC, 128 coeffs | 0.17 - 0.27 us | (unchanged) | ~1.5 ns/term |
| `poly_mul_small` (quinary x digits) | 7.7 - 10.2 us | — | the T7 oracle's unit |
| `ring_mul_split_kara_fast` general x general | 4.1 - 4.4 us | — | the T3b oracle's unit |
| `ring_mul_split_kara_fast` general x small | 4.6 - 4.8 us | — | the psi oracle's unit |

What it was: the butterfly loop compiled the carry/borrow selects of
`add_p` / `reduce128` (`(borrow as u64) * EPS`, `if borrow { .. }`) to
data-dependent branches (`jb` + `xor` in the disassembly, 4 per
butterfly); on random data those mispredict, ~40 cycles per butterfly.
A first "branchless" rewrite with mask selects was folded back into the
same branches by LLVM. The form that stays branchless here: u128 sums +
COMPARE-based conditional subtracts (`if s >= P { s - P }` compiles to
cmp/sbb/cmov), i.e. `x = lo + EPS*hi_lo + (p - hi_hi)` as three
non-negative u128 terms then two conditional subtracts (2p, p). The
inner loop is now ~45 instructions, cmov/setb/sbb only, ~10 cycles per
butterfly. The remaining cost is instruction throughput; a Shoup-
constant twiddle multiply would save ~6 of the 45 and SIMD would be the
real next step (not this round).

Consequence: with the transform at 4.35 us a kernel that transforms
each operand ONCE could not beat schoolbook (7.7 us) or Karatsuba (4.1
us) — the first bench of the T7/psi/combine kernels measured 1.8x /
1.0x / 0.8x — while the Phase-0 kernels won only because their
transforms amortize over r = 64 (level-h) or kappa = 11 (matvec)
products. With the branchless transform every kernel wins, and the
Phase-0 kernels gain too (their per-product transform share drops 3x;
they are MAC-bound now).

## 2. Method notes (the exact identities each item relies on)

- T7: z_u = sum_j c_j (x) w_{j,u} over Z, |c| <= 2, |w| <= 2^(e-1) <= 64:
  every coefficient of the true integer result is bounded by r * D *
  cmax * wmax (<= 2^21 in the composed pass, checked EXACTLY from the
  data bounds against (p-1)/2, oracle otherwise), so its image mod p
  determines it and `center_from_p` recovers it. c transformed once,
  each w once, r-term split-halves MAC, one inverse per output.
- T3b: in Z_q, with radix a scalar and c_j small, a*(radix*X) =
  radix*(a*X), a*(-radix*c_j) = (-radix)*(a*c_j), a*(const radix) =
  radix*a; so every next-witness ring is a scalar multiple of a per-
  SOURCE ring: Z-ring (src, limb) = radix_limb * S[src] with S[src] =
  a_l1*psi[src] + sum_kap a_t4[kap]*A[kap][src]; T-ring = (-radix)*
  (a_t4[kap]*c_j) + T5[pos]; H-ring = [j=k] radix*a_t1 + (-radix)*
  (a_l1*cpair) + T5[pos]; T5[pos] = sum_kap2 a_t5[bi][kap2]*B_bi[kap2]
  [pos - col_base]. S and T5 are GEMV-shaped contractions of a few FIXED
  alphas against GENERAL mod-q operands -> `ntt_combine_general`: at q31
  the ONE-SIDED regime (only the alphas limb-split at L = 16; per
  operand ONE forward transform; two in-domain accumulations a0*b, a1*b
  each exact by capacity for n <= 2048 terms; two inverses; out = V0 +
  2^L V1 mod q); at q46 the TWO-SIDED Karatsuba regime (both split, 3
  sub-products, 3 inverses — the `A1LimbCommitKernel` contract, n <=
  1024); the oracle if neither fits. The two small-operand families
  (a_t4[kap]*c_j, a_l1*cpair) ride `ntt_gemm_modq_small`; assembly is a
  fixed-order mod-q sum of scalar multiples (`scale_exact` == poly_scale).
  h_next stays the reference sum (1 + 11*n_bindings products).
- psi: Psi_u = sum_k c_k * phi[k*chunk+u], small x general, r <= 64
  terms: the single-prime window (`ntt_window_terms(q, |c|max)`, >= 1024
  at q46) covers it; oracle over capacity.
- Threads: `map_ordered` (rayon indexed collect over outputs, on the
  `ZK_THREADS` pool) — every output computed whole by one thread from
  the same term list; identical for any thread count.

## 3. Differential evidence (all at HEAD of uperf2-c)

- `uperf-c diff-battery` at ZK_THREADS 1, 2, 7 (three runs each state):
  GL primitives (planted extremes + random, transforms on 504 rings incl.
  extremes); T7 fold 34/34 (e = 1..7, zero rings/slices, r <= 64, the
  >2^48 fallback, `bg_fold` fast-vs-oracle flip on schedule-derived
  plans); T3b combine 14/14 (one-sided + two-sided regimes at q31 AND
  q46, the n = 2100 two-sided-at-q31 and n = 1100 fallback-at-q46 legs);
  T3b transport 40/40 (phi_next AND h_next byte-identical on
  schedule-derived level-0 plans n0 = 64..5000, e0 = 1/2/3/7, both
  binding forms (Bu+Bh and one combined B), zero rings, a zero alpha,
  every Z/T/H boundary of `NextLayout` walked, plus `transport_level`
  (compute_psi + transport) fast-vs-oracle flip on a ragged-tail phi);
  compute_psi 11/11 (tail chunks, zero rings, r <= 64, the |c| = 2^40
  fallback at q46); digit splits 12/12.
- `uperf-pc diff-battery` at ZK_THREADS 1, 2, 7: O1 4/4, O2 35/35, O3
  63/63, O5 12/12, E2E 2/2 (the whole bg_prove_group + bg_verify_group
  on the mixed-tensor group with the forced 2-level schedule, proven
  under oracle AND fast routing in one process — field-identical, both
  verify, cross-verify) — with the new fold, transport, psi, splits AND
  the fast transform inside Phase 0's `ntt_gemm_modq_small`.
- `agg-matmul battery` (exercises agg_fold / agg_level_t / agg_level_h /
  transport on the BD stack incl. Tier-Z and the tamper legs): passed,
  120.7 s. `bh-verifier battery`: passed, 14.3 s. freeze-check: 98 `ok`
  rows, IDENTICAL line-for-line to the capture taken from the untouched
  build before any code change (then the expected export panic — note:
  during the session an `results/m125_ffn_export/` directory appeared in
  the main checkout, so the post-change run panicked at "layer 0 X:
  export digest mismatch" instead of "cannot read layer00_X.bin"; that
  is the box, not this lane — the 98 rows are the gate and they match).

## 4. Kernel benches

`uperf-c bench 16 2048` [WSL-BOX 1T, NOISY-SHARED — lane A building],
oracle timed alongside in the same run, byte equality asserted:

| kernel | unit | fast | oracle | speedup |
|---|---|---:|---:|---:|
| T7 fold, e = 2 digits (level 0 class) | us per (c x w) product | 1.78 | 10.20 | 5.7x |
| T7 fold, e = 5 digits (interior) | us per product | 1.48 | 9.15 | 6.2x |
| compute_psi (r = 16 general phi, ragged tail) | us per (c x phi) term | 1.66 | 5.38 | 3.2x |
| `ntt_combine_general`, 12 terms (the S contraction) | us per general product (per output) | 2.08 (25.0) | 4.44 | 2.1x |
| transport level (chunk 2048, r 16, e_next 5, l_z 3, l_t = l_h 7, two bindings) | us per next-witness ring | 16.3 | 70.7 | 4.3x |

The same bench BEFORE the transform fix (same box state): fold 1.8x /
1.9x, psi 1.0x, combine 0.8x, transport 1.4x — the whole difference is
Section 1.

`uperf-c bench 64 8192` — the level-0 shape class (r = 64; n_0 = 524K
rings; transport n_total = 44,064 = 8192 x 3 + 64 x 11 x 7 + 2080 x 7)
[WSL-BOX, NOISY-SHARED — one foreign 1-core job resident]:

| kernel | unit | oracle 1T | fast 1T | 4T | 8T | 16T |
|---|---|---:|---:|---:|---:|---:|
| T7 fold e = 2 | us / (c x w) product | 9.65 | 2.20 (4.4x) | 0.70 | 0.56 | 0.52 |
| T7 fold e = 5 | us / product | 10.07 | 1.55 (6.5x) | 0.62 | 0.39 | 0.44 |
| compute_psi (64 x 8192, ragged tail) | us / (c x phi) term | 5.18 | 1.75 (3.0x) | 0.65 | 0.32 | 0.29 |
| `ntt_combine_general` 12 terms | us / general product | 4.92 | 2.45 (2.0x) | 0.72 | 0.47 | 0.38 |
| transport level (two bindings) | us / next-witness ring | 63.3 | 18.6 (3.4x) | 5.60 | 4.18 | 4.58 |

Thread scaling saturates around 4x at 8-16 threads on this box (hybrid
P/E cores, one core taken by a foreign job, and the fold/psi read 0.5-1
GB of rings per run); the split is per output so the Mac's cores scale
the same code without any change (bit-identical at any ZK_THREADS by
construction — the batteries at 1/2/7 are the proof).

Phase-0 kernels on the fast transform (`uperf-pc kernel-bench 64 8192
noref`) [WSL-BOX NOISY-SHARED]: level-h 0.183 us/product at 1T (ledger
0.238 QUIET -> ~1.3x; the r = 64 amortization already made it MAC-bound),
0.033 at 8T; matvec 0.277 at 1T (ledger 0.64 -> 2.3x), 0.098 at 8T. Both
legs of `uperf-pc diff-battery` re-verify them byte-identical.

## 5. Projected Mac deltas [MODEL — from the ratios; not a rig number]

Composed 125M prove at 1T (PROGRESS_UPERF 2026-08-17 model ~1,300-1,600
s after Phase 0), the terms this lane touched:
- fold `bg_fold` (n_0 = 7.8M act + weights, ~40-60 s at 8-10 us/product)
  -> ~6x: ~7-10 s at 1T; per-output parallel, so /ZK_THREADS on top.
- transport levels (prover AND verifier level 1, ~10-25 s each side per
  the ledger's model at ~4 us per general product; the l_z = 3
  regrouping is inside the 4.3x) -> ~4x: a few seconds each side, and
  threaded.
- prover `compute_psi` at level 1 (n_0 terms, ~35-45 s at 5.4 us) -> ~3x:
  ~12 s at 1T, threaded.
- Phase-0 level-h / matvec: transform share down 3x (MAC-bound now);
  matvec ~2x, level-h ~1.3x by the same arithmetic — to be re-measured
  on the rig (TASK_BOARD T1's A/B is still the honest test).
Sum on the touched terms: roughly 100 s -> ~25 s at 1T [MODEL]; the
descents (~630 s) and the commit phase remain the shares that matter,
as the priority table said.

## 6. What is left (honest state at close)

- The transform is now instruction-throughput bound (~45 instructions,
  ~10 cycles per butterfly at 3 GHz). Tried and dropped: Shoup-constant
  twiddle multiplies (fwd 1.30 vs 1.30 us, inv 1.79 vs 1.60 — the u128
  products cost what the reduction saved). The next real step is a SIMD
  (AVX2/AVX-512) Goldilocks butterfly — Plonky2-class 3-4x on the
  transform, which every NTT-domain kernel here would inherit
  unchanged (values identical by construction, battery-checked). Not
  this round.
- A 31-bit-prime NTT for the SMALL x SMALL fold only (|z| <= 2^21 fits
  one 31-bit prime; ~3x cheaper butterflies, autovectorizable): would
  take T7 from ~6x to ~15x on its ~40-60 s term; the psi/transport
  kernels cannot use it (their operands are mod-q general). Left as a
  RUN/CODE row for the board.
- The T3b Z contraction transforms psi and the 11 A rows per source
  (12 x 1.5 us of its ~25 us per output). A per-level transformed-A
  cache shared with the matvec (`ntt_gemm_modq_small` transforms the
  same A rows) would remove 11 of the 12 — 1.3 GB at level 0 for the
  act group at 125M (one-sided regime, one transform per ring), so it
  is a memory-vs-time trade for TASK_BOARD's memory-diet row (T9), not
  a free win.
- The verifier's transport (level 1) rides the same fast body; its psi
  (`psi_level0_factored_multi`) is O5's and untouched here.
- Nothing here has been measured on the rig: TASK_BOARD T1's one-binary
  A/B (`ZK_UPERF_ORACLE=1` vs default, EVAL-PROOF DIGEST identical) is
  still the honest test of every projection in Section 5, and now also
  covers the transform switch inside the Phase-0 kernels.
- Observation for the orchestrator (not a lane item): an
  `results/m125_ffn_export/` directory with layer files appeared in the
  main checkout during the session and freeze-check's BF row now fails
  on a DIGEST MISMATCH for layer 0 X rather than a missing file — either
  a partial copy or a non-Mac export; check `digests.txt` there before
  trusting any BF-row result on this box.
