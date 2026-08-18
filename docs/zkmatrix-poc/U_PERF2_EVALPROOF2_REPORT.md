# U-PERF2 lane M — eval-proof leftovers 2: psi0-factored (SIMD MAC + NTT-domain accumulation), kernel-rows, fold, CRS, transport, precommit, the verifier's share

Status: IN PROGRESS (skeleton, 2026-08-17). Written by lane M of the
U-PERF2 round 7 (ledger: PROGRESS_UPERF2.md, "Lane M" + "Agent M
status"). Worktree /home/victor/wt-uperf2-m, branch uperf2-m, opened at
f821485. Every number below is labeled [WSL-BOX 1T|NT, QUIET|NOISY-SHARED];
the WSL box is Intel Core Ultra 9 185H (22 threads, 15 GB), and lane L
(GPU step 2) builds/runs concurrently for most of the session — the
RATIOS (fast vs oracle in the same run) and the same-binary rig rows are
what to read.

The rule (unchanged): every optimization is DIFFERENTIAL — the pre-change
body stays reachable as an oracle (`oracle_mode()` / `ZK_UPERF_ORACLE=1`,
plus the per-item knobs below), the outputs are byte-identical, the
batteries hold at ZK_THREADS 1/2/7, freeze-check's 98 on-box rows are
identical to the pre-change capture, the REAL rigs reproduce their
digests.

## 0. Items and where they land

| item | function (eval_proof.rs) | oracle / knob | call sites | status |
|---|---|---|---|---|
| 1a PHI MAC loop on AVX2 | `PhiFactored::value_ring` | scalar u128 body (`ZK_PSISIMD=0`) | the phi pass, `Phi0Source::fill` (level-0 h), `psi_level0_factored_multi` (prover level 1 x2 + verifier x2) | planned |
| 1b psi0 NTT-domain accumulation | `psi_level0_multi_impl` aligned branch | today's kara/scale/add body (`oracle_mode()` keeps the pre-O5 form; `ZK_PSI0NTT=0` keeps today's fast body) | same 4 calls | planned |
| 2 rows pass MAC | `kernel_pass_factored_gen` aligned rows | scalar u128 body | prover rows pass, verifier rows_eval | planned |
| 2 fold | `fold_chunks_ntt_gen` | `fold_chunks_ref` | `bg_fold` | attribute first |
| 2 CRS | `expand_level_matrix_par` | `expand_level_matrix_raw` | every CRS miss | planned |
| 2 transport / precommit / verifier | — | — | — | measure + report |

Harness: `ring_matmul uperf-m {battery, bench, sha-bench}` (bin section
`// [UPERF2-M]`).

## 1. Baseline attribution (the pre-change binary at f821485)

(filled as the rigs run)

## 2. Method notes (why the bytes cannot move)

(filled per item)

## 3. Differential evidence

(filled at HEAD)

## 4. Measurements

(filled per item)

## 5. The REAL rigs

(filled at HEAD)

## 6. What is left (honest state)

(filled at close)
