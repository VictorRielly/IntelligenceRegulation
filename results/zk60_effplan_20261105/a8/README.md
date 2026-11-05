# A8: the openings' store folds, and the A/H zero-fills (2026-11-05)

The plan: `docs/zkmatrix-poc/ZK60_EFFICIENCY_PLAN_20261105.md`, item A8 (FlashProve's Gram-matrix folding, §2).
Byte-preserving. It follows A11 (`../a11/README.md`), whose profile after its fix put the openings' store folds at
about 8% of a fork's main line and the A/H zero-fills at about 8% of its host samples.

Labels: [MEASURED] a number from a log in this directory; [INFERRED] derived from measured numbers; [ESTIMATE] a
judgement, not a measurement.

All D55 runs: W16R2 8B T128, 32 blocks, N = 6 fork workers (A11's per-fork pools of 6 threads), `HL_GPU=1
HL_PB_ORACLE=0 HL_METAL_TIMING=0`, on the shared M3 Ultra (another agent's jobs ran between ours, never with
them: every stage held the guard's heavy lock).

## Plain summary

- **There was no Gram folding to do.** Each opening already reads its committed rows once (the Metal store folds
  every vector in one call, `fold_batch = usize::MAX`), and the small coefficient vectors are already combined
  before that pass (`zk_rhos`: one vector per column-weight group, the claims combined by their lambdas). The
  outputs are 37 (A) and 10 (H) different linear maps of the rows, all sent in the receipt, so the work is fixed
  at one multiply-add per nonzero coefficient and column. What was left was the constant factor. [MEASURED census,
  `s1_bench.log`]
  - A: 37 vectors, but only 5,658 nonzero coefficients over 2,504 rows (2.26 rows' worth: the proximity vector is
    dense, the groups are sparse). 85% of the updates fall on rows whose words are 16-bit signed integers.
  - H: 10 vectors, 7,726 nonzero coefficients over 2,606 rows (2.96 rows' worth), almost no small words.
- **What bounded the fold was memory latency, not arithmetic.** A column chunk reads each row's slice, and every
  row's slice starts 128 KB (eight pages) after the last one's. [MEASURED, `s1_bench.log`, `s1b_bench.log`]:
  - narrow chunks, which keep the accumulators in L1, were up to 2x slower;
  - one row of software prefetch did more than anything else.
  - [INFERRED from that sweep] Each row's first lines are a miss that the hardware prefetcher does not hide.
- **Two smaller costs** [MEASURED]:
  - the pads (`q = 280` columns) were folded afterwards on ONE thread (2.4 ms for A, 3.3 ms for H);
  - A's 37 vectors took the per-term form (the M11 lazy form stops at 16, and at 37 it was no faster).
- **The change, a new store fold** (`gpu/metal.rs`, `fold_segments_a8_opts`; the default):
  - row-sparse: each row's nonzero coefficients listed once;
  - exact u128 sums for every vector count;
  - chunks of 256 columns with the next row's slice prefetched;
  - 16-bit small words summed in NEON u64 lanes (an offset `x + 2^15` against the coefficient's two 32-bit halves;
    the offset is taken out once per vector and chunk);
  - the pads folded in the same parallel pass (a new defaulted `EncodedStore::fold_rows_with_pads`);
  - outputs written in place at their final length.
  - The same integer sums, so the same field words.
- **The fold alone, in a 6-thread pool:** A 24.6 → 10.1 ms, H 31.5 → 19.3 ms. With six folds at once (six forks
  folding together): A 36.4 → 19.7 ms, H 45.5 → 29.7 ms. [MEASURED, medians, `s1b_bench.log`]
- **In the D55 fork run on the merged tree (A8 + A12), in-process, both arm orders, every pair of every clock
  favouring A8** (stage 10, 6 passes) [MEASURED, `s10_pairs.md`]:
  - **proof only −5.1%**, 4.304 → 4.087 s (29.7 → 31.3 tok/s);
  - **one request from its input −3.2%**, 8.631 → 8.354 s (14.8 → 15.3 tok/s);
  - **the 4-request stream +2.6% steady**, 24.13 → 24.76 tok/s; amortized +2.4%, 20.61 → 21.10 tok/s;
  - user CPU −10.0%, system CPU +0.7%.
- **On the A11 tree before A12** the A/Bs said the same: stage 4 gave proof only −4.9%, sealed −3.3% and stream
  steady +2.7%; stage 3 gave proof only −4.5%. Stage 3's phase clock: open A 50.7 → 28.4 ms per block, open H
  52.1 → 36.8 ms. [MEASURED, `s4_pairs_small.md`, `s3_d55_ab.log`]
- **The zero-fills: an allocator-zeroed `A`/`H` (`calloc`) was measured and dropped.** It made the fork run 5.6%
  SLOWER (system CPU +25%), so `protocol.rs` is unchanged. [MEASURED, `s3_pairs_m11+cols+calloc+phases.md`]
- **The prover's unused column weights: measured and dropped.** `open_zk` builds a 2^14-entry eq table per group
  (45 per block) that no prover byte depends on. Skipping them took a few ms off the openings' phase clock but
  nothing measurable off any wall (stage 4: proof +0.2%, stream −1.6%), so `open_zk` is unchanged (§5.5).
- **No byte moves.** A word-for-word test over random rows and every form; the W16R2 rung's golden `96e4f0b6`
  under every form, every captured fold word for word; the 8B block's proof equal under every form; the
  acceptance (§6).

## 1. The method

- **The capture** (test builds only): `MetalCommit::fold_rows` and `fold_rows_with_pads` copy their inputs (the
  committed rows, the coefficient vectors, the pads) when `fold_capture_for_test(true)` is on.
- **The census and the bench** (`w16r2_tests::a8_store_fold_census_and_bench_on_the_8b_block`, ignored): one
  W16R2 8B T128 block (w16r2_ab's recipe) proved on the device under every form, phase clock on, every digest
  equal; its two captured folds analysed (sparsity, small words) and every fold form timed (7 reps, medians) in a
  rayon pool of 6 threads, of 32, and as six folds at once, each in its own pool of 6 (`six x 6`, the six forks
  folding together). Every timed result was compared with the per-term fold, word for word.
- **The A/B** (`HL_D55_GPU_AB`, new arm words): `m11` / `sparse` / `small` (the store fold form). The builds of
  stages 2–4 also had `cols` / `nocols` (the prover's column weights built or skipped), and those of stages 2 and 3
  had `calloc` / `vecfill` (the zero-fill). Both were dropped and their words removed (§5). `HL_D55_AB_ALTERNATE=1`
  reverses the whole arm order in every odd pass. `../a11/pairs.py` gives each metric's paired change in both
  orders and their mean, which cancels the order bias.

## 2. The census [MEASURED, `s1_bench.log`]

| | A | H |
|---|---:|---:|
| rows x columns (+ pads) | 2,504 x (16,384 + 280) | 2,606 x (16,384 + 280) |
| coefficient vectors | 37 (36 groups + the proximity vector) | 10 (9 + 1) |
| nonzero coefficients | 5,658 = 2.26 rows' worth | 7,726 = 2.96 rows' worth |
| the largest per row | 11 | 3 |
| rows of 16-bit signed words | 1,900 of 2,504 (32-bit: 2,280) | 0 |
| updates on 16-bit 32-column chunks | 85.0% | 1.0% |

Per vector, A: `[34, 34, 18, 6 x 9, 68, 34, 34, 34, 34, 10, 34, 10, 34, 34, 34, 130, 646, 6, 204, 34, 60, 10, 272, 6,
1170, 48, 34, 34, 2504]`; H: `[4, 660, 198, 54, 330, 1290, 64, 4, 2516, 2606]`.

**Why Gram folding does not apply here.** FlashProve's `fold.cuh` combines the small coefficient vectors first
when several folds or rounds read the same big rows, so the rows are read once. Here every opening already folds
once: one pass over the rows for all its vectors, each vector already the lambda-combination of its group's
claims. The vectors are different linear maps, each output in the receipt, so none can be formed from the others.
[INFERRED from the code: `zk_rhos` and `fold_rows_multi_zk` in `zkp-core/src/pcs.rs`, `fold_batch` in
`gpu/mod.rs`]

## 3. The bench [MEASURED, `s1_bench.log`, `s1b_bench.log`; medians in ms]

Before A8 is the M11 message fold, then the pads per-term on one chunk (one thread), appended. `six x 6`: six
folds at once, each in its own pool of six. `pf`: rows of prefetch ahead. Every row equal to the per-term fold.

| form | A pool 6 | A six x 6 | A pool 32 | H pool 6 | H six x 6 | H pool 32 |
|---|---:|---:|---:|---:|---:|---:|
| **before A8** (M11 + pads on one thread) | **24.6** | **36.4** | **9.8** | **31.5** | **45.5** | **11.6** |
| of which the M11 message fold | 22.0 | 32.4 | 7.5 | 29.0 | 40.6 | 8.4 |
| of which the pads, per-term, one chunk | 2.4 | — | 2.4 | 3.3 | — | 3.2 |
| A8 row-sparse, w 128, pf 0 | 44.6 | 55.2 | 12.0 | 53.2 | 71.1 | 13.0 |
| A8 row-sparse, w 256, pf 0 | 22.1 | 34.0 | 7.8 | 27.0 | 42.0 | 8.0 |
| A8 row-sparse, w 256, pf 1 | 14.2 | 23.9 | 5.7 | 18.3 | 29.4 | 5.8 |
| A8 row-sparse, w 512, pf 1 | 15.9 | 24.7 | 6.2 | 20.7 | 30.7 | 7.1 |
| A8 small + NEON, w 128, pf 2 | 10.3 | 18.6 | 4.8 | 20.1 | 31.2 | 6.2 |
| **A8 small + NEON, w 256, pf 1 (the default)** | **10.1** | **19.7** | **4.8** | 19.3 | 29.7 | 6.2 |
| A8 small + NEON, w 512, pf 1 | 12.1 | 19.6 | 5.1 | 22.8 | 31.6 | 7.6 |
| A8 small + NEON, w 1024, pf 1 | 13.5 | 22.8 | 5.8 | 27.7 | 39.0 | 9.8 |

- **Stage 1 (no prefetch):** chunks of 16 and 32 columns, which keep a chunk's accumulators in L1, took 44–55 ms in
  a pool of 6, twice the old fold. [INFERRED] The time follows the number of row starts, not the accumulators'
  footprint.
- **The prefetch:** one row ahead (`prfm`, one hint per 128-byte line of the next row's slice) took the row-sparse
  form from 22.1 to 14.2 ms on A and 27.0 to 18.3 ms on H. Two rows ahead is no better.
- **The small-word path:** on A it takes 14.2 to 10.1 ms. Its NEON lanes beat the scalar loop by about 7% (10.8 →
  10.1 ms). On H, the stage 1b build tested every word of every row chunk, which cost about 1 ms in a pool of 6
  (sparse 18.3 against small 19.3). The final form stops at a chunk's first word when that word is not small, so
  a chunk of full-width words costs one test. That form was not re-timed alone; stages 4 and 10 measure it in the
  D55 run.
- **The default**, chunks of 256 with one row of prefetch and the small path, is the best or within noise of it in
  every column.

## 4. What changed

- **`gpu/metal.rs`** (production; the store-fold functions this lane owns):
  - `fold_segments_a8_opts` with `A8Opts` / `a8_opts`: the A8 fold. One parallel pass over every column chunk of
    one or more segments (the message rows, then the pads); per chunk, row by row, each row's nonzero
    coefficients (listed once) added into exact u128 sums with u64 overflow counts, or for a chunk of small words,
    into four u64 lanes. One field reduction per output entry; outputs written in place.
  - `a8_small_lanes` (NEON `umlal`), `a8_prefetch` (`prfm pldl1keep`, a hint with no architectural effect).
  - `MetalCommit::fold_rows_with_pads`: the hiding opening's `rho^T [M | pads]` in one pass.
  - `MetalCommit::fold_rows`: the form switch (`HL_METAL_A8_FOLD=m11|sparse|small`, default `small`; `m11` restores
    the forms before A8, which stay in the tree).
  - Test-only: the capture, `set_a8_fold_for_test`, the M11 dispatcher for tests.
- **`gpu/mod.rs`**: the Metal store's `fold_rows_with_pads`; test-only exports.
- **`zkp-core/src/pcs/backend.rs`**: `EncodedStore::fold_rows_with_pads`, defaulted to `None` (decline), so the CPU
  store, the CUDA store and `NoExternal` keep the old path exactly.
- **`zkp-core/src/pcs.rs`**: `fold_rows_multi_zk` offers the store the combined fold first (and checks the shape it
  returns); nothing else. (The column-weight skip of stages 2–4 was removed, §5.5.)
- **Tests**: `w16r2_tests.rs` (§6); the A/B words `m11` / `sparse` / `small` in `run_fork_tests.rs`.
- **Not changed by A8:** `protocol.rs` (the zero-fill was dropped, so A8's commits leave it as they found it);
  `metal_kernels.metal`,
  `metal_slot.rs`, `MetalRounds` and the table builds (A12's); the CPU host folds (`fold_rows_host` in zkp-core
  and in `metal.rs`, the oracle and the M11 forms).

## 5. The A/Bs, in-process, both arm orders [MEASURED]

N = 6. "Base first" and "test first" are the passes in which that arm ran first; the bias-solved column is their
mean. (n pairs, n favouring the test.)

### 5.1 Stage 2: everything at once, with the zero-fill (`s2_pairs.md`, 6 passes)

`small+nocols+calloc` against `m11+cols+vecfill`: proof wall −1.4% (+0.6% / −3.4%), sealed +1.1%, stream steady
−3.0% (worse), user CPU −8.0%, system CPU +15.0%. It does not pay; stage 3 shows why.

### 5.2 Stage 3: each part alone, proof only, phase clock on (`s3_pairs_*.md`, `s3_d55_ab.log`, 6 passes, 5 arms)

| against `m11+cols+vecfill` | proof wall, bias solved out | base first | test first | user CPU | system CPU |
|---|---|---|---|---|---|
| **`small` store fold** | **−4.5%** (6 pairs: 6) | −4.2% (3, 3) | −4.8% (3, 3) | −8.5% | +5.7% |
| `nocols` (column weights skipped) | +0.5% (6: 2) | +3.0% (3, 0) | −2.0% (3, 2) | +0.1% | +4.0% |
| `calloc` (zeroed allocation) | **+5.6%** (6: 1) | +9.6% (3, 0) | +1.5% (3, 1) | +1.2% | +24.8% |
| all three | −0.8% (6: 4) | +0.4% (3, 1) | −2.1% (3, 3) | −7.8% | +20.9% |

The phase clock (ms per block, mean of 6 calls, summed over every fork's phases):

| phase | before A8 | `small` | `nocols` | `calloc` | all |
|---|---:|---:|---:|---:|---:|
| open A | 50.7 | 28.4 | 42.6 | 43.2 | 25.3 |
| open H | 52.1 | 36.8 | 51.5 | 48.7 | 28.6 |
| A: allocate + witness planes | 30.9 | 31.1 | 30.2 | 29.8 | 30.3 |
| A commit | 62.6 | 63.0 | 60.8 | 68.2 | 65.8 |
| H commit | 42.9 | 46.8 | 45.1 | 46.8 | 43.3 |
| all phases | 737 | 702 | 738 | 772 | 718 |

- The `calloc` arm's own allocation phase hardly moved (30.9 → 29.8 ms); what it lost is everywhere else (all
  phases +35 ms per block, system CPU +25%). The kernel now zero-fills the fresh pages inside the parallel writers
  of six forks at once, instead of inside one serial fill per fork [INFERRED: system time, faults +3%].
- With five arms the arm positions differ by pass; the `small` arm's pairs favour it in all six.

### 5.3 Stage 4: the confirmation on every clock (`s4_pairs_*.md`, `s4_d55_ab.log`, 6 passes, 3 arms)

After stage 3 the zero-fill was removed from the tree. Arms: `m11+cols` (the tree before A8), `small+cols` (the
A8 store fold, which is the final default), `small+nocols`. Each arm and pass made a proof-only call, one sealed
request and a stream of 4.

**`small+cols` against `m11+cols`** (`s4_pairs_small.md`):

| metric | base first | test first | order bias solved out | means, before A8 / A8 |
|---|---|---|---|---|
| proof wall | −3.0% (3, 2) | −6.8% (3, 3) | **−4.9%** | 4.595 / 4.364 s = 27.9 / 29.3 tok/s |
| forks phase | −2.4% (3, 2) | −7.3% (3, 3) | −4.9% | 4.211 / 4.002 s |
| one request from its input (sealed) | −3.3% (3, 3) | −3.2% (3, 3) | **−3.3%** | 8.859 / 8.570 s = 14.4 / 14.9 tok/s |
| stream of 4, steady state | +1.1% (3, 2) | +4.3% (3, 3) | **+2.7%** | 23.38 / 24.00 tok/s |
| stream of 4, amortized | +2.5% (3, 3) | +4.0% (3, 3) | **+3.3%** | 19.87 / 20.51 tok/s |
| user CPU (proof-only call) | −7.9% | −9.0% | −8.5% | 55.7 / 51.0 s |
| system CPU (proof-only call) | +3.5% | +10.2% | +6.9% | 6.7 / 7.2 s |

- Bests: proof only 4.434 → 4.124 s (28.9 → 31.0 tok/s); sealed 8.721 → 8.501 s; stream steady 24.08 → 24.28 tok/s.
- Per-request latency in the stream: 9.1–9.5 s for the first request and 10.0–10.9 s for the others before A8;
  8.8–9.3 s and 9.5–10.4 s with it.
- Receipts: all 18 streams' receipts verified after their clocks, and each arm's first proof-only and sealed
  receipt; fork receipts 818,728,672 B in every call, D12a 818,728,480 B.
- The system CPU grew a little in every A/B with the A8 fold (+5.7% in stage 3, +6.9% here, about 0.4 s per call)
  [MEASURED]. Its cause is not identified [ESTIMATE: the fold's outputs are now allocated per call in parallel, so
  their first-touch faults land on several threads].

### 5.4 Stage 10: the final default on the merged tree (`s10_pairs.md`, `s10_d55_ab.log`, 6 passes)

The A8 branch merged with `perf/zk-batch-optimizations` at A12 (`fe6ae5fe`), whose GPU-built slot tables took the
largest host region off the forks. `small` (the default) against `m11`:

| metric | base first | test first | order bias solved out | means, before A8 / A8 |
|---|---|---|---|---|
| proof wall | −4.7% (3, 3) | −5.4% (3, 3) | **−5.1%** | 4.304 / 4.087 s = 29.7 / 31.3 tok/s |
| forks phase | −5.2% (3, 3) | −5.5% (3, 3) | −5.3% | 3.937 / 3.726 s |
| one request from its input (sealed) | −3.5% (3, 3) | −2.9% (3, 3) | **−3.2%** | 8.631 / 8.354 s = 14.8 / 15.3 tok/s |
| stream of 4, steady state | +3.1% (3, 3) | +2.2% (3, 3) | **+2.6%** | 24.13 / 24.76 tok/s |
| stream of 4, amortized | +2.6% (3, 3) | +2.1% (3, 3) | **+2.4%** | 20.61 / 21.10 tok/s |
| user CPU (proof-only call) | −10.0% | −9.9% | −10.0% | 47.2 / 42.5 s |
| system CPU (proof-only call) | +1.2% | +0.1% | +0.7% | 6.82 / 6.83 s |

- Every pair of every metric favours A8.
- Bests: proof only 4.274 → 4.022 s (29.9 → 31.8 tok/s); sealed 8.442 → 8.204 s (15.2 → 15.6 tok/s); stream steady
  24.41 → 24.95 tok/s.

### 5.5 The prover's column weights

`open_zk` groups the claims by column key and builds each group's column weights, an eq table of 2^14 entries,
which only the verifier reads (`zk_rhos` uses the row weights and values). Stage 1's phase clock (one block, 32
threads) put them at about 4–5 ms of open A [INFERRED]. Stage 3 saw open A 50.7 → 42.6 ms per block with them
skipped. But the walls did not move:
- stage 3, alone: +0.5% (+3.0% / −2.0%);
- stage 4, on top of the A8 fold (`s4_pairs_nocols_given_small.md`): proof +0.2% (−3.4% / +3.8%, an order effect
  only), sealed −0.5%, stream steady −1.6% (−0.1% / −3.1%).

[INFERRED] The time comes off one thread's host path while the fork waits on the GPU or the pool anyway. It does
not pay in both orders, so the switch was removed: `open_zk` and `group_zclaims` are as before A8.

## 6. Acceptance [MEASURED]

**Stage 9** (`s9.sh`, `s9.progress`, `s9_*.log`, `s9.guard.json`) ran on the final tree, which is the A8 branch
merged with A12 (`d891e2f3`), with the A8 fold as the default. One guarded job (433 s, peak RSS 25.2 GiB):
- **build:** rc 0. **The no-feature `cargo check --tests`** (no `gpu-metal`): rc 0.
- **The full lib suite** (`--test-threads=8`, the R13 loader fixtures): **924 passed, 3 failed, 103 ignored**. The
  three failures are exactly the known ones:
  - `review_tests::a_toy_receipt_made_before_f12_is_refused`;
  - `trained_block::accuracy::profile_tests::accuracy_v2_dense_witness_matches_all_nineteen_independent_integer_traces`;
  - `trained_stack_tests::review_n_r6_b_a_stale_statement_writing_dir_is_removed_or_refused_by_name`.
  - 924 is A12's merged 923 plus `a8_store_fold_forms_equal_the_per_term_fold_word_for_word`. 103 ignored is A12's
    101 plus the two ignored A8 tests.
- **zkp-core's lib tests:** 78 passed, 2 ignored.
- **The A8 byte tests:**
  - **the word-for-word test** (in the suite): 765 fold forms, every form at every chunk width, prefetch distance
    and lane kind, on random rows of every word kind, all equal to the per-term fold. This includes the small
    path's overflow edge at 2^16 − 1 rows and its standing aside at 2^16.
  - **the W16R2 rung under every store fold form** (`HL_GPU_REQUIRED=1`): M11, row-sparse and small all give the
    golden `96e4f0b6`. Every fold each proof made was captured and folded again by 90 forms, all equal word for
    word.
  - **the 8B block** (stages 1 and 1b): its core proof under every form gives the same digest, and every timed
    fold of its two store folds equals the per-term fold.
- **The A11 pool byte tests:** the seeded W16R2 rung in pools of 1, 2, 3 threads and on the global pool gives
  `96e4f0b6…` (CPU). Three concurrent Metal proofs, each in its own pool of 1, 2 and 6, give `96e4f0b6` every time.
- **The A7 queue byte test** (`HL_GPU_REQUIRED=1`): `96e4f0b6` six times on the shared queue and six times on
  per-thread queues.
- **The W16R2 rung golden** (`HL_GPU_REQUIRED=1`): CPU = Metal = `96e4f0b6f34f7876…`.
- **The six post-F12 trained digests** (`HL_GPU_REQUIRED=1`): 5a6193d3, f590b01f, 79f987ef, a8258241, 0e88d84f and
  90003b76 are all present.
- **The D55 harness on the final default** (`s9_d55.log`; `HL_D55_WORKERS=6 HL_D55_PASSES=2 HL_D55_SEALED=1
  HL_D55_PIPE=4`):

| W16R2 8B T128, 32 blocks, N = 6 | final tree (A11 + A12 + A8, `s9_d55.log`) | A11's final tree, for reference (`../a11/s10_d55.log`) |
|---|---:|---:|
| proof only, the two calls | 4.178, 4.114 s | 4.418, 4.335 s |
| proof only, best / mean | 31.11 / 30.87 tok/s | 29.53 / 29.25 |
| one request from its input (sealed), best / mean | 8.312 s = 15.40 / 15.32 tok/s | 8.088 s = 15.83 / 15.59 |
| stream of 4, steady / amortized | 24.61 / 20.84 tok/s | 23.90 / 20.68 |
| per-request latency in the stream | 8.96, 9.83, 9.98, 9.37 s | 8.69, 10.19, 10.31, 10.03 |
| serial D12a, best / mean | 9.692 / 9.790 s | 10.414 / 10.485 |

- **Receipts:** every receipt the harness verifies verified: the D12a verifier on the first serial pass, the D55
  verifier on the first proof-only and sealed passes, and all 4 stream receipts after the clock. Fork receipts are
  818,728,672 B and D12a receipts 818,728,480 B, unchanged.
- The A11 column is another process on another day's box state, and this tree also has A12. The in-process A/Bs of
  §5 are the measurement of A8. The sealed single call here (8.31 s) is slower than A11's best (8.09 s), while
  stage 10's in-process A/B on this same tree gave sealed −3.2% in every pair: the single sealed call varies with
  the sealing pass (3.9–4.3 s here) [INFERRED].

The guard records: s1 326 s (peak RSS 5.5 GiB), s1b 180 s (4.7), s2 803 s (31.5), s3 227 s (27.5), s4 1,078 s (31.4),
s9 433 s (25.2), s10 770 s (26.7); every job exit 0.

## 7. What was not done

- **Gram folding of the zero-check rounds** (the plan's second half). They are device kernels and `MetalRounds`,
  which are A12's files this time. Not examined.
- **The device fold** (`fold_rows_device`, `HL_METAL_DEVICE_FOLD=1`) was not re-measured (its kernels are in
  `metal_kernels.metal`) and is unchanged; it declines `fold_rows_with_pads`, so it keeps the old path.
- **The opening's other host costs.** The transcript absorbs the clear vectors on one thread: for A, 36 vectors of
  16,664 `Fp2`, about 9.9 MB of BLAKE3 per block. That is about 2–3 ms [ESTIMATE]. It lives in `transcript.rs`, not
  this lane's file. BLAKE3's tree hash gives the same digest from a multi-threaded `update_rayon`, so this is a
  byte-preserving candidate for later.
- **The zero-fills.** Two forms are now measured, and both lost: A11's reuse pool (+2.8%) and A8's `calloc` (+5.6%).
  The fill stays `vec![Fp::ZERO; len]`. Untried: a zeroed allocation whose first touch the fork thread makes itself.
- **The column weights**, measured and dropped (§5.5).
- **The +7% system CPU** with the A8 fold (about 0.4 s per call) is not explained; it did not stop any clock from
  improving.
- **N = 1 was not A/B'd in-process.** The bench at 32 threads: A 9.8 → 4.8 ms, H 11.6 → 6.2 ms (`s1b_bench.log`).
- **Untimed paths:** the plain (systematic) store form under the A8 fold is tested (sources strided by 2 and 4)
  but not timed, since it is not on the D55 path. The CPU store and the CUDA store keep the old fold (the trait's
  default).

## 8. Files

- `ops/zkp-mvp/gpu-metal/hashline/src/gpu/metal.rs` (production, the store-fold region only):
  - `fold_segments_a8_opts`, `fold_rows_host_a8`, `A8Opts`, `a8_opts`, `A8Seg`, `a8_small_lanes`, `a8_prefetch`,
    `a8_shifted`;
  - `MetalCommit::fold_rows_with_pads`; the form switch in `MetalCommit::fold_rows` (`HL_METAL_A8_FOLD`);
  - `fold_rows_host_m11` (the M11 dispatch, factored out unchanged);
  - test-only: the capture, `set_a8_fold_for_test`, `fold_segments_a8`, `fold_rows_host_m11_for_test`.
- `ops/zkp-mvp/gpu-metal/hashline/src/gpu/mod.rs`: the Metal store's `fold_rows_with_pads`; test-only exports.
- `ops/zkp-mvp/gpu-metal/zkp-core/src/pcs/backend.rs`: `EncodedStore::fold_rows_with_pads` (defaulted, declines).
- `ops/zkp-mvp/gpu-metal/zkp-core/src/pcs.rs`: `fold_rows_multi_zk` offers the store the combined fold.
- Tests:
  - `hashline/src/private_block/w16r2_tests.rs`: `a8_store_fold_forms_equal_the_per_term_fold_word_for_word` (in the
    suite); `a8_w16r2_rung_golden_under_every_store_fold_form` and `a8_store_fold_census_and_bench_on_the_8b_block`
    (ignored, Metal);
  - `hashline/src/private_block/run_fork_tests.rs`: the A/B words.
- This directory:
  - the stage scripts `s1.sh`, `s1b.sh`, `s2.sh`, `s3.sh`, `s4.sh` (the A11 tree), and `s9.sh` (acceptance) and
    `s10.sh` (the A/B) on the merged tree, with their logs, progress files and guard records;
  - `run_stage.py` and `watch.py` (A11's, relabelled); the pairs come from `../a11/pairs.py`.
  - `s2` and `s3` ran builds that still had the `calloc` and `nocols` switches; their code is not in the tree.

**For the privacy gate.** Changed digests: `gpu/metal.rs`, `gpu/mod.rs`, zkp-core `pcs.rs` and `pcs/backend.rs`
(production), plus test files. `protocol.rs`, `private_block.rs`, `metal_kernels.metal`, `metal_slot.rs` and
zkp-core `field.rs` and `transcript.rs` did **not** change. The new fold reads the same committed rows, pads and
coefficient vectors as before, and returns the same words. It keeps nothing past the call: its scratch is dropped
at the end of the parallel region. The capture of inputs exists only in test builds.
`D55_REAL_CONTENT_PRIVACY_GATE_PASSED` is untouched.
