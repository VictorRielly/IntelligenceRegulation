# C2/C3 Speedup Bundle (`Opt 1` Sparse GPU Fold + `Opt 4` Stride-4 `mask_open` + `w16_histograms_cols`)

- **Date:** 2026-11-20 / 2026-11-22
- **Isolated Worktrees / Branches:**
  - Original isolated A/B branch: `.agy-worktrees/c2c3-sparse-fold` (`agy/c2c3-sparse-fold` at `43b48760`, branched off `f323bb82`).
  - Composed branch on merged `HL_METAL_FUSED_RS` (`651abb96`): `.agy-worktrees/composed-frs-sf` (`agy/composed-frs-sf`, base commit `5afee227` + second-read fix commit).
- **Scope:** 100% `hashline`-only (8 existing files edited under `ops/zkp-mvp/gpu-metal/hashline/`, 0 `zkp-core` edits, 0 new `.rs` files), 0 transcript/verifier/protocol changes, byte-identical to CPU/reference on every verified unit, installed-classifier, and `W16R2_RUNG_H24` rung proof shape.
- **Switches & Always-On Parts:**
  - `Opt 1` (`HL_METAL_SPARSE_FOLD=1`, **default OFF**; `a22` arm words `sf0` / `sf1`): 1-CB row-sparse GPU opening fold kernels (`k_fold_sparse_partial` / `k_fold_sparse_reduce` in `metal_kernels.metal`), lazily compiled behind `OnceLock` (`SparseFoldPipes`) on first enabled dispatch, env read cached in `OnceLock`, with automatic fallback to the host fold (counted in `SPARSE_FOLD_FALLBACKS`) on cap exceed (`k > 64`, threadgroup/u32 limits), lazy pipeline creation failure, or device error.
  - `Opt 4` (**always on**, proved equal for every input in `SPARSE_FOLD_BUNDLE_REVIEW_20261122.md`): stride-4 `mask_open` using static public coset-7 power tables (`src/zk.rs`) verified word-for-word against the verbatim polynomial-multiply reference (`src/zk_f12_tests.rs`). `MaskCommit::encoded` carries the documented coset-7 evaluation invariant checked via `debug_assert_eq!` at `j = 0` in `mask_open`.
  - `w16_histograms_cols` (**always on**, proved equal for every input in `SPARSE_FOLD_BUNDLE_REVIEW_20261122.md`): flat `u32`/`u64` histogram binning over `LookedCol` views without materializing intermediate `Vec<i64>` columns (`src/private_block/protocol.rs`).
- **Privacy Note (L6, switch-on only):** When `HL_METAL_SPARSE_FOLD=1` is enabled, the Metal scratch buffers (`pads_buf`, `part_buf`, `out_buf`) return to the process-wide Metal buffer pool on drop without zeroing, matching the existing M4f policy used for commitment data buffers. These buffers stay strictly inside the prover process and are never serialized or published.

## 1. Original Base (`f323bb82`, `agy/c2c3-sparse-fold`) Build & Byte-Parity Gate (`11/11` PASS)

All runs serialized through `scripts/zk60_resource_guard.py` (default 5 s poll):

| Gate | Guard Run ID | Class | Exit | Wall | Peak RSS | Peak VRAM | Result |
|---|---|---|---:|---:|---:|---:|---|
| Build (`gpu-metal` lib + `zk60_metal_commit` + `--no-default-features`) | `966286f25cea` (`agy-c2c3-build2`) | `build` | 0 | 246 s | 4.50 GiB | — | PASS (0 warnings in edited files) |
| CPU parity & F12 safety (6 tests) + Metal commit parity (3 tests, `HL_METAL_SPARSE_FOLD=1`) | `9ebf7ef042fa` (`agy-c2c3-parity2`) | `gpu` | 0 | 180 s | 4.51 GiB | 2,068 MiB | PASS (`9/9` ok) |
| Ignored GPU sparse-fold parity (`19` shapes + `W16R2_RUNG_H24` golden digest `96e4f0b6`, `shared` & `thread` queues) | `06338913f378` (`agy-c2c3-parity-gpu`) | `gpu` | 0 | 2 s | 0.64 GiB | 1,127 MiB | PASS (`2/2` ok) |

Verified tests (`[MEASURED]`):
1. `w16_histograms_cols_u32_matches_reference_with_and_without_misses` — valid W16R2 rung witness, mutated witness with injected misses, synthetic `LookedCol` variants (`Words`, `Term` with `c=1`/`c!=1`/wrapping/multi-chunk/empty), and pinned U8 vs Range miss semantics.
2. `mask_open_stride4_matches_poly_mul_reference_byte_for_byte` + all 4 `f12_*` soundness/rejection tests.
3. `sparse_fold_device_equals_per_term_fold_word_for_word` — 19 shapes/edge cases including `k=64` cap and `k=65` fallback (expanded in Section 4 below to cover all 7 installed W16R2 Shieldstral classifier shapes).
4. `sparse_fold_w16r2_rung_golden` — golden receipt digest `96e4f0b6` on both `queues=shared` and `queues=thread` with 2 folds verified word-for-word (expanded in Section 4 below to assert exact `SPARSE_FOLD_CALLS`, `SPARSE_FOLD_FALLBACKS == 0`, and `FUSED_RS_CALLS` deltas across `frs0+sf1` and `frs1+sf1`).
5. `m1_plain_commit_leaves_root_columns_and_folds_match_the_cpu`, `m1_zk_commit_and_opening_bytes_match_the_cpu`, `m1_keyed_zk_commit_and_opening_bytes_match_the_cpu` (`9` shapes each under `HL_METAL_SPARSE_FOLD=1`).

## 2. Quiet Alternating `a22_stream_ab` A/B (`W16R2_8B_T128_H24`, `L=32`, `N=6`, 6 Alternating Passes, Base `f323bb82`)

Common flags:
`HL_GPU=1 HL_GPU_REQUIRED=1 HL_PB_ORACLE=0 HL_METAL_TIMING=0 HL_D55_PROFILE=W16R2_8B_T128_H24 HL_D55_L=32 HL_D55_WORKERS=6 HL_A19_BUDGET_GIB=32 HL_A22_AB_PASSES=6 HL_D55_AB_ALTERNATE=1`

### 2A. Primary `lanes2` A/B (`serve8+lanes2+ba1+sf0` vs `serve8+lanes2+ba1+sf1`)
- **Guard Run ID:** `2fc50f42a9d7` (`agy-c2c3-ab-l2`, `--class gpu`, `exit=0`, `wall=404s`, `peak_rss=34.08G`, `min_avail=159.90G`, `peak_vram=23,955 MiB`).
- **Pre-registered PASS rule (`Opt 1` on `lanes2`):** lower steady gap in `>= 5/6` passes AND `>= 1.5%` median gap reduction, `<= 128 MiB` pooled scratch/call, 100% byte-identical on verified shapes.
- **Verdict:** **PASS (unanimous `6/6` wins, `2.80%` median gap reduction, `2.57%` mean, `+0.1 GiB` peak footprint).**

| Pass | `sf0` steady tok/s (gap s) | `sf1` steady tok/s (gap s) | Gap delta (ms) | Gap reduction | Peak GiB (`sf0` / `sf1`) |
|---:|---:|---:|---:|---:|---:|
| 0 | 36.62 (3.4954) | 37.67 (3.3979) | -97.4 | +2.79% | 45.1 / 46.2 |
| 1 | 37.01 (3.4585) | 37.36 (3.4261) | -32.4 | +0.94% | 46.8 / 47.1 |
| 2 | 36.71 (3.4868) | 37.77 (3.3889) | -97.9 | +2.81% | 47.0 / 47.1 |
| 3 | 36.74 (3.4839) | 38.19 (3.3517) | -132.3 | +3.80% | 46.6 / 46.6 |
| 4 | 37.23 (3.4381) | 37.75 (3.3907) | -47.4 | +1.38% | 47.1 / 47.1 |
| 5 | 36.27 (3.5291) | 37.66 (3.3988) | -130.3 | +3.69% | 47.1 / 47.2 |
| **Summary** | **mean 36.76 (best 37.23)** | **mean 37.73 (best 38.19)** | **med -97.7 / mean -89.6** | **med +2.80% / mean +2.57%** | **max 47.1 / 47.2** |

Per-request phase medians (`n = 48` requests/arm, `[MEASURED]`):
- `sf0`: `seal` `2.853 s`, `prove` `3.858 s` (`commit 0.330`, `forks 3.425`, `join 0.074`), `wait 0.368 s`.
- `sf1`: `seal` `2.730 s` (`-123 ms`), `prove` `3.795 s` (`commit 0.355`, `forks 3.369` `-56 ms`, `join 0.050` `-24 ms`), `wait 0.384 s`.
- Amortized mean: `33.72 -> 34.58 tok/s` (best `34.85`); mean latency `14.671 -> 14.326 s` (first request `5.999 -> 5.868 s`, best `5.693 s`).
- Against prior post-A35 baseline on `f323bb82` (`35.96 tok/s`, `3.560 s/req`, `29.4x fp16`): `sf0` (`Opt 4` + `w16_histograms_cols`) is `+2.2%` (`36.76 tok/s`, `3.482 s/req`) and `sf1` (full C2/C3 bundle) reaches **`37.73 tok/s` mean (`3.393 s/req`, `28.0x fp16`, `+4.9%` combined; best `38.19 tok/s` = `3.352 s/req`, `27.7x fp16`)**.

### 2B. 3-Lane Sensitivity A/B (`serve9+lanes3+ba1+sf0` vs `serve9+lanes3+ba1+sf1`)
- **Guard Run ID:** `fb255cf18637` (`agy-c2c3-ab-l3`, `--class gpu`, `exit=0`, `wall=450s`, `peak_rss=42.55G`, `min_avail=147.15G`, `peak_vram=25,337 MiB`).
- **Pre-registered sensitivity bar (`lanes3`):** `>= 5/6` wins AND `>= 2.0%` median gap reduction.
- **Verdict:** **Unanimous `6/6` wins, `+1.64%` median (`+1.79%` mean) gap reduction — positive in every pass (`12/12` combined across `lanes2`+`lanes3`), slightly below the `2.0%` `lanes3` sensitivity bar.** Note that at `N=6` workers, `lanes3` incurs `2.8–3.0 s` prover-queue wait and `+8.4 GiB` RAM, so `lanes2+sf1` (`37.73 tok/s`, `47.2 GiB`) outperforms `lanes3+sf1` (`37.55 tok/s`, `55.6 GiB`).

| Pass | `sf0` steady tok/s (gap s) | `sf1` steady tok/s (gap s) | Gap delta (ms) | Gap reduction | Peak GiB (`sf0` / `sf1`) |
|---:|---:|---:|---:|---:|---:|
| 0 | 37.19 (3.4418) | 38.23 (3.3482) | -93.6 | +2.72% | 54.3 / 54.8 |
| 1 | 36.64 (3.4934) | 38.08 (3.3613) | -132.1 | +3.78% | 54.5 / 54.4 |
| 2 | 37.56 (3.4079) | 37.70 (3.3952) | -12.7 | +0.37% | 55.1 / 55.3 |
| 3 | 36.86 (3.4726) | 37.25 (3.4362) | -36.4 | +1.05% | 55.3 / 55.4 |
| 4 | 36.49 (3.5078) | 37.32 (3.4298) | -78.0 | +2.22% | 55.4 / 55.6 |
| 5 | 36.51 (3.5059) | 36.73 (3.4849) | -21.0 | +0.60% | 55.3 / 55.5 |
| **Summary** | **mean 36.87 (best 37.56)** | **mean 37.55 (best 38.23)** | **med -57.2 / mean -62.3** | **med +1.64% / mean +1.79%** | **max 55.4 / 55.6** |

Per-request phase medians (`n = 54` requests/arm, `[MEASURED]`):
- `sf0`: `seal 2.866 s`, `prove 4.144 s` (`commit 0.589`, `forks 3.439`, `join 0.078`), `wait 2.819 s`.
- `sf1`: `seal 2.803 s` (`-63 ms`), `prove 4.134 s` (`commit 0.595`, `forks 3.418` `-21 ms`, `join 0.053` `-25 ms`), `wait 3.042 s`.

## 3. Composed Branch (`agy/composed-frs-sf` on `651abb96`) Verification & Second-Read Fixes (`SPARSE_FOLD_BUNDLE_REVIEW_20261122.md`)

### 3A. Initial Composed Commit (`5afee227` on `651abb96`) [MEASURED]
- Build (`--features gpu-metal -j 4 --lib --test zk60_metal_commit --no-run`): `11c57710cde0` (exit 0, 38 s, 3.32 GiB).
- GPU commit/open parity across all 3 arms (`default off/off`, `frs1+sf0`, `frs1+sf1`) + unit tests (`a22_arm_parses_frs0_and_frs1`, `w16_histograms_cols_u32_matches_reference_with_and_without_misses`, `mask_open_stride4_matches_poly_mul_reference_byte_for_byte`): `5f7cfa2b5e72` (exit 0, 47 s, 4.99 GiB, 5,696 MiB VRAM — 7/7 PASS in each arm, 3/3 lib tests PASS).
- Composed `frs1+sf1` sparse-fold GPU parity + `--no-default-features` check: `a33092a92ec8` (exit 0, 14 s, 0.73 GiB, 1,593 MiB VRAM).

### 3B. Second-Read Review Fixes (M1–M5, L1, L4, L6, L8, L9)
Following Claude's Opus second read (`results/zk60_claude_review_20261116/SPARSE_FOLD_BUNDLE_REVIEW_20261122.md`, 0 High findings, both always-on parts proved equal for every input):
- **M1:** committed this write-up in `agy/composed-frs-sf` and re-verified on top of `651abb96`.
- **M2:** removed `"k_fold_sparse_partial"` and `"k_fold_sparse_reduce"` from eager `KERNELS` (back to 23 baseline names) and moved them into lazy `SparseFoldPipes` behind `OnceLock` (pipeline creation failure falls back cleanly to host fold with `SPARSE_FOLD_FALLBACKS += 1`).
- **M3:** mapped device `Err` from `fold_rows_sparse_device` to the host fold fallback (`SPARSE_FOLD_FALLBACKS += 1`) instead of propagating an error into `zkp-core`'s `expect`.
- **M4:** added `SPARSE_FOLD_CALLS` and `SPARSE_FOLD_FALLBACKS` counters + `metal_set_sparse_fold_for_test` / `metal_sparse_fold_calls_for_test` / `metal_sparse_fold_fallbacks_for_test`, asserted with exact deltas in `m1_plain_*`, `m1_zk_*`, `m1_keyed_zk_*`, `m1_sparse_fold_and_fused_rs_composed_parity` (holding `METAL_TEST_LOCK`), `sparse_fold_device_equals_per_term_fold_word_for_word`, and `sparse_fold_w16r2_rung_golden`.
- **M5 + L9:** added all 7 installed W16R2 Shieldstral classifier commitment shapes (`2504/2606/38 x 2^14 q=280`, `76/41/38 x 2^12 q=256`, `6 x 2^8 q=256`) to `sparse_fold_device_equals_per_term_fold_word_for_word` (22 shapes + edge cases) and 5 installed geometries across `frs0+sf0`, `frs0+sf1`, and `frs1+sf1` to `m1_sparse_fold_and_fused_rs_composed_parity`.
- **L1:** cached `HL_METAL_SPARSE_FOLD` environment lookup in `OnceLock`.
- **L4:** documented `MaskCommit::encoded` coset-7 invariant and added `debug_assert_eq!` at `j = 0` inside `mask_open`.
- **L6:** documented buffer-pool reuse behavior in the privacy note above.
- **L8:** tested composed `frs1+sf1` end-to-end with exact counter deltas in both `m1_sparse_fold_and_fused_rs_composed_parity` and `sparse_fold_w16r2_rung_golden` (`shared` & `thread` queues).

Post-fix guarded verification runs on `agy/composed-frs-sf` (`[MEASURED]`):
- Build (`--features gpu-metal -j 4 --lib --test zk60_metal_commit --no-run`): `31307396c414` (`agy-composed-fix-build`, exit 0, 10 s, 2.86 GiB, 0 warnings in edited files).
- GPU commit/open parity + unit tests + CPU-only check: `5ce8702edcc6` (`agy-composed-fix-parity`, exit 0, 49 s, 5.46 GiB, 4,165 MiB VRAM):
  - `zk60_metal_commit` default OFF: `8/8` PASS (`m1-plain/zk/zk-keyed` exact `sparse_folds=0`; `m1-sparse-fold-composed` 5 installed shapes across `frs0+sf0`, `frs0+sf1`, `frs1+sf1` PASS).
  - `zk60_metal_commit` `HL_METAL_FUSED_RS=1 HL_METAL_SPARSE_FOLD=1`: `8/8` PASS (`m1-plain/zk/zk-keyed` exact `sparse_folds=9`, 0 fallbacks; `m1-sparse-fold-composed` 5 installed shapes PASS).
  - Lib unit tests: `a22_arm_parses_frs0_and_frs1`, `w16_histograms_cols_u32_matches_reference_with_and_without_misses`, `mask_open_stride4_matches_poly_mul_reference_byte_for_byte` (`3/3` PASS, with `MaskCommit::encoded` `debug_assert_eq!` active).
  - CPU-only `cargo check --no-default-features --lib --test zk60_metal_commit`: PASS.
- Ignored GPU sparse-fold 7-installed-shape + `frs1+sf1` rung golden: `97662854ca1c` (`agy-composed-fix-ignored`, exit 0, 15 s, 1.08 GiB, 2,205 MiB VRAM):
  - `sparse_fold_device_equals_per_term_fold_word_for_word`: PASS (`26` shapes/edge cases incl. all 7 installed W16R2 Shieldstral classifier shapes, `k=64` cap, and `k=65` fallback with exact `SPARSE_FOLD_CALLS`/`SPARSE_FOLD_FALLBACKS` deltas).
  - `sparse_fold_w16r2_rung_golden`: PASS (golden digest `96e4f0b6` on both `shared` and `thread` queues for BOTH `frs0+sf1` `[2 sparse folds, 0 fallbacks, 0 fused RS]` and `frs1+sf1` `[2 sparse folds, 0 fallbacks, 2 fused RS]`).
