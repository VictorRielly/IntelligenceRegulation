# U-K9 ledger — kernel-grade K-mults + H-03 memory refactor

Branch: worktree-agent-aba54d89afd23bcca (based on perf/zk-batch-optimizations @ 7da16f2).
Discipline: incremental commits, checkboxes updated as stages land. All timing
numbers on this box are [NOISY-SHARED] (22T box shared with a parallel
benchmarking agent); the orchestrator re-measures on a quiet machine.

## Stages

- [ ] S0 — baseline: build release; lookup-bench 2^18/2^20 rates; RSS at
      2^20/2^22 via /usr/bin/time -v; freeze-check + full suite green at base.
- [ ] S1 — kfield.rs fast kernel layer: packed [u32]-canonical table type
      (q < 2^32 fast path, scalar fallback otherwise), division-free
      reduction, no-alloc mul/mul-acc with lazy (wide-accumulate,
      reduce-once) discipline. Unit differential vs slot_mul_g.
- [ ] S2 — gkr.rs: build_tree on the bulk kernel; FracTree packed flat
      layers (public root()/depth() kept, layers_p/layers_q field access
      replaced by accessors — ring_matmul.rs verified to use neither);
      specialized packed layer-sumcheck prover, bit-identical transcript.
- [ ] S3 — sumcheck.rs: fold/mle_eval on bulk kernels (signatures kept);
      generic round_poly retained as the differential oracle path.
- [ ] S4 — gkr_masked.rs: masked prove b-round hot loop on the bulk kernel
      (successive-addition extrapolation, wide accumulate per node).
- [ ] S5 — differential battery: bulk vs scalar bit-identical on random
      inputs + shipped batteries; freeze-check green; full 42-test suite
      green. Self-test hook in ring_matmul.rs (minimal, localized).
- [ ] S6 — B-D2 finish: RSS table at 2^20/2^22/2^23; CLI cap lift to what
      fits with headroom on the 15 GB box.
- [ ] S7 — U_K9_KERNEL_REPORT.md (new file): before/after us/el at
      2^18/2^20, attribution split (lazy reduction vs lane occupancy), RSS
      table, honest gap-to-model statement.

## Decisions

- KElem stays `pub type KElem = Vec<u64>` — ring_matmul.rs binds
  `let x: KElem = ...to_vec()` in several places (lines 7367-7369, 7501,
  7539-7540) and U-K8 writes new call sites against that; an inline/newtype
  KElem is NOT source-compatible. The inline-representation half of B-D2 is
  delivered where it matters for RSS: FracTree layers and all descent work
  tables move to packed flat u32 storage (canonical values < q < 2^31 at the
  frozen point). Scalar KElem remains the API and oracle type.
- Bulk kernel = A1 discipline transplanted: canonical-u32 operands,
  widening 32x32->64 MACs (AVX2 vpmuludq class via autovectorization),
  grouped u64 accumulators, one division-free reduction per output
  coefficient, s-fold deferred to finalization. Round-node extrapolation by
  successive addition (T(x+1) = T(x) + d mod q) keeps operands canonical —
  no mid-loop reductions.
- q >= 2^32 (q46 class) falls back to the existing scalar path everywhere —
  same results, no packed layer.

## Baseline numbers (S0) — all [NOISY-SHARED]

`ring_matmul lookup-bench` at 7da16f2, release, 1T, /usr/bin/time -v:

| N | prover us/el (fuse+trees+descents) | incl. verify | max RSS |
|---|---|---|---|
| 2^18 | 12.48 | 12.86 | 394,092 KiB |
| 2^20 | 12.09 | 12.49 | 1,566,024 KiB (1.49 GiB) |
| 2^22 | 14.13 | 14.55 | 6,253,376 KiB (5.96 GiB) |

(Doc Section 7' recorded 10.8-10.9 us/el on a quieter run of the same box;
the delta is shared-box noise.) Linear RSS extrapolation to 2^23 ~ 12.5 GiB
— H-03 confirmed: no headroom on the 15 GB box; CLI caps at 2^22.
freeze-check green at baseline.

## Measured after (S6/S7)

(to be filled)
