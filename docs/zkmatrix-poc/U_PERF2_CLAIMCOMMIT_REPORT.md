# U-PERF2 lane D — the claim layer (packed ixf sumcheck prover) + the commit phase (chain GEMM, digit witnesses, instance tables)

Status: CLOSED 2026-08-17 (all five deliverables landed; commits 2da5dd4,
7df526b, e2f349c + the report/ledger commit on uperf2-d). Written by lane
D of the U-PERF2 round 3 (ledger: PROGRESS_UPERF2.md "Lane D — CLAIM
LAYER + COMMIT PHASE" + "Agent D status"). Worktree /home/victor/
wt-uperf2-d, branch uperf2-d, opened at d3a4602. Box: the WSL box (Intel
Core Ultra 9 185H — 6 P + 8 E + 2 LP-E cores as 22 vCPUs, 15 GB); the
REAL 3x16 full-statement rig runs here (`M125_EXPORT_DIR=.../
m125_ffn_export_wsl`). Every number carries `[WSL-BOX 1T|NT,
QUIET|NOISY-SHARED]`; lane E built and ran in its own worktree for most
of the session, so most rig walls are NOISY-SHARED — the phase timers
(bg.claim-layer, d.*) and the RATIOS are what to read.

The rule (unchanged): every optimization is DIFFERENTIAL — the
pre-change body stays reachable as `*_ref` and under `ZK_UPERF_ORACLE=1`;
the rig's statement digest, counted bytes, verdict AND EVAL-PROOF DIGEST
are identical at ZK_THREADS 1 and 8, fast and oracle; the batteries hold
at ZK_THREADS 1/2/7; freeze-check's 98 on-box rows are identical to the
pre-change capture.

## 0. One paragraph

The pass claim layer's eight folded ixf instances (3 joint matmuls, the
Hadamard zero-check, 4 requant zero-checks) ran their sumcheck rounds on
the boxed scalar `round_poly` + `fold` loop (~80 KElem allocations and
~12 scalar K-mults per pair per round) and materialized their factor
tables as boxed `Vec<KElem>` (~170 B per element). Now: the three combine
shapes are NAMED (`fold.rs::IxfCombine {Prod3, Had, Rq}`), the zero-check
tables are built DIRECTLY in the lane-packed K9 layout (64 B per element,
one allocation, filled per block on the pool), every round runs on a new
lane-blocked round kernel (`kfield.rs::ixf_round_body` / `k9_ixf_round_par`:
one MAC + one deferred reduction for the inner factor, modular differences,
the eq MAC into per-node lazy planes; per-chunk planes summed in index
order = deterministic ZK_THREADS) with in-place threaded folds, and the
scalar prover stays reachable as the oracle. The commit phase got a
row-blocked i32-accumulated threaded chain GEMM (10x at 1T), a threaded
no-alloc digit witness, and lazy-accumulated threaded matmul-instance
table builders. On the REAL 3x16 rig the claim layer goes **3.17 s ->
0.91 s at 1T (3.5x) -> 0.29 s at 8T (11x)** (8T wall 16.6 -> 13.4 s)
with the statement digest 93a98700.., 985,142 B, accept = true and the
EVAL-PROOF DIGEST 0ae9cdae.. identical on every run (1T, 8T, fast, and
the 610 s all-oracle run); the projected 12x512 claim
layer is ~250-360 s serial [MODEL, the boxed path] -> ~75 s at 1T /
~20 s at 8T on this box's rates, and its peak memory ~14-19 GB of boxed
tables -> ~5.5 GB packed. What did not land: an eq-fold identity and the
per-slot-constant shift table (each ~10% of the packed sumcheck), and
`expand_level_matrix` (the CRS XOF, 2.6 s serial in the 8T rig — 18% of
its wall now — eval_proof.rs, not this lane's file).

## 1. Items and where they land

| item | function | oracle | call sites | status |
|---|---|---|---|---|
| packed ixf sumcheck prover: bulk round kernel + in-place threaded folds, scalar tail below two pair-blocks | fold.rs `ixf_sumcheck_prove_kind` / `ixf_sumcheck_prove_tables` / `ixf_sumcheck_prove_packed`; kfield.rs `ixf_round_body`, `k9_ixf_round_par`, `KField::kt_ixf_round_poly`, `kt_pack` | `ixf_sumcheck_prove_kind_ref` (= `ixf_sumcheck_prove` — the scalar `round_poly` + `fold` loop with the shape's closure) | the 8 claim-layer instances of `bg_pass_run` / `bk_pass_run` | LANDED |
| zero-check tables built directly packed (eq via `kt_eq_table_par`, `scalar_table` per block on the pool, `layer_expand`) | fold.rs `IxfTable`; bin `bg_zc_prove` | the boxed builders `gkr::eq_table` / `bg_stack_table` / `expand_layer_table` + the scalar prover (inside `bg_zc_prove`) | the 5 zero-check instances, both passes | LANDED |
| fold scratch shrink (a table never holds > 1.5x its size) | fold.rs `ixf_sumcheck_prove_packed` | — (memory only) | same | LANDED |
| matmul-instance reduced tables ta/tb: lazy exact u128 accumulation (`kacc_*`) + threads per (layer, k) block | bin `bg_mm_tables` | `bg_mm_tables_ref` (the inline serial loop) | the 3 matmul instances, both passes | LANDED |
| `bg_mle` (the C-side claim value + the public X/z claims): lazy per-row accumulation + threaded rows, row order kept | bin `bg_mle` | `bg_mle_ref` | claim layer + public claims (prover and verifier) | LANDED |
| chain GEMM: row-blocked (RB = 16), i32 accumulation when the int8 x int8 bound fits, threads over row blocks | bin `bf_matmul_i64` | `bf_matmul_i64_ref` (the inline i-k-j closure) | `bf_derive_chain` (3 GEMMs per layer) | LANDED |
| digit witness: threaded per value ring, no per-value allocation (`digits_into`) | bin `agg_digit_witness` | `agg_digit_witness_ref` | `bg_witness`, `bk_witness_weight`, `bk_witness_act` | LANDED |
| observation-only phases `d.*` (ids 40-50) | ct_engine::prof | — | commit phase + claim layer | LANDED |

Harness: `ring_matmul uperf-d diff-battery | bench [n_log2] [prod3|had|rq]
[noref] | gemm-bench [t] [noref]` (bin section `// [UPERF2-D]`).

## 2. Attribution — the 3x16 rig BEFORE (d3a4602 binary, timers only)

`uperf-pc full-profile 3 16` [WSL-BOX 1T, QUIET (load 0.3)]: commit 4.0 /
prove 32.2 / verify 6.9 / wall 43.3 s (the ledger's a450b1f row: 4.2 /
32.1 / 7.3 / 43.7). With the `d.*` timers (first landing, same code
paths otherwise):

| phase | seconds (1T) | what |
|---|---:|---|
| bg.commit-phase | 4.05 | |
| d.precommit-u0 | 3.55 | `bg_precommit` x2: level-0 A matvec chunks + Bu (lane C's kernels) + the CRS expansion (`ep.crs-expand`, ~2 s of it, serial XOF) |
| d.digit-witness | 0.68 | `agg_digit_witness` x2 (14M weight values sign-binary + the act values) |
| d.chain-derive | 0.05 | 3 layers x 3 GEMMs at T = 16 (tiny here; T x 32 at the rig) |
| d.aux-build / d.groups / d.statement | 0.03 / 0.00 / 0.02 | |
| bg.claim-layer | 3.17 | 8 ixf instances |
| — of which the scalar sumcheck rounds + folds (measured by difference; the boxed prover has no sub-timers) | ~2.1 | 5 zero-checks at 2^17 / 2^16 elements x 4-5 tables + 3 small matmul instances |
| — table builds (eq tables, stacked tables, ta/tb, v_c) | ~1.0 | ta/tb over the weights (~1.5M add+scale per layer per instance) dominate |

## 3. Method notes

- ROUND KERNEL (`ixf_round_body`): per pair-block m (8 pairs, one per
  lane) deinterleave the nt tables into even/odd lane-blocks, dd = odd -
  even; node 0 = even, node 1 = odd, node x >= 2 = odd + (x-1)*dd by
  successive modular adds (operands stay canonical u32). Per node: the
  inner factor by ONE `mac_block` + ONE `red_block` (Prod3: v1*v2; Had:
  v1*v2 then - v3; Rq: v4*v2 then v1 - . - v3 via `subm32`), then
  `mac_block(eq, inner)` into the node's persistent lo/hi planes (no
  reduction). All deg+1 nodes are evaluated (the ixf wire ships every
  node; no g(1) identity — see Section 7). Finalization per node =
  `kt_round_g_finalize` (u128 exact). Bounds: <= 16 products of < 2^62
  per pair per plane word, <= 2^21 pair-blocks under K9_MAX_PAIR_TERMS ->
  planes < 2^57; per-chunk planes are exact non-negative integers summed
  in index order — bit-identical for any thread count / chunking.
- The FIELD VALUES are those of the scalar closures because K arithmetic
  is exact and canonical: `IxfCombine::eval` IS the pass closure text
  (Prod3 = mul(mul(v0,v1),v2); Had = mul(v0, sub(mul(v1,v2), v3)); Rq =
  mul(v0, sub(sub(v1, mul(v4,v2)), v3))) and the battery compares the
  packed prover against `ixf_sumcheck_prove` driven by the pass closures
  themselves (not against `eval`).
- FOLDS: `kt_fold_par` (lane A's out-of-place threaded fold into a
  scratch, swapped in) per table per round; then the scratch is truncated
  to the next round's size and shrunk (a shrinking realloc — no copy for
  mmap'd chunks) so a table never holds more than 1.5x its size. Rounds
  run packed while the tables hold >= 2 pair-blocks (n >= 16); the last
  three rounds finish on the boxed scalar path (identical values).
- PACKED BUILDERS (`IxfTable`): `eq` = `kt_eq_table_par` (lane A's
  threaded doubling — the same values as `gkr::eq_table`); `scalar_table`
  writes coefficient 0 of each lane from a `Fn(usize) -> u64` canonical
  residue (the stacked witness tables are `kf.scale(v, one)` = embed(v mod
  q) — one u32 store per element instead of a 16-word Vec); `layer_expand`
  = `KTab::filled` per layer segment. `IxfTable::available(kf)` gates on
  the kernel AND `!oracle_mode()`; `bg_zc_prove` builds boxed + runs the
  scalar prover otherwise.
- ta/tb/bg_mle: `kacc_add(acc: [u128;16], v, w)` sums v*w per
  coordinate exactly (< 2^62 per term), `kacc_fin` reduces once — the
  same canonical element as the `add(scale())` chain (mod-q addition is
  exact) with no per-term allocation; ta/tb per (layer, 64-wide k block)
  on the pool, bg_mle rows on the pool with the row-order K-mult
  combination unchanged.
- Chain GEMM: |a|,|b| <= 127 and inner <= 2048 -> |sum| < 2^31: the row
  block (RB = 16 rows) accumulates in i32 (AVX2 vpmulld/vpaddd) over one
  streamed pass of B^T, widened once; the general i64 loop otherwise;
  every output row is one thread's own exact sum in the same k order.
- Digit witness: `digits_into` is `exact_digit_decompose` written into a
  slice (sign-binary at e0 = 1, else the balanced `digit_decompose` loop
  verbatim); one value ring's l0 digit rows are a contiguous disjoint
  slice of the witness written by exactly one thread.
- Threads come from `eval_proof::threads()` through `fold::ixf_pooled`
  (= kfield's K9 pool); at ZK_THREADS 1 every path runs inline.

## 4. Differential evidence (all at HEAD of uperf2-d)

- `uperf-d diff-battery` 30/30 at ZK_THREADS 1, 2, 7 AND under
  ZK_UPERF_ORACLE=1 (BATTERY DIGEST 46471467bcb8bf43.. identical on
  every run): the three shapes at 2^4..2^14 elements, dense AND sparse
  (stacked-table-like, 90% zeros) with a real eq factor (layer-expanded
  for Prod3, full for the zero-checks) — the pass closures' scalar
  prover == `_kind_ref` == packed fast == fast under the in-process
  `set_oracle_mode` flip, rounds/finals/point/transcript-state
  byte-identical, every proof verifies against the hypercube sum on a
  fresh transcript; the 5 zero-check instances end to end on synthetic
  3-layer T = 8 layers (packed builders + packed prover == boxed builders
  + scalar prover under the flip); bg_mm_tables + bg_mle ref == fast on
  the 3 matmul instances; the chain GEMM ref == fast on 3 layers
  (768x2048 x2 + 2048x768); agg_digit_witness ref == fast on a mixed
  group (sign-binary + two e0 = 2 classes, 8,560 digit rings).
- THE REAL-DATA GATE, `uperf-pc full-profile 3 16` at HEAD: accept =
  true, statement digest 93a987002a7c4b60c3dfbfc62b7a4f0e5957d8ae2039014ff241e323285fb790,
  985,142 B, EVAL-PROOF DIGEST 0ae9cdae66607239a80cc1f1dea36248370edadbe85214144aee7a5250d975be
  — identical on every run of every landing step: 1T fast (x4 runs
  across the three code steps), 8T fast, and ZK_UPERF_ORACLE=1 (Section
  5's table).
- Gates at HEAD (the final binary) on this box: `uperf-pc diff-battery`
  green at 1T and 7T (O1 4/4, O2 35/35, O3 63/63, O5 12/12, E2E 2/2);
  `uperf-a descent-battery` 18/18 at 1T and 7T (BATTERY DIGEST
  f936ff79.. unchanged); `uperf-c diff-battery` green at 1T and 7T;
  `self-test` green (262.6 s); `bh-verifier battery` green; `agg-matmul
  battery` green (141 s; it rides `agg_digit_witness`); `pass-agg
  battery` 14/14 green (REAL 3x16 data: honest P0/P2 + every tamper arm
  through the packed claim layer, 82 s at 8T); `table-descent battery
  small` 5/5 green (real data, 45.5 s at 8T); `t-blind battery` 11/11
  green; freeze-check 98 `ok` rows identical to the pre-change capture
  (the full pre-panic text identical; only the panic's source line
  number moved because code was added above it).

## 5. Before / after — the 3x16 rig (`uperf-pc full-profile 3 16`)

| binary | threads | box state | commit / prove / verify / wall (s) | bg.claim-layer | d.cl-tables / rounds / folds / pack | d.digit-witness | digests |
|---|---|---|---|---:|---|---:|---|
| d3a4602 (pre-change) | 1T | QUIET | 4.0 / 32.2 / 6.9 / 43.3 | 3.17 | (boxed prover: no sub-timers) | 0.68 | identical |
| ledger a450b1f | 8T | QUIET | 2.6 / 12.0 / 1.9 / 16.6 | — | | | identical |
| 2da5dd4 packed prover (boxed tables) | 1T | QUIET-ish | 4.3 / 30.8 / 7.2 / 42.4 | 1.64 | 0.96 / 0.30 / 0.27 / 0.10 | 0.68 | identical |
| 7df526b + packed builders | 1T | NOISY-SHARED | 5.0 / 33.8 / 7.6 / 46.6 | 1.64 | 1.05 / 0.30 / 0.29 / 0.00 | 0.92 | identical |
| 7df526b + lazy ta/tb/mle | 1T | NOISY-SHARED | 5.1 / 35.1 / 8.0 / 48.4 | **1.02** | 0.44 / 0.29 / 0.29 / 0.00 | 0.82 | identical |
| e2f349c (HEAD) | 8T | NOISY-SHARED | 2.7 / 9.7 / 2.1 / 14.7 | **0.31** | 0.11 / 0.09 / 0.10 / 0.00 | 0.44 | identical |
| HEAD (final binary) | 1T | NOISY-SHARED (load 3.3, lane E compiling) | 4.4 / 31.5 / 7.9 / 44.0 | **0.91** | 0.36 / 0.27 / 0.27 / 0.00 | 0.46 | identical |
| HEAD (final binary) | 8T | NOISY-SHARED | 2.4 / 8.9 / 1.9 / **13.4** | **0.29** | 0.10 / 0.08 / 0.10 / 0.00 | 0.36 | identical |
| HEAD (final binary), ZK_UPERF_ORACLE=1 (every lane's oracle) | 1T | NOISY-SHARED | 45.1 / 424.8 / 140.4 / 610.4 | 3.53 (the boxed scalar path) | 1.10 / — / — / — | 0.61 | identical |

The NOISY-SHARED 1T rows carry lane E's concurrent load (their
precommit / verify / descent columns move by 15-20% with no code change
in those paths); the claim-layer column is the lane's own term and its
sub-timers reproduce to +-0.03 s across the runs. Net at HEAD vs the
pre-change binary: claim layer 3.17 -> 0.91 s at 1T (3.5x) and 0.29 s at
8T (11x); the digit witness 0.68 -> 0.46 s at 1T (allocation-free) /
0.36 s at 8T; the 8T wall 16.6 (ledger) -> 13.4 s.

Per item (unit benches, byte equality asserted in the same run):

| item | before | after | speedup | evidence |
|---|---:|---:|---:|---|
| packed ixf prover, Rq at 2^17 x 5 tables (`uperf-d bench 17 rq`) [WSL 1T NOISY-SHARED] | scalar 0.401 s (3,062 ns per pair-round) | 0.125 s (rounds 0.051 + folds 0.055 + pack 0.019) | 3.2x (2.5x incl. the pack of boxed tables) | byte-identical; 8T: rounds 0.015, folds 0.020 (3.0x on the kernels; the pack is memory-bound and does not scale) |
| the rig's claim layer 3x16 | 3.17 s (1T) | 1.02 s (1T), 0.31 s (8T) | 3.1x / 10x | rig digests identical |
| chain GEMM, one layer at T = 512 (`uperf-d gemm-bench 512`) [WSL 1T] | 0.923 s (2.62 GMAC/s, i-k-j i64) | 0.092 s (26.2 GMAC/s: i32 row blocks, AVX2 vpmulld) | 10.0x | byte-identical; 8T 0.09-0.10 s (flat — Section 6's box note) |
| digit witness, WgT + one 25-bit act tensor at T = 512 | 0.173 s | 0.150 s (1T; 57 ns per value) / 0.075 s (8T) | 1.2x / 2.3x | byte-identical |
| ta/tb + v_c table builds (in the rig's d.cl-tables) | ~1.0 s (1T) | 0.44 s (1T), 0.11 s (8T) | 2.3x / 9x | rig digests identical |

## 6. Thread scaling and the box note

- Packed prover (`uperf-d bench 17 rq`): rounds 0.051 -> 0.015 s, folds
  0.055 -> 0.020 s at 8T (3.0-3.4x); the rig's claim layer 1.02 -> 0.31
  s (3.3x on top of the 1T packed gain). The kernels are lane A's class
  (`round_g5`-style MAC/reduce pipelines, memory-bound folds) and
  saturate the same way on this hybrid virtualized box (~4x by 6-8
  threads); the Mac's uniform cores measured 8.7-9.1x on the commit
  kernel (PROGRESS_UPERF) — that is the expectation, to be measured by
  TASK_BOARD T1 with `ZK_THREADS`.
- BOX NOTE (chain GEMM at 8T is flat, 26 GMAC/s at 1T and 8T; 2T is
  SLOWER, 12 GMAC/s): a standalone probe of the identical loop
  (scratchpad/gemm_probe, `-C target-cpu=native`, work always inside a
  rayon pool) scales 14 -> 25 -> 45 -> 58 GMAC/s at 1/2/4/8 threads.
  The difference is where the work runs: at ZK_THREADS 1 the engine runs
  the GEMM INLINE on the hot main thread (a boosted P-core, 26 GMAC/s),
  while pool threads on this WSL2 box are placed by the hypervisor on
  E/LP-E cores (a pool thread at T = 1 measures 14 GMAC/s; two of them
  12 in total). The split is deterministic and correct at any thread
  count (battery + rig digests); the scaling is the box's, and the item
  is 0.06 s of the 3x16 rig either way. At the rig's T = 512 the chain
  is 12 x 3 GEMMs = 12 x 0.09 s ~ 1.1 s at 1T (was ~11 s).

## 7. Projected 12x512 deltas [MODEL — from the 3x16 phase timers and the unit rates; not a rig number]

The claim layer's zero-checks scale with T x layers (tables 2^24 / 2^23
elements at 12x512 vs 2^17 / 2^16 at 3x16: x128) and its matmul-instance
tables with layers (x4) at fixed weight shapes:
- boxed path (pre-change): the 5 zero-check sumchecks ~2.1 s x 128 =
  ~270 s + the boxed table materialization (5 x 5 x 16.7M KElem
  allocations, ~14 GB resident per instance, ~19 GB with the packing
  copy) ~40 s + ta/tb ~4 s + bg_mle ~5 s = ~320 s serial (the ledger's
  "~100 s serial" was low: the round loop's per-pair cost is ~5 us on
  5-table degree-2/3 rounds).
- packed path (this lane): rounds + folds 0.58 s x 128 = ~74 s at 1T,
  ~19 s at 8T on this box (~8-10 s at the Mac's expected scaling);
  packed table builds ~2-3 s (memory-bound, threaded); ta/tb + bg_mle
  ~2 s (1T) / ~0.5 s (8T); peak claim-layer memory ~5.5 GB (5 x 1 GB
  packed tables + one 0.5 GB fold scratch) instead of ~14-19 GB — a T9
  (memory-diet) item in the direction the 15 GB box needs.
- commit phase: chain 12 x 3 GEMMs ~11 s -> ~1.1 s (1T); digit witness
  (weights 57M values + act ~160M values) ~10 s -> ~4 s (1T) / ~1.5 s
  (8T); precommit-u0 (lane C's kernels, threaded) unchanged here — its
  CRS expansion (`ep.crs-expand`, serial XOF) is the commit phase's
  largest fixed term now (2.6 s at 3x16 for prover + verifier; the
  level-0 A matrices scale with n_digit_rings/r0: at 12x512 the act
  group's A_0 is ~11 x 122K rings = ~170M field draws, ~4 s of XOF at
  this box's SHA rate, the weight group's ~2 s — ~6-8 s serial per
  process [MODEL]).
Sum on the touched terms: ~330 s -> ~80 s at 1T [MODEL], scaling with
ZK_THREADS; TASK_BOARD T1's one-binary A/B is the honest test.

## 8. What is left (in the order of the remaining share)

1. `expand_level_matrix` (eval_proof.rs — lane C's file, not touched):
   the CRS XOF expansion is serial and 2.6 s of the 8T rig's 14.7 s wall
   (18%; it does not shrink with threads). Every poly is an independent
   XOF stream position — parallel per row block with a per-block reader
   would be bit-identical only if the stream were re-seeded per block
   (it is ONE counter-mode stream today, so a split needs a block-indexed
   derivation = a CRS change, i.e. NOT transcript-neutral) OR the single
   stream is expanded serially and only the field sampling is split
   (rejection sampling makes positions data-dependent — also not
   splittable). The honest options: cache the level-0 matrices across
   processes (they are seed-determined) or accept the serial term.
   Flagged for the orchestrator.
2. The eq-fold identity: fold(eq_t, r) = ((1-r_t)(1-r) + r_t r) x eq_{>t},
   so the eq table's per-round fold (1 of 4-5 folds) can be a scalar
   carried into the finalization; and the requant shift table is per-slot
   constant while position variables remain (its fold is a re-expansion,
   its node operand a broadcast) — together ~10-15% of the packed
   sumcheck and 1 GB of the 5.5 GB at 12x512. Same values by identity;
   not attempted (small share, kernel variant needed).
3. g(1) = c_t - g(0) with the running claim (skips one node per round,
   ~17% of the round work for degree 2): exact for well-formed tables but
   changes what a MALFORMED prover ships (the pass batteries' tamper
   arms build honest-structure tables, so it would hold there too) — left
   out to keep every tamper leg's transcript byte-identical to the
   oracle's.
4. The digit witness's act-group share at 12x512 (~160M values):
   threaded and allocation-free now; a per-tensor vectorized
   decomposition (all 128 coefficients of a value ring at once) is the
   next 2-3x if it matters after T1.
5. The T_blind (P2 masked) matmul instances ride `t_blind::
   masked_sumcheck_prove` (not this lane's file) — still the scalar loop;
   small tables (slots x nk) so it does not matter at 12x512.
6. Nothing here has been measured on the rig beyond 3x16: TASK_BOARD T1's
   one-binary A/B (`ZK_UPERF_ORACLE=1` vs default, EVAL-PROOF DIGEST
   identical) is the honest test of Section 7, and now also covers the
   packed claim layer and the commit-phase splits.
