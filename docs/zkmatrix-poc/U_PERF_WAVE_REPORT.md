# [UPERF-PC] U-PERF lane PC — the composed-pass prover/verifier clocks

Status: Phase 0 in progress (O1 CRS memo landed 2026-08-13; O2 + O3
landed 2026-08-17 with their battery legs, rig A/B pending — TASK_BOARD
T4). Standing queue: CONTINUATION.md; executable task list:
TASK_BOARD.md. All timings [MAC-BOX ~1T, NOISY-SHARED] unless marked.
PERF RULE: every optimization here is differential — bit-identical
transcript bytes, unmoved freeze digests, identical verdicts at fixed
test seeds; anything that would move a byte is an R-row (Appendix),
not a build.

**Scope correction (2026-08-17, PROGRESS_UPERF.md "2026-08-17"
section):** the composed pass (`bg_pass_run` / `bk_pass_run`) never
calls `prove_ct_round` — the ct-round wave path this lane was named
after (the "68.8%") is the LEGACY per-layer opening whose artifact the
aggregation stack replaced. The lane's real target is `bg_prove_group`
(~83% of the 4,811 s full-statement prove: level-0 h cross-garbage,
the two claim-kernel passes, the A matvecs) and the same files on the
verifier side. `wave-profile` / O4 stay as a secondary rig.

## 1. Scope and baselines (from the frozen reports)

- m125 layer pass (M125_PASS_REPORT Section 5): 12-layer prove
  3,275.1 s, waves 2,251.8 s = 68.8% (127 masked wave ct-rounds per
  layer at ~131 commitments each), descents 25.5%. Layer-2 row:
  prove 254.7 s, waves 170.1 s, commit 38.7 s, verify 34.0 s.
- Composed pass (UAGB1_PASS_AGG_REPORT BG-F3): prove 69.6 min,
  level-0-dominated — h cross-garbage Theta(n_0*r) at the r = 64
  cap (~500M + ~227M kara-muls across the two groups), three
  O(N_limb) claim-kernel/phi passes, commit 380 s. Verifier
  residual (UAGB1_VERIFIER_REPORT 1): 1.03 s level-0 seed-XOF CRS
  expansion at the single-layer shape.

## 2. Wave-phase attribution (deliverable 1) — baseline

(to be measured: `uperf-pc wave-profile 2 512` at the baseline
commit; per-phase table for the m125 layer scope + eval-proof phase
table for the composed scope via `uperf-pc pass-profile`.)

## 3. Optimizations (each with its differential check)

Land in measured-share order. Transcript-preserving only.

### O1 — CRS memo (`expand_level_matrix`) — LANDED 2026-08-13

`eval_proof::expand_level_matrix` memoizes by
`(seed, group, level, which, rows, cols, q)`. Hits return a clone
of the cached polynomials; misses run the original XOF expansion
and store it. Prove-then-verify of the same group therefore pays
the seed-XOF once per unique CRS matrix (the 1.03 s BH residual
class + double re-expansions). Values are byte-identical to
`expand_level_matrix_raw` (the uncached oracle) — asserted by
`uperf-pc diff-battery` leg O1. Cache is process-global;
`clear_crs_cache` exists for tests. No transcript bytes change:
the CRS is deterministic from public (seed, labels, shapes).

Wall-clock on the 125M rig is NOT claimed here. Measure with
`uperf-pc pass-profile` on a quiesced box (ep.crs-expand vs
ep.crs-cache-hit).

### O2 — level h cross-garbage in the NTT domain — LANDED 2026-08-17 (rig A/B pending)

`eval_proof::level_h_pairs(ctx, phi_slices, w_slices, chunk)` replaces
the r(r+1)/2-pair loop of `ring_ip_modq_small` calls in `bg_level_h`
(composed pass) and `agg_level_h` (synthetic rig). One call of the
shared kernel `ntt_gemm_modq_small` (below) yields the r x r table
<phi_j, w_k>; pairs are assembled as h_jj = g[j][j], h_jk = g[j][k] +
g[k][j]. `level_h_pairs_ref` (the pre-O2 loop) is the oracle.
Battery leg (`uperf-pc diff-battery`, "O2 level-h"): 35/35 byte-
identical at q31 AND q46, r in {1,2,3,5,8}, chunk in {1,7,64,257},
small operands with planted +-s_max / zero rings / a whole-zero slice,
window sizes {2^20-class, 64, 32 terms} so windows cross the inputs,
and the over-capacity fallback (q46, s_max 2^40) — plus the raw kernel
cell-by-cell against `ring_ip_modq_small_ref`.

### O3 — the matvecs in the NTT domain — LANDED 2026-08-17 (rig A/B pending)

`matvec_modq_small` (every call site, prover and verifier) now rides
`ntt_gemm_modq_small`; new `matvec_modq_small_multi` (one M, all r
chunk slices — M transformed once) is used by `bg_matvec_chunks` and
`agg_level_t`; `ring_ip_modq_small` likewise. Oracles kept as
`matvec_modq_small_ref` / `ring_ip_modq_small_ref`. Battery leg ("O3
matvec"): 63/63 byte-identical (single, multi, ring-ip; both q's;
shapes 1x1 .. 11x301 x 4 vectors).

**The shared kernel** `ntt_gemm_modq_small(ctx, a, b, len)`:
out[ia][ib] = sum_u a[ia][u] * b[ib][u] over R_q for na mod-q slices
and nb small slices — D = 128 independent (na x len) x (len x nb)
integer GEMMs in the Goldilocks NTT domain (aux_ntt_core): each ring
transformed once, A1 split-halves lazy accumulation, exact recovery
once per (output, window) with the window = the largest term count
under the single-prime contract n * D * (q-1)/2 * s_max <= (p-1)/2
(`aux::max_n_acc`; s_max read from the data), so every recovered
coefficient is the true integer partial sum — bit-identical to the
Karatsuba oracle by construction. Windows depend on (q, s_max, len)
only, so the T6 thread split cannot move a byte. Over capacity (a
single product does not fit) => the oracle runs.

Measured [WSL-BOX, 1T, QUIET] with `uperf-pc kernel-bench r chunk`
(synthetic level-0 shapes, digits |w| <= 2): see Section 4. The rig
number (12x512, MAC) is TASK_BOARD T4.

### O5 — the two claim-kernel passes, factored — LANDED 2026-08-17 (rig A/B pending)

`eval_proof::kernel_pass_factored` replaces the bin's `bg_kernel_pass`
at its three call sites (prover rows pass, prover phi pass, the
verifier's non-recursed rows_eval); `bg_kernel_pass` stays as the
oracle. The identities (module note in eval_proof.rs; TASK_BOARD T5):
with sr_c[row] = scale_c *_K row_c[row] hoisted and the col side
expanded on the K basis (Y^{d1} *_K col only shifts coordinates in
Z_q[Y]/(Y^16 - s)), the per-value-ring work becomes 16 x n_contrib
scalar-x-ring MACs against 16 cached rings per (col kernel, cb):
phi pass PHI_vr = sum_c sum_{d1} sr_c[row][d1] * G_c[cb][d1],
G_c[cb][d1] = sum_e sigma * CQ0_c[cb][e] * alpha_{(e+d1) mod 16}
(256 ring products per block, cached by the col kernel's Rc — the
IXF-folded claims share col kernels across the 12 layers); rows pass
T_c[d1][cb] += sr_c[row][d1] * V_vr with V_vr the value ring
recomposed mod q from its digit rings, then b_rows[cd] += sigma *
CQ0_c[cb][(cd - d1) mod 16] * T_c[d1][cb]. No per-ring K-mults, no
per-ring ring-mults. Misaligned tensors (cols % 128 != 0) and
kernel-less tensors ride the per-ring reference path inside the same
function. Battery leg ("O5 kernel-pass"): 6/6 byte-identical (rows +
phi; aligned nb = 1/2/3, misaligned 64x96, no-kernel tensor, zero
scale, shared col kernels; q31 + q46).

Measured [WSL-BOX 1T QUIET] `uperf-pc kpass-bench 512 2048` (the act
tensor shape, e0 2 l0 5, 3 contributions): factored rows pass 3.15
us/digit ring vs oracle 134.0 (42.6x); phi pass 2.66 vs 137.3 us
(51.5x). At the 125M pass (11.4M digit rings, both groups) that is
~35 s + ~30 s on this box vs ~1,500 s + ~1,500 s for the oracle
(Mac ~2.5x faster on both) — the oracle's ~134 us/digit ring is
~1/3 of the composed prove, dominated by the per-value K-field
weight rows (128 x n_contrib x 2 K-mults), not by the 16 ring-mults.

### O4 — DEMOTED (legacy path)

`prove_ct_round` alloc/borrow is not on the composed pass; kept in the
queue only for the per-layer rig. See the scope correction above.

## 4. Cumulative results

### 4.1 Kernel-class measurements [WSL-BOX (Core Ultra 9 185H), 1T, QUIET, 2026-08-17]

`uperf-pc kernel-bench r chunk` — synthetic level-0 operands (uniform
mod-q phi / A, digits |w| <= 2), byte equality asserted whenever the
oracle runs. "product" = one (mod-q ring) x (small ring) term.

| shape | level-h NTT | level-h kara (oracle) | speedup | matvec NTT | matvec kara | speedup |
|---|---:|---:|---:|---:|---:|---:|
| r=16, chunk=1024 (n_0 16K) | 0.20 s = 0.76 us/product | 1.32 s = 5.02 us | 6.6x | 0.17 s = 0.92 us | 1.01 s = 5.60 us | 6.1x |
| r=64, chunk=2048 (n_0 131K) | 2.06 s = 0.245 us/product | (not run) | ~20x vs the 5.0 us kara rate | 0.93 s = 0.65 us | — | ~8x |
| r=64, chunk=8192 (n_0 524K) | 7.98 s = 0.238 us/product | 174.4 s = 5.20 us | **21.8x** | 3.72 s = 0.64 us | 29.8 s = 5.17 us | **8.0x** |

Reading: at the level-0 r = 64 the per-product cost is MAC-bound
(128 split-halves MACs at ~1.6 ns), the transforms amortize as 2/r,
and the kernel sits ~20x under the Karatsuba rate on this box.
Projection for the 125M rig level-0 h term (act 500.7M + weight 226.5M
products): ~170 s NTT vs ~1,450-3,600 s kara (Mac ~2 us / WSL ~5 us
per product) — the ~60% share of the composed prove becomes ~4-5%.
The projection is NOT a rig number; T4 measures it.

`uperf-pc kpass-bench 512 2048` (O5, the claim-kernel passes; see
Section 3): rows 3.15 vs 134.0 us/digit ring (42.6x), phi 2.66 vs
137.3 (51.5x), byte-identical.

Threads (T6, `ZK_THREADS`, same box, digests identical at 1/2/7 by
the battery): kernel-bench 64x8192 level-h 7.6 s (1T) -> 2.9 (4T) ->
1.38 (11T) -> 1.24 s (20T) = 6.6x on this hybrid 6P+8E box (the
scatter/flush are per-t parallel too; memory bandwidth and the E-cores
bound the tail); matvec 3.6 -> 0.69 s (5.2x). kpass-bench 512x2048:
rows 2.55 -> 0.74 us/digit ring, phi 2.39 -> 0.91 at 7T (per-tensor
precomputes bound the gain at this size). Combined with the algorithmic
factor the level-0 h term sits ~140x under the 1T Karatsuba rate at
20T on this box.

Synthetic rig at the 125M LAYER shape, `agg-matmul 512 768 2048`
(BD's stack: O2/O3 apply; its own claim-kernel pass is the wave-2
`agg_value_weights` form, NOT O5's; verifier = `psi_level0_factored`,
untouched) [WSL, one shot each, 344,318 B counted + accept true on
every run]:

| run | commit | prove | verify |
|---|---:|---:|---:|
| `ZK_UPERF_ORACLE=1` (the pre-change arithmetic), 1T | 10.40 s | 72.82 s | 4.47 s |
| fast, 1T | 2.25 s | 42.30 s | 4.52 s |
| fast, `ZK_THREADS=7` | 1.09 s | 39.56 s | 4.76 s |

Reading: on THIS rig only the level-h / matvec shares moved (commit
4.6x from the u_0 matvecs; prove 1.7x — the rest of its prove is its
own unfactored kernel pass + descents); the composed pass (`bg_*`,
which is what T1 measures) additionally gets O5 on its two kernel
passes and T8b on the verifier.

Projected composed-pass prover after O2+O3+O5 [MODEL from the kernel
benches, WSL rates; the Mac is ~2-2.5x faster on both paths]: level-0
h ~170 s, matvecs ~75 s, kernel passes ~65 s, plus the untouched
descents (~630 s Mac), fold, transport levels (>= 1), claim-layer
sumchecks and commit (~385 s Mac) => the 4,811 s full-statement
prove should land in the ~1,300-1,600 s class on the Mac at 1T
(~3x), with the descents + commit now the largest remaining shares.
T4 measures; T6 (threads) and the descent/commit items follow.

### 4.2 Composed-pass A/B on REAL data — the 3x16 full-statement rig on the WSL box (2026-08-17)

The 125M checkpoint + val shard reached the WSL box on 2026-08-17; the
local re-export `results/m125_ffn_export_wsl/` (same ckpt-00009536 +
window; X differs from the Mac's by mlx CPU-vs-Metal rounding; 0 range
violations — a valid witness of the same statement class, NOT the
frozen digests) lets the 3-layer x T=16 FULL-STATEMENT rig
(`uperf-pc full-profile 3 16`, BK's table-descent rig) run here.
[WSL-BOX 1T, wsl-export, NOISY-SHARED (two agent lanes building/running
concurrently)]:

| run | commit | prove | verify | wall | EVAL-PROOF DIGEST | peak RSS |
|---|---:|---:|---:|---:|---|---:|
| fast, before the misaligned-path fix (d3ec01f^) | 8.3 s | 55.9 s | **142.4 s** | 206.8 s | 0ae9cdae… | 2.9 GiB |
| fast, after the fix (d3ec01f) | 7.4 s | 54.1 s | **10.4 s** | 72.0 s | 0ae9cdae… (identical) | 2.9 GiB |
| `ZK_UPERF_ORACLE=1` (the pre-Phase-0 arithmetic) | ORACLE_3X16_ROW |

FINDING (real data, first profile): the verifier spent 137 of 142 s in
`ep.psi0-factored` — the BK aux tensors (`bk-bl/wm/tm-*`, cols = 16)
are MISALIGNED, so they took the generic per-ring branch, which
recomputed the K-weight row (256 K-mults per kernel) and 16 kara-muls
PER DIGIT RING — and those tensors carry q-range coefficients with
l0 = 16 limbs. Per-value-ring restructuring (kw once, radix-1
products once, radix scale per limb; the rows pass against the
recomposed value ring) is byte-identical (digest unchanged, battery
green) and cut the verify 13.7x. The prover's misaligned path got the
same treatment (55.9 -> 54.1 s at this shape).

Phase table after the fix (fast, 1T): level-h 14.4 s (weight group,
n_0 = 885K rings at T = 16 — the weights do not shrink with T), fold
8.7, transport 8.6 (both sides), matvec 7.9, kernel rows/phi 6.0/5.1,
compute-psi 5.6, psi0-factored 5.4 (verify), crs-expand 2.4, commit
7.4, claim layer 3.1, descents 3.7 (tiny at T = 16). The 12x512 shape
still needs the Mac (RSS 41-47 GiB) — TASK_BOARD T1.

## 5. Walls and cross-zone findings (filed, not built)

(measured shares for off-zone costs: mod.rs XofReader/gaussian
economics, commit.rs/aux shared column transforms, thread model.)

## Appendix R — transcript-CHANGING candidates (R-rows, not built)

(candidates with derived savings for the orchestrator to rule on.)
