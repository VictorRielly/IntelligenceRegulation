# Covering module `BlockW16U1Cover.lean`, corrected (2026-11-27, Claude co-coordinator)

**What was wrong.** The first version (2026-11-26, `../zk60_lean_w16u1_check_20261126/`) built a witness record
`covParamsW16` for the installed profile's single-block statement and said in its header that this shows "the statement
is not vacuous". It did not. The record took its opening dimensions from the older profile (`R13.blkDim`: 256 opened
columns, paths of 16 entries) together with `aPath = 15`. `CoreShape` asks for paths of 16 entries, `blockVerify`
refuses any path that is not 15 entries long, both are required by `BlockAcc`, so no core was accepted at that record
and the theorem held there for an empty event. The premises were jointly satisfiable, as the header also said; the
instance had no content.

**Who found it.** An independent read of every field of the record against the Rust verifier
(`results/zk60_claude_review_20261116/W16R2_PARAMS_READ_20261127.md`, finding F1; an Opus reader, read-only). I
confirmed F1 by reading the definitions (`ExecBlockR13.lean:289-298`, `ExecBlockWire.lean:238-248`,
`ExtractW16Block.lean:50-54`, `OpenKnowBlock.lean:45-48`, `ExecBlockVerify.lean:369-392`) and the Rust dimension
(`wire.rs:93-101` under `ops/zkp-mvp/gpu-metal/hashline/src/private_block/`).

**The correction** (one file, `formal/ZK60Formal/BlockW16U1Cover.lean`, 146 to 183 lines):
- `covDimW16 : Dim := ⟨280, 2 ^ 14 + 280, 2 ^ 15, 15⟩`, the block dimensions the Rust verifier computes for the W16R2
  profiles (`Dim::new(14, 2, 280)`); the record's `geom` now carries it.
- `cov_paths_agree`: the record's `geom.blk.path` equals its `aPath` and its `hPath` (by `rfl`).
- The header says what the first version got wrong and what is still not shown.

**The check.** Runner `run_cover2.py` (the steps and pass rule of `run_cover.py` of 26 November, with four axiom reports
instead of three), definition posted in the coordination file and pushed before the recorded run. A development compile
came first (guard run `ae96ee36da21`).

- **`cover2` (guard run `62a1866f6735`, 9 s): GREEN** [MEASURED]. The module builds alone, with no error and no `sorry`
  warning; the root rebuilds alone; the four statements (`cov_layR_c0`, `cov_isShieldW16`,
  `cov_block_knowledge_w16r2_shieldU1`, `cov_paths_agree`) rest on `propext`, `Classical.choice`, `Quot.sound` only; no
  banned word in the code. The file in the tree is byte-identical to the copy that was built.

**What a pass means, and does not.** The corrected file compiles and the one contradiction that was found is gone. It is
still not proved, here or anywhere, that an accepting core exists at the record, so this file still does not show that
the statement has content. The record remains a witness with placeholders (the endpoint commitments' row count,
`preChecks`, `name`; `checkOpening` is a parameter). The file is my own text; the correction has not been read by anyone
who did not write it.

**What the read says beyond this file** (for the run-level item, which is not started): no field that
`Link.IsShieldW16` or a premise of `block_knowledge_w16r2_shieldU1` fixes disagrees with the Rust code; `IsShieldW16`
leaves `geom.blk`, `aPath`, `hPath`, `aRows`, `hRows` and `checkOpening` free, so the statement is about a class of
records and the run-level record has to pin them to the code's; the Lean tree had no W16R2 block `Dim` before this file.

Files: `run_cover2.py`, `raw/cover2.*` (log, guard record, done marker, runner output).

## Consistency read of the corrected record (same day)

A second independent reader (Opus, read-only) checked every place where two parts of `BlockAcc` constrain the same
quantity of a core at the corrected `covParamsW16`: 31 pairs, 29 consistent, 0 contradictory, 2 not determined (the
lengths of the public tables at 14 slots, not read; `checkOpening`, which the cover leaves free). Report:
`results/zk60_claude_review_20261116/W16R2_COVER_CONSISTENCY_READ_20261127.md`. It is a reading of definitions, not a
proof: it does not show that an accepting core exists. Its section 2 lists 16 equalities a record must satisfy for
`BlockAcc` to be satisfiable, for whoever writes the run-level record. With it, the corrected file has been read by
someone who did not write it, for consistency of counts and shapes only.
