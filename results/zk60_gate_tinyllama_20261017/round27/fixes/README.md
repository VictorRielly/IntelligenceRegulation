# Gate round 27, the v25 freeze fixes (FR25-01 to -06, -11, -13, with FR25-14's tests)

Branch `fr25-fixes`, from `4d906668` (the merge of the round-27 freeze review). Date: 2026-11-02.
The review is `../FREEZE_REVIEW_V25.md`.

These fixes change what the status counts and what the pins admit. No check computes anything new, and no figure moves.
The changes are in v25 files only: the five scripts below, two existing v25 tests and one new test module. No
`frozen_v*` file, no v24 file, no Rust file and no pinned file changed. `D55_REAL_CONTENT_PRIVACY_GATE_PASSED` is
untouched. **Nothing here is a privacy statement or an acceptance.**

All paths are under `ops/zkp-mvp/gate-tinyllama/staging_v25/` unless given in full.

## 1. Each finding: what changed, and the test that shows it

| finding | change (file : function or constant) | test (`tests/…`) |
|---|---|---|
| **FR25-01** (High). HASH-2 passed when the printout was missing. | `scripts/zk60_native_rg_d55hash.py`. `load_rust` now refuses when `ZK60_S25_W2_PRINTOUT` is unset, empty or unreadable, and `hash2_verdict` then makes HASH-2 **false**, with a finding. HC-7 is always in the control list: without the printout it is recorded with `fires: False` and a `not_run` reason, so the controls fail too. `d55_hash` is called only at an R13 base. | `test_fr25_fixes.Printout.test_not_set_or_unreadable_is_refused`, `…test_hash2_is_false_without_the_pinned_table`; on the rung bundle, `test_fr25_fixes.OnABundle.test_hash2_without_the_printout_is_false_and_hc7_is_not_fired` and `…test_hash2_with_the_pinned_printout_holds` |
| **FR25-02**. The printout's digest was not checked. | `d55hash.py`: `S25_W2_PRINTOUT_PIN = bac4bbd6…dc53`. `load_rust` reads the file once, hashes it, refuses any other digest and parses the very bytes it hashed (`rust_table_of_bytes`). The parse is the same: the test checks it equals `rust_table(path)`. `S25_W2_PRINTOUT_MADE_BY` records the `s25_tests.rs` that made the printout: commit `076a485f`, blob `5ab22020`, sha256 `39b2e1c02606f72f49052025d0dfbb3e4bc65ac7e776b00f991922845503b99e`, 205,091 B (computed with `git show 076a485f:…/s25_tests.rs`). The HASH-2 part records it as `s25_printout.made_by` and `rust_table.printout_made_by`. | `Printout.test_a_wrong_digest_printout_is_refused` (an edited copy with one extra kind), `…test_the_genuine_printout_is_the_pin_and_parses_as_before` (the committed `.gz`, unpacked into a temporary directory; also checks `PRINTOUTS_SHA256.txt`), `…test_the_printout_names_the_s25_tests_rs_that_made_it` (re-hashes the git blob) |
| **FR25-03**. `--no-joint` and `--no-controls` still gave D55-PASS. | `scripts/zk60_native_rg_d55.py`: `d55_status` caps either flag at **D55-DEV-PASS**, and the reason is listed in `status_reasons`. `d55_gate` writes `controls_run` and `joint_run` into every record, the REFUSED early return included. The choice is explained in §3. | `test_fr25_fixes.Status.test_no_controls_or_no_joint_never_gives_pass`; through the driver, `StubbedDriver.test_no_controls_and_no_joint_are_capped` |
| **FR25-04**. D55-PASS ignored `not_here`. | `d55.py`. **`ACCEPTED_RESIDUALS`** holds exactly one entry: "G_k in the clear: recovered on SC_FZC, not read from a bound line", accepted by "round 27 freeze review, §3 Q5 (to be recorded in the D60 row)". Any other `not_here` entry keeps the record at D55-DEV-PASS. A self-read reading counts as owed, so it also blocks PASS. **`W16_FAMILY_CAP`**: any family other than R13 is capped at DEV-PASS. The record shows the result in `not_here_accepted` and `not_here_unaccepted`. | `Status.test_an_unaccepted_not_here_entry_blocks_pass`, `…test_the_accepted_residuals_are_the_one_review_verdict`, `…test_the_w16_family_is_capped`; `StubbedDriver.test_the_w16_family_is_capped`, `…test_a_self_read_reading_is_owed_and_blocks_pass` |
| **FR25-05**. The completeness of the pin list was not checked. | `d55.py`: `pin_set_check`, wired into `PINS.ok` as `PINS.pin_set`. The manifest's `writer` must be one of the two known strings (copied verbatim from the Rust writers). The declared pin set must then be exactly that writer's set: anything missing, unexpected or duplicated is refused. **`REGISTERED_WRITER_PINS`** holds the 75 files of `OWN_SOURCE_FILES` (44) + `SHARED_SOURCE_FILES` (31) of `run_capture.rs` at `10b6d3be…` (blob `dd1195a2`, re-hashed before parsing). They were derived by `derive_pins.py` (`logs/derive_pins.log`), and a test re-derives them from the file at that digest, order included. **The test-only writer** adds `run_fork.rs`, `run_fork_wire.rs` and `w16_privacy_gate_tests.rs`; as a set that is 76 files, because since D60 the first two are already in the 75. New controls on doctored copies of the manifest: **P-4** removes one expected pin, **P-5** adds an unexpected one. | `PinSet.*`: the re-derivation, the honest 75, all 13 retained D55 manifests, the review's cut to 6 (the classification alone still says ok; the pin set refuses it, with 69 missing), an empty list, an extra pin, a duplicate, the test file under the registered writer, unknown or absent writers, the test-only writer's 76, and P-4 / P-5 firing; `StubbedDriver.test_a_cut_or_extended_pin_list_is_refused` |
| **FR25-06**. Two W16 readings read a pin on a 48-bit prefix. | `scripts/zk60_native_rg_w16.py`: **`W16_READINGS`** now holds full sha256 values, and `classify_pins` matches them by **equality**. The digests and their sources are in §2. New control in `d55.py:pin_controls`: **P-3**. It takes a W16-read pin: one of the bundle's own if it has one; otherwise it writes `run.rs` at its W16 digest into the copy. P-3 requires the pin to be read at its full digest and UNREAD at the review's prefix twin (12 hex + 52 zeros). | `W16FullDigests.*`: every entry is 64 hex and agrees with R26; the digests equal what the five round-25 W16 records declared; the twins (prefix + zeros, last hex changed) are unread; P-3 fires on the rung manifest, and with the old prefix rule patched back in, P-3 does not fire and the PINS controls fail |
| **FR25-11**. A control with nothing to act on counted as fired. | `d55.py:pin_controls`: P-1 / P-2 with no R26-read pin now report `fires: None`, `not_applicable`. `_control_family_ok` requires that no control has `fires: False` and that each family (B-\*, P-\*) has at least one applicable control that fired; an empty family fails. `scripts/zk60_native_rg_d55ts.py`: `fidelity_control` makes TS-1F **not applicable** (`ok: None`) when it has no row, and **refuses** a fidelity limit below 1 (`ok: False`). `controls_ok` leaves out not-applicable controls and needs one applicable control that holds. | `NotApplicable.*` (the review's `exp_prefix` (b) shape; a family made only of not-applicable controls; TS-1F with no row, with limits 0 / 0 / −1, and the family verdicts) |
| **FR25-13**. Three readings were still labelled self-read. | `scripts/zk60_native_rg_r26readings.py`: the three wiring entries (`run_capture.rs` `10b6d3be`, `gpu/metal.rs` `a96882bc`, `gpu/metal_kernels.metal` `be968236`) now name **`WIRING_CHECKED`** as their reader: the independent check `READINGS_R26_WIRING_CHECK.md` (commit `748fe707`, sha256 `3c3dae4a…`, re-hashed by a test). Each pointer names the check's section. The scopes are unchanged: the two Metal files stay **CPU-path only**. No entry is `SELF_READ` any more, so `self_read_pending_independent_check` is empty, and the not_here line "the independent check of the self-read readings …" no longer appears. | `test_r26_readings.R26Table.test_the_wiring_entries_are_the_wiring_record_and_carry_the_independent_check`, `…test_the_independent_check_is_the_committed_record_and_names_each_digest`, `R26Classification.test_a_cpu_made_bundle_reads_the_metal_pins_at_the_cpu_path_scope_only` (updated); `StubbedDriver.test_the_genuine_shape_is_d55_pass_with_its_record_fields` |
| **FR25-14** (tests). | `d55.py`: **`d55_status`** is the single pure status function. `d55_gate` calls it once, at the end; the two lane blocks no longer lower the status themselves, though their delimited text is kept. | `Status.*` calls `d55_status` directly. `StubbedDriver.*` runs the real `d55_gate`, with every figure part stubbed, on the retained rung manifest, using the real classification, pin-set check and PINS controls, for each flag combination, each family, a cut / extended / unknown-writer pin list, a re-labelled self-read reading and a false part. |

Two existing tests needed small updates:

* `tests/test_r26_readings.py`, for the relabel and the full W16 digest.
* `tests/test_d55_ts_hash.py`, `OnABundle.test_the_hash_layer_and_census_and_every_control`: the printout is now
  mandatory, so the test uses `ZK60_S25_W2_PRINTOUT` when it is set. Otherwise it unpacks the committed
  `s25_w2_printout_v2.log.gz` into a temporary directory and checks the gate accepted it.

## 2. FR25-06: the full digests and where they came from

| file | W16 prefix | full sha256 | found in |
|---|---|---|---|
| `src/private_block/run.rs` | `b9b40cadef4a` | `b9b40cadef4ac98ad1c0820dd42c035d491298bc603c2536f2294df2fd1b44c6` | see below |
| `src/private_block/run_capture.rs` | `d10d33e3e04f` | `d10d33e3e04f5a35695023ed55c99d14398a1c3edecbf6c5db8f787e5feaaee1` | the same |

Both digests come from two independent sources:

* **The round-25 W16 records.** Every record in `results/zk60_gate_tinyllama_20261017/round25/w16/` (five records)
  has these digests in `W16-0 integrity.source_pins`. These are the bundles the W16 readings read: each record's
  `PINS.readings` names all nine W16 readings.
* **Git.** These are also the git blobs of these files at commit `efd2e515` (2026-11-01, the W16 privacy-gate commit,
  that is, "the gpu-metal tree of 2026-11-01" the readings name). I hashed every commit since 2026-10-20 that touched
  either file, and `efd2e515` is the only match.

The other seven W16 entries had round-26 readings at the same prefix. Their full digests equal the R26 ones and the
round-25 records' (a test checks both). No digest had to be guessed, and no pin is left unread by this fix.

`W16_READINGS_DIGEST_SOURCE` in `w16.py` records the sources.

## 3. FR25-03: the choice

**Capped at D55-DEV-PASS, not a status of its own.** The reasons:

* DEV-PASS already means "every part that ran is true, but the figures are NOT admissible evidence". A run without its
  controls or its joint rank is exactly that.
* With a cap, the status set stays closed: D55-PASS / D55-DEV-PASS / NOT-OK / REFUSED. Every consumer that admits only
  `D55-PASS` stays correct with no change, including D60's "a PASS record exists" and the queue summaries. An
  unfamiliar new string is a failure mode of its own.
* The reason is still named in the record, in `status_reasons`, and in two new fields: `controls_run` and `joint_run`.

## 4. Regression: the fixed rules on the records already written

`exp_restatus.py` (`logs/restatus.log`) does not recompute any figure. It applies the fixed status rules to each
record's own fields, plus `pin_set_check` on the bundle's manifest:

* **The one merged 18-part record finished so far, `d55-mg-r13-rung-s0`, stays D55-PASS.** Its parts are 18 / 18,
  controls and the joint rank are on, the printout is pinned and the pin set is 75 / 75. The only not_here line left is
  G_k, because its self-read line is exactly the three FR25-13 relabels.
* **The earlier partial-lane records** were D55-PASS before. These are the round-26 four, the NL-1 / PRE four and the
  TS lane's twelve `records_final`. Under FR25-04 they become **D55-DEV-PASS**, because each one still listed owed
  items in `not_here`:
  * NL-1 and the full preimage, in the TS lane's records;
  * TS-1, the census and the hash census, in the NL / PRE lane's records.

  This is the intended effect. Only records with all 18 parts can be PASS.
* The W16 and W16R2 D55 records stay DEV-PASS: the family cap applies, and their pin set is 74 / 76 (see §5).

## 5. Runs (each guarded, `--class light`, about 0.0–0.35 GiB and 0–9 s; logs in `logs/`)

Tests:

| log | what | result |
|---|---|---|
| `tests1.log` | `test_fr25_fixes`, no bundle | 34 tests, OK, 3 skipped (the bundle tests) |
| `test_fr25_fixes_rung_bundle.log` | `test_fr25_fixes -k OnABundle` on `pg_bundles_r26/d55-r13_rung_h24-s0` | 3 tests, OK |
| `test_r26_readings.log` | `test_r26_readings`, no bundle | 12 tests, OK, 2 skipped |
| `test_r26_readings_with_bundles.log` | `test_r26_readings` with the rung bundle and the old D60 bundle | 12 tests, OK |
| `test_d55_ts_hash_rung_hash_only.log` | `test_d55_ts_hash -k test_the_hash_layer_and_census_and_every_control` on the rung bundle | OK |
| `test_w16_gate_with_bundles.log` | `test_w16_gate` with the W16, W16R2 and W16 D55 scratch bundles | 20 tests, OK |
| `suite_v25_no_bundles.log` | the **whole v25 suite with no bundle variables** | 203 tests, 99 skipped, **only the known failure** `test_v4_status_g10.ClassifierV24.test_r19b_self_check_and_its_control` (the r19b binary) |

Other logs:

* `test_d55_*.log` / `test_w16_gate.log`: the other touched modules without bundles, all OK.
* `tests2.log`: the first `test_r26_readings` run, which had one error: a test I had split left a `doc` reference
  behind. Fixed, then rerun in `test_r26_readings.log`.
* `derive_pins.log`: the pin list, the printout digest and every D55 manifest under `zk60-artifacts/d60_20261102/`:
  * the 12 registered bundles: 75 / 75;
  * the old D60 bundles: 73, without the Metal pins;
  * the GPU-marked control: 75.
* `restatus.log`: §4.

No build, proof, gate run or full suite was run. The heavy lock stayed with the merged gate.

## 6. Not done here, and things to know

* **The D60 row.** The accepted residual cites "round 27 freeze review, §3 Q5 (to be recorded in the D60 row)". The
  coordinator still has to record that acceptance in `docs/zkmatrix-poc/ZK60_DECISIONS.md` (D60). I did not edit the
  register.
* **Not in this brief, and not done:**
  * FR25-07 (`ZK60_NL_CHECK_DIR` shadowing imports; the commands below unset it);
  * FR25-08 (the tail frame's digest);
  * FR25-09 (the backend from the prover; `writer` is now required to be a known string, which is half of it);
  * FR25-10 (the r19b manifest pin);
  * FR25-12 (J-C5's premise; `--other` is not yet required for a record);
  * FR25-14's exit code (DEV-PASS still exits 0) and its refusal to overwrite a record;
  * FR25-15 to FR25-18.
* **The test-only writer's older bundles.** The W16 and W16R2 D55 bundles in the scratchpad (74 pins) were written by
  a tree whose `OWN_SOURCE_FILES` / `SHARED_SOURCE_FILES` were shorter. They now fail the exact pin set. That is
  harmless while the W16 family is capped. If the W16 family ever needs `PINS.ok`, the expected set has to be held
  per writer **and tree**.
* **Out of scope.** `w16_gate`, the plain one-block W16 gate, gets the full-digest rule but not the pin-set check,
  because the brief scoped FR25-05 to D55 bundles.
* **`ZK60_S25_W2_PRINTOUT` is now required** for every R13 `d55_gate` run: without it, HASH-2 is false.

## 7. For the coordinator, after the merged-gate queue ends

1. **The full v25 suite on the fixed tool state**: cpu class, about 7 min, the m32 suite's environment plus the pinned
   printout.

       bash /Users/victorrielly/IntelligenceRegulation/.claude/worktrees/fr25-fixes/results/zk60_gate_tinyllama_20261017/round27/fixes/suite.sh

   (Give the main checkout as the first argument after a merge.) Expected: 203 tests, with only the known r19b-binary
   failure.

2. **Re-gate the two R13 rung bundles on the fixed tool state**: cpu class, all 18 parts, controls and joint on, each
   with its pair as `--other`, the pinned printout, about 28 min each, run one after the other.

       bash /Users/victorrielly/IntelligenceRegulation/.claude/worktrees/fr25-fixes/results/zk60_gate_tinyllama_20261017/round27/fixes/regate.sh

   It runs, for `s` in s0, s1 (with `o` the other one):

       python3 /Users/victorrielly/IntelligenceRegulation/scripts/zk60_resource_guard.py run --class cpu --need-gib 24 --cap-gib 160 \
         --label fr25-regate-rung-$s --wait-secs 28800 --max-secs 43200 --log <fixes>/logs/regate-rung-$s.log \
         --done <fixes>/logs/regate-rung-$s.guard.done -- \
         env -u ZK60_NL_CHECK_DIR ZK60_D55TS_WORKERS=16 ZK60_S25_W2_PRINTOUT=/Users/victorrielly/zk60-artifacts/d60_20261102/s25_w2_printout_v2.log \
         <gatevenv>/bin/python3 -B <tree>/ops/zkp-mvp/gate-tinyllama/staging_v25/scripts/zk60_native_rg_d55.py \
         --bundle /Users/victorrielly/zk60-artifacts/d60_20261102/pg_bundles_r26/d55-r13_rung_h24-$s --evidence <fixes>/records \
         --name fr25-r13-rung-$s --other /Users/victorrielly/zk60-artifacts/d60_20261102/pg_bundles_r26/d55-r13_rung_h24-$o

   Expected for each record:
   * `status` D55-PASS;
   * `not_here` = [G_k], with `not_here_accepted` naming §3 Q5;
   * `controls_run` and `joint_run` true;
   * `PINS.pin_set.ok` (75 / 75);
   * `PINS.self_read_pending_independent_check` [];
   * the PINS controls B-1..B-3 and P-1..P-5 all fired, with `not_applicable` [];
   * HASH-2 `s25_printout.accepted` at `bac4bbd6`.

   Then run the coordinator's checker on the records:

       python3 /Users/victorrielly/IntelligenceRegulation/results/zk60_d60_20261102/privacy_gate_merged/check_records.py <fixes>/records

3. **The queue's twelve merged records** come from the pre-fix tool state. Apply the fixed rules to them, read-only:

       python3 -B <tree>/results/zk60_gate_tinyllama_20261017/round27/fixes/exp_restatus.py <tree>/ops/zkp-mvp/gate-tinyllama/staging_v25/scripts \
         /Users/victorrielly/IntelligenceRegulation/results/zk60_d60_20261102/privacy_gate_merged/records/*.json

   Run `check_records.py` on them too.
