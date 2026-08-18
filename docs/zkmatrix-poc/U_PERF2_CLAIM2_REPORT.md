# U-PERF2 lane O — the claim layer, round 2 (table pool + the ixf tables built on the device), the GEMM's u32-limb MAC (measured, refuted), leftovers

Branch `uperf2-o` (worktree /home/victor/wt-uperf2-o), opened at 50aea3e on
2026-08-17. Ledger: PROGRESS_UPERF2.md "Round 8 ... Lane O" + "Agent O
status". This continues lane D's packed ixf prover (U_PERF2_CLAIMCOMMIT_
REPORT.md), lane L's device ixf chain (U_PERF2_GPU2_REPORT.md Section 5,
items 3-4) and lane K's GEMM kernel (U_PERF2_GPU_REPORT.md Section 5).

**Hardware (this box) [MEASURED]:** NVIDIA GeForce RTX 4070 Laptop GPU
(8,188 MiB, sm_89, 36 SMs, a 55-70 W mobile part) behind WSL2 (pinned H2D
5-9 GB/s per lane L); host Intel Core Ultra 9 185H (22 threads), 15 GB.
Nothing here is a claim about the TARGET_CONTRACT's desktop board. Every
wall-clock number is `[WSL-BOX NT NOISY-SHARED]` unless marked QUIET —
lane N built and ran concurrently; the rigs are serialized through
`/tmp/zk-heavy.lock`.

## 0. One paragraph

The pass claim layer's five stacked zero-check instances (the Hadamard
check and the four requant checks — 4-5 factor tables of 2^24 elements = 1
GB packed each at 12x512) no longer exist on the host in the GPU build:
`bg_zc_prove` hands fold.rs the COMPACT operands (the eq point, the three
witness tensors per layer with their index law, the 16-slot shift table)
and the device builds the three stacked tables from the i64 layers
(embed(to_mod(v)), 300 MB uploaded through pinned staging instead of 4-5
GB of tables), never materializes the eq factor (the eq-fold identity: eq
= eqL x eqH with two <= 4096-element halves, the low half folded per round
on the host) nor the requant shift table (a per-slot base-field scalar
while position variables remain), runs the round + fold kernels on
device-resident tables (rotating scratch: 3.5 tables of VRAM, 4.06 GB at
12x512, released at the claim layer's end) and hands the < 512-element
tail back to the CPU loop. On the CPU path (both builds) the packed tables
come from a claim-layer-scoped POOL (full-size buffers reused across the
instances, one half-size rotating fold scratch, nothing shrunk or
re-faulted; peak = lane D's 5.5 x table). Everything is bit-identical: the
device's node values are the canonical sums the CPU planes finalize to
(lane L's argument), the folded and built tables are the canonical
representatives of the same field expressions, and the eq / shift factors
are the same multilinear functions read off a product form —
`uperf-o battery` (20 shapes x {Had, Rq}: boxed scalar oracle == host
packed == device == device at min_pairs 1 / low bits 3, planted q-1 / -q /
wide values, ZK_THREADS 1/2/7, digest b67af1aa..), `uperf-d` 30/30
(46471467.. unchanged) under ZK_GPU=1, `uperf-pc diff-battery`, and the
REAL rigs' digests. **THE PoC SHAPE 12x512 8T+GPU: 60.2 s -> 46.6 s (commit
4.7 / prove 37.5 / verify 2.6), the claim layer 15.5 -> 2.0 s, peak RSS 11.2
-> 9.3 GB, statement 2f8a92f8.. / EVAL 4c259008.. / 1,509,911 B identical,
accept**; 12x128 8T+GPU 25.5 -> 19.1 s (claim layer 2.61 -> 0.73 s); the CPU
path's zero-check sequence at the 12x128 shape 2.67 -> 2.03 s from the pool
alone (8T, proofs identical). The GEMM's u32-limb MAC (item 2, lane K's
"~2.5-3x [ASSUMED]") was MEASURED and refuted on this part: `mad.wide.u32`
issues at half the IMAD rate (746 vs 1,631 G/s) and the 3-limb 9-product
MAC runs at 111 G MAC/s against K's 64x64->128 + ACC128 form at 156 G
MAC/s — the kernel stays as it is (its inner MAC is within 2x of its
instruction floor; the level-h phase's remaining 4.6 s is host pack /
transfer / phi-fill bound, not the MAC). Leftovers (CRS SHA-256 on the
device, transport / precommit transforms) sit in eval_proof.rs, outside
this lane's file rule — not touched (Section 5).

## 1. What landed (files)

- `zkmatrix-rs/src/ring/fold.rs`: the claim-layer TABLE POOL (`IxfPoolScope`,
  `ixf_pool_take/give/clear/stats`, `ixf_ktab_take/give`; the builders
  `IxfTable::eq / scalar_table / layer_expand` write every word of a
  pooled (dirty) buffer; the packed prover keeps ONE rotating half-size
  scratch and never shrinks while the pool is open; `ZK_IXF_POOL=0` = off);
  the compact-operand entry `IxfZcSpec` + `ixf_sumcheck_prove_zc` (device
  path when live, else the pooled host builders + the packed prover; the
  host rebuild + re-fold fallback on a device error;
  `ixf_sumcheck_prove_packed_from` = the packed loop from a round index).
- `zkmatrix-rs/src/ring/gpu/ixf.rs` (NEW): the device module — own NVRTC
  module `zkgpu_ixf` (PTX cached on disk as k9's), device buffers (4 big
  rotating + sources + small tables), pinned staging, the chain protocol
  (`ixf_zc_open / round / fold / handover / abort`, `ixf_release`), knobs
  (`ZK_GPU_IXF=0` off, `ZK_GPU_IXF_MIN_PAIRS` default 32, `ZK_GPU_IXF_LOWBITS`
  default 12, `ZK_GPU_IXF_STG_MB`, `ZK_GPU_IXF_MINB` NVRTC-time launch
  bounds), stats, harness setters (`ixf_set_bypass / min_pairs / low_bits`).
- `zkmatrix-rs/src/ring/gpu/kernels_ixf.cu` (NEW): the K-field arithmetic
  header (copied from lane L's kernels_k9.cu — lane N owns that file),
  `k_oixf_build` (the stacked tables from the i64 layers), `k_oixf_fold`,
  `k_oixf_round` (three tables in shared memory, the eq pair from the two
  small tables, the shift as a scalar product, four unrolled nodes, block
  reduction + one u64 atomic per (node, t)).
- `zkmatrix-rs/src/ring/gpu/mod.rs`: `mod ixf;` + re-exports + the stub;
  `imad_probe` re-export.
- `zkmatrix-rs/src/ring/gpu/kernels.cu` + `cuda.rs`: `k_imad_probe` /
  `imad_probe` (the instruction-throughput probe, analysis only).
- `zkmatrix-rs/src/bin/ring_matmul.rs`: `bg_zc_prove` builds an `IxfZcSpec`
  on the fast path (the boxed oracle path unchanged); `bg_pass_run` /
  `bk_pass_run` open an `IxfPoolScope` around the zero-check loop; the
  `// [UPERF2-O]` section with `uperf-o battery [seed] | bench [layers] [t]
  [reps] | probe [iters] [blocks]`.
- This report + "Agent O status" in PROGRESS_UPERF2.md.

Not touched: k9.rs / kernels_k9.cu (lane N), eval_proof.rs, kfield.rs,
sumcheck.rs, gkr*, ct_engine.rs (the existing `d.cl-*` phase ids are
reused).

## 2. Method (why the values are identical)

### 2.1 The table pool

Allocation plumbing only. A pooled buffer is DIRTY, so every builder writes
every word it hands out (`scalar_table` writes the 15 zero planes of each
block; `layer_expand` whole blocks; `eq` every entry by the doubling — the
kfield builder body over the pooled buffer); a partial last block is
zeroed at take. The fold scratch is the biggest fold output (half a table);
the out-of-place fold swaps the old table buffer in as the next table's
scratch, so no buffer is ever shrunk while the pool is open. Every pool
buffer was born as `vec![0u32; n]` and only truncated / swapped / written
within its capacity since (takes are served at capacity >= words), so
`set_len` at take is sound (documented in `ixf_pool_take`). The scope
closes at the end of the zero-check loop (the pass drivers), releasing the
host buffers AND the device buffers (`gpu::ixf_release`) before the descent
phase. Under `ZK_UPERF_ORACLE=1` the boxed path runs as before.

### 2.2 The device-built ixf tables and the device-resident chain

- Stacked tables: element idx = embed(to_mod(v)), v the i64 value at
  (layer idx >> n_pos, row (idx & (np-1)) >> lcp, col (idx & (np-1)) &
  (cols_pad-1)), zero for a pad layer / padded column / row past the
  layer's rows — the same rule `IxfTable::scalar_table` evaluates on the
  host; `to_mod` = `Zq::to_mod` (C's truncated `%` == Rust's `%`).
- The eq factor: eq(z, i) = prod_j (bit_j(i) ? z_j : 1 - z_j) is the
  product of the eq over the low h variables and the eq over the high
  ones: eq[i] = eqL[i & (2^h - 1)] x eqH[i >> h]. Folding variable t (the
  lowest unbound bit) is substituting x_t = r_t in a multilinear form, so
  it folds eqL alone (eq_{t+1}[i] = fold(eqL_t)[i & m] x eqH[i >> a]) —
  the same field element per entry as folding the materialized table.
  When the low group is exhausted (t = h) the remaining eq is C x eqH (C =
  the fully folded eqL, one element), a <= 4096-element table G folded per
  round on the host. Both small tables come from `kt_eq_table_par` (the
  same values as `gkr::eq_table`). The kernel forms the pair (e0, e1) =
  (eqL[2p'] x H[j], eqL[2p'+1] x H[j]) with two kmuls (mode 0) or reads
  (G[2p], G[2p+1]) (mode 1); the node values are then the CPU's e0 / e1 /
  e1 + (x-1)(e1 - e0).
- The requant shift table sh~[idx] = sh[idx >> n_pos]: while position
  variables remain both pair elements are the same slot's entry, so the
  fold leaves it a per-slot broadcast and every node value IS that entry —
  a base-field scalar embed(2^shift) (zero for pads; the device path
  declines any other shape), whose product with a K-element is 16 scalar
  products with kmul's exact chain (h_t = 0). From t = n_pos on the
  16-slot layer table L_t is folded on the host and read as pairs.
- The round: nodes x = 0..deg (all shipped, as lane D's kernel), inner
  factor by kind (Had v1 v2 - v3; Rq (v1 - v4 v2) - v3), term = eq x
  inner reduced to its canonical value, summed mod q per thread, a
  fixed-order block reduction, one u64 atomic add of canonical values per
  (node, t) (< 2^49), reduced mod q on the host: reduction commutes with
  addition, so the node value is the same field element the CPU's exact
  planes finalize to — lane L's Section 2.2 argument, asserted by the
  batteries (every round polynomial is absorbed, so the proof digest
  covers every node of every round).
- The fold: out[i] = in[2i] + r (in[2i+1] - in[2i]) on the three stacked
  tables (kfold, lane J's chain), out of place through a rotating scratch
  (four buffers for three tables: 3.5 tables of VRAM instead of 2 x nt x
  0.75); the eq / shift small tables folded on the host (`kt_fold_inplace`
  — no k9 hook on that path).
- The handover (below `min_pairs` pair-blocks = 512 elements): eq
  materialized on the host from the small tables (eqL[i & m] x eqH[i >>
  a] or G[i]), the three tables downloaded (< 32 KB each), the shift table
  materialized (broadcast or L_t) — the packed CPU loop continues from
  round t on the same tables lane D's path would hold (asserted by the
  battery legs at min_pairs 1 / low bits 3, which drive every mode down to
  16 elements).
- Failure: a device error mid-instance rebuilds the tables on the host
  from the same operands and re-folds them by the challenges already
  drawn (deterministic), then continues on the CPU; the module is
  disabled for the process (reported once). `set_bypass` asserts no chain
  is open; `ixf_release` asserts the same.

### 2.3 The GEMM's u32-limb MAC — measured, not built

`uperf-o probe` [WSL-BOX, RTX 4070 Laptop, warm, best-effort G ops/s]:

| formulation (per thread 8 / 4 independent chains) | G MAC-class ops/s |
|---|---:|
| IMAD 32x32->32 (the peak reference) | 1,631 |
| `mad.wide.u32` 32x32->64 (the K-field kernels' MAC) | 746 (0.46x IMAD: HALF rate) |
| lane K's GEMM MAC: 64x64->128 (`mul.lo` + `mul.hi`) + 2 x ACC128 | 156.5 |
| the 3-limb u32 MAC (9 x `mad.wide.u32` into 5 diagonals; K's Section 5) | 111.2 (0.71x of K's) |

So on this part the u32-limb formulation is SLOWER than the current MAC
(the wide multiply-add is half rate, and nine of them cost more than the
two 64-bit multiplies plus four carry-chain adds), and K's kernel (75 G
MAC/s measured at 64x64x1024) sits at ~48% of its own MAC ceiling — the
rest is tile loads / syncs / occupancy, worth at most ~2x on a 7 ms
kernel inside a ~16 ms call whose other 9 ms are h2d / transforms / flush
/ d2h / host pack: ~0.5 s of the 12x512 rig at best. Not built; the
finding is the deliverable (it also prices lane L's / N's kernels: their
`mad.wide.u32` MACs run at 746 G/s peak, not 1.6 T).

## 3. Differential evidence (all at HEAD of uperf2-o)

| gate | result |
|---|---|
| `uperf-o battery` (GPU build, ZK_GPU=1; ZK_THREADS 1, 2, 7) | 20/20: 10 shapes (layers 1..16 = lambda 0..4, t 8..64, cols 5 / 100 / 128 / 768 / 2048 = every lcp / pad case, patterns small / wide (|v| to 2^40, multiples of q, -q) / zero / planted q-1, -(q-1), q, -q, q/2+1) x {Had, Rq}: the boxed scalar oracle == the host packed path == the device == the device at min_pairs 1 + low bits 3 (every round the device can take, incl. the G and L_t modes); 40 device instances, 376 rounds + folds; BATTERY DIGEST b67af1aa.. at 1/2/7T; the default build reports the stub |
| `uperf-d diff-battery` (both builds; GPU under ZK_GPU=1 — its zero-check legs go through the device path) | 30/30, 46471467.. (lane D's value) at 1/2/7T |
| `uperf-o bench 12 128` (the 5 zero-check instances of the pass claim layer on synthetic layers, one transcript) | proofs identical: host pool off == host pool on == device (digest 4f68023a..) |
| the REAL rigs (Section 4.3) | 3x16 93a98700.. / 0ae9cdae.. / 985,142 B; 12x128 4a3af8c3.. / 742d88e1.. / 1,372,775 B; 12x512 2f8a92f8.. / 4c259008.. / 1,509,911 B — all accept, identical |
| the rest of the gate | (Section 3.1, filled at close) |

### 3.1 The rest of the gate

(filled at close)

## 4. Measurements

### 4.1 Baselines (the 50aea3e binaries, this box)

- 12x128 8T+GPU (baseline binary, `ZK_GPU_VERBOSE=1`): wall 25.5 s = commit
  2.5 / prove 20.3 / verify 2.0; claim layer 2.61 s (cl-tables 1.13,
  cl-rounds 1.26, cl-folds 0.21); lane L's device ixf chain: the had
  instance's round 0 at 2^21 pairs 214 ms (kernel 54 ms + the 1 GB upload
  of 4 x 256 MB tables), rq 178 ms; peak RSS at the claim layer's end
  4,084 MiB.
- 12x512 8T+GPU: the ledger's round-7 row (60.2 s; claim layer 15.5).

### 4.2 Per item before / after

| item | before | after | evidence |
|---|---:|---:|---|
| the pool, CPU path (default build), the 5 zero-check instances at the 12x128 shape, 8T (`uperf-o bench 12 128`) | 2.67 s (cl-tables 0.79, cl-rounds 0.84, cl-folds 1.03) | **2.03 s** (0.52 / 0.86 / 0.65); pool peak 1,408 MiB (= 5.5 x 256), RSS hwm unchanged (2,128 -> 2,129 MiB), 23 hits / 6 misses | proofs identical |
| the same on the GPU build (lane L's k9 chain for the rounds), host path | 2.48 s | 2.09 s (pool) | identical |
| the device path, the same sequence (GPU build, ZK_GPU=1) | 2.48 s (L's chain: 1 GB uploads per instance) | **0.385 s** (opens 0.125 = upload 0.09 + build 0.03; rounds 0.22; folds 0.004; handover 0.001) | identical (4f68023a..) |
| the round kernel, had at 2^21 pairs (4 nodes) / rq (3 nodes) | L's k_ixf_round 54 / 48 ms (kernel only) | 23.6 / 13.5 ms (TOX 32, the shift as a scalar product) | — |
| the 12x512 claim layer, 8T+GPU | 15.5 s (cl-tables 4.9 / rounds 5.3 / folds 5.2) | **1.98 s** at 41eb013 (cl-rounds 1.13, opens 0.49, tables 0.30) — before the TOX-32 / scalar-shift tuning (~-30% on the rounds expected; the final rig row in 4.3) | digests identical |
| the GEMM u32-limb MAC | 156.5 G MAC/s (K's form, probe) | 111.2 G MAC/s (u32-limb, probe) — NOT built | Section 2.3 |

### 4.3 The rigs (`uperf-pc full-profile`, ZK_THREADS 8, `ZK_GPU=1`, wsl export, flock) [WSL-BOX 8T NOISY-SHARED unless noted]

| rig | binary | commit / prove / verify / wall | claim layer (cl-tables / rounds / folds) | peak RSS | digests |
|---|---|---|---|---:|---|
| 12x512 | 50aea3e baseline (the ledger's round-7 row) | 4.9 / 50.9 / 2.6 / **60.2 s** | 15.5 (4.9 / 5.3 / 5.2) | 11.2 GB | 2f8a92f8.. / 4c259008.. / 1,509,911 B |
| 12x512 | 41eb013 (pool + device zc tables) | 4.7 / 37.5 / 2.6 / **46.6 s** | **1.98** (0.30 / 1.13 / 0.01; opens 0.49 inside) | **9.30 GB** | identical, accept |
| 12x512 | HEAD (final) | (filled at close) | | | |
| 12x128 | 50aea3e baseline (this session) | 2.5 / 20.3 / 2.0 / 25.5 s | 2.61 (1.13 / 1.26 / 0.21) | 4,084 MiB at claim-layer end | 4a3af8c3.. / 742d88e1.. / 1,372,775 B |
| 12x128 | 41eb013 | 2.5 / 14.6 / 1.4 / 19.1 s | **0.73** (0.20 / 0.35 / 0.01) | 3,062 MiB at claim-layer end | identical, accept |
| 12x128 | HEAD (final) | (filled at close) | | | |
| 3x16 | 41eb013 | 0.8 / 2.8 / 0.5 / 4.3 s | 0.16 | — | 93a98700.. / 0ae9cdae.. / 985,142 B, accept |
| 3x16 | HEAD (final) | (filled at close) | | | |

12x512 attribution at 41eb013 (8T+GPU): descents 22.9 (bk.descent-gkr
16.7 = a.round-g 12.1 + a.tree-step 8.6 inside; trees 6.2 — lane N's),
prove-group 12.4 (level-h 4.6, psi0-factored 2.7, fold 1.9, kernel-rows
1.8, matvec-chunks 1.4), commit 4.7 (precommit-u0 3.2, chain-derive 1.4,
digit-witness 1.2), CRS 2.6 (m.crs-blocks 1.8), verify-group 2.4,
claim layer 2.0, transport 1.9. The claim layer's device chain: 79 device
rounds (had round 0 at 2^23 pairs 103 ms = 12 ns per pair; rq 85 ms; the
rounds then halve; the folds 3 x ~9 ms at 2^23 elements, bandwidth-bound),
opens 247 ms (the first: 4 GB of cudaMalloc) / ~70 ms (the next: 3 x 100
MB of i64 layers uploaded through pinned staging + the builds) / 29 ms;
VRAM held 4.06 GB during the claim layer, released at its end.

### 4.4 Kernel notes (what was tried on the round kernel)

- Occupancy is shared-memory-limited: 3 tables x (e1, dd) x 16 u32 = 384
  B per thread; TOX 64 -> 3 blocks/SM (6 warps), TOX 32 -> 7 blocks (7
  warps): had 29.1 -> 23.9 ms, rq 24.5 -> 20.1 ms at 2^21 pairs.
- The shift as a scalar product (16 products for kmul's exact chain with
  h_t = 0 instead of 256): rq 20.1 -> 13.5 ms.
- A two-pass kmul (15 h_t + one live acc_t instead of 31 u64
  accumulators): fewer registers but less ILP — 3x SLOWER at the same
  occupancy; dropped. A launch-bounds register cap (`ZK_GPU_IXF_MINB` 10 /
  12): spills, slower; the knob stays (default 1). A grouped-eq mode (the
  block's 32 pairs share H[j]; H applied to the block sum — saves 2 of the
  ~10 kmuls per pair): had 24.4 -> 28.0 ms, rq 13.6 -> 12.6 — the fixed
  per-block grid + the extra atomics ate it; removed.
- The kernel now runs at ~30% of the (half-rate) `mad.wide.u32` peak; the
  next levers are lane J's matrix form for the fixed multiplies and a
  2-thread coefficient split (lane L's Section 5.2), not this round.

## 5. What is left / honest state

1. LANDED: the pool (both builds), the device-built zero-check tables +
   device chain (GPU build), the batteries, the probe finding; the 12x512
   rig 60.2 -> 46.6 s (before the final kernel tuning; the final row in
   4.3).
2. The GEMM u32-limb formulation: measured slower than the current MAC on
   this part — not built (Section 2.3). What would still move the level-h
   phase (4.6 s at 12x512): fusing the host phi fill into the device pack
   and a double-buffered tile load in the GEMM kernel (~0.5 s each at best)
   — lane K's file / eval_proof.rs.
3. The claim layer's remaining ~1.5-2 s at 12x512: opens ~0.5 s (the first
   4 GB cudaMalloc ~0.2 s; then 3 x 100 MB uploads + builds per instance —
   a prefetch of the next instance's tensors during the current one's
   rounds would hide most of it; i32 sources would halve the bytes), the
   round kernel (~30% of the mad.wide peak; a fold-into-next-round fusion
   would save the round's table read, ~25% of the traffic), the joint
   matmul instances (tiny, on lane L's chain / CPU), finals.
4. Leftovers of the brief (CRS SHA-256 blocks on the device or batched
   SHA-NI; the transport's row transforms; precommit's transforms): every
   entry point is in eval_proof.rs, which this lane's file rule reserves
   to the GEMM hook's parameters — NOT touched; designed hook shape as
   lane K's (one line at the top of `expand_level_matrix`'s block loop /
   `transport_level_from_psi`), flagged for the orchestrator.
5. The pool's memory: peak held = 5.5 x the biggest table (lane D's figure)
   for the duration of the zero-check loop; the arena of lane G
   (`ZK_K9_ARENA_MB`) is untouched and still off.
6. Not a Mac build for the device part (CUDA-only, as lanes K/L); the pool
   is plain Rust and lands on the Mac path.
