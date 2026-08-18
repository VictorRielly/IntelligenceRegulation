# U-PERF2 lane M — eval-proof leftovers 2: psi0-factored (SIMD MAC + NTT-domain accumulation), the claim-kernel passes, the CRS stream, fold/transport/precommit/verifier attribution

Status: CLOSED 2026-08-17 (every planned item landed; the rig rows and
gates are at the HEAD of uperf2-m — see Section 5). Written by lane M of
the U-PERF2 round 7 (ledger: PROGRESS_UPERF2.md, "Lane M" + "Agent M
status"). Worktree /home/victor/wt-uperf2-m, branch uperf2-m, opened at
f821485. Every number below is labeled [WSL-BOX 1T|NT, QUIET|NOISY-SHARED];
the WSL box is Intel Core Ultra 9 185H (22 threads: 6 P + 8 E cores +
HT, 15 GB), and lane L (GPU step 2) built/ran concurrently for parts of
the session — the RATIOS (fast vs oracle in the same run, one binary)
and the same-binary rig rows are what to read. All rig runs are the
CPU-only default build (no `gpu-cuda` feature).

The rule (unchanged): every optimization is DIFFERENTIAL — the pre-change
body stays reachable as an oracle (`oracle_mode()` / `ZK_UPERF_ORACLE=1`
for the entry points, plus one knob per new body: `ZK_PSISIMD=0`,
`ZK_PSI0NTT=0`, `ZK_GBLOCKNTT=0`, `ZK_NTTMAC=0`, `ZK_CRSPAR2=0`), the
outputs are byte-identical, the batteries hold at ZK_THREADS 1/2/7 and
with every knob off, freeze-check's 98 on-box rows are identical to the
pre-change capture, and the REAL rigs reproduce their digests.

## 0. One paragraph

`psi_level0_factored_multi` — the level-0 factored psi that runs four
times per pass (the prover's level-1 transport for both groups + the
verifier's two) and cost 11.9 s of the 85 s 12x512 8T+GPU wall — was
per value ring a scalar u128 MAC of 16 x n_kernels G rings (its
`% q` finalize alone ~1/3 of it), then a general x quinary Karatsuba
product per k-run and l0 `poly_scale` + `poly_add` per digit ring into
psi[u], preceded by a G-block setup that ran 256 Karatsuba products per
(col kernel, cb) block. Now: (a) the PHI MAC runs on AVX2 lanes
(`vpmuludq` u32 x u32 exact products in bursts of 4, each burst folded by
2^32 == c32 into one u64 plane, a fold-by-2^31 finalize — canonical
residues of the same exact sums; 4.07 -> 0.58 us per 48-term value ring);
(b) the per-digit-ring products are a u-major NTT-domain accumulation
(PHI-hat once per value ring, the (R c_k)-hat table precomputed with the
INTEGER radix R = 2^(e0*limb) — split as 2^S PHI mod q x R_lo for the
limbs beyond the window — one lane-MAC per digit ring into a
2048-position block's accumulators, the exact-integer window charged per
term by its radix, one inverse per u); (c) the G blocks ride a pooled NTT combine (32 distinct rings
transformed once for the 256 cells) and are built block-parallel; (d)
every NTT-domain accumulator of the file (fold, compute_psi, the transport
combines, the new kernels) is now a canonical Z_p u64 lane accumulator on
AVX2 (`NttAcc`, lane I's mul/add), the split-halves body kept for non-x86;
(e) the hoisted K-mults / mulmods use a fold reduction (2^b == c twice
+ one subtract) instead of `% q` libcalls, the digit splits allocate no
per-coefficient Vec, and small parallel maps stay inline. The rows pass
(bg.kernel-rows) got the same `vpmuludq` T-plane MAC (products folded per
row) and its per-block CQ0 x T products the pooled combine; the CRS
expansion writes its SHA-256 blocks straight into the stream buffer and
walks the rejection sampler in parallel by accepted-word prefix counts;
the transport's 2,000-odd small single products left the len-1 GEMM;
`SmallRings::max_abs` (a serial scan of the whole level-0 store per
fold / matvec / GEMM call) is parallel. Kernel benches [WSL 1T]:
psi0-factored-multi 512x2048 11.9 -> 3.4 us/value ring (3.5x; the
accumulation itself 2.6), rows pass 2.87 -> 0.86 us/digit ring (3.3x), phi
pass 2.37 -> 0.90 (2.6x), CRS walk 5.0 -> 0.8 ns/element (0.19 at 8T).
One finding on the way (Section 4.4): the act groups of the 12-layer rigs
carry (2, 14)/(2, 16)-class aligned tensors whose integer radix exceeds
the exact window — the first cut decided the window over the whole set
and silently ran today's body for all 178 act tensors; eligibility is now
per tensor with a radix-weighted per-u window and a PHI-side split for the
big limbs, and every aligned tensor rides the NTT path. REAL rigs (Section
5): 3x16 1T 23.0 -> 17.4 s / 8T 8.1 -> 6.3 s (psi0-factored 4.00 -> 1.06
/ 1.45 -> 0.34, kernel-rows 2.40 -> 0.81 / 0.58 -> 0.24, verify 3.1 -> 1.5
/ 1.1 -> 0.5), 12x128 8T 43.8 -> 36.1 s (psi0 5.78 -> 1.26, rows 2.39 ->
1.10, fold 2.03 -> 1.08, verify 3.7 -> 1.5), **12x512 8T CPU-only 106.8 ->
96.7 s (verify 7.4 -> 2.7 s; psi0-factored 2.82 s from 11.9)**. Digests
identical on every row.

## 1. Items and where they land

| item | function (eval_proof.rs unless noted) | oracle / knob | call sites | status |
|---|---|---|---|---|
| 1a PHI MAC on AVX2 | `PhiFactored::value_ring[_into]` -> `psi_avx2::mac_mod_q` | scalar u128 body `value_ring_scalar_into` (`ZK_PSISIMD=0`); q46 always scalar | the phi pass, `Phi0Source::fill` (level-0 h), `psi_level0_factored_multi` x4 | LANDED |
| 1b psi0 NTT-domain accumulation | `psi_level0_aligned_ntt` (+ `PsiAlignedTensor`, `psi_ntt_tensor_fits`) | today's aligned body `psi_level0_aligned_today` (`ZK_PSI0NTT=0`; also the over-capacity fallback); the pre-O5 kara form under `ZK_UPERF_ORACLE=1` | `psi_level0_multi_impl` | LANDED |
| 1c G blocks via the pooled combine, block-parallel | `g_block` -> `g_block_pool` (`ntt_combine_pool`), `ColBlockCache::g_prepare` | `g_block_ref` (`ZK_GBLOCKNTT=0`) | `PhiFactored::new` (phi pass, Phi0Source, psi0) | LANDED |
| 1d canonical Z_p lane accumulator | `NttAcc` (aux_ntt_core `gl_mac_lanes_avx2` / `_scalar`) | scalar canonical (`ZK_NTTMAC=0`); split-halves u128 body on non-x86 (verbatim) | `fold_chunks_ntt_gen`, `compute_psi_ntt`, `ntt_combine_general`, `ntt_combine_pool`, `psi_level0_aligned_ntt`, `mul_modq_small_many` | LANDED |
| 1e fold-reduced K-mult / mulmod, alloc-free digits, inline small maps | `QFold`, `kmul_fast`, `digits_into_local`, `map_ordered_min` | `kf.mul` / `zq.mul` (battery leg E), `decompose_poly_*_ref` | `kernel_row_factors`, `kw_hoist`, `kw_row_hoisted`, `bpolys_from_kw_local`, `decompose_poly_modq/small` | LANDED |
| 2 rows pass T planes on AVX2 + pooled block products | `rows_t_rings_avx2` (`psi_avx2::mac_fold_row`), the block combine in `kernel_pass_factored_gen` | the u128 body (non-q31 / `ZK_PSISIMD=0`), `rows_block_ref` (`ZK_GBLOCKNTT=0`) | prover rows pass (both groups), verifier rows_eval (no-level case) | LANDED |
| 2 CRS expansion v2 | `expand_level_matrix_par` -> `_v2` (`crs_blocks_into`, prefix-count walk) | `_v1` (`ZK_CRSPAR2=0`), `expand_level_matrix_raw` (XofReader) | every CRS miss | LANDED |
| 2 transport small products | `mul_modq_small_many` | the len-1 `ntt_gemm_modq_small` (fallback + oracle) | `transport_level_from_psi_fast` (p_rings, q_rings) | LANDED |
| 2 `SmallRings::max_abs` parallel | `impl SmallRings for [i8] / [Vec<i64>]` | the serial scan (same max) | every kernel's s_max | LANDED |
| 2 fold / precommit / verifier | attribution only (Section 4.4) | — | — | measured |

Harness: `ring_matmul uperf-m {battery, bench [rows] [cols] [r], sha-bench
[n], crs-bench [cols]}` (bin section `// [UPERF2-M]`); prof phases
`m.psi0-ntt`, `m.fold-ntt`, `m.crs-blocks`, `m.crs-walk`, `m.phi-setup`,
`m.tr-s/-t5/-pq/-asm` (observation only, appended to ct_engine::prof).
`ZK_M_DEBUG=1` prints the psi0 shape per call.

## 2. Method notes (why the bytes cannot move)

- **1a (the AVX2 PHI MAC).** The scalar body computes per coefficient the
  exact integer S = sum_t s_t g_t[j] in u128 and returns S mod q. The AVX2
  body returns the canonical residue of the SAME S by exact mod-q
  arithmetic on u64 lanes: s, g < q < 2^31 so `vpmuludq` is the exact
  product (< 2^62) and a burst of 4 is exact in u64; a burst B is folded
  as (B mod 2^32) + c32 (B >> 32) with c32 = 2^32 mod q — == B (mod q),
  < 2^32 (1 + c32); the plane sums the bursts (< n_bursts 2^32 (1 + c32)
  < 2^63 for c32 < 2^16, n_terms <= 2^16 — asserted at dispatch); the
  finalize folds by 2^31 == c31 (c31 = 2^31 - q < 2^10) twice (to < 2q)
  and subtracts q once. Canonical residues of equal integers are equal.
  The body runs only for 2^30 < q < 2^31, c32 < 2^16, c31 < 2^10 (the
  house q31: c32 = 798, c31 = 399), AVX2 detected, `ZK_PSISIMD` != 0;
  q46 takes the scalar body (its operands do not fit u32 lanes).
- **1b (u-major NTT accumulation).** Today's aligned body adds
  radix_limb (c_k PHI_vr) mod q per digit ring into psi[u]. With PHI in
  balanced form (|PHI| <= (q-1)/2), c quinary (|c| <= cmax) and the
  INTEGER radix R = 2^(e0 limb) (radix_limb == R mod q), every coefficient
  of (R c_k) (x) PHI is bounded by D (q-1)/2 cmax R and n <= window =
  `ntt_window_terms(q, cmax R_max)` such terms stay under (p-1)/2, so the
  Goldilocks image of the accumulation determines the true integer,
  `center_from_p` recovers it and its residue mod q is the residue of that
  partial sum; the flush schedule (terms counted per u in k order, flush
  at `window` and at the end) is a function of (u, k) only. The other
  tensors (small-cols, generic — today's bodies) add their canonical
  residues into the same psi[u]; mod-q addition is associative and
  commutative. Threads split the u range into blocks, each computed whole.
  ELIGIBILITY IS PER TENSOR (`psi_ntt_radix_split`): with cap =
  `ntt_window_terms(q, cmax)` (the window in R = 1 units; 2^25 at q31,
  2^10 at q46) a limb whose R <= cap charges R on the c side; a limb with
  R > cap is split R = 2^S R_lo with the per-tensor S = e0 (l0-1) -
  floor(log2 cap): the 2^S goes to the PHI side as PHI' = 2^S PHI mod q
  (balanced like PHI; one more transform per value ring), R_lo <= cap
  stays on the c side, and (R_lo c_k) (x) PHI' == R c_k PHI (mod q) with
  the same term bound. Each u keeps a LOAD (the sum of the c-side radixes
  of its terms) and is flushed before a term would push it past cap — a
  function of (u, k order) only. A tensor is eligible iff every hi limb
  has e0 limb >= S, i.e. e0 (l0-1) <= 2 floor(log2 cap) + 1 (51 bits at
  q31: every 125M class incl. the (2, 16) accumulator; 21 at q46 — the
  (2, 16) class rides today's body there); ineligible tensors ride
  today's body, the rest the NTT path (they add into the same psi[u]).
  `PSI_NTT_UBLOCK` = 2048 positions (`ZK_PSI0BLOCK` overrides; neutral).
- **1c (pooled combine).** `ntt_combine_pool` is `ntt_combine_general`
  (lane C's limb-split contract, one-sided at q31 / two-sided at q46,
  oracle when neither fits) with the operand rings drawn from a pool
  transformed once — the same exact-integer products, the same regimes;
  G[d1] = sum_e CQ0[e] (sigma alpha_{(e+d1) mod 16}) with sigma a scalar
  is the same mod-q sum of the same ring products as the 256-product
  body; blocks are independent so a block-parallel build cannot move a
  value.
- **1d (`NttAcc`).** Every NTT-domain kernel accumulates a-hat (.) b-hat
  over a term list and leaves the domain once; the exact-integer contract
  bounds the TRUE integer its Z_p image determines, so any correct Z_p
  accumulation gives the same image. On x86_64 the accumulator is the
  canonical u64 lane value updated by lane I's AVX2 `mul`/`add` (or the
  scalar `gl_add(acc, gl_mul(a, b))`), flushed by the inverse transform;
  elsewhere the pre-change split-halves u128 pair (verbatim). Canonical
  representatives are unique.
- **1e (`QFold`).** q = 2^b - c with c tiny (q31: b 31, c 399; q46: b
  46, c 1103): x -> (x mod 2^b) + c (x >> b) is == x (mod q); from x <
  2^(2b+4) (a 16-term column sum of canonical products) two folds land
  below 2q, one subtract canonicalizes — the same residue `% q` returns.
  `digits_into_local` is `digits::exact_digit_decompose` written into a
  slice (the same operations, the same panics).
- **2 (rows pass).** T[ki][d1][cb] = sum_row s (V mod q): the u64 planes
  hold every product folded by 2^32 == c32 (bounded: rows 2^32 (1 + c32)
  < 2^63 for rows < 2^20), thread partials add, `QFold::reduce` gives the
  canonical T ring = the u128 body's `(x % q)` of the same exact sum; V is
  reduced by the fold from its exact i128 recomposition (i64 fast path)
  == `mod_q_i128`. The per-block CQ0 x T products: the pooled combine
  (alphas = the 16 T rings, pool = CQ0 and s CQ0), the same mod-q sum.
- **2 (CRS v2).** XofReader's stream is SHA-256 counter mode consumed in
  8-byte words (pos advances by 8 always); word w is accepted iff (word
  >> shift) < q; element i is the i-th accepted word. Counting accepted
  words per whole word block (the SHA block count is kept a multiple of
  the word block) and prefix-summing locates any accepted index; each
  thread walks its own poly range from that word in order — the serial
  walk's output by construction; the stream is extended in counter order
  if the accepted count falls short.
- **2 (`mul_modq_small_many`).** One general x small single product per
  output: exact by the single-product capacity (D (q-1)/2 s_max <=
  (p-1)/2, checked; the len-1 GEMM otherwise) — the value
  `ring_mul_split_kara_fast` / the GEMM return.
- **2 (`max_abs`).** A max over the same elements, chunked; exact.
- Threads: every split is over independent outputs / exact partials with
  fixed reduction order (blocks of u, poly ranges, value-ring ranges);
  identical for any ZK_THREADS (batteries at 1/2/7).

## 3. Differential evidence (final HEAD binary)

- `uperf-m battery` at ZK_THREADS 1 / 2 / 7 and at 7 with every knob
  off (`ZK_PSISIMD=0 ZK_NTTMAC=0 ZK_PSI0NTT=0 ZK_GBLOCKNTT=0
  ZK_CRSPAR2=0`): BATTERY DIGEST 8f2344598d16.. on all four runs. Legs:
  (A) PHI MAC avx2 == scalar, 136 term lists (n = 0..1000 across every
  burst tail; all-(q-1), zero-interleaved, random; q46 declines); (B)
  psi0-factored-multi NTT == today == compute_psi(reference Phi_0), 200
  legs = 5 shapes (the act/weight radix classes + misaligned + kernel-less
  + shared col kernels; window-1 (e0 5, l0 6); multi-window at q46 (e0 3,
  l0 4); over-capacity fallback (e0 7, l0 6); the radix-cap mixed case (e0
  2, l0 21)) x 5 chunk splits (n0/5, 37, n0, n0/3+1, 300 — blocks and
  tensors crossed) x q31/q46 x SIMD on/off; (C) `ntt_combine_pool` == the
  Karatsuba reference (6 shapes incl. two-sided-at-q31 n = 2100 and the
  fallback n = 1100) + `g_block_pool == g_block_ref` (3 seeds with zero
  rings), q31 + q46; (D) canonical lane MAC avx2 == scalar, 12
  accumulations (planted extremes p-1 / 0 / EPS / 2^32 / 2^63 / p-EPS /
  (p-1)/2, nonzero starts, up to 4096 terms); (E) `kmul_fast == kf.mul` +
  `mulmod_fold == zq.mul` (40 cases x q31/q46 with extremes) + digit
  splits == the pre-change bodies (8 (e, l) classes incl. the range
  ends); (F) CRS v2 == v1 == raw (q31, q46, the rejection-heavy 2^30 + 1;
  1x1 .. 11x3000).
- `uperf-pc diff-battery` 1T / 7T: O1 4/4 + par 4/4, O2 35/35, O3 63/63,
  O5 12/12 (rows + phi + psi0), E2E 2/2 (the whole bg_prove_group /
  bg_verify_group under oracle vs fast routing, field-identical +
  cross-verify) — with every new body inside the fast routing.
- `uperf-c diff-battery` 1T / 7T (fold 34/34, combine 14/14, transport
  40/40, psi 11/11, digit splits) and `uperf-f diff-battery` 1T / 2T
  (both stores through every kernel), `uperf-i battery`: passed on the
  final binary (`NttAcc` inside every one of those kernels).
- freeze-check: 98 `ok` rows IDENTICAL to the pre-change capture (the
  f821485 build; scratchpad/m_freeze_baseline_raw.txt), then the expected
  export panic.
- `self-test`: (Section 5.4).
- The REAL rigs: Section 5 — statement / EVAL-PROOF digests identical to
  the ledger's on every row (3x16 93a98700.. / 0ae9cdae.. 985,142 B;
  12x128 4a3af8c3.. / 742d88e1.. 1,372,775 B; 12x512 2f8a92f8.. /
  4c259008.. 1,509,911 B).

## 4. Measurements

### 4.1 Kernel benches [WSL-BOX 1T, NOISY-SHARED unless stated]

`uperf-m bench 512 2048 16` (one aligned tensor, e0 2 / l0 5, 3
contributions, r 16, chunk 2560; byte-identical on every path):

| path | total | per value ring | of which the accumulation |
|---|---:|---:|---:|
| today's kara body + scalar MAC (the pre-change psi0) | 0.096 s | 11.7 us | — |
| today's kara body + AVX2 MAC | 0.073 s | 8.9 us | — |
| NTT accumulation + scalar MAC | 0.055 s | 6.7 us | 5.8 us |
| **NTT accumulation + AVX2 MAC (default)** | **0.028 s** | **3.4 us** | **2.6 us** |

The rest of the default path (0.8 us/value ring here) is the G-block
setup — 46 ms with the Karatsuba blocks, 7 ms with the pooled combine.
The raw 48-term x 128-lane MAC: scalar u128 4.07-4.21 us -> AVX2 0.57-0.62
us (6.8-7.1x). Sensitivity: `ZK_NTTMAC=0` 2.6 -> 2.85 us/value ring;
`ZK_NTT_SIMD=0` (scalar transform) 3.2; r = 64: 2.1; the weight shape
2048x768 r 64: 2.1 us/value ring vs 11.3 today.

`uperf-pc kpass-bench 512 2048 noref` (the O5 claim-kernel passes): rows
pass 2.87 -> 0.86 us/digit ring (3.3x; SIMD off 1.40), phi pass 2.37 ->
0.90 (2.6x; the ledger's Phase-0 numbers 3.15 / 2.66).

`uperf-m crs-bench 20000` (11 x 20000 polys, 225 MB):

| threads | v1 (serial walk) | v2 (parallel walk) |
|---|---|---|
| 1T | 0.747 s = blocks 0.597 (85 ns/block) + walk 0.142 (5.0 ns/element) | 0.575 s = blocks 0.423 (60) + walk 0.022 (0.76) |
| 8T | 0.277 s = blocks 0.156 (22) + walk 0.113 (4.0) | 0.210 s = blocks 0.126 (18) + walk 0.005 (0.19) |

`uperf-m sha-bench 2000000`: 35.0 ns per 40-B block at 1T (28.6 M
blocks/s) — SHA-NI IS in use (`sha2` 0.10.9's runtime `cpufeatures`
dispatch; the `sha` cpu flag is set); a software SHA-256 would be
150-300 ns/block. The block generation is now memory/page-fault bound at
8T (18 ns/block = 3.4x scaling on the hybrid box); the serial walk was
the larger term at 8T and is gone.

### 4.2 The 3x16 REAL rig, per phase [WSL-BOX 8T, QUIET-ish (load < 1), `M125_EXPORT_DIR=results/m125_ffn_export_wsl`]

| phase | before (f821485) | after (HEAD) | note |
|---|---:|---:|---|
| wall (commit / prove / verify) | 8.1 s (1.2 / 5.8 / 1.1) | **6.4-6.7 s (1.1 / 4.6-4.8 / 0.5-0.6)** | 1T: 23.0 s -> Section 5 |
| ep.psi0-factored (x4) | 1.45 | **0.36-0.38** | m.psi0-ntt 0.17-0.19; m.phi-setup 0.56 -> 0.08 |
| bg.kernel-rows (x2) | 0.58 | **0.25-0.27** | |
| bg.kernel-phi (x2) | 0.28 | **0.08-0.10** | the G blocks |
| bg.verify-group (x2) | 1.02 | **0.46-0.54** | |
| ep.crs-expand (x32) | 0.52 | 0.43-0.45 | walk 0.18 -> 0.02; blocks 0.34 -> 0.28 |
| ep.transport (x26) | 0.49-0.52 | 0.44-0.48 | m.tr-s 0.13-0.15, -t5 0.18, -pq 0.03, -asm 0.05 |
| bg.fold (x15) | 0.40 | 0.41-0.43 | m.fold-ntt 0.11-0.13 (the rest = digit split + asserts + boxing) |
| ep.level-h-pairs / ep.matvec / d.precommit-u0 | 2.08 / 0.92 / 1.04 | 1.96-2.03 / 0.90-0.99 / 0.96-1.12 | not this lane's kernels (the CPU GEMM) |

### 4.3 The 12x128 REAL rig, per phase [WSL-BOX 8T, NOISY-SHARED]

| phase | before | after (04dfd24) |
|---|---:|---:|
| wall (commit / prove / verify) | 43.8 s (5.7 / 33.7 / 3.7) | **39.9 s (5.9 / 31.2 / 2.1)** |
| ep.psi0-factored (x4) | 5.78 | **2.50** (m.psi0-ntt 2.10, m.phi-setup share ~0.15) |
| bg.kernel-rows (x2) | 2.39 | **1.09** |
| bg.kernel-phi (x2) | 0.41 | 0.17 |
| bg.verify-group (x2) | 3.52 | **2.00** |
| ep.crs-expand (x34) | 1.81 | 1.50 (blocks 1.04, walk 0.05) |
| ep.transport (x28) | 1.21 | 1.30 (noise; the T5 / S transforms dominate) |
| bg.fold (x16) | 2.03 | 2.15 (m.fold-ntt 0.59; the rest was the serial `max_abs` scans — fixed after this run, see 4.4) |
| ep.matvec / bg.matvec-chunks / d.precommit-u0 | 4.11 / 3.98 / 5.09 | 4.37 / 4.26 / 5.15 (the CPU GEMM + its `max_abs` scans; not re-run after the fix) |

### 4.4 Attribution findings (what the counters said)

- **psi0-factored** was three terms: the PHI MAC (~1/3, half of it the
  u128 `% q` finalize), the kara/scale/add per digit ring (~1/2), and
  the G-block setup (256 Karatsuba products per block; at 3x16 the
  largest of the three, 0.56 of 1.45 s). All three are gone; what
  remains is the accumulation (m.psi0-ntt: 2.6-2.9 us per value ring at
  1T in the bench, one or many tensors = the AVX2 MAC 0.3-0.6 + one
  forward transform 0.42 (two for the split-radix tensors) + l0
  lane-MACs + the flush share; ~5 us per value ring in the 12x128 1T
  rig — the act tensors' 36-term MACs and l0 up to 14) — 1.83 s at
  12x512 8T for ~3.2M value rings per pass. THE FINDING: `ZK_M_DEBUG=1`
  showed the act groups carry (2, 14) / (2, 16)-class tensors (l0 up to
  16 at e0 2: R up to 2^30 > the q31 window 2^25) — with the window
  decided over the whole aligned set, all 178 act tensors of the 12x128
  rig were falling back to today's body INSIDE the m.psi0-ntt timer
  (2.1 s at 8T, 7.4 s at 1T); per-tensor eligibility + the PHI-side
  radix split brought m.psi0-ntt to 0.83 s (8T) with every tensor on the
  NTT path. The u-block size (256..4096) is neutral (A/B on 12x128).
- **bg.fold vs m.fold-ntt**: at 12x128 8T only 0.59 of the 2.15 s were
  the NTT fold; the rest was `SmallRings::max_abs` scanning the WHOLE
  level-0 store (250-360 MB) serially per call — and the same scan sat in
  every matvec / GEMM call's `s_max` (`bg.matvec-chunks`, `ep.level-h`).
  Made parallel (exact); the 12x512 row (Section 5.3) carries the effect.
- **CRS**: SHA-NI is on; at 8T the serial rejection walk was ~40% of
  the CRS time (0.66 of 1.81 s at 12x128); the block generation is now
  memory-bound (the fresh 1.3 GB stream at 12x512).
- **transport**: S (11 A rows + psi transformed once per source) and T5
  (11 B rows per binding) are transform-bound by design (the combine
  transforms each operand once); the small products a_t4 c_j / a_l1
  cpair (0.03 s) and the assembly (0.05 s) are minor. Nothing further
  transcript-neutral here short of caching the A/B transforms across
  prover and verifier (memory: 1.3 GB per level-0 A image at 12x512 —
  the memory-diet trade the round-4 report already declined).
- **precommit-u0** (bg_precommit): the level-0 A expansion (CRS) + the A
  matvec over all r chunk slices (`ntt_gemm_modq_small` — GPU'd in the
  GPU build) + the Bu expansion and matvec; the w transforms are indeed
  recomputed by level-h; caching them is 1.3 GB per group at 12x512 —
  measured, not done (RAM).
- **the verifier**: bg.verify-group = psi0 (2 of the 4 calls) + the
  level-1 transport + the CRS memo hits + the floor checks; the psi0
  share fell from ~1.5 to ~0.4 s at 12x128 8T; verify 3.7 -> 2.1 s.

## 5. The REAL rigs (final HEAD binary c3c8a97; `uperf-pc full-profile`, `M125_EXPORT_DIR=results/m125_ffn_export_wsl`, flock-serialized, `/usr/bin/time -v`; digests identical to the ledger's on every row: 3x16 93a98700.. / 0ae9cdae.. 985,142 B; 12x128 4a3af8c3.. / 742d88e1.. 1,372,775 B; 12x512 2f8a92f8.. / 4c259008.. 1,509,911 B; accept = true)

"Before" = the same rig from the f821485 build at the start of the lane
(same box, same session; the 12x512 before-row is the ledger's round-6
CPU-only line — its attribution was recorded on the GPU build, so only
the terms the GPU does not touch are compared there). [WSL-BOX, load
1-2 during the 3x16/12x128 rows, 3-6 during the 12x512 row (lane L
building/running) — NOISY-SHARED throughout; the ep./bg. terms are
per-phase counters, the wall is what it is.]

### 5.1 3x16

| | before 1T | after 1T | before 8T | after 8T |
|---|---:|---:|---:|---:|
| **wall (commit / prove / verify)** | 23.0 (2.7 / 17.1 / 3.1) | **17.4 (2.6 / 13.2 / 1.5)** | 8.1 (1.2 / 5.8 / 1.1) | **6.3 (1.1 / 4.6 / 0.5)** |
| ep.psi0-factored (x4) | 4.00 | **1.06** | 1.45 | **0.34** |
| bg.kernel-rows (x2) | 2.40 | **0.81** | 0.58 | **0.24** |
| bg.kernel-phi (x2) | 0.60 | 0.22 | 0.28 | 0.09 |
| bg.verify-group (x2) | 3.07 | **1.44** | 1.02 | **0.45** |
| ep.crs-expand (x32) | 1.42 | 1.23 | 0.52 | 0.43 |
| ep.transport (x26) | 1.79 | 1.67 | 0.49 | 0.42 |
| bg.fold (x15) | 0.90 | 0.94 | 0.40 | 0.42 |
| ep.matvec / bg.level-h / d.precommit-u0 | 2.13 / 7.23 / 2.43 | 2.15 / 6.92 / 2.36 | 0.92 / 2.08 / 1.04 | 0.96 / 2.06 / 1.02 |
| peak RSS | — | 961 MB | — | 973 MB |

### 5.2 12x128, 8T

| | before | after |
|---|---:|---:|
| **wall (commit / prove / verify)** | 43.8 (5.7 / 33.7 / 3.7) | **36.1 (4.6 / 29.5 / 1.5)** |
| ep.psi0-factored (x4) | 5.78 | **1.26** (m.psi0-ntt 0.83) |
| bg.kernel-rows (x2) | 2.39 | **1.10** |
| bg.kernel-phi (x2) | 0.41 | 0.16 |
| bg.verify-group (x2) | 3.52 | **1.33** |
| ep.crs-expand (x34) | 1.81 | 1.45 (blocks 1.01, walk 0.04) |
| ep.transport (x28) | 1.21 | 1.20 (S 0.64, T5 0.30, asm 0.13, pq 0.04) |
| bg.fold (x16) | 2.03 | **1.08** (m.fold-ntt 0.60) |
| ep.matvec (x38) / bg.matvec-chunks / d.precommit-u0 | 4.11 / 3.98 / 5.09 | 3.21 / 3.09 / 3.89 (the `max_abs` scans) |
| bg.level-h (the CPU GEMM) | 10.34 | 10.27 |
| peak RSS | — | 4,156 MB |
| (1T reference, HEAD~1 binary) | — | 133.3 s = 18.0 / 107.6 / 7.1; psi0 8.16, rows 3.64, fold 4.56, crs 4.21, transport 5.04, verify-group 6.92 |

### 5.3 12x512, 8T, CPU-only (the PoC shape; `free -g` 13 GB available at start; flock; nothing else heavy)

| | before (ledger, round 6, CPU-only) | after (HEAD) |
|---|---:|---:|
| **wall (commit / prove / verify)** | 106.8 (11.3 / 86.5 / 7.4) | **96.7 (9.6 / 82.7 / 2.7)** |
| ep.psi0-factored (x4) | 11.9 (the GPU-build attribution) | **2.82** (m.psi0-ntt 1.83, m.phi-setup 0.95 x642 across psi0 + the phi pass) |
| bg.verify-group (x2) | 7.2-7.4 | **2.53** |
| bg.kernel-rows (x2) | 3.3-3.4 | **2.04** |
| bg.fold (x17) | 3.7 | **2.03** (m.fold-ntt 1.21) |
| ep.crs-expand (x36) | 3.3 | 2.69 (blocks 1.86, walk 0.07) |
| ep.transport (x30) | 2.2 | 2.05 (S 1.28, T5 0.40, asm 0.19) |
| d.precommit-u0 (x2) | 3.8 (GPU build) | 7.88 (CPU-only: the level-0 A matvec on the CPU GEMM) |
| bg.level-h (the CPU GEMM) / bg.claim-layer / descents | 22.2 / 23.9 / ~72 (round 5 CPU-only) | 21.6 / 15.9 / (lane J's) |
| peak RSS | 10.9 GB | 10.96 GB |

Reading: at 12x512 CPU-only the lane took 10 s off the wall (-9.4%) and
4.7 s off the verifier (7.4 -> 2.7 s: psi0 x2 + the transport x1 are
now ~1.5 s of it); on the GPU build the same terms move by the same
amounts (they are CPU-side in both builds), i.e. 85.0 s -> ~75 s
[MODEL — not run: the GPU build was not built in this lane].
The remaining CPU-only wall is the CPU GEMM (level-h 21.6 + precommit
7.9 + matvec 6.3 ~ 36 s — the GPU build's kernel), the claim layer 15.9
and the descents (lane J/L's).

### 5.4 Gates at HEAD (final binary c3c8a97)

self-test passed in 238.3 s (ZK_THREADS 1); freeze-check 98 `ok` rows
identical to the pre-change capture, then the expected export panic;
`uperf-m battery` 1T/2T/7T + 7T with every knob off: one digest
37d6a49b55874c53d426478584b934e645c4b974ae6b3bb01af7527aaaf755c6;
`uperf-pc diff-battery` 1T/7T, `uperf-c` 1T/7T, `uperf-f` 1T/2T,
`uperf-i` passed.

## 6. What is left (honest state at close)

- psi0's remaining cost is the accumulation itself (Section 4.4); the
  next levers are (i) the forward transform per value ring (0.42 us; a
  batched two-ring AVX2 transform or the level-0 h fill sharing its
  PHI-hat with psi0 — the two consumers of PHI_vr, prover side, could
  share one transform pass if the h GEMM took NTT-domain phi input, a
  kernel-interface change), (ii) the E-core scaling of this box (~4x at
  8T on every kernel here).
- The CPU GEMM (`ntt_gemm_modq_small_gen`, level-h 10.3 s at 12x128 8T
  CPU-only, the biggest CPU term) keeps its scalar split-halves dot
  product; a canonical-lane AVX2 dot would need the same `NttAcc` idea
  inside the (ia, ib) cell loop — not this lane's item (the GPU build
  covers it; a CPU-only Mac run would want it).
- The transport's transforms of A/B rows on both sides (Section 4.4).
- The digit split after the fold still boxes l_z x chunk rings
  (`Vec<Vec<i64>>`, the deeper levels' witness form) — a `DigitCols`
  form for the level >= 1 witnesses would remove the boxing (memory
  report T9's row), not a time item.
- Nothing here has been run on the Mac; the NEON side keeps the scalar
  PHI MAC and the split-halves accumulator (both today's bodies), the
  fold-reduced K-mult and the digit/CRS/max_abs changes apply there
  unchanged (portable Rust).
