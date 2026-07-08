# A1 -> Route R integration tranche — progress log

Task: integrate the A1 auxiliary-modulus NTT kernels (aux_ntt.rs) into the
Route R prototype (ring_lattice.rs) per A1_AUX_NTT_REPORT.md Section 5;
convert the ~15-30 s/pass gate from projection to measurement at the
arithmetic layer. Build with:
PATH="$HOME/.rustup/toolchains/stable-x86_64-unknown-linux-gnu/bin:$PATH" cargo build --release
Suite: python3 -m unittest discover -s tests (must stay 37/37).

## State

- [x] Setup: merged perf/zk-batch-optimizations (0e64ca4 present). Required reading done.
- [x] U1 shared kernel module (src/aux_ntt_core.rs, #[path] from aux_ntt.rs; aux_ntt self-test green incl. NEW tests: A1GemmKernel auto-path, a1_regime_path, chunked combination sum with 2048 terms at q46 crossing the 1023 chunk limit). New shared API: A1CommitKernel::new(.., b_max, ..), A1LimbCommitKernel (b_max stored), A1GemmKernel enum (auto single/limb), a1_regime_path, a1_combination_sum, cached_bytes().
- [ ] U2 commit-path integration (cached NTT CRS + A1 commit at k=2/q46-regression and k=8/q31; differential + boundary tests)
- [ ] U3 mask + combination-sum paths (auto single-prime/limb fallback; differential tests)
- [ ] U4 capacity assertions in route_r_params.py + Rust derivation; regime->path table emitted
- [ ] U5 measure (idle machine, medians of pinned reps) + reconcile RING_MULT_BOTTLENECK.md S6, A1_AUX_NTT_REPORT.md, LLM_SCALE_ESTIMATE.md

## Decisions

- Shared module named src/aux_ntt_core.rs (manifest.rs precedent: #[path] include
  from each bin; no library target).
- ring_lattice parameter points: the k=2 legacy point (q = 2^31 - 19) and the
  recommended (k = 8, q8 = 2^31 - 399). The k=2/q46 regression regime
  (q46 = 2^46 - 635) is covered by a dedicated differential commit-kernel test
  inside ring_lattice (generic Zq/ring_ctx machinery works at q46) — the q46
  Sigma round itself is not prototyped there (would need a q46 CRS sampler;
  arithmetic-layer coverage is the goal).
- Kernel sharing design: A1CommitKernel gains a construction-time contract
  bound b_max (regime property, checked static per report discipline);
  A1GemmKernel enum auto-selects single-prime vs limb-split from capacity()
  (automatic fallback, never assert for over-capacity regimes; assert only if
  even limb-split fails = derive-time-failure defense).
- Per-CRS cache (A1Paths): stacked [A1;A2] ternary commit kernel, A1-rows
  mask kernel (b = 12*sigma_max, also serves digit-witness commits), A1-rows
  verify kernel (b = ceil(sqrt(bound_sq))_max -> limb-split at q31). Verifier
  norm-checks BEFORE the matvec, so the verify contract bound is sound.
- Combination sums: shared chunked kernel a1_combination_sum (quinary x mod-q,
  chunk at max_n_acc); verifier c*t1 goes through ring_mul_q_single.

## Log

- (session 1) Merged 0e64ca4; read A1_AUX_NTT_REPORT, RING_MULT_BOTTLENECK,
  aux_ntt.rs, ring_lattice.rs, route_r_params.py, LLM_SCALE_ESTIMATE, manifest.rs.
  Tests do NOT invoke ring_lattice/aux_ntt binaries (suite = 37 python tests;
  cargo build + other bins' self-tests). Next: U1.
