# E2 notes: lifting and parametrising (staging `/home/victor/ir-public` only)

Written 2026-10-30 06:57 UTC by the release-prep agent. The private repo was not modified.

## The three variables (same meaning in Python, Rust and shell)

| Variable | Meaning | Default | Old location |
|---|---|---|---|
| `ZK60_REPO` | repository root; lane result folders are `$ZK60_REPO/results/<lane>/` | this checkout (computed from the file's own location; Rust: `CARGO_MANIFEST_DIR/..`) | `/home/victor/IntelligenceRegulation` |
| `ZK60_MODELS` | model checkpoints | `~/models` | `/home/victor/models` |
| `ZK60_ARTIFACTS` | large outputs kept outside any git work tree | `~/zk60-artifacts` | `/home/victor/zk60-artifacts` |

Each variable maps to exactly one old root. With the variables at the old roots (or unset on the
development box, whose HOME is the old home), every data path is the old path. Old lane worktrees
(`/home/victor/wt-*`) map to the checkout (the inventory scripts' `--repo` defaults and
`floors_round13_merge.sh` `V3`), or keep an explicit override variable (`HL_EXPORT_DIR`). CUDA
locations use `CUDA_ROOT` (default `~/cuda-root`).

## What was edited (scripts are re-runnable on a fresh copy: `prep/e2_*.py <staging>`)

- `prep/e2_rust_edits.py`: 8 files. These are test-only files (token-I/O capture, r2 and r3 tests,
  run-capture tests, the gpu_cache process test), the unpinned `hashline/src/export.rs` default
  (`M125_EXPORT_DIR` still wins), and 2 Cargo.toml comments.
- `prep/e2_tools_edits.py` and 7 follow-up fixes: 60 of the 93 lifted tools.
  - CODE is the tool's own directory: sources, sibling imports, and source digests.
  - HERE is the original lane DATA folder under `$ZK60_REPO/results/`.
  - The vendored calibration port output is byte-identical: tlcalib 2441cc40…, b3calib
    656049c8… and b3_ladder d2e07ab4… are the lane's recorded adapted digests.
  - Recorded provenance strings keep their lane-relative form, for example
    `calibration_tool.path` and vendor_port's `source`.
  - `evaluate_verdicts_cached.py`'s hard-coded baseline digest was updated to the lifted
    `evaluate_verdicts.py` (eb1aae88…; before: 5410c8ba…).
- `prep/e2_app_edits.py`: 7 app files.
  - `config.py` gains `REPO`, `ARTIFACTS` and `MODELS`. `SPM_BPE_DIR` prefers the lifted
    tools, else the lane folder.
  - `shieldstral_runtime.py`: TEKKEN comes from `ZK60_MODELS`. The activation WRITER prefers
    the lifted copy, else the lane copy, and both digests are accepted: 8d6ce81b… (lane, reviewed
    demo run) and 7cf6c0de… (lifted, path-only diff).
  - seqgen, compile_anchor (`npm` from PATH), docstrings, and the storage-policy test literals
    (`/home/someone/...`).
- `prep/e2_scripts_edits.py`: 13 scripts and 7 Python tests.

## Deliberately NOT edited (byte-pinned reviewed artefacts; coordinator decision wanted)

| File | Remaining owner path | Why not edited |
|---|---|---|
| `hashline/src/private_block/tied_tables/derive.rs` | `DEFAULT_CHECKPOINT = /home/victor/models/shieldstral-1.0-3b/...` | Production code. It is a capture source pin (`run_capture.rs` OWN_SOURCE_FILES), and the privacy gate v23 pins its digest c5bec3c6… (`privacy-gate/scripts/zk60_native_rg_r13_pins.py`); `hash_domain_tests` and `s25_tests` read its text. Editing it would make the public prover differ from the reviewed 16b in a pinned file. **Consequence:** a stranger cannot verify a Shieldstral receipt unless the checkpoint sits at that path, or the export's `tied_embeddings.checkpoint_file` names it (that field is bound in the profile). **Recommended:** route a one-line `ZK60_MODELS` override into the next reviewed token round and re-pin the gate. |
| `hashline/src/private_block/trained_accuracy.rs` | none; but its test default `CARGO_MANIFEST_DIR/../../loader-fixtures` points outside the checkout | Pinned (gate digest f47b1084…). The suite passes `HL_R13_LOADER_FIXTURES` (README documents it). |
| `privacy-gate/` (all 122 files; 12 contain `/home/victor`) | evidence and capture locations in tests and defaults | Frozen v23: 80 of 80 files match `evidence/zk60_gate_tinyllama_20261017/gate-tinyllama.tools.frozen.v23.sha256`. The tests skip when the data is absent. |
| `scripts/zk60_opus_attention_inventory.py` | a docstring and the output record field `"worktree": "/home/victor/wt-zk60-fa"` | Its digest dd0b8cde is cited by `ZK60_OPUS_ATTENTION_INVENTORY.md`, and the field is a record. |
| docs and evidence | 91 docs and 10 evidence files | Records. Evidence is verbatim. Docs that are runnable instructions were edited: `START_HERE`, `RESOURCE_PROTOCOL`, the app README, `hashline/README`. Accepted documents are byte-pinned: D33 pins the trained TinyLlama statement and D36 the next-token statement, and FABLE_TRANSCRIPT_REVIEW pins 4 FABLE docs. |

## Consequences to know

1. **Tools record their own digest.**
   - Every lifted tool that was edited has a new sha256.
   - The export chain writes those digests into the exports' provenance, and therefore into
     `profile.json`.
   - A stranger's rebuilt export therefore differs in provenance from the published exports
     (PROFILE_SHA 2ba468f9… for the T128 classifier export). Byte-identical reproduction of the
     published export needs the original tool bytes at their original lane paths, and the
     original absolute paths.
   - Practical route for "check a published receipt": publish the export's non-weight metadata
     (`profile.json`, manifests) with the receipts. Then let the tools regenerate the
     weight-derived arrays and check them against those manifests. Not verified.
2. **Missing upstream files** (listed in `tools/model-export/README.md`):
   - `fp_lib.py` and `fp_selfcheck.py` (fidelity-parity lane);
   - `importer_zk60_1b_checkpoint.py`;
   - `export_head_r2.py`;
   - `S2_DOMAIN_AMENDMENT.json`;
   - the 8B lane `NOTICE`;
   - native r12b/r13 reference data.

   All of them exist privately and are small. Adding them is a follow-up ("E2b"), not done here,
   because it would go beyond the inventory.
3. The two gpu_cache process tests ran against the 125M v3 export in s21. In the clean room they
   loud-skip, because the export is absent.

## How to switch the reference to a later token round (e.g. 18), once it is frozen AND reviewed

1. In `build_inventory.py`, set `R16B` (and the strings in `summary["reference_prover"]` and in
   `EVIDENCE`) to the new `frozen-r18` tree, its manifest and its binary records. Re-run the
   inventory, guarded as `light`.
2. Rebuild the staging copy from scratch with `prep/stage_copy.py` into a new directory, then
   re-apply:
   - `prep/e2_rust_edits.py`. Its counts will stop the script if the round changed those test
     files; re-derive the strings, never force.
   - `e2_tools_edits.py`, `e2_app_edits.py` and `e2_scripts_edits.py`. These are independent of
     the round, apart from the app's `BINARY` / `BINARY_SHA`, which change with the deployed
     binary.
   - the E3 / E4 edits: copy the redacted documents and the new top-level files from the old
     staging tree, then re-check for changes.
3. Check the new tree against its manifest (as E1 did for 16b: 301 of 301). Confirm that the gate
   version that pins the new round's source digests is the one shipped. Re-run E5.

## The derive.rs change for a reviewed token round (not made here; the gate pins the file)

Coordinator's instruction, 2026-10-30: do not add the override in staging; name the exact change.

- **File:** `hashline/src/private_block/tied_tables/derive.rs` (round 16b digest c5bec3c6…).
- **Where:**
  - line 10, `const DEFAULT_CHECKPOINT: &str = "/home/victor/models/shieldstral-1.0-3b/snapshot-003ec7e2/model.safetensors";`
  - its one use, in `fn recompute_profile` (line 227), at line 244:
    `let checkpoint_path = declaration.opt("checkpoint_file").map(J::str).transpose()?.unwrap_or(DEFAULT_CHECKPOINT);`
- **Change:**
  - Replace the constant with a function `default_checkpoint() -> PathBuf`. It returns
    `$ZK60_MODELS/shieldstral-1.0-3b/snapshot-003ec7e2/model.safetensors` when the environment
    variable `ZK60_MODELS` is set and non-empty, else `$HOME/models/shieldstral-1.0-3b/snapshot-003ec7e2/model.safetensors`.
    On the development box both equal the old path.
  - At line 244, use the declared `checkpoint_file` when present (unchanged precedence), else
    `default_checkpoint()`.
- **Soundness is unchanged.** The checkpoint bytes stay authenticated:
  - by `CHECKPOINT_BYTES`;
  - by the tied-tensor digest checked against `tied_tensor_for_profile`'s pin;
  - by the consumed-tensor SHA-256 compare.

  Only the file's location becomes configurable.
- **Constraints the tests impose on the edit:**
  - `s25_tests.rs` requires exactly 5 `Sha256::new(` in derive.rs, so add none.
  - `hash_domain_tests.rs` scans derive.rs for absorb labels, so add none.
  - derive.rs stays in `OWN_SOURCE_FILES`.
- **Gate follow-up, in the same round:**
  - Mirror the override in `privacy-gate/scripts/zk60_native_rg_classtied.py`
    (`SHIELD_DEFAULT_CHECKPOINT`, line 334, used at line 414).
  - Re-pin `DERIVE_T16` (line 195) and the chain entry at line 482 of
    `privacy-gate/scripts/zk60_native_rg_r13_pins.py` (and the same pins in any later gate version).
  - Refreeze the gate manifest.

## Native-suite resources for future runs

The clean-room run peaked at 10.35 GiB RSS (10.77 GiB cgroup) against an 11 GiB cap. Use the guard's
`--class cpu --need-gib 11 --cap-gib 12` from now on (coordinator, 2026-10-30).

## 2026-10-30 16:25 UTC: switched to token round 19b and gate v24

- Round 19b carries E7: `derive.rs` `default_checkpoint()` resolves `$ZK60_MODELS`, else `$HOME/models`,
  and refuses otherwise. A declared `checkpoint_file` wins. The gate v24 mirrors it.
- The derive.rs residual above is therefore **resolved upstream, in a reviewed round**
  (REVIEW_R19 / REVIEW_R19B). The staging copy of derive.rs is round 19b's bytes, unedited. Its only
  `/home/victor` strings are in its test module, which asserts the old-path equivalence on the dev box.
- The E2 Rust edits are unchanged; round 19b did not touch those 7 files. The staging tree is
  the 306-file manifest with exactly those 7 differing.
- Still unedited because pinned: privacy-gate (now v24, 80 of 80) and `scripts/zk60_opus_attention_inventory.py`.
