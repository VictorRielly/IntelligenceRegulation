# D63 step L8, Fiat–Shamir composition on the code's own chain: evidence (2026-11-06)

The report is §10 of `docs/zkmatrix-poc/ZK60_LEAN_ASSEMBLY_20261106.md`. Every job below ran through the zk60 resource
guard (class `cpu`) with `run_guarded.py`, detached with `start_new_session`. Peak RSS of the final check: 3.84 GiB.
No Rust was added: the L5 and L6 corpora already pin the encodings this step uses (the transcript's items, the
`sc-round` absorb, `challenge_fp2`), and both are re-checked here as regressions.

## What was written

| File | What |
|---|---|
| `formal/ZK60Formal/ExecComposeFS.lean` | a schedule of sub-protocols on the CODE's transcript chain (`CSub`, `Rounds`), the step parse (`tRem`) and the scheduled reader (`cRdStep`, `cRd`), the composed round-by-round bound with the largest error (`allSt_rbr`) and for dooms that start late (`everSt_rbr`), the composition on any code-item chain (`fs_code_chain_ever`, `fs_code_chain_sound_sched`), the code's own steps for any widths (`stepsB`, `stepsB_ok`), and the executable instance: a run of sumcheck slots on one transcript (`Slot`, `slotSub_rbr`, `slot_take`, `slot_alive`, `slot_transcript_next`, `exec_sumchecks_fs_sound` with its Goldilocks and slot-shape corollaries) |
| `formal/ZK60Formal.lean` | imports the new file (one line) |

`Statements.lean`, every existing Lean file and every production source are unchanged.

## Scripts

| File | What |
|---|---|
| `run_guarded.py` | the guarded, detached runner (a copy of L7's; `L8_CAP_GIB` lowers the cap while iterating on one file, and the guard's need is then the cap) |
| `stage.sh` | elaborate one file with `lake env lean` (L7's, this worktree's path) |
| `gen_axioms.py` | writes `axioms_l8.lean`: a `#print axioms` line for every theorem of `ExecComposeFS.lean` |
| `check_l8.sh` | the final check, ONE guarded job: the full `lake -d formal build` (`full.log`), the axiom audit (`axioms_l8.lean` → `axioms.log`), the source scan, the root import, and the regressions `L6Check` on `results/zk60_lean_l6_20261106/corpus.txt` (`l6check_regression.log`) and `L5Check` on `results/zk60_lean_l5_20261106/corpus.txt` (`l5check_regression.log`) |

## How the file was written

- `file1` (not kept): the guard refusing a 10 GiB cap below its default 14 GiB need (fixed in `run_guarded.py`), then
  the first elaboration of the parse, the reader and the states (beta-redexes under `rw`, an index type left to
  inference).
- `file2.log` … `file5.log`: the new file alone under a 10 GiB cap as it grew, each run 3–4 s at about 3.68 GiB. The
  errors fixed on the way (two instance-search pitfalls, finding L8-7; a fixed width function against a literal one;
  two deprecations and an unused section variable in `file4.log`) are in those logs; `file5.log` is the final file:
  rc 0, no message.
- `full.log` shows only the two rebuilt modules (the new file, 7.0 s, and the root): the rest of the 3,454 jobs were
  replayed from the build copied from the main checkout.

## Results (`check.log`)

- Full build: 3,454 jobs (the library plus the new file), rc 0, 0 warnings, 0 errors, no `sorry`.
- Axiom audit: 64 theorems; 25 on `[propext, Classical.choice, Quot.sound]`, 15 on `[propext, Quot.sound]`, 17 on
  `[propext]`, 7 on none; no `sorryAx`, no `Lean.ofReduceBool`.
- Source scan of `ExecComposeFS.lean` for `sorry`, `axiom`, `native_decide`, `admit`, `maxRecDepth`, `maxHeartbeats`,
  `implemented_by`, `extern`, `bv_decide`, `ofReduceBool`: none.
- Regressions: `L6Check: 1206 checks, 0 failed`; `L5Check: 5553 checks, 0 failed`.
- Guard: `check.log.guard`, 31 s, peak RSS 3.84 GiB.
