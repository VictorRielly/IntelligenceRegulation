# Privacy gate, sub-lane P-18: one capture through the R6 CLI's own path (L = 2)

Review finding P-18 of `../PRIVACY_STATEMENT_TRAINED_T32_DRAFT.md` (§1
"Evidence path", §10b item 5): every gate bundle so far was made by the test
harness (`TrainedChain` + `run::prove_run` + `RunStatement::new_bound`). This
sub-lane makes ONE bundle whose RECEIPT BYTES were written by the production
CLI's own prover (`zk60_trained_block stack-prove`, R6 release binary), and
whose verification is the CLI's own verification function
(`run::verify_run_from_dir_hashed_with` over the CLI's run directory), with
the gate's recorder attached.

**Nothing here is a privacy acceptance.** A capture is the INPUT to the run
privacy gate; only the security review process can accept, and rulings are
Victor's (`docs/zkmatrix-poc/ZK60_DECISIONS.md`).

Write set (exclusive): `ops/zkp-mvp/trained-1b-gate-r6/`, this directory,
`/home/victor/zk60-artifacts/tinyllama-cli-seq-ho00/`,
`/home/victor/zk60-artifacts/pg_rot1_export_T32-verifier/`,
`/home/victor/zk60-artifacts/tinyllama-cli-run-l2/` (+ the CLI's
`.unverified-statement` sibling, removed by `stack-verify` itself),
`/home/victor/zk60-artifacts/tinyllama-cli-capture-dense-l2/`.

Rules: `ops/zkp-mvp/LANE_RULES_20261017.md` (guard on every heavy leaf,
detached with a `.done`, no git writes, no kill). Costs are [MEASURED,
shared box, n=1] unless labelled otherwise.

## Ledger (UTC from `date -u`)

- 2026-10-17 (first session): read the brief, the patch, the R6 CLI's
  stack-prove / stack-verify. Stopped by the usage limit before any write.
- 2026-10-19 09:28 resumed (coordinator message 09:27). `/tmp` wiped by the
  10-18 21:29 reboot; nothing of this lane existed.
  - R6 CLI `results/zk60_1b_native_20261017/r6/zk60_trained_block.release.bin`
    sha256 `c17abef1a2f1472fe50b1d1dec5b10415c9f6ee73358ffcf9ca1c8739b792eb9`
    = `r6/binaries.sha256` [checked].
  - R6 frozen tree checked in place against `r6/manifest_frozen.json`
    (sha256 `44e0e54f…86d5`): 219 listed, 0 mismatch, 0 missing, 0 unlisted;
    tree digest formula = sha256 of `"<path> <digest>\n"` sorted by path
    (`results/zk60_1b_native_20261017/r5_manifest.py`).
  - Read of the CLI (R6 `trained_block.rs`):
    - `--layers A..B` is B-EXCLUSIVE (`parse_layers`, :1924): `7..9` = layers
      7 and 8 = the harness's `HL_PB_FIRST_LAYER=7 HL_PB_CAPTURE_BLOCKS=2`.
    - labels are allow-listed (C-R4, :1168-1177): stack label
      `zk60-trained-stack` only (the default).
    - `stack-verify` refuses an export holding any `seq_*` entry (P-5,
      :1349); the verifier's copy may hold everything else.
    - `stack-prove` without `--verify-in-process` writes the segments into
      `--out` and the prover statement into `<out>.unverified-statement/`;
      `stack-verify` (fresh process) verifies with
      `run::verify_run_from_dir_hashed_with(&rst, &mut CacheBlocks(..), &art)`
      (:2657) and then writes `<out>/statement/` itself and removes the
      unverified directory.
    - `stack_records`, `stack_context`, `BlockCache`, `CacheBlocks` are
      PRIVATE to `trained_block` (`run_capture_tests` is a sibling module), so
      the capture test re-states them from `pub(crate)` pieces:
      `TrainedExport::load / run_constants / shape_for / load_layer /
      reload_block / statement_of_records`, `geometry.run_shape`,
      `ExpectedIo::from_bytes_at`, `RunStatement::new_bound_from_digests`,
      the `run::BlockSource` trait, `run::digest_is_the_statements`. See the
      test for the line-by-line correspondence.
- 09:29 copy: `rsync -a --exclude='target*'` of `r6/frozen-tree/` into
  `ops/zkp-mvp/trained-1b-gate-r6/`; `verify_copy.py` (this dir; adapted from
  `../r5/verify_copy.py` with the native formula) → `verify_copy.before_patch.json`:
  219/219, 0 mismatch / missing / unlisted, tree `83f1fdcb…cc33` REPRODUCED.
- 09:30 capture patch `../trained-1b-gate-vs-review-r2.v2.patch` (sha256
  `66f65a68…777e`) applied with `patch -p1 --no-backup-if-mismatch`: all three
  `run_capture.rs` hunks at offset 24, `run_capture_tests.rs` appended clean.
  `verify_copy.after_patch.json`: exactly those two files differ, nothing else.
- 09:31 `record_sources.py v1` (this dir; adapted from `../r5b/record_sources.py`):
  - `trained-1b-gate-r6-vs-frozen-r6.v1.patch` 22,482 B, sha256
    `7f5d81c326c1c417a00871d277965d3b58e10d4d87150a61358f42f473aef8b5`, 2 files
    (`run_capture.rs`, `run_capture_tests.rs`);
  - `trained-1b-gate-r6.sources.v1.sha256` 219 files, sha256
    `d092f8b4251deb305a0ea8e9504f0c1128923e827c5c320529b1958e78fd3388`;
  - `r6-source-pins.v1.json` (sha256 `2c4b43ab…2779`): the capture's 46 source
    pins (17 own + 29 shared, parsed from the frozen R6 `run_capture.rs`),
    each with its sha256 in the frozen R6 tree, the gate copy and the frozen
    R5b tree. Copy ≠ R6 only in `run_capture.rs` (R6 `1d43d68c…a503`, copy
    `31557a27…be6f`, the capture patch). R6 ≠ R5b in exactly six pins:
    `run.rs` `ad92be08…e0e9`, `protocol.rs` `85ca8931…e6581`, `shape.rs`
    `7b0c9742…c5f6`, `private_block.rs` `386194fe…3293587`,
    `trained_statement.rs` `6f18efcd…de1c34`, `trained_block.rs`
    `bc18b9d8…638b3d` (full digests in the JSON).
- 09:31 export read: `pg_rot1_export_T32/profile.json` marks only `exp_e_s`
  and `silu_member` per layer; `sh_s` is uniform (6), so R6's per-layer score
  shift (`sh_s_per_layer`) is INACTIVE at this export. The export holds
  `seq_ho00/` AND `seq_ho01/`; a verifier copy drops both (P-5 refuses any
  `seq_*` entry) and keeps `profile.json`, `rotation.json`,
  `rotation_sign.bin`, `README.md`, `layer_00..21/`.

## 09:32 PLAN CHANGE (coordinator message): no R6 CLI capture

The coordinator moved P-18 to the native R7 freeze (R6 + N-r6-b + the Q-2
backend allow-list), because the R6 CLI's free `prover_reported.backend`
field is review item Q-2. **No prove, verify, build or other guarded job of
this lane was launched on R6; nothing is pending.** The R6 copy
(`ops/zkp-mvp/trained-1b-gate-r6/`, patched, NOT built) stays as a record;
the capture will be redone on an R7 copy when the freeze is announced. None
of the three `/home/victor/zk60-artifacts/tinyllama-cli-*` directories nor
the verifier export copy was created.

### What the R7 resume does (commands to run, with R7 paths substituted)

`G=python3 /home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py`,
`EV=results/zk60_gate_tinyllama_20261017/r7` (or reuse this dir under an R7
heading), `BIN=` the R7 release CLI (check its sha256 against R7's
`binaries.sha256` first), `X=/home/victor/IntelligenceRegulation/results/zk60_1b_calibration_20260929/export/pg_rot1_export_T32`.

1. Copy R7 frozen tree → a new gate copy; `verify_copy.py` against R7's
   manifest (tree digest must reproduce); apply the v2 capture patch (or port
   by hand); `record_sources.py` re-pointed at R7 (OLD / NEW / tag); re-read
   whether R7 moved `trained_block.rs`'s `stack_verify_inner` /
   `stack_records` / `stack_context` / `CacheBlocks` (the test mirrors them).
2. Add `capture_a_cli_run_directory` (`#[ignore]`, in `run_capture_tests.rs`
   only; design below).
3. Build: `setsid nohup bash -c '$G run --class build --need-gib 3 --cap-gib 5
   --label p18-build --wait-secs 7200 --max-secs 3600 --log $EV/p18-build.log
   --done $EV/p18-build.guard.done --result-json $EV/p18-build.guard.json --
   /home/victor/.cargo/bin/cargo test --release --lib --no-run --offline
   --locked -j2 --manifest-path <copy>/hashline/Cargo.toml; echo $? >
   $EV/p18-build.done' >/dev/null 2>&1 &`; wait with a `run_in_background`
   `until [ -f $EV/p18-build.done ]` loop.
4. Inputs (plain copies, no guard needed): `mkdir
   /home/victor/zk60-artifacts/tinyllama-cli-seq-ho00` and `cp -p
   $X/seq_ho00/* ` into it; `rsync -a --exclude='seq_*' $X/
   /home/victor/zk60-artifacts/pg_rot1_export_T32-verifier/`; check
   both with sha256 lists into `$EV`.
5. Prove (class cpu, need 3 / cap 4.5, max 1800, detached, own `.done`):
   `$BIN stack-prove --export $X --seq-dir
   /home/victor/zk60-artifacts/tinyllama-cli-seq-ho00 --out
   /home/victor/zk60-artifacts/tinyllama-cli-run-l2 --layers 7..9 --label
   zk60-trained-stack` (stdout = JSON events incl. `statement_identity`;
   stdout/stderr kept in `$EV`, public held-out calibration data, values not
   pasted into the ledger). No `--verify-in-process`, so the prover statement
   lands in `tinyllama-cli-run-l2.unverified-statement/`.
6. Fresh-process verify (class cpu, same caps, detached): `$BIN stack-verify
   --export /home/victor/zk60-artifacts/pg_rot1_export_T32-verifier
   --artifact /home/victor/zk60-artifacts/tinyllama-cli-run-l2
   --expect-statement <identity from step 5> --layers 7..9 --label
   zk60-trained-stack` → `verified`, then `statement-published` (writes
   `<run>/statement/`, removes the unverified dir).
7. Capture (class light, need 2 / cap 3.5, detached): `/usr/bin/env
   HL_PB_EXPORT=<verifier copy> HL_PB_ARTIFACT=<run dir> HL_PB_LAYERS=7..9
   HL_PB_LABEL=zk60-trained-stack
   HL_PB_CAPTURE_DIR=/home/victor/zk60-artifacts/tinyllama-cli-capture-dense-l2
   HL_RUN_CAPTURE_PUBLIC_TABLES=1 HL_TEST_SOURCE_COMMIT=<label naming the R7
   tree digest + gate copy patch> <copy>/hashline/target/release/deps/hashline-<hash>
   private_block::run_capture_tests::capture_a_cli_run_directory --ignored
   --nocapture --exact` (the test binary from step 3's build log).

### Test design: `capture_a_cli_run_directory` (to write on R7)

Mirrors `stack_verify_inner` step by step; every refusal is a panic with the
CLI's reason:
- env as in step 7; refuse a capture dir inside the repo
  (`capture_dir_from_env`); refuse an export holding any `seq_*` (mirror of
  the private `refuse_prover_private_entries`); label must be in
  `trained_block::STACK_LABELS`.
- `TrainedExport::load`; layers parsed `A..B`, B exclusive, each in
  `ex.layers` (mirror of private `parse_layers`); `run_constants`,
  `shape_for`; per layer `load_layer(&sh,&c,l,false)` → `record.block_digest`
  and the record (mirror of private `stack_records`, sequential instead of
  2-wide: same loads and checks, layer order); `statement_of_records`.
- context: length-prefixed blake3 of `["hashline/zk60-trained-stack-context/1",
  variant, label]` + u64-LE layers (mirror of private `stack_context`,
  C-R1's 40-byte refusal included).
- `<art>/statement/` must exist (i.e. the fresh-process `stack-verify` ran);
  its `statement.json` parsed with `trained_block::parse_json`: schema
  `zk60-trained-stack-run/2`, `statement_written_by` = the FreshVerify text,
  `trained_statement_identity` = hex(st.identity()) (asserted and PRINTED,
  public), `context` = hex(ctx), `expected_io` = hex(expected.bin).
- `expected.bin` (≤ 4096 B) → `ExpectedIo::from_bytes_at(&sh, ..)`,
  canonical re-encoding, bytes 8..40 = ctx; `RunStatement::new_bound_from_digests
  (ex.geometry.run_shape(&sh,l), ctx, expected, digests, &[(0,0); l], &st)`.
- recorder: `Recorder::attach()`, `begin_run_with(rst.capture_header(),
  rst.binding(), CaptureOpts{arrays:true, public_tables})`, then
  `run::verify_run_from_dir_hashed_with(&rst, &mut CliBlocks{..}, &art)` —
  THE CLI's verification function on THE CLI's run directory — then
  `run_capture::take()`. `CliBlocks` is a test-local `run::BlockSource`
  mirroring the private `CacheBlocks`/`BlockCache`: `reload_block(..,false)`
  one block resident, refused unless its digest is the statement's;
  `fit_the_shape` on the block GEOMETRY only; `are_the_statements` = CS-6 on
  the digest list via `run::digest_is_the_statements`.
- the returned `seen` (len, sha256 of exactly the verified bytes) must equal
  `statement/segments.json` entry for entry; segments then re-read through
  `run::read_segment_bounded` and their (len, sha256) must equal `seen`; those
  bytes go to `write_bundle` + `check_bundle_on_disk(dir, l, binding, segs,
  true)`; assert `capture_header().calibration == st.identity()`.
- note: receipt bytes = the R7 CLI's `stack-prove` (binary sha256 named),
  verification = the CLI's `verify_run_from_dir_hashed_with`, recorder = the
  gate's; NOT a privacy result.

Expected costs for sizing the R7 jobs: the gate's R5b lib-test build was
151 s wall, peak cgroup 2.04 GiB (`../r5b/r5b-build.guard.json`) [MEASURED,
shared box, n=1]; step 3's command form is that build's.

- 09:33 handed back to the coordinator. No job of this lane is queued or
  running; no `.done` is owed.
