# Integrated integer row folds — 2026-09-19

The signed-accumulator candidate from attempt 4 is accepted into main after
exact arithmetic and full proof validation. Production change:
`zkp-core/src/mle.rs`; benchmark: `zkp-core/examples/row_fold_bench.rs`.
`HL_FSP_ROW_FOLD=0` restores the inherited fold in the same binary.

- `attempt-1/`: arithmetic passed, benchmark compile failed (corrected type).
- `attempt-2/`: unsigned bias passed correctness but regressed sparse input
  2.55–2.92x. Rejected; exact source retained.
- `attempt-3/`: signed sums with the inherited zero skip; dense gain,
  sparse results near baseline.
- `attempt-4/`: adds the zero-accumulator reduction shortcut. Seven arithmetic
  tests in both modes, eight independent fold comparisons per benchmark run;
  ABBA dense ratio 2.32–2.42x, sparse 0.89–1.20x. Shared laptop, two threads,
  concurrent builds permitted; no full-model timing claim.
- `integration/`: 37 core and 261 default hashline tests, twelve frozen
  CPU/GPU/forced-chunked proof-byte gates, four retained native receipts
  cross-verified with both fold modes and corruption controls, six repaired
  private-IO P1/P3 checks per mode. Source, binary, runner and log pins.
- `storage-gate/`: 288 storage-feature tests pass, two explicit native capture
  writers ignored, twelve doctests included. Separate build output protects
  the frozen CPU/GPU binaries. Pins the inventory used by floors suite v10.
- `integration/floors-v10-tests.*`: all 88 gate-helper tests pass. The first
  local run caught the shell runner still selecting v9 and an outdated usage
  string; both were corrected before this retained passing run.
- `integration/audit.json`: independent post-run source/artifact recheck.

The isolated source worktree was `/tmp/wt-zk60-rowfold-20260919`, branch
`perf/zk60-rowfold-20260919`, based on `586eccd`. Attempt runners are archived
copies; do not run them against main. `integrate.py` and `storage-gate.py`
are the main-checkout runners; their output directories are write-once.
No row-fold jobs remain live. Model-scale speed and whole-proof privacy
remain open. See `docs/zkmatrix-poc/ZK60_ROWFOLD_INTEGRATION_20260919.md`.
