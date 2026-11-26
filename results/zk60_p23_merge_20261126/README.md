# Merge gate of the error-recovery branch (with the check-server guard fix) and the L1 binding branch, Nov 26

Follows `results/zk60_p23_merge_20261125/` (gates 1 and 2, the default-path timing set `p23_ab8`). The independent code read of
Nov 26 (`results/zk60_claude_review_20261116/P23_CODE_READ_20261126.md`) held that merge on one finding: the serve-loop panic
guard also covered the check server. The author did not answer; the co-coordinator wrote the fix on
`claude/p2-check-serve-guard` (two commits on `agy/metal-err-recovery` `932915a9e`).

## What was gated

- Runner `run_gate.py`: the 38 steps of Nov 25 and one more, the fix's test in a fresh process (39 steps: 2 suite runs, 35
  single gates, 2 integration runs). Pass rule in its docstring, unchanged from Nov 25.
- **`gate3`** (guard run `ae3532fad64e`, 1707 s, peak 9.81 GiB) on merge object `e04802814` (fix commit `9ee0ba37b`): **GREEN.** Both suite
  runs 1047 passed, 2 failed (the two known fixture failures), 156 ignored; 37 other steps ok.
- **`gate4`** (guard run `424d6f0cb5f7`, 1693 s, peak 10.23 GiB) on merge object `f641a976d` (fix commit `67bacfa59`, which differs from
  `9ee0ba37b` in comment lines only): **GREEN.** Both suite runs 1047 passed, 2 failed (the same two), 156 ignored; 37 other steps ok.
- Full logs are about 5.7 MB each and stay out of the repository; `raw/<label>.log.trimmed.txt` keeps every step, result and
  FAILED line.

## Why `gate3`'s object was not merged

The landing rule posted before `gate3` required no High finding from an independent reader of the fix. The reader
(`results/zk60_claude_review_20261116/P2FIX_READ_20261126.md`) found the fix correct, and one High finding older than the fix:
`Cargo.toml` sets `panic = "abort"` for the release profile, so `catch_unwind` never catches in a release binary. A panic ends
either server at once, as before the branch; the guard acts in test and debug builds only. Verified by the co-coordinator with
a probe crate (same five profile lines): the release binary is killed by SIGABRT, the same function inside a
`cargo test --release` test returns `Err`. The rule was applied as written. Commit `67bacfa59` corrects the doc comments, and a
second landing rule was posted before `gate4`: `gate4` GREEN and the limit stated in the code, the merge message and the status
page.

## What landed

- `5ba7250ad`: merge of `claude/p2-check-serve-guard` (`67bacfa59`); `1ff3aa3c4`: merge of `agy/l1-block-binding` (`b6d7f92c9`). Prover tree
  `93c316f1e550`, identical to the tree `gate4` ran on.
- Timing: `p23_ab8` of Nov 25 stands (rule of Nov 26, 00:13:10Z: the fix touches only `classify_serve.rs` and its test file).

## What this does and does not give

- In a release binary: on a Metal command-buffer error the prover falls back to the CPU when `HL_GPU_REQUIRED=0`; with
  `HL_GPU_REQUIRED=1` it still panics by design, which ends the server. The sealed-histogram cache is keyed by a digest of the
  lookup tables' content.
- Not given: a server that survives an internal crash. Not decided: whether the release profile should unwind.
- Open from the first read (not merge blockers, for the author and for Victor): one recovered device error makes `stack-serve`
  refuse later requests on a Metal build (the decline count is never reset); device faults that used to end the attempt now
  fall back to the CPU.
- `results/zk60_composed_8b_20261123/run_8b.py` pins a binary hash (`BIN_SHA`) of the tree before this merge; it has to be
  re-pinned by whoever next runs it.
