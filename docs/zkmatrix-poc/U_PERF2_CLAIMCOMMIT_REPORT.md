# U-PERF2 lane D — the claim layer (packed ixf sumcheck prover) + the commit phase (chain GEMM, digit witnesses, instance tables)

Status: IN PROGRESS (skeleton + first landing; sections fill in as steps
close). Written by lane D of the U-PERF2 round 3 (ledger:
PROGRESS_UPERF2.md "Lane D — CLAIM LAYER + COMMIT PHASE" + "Agent D
status"). Worktree /home/victor/wt-uperf2-d, branch uperf2-d, opened at
d3a4602. Box: the WSL box (Intel Core Ultra 9 185H, 22 threads, 15 GB);
the REAL 3x16 full-statement rig runs here (`M125_EXPORT_DIR=.../
m125_ffn_export_wsl`). Every number carries `[WSL-BOX 1T|NT,
QUIET|NOISY-SHARED]` (lane E works concurrently in its own worktree —
timings taken while it built or ran are NOISY-SHARED).

The rule (unchanged): every optimization is DIFFERENTIAL — the
pre-change body stays reachable as `*_ref` and under `ZK_UPERF_ORACLE=1`;
the rig's statement digest, counted bytes, verdict AND EVAL-PROOF DIGEST
are identical at ZK_THREADS 1 and 8, fast and oracle; the batteries hold
at ZK_THREADS 1/2/7; freeze-check's 98 on-box rows are identical to the
pre-change capture.

## 0. Items and where they land

| item | function | oracle | call sites | status |
|---|---|---|---|---|
| packed ixf sumcheck prover (bulk round kernel + in-place threaded folds) | fold.rs `ixf_sumcheck_prove_kind` / `ixf_sumcheck_prove_packed`; kfield.rs `k9_ixf_round_par`, `kt_ixf_round_poly` | `ixf_sumcheck_prove_kind_ref` (= `ixf_sumcheck_prove`, the scalar `round_poly` + `fold` loop) | the 8 claim-layer instances of `bg_pass_run` / `bk_pass_run` (3 matmul Prod3, 1 Hadamard Had, 4 requant Rq) | LANDED (rig gate: pending) |
| matmul-instance reduced tables (ta/tb) threaded | bin `bg_mm_tables` | `bg_mm_tables_ref` (the inline serial loop) | the 3 matmul instances, both passes | LANDED |
| chain GEMM: row-blocked, i32-accumulated, threaded | bin `bf_matmul_i64` | `bf_matmul_i64_ref` (the inline i-k-j closure) | `bf_derive_chain` (3 GEMMs per layer) | LANDED |
| digit witness threaded per value ring | bin `agg_digit_witness` | `agg_digit_witness_ref` | `bg_witness`, `bk_witness_weight`, `bk_witness_act` | LANDED |
| observation-only phases `d.*` | ct_engine::prof (ids 40-50) | — | commit phase + claim layer | LANDED |

Harness: `ring_matmul uperf-d diff-battery | bench [n_log2] [prod3|had|rq]
[noref]` (bin section `// [UPERF2-D]`).

## 1. Attribution (the 3x16 rig, before)

(filled in from the profiled run)

## 2. Method notes

(filled in)

## 3. Differential evidence

(filled in)

## 4. Before / after

(filled in)

## 5. Projected 12x512 deltas [MODEL]

(filled in)

## 6. What is left

(filled in)
