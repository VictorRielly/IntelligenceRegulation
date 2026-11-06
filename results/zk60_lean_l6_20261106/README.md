# D63 step L6, the generic sumcheck verifier: evidence (2026-11-06)

The report is §8 of `docs/zkmatrix-poc/ZK60_LEAN_ASSEMBLY_20261106.md`. Every job below ran through the zk60 resource
guard (class `cpu`) with `run_guarded.py`, detached with `start_new_session`. Peak RSS of any job: 6.72 GiB (the final
full check).

## What was written

| File | What |
|---|---|
| `formal/ZK60Formal/ExecMle.lean` | `mle.rs` executable (`interpolate_eval`, `eq_point`, `eq_table`, `eq_table_msb`, `eval_mle_ext`, `eval_mle_base`) and proved to be `interpEval`, `eqPoly`, `mleAt` |
| `formal/ZK60Formal/ExecSumcheck.lean` | `sumcheck::verify` executable on L5's transcript, proved to accept exactly when `scAccept` holds on the transcript chain's challenges (`scVerify_accept_iff`, `scChal_chain`, `scVerify_fs`) |
| `formal/ZK60Formal/ExecCfs.lean` | `CfsMask` (`sum_weights`, `eval_weights`, `total`, `eval`, `round`), `CfsMasker::mask_round`, `extension_round`, `masked_terminal`, proved to be `HidingSumcheckJoint.lean`'s CFS model and `SoundSumcheck.lean`'s extension model |
| `formal/ZK60Formal/L6Check.lean` | the agreement checker (defines `main`; not imported by the library root) |
| `ops/zkp-mvp/gpu-metal/zkp-core/tests/lean_l6_export.rs` | the TEST-ONLY corpus export (an integration test; no production source changed) |

## Inputs

| File | What |
|---|---|
| `corpus.txt` | the agreement corpus written by `lean_l6_export.rs` (public synthetic data: fixed seeds, the development rung's public transcript key): 1,561 records, 323,299 bytes |
| `mutate_corpus.py` | the negative control: eight single changes to the corpus |
| `gen_axioms.py` | writes `axioms_l6.lean`: a `#print axioms` line for every theorem of the three library files |

## Jobs

| Script | Log | What |
|---|---|---|
| `lean_file.sh`, `stage.sh` | `file1.log` … `file8.log` | the new files while they were written (the errors fixed on the way are in these logs) |
| `export_corpus.sh` | `rust.log` | `cargo test --release --offline --locked -j 2 --test lean_l6_export` with `LEAN_L6_CORPUS=corpus.txt` |
| `run_l6check.sh` | `l6check.log` | the modules built, then `L6Check.lean` on the corpus |
| `check_l6.sh` | `check.log` (two runs: before and after a comment-only correction of the file headers; both green) | the full `lake -d formal build` (`full.log`), the axiom audit (`axioms_l6.lean` → `axioms.log`), the source scan, the agreement check (`l6check_full.log`) and the negative control (`negative_control.log`) |

## Results

- Full build: 3,452 jobs, rc 0, no warning, no error.
- Axiom audit: 128 theorems; each shows only `propext`, `Classical.choice`, `Quot.sound` (or a subset); no `sorryAx`.
- Source scan of the four L6 Lean files for `sorry`, `axiom`, `native_decide`, `admit`, `maxRecDepth`, `maxHeartbeats`,
  `implemented_by`, `extern`, `bv_decide`, `ofReduceBool`: none.
- Agreement check: `L6Check: 1206 checks, 0 failed` (171 `verify` runs: 29 accepted, 142 refused with Rust's message
  bytes; every run's challenges and final transcript state equal Rust's).
- Negative control: `L6Check: 1206 checks, 8 failed`, as required.
