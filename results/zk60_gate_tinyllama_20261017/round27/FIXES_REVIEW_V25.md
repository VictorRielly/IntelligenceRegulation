# Gate round 27: review of the v25 freeze fixes (`fr25-fixes`, `ec12ffb2`)

Reviewer: Claude (Opus 5.5), 2026-11-02, read-only. I reviewed the code itself; the fixer's README was a guide only.
Nothing here is a privacy statement.

## Bottom line

**Freeze on `ec12ffb2` as is.**

The fixes asked for are closed: FR25-01 to FR25-06, FR25-11 and FR25-13. FR25-14's test half is done. Its
exit-code and record-overwrite half was left open, and that half is Info. I found no bypass, no new way to reach
D55-PASS and no new refusal of a genuine bundle. All 12 registered bundles still get PINS ok, with 75 of 75 pins and
every PINS control fired.

The new findings are Low or Info. One of them, FX-02, is a step to take before any D55-PASS record is used, not before
the freeze: record the G_k acceptance that `ACCEPTED_RESIDUALS` cites in the D60 row. Today the decisions register
does not have it.

## 1. What I checked, and how

* **The tree.** The fixer's worktree holds exactly `ec12ffb2`'s bytes for all 158 gate and fixes files
  (`experiments/fixes/cmp_wt.py`: 0 mismatches, nothing untracked). I read:
  * `git diff 4d906668 ec12ffb2` for the five scripts;
  * the fixed driver's PINS / status / `d55_gate` tail (`zk60_native_rg_d55.py:847-1225`);
  * the stubbed-driver tests and `exp_restatus.py`.
* **The cited constants**, recomputed independently:

  | constant | recomputed from | result |
  |---|---|---|
  | `REGISTERED_WRITER_PINS` | `OWN_SOURCE_FILES` and `SHARED_SOURCE_FILES` parsed out of `run_capture.rs` (sha256 `10b6d3be…`, blob `dd1195a2`), not with the fixer's `derive_pins.py` | equal, in order: 44 + 31 = 75 distinct |
  | the test-only extras | `w16_privacy_gate_tests.rs` | equal; as a set 76 |
  | `W16_READINGS` for `run.rs` / `run_capture.rs` | `git show efd2e515:…` piped to sha256 | `b9b40cad…44c6` / `d10d33e3…aee1`, equal |
  | the other seven W16 entries | the R26 full digests | equal |
  | `S25_W2_PRINTOUT_PIN` | the artifact `s25_w2_printout_v2.log`, and the committed `.gz` unpacked | both `bac4bbd6…dc53` |
  | `S25_W2_PRINTOUT_MADE_BY` | `git show 076a485f:…/s25_tests.rs` | sha256 `39b2e1c0…`; blob `5ab22020`, unchanged at `ec12ffb2` |
  | `R26_WIRING_CHECK_SHA256` | `READINGS_R26_WIRING_CHECK.md` | `3c3dae4a…`, as I hashed it in the first review |

* **Experiments.** Light, guarded, in-memory copies only; the fixer's modules were imported with `-B`, and no
  bytecode was written there. Logs are in `logs/`, scripts in `experiments/fixes/`:
  * `fixcheck.log`:
    * every D55 manifest under `zk60-artifacts/d60_20261102`;
    * the W16 readings;
    * pin-set bypass attempts;
    * `d55_status` probes;
    * `load_rust` refusals.
  * `stale.log`: a W16-era writer digest under the registered writer. Its lines 1-2 are a superseded first run that
    used the terminal port's raw `ok`; lines 3-4 follow the driver's logic.
  * `fixtests.log`: `test_fr25_fixes.py` alone, without bundles. 34 tests, OK, 3 skipped.
* **Not run:** the full v25 suite (cpu class, about 7 min), any gate run, and the fixer's `regate.sh`. The heavy lock
  is with the queue.

## 2. Verdict per finding

| finding | closed? | bypass? | new D55-PASS path or false refusal? |
|---|---|---|---|
| **FR25-01** HASH-2 without the Rust table | **Closed.** `load_rust` (`d55hash.py`) refuses unset, unreadable and wrong-digest printouts. `hash2_verdict` then sets HASH-2 false and adds a finding. HC-7 is always listed, with `fires: False` when no table is loaded. `fixcheck.log` F: unset, a missing file, a directory and an edited copy are each refused, with HASH-2 false; the genuine printout loads with 129 kinds for the rung profile. `OnABundle` covers it on a real bundle. | None found. The pin is a code constant, covered by `tool_sha256`. | No new PASS path. Running without the variable now makes a genuine bundle **NOT-OK**, not DEV-PASS: fail-closed, but labelled "some part is false" (FX-04, Info). |
| **FR25-02** the printout unpinned | **Closed.** The file is read once, its sha256 compared with the pin, and its table parsed from the very bytes hashed (`rust_table_of_bytes`, the same decoding as before). That removes the gap where the file could change between the hash and the parse. | None at the byte level. The pin binds the bytes, but not the Rust tree they describe (FX-03, Low). | None. |
| **FR25-03** `--no-joint` / `--no-controls` | **Closed.** `d55_status` caps either flag at D55-DEV-PASS and names the reason. `controls_run` and `joint_run` are written at the start of the record, the REFUSED return included. `fixcheck.log` E agrees, as does `StubbedDriver.test_no_controls_and_no_joint_are_capped`. | None: the flags are the run's own arguments, and the bundle cannot set them. | None. The cap keeps the status set closed, which I agree with. |
| **FR25-04** `not_here` ignored | **Closed.** D55-PASS now requires every `not_here` entry to be in `ACCEPTED_RESIDUALS`, which holds exactly the G_k line and cites "round 27 freeze review, §3 Q5". Any family other than R13 is capped (`W16_FAMILY_CAP`). Matching is exact: the G_k line with a trailing space comes out DEV-PASS, so the match fails closed. Removing a line from `not_here` still requires its part to have **run**, and a part that ran and failed is NOT-OK. | No bundle input reaches `not_here`; it is built from code. FX-02: the acceptance it cites is not yet in the decisions register. | No new PASS path. The FR25-13 relabel removes the self-read line only because the independent check exists. Pre-fix partial-lane records drop to DEV-PASS, which is intended. |
| **FR25-05** pin-list completeness | **Closed.** `pin_set_check` requires a known `writer` string and then exactly that writer's set: anything missing, unexpected or duplicated is refused. The sets are correct (§1). `fixcheck.log` B: the 12 registered bundles 75/75 ok; the old D60 bundles 73/75 refused (and backend UNKNOWN); the GPU-marked control 75/75 but backend refused. D: a trailing space in `writer`, `writer` absent, the test-only string over 75 pins, a `./` path variant, a duplicate replacing a pin, and an entry without `file` are all refused; reordering is accepted, which is correct. P-4 and P-5 fire on all 19 retained D55 manifests. | The set is checked **by file name only**. The writer file's own digest is not tied to the `run_capture.rs` `10b6d3be` the set was derived from (FX-01, Low). | No false refusal of a genuine bundle. The test-only writer's older W16 / W16R2 bundles (74 pins) are now refused, which is harmless while that family is capped. |
| **FR25-06** prefix readings | **Closed.** All nine W16 entries are 64-hex digests and are matched by equality (`w16.py`, `classify_pins`). The two W16-only digests equal the git blobs at `efd2e515`; the seven others equal R26's. `fixcheck.log` C: at each W16-only file, the full digest is read, while the prefix plus 52 zeros, and the full digest with its last hex changed, are both unread. P-3 fires on all 19 retained D55 manifests: it uses the bundle's own W16-read pin, or else writes `run.rs` at its W16 digest into the copy. | Not at 48 bits; full SHA-256 equality. The two stale W16-era digests still read for a D55 bundle (FX-01). | None. |
| **FR25-11** a control with no object counted as fired | **Closed for the controls named.** P-1 / P-2 with no object report `fires: None`. `_control_family_ok` needs no `False` and at least one `True` in each family (B-\*, P-\*); a family that is all not-applicable fails (test). TS-1F with no row reports `ok: None`, and a fidelity limit below 1 is refused (`ok: False`). `controls_ok` needs at least one applicable control and every applicable one true. The other families already followed the rule, or fail closed on `None`: J-C5 / J-C6 (`bool(applicable)`), N5-2 (`bool(live)`), and R13-3 (`all(fired)` is false on a `None`). | None found. | None. On every retained manifest, `not_applicable` is empty and every PINS control fires (`fixcheck.log` B). |
| **FR25-13** stale SELF_READ labels | **Closed.** The three entries name `WIRING_CHECKED` (the `748fe707` check, sha256 `3c3dae4a`, re-hashed by a test). Their scope is unchanged: the two Metal files stay CPU-path only, so a GPU-made bundle is still refused. The self-read list is empty on every bundle (`fixcheck.log` B). | None. A future SELF_READ entry still blocks PASS (`StubbedDriver.test_a_self_read_reading_is_owed_and_blocks_pass`). | Removes the self-read line from `not_here`, which is legitimate. Not a new path, because the check was done. |
| **FR25-14** status tests, exit code, overwrite | **Partly closed.** `d55_status` is now the only place the status is decided; the early REFUSED return is the one other place a status is set (`fixcheck.log` E). `Status.*` tests it directly, and `StubbedDriver.*` runs the real `d55_gate` with stubbed figure parts over each flag, family, pin list and false part. The module ran here with no bundle: 34 tests, 31 OK, the 3
bundle tests skipped (`fixtests.log`). **Open (Info, as the README says):** `main` still exits 0 for D55-DEV-PASS (`d55.py:1269`), and a record of the same name is still overwritten silently. | — | — |

## 3. New findings

| ID | severity | status | file:line | failure scenario → wrong verdict | suggested fix |
|---|---|---|---|---|---|
| FX-01 | Low | CONFIRMED | `d55.py:847-870`; `w16.py` `W16_READINGS` (`run.rs`, `run_capture.rs`) | The pin set is checked by name only. `stale.log`: a registered-writer manifest declaring `run_capture.rs` at its W16-era digest `d10d33e3…` (or `run.rs` at `b9b40cad…`) gets PINS ok. The file is "read" (the W16 reading, now at full digest), the 75 names match, and the terminal port does not pin either file. Neither file can write a registered D55 bundle: it has no D55 writer or registry. So only a manifest that misstates its digests produces this, which the gate cannot catch in general. But the expected set's own source, `run_capture.rs` `10b6d3be`, is not enforced. | For `REGISTERED_WRITER`, require the declared `run_capture.rs` digest to equal `RUN_CAPTURE_RS_READ`. Apply the two W16-era `run.rs` / `run_capture.rs` readings only to the one-block W16 gate, not to D55 bundles. |
| FX-02 | Low | CONFIRMED | `d55.py` `ACCEPTED_RESIDUALS`; `docs/zkmatrix-poc/ZK60_DECISIONS.md` at `ec12ffb2` | The one accepted residual cites "round 27 freeze review, §3 Q5 (to be recorded in the D60 row)". The register at `ec12ffb2` has no such record: 0 matches for "round 27" / "accepted residual". A reviewer's "accept as is" is a recommendation, not the owner's ruling. Yet D55-PASS now rests on that constant. | Record the acceptance in the D60 row (Victor's or the coordinator's ruling, the day it is made), and point the constant at the row. Do this before any D55-PASS record is used, for example before the `D55_REAL_CONTENT_PRIVACY_GATE_PASSED` flip. It need not block the freeze. |
| FX-03 | Low | PLAUSIBLE | `d55hash.py` `S25_W2_PRINTOUT_PIN`, `load_rust` | The pin binds the printout's bytes, not the Rust tree whose arithmetic they print. The gate's lookup checks only the kinds the gate itself measures. The prover-only kinds (the seed domains, the generator refill) are covered only by s25's own run on its tree (`076a485f`, whose pinned files equal today's bundles' pins). Suppose a later tree changes such a file, and it is re-read and admitted by a new reading, while the pin stays at the old printout. HASH-2 then passes on a census of the old tree. | Record in the gate the pinned-file digests at which the printout was made (the 75 files at `076a485f`), and make HASH-2 false (or DEV-PASS) when the bundle's pins differ. |
| FX-04 | Info | CONFIRMED (code) | `d55hash.py` `hash2_verdict`; `d55ts.py` `fidelity_control`; `d55.py` `d55_status` | A configuration error (printout unset or unpinned, or a TS fidelity limit below 1) makes a genuine bundle NOT-OK, and `status_means` reads "some part is false", the same text as a failed check. | Add a status reason naming the configuration error, or end the run as REFUSED before any figure is computed. |
| FX-05 | Info | CONFIRMED (code) | `d55hash.py` `load_rust` | The printout is opened with a plain `open`. A FIFO at that path hangs the run. Denial of service only; no verdict changes. | Use a no-follow, non-blocking open, as D60 F4 did in Rust, and refuse anything that is not a regular file. |
| FX-06 | Info | — | `d55.py` `not_here` / `ACCEPTED_RESIDUALS` | Residuals the gate never lists in `not_here` do not block D55-PASS, so they are accepted silently. They include S1–S5 on the 16 slots R13 does not redefine (FR25-17, carried by D58's argument), J-C5 without `--other` (FR25-12) and the unbound tail frame (FR25-08). G_k is listed and accepted by name, but the 16-slot carry, which rests on an equally argued acceptance, is not. | Name each residual a PASS relies on in `not_here` and in `ACCEPTED_RESIDUALS`, with its ruling (the 16-slot carry citing D58 and §3 Q5). Otherwise close it: require `--other` for a record. |

## 4. Still open from the first review (not in this brief; unchanged)

* FR25-07 (`ZK60_NL_CHECK_DIR` shadowing; the fixer's `regate.sh` unsets it).
* FR25-08 (the tail frame).
* FR25-09, half done: a known `writer` is now required, but the backend still comes from the capture process.
* FR25-10 (the r19b manifest pin).
* FR25-12 (J-C5's premise; `--other` not required).
* FR25-14's exit code and overwrite.
* FR25-15 to FR25-18.

None is Medium or higher.

## 5. On the records

* The fixer's `exp_restatus.py` calls the real `d55_status`. Under the fixed rules, the merged queue's finished
  `d55-mg-r13-rung-s0` stays D55-PASS: 18/18 parts, controls and joint rank on, printout pinned, pin set 75/75.
* It does not re-run the new PINS controls P-3 to P-5. My `fixcheck.log` B runs the fixed `pin_controls` on all 19
  retained D55 manifests: every control fires, and none is not applicable. So the pre-fix records' "PINS controls" verdict
  would hold under the fixed code.
* For freeze evidence bound to the fixed tool's hashes, the fixer's `regate.sh` (both rung bundles, each with its pair
  as `--other`, controls and joint rank on, the pinned printout, `ZK60_NL_CHECK_DIR` unset) is the right run. After
  the queue frees the lock, run it with the checks its README lists.
