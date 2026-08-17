# U-PERF2 lane C — eval-proof leftovers (fold NTT, transport limb-split NTT, compute_psi, digit-split threads)

Status: SKELETON (plan commit, 2026-08-17). Lane C of the U-PERF2
round (ledger: PROGRESS_UPERF2.md, "Lane C — EVAL-PROOF LEFTOVERS").
Worktree /home/victor/wt-uperf2-c, branch uperf2-c, opened at c46483a.
Every number below is labeled [WSL-BOX 1T|NT, QUIET|NOISY-SHARED]; the
WSL box is Intel Core Ultra 9 185H, 22 threads, 15 GB, no m125 export
— nothing here is a rig number, and the Mac projections are [MODEL].

The rule (unchanged from Phase 0): every optimization is DIFFERENTIAL —
the pre-change body stays reachable as `*_ref` and under
`ZK_UPERF_ORACLE=1`; the outputs are byte-identical; the battery holds
at ZK_THREADS 1/2/7; freeze-check's 98 on-box rows are identical to the
pre-change capture.

## 0. Items and where they land

| item | function (eval_proof.rs) | oracle | call sites | status |
|---|---|---|---|---|
| T7 fold | `fold_chunks_ntt` | `fold_chunks_ref` (the `poly_mul_small` loop) | `bg_fold`, `agg_fold` | planned |
| T3b transport | `transport_level_from_psi` (fast body) + `ntt_combine_general` | `transport_level_from_psi_ref` | prover levels >= 1 (`transport_level`), verifier level 1 (`transport_level_from_psi`) and deeper | planned |
| psi | `compute_psi` (NTT per-u accumulate) | `compute_psi_ref` | prover `transport_level`, verifier floor psi | planned |
| digit splits | `decompose_polys_modq` / `decompose_polys_small` (parallel over rings) | the per-ring `decompose_poly_*` (same function, serial) | `bg_matvec_chunks`, `bg_level_h`, `bg_fold`, `agg_level_t`, `agg_level_h`, `agg_fold` | planned |

## 1. Method notes (the exact identities each item relies on)

(filled per item as it lands)

## 2. Differential evidence

(uperf-c diff-battery legs; uperf-pc diff-battery incl. E2E; agg-matmul
battery; bh-verifier battery; freeze-check 98 rows vs baseline; at
ZK_THREADS 1/2/7 and oracle vs fast)

## 3. Kernel benches (us per unit, oracle alongside)

(uperf-c bench at level-0/level-1-like shapes)

## 4. Projected Mac deltas [MODEL]

(from the benches; not a rig number)

## 5. What is left

(honest state at close)
