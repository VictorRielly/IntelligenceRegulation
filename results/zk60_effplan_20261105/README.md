# Efficiency plan, Phase A: results (2026-11-05)

The plan: `docs/zkmatrix-poc/ZK60_EFFICIENCY_PLAN_20261105.md`. Every item in Phase A is byte-preserving: the goldens,
the six pinned trained digests and the receipt sizes must stay unchanged.

## A2: the D55 preflight in parallel (H122), done

**Change** (`run_fork.rs`, `preflight`; `private_block.rs`, `check_accuracy_for_shape`):
- the per-block public checks run one block per rayon task, about 7 GB of weights at 8B;
- the int8 symmetry scan runs in parallel chunks;
- the refusal is the serial loop's: results are read back in block order and the first error is returned.

**Acceptance** (`results/zk60_h124_witness_20261104/check_a1a2.sh`, `a1a2.progress`):
- the full lib suite is 913 / 3 known / 94;
- the W16R2 rung golden is unchanged;
- the six post-F12 trained digests are present;
- every D55 receipt verified, and the receipt is 818,728,672 B, unchanged.

**Time, one W16R2 8B T128 request, 32 blocks, forks N = 6** [MEASURED, best of 2, `d55_ab_a2.log`]:

| | before (F12 merge run) | after A2 |
|---|---:|---:|
| preflight | 0.35–0.38 s | **0.081–0.084 s** |
| forks, witnesses prebuilt (proof only) | 5.749 s = 22.27 tok/s | **5.111 s = 25.04 tok/s** |
| one request from its input (sealed) | 11.664 s = 10.97 tok/s | **10.807 s = 11.84 tok/s** |
| a stream of 4 requests, steady | 15.94 tok/s | 15.95 tok/s (limited by the sealing pass, A4's target) |

## A1: where one 8B block's proving time goes

`HL_PB_TIMING=1`, one D12a serial block, uncontended, 4-block run, one fork worker [MEASURED, shared box, one run;
`results/zk60_h124_witness_20261104/a1_phases.log`]. Wall 0.591 s:

| Phase group | s | % |
|---|---:|---:|
| A: witness planes into rows, lookups, histograms, mask rows | 0.047 | 8.0 |
| **A commit** (encode + Merkle, one call) | **0.078** | **13.3** |
| H: LogUp helper inverses (six domains + exp/act) | 0.032 | 5.4 |
| **H commit** (encode + Merkle, one call) | **0.072** | **12.2** |
| M commit, table helpers, mask and zero-sum rows | 0.013 | 2.2 |
| **slot 18, F zero-check** (79.7 M elem-terms) | **0.106** | **17.9** |
| slot 14, D zero-check | 0.045 | 7.6 |
| slot 17, softmax zero-check | 0.028 | 4.8 |
| slot 15, Q zero-check | 0.023 | 3.9 |
| the other 19 slots | 0.086 | 14.6 |
| openings A, H, M | 0.044 | 7.4 |

**What it says for the plan:**
- **The two commitments (25%) and the F and D zero-checks (26%) are half the block.** They are the targets of B1, of
  A6 (kernels) and of A8 (Gram folding), and B4 and B5 would shrink both by committing fewer rows.
- **Concurrency matters:** in the fork run the same blocks take 0.42–1.25 s each, and 32 blocks finish in about 4.7 s
  on 6 workers. That is about 0.15 s of wall per block, so CPU and GPU phases overlap across forks. A7's per-fork
  queues and GPU timestamps will show which resource limits.
