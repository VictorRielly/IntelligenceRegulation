# Isolated row-fold candidate, 2026-09-19

This is a recovery snapshot, not an integrated or validated optimization.
The source worktree is `/tmp/wt-zk60-rowfold-20260919`, branch
`perf/zk60-rowfold-20260919`, based on `586eccd`.

- `candidate.patch` changes only `zkp-core/src/mle.rs`.
- `row_fold_bench.rs` belongs in that worktree's `zkp-core/examples/`.
- `run.py` is an archived copy of the runner in the worktree's
  `results/zk60_rowfold_20260919/`. Do not run this snapshot against main.
- The detached validation process is PID 235057, session 82696. It waits
  for `/tmp/zk-build.lock`, runs both arithmetic arms, builds the diagnostic,
  then takes `/tmp/zk-heavy.lock` for its bounded CPU comparison.
- Authoritative completion is that worktree's `results/zk60_rowfold_20260919/run.done`
  and `validation.json`; inspect the existing process handle before retrying.

Acceptance still requires exact differential tests, inspection of dense and
sparse timing behavior, and full proof-byte gates before main integration.
No model-scale speed or privacy claim follows from this candidate.
