# Fixing the joint-view gate's stage 4 (ruling G-1), re-pinning `mle.rs`,
# and printing the certifying minor — lane ledger

Lane: `zk60-native-jointview`, worktree `/home/victor/wt-zk60-jointview`.
Opened 2026-09-20 00:58 PDT by a delegated agent working for the security
owner. Python only; no cargo, no GPU. Sole writer in this worktree.

**Nothing in this lane establishes a privacy property.** The joint-view gate
is a consistency gate over an explicitly stated linear model at four real
captures' challenges. The project's open obligations (D8/D11 endpoint roots,
the nonlinear terminal link, the salted-leaf and Merkle channels) are
untouched.

## 0. The three jobs

| Job | What | Status |
|---|---|---|
| JOB 1 | Re-pin `zkp-core/src/mle.rs` at the integrator's proved-equivalent row-fold commit (4bf1fa0), after re-reading every ported function; rerun the gate and the tests | **DONE** 2026-09-20 01:20 |
| JOB 2 | Ruling G-1: stage 4 hard-codes `joint == sum` and cannot fail. Replace with a genuine joint computation over the union of the receipt's commitments, with shared coordinates identified; three negative controls | not started |
| JOB 3 | Print the certifying minor per role per capture (indices, determinant, g, G, rank) and the distinct-opened-columns vs pad-count check | not started |

## 1. Status table

| Step | Command / artefact | Result |
|---|---|---|
| J1.1 merge | `git merge --no-edit perf/zk-batch-optimizations` -> `ce44efc` | CLEAN, no conflict, no conflict markers under `scripts/ tests/ docs/zkmatrix-poc/ zkp-core/` |
| J1.2 read | `zkp-core/src/mle.rs` re-read whole, function by function | only `fold_rows_i8` / `fold_rows_i32` changed; 10 other functions byte-identical (checked by extracting each body from the old blob and the new file) |
| J1.3 re-pin | `scripts/zk60_native_terminal_polys.py`: `SOURCE_PINS` + new `REPIN_HISTORY` | old sha256 `131cf1b4…`, blob `649a63d3…`; new sha256 `b20c8b75…`, blob `51655b76…` |
| J1.4 gate | `results/zk60_native_joint_view_fix/job1_gate.log`, record in `.../job1_repin/joint_view.json` | exit 0, all 7 stages ok; **numbers identical** to the retained record except two `seconds` fields (1.6->1.5, 1.7->1.9) |
| J1.5 retained | gate rerun into `results/zk60_native_joint_view/`; port rerun into `results/zk60_native_terminal_polys/` | both refreshed (they pin the tool's own sha256, which moved with the re-pin) |
| J1.6 tests | `results/zk60_native_joint_view_fix/job1_tests.log` | **69 tests, OK (skipped=1)** — the skip is the capture test that needs `HL_NATIVE_CAPTURE_TEST_BINARY`, pre-existing |

## 2. Findings

### F1 — the `mle.rs` change, function by function (JOB 1)

The integrator's commit `4bf1fa0` adds an integer fast path to the two
signed-integer row folds and nothing else. Verdicts recorded in the tool at
`REPIN_HISTORY` and repeated here:

| function | verdict |
|---|---|
| `eq_table`, `eq_table_msb` | byte-identical; these are what `zk60_native_jv_field.py` ports |
| `eq_point`, `eval_mle_base`, `eval_mle_ext` | byte-identical; `eq_point` is transcribed in the terminal-polynomial port |
| `interpolate_eval` | byte-identical; the CFS Lagrange weights rest on it |
| `fold_rows_base`, `fold_cols_base`, `fold_cols_i8`, `fold_cols_i32` | byte-identical |
| `fold_rows_i8`, `fold_rows_i32` | CHANGED; same values (below) |
| `deferred_rows`, `fold_rows_deferred` | new private helpers |

Why the changed pair still means the same thing, verified rather than
assumed: `Fp` is a plain canonical `u64` in `[0, P)` (`field.rs:20, 27`), not
a Montgomery form, so `wi.c0.0` IS the residue. The fast path accumulates,
per output column and per extension component, the exact integer
`sum_i (w_i.c0) * v_i` in an `i128`, then `reduce()` returns that integer mod
`P` with its sign — which is exactly the field sum the inherited loop forms
term by term, because `Fp::from_i64(v) = v mod P` and multiplication is mod
`P`. The zero skip drops only zero terms. Overflow is impossible: the guard
refuses when `rows > i128::MAX / (u64::MAX * max_abs)` and falls back to the
inherited path, and `|partial sum| <= rows * (P-1) * max_abs` is under that
bound in any sign order. Output length and order are unchanged, and
`HL_FSP_ROW_FOLD=0` selects the old path in the same binary. **Neither
function is transcribed by the Python port** (no witness matrix is folded in
Python), so the port itself could not have drifted; the pin moved only
because the pin covers the whole file.

The captured proof/source relationship is unchanged and stays recorded: the
four receipts of 2026-09-19 were produced and verified by the OLD bytes, and
`REPIN_HISTORY` says so in the tool.

## 3. NEXT

JOB 2: the genuine joint computation (ruling G-1), then JOB 3 (the
certifying minor).
