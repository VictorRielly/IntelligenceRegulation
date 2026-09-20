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
| JOB 2 | Ruling G-1: stage 4 hard-codes `joint == sum` and cannot fail. Replace with a genuine joint computation over the union of the receipt's commitments, with shared coordinates identified; negative controls | **DONE** 2026-09-20 02:05 |
| JOB 3 | Print the certifying minor per role per capture (indices, determinant, g, G, rank) and the distinct-opened-columns vs pad-count check | **DONE** 2026-09-20 02:25 |

Commits on `zk60-native-jointview`, in order: ledger skeleton; `ce44efc`
(the one permitted merge); JOB 1 re-pin; JOB 2 (the joint computation);
JOB 1 addendum (the re-pin test); JOB 3 (the certifying minor); this
ledger and the report's §12.

## 1. Status table

| Step | Command / artefact | Result |
|---|---|---|
| J1.1 merge | `git merge --no-edit perf/zk-batch-optimizations` -> `ce44efc` | CLEAN, no conflict, no conflict markers under `scripts/ tests/ docs/zkmatrix-poc/ zkp-core/` |
| J1.2 read | `zkp-core/src/mle.rs` re-read whole, function by function | only `fold_rows_i8` / `fold_rows_i32` changed; 10 other functions byte-identical (checked by extracting each body from the old blob and the new file) |
| J1.3 re-pin | `scripts/zk60_native_terminal_polys.py`: `SOURCE_PINS` + new `REPIN_HISTORY` | old sha256 `131cf1b4…`, blob `649a63d3…`; new sha256 `b20c8b75…`, blob `51655b76…` |
| J1.4 gate | `results/zk60_native_joint_view_fix/job1_gate.log`, record in `.../job1_repin/joint_view.json` | exit 0, all 7 stages ok; **numbers identical** to the retained record except two `seconds` fields (1.6->1.5, 1.7->1.9) |
| J1.5 retained | gate rerun into `results/zk60_native_joint_view/`; port rerun into `results/zk60_native_terminal_polys/` | both refreshed (they pin the tool's own sha256, which moved with the re-pin) |
| J1.6 tests | `results/zk60_native_joint_view_fix/job1_tests.log` | **69 tests, OK (skipped=1)** — the skip is the capture test that needs `HL_NATIVE_CAPTURE_TEST_BINARY`, pre-existing |
| J2.1 module | `scripts/zk60_native_jv_joint.py` (new), wired into stages 2/4/6 | one generator system over A, H, the two endpoints and M; shared coordinates discovered from the capture |
| J2.2 gate | `results/zk60_native_joint_view_fix/job2_gate.log` | exit 0, 7 stages ok; joint 4 = sum 4 on all four captures, `k0` 0, u-term 2, 899 / 646 coordinate classes |
| J2.3 controls | `stage6_negative_controls.stage4_joint_controls` | all four fire at the honest capture; honest `ok` beside each |
| J2.4 small model | `stage6_negative_controls.joint_reduction_against_a_dense_joint_rank` | the joint reduction agrees with a DENSE joint rank in all three cases |
| J2.5 tests | `results/zk60_native_joint_view_fix/job2_tests.log` | **81 tests, OK (skipped=1)** |
| J3.1 minor | `certifying_minor` per role per capture in stage 2 | `g = 2(G+1)` (72/20/4/4 block, 62/18/4/4 attention), rank `= g`, determinant nonzero, 16/16 |
| J3.2 budget | `distinct_opened_columns <= pad_count` | 231–246 distinct of 256 sampled, 256 pads; holds for all 16 |
| J3.3 tests | `results/zk60_native_joint_view_fix/job3_tests.log` | **85 tests, OK (skipped=1)**; each determinant recomputed from the emitted indices by Bareiss, and a singular index set fails |
| J3.4 gate | `results/zk60_native_joint_view_fix/final_gate.log`, record in `results/zk60_native_joint_view_fix/joint_view.json` | exit 0, 7 stages ok, 21 s |

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

### F2 — what is shared between roles at the toy profiles (JOB 2)

Read off the capture and the pinned Rust, not assumed. **The two endpoint
commitments share their DATA with A.** The last two slots of either profile
(`SC_IO_IN` / `SC_IO_OUT`, `private_block/argument.rs:902-908`) are
Standalone slots — `SLOT_KINDS`, `layout.rs:474-498`, so the sum they prove
is zero and the published scalar is the CFS mask term alone — running
`eq(tau)*(A_plane − endpoint_plane)` over 9 variables. A zero sum at a
random `tau` says the planes are equal, so the endpoint's two data rows ARE
two of A's, position by position: `A[10]=Input[0]`, `A[11]=Input[1]`,
`A[68]=Output[0]`, `A[69]=Output[1]` on the block captures. The tool
rebuilds those pairs from the capture's own claim offsets and points.

**No blinding source is shared.** Every commitment draws its own pads,
reserved mask pairs and proximity rows; M draws its own coefficients. The
tool checks that no identification class holds a non-data row of two roles
(0 on all four captures) and says in its output that the non-data block is
therefore block diagonal by role, so `joint == sum` is a THEOREM about that
block structure here — and computes the rank anyway.

### F3 — the numbers (JOB 2, JOB 3)

Per capture: joint 4, sum 4, equal, `k0` 0, u-row term 2; 4 shared data
classes, 0 shared non-data; joint without the endpoint identification also
4, so the aliasing is worth 0. Certifying minors: A `g` 72 (G 35), H 20
(G 9), endpoints 4 (G 1) on the block; 62 / 18 / 4 / 4 on attention; every
rank equals `g` and every determinant is nonzero. Distinct opened columns
231–246 against 256 pads.

### F4 — the controls, and where the model is blind (JOB 2)

| control | honest | perturbed | direction |
|---|---|---|---|
| a blinding source shared across two commitments (`A[213]` ≡ `H[280]`) | passes | FAILS | **UP**: parts unchanged (0/2/0/0), joint 4 -> **260**, `k0` 0 -> 1 |
| one masking row removed (`A[213]`) | passes | FAILS | UP in the marginal too: A 256, sum 260 = joint 260; fails on "a part exceeds its expected value" |
| one pad fewer than the distinct opened columns (245 vs 246) | passes | FAILS | H-pad breaks; the stage refuses instead of printing a number |
| a claim's weight outside its reserved pair (A claim 0 on row 215) | passes | FAILS | H-pair breaks; the stage refuses |

**Blind spot, recorded as a test.** The joint rank sees a shared blinding
row only where the non-data block is tight — a singleton opening group's
reserved pair, two generators against exactly two columns. A has 17
singleton groups of 35, H 2 of 9; sharing at a slack position changes no
rank and the gate would not see it. A limit of the linear model, not a
property of the protocol (where nothing is shared at all).

### F5 — the joint reduction is validated against a dense rank

`zk60_native_jv_smallmodel.joint_controls()` stacks two toy commitments and
computes the joint disclosed dimension densely from the definition:
honest 0 = reduction 0; one blinding row shared, **both marginals 0 and the
joint 4**, reduction 4; one data row shared 0 = 0. The reduction agrees in
all three cases. The identification is of message coordinates only — each
commitment still draws its own pads.

## 3. NEXT

Nothing outstanding in this lane. For the orchestrator:

1. Push `zk60-native-jointview` (this lane never pushes).
2. Ruling G-1 can be closed for the two toy profiles; §12.8 of the report
   lists what stays a reviewed obligation (the joint reduction's structural
   step at the receipt geometry, the blind spot above, and G-2's "owed again
   at the rung and 125M").
3. Tell the integrator the `mle.rs` re-pin is done, both hashes recorded,
   nothing recaptured, and every gate number identical.
