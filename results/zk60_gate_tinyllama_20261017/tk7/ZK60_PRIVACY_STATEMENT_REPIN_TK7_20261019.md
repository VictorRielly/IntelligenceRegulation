# D33 source re-pin onto the token round-7 tree (native R8 + token files): 2026-10-19

Written by the PRIVACY GATE lane, a delegated Claude Opus 5.5 agent,
2026-10-19 (finished 2026-10-19 23:59 UTC). It follows the form of
`docs/zkmatrix-poc/ZK60_SECURITY_PROBE_REPIN_20260922.md` (the D22 re-pin
at 4751b93). **This is gate evidence for a re-pin, not a privacy acceptance.**
Whether D33's pin set moves is the security owner's decision, and rulings
are Victor's. The accepted statement
`docs/zkmatrix-poc/ZK60_PRIVACY_STATEMENT_TRAINED_TINYLLAMA_T32.md` is not
edited.

Below, EV is `results/zk60_gate_tinyllama_20261017/`, and **tk7** is the
gate's copy of the token lane's frozen round-7 tree:

- `results/zk60_token_io_r1_20261017/frozen-r7/`;
- 233 files equal to `manifest_final_r7.sha256`, list sha256 `eb912dd5…`;
- native R8 plus the token-I/O files.

## The refusal, and both identities kept

The gate's source check correctly refused the tk7 bundles:

- Frozen tools **v10** carry R7's readings and the token readings, but no
  block-port reading for the moved files.
- On the tk7 L = 2 dense bundle, v10 refused `run.rs` `2c158dc9` and
  `run_capture.rs` `f47e28bf` by name, and suspended every stage of the
  pass (`EV/tk7/probe_before_repin/probe-v10-tk7-l2-dense.json`, status
  NOT-OK).
- This is the same behaviour as v7 refusing R7 in round 6
  (`EV/r7/probe_before_repin/`).

**D33 is unchanged.** It still names R7:

- tree `36a8aed1…`;
- R7's 46 pins;
- the CPU binary `e51cc6a4…`.

**What tools v11 adds.** They accept the tk7 digests **in addition to** every
earlier reading:

- `ops/zkp-mvp/gate-tinyllama/frozen_v11/`, manifest
  `EV/gate-tinyllama.tools.frozen.v11.sha256`, 7459dfdc…;
- the merge refuses to replace any digest it already holds;
- no R7 record is relabelled, and every R7 record keeps its v8 tool hashes.

A tk7 block bundle pins 52 files. 40 are byte-identical to R7's pins. The
other 12 are listed here with both hashes:

| Pinned file | R7 (D33) | tk7 | Where it is read |
|---|---|---|---|
| `src/private_block/run.rs` | `ad92be08fe55b86e…` | `2c158dc9c22c23e4…` | the token r7c reading, carried verbatim in `zk60_native_rg_tinyllama_tk7_pins.py` (run-layer port) |
| `src/private_block/shape.rs` | `7b0c9742db3434fd…` | `8c62519c98e36ae9…` | the same (terminal and mask ports) |
| `src/private_block/trained_statement.rs` | `6f18efcd0fe584e1…` | `e623c2278042a42e…` | `zk60_native_rg_tokenio_r7c_pins.py` (report-only: no port transcribes it) |
| `src/private_block/trained_block.rs` | `30cb9a31703a7a07…` | `0943baded99b1fb1…` | the same (report-only) |
| `src/private_block.rs` | `386194fe90f01829…` | `45286ae8f3be17da…` | the same (report-only) |
| `src/private_block/run_capture.rs` (the capture writer) | `31557a27…` (gate R7 copy) | `f47e28bf791aa225…` (gate tk7 copy) | `zk60_native_rg_tinyllama_tk7_pins.py`: the token writer `aaff4e6e` plus the gate's 47-line R5b capture patch, line for line |
| `src/private_block/token_io.rs`, `token_io/{stage_in, stage_out, run, load, cli}.rs` | not in R7 | `396daba1…`, `0387e6b1…`, `69abed43…`, `924ee3e2…`, `998bc0e8…`, `04e32868…` | `zk60_native_rg_tokenio_r7c_pins.py`, read in gate round 7. **Not on the block path** (below) |

Full digests: `EV/tk7/tk7-source-pins.v1.json`.

## Re-reading the changed code on this profile's path [READ]

Each of R8's five files was read in full against R7's copy (the R7 gate copy
against frozen-r7; the diff stats are in the token r7c readings).

- **`run.rs` (+73 / −24, 7 hunks):**
  - the three token-I/O profile strings and their `run_shape` arms;
  - a new refusal: a blocks-only run statement may not carry a token-I/O
    profile;
  - `stage_sh_s: Vec<u32>` becomes `stage_cal: Vec<NormCalibration>`;
  - `token: None` in the block capture header.

  The schedule line gains a clause only where a stage's calibration differs
  from the run's. `stage_shape(k)` returns the run shape whenever
  `stage_cal[k]` equals it. The header, the stage order, the boundary
  absorb, the position tags and the opening order are unmoved.
- **`shape.rs` (one hunk, +37 / −12):**
  - `with_score_shift` now calls the new `with_layer_calibration`;
  - that function checks every class (`derive_at_width`), rebuilds through
    CS-8, checks the trained class, and refuses a plane-list move;
  - `Shape::slots` and ruling C-4 are outside the hunk.
- **`trained_statement.rs` (+113 / −23):**
  - `sh_s: Option<u32>` becomes `own: [Option<i64>; 11]`, in the canonical
    order of `OWN_FIELDS`, with sh_s first and R6's labels;
  - the identity encoder writes an own field only when it is `Some`;
  - `check` refuses an own value equal to the run's, and validates the
    layer's whole calibration at the trained door.

  The `u64::MAX` fallback for a negative value cannot be reached after
  `check`, because the norm classes are ≥ 1.
- **`trained_block.rs` (+73 / −57):**
  - `per_layer_cal_fields`, `masked`, `run_constants` and `load_layer` are
    generalised from sh_s to the eleven fields;
  - the stack loop builds each witness at `apply_own(…)` when a layer has
    its own values;
  - `stack_records` renders own fields only when present;
  - the rest is `fn` → `pub(crate) fn` visibility for the token CLI.
- **`private_block.rs` (+11):** `mod token_io`, the token CLI re-exports,
  and the cfg(test) `r8_tests`.

**The export fact [READ].** `pg_rot1_export_T32/profile.json` has
`per_layer_constants_differ = [exp_e_s, silu_member]`, and none of R8's
eleven keys. So:

- `per_layer_cal_fields()` is empty and `masked` is the identity;
- every layer's `own` is all `None`;
- the identity bytes, the schedule lines and every stage shape are R7's.

**Not on the block path [READ].** `run.rs`, `trained_block.rs` and
`shape.rs` make no call into `token_io`. `run_capture.rs` and the stage-47
module are `#[cfg(test)]` (`private_block.rs:222-225`), so no production
build contains them.

**Soundness** is not this note's subject:

- native R8 was **accepted on soundness** in D24 review round r8
  (`results/zk60_d24_review_20261017/R8_VERDICT.md`, 14:59 UTC; its object is
  the native R8 freeze `7f64276a…`, without the token files);
- the token files' round-6 adversarial review of frozen-r7 (`REVIEW5.md`)
  had not yet written its verdict when this note was written.

## Execution evidence [MEASURED, shared box, n = 1]

**The tree.**

- `ops/zkp-mvp/trained-1b-gate-tk7/` is an rsync of frozen-r7: 233 of 233
  files equal the manifest (`EV/tk7/verify_copy.before_patch.json`).
- On top of it: the gate's R5b capture patch (three hunks, applied with
  offsets 590 / 824 / 885) and the stage-47 module.
- Sources manifest `EV/tk7/trained-1b-gate-tk7.sources.v1.sha256` (234 files,
  d356e7aa…); patch `EV/tk7/trained-1b-gate-tk7-vs-frozen-tk7.v1.patch`
  (94ed30a7…).

**The build and stage 47.**

- `cargo test --release --lib --no-run --offline --locked -j2`: exit 0 in
  4 min 53 s. Test binary sha256 `9dcca83f…`.
- The five stage-47 root-rebuild tests (two-block run dense / zero, block
  dense / zero, boundary) passed, 1 / 1 each.

**Six captures** of `pg_rot1_export_T32`:

- `tinyllama-trained-tk7-capture-{dense,zero}-{l1,l2,l22}`, at layer 0,
  layers 7–8, and all 22 layers;
- held-out `ho00` and the all-zero input;
- source label `trained-1b-gate-tk7-sources-v1-d356e7aa`; every capture
  exited 0.

**The gate, tools v11, the plan of round 6 (B) on R7**
(`EV/tk7/gate_queue.sh`; summary `EV/tk7/tk7-summary.json`):

| Record | Status | Unexplained | Replay (challenges / positions) | Terminals | Export E3 |
|---|---|---|---|---|---|
| L1 pass A, dense / zero | PASS / PASS | 0 / 0 | 4,511 / 127 | 23 / 23 | ok |
| L1 everything, dense / zero | PASS / PASS | 0 / 0 | 4,511 / 127 | 23 / 23 | ok; full preimage 0 differing; mask 0; joint couplings respected; M9-3 fires |
| L2 pass A, dense / zero | PASS / PASS | 0 / 0 | 9,002 / 251 | 46 / 46 | ok |
| L2 everything, dense / zero | PASS / PASS | 0 / 0 | 9,002 / 251 | 46 / 46 | ok; as at L1 |
| L22 pass A, dense / zero | PASS / PASS | 0 / 0 | **98,822 / 2,731** | **506 / 506** | **identity = `68ad19c8…`** (the native r2 statement, sha256 5b7acd4d…), on both inputs |

- **Every deterministic figure equals R7's record for the same bundle**, on
  all ten records:
  - the replay counts;
  - the columns and bytes hashed;
  - every commitment's role, disclosed dimension, rows, claims and groups;
  - the terminal counts and the channel counts;
  - the mask entries recomputed;
  - the whole-run joint, 2 = 2 (L1), 4 = 4 (L2), 44 = 44 (L22).
- The witness comparison at L2 differs between inputs only in the
  randomness-dependent figures (distinct opened columns, pad block, pad
  margin): 114 of 128 identical, against 112 on R7.
- **Controls:**
  - pin controls PC-0..PC-11: 12 / 12 exact on L1;
  - TL controls: 15 / 15 (L1), 18 / 18 (L2, both inputs);
  - G-10: 8 / 8 at L1, L2 and L22;
  - schema check: ok over the six bundles (222 allowed keys).
- **Predictions** (`zk60_native_rg_predict.py`), validated against the tk7
  pass-A records: **6 of 6 ok, 0 mismatches**
  (`EV/tk7/l*/prediction_tk7_*_validated.json`).
- **Unit suite:** 63 tests OK in the working copy at v11 (`EV/tk7/suite/`).
  It includes `TK7Pins`:
  - every tk7 digest is the tk7 copy's file;
  - the 52 pins split 40 R7 / 11 token r7c / 1 tk7 writer;
  - a moved run.rs, run_capture.rs or shape.rs pin is refused.

**About the predictions that exited 1 (coordinator's question).**

- The six prediction jobs in the gate queue (two at 21:34 UTC on L22, four
  earlier on L1 / L2) were run **without** `--validate`.
- Without that flag, `validation` is empty, and `ok = validation_ok and
  bool(validation)` is false by construction (`zk60_native_rg_predict.py:690-692`;
  exit 1 at :707).
- So they show neither a mismatch nor a tool-order effect. Every R7
  prediction has the same empty `validated_on`.
- The validated re-runs above are the answer.

**The CPU command-line binary.** Built from the tk7 copy with the native
lane's own command (`cargo build --release --offline --locked -j2 --example
zk60_trained_block`, 1 min 16 s):
`~/zk60-artifacts/tinyllama-gate-bins/zk60_trained_block.tk7.release.bin`,
sha256 **`dac7fc7303ac5ce935cda487e539194bf6044e9685c948f92556c0f97dc17b93`**
(`EV/tk7/zk60_trained_block.tk7.release.bin.sha256`).

- The copy's only differences from frozen-r7 are `#[cfg(test)]`, so this
  production build compiles frozen-r7's non-test sources.
- It was built in the gate copy's path, and absolute source paths can reach
  the binary, so a rebuild elsewhere need not give the same bytes.

**The binary exercised on review P-18's inputs** [MEASURED, `EV/tk7/cli_run.sh`,
`EV/tk7/cli/`]. Layers 7..9 of `pg_rot1_export_T32`, read in place and first
checked against P-18's manifests (45 + 312 files, 0 moved). Class cpu, under
the coordinator's memory hold at 0.8 / 1.5 GiB.

- **`stack-prove`** exited 0 in 6.5 s at a peak of 1.04 GiB:
  - backend `gpu: off (built without --features gpu-cuda)`;
  - the chain is sealed by the witness builder's own pass, with parity
    bit-exact at both layers before the run header (H-1);
  - 2 segments, **23,019,088 B**, the same length as R7's P-18 receipt;
  - the prover's statement went to `<run>.unverified-statement/` (copied to
    `EV/tk7/cli/prover-unverified-statement/`).
- **`stack-verify`**, in a fresh process with
  `--expect-statement ef061000…`, exited 0 in 1.3 s and printed
  **`statement-published`**. The statement was written "by stack-verify,
  from its own rendering and the hashes of the verified bytes", and the
  prover's copy was removed.
- **The published trained statement identity is `ef061000…`**, the identity
  R7's verifier published for these layers.
- Of the 52 fields of its `statement.json`, 51 are equal to R7's P-18
  statement. The one that differs is `expected_io`, which carries the two
  endpoint roots, and those are fresh per run.
- This run directory (`~/zk60-artifacts/tinyllama-cli-tk7-run-l2/`) is
  **not captured or gated**: that would be P-18 itself, which is not re-done
  here.

## Limits

- **Not re-done on tk7:**
  - **P-18's capture through the CLI's own path.** The tk7 binary's
    stack-prove / stack-verify are exercised above, but that run directory
    is not captured or gated. The CLI functions R8 changed (`run_constants`,
    `load_layer`, the stack loop, `stack_records`) are the ones read above,
    and they are inert at this export.
  - **The 22-block pass F** (full preimage and joint at L = 22). D33 itself
    carries it from R5b by reading.
- **An integrated tree.** frozen-r7 is a frozen copy, not a commit, so
  condition 7's pin set would be its 52 pins until an integrated tree
  replaces it.
- **Out of scope, unchanged from D33:**
  - any other calibration, and every per-layer export (F-6);
  - the GPU path;
  - the token stages themselves: the next-token proof's own gate is gate
    round 7, `EV/token_io/TOKEN_GATE_REPORT_T32_v10.md`, which covers a
    different calibration (`pg_rot1_b4_T32_cal128`).
- **What this establishes** is that the block-stage receipts of this profile
  and calibration, written by the tk7 tree, pass the same gate, figure for
  figure, as R7's. It does not establish a privacy property.

## Validation

- Tools v11: 60 files, tool check "60 listed, 0 moved, 0 unlisted" on the
  snapshot and on the working copy; patches
  `EV/gate-tinyllama-v10-to-v11.{scripts,tests}.patch` (f28be367…,
  e035095d…).
- tk7 gate: 10 of 10 records PASS (0 unexplained), 6 of 6 predictions
  validated, 63 unit tests OK.
- The failing-first probe refuses as predicted.
- The tk7 CPU CLI binary (dac7fc73…) proves and verifies P-18's layers:
  statement-published, identity `ef061000…`.
- Queues and markers: `EV/tk7/{heavy_queue,gate_queue,post_queue,cli_build,cli_run}.done`.
- Ledger: `EV/PROGRESS.md`, round 8 entries from 19:27 UTC.
