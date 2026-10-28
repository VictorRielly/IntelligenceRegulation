# D33 source re-pin onto the token lane's frozen round-9 tree: addendum, 2026-10-20

Written by the PRIVACY GATE lane, a delegated Claude Opus 5.5 agent,
2026-10-20 (finished 04:32 UTC). This is a short addendum to the tk7 re-pin
note `EV/tk7/ZK60_PRIVACY_STATEMENT_REPIN_TK7_20261019.md` (sha256
9958e548…; review round 4: YES), in the same form.

**This is gate evidence for a re-pin, not a privacy acceptance.** Whether D33
is extended to this tree is Victor's ruling on the security owner's
recommendation. The accepted statement
`docs/zkmatrix-poc/ZK60_PRIVACY_STATEMENT_TRAINED_TINYLLAMA_T32.md` is not
edited.

In this note:

- EV is `results/zk60_gate_tinyllama_20261017/`.
- **tk9** is the gate's copy of the token lane's frozen round-9 tree:
  - `results/zk60_token_io_r1_20261017/frozen-r9/`;
  - 236 files equal to `manifest_final_r9.sha256` (list sha256 b666a991…,
    the same as manifest_r9C);
  - this is the tree that built the named token binary b56f1b71… and the
    CLI-path capture `tinyllama-t32-L2-dense-pt1-cli-r9`.

## The refusal, and both identities kept

**[MEASURED] frozen-r9 against frozen-r7.**

- frozen-r9 re-hashes to its manifest: 236 / 236 files, nothing extra.
- Against frozen-r7: 12 files changed, 3 added, 0 removed.
- A trained-block bundle written from tk9 pins 52 files. Six of them differ
  from a tk7 bundle's (`EV/tk9/tk9-source-pins.v1.json`, c2abb5cd…):

| Pinned file | tk7 (frozen-r7) | tk9 (frozen-r9) | Where it is read |
|---|---|---|---|
| `src/private_block/run.rs` | `2c158dc9c22c23e4…` | `cc2c420498b11427…` | **v15** `zk60_native_rg_tinyllama_tk9_pins.py` (the run-layer port; below) |
| `src/private_block/token_io.rs` | `396daba1…` | `602597ad…` | v13 `zk60_native_rg_tokenio_r9_pins.py`; report-only on a block bundle |
| `token_io/stage_in.rs` | `0387e6b1…` | `e4609b1a…` | the same |
| `token_io/run.rs` | `924ee3e2…` | `4671d03e…` | the same |
| `token_io/load.rs` | `998bc0e8…` | `8c041721…` | the same |
| `token_io/cli.rs` | `04e32868…` | `b9079130…` | the same |

**All six frozen-r9 digests equal the v13 readings.** v13 read them before
the freeze, on manifest_r9C, and manifest_r9C is this tree.

The other 46 pins are byte-identical to tk7's:

- 40 R7 pins;
- 5 token r7c readings (`shape.rs`, `trained_statement.rs`,
  `trained_block.rs`, `private_block.rs`, `token_io/stage_out.rs`);
- the capture writer `run_capture.rs` f47e28bf. frozen-r9's base for it is
  frozen-r7's `aaff4e6e`, so the gate patch is the tk7 patch.

This matches the coordinator's statement exactly: one block/run file moved
(`run.rs`); `private_block.rs`, `trained_block.rs`, `protocol.rs` and
`run_capture.rs` are byte-identical; the rest is token-only.

**Failing-first [MEASURED].** Frozen tools **v14** carry no tk9 reading.

- On the tk9 L = 2 dense bundle they refused `run.rs` `cc2c420498b1` by name
  ("not one of the 15 digests this gate has read"), the only moved pin
  (`EV/tk9/probe_before_repin/probe-v14-tk9-l2-dense.json`).
- They suspended all 13 stages: status NOT-OK.
- This is the same behaviour as v10 on tk7 and v7 on R7.
- The unit test `TK9Pins` repeats the check in memory: with the tk9 entry
  removed, run.rs is refused and every stage it affects is suspended.

**D33 is unchanged.** It still names R7: tree `36a8aed1…`, 46 pins, CPU
binary `e51cc6a4…`.

**What tools v15 adds** (`ops/zkp-mvp/gate-tinyllama/frozen_v15/`, manifest
`EV/gate-tinyllama.tools.frozen.v15.sha256` c3d9db18…, 65 files):

- `zk60_native_rg_tinyllama_tk9_pins.py` puts run.rs `cc2c4204` into
  `RUN_LAYER_PINS`, with the reading below (blob 09647b56, 81,468 B);
- one marked merge line in `zk60_native_rg_runpins.py`; the merge refuses a
  digest it already holds;
- `TOOLS` +1, and test `TK9Pins` (2 tests);
- **no earlier digest, reading or record changes.**

Patches: `EV/gate-tinyllama-v14-to-v15.{scripts,tests}.patch` (0afcc25a…,
a8c15661…) and vs-original v15 (49a6d401…).

## Re-reading run.rs on this profile's path [READ]

`diff -u` against `2c158dc9` gives +16 / −1 in two hunks. The change comes
from token round 8.

- **Hunk 1** adds two `pub(crate) const` token-I/O run profile strings with
  their doc comments:
  - `…-token-io-run-tinyllama-t128-trained-statement-public-row/1`;
  - `…-token-io-run-llama-3-8b-t128-…/1`.

  It also grows `TOKEN_IO_RUN_PROFILES` from `[&str; 3]` to `[&str; 5]` by
  appending them.
- **Hunk 2** adds two arms to `registered_block_shape`, keyed by those two
  strings: `Shape::tinyllama_trained(128, …)` and
  `Shape::llama3_8b_trained(128, …)`. Both constructors are in `shape.rs`,
  which is unchanged.

**On D33's profile** (`private-run-tinyllama-1.1b-t32-trained-statement/1`):

- The match is by string equality, and the new strings differ from every
  block profile. So D33's profile selects the arm it selected before.
- `TOKEN_IO_RUN_PROFILES` is read in exactly two production places:
  - `RunStatement::new_bound_from_digests`, where a blocks-only statement
    refuses a token profile; two more token strings are now refused, and
    none is a block profile;
  - `token_io/run.rs:197`, where a token run must carry one.
- These are byte-identical and outside both hunks: the header,
  `run_shape_words`, the stage order, the boundary absorb, the position
  tags, the opening order, `stage_shape`, `stage_cal` and the schedule
  lines. These are everything the run-layer port transcribes.

**Not on the block path [READ]**, as in tk7:

- `run.rs`, `trained_block.rs` and `shape.rs` make no call into `token_io`.
- The round-9 token code (the sealing pass, `lookup_misses`, the CLI changes;
  the v13 readings) runs only in a token run.

**Soundness** is not this note's subject:

- native R8 was accepted in D24 review round r8;
- REVIEW5 (2026-10-20 01:28 UTC) found the token CLI demo-fit on frozen-r7;
- whether a review covers frozen-r9's round-8 / round-9 additions is for
  the coordinator to state.

## Execution evidence [MEASURED, shared box, n = 1]

**The tree.**

- `ops/zkp-mvp/trained-1b-gate-tk9/` is an rsync of frozen-r9, 236 / 236
  files equal before the patch (`EV/tk9/verify_copy.before_patch.json`).
- On top of it are the tk7 copy's four test-only files, byte for byte:
  - the capture patch in `run_capture.rs`;
  - `run_capture_tests.rs` with the P-18 port;
  - the stage-47 module and its token child.
- Sources manifest `EV/tk9/trained-1b-gate-tk9.sources.v1.sha256` (238 files,
  597b2204…); patch `EV/tk9/trained-1b-gate-tk9-vs-frozen-r9.v1.patch`
  (c8e94a0b…, 4 files).

**Build and stage 47** (`EV/tk9/heavy_queue.sh`, marker `= 0`):

- test build: 3 min 39 s, test binary e79029e6…;
- the five block stage-47 root-rebuild tests pass: two-block run dense /
  zero, block dense / zero, boundary;
- the four token stage-47 replays (gate round 10, PR4-8) also pass on the r9
  code. Their prover consumed exactly 54,185,024 (L = 1) and 93,648,512
  (L = 2) bytes, the same as on tk7. So the round-9 sealing pass adds no
  draw.

**Six captures** of `pg_rot1_export_T32`:

- `tinyllama-trained-tk9-capture-{dense,zero}-{l1,l2,l22}`;
- layer 0, layers 7–8 and all 22 layers;
- held-out `ho00` and the all-zero input;
- every capture exited 0.

**The gate, tools v15, the tk7 plan** (`EV/tk9/gate_queue.sh`,
`gate_queue_l22.sh`; summary `EV/tk9/tk9-summary.json`):

| Record | Status | Unexplained | Replay (challenges / positions) | Terminals | Notes |
|---|---|---|---|---|---|
| L1 pass A, dense / zero | PASS / PASS | 0 / 0 | 4,511 / 127 | 23 / 23 | export ok |
| L1 everything, dense / zero | PASS / PASS | 0 / 0 | 4,511 / 127 | 23 / 23 | full preimage 0 differing; mask 0; joint couplings respected; M9-3 fires |
| L2 pass A, dense / zero | PASS / PASS | 0 / 0 | 9,002 / 251 | 46 / 46 | export ok |
| L2 everything, dense / zero | PASS / PASS | 0 / 0 | 9,002 / 251 | 46 / 46 | as at L1 |
| L22 pass A, dense / zero | PASS / PASS | 0 / 0 | **98,822 / 2,731** | **506 / 506** | **E3: identity equal** to the native r2 statement's `68ad19c8…` (statement sha256 5b7acd4d…), on both inputs |

**Every deterministic figure equals tk7's record for the same bundle**, on
all ten records (`EV/tk9/compare_figures_tk9_tk7.json`, 956cf20c…; "every
pair equal: True"). The figures compared:

- the replay counts and the run binding;
- the columns checked and authenticated, and the bytes hashed;
- every commitment's role, disclosed dimension, rows, claims and groups;
- the terminal slot checks and the channel counts;
- the mask entries;
- the whole-run joint, 2 / 4 / 44, each equal to its sum of parts;
- E3.

The leaf-by-leaf comparison (`EV/tk9/compare_tk9_tk7.json`) differs only in
two kinds of figure:

- run.rs's pin entry (digest, blob, bytes, reading);
- figures that depend on the run's randomness: roots, minor determinants,
  opened columns, pad blocks and margins, the free dimensions that follow
  from them, array-store bytes, and segment hashes.

**Controls and the rest.**

- pin controls PC-0..PC-11: 12 / 12 exact;
- TL controls: 15 / 15 (L1) and 18 / 18 (L2, both inputs);
- G-10: 8 / 8 at L1, L2 and L22;
- schema: ok over the six bundles (222 allowed keys);
- witness comparison at L2: 118 of 128 figures identical (tk7: 114). Only
  distinct opened columns and pad margins differ;
- predictions validated against the pass-A records: **6 of 6 ok, 0
  mismatches**;
- the v15 unit suite: **70 tests OK** in the working copy.

**The CPU command-line binary.** Built from the tk9 copy with the native
lane's own command (`cargo build --release --offline --locked -j2 --example
zk60_trained_block`):
`~/zk60-artifacts/tinyllama-gate-bins/zk60_trained_block.tk9.release.bin`,
sha256 **`911e82f0fa5bed2753999eb7e88bf471745ccd7a17af3f894f53e51f4e63802f`**
(`EV/tk9/zk60_trained_block.tk9.release.bin.sha256`).

- The copy differs from frozen-r9 only in `#[cfg(test)]` files.
- It was built in the gate copy's path, so a rebuild elsewhere need not give
  the same bytes.
- It is not the token lane's token binary b56f1b71… (a different example).

It was run on review P-18's inputs: layers 7..9, with 45 + 312 input files
checked and 0 moved.

- **`stack-prove`** exited 0 in 6.1 s at 1.02 GiB:
  - it was sealed by the witness builder's own pass before the header, with
    parity bit-exact;
  - it wrote 2 segments, **23,019,088 B**.
- **`stack-verify`** ran in a fresh process with `--expect-statement
  ef061000…`. It exited 0 and printed **`statement-published`**, identity
  **`ef061000…`**.
- Of the statement's 16 top-level fields, only `expected_io` (the fresh
  endpoint roots) differs from the tk7 run's.
- This run directory (`~/zk60-artifacts/tinyllama-cli-tk9-run-l2/`) is not
  captured or gated, as in tk7.

## Limits

- **Not re-done on tk9:**
  - P-18's capture through the CLI's own path for the trained-block binary;
  - the 22-block pass F; D33 carries it from R5b by reading.
- **No integrated tree.** frozen-r9 is a frozen copy, not a commit, so
  condition 7's pin set would be its 52 pins.
- **Out of scope, as in D33:**
  - other calibrations and the GPU path;
  - the token stages. Those are the next-token draft's: on this tree, the
    CLI-path capture passed the token gate under v14 (round-10 addendum,
    PR4-10).
- **What this establishes:** the block-stage receipts of this profile and
  calibration, written by the frozen-r9 tree, pass the same gate, figure for
  figure, as tk7's, and so as R7's. It does not establish a privacy property.
