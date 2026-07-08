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
- [x] U2+U3 (committed jointly — same file, intertwined round signatures):
  ring_lattice.rs integrated. A1Paths per-CRS cache (commit stacked [A1;A2]
  b=1 / mask b=12*sigma_max / verify b=isqrt(bound_sq)_max), KernelPath
  {School oracle, A1} threaded through commit + plain/k8/digit Sigma rounds
  (mask commits, digit-witness commits, verifier matvec, c*t1 single-prime).
  Differential battery (section 13): same-seed BIT-IDENTICAL proofs on all 3
  rounds + cross-path verification; capacity-boundary commits exact at q31,
  q8, q46 (59-bit case); q46 regression vs schoolbook AND k2 split kernel;
  mask-regime fallback auto (limb at q46, single at q8; q8 verify kernel
  falls back to limb); combination sum vs k8 split accumulation; gate-term
  limb product. Bench section 14: A1 rows in both tables; FFN-shape 47x72
  @q8 A1 0.168 us/ring-MAC vs k8+Kara 1.039 -> 6.2x (97.4 eff GMAC/s);
  prototype-shape 8x26: 0.300 us -> 3.6x vs k8+Kara, 28.7x vs naive; Sigma
  rounds (same-seed, median of 9): k=2 prove 6.04->0.98 ms, k=8 9.11->1.49,
  digit 27.1->3.31; verify 2.6->0.25 / 7.9->0.78. Memory delta: 1092 KB per
  CRS point (260 commit + 208 mask + 624 verify-limb). Suite 37/37 OK.
- [x] U4 capacity assertions: Rust side landed with U2/U3 (print_a1_regime_table
  at both parameter points + construction asserts in kernels). Python side:
  P0 block in route_r_params.py (a1_path/a1_paths_for/a1_require/
  a1_capacity_table mirroring aux_ntt_core), out["a1"] recorded in derive()
  and derive_q2(), P0 summary lines under every show() table (worst-case
  2^61 row correctly marked REJECTED), a1_capacity_section() emits enforced
  exact-prime tables at (k8,q8_31) e in {2,3,4}, FFN e=4, (k2,q46) baseline,
  plus a loud-failure self-check (2^61 point raises ValueError). FINDING:
  q31 mask regime sits at the 63-bit edge — single-prime at e=2 and the
  N_r=26 prototype, limb-split at e in {3,4}/FFN shapes (63.8-64.6 bits);
  commit regime single-prime everywhere incl. q46.
- [x] U5 measured (idle machine, 3 full runs, medians of pinned reps; session
  saved to docs/zkmatrix-poc/results/a1_integration_bench.txt) + docs
  reconciled. Integrated numbers: FFN 47x72 @q8 commit kernel 0.161-0.195
  us/ring-MAC (84-102 eff GMAC/s 1T) = 6.2-6.4x over k8+Kara head-to-head;
  8x26 shape 0.30-0.38 (3.5-3.6x k8+Kara, ~29x naive); mask path 1.00x of
  ternary; Sigma prove 6-8x, verify ~10x, proofs bit-identical; ~99-111 ns
  (~119 muls)/committed element. Commit-bill 7B/512: ~1.6-2.0 min 22T CPU,
  ~5-6 s GPU(assumed 20x); GATE ~15-30 s CONFIRMED at integrated rates
  (remaining assumptions: GPU 20x, MT ~15x). RING_MULT S6 rows upgraded
  (prototype rows marked superseded, not deleted); A1 report Section 5
  actuals block (one session vs 3-5 day estimate; verifier migrated too);
  LLM_SCALE ladder row updated to INTEGRATED-MEASURED. Suite 37/37.

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
