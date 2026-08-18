# U-PERF2 lane J — AVX2 in the packed K-field lane kernels (descent rounds, folds, tree steps, ixf rounds)

Branch `uperf2-j` (worktree /home/victor/wt-uperf2-j), opened at bd5e0dd
on 2026-08-17. Ledger: PROGRESS_UPERF2.md "Lane J" + "Agent J status".
Box: the WSL box (Intel Core Ultra 9 185H — 6 P + 8 E + 2 LP-E cores as
22 threads, 15 GB; AVX2, no AVX-512; the local m125 re-export is here, so
the 3x16 / 12x128 / 12x512 real-data rigs run). Every number carries
`[WSL-BOX 1T|NT, QUIET|NOISY-SHARED]`; lane K (the GPU rung) built and
ran in its own worktree during the whole session (load 1-3 while the
microbenches ran) — every microbench number below is NOISY-SHARED and the
scalar/AVX2 pairs are taken back to back in ONE binary (`uperf-j bench`
runs the three variants on the same tables in one process; the rigs use
`ZK_KSIMD=0` vs default), so the RATIOS are what to read; absolute
nanoseconds moved by 10-25% between repeats.

## 0. One paragraph

The packed K-field lane kernels of kfield.rs — the fused masked-descent
round (`fused_round_body`), the five-table node loop, the folds, the tree
step, the eq doubling, the fixed/elementwise products and lane D's ixf
round kernel — now have hand-written AVX2 bodies (`kfield::k9_avx2`)
whose values are IDENTICAL to today's auto-vectorized bodies: the AVX2
unit is a row of a lane block (8 u32; `vpmuludq` multiplies the low u32
of each 64-bit lane, so the row is the "even set" operand and the row
shifted by 32 the "odd set" — 8 lane products in two multiplies with no
zero-extension), the (2m, 2m+1) block pair deinterleaves by two `vshufps`
per row into a fixed working lane order (an involution of the standard
order, undone by one `vpermq` at every store), the 16x16 schoolbook runs
OUTPUT-STATIONARY in registers (per output coefficient: bursts of <= 4
products < 2^62 summed exactly in u64, each burst folded once by 2^32 ==
c32 into a single u64 accumulator < 2^46; two adjacent output diagonals
share the operand loads), a FIXED operand (folds, eq, PL) is its 16x16
canonical matrix (the Y^16 = s fold-in precomputed, so its reduction is
one fold31 + one conditional subtraction), and every reduction lands the
canonical representative in [0, q) of the same field expression the
scalar body stores — uniqueness of canonical representatives is the
identity argument (Section 3), `uperf-j battery` the witness (1,120 legs
x 3 variants, planes compared as the exact integer W = lo + 2^32 hi per
lane word, plus every existing battery at 1/2/7 threads with and without
`ZK_KSIMD=0`). Measured on this box, 1T, one binary [NOISY-SHARED]: the
fused round 9.4-11.2 -> 3.2 (cache-resident) / 4.2 (DRAM-streamed) us
per pair-block (2.3-2.9x), the round-1 extract-fold 2.6-2.9x, the tree
step 2.6-3.0x, the ixf round 2.5-2.8x, the fold and fixed product 3.6-4.3x;
lane A's depth-20 x 8 descent bench: `masked_gkr_prove` 9.39 -> 3.54 s at
1T (2.65x; a.round-g 8.27 -> 3.04, a.tree-step 2.21 -> 1.01) and 2.03 ->
0.99 s at 8T (2.05x), DESCENT DIGEST 47a58a27.. on every run. REAL rigs:
Section 6. Dispatch: `is_x86_feature_detected!("avx2")` and `ZK_KSIMD`
!= "0" (the one-binary A/B; `asm!("vpmuludq")` as lane I did). What did
NOT land: a NEON mirror (the body set is ~900 lines; an untested mirror
of that size in the hot path is not "cheap" — Section 7 gives the 1:1
mapping), Karatsuba on the variable x variable product (~15% of the
node loop's MACs, not the fixed multiply where the matrix form's cheap
reduction wins — Section 7).

## 1. What landed (files)

- `zkmatrix-rs/src/ring/kfield.rs` (additive + the dispatch macro):
  - `pub(crate) mod k9_avx2` (x86_64): the row primitives (`mul32` asm
    `vpmuludq`, `fold31`, `canon1`, `fold_burst`, `addm8`/`subm8` on 8 u32
    lanes, `deint_row` = two `vshufps`, `unperm` = one `vpermq`), the
    block products (`diag2<T>` / `diag<T>` output diagonals with
    compile-time bounds, `mul_vv_acc`, `mul_fix_acc` with `RMat`, the
    reductions `red_wire` (h-step class) / `red_fix`), `plane_mac` (the
    eq x wire product into the persistent planes, standard lane order,
    same W per lane word), the block helpers, and the kernels
    `mul_fixed`, `mul_fixed_add`, `mul_elem`, `addc`, `fold_oop`,
    `fold_inplace`, `eq_double`, `eq_double_split`, `tree_step`,
    `round_g5`, `fused_round` (all three modes), `ixf_round`; plus the
    harness primitives `mac_block_planes` / `red_block_planes`.
  - `k9_hand_avx2_enabled()` (AVX2 detected && `ZK_KSIMD` != "0", read
    once), `k9_kernel_label()`; the dispatch macro `k9_kernel_h!` (hand
    body -> today's auto-vectorized instantiation -> portable body) on
    every kernel entry point that has a hand body, and a `*_auto` entry
    per kernel (today's path only — the harness's variant 1). The
    six-table `round_g_body` (the U-K9 oracle path) keeps the old
    dispatch untouched.
  - The `// [UPERF2-J]` harness: `harness_j_run(kf, kernel, variant,
    nblk, reps, seed, pattern)` over 16 kernels x 3 variants (0 portable,
    1 today's, 2 hand), digests over every output (tables; the planes as
    W per lane word; the finalized nodes), `J_KERNELS`, `j_avx2_available`.
- `zkmatrix-rs/src/bin/ring_matmul.rs`: `// [UPERF2-J]` section,
  `uperf-j bench [nblk] [reps] | battery`, registered next to `uperf-h`.
- This report + "Agent J status" in PROGRESS_UPERF2.md.

Not touched: gkr_masked.rs / gkr.rs / fold.rs / sumcheck.rs (no call-site
switch was needed — every caller reaches the kernels through the
`k9_*` entry points, whose dispatch now has the hand body in front),
eval_proof.rs, aux_ntt_core.rs, the bin's other sections, transcript /
mask / RNG order, tree layouts.

## 2. Profile of the kernels as compiled today (`uperf-j bench`, the auto-vectorized AVX2 instantiation) [WSL-BOX 1T NOISY-SHARED]

Disassembly of `k9_round_g5_blocks_avx2` (today's shipped body): the
inner (i, j) iteration of `mac_block` is `vpmovzxdq` x2 (zero-extend the
b row halves), `vpmuludq` x2, `vpblendd` x2 (the lo mask), `vpsrlq` x2,
`vpaddq` x4 with memory operands and 4 STORES — ~18 uops and 4 stores per
8 lane-MACs, the 31 x 8 lo/hi planes living in memory (62 ymm of
accumulators cannot be register-resident); the reduction (`red_block`)
carries LLVM's three-`vpmuludq` 64-bit multiply idiom for `c32 * (hi &
m32)` and a `vmovq`/`vpinsrd` scalar gather for the h-term (`s * h[t*KL+l]`
mixes a u32 array with u64 planes); the masked add-constant loops
(`addm32` over the operand copies) are SCALAR (`cmovae` chains). Per
kernel (ns per unit; v0 = the portable body, v1 = today's dispatch;
2,048 units, best of 3; from the pre-change binary at 0a51729):

| kernel (unit) | v0 portable | v1 today (auto AVX2) | what it is |
|---|---:|---:|---|
| mac (block: one 16x16 lane MAC into planes) | 1,285 | 714 | 2,048 lane-MACs; ~0.35 ns = ~1.2 cycles per lane-MAC |
| red (block: the two-product reduction) | 364 | 282 | |
| mulfix (block) | 828 | 704 | fixed-operand product |
| mulelem (block) | 1,368 | 726 | |
| fold (output block) | 918 | 707 | deint + sub + fixed MAC + red + add |
| eqdbl (block: two fixed products) | 1,748 | 1,253 | |
| tree (output block: 3 products, 2 reds) | 3,965 | 1,897 | |
| g5 / g5m (pair-block: 3 nodes) | 10,970 / 11,205 | 4,832 / 5,131 | 9 products, 3 reds, 3 plane MACs |
| fused FOLD / masked (pair-block) | 20,598 / 19,505 | 10,080 / 10,489 | 10 folds + g5 |
| fused EXTRACT_FOLD (round 1) / EXTRACT (round 0) | 24,528 / 13,589 | 14,133 / 6,457 | |
| ixf-rq / -p3 / -had (pair-block, deg 3) | 9,434 / 8,998 / 9,800 | 4,594 / 4,398 / 5,006 | |

Reading: the descents' pair-block (fused FOLD ~10 us at 1T) is ~19
K-mults + 13 reductions; at ~0.35 ns per lane-MAC the MACs are ~7 us of
it and the reductions/deint/adds ~3 us — MAC-bound with a reduction
share of ~30%. Both are attackable: the MACs by register-resident
accumulation (the memory planes are the cost, not the multiplies), the
reductions by a straight vector formulation.

## 3. Method (why the values are identical, and where the speed comes from)

### 3.1 The lane mapping

A lane block is 16 rows of 8 canonical u32 (coefficient-major). Loaded
as one `__m256i`, a row's four u64 lanes hold the u32 pairs (lane 2k,
lane 2k+1); `vpmuludq` multiplies the low u32 of each u64 lane, so the
row AS IS is the "even set" operand and the row shifted right by 32 is
the "odd set" — two multiplies give all 8 lane products with no
zero-extension and no shuffle. A canonical result of the two sets is
recombined into a row by `even | (odd << 32)`.

The (2m, 2m+1) block pair of a table feeds the round kernels as (even
elements, odd elements): `vshufps(x, y, 0x88)` and `(.., 0xDD)` per row
give exactly those, in the WORKING lane order (pair-lanes 0,1,4,5,2,3,6,7
of the standard order). Lanes are independent K-values, so any consistent
order is exact; the working order is an involution of the standard order
(swap the middle two 64-bit lanes: one `vpermq`), applied wherever a
block is stored, and the persistent planes are written in the standard
order through one `vpunpcklqdq`/`vpunpckhqdq` pair per output row (even
set = pair-lanes 0,4,2,6 / odd set = 1,5,3,7 of the working order
interleave into 0..3 and 4..7).

### 3.2 The product

16x16 schoolbook, 256 coefficient products of < 2^62 per lane,
OUTPUT-STATIONARY: for output coefficient t the products a_i b_{t-i} are
summed in bursts of <= 4 (exact in u64: 4 (q-1)^2 < 2^64), each burst s
folded once by 2^32 == c32 (mod q) into a single u64 accumulator: acc +=
(s & m32) + c32 (s >> 32) (< 799 x 2^32 per burst). Two adjacent
diagonals (t, t+1) run i-major so each a_i / odd(a_i) row is loaded once
for both (`diag2<T>`; every loop bound is a constant of T, so the code is
straight-line after monomorphization — LLVM did NOT unroll the same loop
with runtime bounds, the first build measured 0.8x on the MAC leg). One
block product adds <= 5 bursts per t, the wire's two products <= 10: acc
< 10 x 799 x 2^32 < 2^46. Registers only; the operand rows stream from
L1 (two loads per `vpmuludq` because the asm operand cannot fold a
load; the load ports are not the bound).

The FIXED operand r (folds, eq doubling, PL = p0 + lambda q0, `kt_mul_
fixed`) is its 16x16 canonical matrix R[t][j] = r_{t-j} (j <= t) or s
r_{16+t-j} mod q (j > t), built once per kernel call: out_t == sum_j d_j
R[t][j] with the Y^16 = s fold-in already inside R — 256 products, 4
bursts per t, and NO h-step in the reduction. (Karatsuba does not pay
here: 192 products but a two-class reduction that costs more than the
64 products it saves — Section 7.)

### 3.3 The reductions (canonical by construction)

fold31(v) = (v & m31) + c31 (v >> 31) == v (mod q), exact for v < 2^63
(v >> 31 < 2^32 fits the multiplier; c31 = 399); canon1(v) = min(v, v -
q) on the u32 lanes lands [0, q) for v < 2q (== the first — and here
only effective — conditional subtraction of the scalar `canon32`).
- fixed class: acc < 2^44 -> fold31 -> < 2^31 + 399 x 2^13 < 2q -> canon1;
- two-product class with the h-step: h_t = canon1(fold31(acc_{t+16}))
  (acc < 2^46 -> < 2^31 + 399 x 2^15 < 2q); v = acc_t + s h_t < 2^46 +
  2^62 < 2^63; fold31 -> < 2^31 + 399 x 2^32 < 2^41; fold31 -> < 2^31 +
  399 x 2^10 < 2q; canon1. t = 15 has no h term.
Every stored coefficient is therefore the canonical representative of the
same field expression the scalar body stores (fold: t0 + r (t1 - t0) [+
c]; PL; the tree's pL qR + pR qL and qL qR; eq's a zbar / a z; the wire PL
Q1 + P1 Q0; the ixf inner factors), reached by exact integer arithmetic;
canonical representatives are unique; hence identical bytes.

### 3.4 The persistent planes

`acc_lo` / `acc_hi` keep the scalar layout (lo[t*KL + l], hi[t*KL + l])
and are still summed across chunks/jobs and finalized by
`kt_round_g_finalize` (u128 exact). The eq x wire products are summed in
bursts of <= 4 per (t, set) and each burst adds (s & m32) to lo and (s >>
32) to hi: the (lo, hi) SPLIT of a lane word differs from the scalar
path's per-product split, but the exact integer W = lo + 2^32 hi per lane
word is the same (the sum of the same products), the cross-chunk sums add
the same W's, and the finalize consumes only W — asserted per lane word
by `uperf-j battery` and on the finalized nodes. Bounds: <= 4 bursts per
pair term per plane word, each < 2^32 to lo and < 2^32 to hi; at
K9_MAX_PAIR_TERMS = 2^24: < 2^58 each, no overflow (the scalar bound was
2^60 / 2^58). This is the one place where "the reduction points" moved:
none — the planes are not reduced until the finalize, and the finalize
input is identical.

### 3.5 Dispatch and safety

`k9_kernel_h!` puts the hand body in front of today's dispatch on every
entry point that has one (`k9_tree_step`, `k9_fold_blocks`,
`k9_eq_double_blocks`, `k9_mul_fixed_blocks`, `k9_mul_elem_blocks`,
`k9_addc_blocks`, `k9_fold_oop_blocks`, `k9_mul_fixed_add_blocks`,
`k9_eq_double_split_blocks`, `k9_round_g5_blocks`, `k9_fused_round_blocks`,
`k9_ixf_round_blocks`); the threaded drivers (`k9_fused_round_par`,
`k9_tree_climb_par`, `kt_fold_par`, ...) are unchanged, so the chunking,
the rung schedule and the plane summation order are exactly lane A/G/H's.
`ZK_KSIMD=0` restores today's bodies everywhere (one env var, no
rebuild); `ZK_UPERF_ORACLE=1` still routes to the U-K9 `_ref` bodies
(which use the six-table `round_g_body` on the old dispatch). The only
`unsafe` is the AVX2 entry points (`#[target_feature(enable = "avx2")]`,
reached after `is_x86_feature_detected!`) and the loads/stores at block
offsets already asserted by the same layout checks the scalar bodies
run; no aliasing beyond the scalar bodies' (the in-place fold's forward
safety and the fused kernel's rung schedule are the drivers'), no
allocation in the kernels (`RMat` is 1 KB on the stack).

## 4. Measurements

### 4.1 Kernel by kernel — `uperf-j bench` (one binary, three variants on the same tables, digests identical) [WSL-BOX 1T NOISY-SHARED, load 1-2]

ns per unit; v1 = today's dispatch (auto-vectorized AVX2), v2 = the hand
body; 2,048 units (DRAM-streamed for the pair kernels: 30 MB of tables)
and 256 units (cache-resident); best of 3 / 7 passes.

| kernel | v0 portable | v1 today | v2 hand | v1/v2 | v0/v2 | 256 units: v1 -> v2 (ratio) |
|---|---:|---:|---:|---:|---:|---|
| mac | 1,076 | 552 | 341 | 1.6x | 3.2x | 526 -> 352 (1.5x) |
| red | 316 | 246 | 164 | 1.5x | 1.9x | |
| mulfix | 737 | 601 | 139 | 4.3x | 5.3x | |
| mulelem | 1,170 | 609 | 206 | 3.0x | 5.7x | |
| fold | 813 | 625 | 156 | 4.0x | 5.2x | 564 -> 157 (3.6x) |
| eqdbl | 1,464 | 1,092 | 296 | 3.7x | 4.9x | |
| tree | 3,375 | 1,587 | 542 | 2.9x | 6.2x | 1,376 -> 526 (2.6x) |
| g5 | 9,263 | 4,054 | 1,613 | 2.5x | 5.7x | 3,780 -> 1,521 (2.5x) |
| g5m (masked consts) | 9,877 | 4,449 | 1,793 | 2.5x | 5.5x | 4,054 -> 1,611 (2.5x) |
| fused FOLD | 18,352 | 11,197 | 4,250 | 2.6x | 4.3x | 9,381 -> 3,200 (2.9x) |
| fused FOLD masked | 18,901 | 12,106 | 4,258 | 2.8x | 4.4x | 9,913 -> 3,305 (3.0x) |
| fused EXTRACT_FOLD (round 1) | 23,635 | 13,560 | 5,110 | 2.7x | 4.6x | 13,247 -> 4,522 (2.9x) |
| fused EXTRACT (round 0) | 12,972 | 6,304 | 2,437 | 2.6x | 5.3x | 5,813 -> 2,130 (2.7x) |
| ixf-rq | 10,650 | 4,900 | 1,879 | 2.6x | 5.7x | 4,195 -> 1,537 (2.7x) |
| ixf-p3 | 8,562 | 3,979 | 1,493 | 2.7x | 5.7x | |
| ixf-had | 8,934 | 3,971 | 1,570 | 2.5x | 5.7x | |

Reading: the fixed-operand kernels (fold, mulfix, eqdbl) gain ~4x (the
matrix form's h-step-free reduction on top of the register MAC); the
variable x variable kernels (mac, mulelem, tree, the node loops) gain
2.5-3x; the fused round pair-block goes ~9.4-11 -> 3.2 us cache-resident
(the sum of its parts: 10 folds ~1.6 us + the node loop ~1.5 us + deint /
stores) and 4.2 us when the tables stream from DRAM at 1T (15 KB per
pair-block: ~3.6 GB/s per thread; at 8T that is ~30 GB/s — the point
where this box's memory system starts to show, Section 4.3). The "mac"
harness leg writes memory planes (`plane_mac`'s shape) and is 1.5-1.6x;
the register-accumulated product inside the node loop is what the g5 /
tree rows show.

Steps on the way (fused FOLD, 2,048 units, v1/v2): first hand build
(from_fn helpers out of line, runtime-bound loops) 1.0-1.2x on the round
kernels and 0.8x on the MAC leg; static bounds (`diag<T>`) 2.36x; two
diagonals per operand load + no block copies in the node loop 2.6-2.9x.

### 4.2 Lane A's descent bench (`uperf-a descent-bench 20 8 5 9`, depth 20 x 8, 5 real + 3 pads, dt 9; DESCENT DIGEST 47a58a2742f9e656ec07f7b14ff696d1ff8092333fb3f6883d7aa95224dafefb on every row) [WSL-BOX NOISY-SHARED, load ~1]

| | today (`ZK_KSIMD=0`) 1T | hand 1T | ratio | today 8T | hand 8T | ratio |
|---|---:|---:|---:|---:|---:|---:|
| masked_gkr_prove | 9.39 s | 3.54 s | 2.65x | 2.03 s | 0.99 s | 2.05x |
| a.round-g | 8.27 | 3.04 | 2.72x | 1.72 | 0.81 | 2.1x |
| a.tree-step | 2.21 | 1.01 | 2.2x | 0.52 | 0.27 | 1.9x |
| trees | 1.57 | 0.85 | 1.8x | 0.41 | 0.27 | 1.5x |
| wall | 11.94 | 5.39 | 2.2x | 3.45 | 2.24 | 1.5x |
| peak RSS | 1,100 MiB | 1,101 | | 1,101 | 1,100 | |

(the h-bench and the thread ladder: Section 4.3)

### 4.3 (to be filled: h-bench, thread ladder, uperf-d bench)

## 5. Differential evidence + gates (all at HEAD of uperf2-j)

| gate | result |
|---|---|
| `uperf-j battery` | 16 kernels x 5 value patterns (uniform; planted extremes 0 / 1 / 2 / q-1 / q-2 / q-3 / 2^30 / 2^30+1 / q-2^30 / q/2 / q/2+1 / 2^30-1 mixed in; all q-1 = the maximal product sums; per-lane extremes; 1/8 zeros) x 3 seeds x sizes 1, 2, 3, 8, 17, 64 units = 1,120 legs, each THREE ways (portable body == today's auto-vectorized AVX2 == hand AVX2): digests over every output table, the planes as the exact integer W = lo + 2^32 hi per lane word, and the finalized nodes — identical; BATTERY DIGEST 45dba7c76658ab9d7a0b9c811ffa14f68267ca9742c39a23cabbef1c03773369 at ZK_THREADS 1, 2, 7 and under `ZK_KSIMD=0` |
| `uperf-a descent-battery` | 18/18 (boxed scalar oracle == bulk-ref == fast, verified), BATTERY DIGEST f936ff79.. (lane A's value) at ZK_THREADS 1, 2, 7, with and without `ZK_KSIMD=0` |
| `uperf-g descent-battery` | 22/22 four ways, 6d6a3f6b.. (lane G's value) at 1/2/7T x {hand, ZK_KSIMD=0} |
| `uperf-h battery` | 24/24 legs eight ways, b1e78285.. (lane H's value) at 1/2/7T x {hand, ZK_KSIMD=0} |
| `uperf-d diff-battery` | 30/30, 46471467.. (lane D's value) at 1/2/7T x {hand, ZK_KSIMD=0} |
| `uperf-a descent-bench 20 8 5 9` | DESCENT DIGEST 47a58a2742f9e656ec07f7b14ff696d1ff8092333fb3f6883d7aa95224dafefb at 1T and 8T, hand and `ZK_KSIMD=0` |
| `uperf-pc diff-battery` | (Section 5.1) |
| freeze-check | (Section 5.1) |
| `self-test` | (Section 5.1) |
| REAL rigs | Section 6: statement / EVAL-PROOF digests identical to the ledger's on every run |

### 5.1 (to be filled at close: diff-battery, freeze rows, self-test)

## 6. The REAL rigs (`uperf-pc full-profile`, `M125_EXPORT_DIR=results/m125_ffn_export_wsl`, flock-serialized with lane K's runs; one binary, `ZK_KSIMD=0` = today's bodies) [WSL-BOX NOISY-SHARED, load 2.5-4 (lane K's rigs/builds between the flock'd runs)]

Digests on EVERY row: 3x16 statement 93a987002a7c4b60c3dfbfc62b7a4f0e5957d8ae2039014ff241e323285fb790 / EVAL-PROOF 0ae9cdae66607239a80cc1f1dea36248370edadbe85214144aee7a5250d975be; 12x128 4a3af8c3.. / 742d88e1..; 12x512 2f8a92f8.. / 4c259008.. (the ledger's values); accept = true.

| rig | bodies | wall (commit / prove / verify) | bk.descent-gkr | a.round-g | a.tree-step | bg.claim-layer | d.cl-tables / rounds / folds | maxrss |
|---|---|---|---:|---:|---:|---:|---|---:|
| 3x16, 1T | today (`ZK_KSIMD=0`) | 25.7 s (2.8 / 19.6 / 3.1) | 2.62 | 2.05 | 0.73 | 0.83 | 0.33 / 0.25 / 0.24 | 961 MB |
| 3x16, 1T | **hand AVX2** | **23.5 s** (2.7 / 17.7 / 3.0) | **1.06** (2.5x) | **0.82** (2.5x) | **0.27** (2.7x) | **0.47** (1.8x) | 0.28 / **0.12** (2.1x) / **0.07** (3.4x) | 961 MB |
| 3x16, 8T | today | 8.6 s (1.2 / 6.2 / 1.1) | 0.97 | 0.70 | 0.20 | 0.30 | 0.10 / 0.08 / 0.11 | 1,037 MB |
| 3x16, 8T | **hand AVX2** | **8.1 s** (1.1 / 5.8 / 1.1) | **0.59** (1.6x) | **0.42** (1.7x) | **0.11** (1.8x) | **0.17** (1.8x) | 0.08 / 0.04 / 0.05 | 1,037 MB |
| 12x128, 8T | today | (12x128 rows) | | | | | | |
| 12x128, 8T | **hand AVX2** | | | | | | | |
| 12x512, 8T | ledger row (96559ee, 8T QUIET) / p50 of 20 runs at bd5e0dd | 155.6 s (11.7 / 134.9 / 7.3) / 153.1 (11.2 / 132.8 / 7.3) | 61.4 | 52.5 | 15.7 | 23.9 (25.4 with the d.* rows) | 6.6 / 6.9 / 10.5 | 10.98 GB |
| 12x512, 8T | **hand AVX2** (ONE run) | (12x512 row) | | | | | | |

Reading: (to be filled)

## 7. What is left / honest state

1. **NEON (the Mac)**: NOT written. The mapping is 1:1 — `vmull_u32` /
   `vmlal_u32` (2 x u64 lanes from the low u32 of each lane; the row of 8
   u32 is two `uint32x4_t`, its even/odd sets `vmovn`/`vshrn` or
   `vuzp1q/vuzp2q_u32`), `vshlq_u64` by -31 / -32 for the folds, `vminq_u32`
   for canon1, `vuzp1q_u32/vuzp2q_u32` for the block-pair deinterleave, a
   `vextq`/`vcombine` for the un-permute — but the AVX2 body set is ~900
   lines and no aarch64 target is installed here (`rustup target list
   --installed` = x86_64 only), so an untested mirror of that size in the
   hot path is not "cheap" and was not attempted. On the Mac the kernels
   run today's auto-vectorized bodies (`k9_hand_avx2_enabled()` is
   false off x86_64); nothing there depends on `ZK_KSIMD`. When someone
   with a Mac wants it: mirror `k9_avx2` function by function keeping the
   bound comments, then `uperf-j battery` is the gate (three-way; on
   aarch64 variant 2 = NEON) followed by the descent digests.
2. **Karatsuba on the variable x variable product**: 3 x (8x8) = 192
   products instead of 256 with M = (a0+a1)(b0+b1) - a0b0 - a1b1 carried
   as M' + K - A - B (K = 0 mod q, > A + B) and out_t = A_t + s (B_t +
   M_{t+8}) (t < 8) / A_t + M_{t-8} + s B_t (t >= 8) — all bounds fit
   the same fold31/canon1 chain: ~14% fewer uops on the wire and the
   tree step's np, 25% fewer operand loads; ~5% of the fused round.
   Not done (the fixed multiply, which is 45% of the round, does NOT
   benefit: the matrix form's h-step-free reduction beats the 64 saved
   products; measured design, Section 3.2). Left as the next kernel
   step if the descents stay the largest term.
3. **The fold share**: 10 fixed K-mults per pair-block (five tables x
   two output blocks) = ~45% of the fused round at 1T; each is a 16x16
   canonical matrix-vector product per lane with no cheaper exact form
   found (16-bit operand splitting doubles the multiplies; Karatsuba
   loses to the reduction). The remaining lever there is structural
   (fewer tables per round), not arithmetic.
4. **Memory at 8T**: the fused round streams 15 KB per pair-block; at
   ~3.2-4.2 us per pair-block per thread the descent runs at ~30 GB/s
   on 8 threads — the 8T ratios (2.0-2.1x) are below the 1T ones
   (2.6-2.9x) partly for that reason and partly the hybrid cores.
   `uperf-a descent-bench` at ZK_THREADS 1/8: Section 4.2/4.3.
5. **Compact-leaf expansion** (`CompactLeaves::expand_blocks`, scalar):
   ~7% of a.tree-step (the leaf-level step reads it twice with c = 2);
   an AVX2 version is ~40 vector ops per block (member mask blends) —
   not done.
6. The six-table oracle body `round_g_body` (`masked_rounds_bulk_ref`)
   is kept on the old dispatch by design (the U-K9 oracle path).
