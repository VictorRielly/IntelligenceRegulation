# Re-pin onto the token lane's frozen round-11 tree, for D33 and D36: dated note, 2026-10-21

Written by the PRIVACY GATE lane, a delegated Claude Opus 5.5 agent, on
2026-10-21; finished at 02:16 UTC. It is gate round 15, in the form of
the tk9 note (`EV/tk9/ZK60_PRIVACY_STATEMENT_REPIN_TK9_20261020.md`,
c4d88df1…).

**This is gate evidence for a re-pin, not a privacy acceptance.** It does not
edit either accepted statement:

- D33: `docs/zkmatrix-poc/ZK60_PRIVACY_STATEMENT_TRAINED_TINYLLAMA_T32.md`;
- D36: `docs/zkmatrix-poc/ZK60_PRIVACY_STATEMENT_NEXT_TOKEN_TINYLLAMA_T32.md`.

Both name frozen-r9 today. Whether either is extended to frozen-r11 is
Victor's ruling on the security owner's recommendation.

In this note:

- EV is `results/zk60_gate_tinyllama_20261017/`.
- **frozen-r11** is `results/zk60_token_io_r1_20261017/frozen-r11/`: 237
  files, manifest `manifest_final_r11.sha256`, list sha256 d8075d76….
- The named round-11 CPU token binary is
  `cli/zk60_token_io.r11.release.bin`, sha256
  **0c9f247c0f91162177f8ed90285f8664cc4dd36ebd8934dc650804bafe5c2c6b**.
  It was built from this tree, and it is the binary the demo now runs.

## 1. What moved, with both hashes [MEASURED / READ]

The gate's copy, `ops/zkp-mvp/token-gate-r11/`, re-hashes 237 / 237 to
`manifest_final_r11` with nothing extra (`EV/round15/verify_copy.json`).
`diff -r` against frozen-r9 shows:

- **changed** `examples/zk60_token_io.rs`: its doc header only, the
  TR7-6 / TR7-7 sentences. Not pinned.
- **changed** `token_io/cli_tests.rs`: tests. Not pinned.
- **added** `token_io/r11_tests.rs`: `#[cfg(test)]`. Not pinned.
- **changed** two PINNED files:

| Pinned file | frozen-r9 | frozen-r11 | `diff -u` |
|---|---|---|---|
| `src/private_block/token_io.rs` | `602597ad50d0978d4ea82385011084e2ff4f3678ecbffedc3f192b69d8fe5d9f` (73,261 B) | `7730c8d01bd85b916be81a176f3aeb4238d426748a99aef7075f3630e0a00fb4` (73,417 B) | +4 / −0, 1 hunk |
| `src/private_block/token_io/cli.rs` | `b9079130204b49f5f73d38d8f5d531fcfa388d3a8d57c84ff87142eb57b655e9` (54,823 B) | `3eaaacdbafdcd2a7863a52294a7f762898f70f0837eaa06eb34cb7560751fabc` (58,131 B) | +75 / −10, 7 hunks |

**No block or run file changed** between frozen-r9 and frozen-r11. That
includes `run.rs`, `trained_block.rs`, `shape.rs`, `protocol.rs`,
`argument.rs`, the token stage files, `token_io/run.rs` and the capture writer
`run_capture.rs` (aaff4e6e).

**The hunks [READ]:**

- **`token_io.rs`**: one `#[cfg(test)] mod r11_tests;` declaration with a
  two-line comment (review REVIEW6 TR7-5). No production item changes.
- **`cli.rs`**. All of it is CLI-side, a caller of the shared prover and
  verifier:
  - **TR7-5.** `seal_chain`'s inline stage-shape derivation moves into
    `cli_stage_shape(sh, own)`. It is the same expression: the run shape
    when the layer's calibration equals the run's, else
    `Shape::with_layer_calibration(apply_own(base, own))`. The test-only
    `r11_tests` pins it equal to `TokenRunStatement::stage_shape` at every
    registered profile.
  - **TR7-6.** `owner_inner` refuses an existing `--token-out` path BEFORE
    the full re-verification. Before, `write_private`'s create-new refused it
    after; that still closes the race. There is also a test-only counter of
    `check_run` calls.
  - **TR7-7.** The owners' default base and its per-user level are tightened
    to 0700 on use (`tighten_to_0700`). A stdout event names the path and its
    old mode only; a base that is not a directory is refused.
  - Doc comments for TR7-6 / TR7-7.

  The statement the CLI writes, the run directory, the verifier's reading of
  it, the transcript, every draw and every opening are unchanged.

**Does anything here touch the privacy argument?**

- TR7-6 and TR7-7 harden the owner side. TR7-7 sits exactly where D36's
  operating rules (PR4-16) put the decommitments.
- TR7-5 is a refactor with a pinning test.
- No change moves a byte of a token-run receipt or a block-stage receipt.
  §3 measures that.

## 2. D36 (the next-token statement): the re-pin [MEASURED]

**Failing first.** Frozen tools **v17** carry no round-11 reading. On the
round-11 CLI-path capture (§3) they:

- refuse **`token_io.rs` 7730c8d01bd8** and **`cli.rs` 3eaaacdbafdc** by
  name ("has no reading"), the only two moved pins. The other 50 are read
  (40 R7, 6 r7c, 4 r9);
- refuse the new-slot terminals before any slot is evaluated ("token_io.rs:
  bundle 7730c8d01bd8, port read at 396daba1a494");
- read no block stage ("a token pin has no reading").

Status NOT-OK, false parts integrity / terminals_new_slots /
terminals_block_stages / joint_preimage
(`EV/round15/gate/ff-v17-tokengate-cli11.json`, 1,179 s). The unit test
`TokenR11Pins` repeats this in memory: without the round-11 readings both
files are refused by name, and a reading whose base no round-9 reading reads
is refused.

**What tools v18 adds** (`ops/zkp-mvp/gate-tinyllama/frozen_v18/`, manifest
`EV/gate-tinyllama.tools.frozen.v18.sha256`, 71 files, ebdca44a…; patches
v17 → v18 `9d3a7f85…` / `0de785a3…`, vs-original v18 `1671c49d…`):

- `zk60_native_rg_tokenio_r11_pins.py` holds the two readings above. Each
  reading's `base` is the frozen-r9 digest.
- `token_pins` accepts them.
- `tokenterminals.check_source_pins` **walks the readings back to the
  digest the port was written at**: r11 → r9 → frozen-r7. Every step must say
  "no receipt byte moves". The record names the chain: "round-11 reading
  7730c8d01bd8 against 602597ad50d0; round-9 reading 602597ad50d0 against
  396daba1a494".
- `TOOLS` gains one entry. Test `TokenR11Pins` (2) is new.
- **No earlier digest, reading or record changes.**

**The CLI-path capture, re-run with the r11 binary.**

- **How it was made.** The token lane's own test,
  `capture_the_cli_verify_path_at_tinyllama_t32_l2` (the P-18 pattern, PR4-10),
  ran from the unmodified frozen-r11 copy (`EV/round15/r15_heavy.sh`):
  - `HL_PB_CLI_BIN` was the r11 binary, its sha256 checked first;
  - the binary's own `prove` and `verify` ran as its own processes;
  - the run directory was then read with the CLI's readers and verified
    with the recorder attached.
- **What it did [MEASURED]:**
  - `prove` sealed before the header: 2 parity layers, 4 segments,
    27,422,816 B, 10.6 s;
  - `verify` published the statement at 95 / 100 bits;
  - the recorded verification took 7.8 s; peak 1.10 GiB rss.
- **Where things are.**
  - Bundle:
    `~/zk60-artifacts/token-io-r11-gate/captures/tinyllama-t32-L2-dense-pt1-cli-r11`
    (label `frozen-r11-d8075d76-gate-copy`).
  - Work files (the export view, the run directory, the owners'
    decommitments) are in a new directory under `~/zk60-owner-private/`.
    This lane never reads it (D21).
- **Two figures equal the round-9 CLI run's:**
  - the identity the binary printed for its export view, **0f4cef3e…**;
  - the capture's absorbed calibration word, **45ce7431…**.

**The gate, tools v18** (`EV/round15/r15_gate.sh`):

| Record | Result |
|---|---|
| Token gate (`v18-tokengate-cli11.json`, with the b4 export override as v14 on the r9 capture) | **PASS**, false parts none, 974 s. Integrity: **52 pins** (40 R7, 6 r7c, 4 r9, **2 r11 readings**), 0 refused. Replay 9,838 / 344, binding reproduced. New slots **15 / 15**. Block-stage terminals: every block slot equal on both blocks; calibration cross-checks, I/O wiring, plane index and token integrity all true. Full preimage **2,502,073** entries, **0 differing** (3,328 salted leaves). Joint **0**, equal to the sum of parts, over 133,153 word pairs. **36 / 36** live controls fire, 2 not applicable (TC-9 IN / OUT M4), as on every harness capture: 38 control entries |
| NL-1 (`v18-nl-cli11.json`) | **PASS**. T-0 15 / 15, S3 45 / 45, S1 / S4 / F-0 15 / 15 in every mode, S5 controls fire. **Its summary equals the r9 CLI capture's** (round 10, v13) exactly |
| Surjection (`v18-ts-cli11.json`) | exit 0, controls ok. Per role: IN A-in 0 (3 / 3 groups onto), E-token-in 0, H-in 2; OUT A-out 0 (18 / 18), B-out 0, E-token-out 0, H-out 2; TS-1 fires on all 7 token roles. **Every figure equals the r9 CLI capture's** (round 10, v12) |
| v18 unit suite (in the frozen snapshot) | **81 tests OK** (`EV/round15/gate/unittests-v18.log`), including `TokenR11Pins` on this capture |

**Equality with the round-9 CLI capture [MEASURED]**
(`EV/round15/compare_r15.py` → `compare_r15.json`, a088108e…; NL-1 and surjection included). Against the
r9 CLI capture's v14 record (round 10, `EV/round10/cli9/v14-tokengate-cli9.json`):

- **every randomness-free figure of the token gate is equal.** These are the
  figure set of the round-12 addendum: statuses; replay counts; hashed
  bytes and columns; every commitment's role, class, rows, disclosed and
  expected dimension, claims, groups, k0 and reserved pairs; G-3; the joint;
  the full preimage's commitments, salted leaves and differing entries; the
  terminal counts; the block-stage parts; the controls.
- The two run.json files are also equal in profile, block profile, the
  calibration word, the block digests, the parameter line, the schedule
  digest, the shape, the stage lines, the layout description, the hash tag
  and the transcript domain.
- They differ only in the fresh endpoint roots (`token_io.input_root` /
  `output_root`) and the expected-policy digest that contains them. Both are
  functions of the run's randomness.
- The pins differ in exactly the two files of §1.

## 3. D33 (the trained-block statement): the token files are report-only [MEASURED]

**frozen-r11 moves no file the block gate enforces.**
`EV/round15/d33_report_only_check.py` (frozen v18) → `d33_report_only_check.json`
(26fb07da…) checks four things:

- **What the block gate enforces.** Its pin tables (the terminal port's
  ported and if-present files, the run-layer and shared tables, the mask
  layer) enforce **44 files, none of them a token-I/O file**.
- **The tk9 L = 1 dense block bundle, with and without the r11 digests.**
  It pins 52 files. Replacing its `token_io.rs` and `cli.rs` digests with
  frozen-r11's leaves the terminal, run-layer and mask pin checks passing,
  exactly as on the bundle as captured. The token files are **report-only on
  a block bundle**, as in the tk7 and tk9 notes.
- **The other pins.** Every other pin of that bundle equals the frozen-r11
  file of the same name: 49 of 49. The one exception is the capture writer,
  where the bundle pins the gate's test-only patch f47e28bf; its base
  aaff4e6e is frozen-r11's file.
- **So** a block bundle written from a frozen-r11 gate copy with the same
  patch would differ from the tk9 bundles in exactly the two report-only
  token pins.

**The trained-block CPU CLI, built from frozen-r11** (`EV/round15/r15_heavy2.sh`).

- Built in the unmodified copy with the native lane's own command (`cargo
  build --release --offline --locked -j2 --example zk60_trained_block`):
  `~/zk60-artifacts/tinyllama-gate-bins/zk60_trained_block.r11.release.bin`,
  sha256 **631e2a1506c566d40915a492aa2adb899f0b66b2a0cd52b3d2451eeb5da41364**.
- It is built in a different path from tk9's `911e82f0…`, so the bytes need
  not match. If a D33 extension names a binary, it names this one or the
  native lane's own build.
- It was run on review P-18's inputs: layers 7..9, 45 + 312 input files,
  0 moved.
  - `stack-prove` exited 0 in 7.7 s at 1.02 GiB. It was sealed before the
    header, with parity bit-exact, and wrote 2 segments of
    **23,019,088 B**, the same as tk9.
  - `stack-verify` ran in a fresh process with `--expect-statement
    ef061000…`. It exited 0 and printed **statement-published, identity
    ef061000…**, the same as tk7 and tk9.

**Not re-done for D33 on frozen-r11:**

- block captures and the block gate on them. No enforced pin moved, so the
  tk9 records' figures carry by reading;
- P-18's capture through the trained-block CLI and the 22-block pass F.
  These are carried by reading, as in tk9.

## 4. Did any figure rest on one run calibration for every stage? (diligence)

**No figure that D33 or D36 rests on could have been a false pass from the
one-calibration reading that tools v16 and earlier used.**

**The exports [MEASURED, profile.json].** Both statements' exports declare
`per_layer_constants_differ = [exp_e_s, silu_member]`, and those two are
the only null `profile_constants`:

- D33's `pg_rot1_export_T32` (profile.json sha256 b25ba5f5…);
- D36's `pg_rot1_b4_T32_cal128` (826f7641…).

Both are **table keys**, not calibration constants. Each stage's exp and SiLU
tables are captured per stage and checked per stage: slot 19, E4, TL-4. None
of the eleven calibration constants varies by layer in either export, so every
stage of every capture those statements rest on IS at the run calibration. A
one-calibration reading was therefore exact for them.

**The 8B export.** The Llama-3-8B export used in the token gate rounds
(`llama3_8b_pg_rot1_b7voc0_T32`) does mark `sh_s` per layer, but:

- 8B is outside both statements;
- its token runs' block stages were checked through tokenblocks' per-block
  shim, each block at its own calibration (the v10 report §2.3: 8B L2,
  layer 1 at sh_s 7 against the run's 6), not through the one-calibration
  path.

**Wrong constants fail.** A terminal check made at the wrong constants
fails; it does not pass. TL-5 (round 14) evaluates a stage with its own
constants at the run's, and fails at exactly that stage's affected slots,
(1, 14) and (1, 17). TL-2 shows that each constant moved by one fails the
slots that read it.

**The only capture in this lane with per-layer calibration constants** is
round 14's TinyLlama T128 DD L = 2, which is gated by v17's per-stage reading.

**A wording correction to the round-12 addendum** (sha256 44956506…, cited
by D36's header; not edited). Its table's "38 / 38 fire" counts the 38
control entries of each token-gate record. **36 are live and all fire; 2 are
not applicable** (TC-9 IN / OUT M4, as in the v10 report). This is the same
on frozen-r7 and frozen-r9, so the equality it reports is unaffected.

## 5. Limits

- **Not re-done on frozen-r11:**
  - the ten harness captures. Round 12 measured them on frozen-r9, and no
    file on their path moved;
  - the L = 1 and L = 22 CLI runs;
  - the GPU path.
- **No integrated tree.** frozen-r11 is a frozen copy, not a commit; a pin
  set for it would be its 52 pins.
- **Soundness** is not this note's subject. The token lane's REVIEW6 TR7-5..7
  findings are what round 11 answers; whether a review covers them is for the
  coordinator to state.
- **None of this is a privacy acceptance.**

## 6. Evidence index

| What | Where |
|---|---|
| The gate copy and its check | `ops/zkp-mvp/token-gate-r11/`; `EV/round15/verify_copy.json` |
| The capture queue and logs | `EV/round15/r15_heavy.sh`, `r15-build.log`, `cap-tinyllama-t32-L2-dense-pt1-cli-r11.{log,guard.json}`, `hashline-lib-test-release.r15.sha256` |
| The trained-block CLI and P-18 run | `EV/round15/r15_heavy2.sh`, `zk60_trained_block.r11.release.bin.sha256`, `r15-cli-stack-{prove,verify}.log`, `cli/inputs.check` |
| The gate queue and records | `EV/round15/r15_gate.sh`; `EV/round15/gate/` |
| Comparisons | `EV/round15/compare_r15.py` / `.json`; `EV/round15/d33_report_only_check.py` / `.json` |
| Tools | `EV/gate-tinyllama.tools.frozen.v18.sha256` and patches; `ops/zkp-mvp/gate-tinyllama/frozen_v18/` |
| Ledger | `EV/PROGRESS.md` (round 15 entries, 2026-10-21) |
