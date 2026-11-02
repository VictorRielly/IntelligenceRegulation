# Gate round 26 wired: the D60 privacy gate re-run with every moved pin read, and F-B1 closed (2026-11-02)

The previous record (`../privacy_gate/README.md`) ran the Python D55 gate on four registered R13 fork bundles. Every
figure passed, but every record was **D55-DEV-PASS**, because 23 moved source pins had not been read. Two readers have
since read every moved pin, r19b → HEAD, and found them safe (`results/zk60_gate_tinyllama_20261017/round26/`). This
directory:

* wires their readings into the v25 staging gate;
* closes the block reader's finding F-B1 (the Metal backend was not pinned), in test code only;
* re-writes fresh registered bundles with the new code;
* re-runs every gate on them.

Privacy requirement P1 (`ZK60_PRIVACY_REQUIREMENTS.md`) is not reopened.

**Verdict: the four fresh records are D55-PASS.** That is the R13 rung and the 8B T128 geometry, at two hidden inputs
each. Every part is true. Every one of the 75 pins is either at r19b or read at its full digest. The prover backend
is admissible (CPU-made). Every control fires. The GPU-refusal control and the old D60 bundle are both refused, as
designed.

What this is not:

* **Not a privacy acceptance, a registration or a statement.** D55-PASS means "every part computed true, and the
  code that made the bundle is read". Owed items remain (section 7).
* **Three of the 34 readings are SELF-READ.** These are `run_capture.rs` after this round's change, and the two
  Metal files at the CPU-path scope (`round26/READINGS_R26_WIRING.json`). Every record names them. They are owed an
  independent check at the v25 freeze review.
* **Not real content.** The bundles are test-only and synthetic, as before.
* v25 is NOT frozen and no v24 file was edited. No production (non-test) Rust file changed.
  `run_fork::D55_REAL_CONTENT_PRIVACY_GATE_PASSED` is untouched.

## 1. What was wired

**The readings table.** File `staging_v25/scripts/zk60_native_rg_r26readings.py` (new), as `R26_READINGS`, in the
`*_READINGS` style.

* Each entry is keyed by `(file, the digest's first 12 hex)`.
* Each entry carries:
  * the FULL SHA-256 the reading names;
  * its scope (`full` or `cpu-path`);
  * who read it;
  * a one-line summary;
  * a pointer to the record (`round26/READINGS_R26_{RUN,BLOCK,WIRING}.json`, `readings['<file>']`).
* There are 42 entries:
  * 17 from the run-level reader. These include the dd81ab4f digests that the four old D60 bundles carry for
    `run.rs`, `run_capture.rs`, `trained_block.rs`, `run_fork.rs` and `run_fork_wire.rs`.
  * 22 from the block-level reader. These include `shape.rs` at the W16R2 re-check bundles' `3b78b725`.
  * 3 SELF-READ entries from this round (section 2).
* The test `test_r26_readings.R26Table` checks the table against both readers' JSON tables. Every reader entry must
  be wired at the full digest that its `readings` names, and nothing else may be wired.

**`classify_pins`** (`zk60_native_rg_w16.py`) now classifies each pin in this order:

1. At the r19b digest: at r19b, as before.
2. Else an R26 reading whose full digest EQUALS the pin's: read. A `cpu-path` reading counts only when the
   manifest says `proved_on_gpu: false`.
3. Else a W16 reading, as before, by its 12-hex prefix. **Strengthened:** if round 26 re-read that (file, prefix),
   only the full digest reads it, so a prefix twin stays UNREAD.
4. Else UNREAD.

Nothing was weakened:

* An unknown digest is UNREAD.
* A 48-bit prefix alone never reads a pin. Controls P-1 and P-2 below, and three unit tests, check this.

The record now also carries:

* `readings_r26` (per pin: the reading, its scope and reader, and the pointer);
* `self_read_pending_independent_check`;
* `backend` (section 2);
* `at_r19b_files`.

**The D55 driver** (`zk60_native_rg_d55.py`) changes in three ways:

* **D55-PASS is reachable.** It needs every part true, `PINS.ok`, and an admissible backend.
* **The R13 terminal port's own pin check is still reported, not applied.** But every pin it refuses must now be
  read by the classification (`PINS.terminal_port_refusals`): `layout.rs`, `protocol.rs`, `plane_index.rs`,
  `shape.rs` and `pad.rs`, all read by the block or run reader.
* **A new part, `PINS controls`,** runs on doctored copies of the manifest, with the bundle's files untouched:
  * **B-1:** the manifest marked `proved_on_gpu: true`. The bundle is refused, and the Metal pins become UNREAD.
  * **B-2:** the field removed. The bundle is refused as UNKNOWN.
  * **B-3:** the field set to the string `"false"`. The bundle is refused.
  * **P-1:** one R26-read pin (zkp-core `merkle.rs`, which is also in W16_READINGS) given the same 12-hex prefix and
    a different tail. The pin is UNREAD.
  * **P-2:** the same pin at an unknown digest. The pin is UNREAD.

**Text fixes.**

* **F-B4:** `W16_READINGS['src/gpu/mod.rs']`'s stat now reads "+106 / -5 in 5 hunks".
* The status texts and docstrings in `zk60_native_rg_d55.py`, `zk60_native_rg_d55r13.py` and
  `zk60_native_rg_w16.py` were updated.
* No v24 module was edited.

## 2. F-B1: the design (test code only)

**The Rust side.** All of it is in the test-only module `run_capture.rs`, plus two test files:

* `src/gpu/metal.rs` and `src/gpu/metal_kernels.metal` are appended to `SHARED_SOURCE_FILES` (29 → 31). A bundle now
  has 75 pins.
* The M26 comment (`run_capture.rs:306-315` at HEAD) said a Metal-built bundle is "tied to" its Metal sources
  through `slot_ir*.rs` and `metal_slot.rs`. That overstated the coverage. It now says those three files tie a bundle
  only to the IR and its kernel codegen, not to the backend that runs the kernels and computes the commitments.
* Both manifest writers (the registered-D55 fork writer and the generic `write_bundle`) record
  `"proved_on_gpu": <bool>`.
  * The value is `crate::gpu::enabled()`, the switch every device path is gated on: the Metal commit seam
    (`gpu/mod.rs:774/786/798`), the slot IR (`argument.rs:2636`) and `trained_block.rs:2600`.
  * The value is read in the proving process.
* The key is on `ALLOWED_KEYS`.
* `s24_tests.rs` (d3) asserts that both files are pinned and that the writers record the field.
* `run_fork_tests.rs` (the ordinary D60 writer test) asserts both pins once each, and `proved_on_gpu =
  gpu::enabled()`.
* `git diff 6d06b8b0 -- '*.rs'` touches only `run_capture.rs`, `s24_tests.rs` and `run_fork_tests.rs`.

**The gate rule** (`zk60_native_rg_r26readings.gpu_backend`):

| manifest | verdict |
|---|---|
| no `proved_on_gpu` (every bundle written before this fix) | **REFUSED, backend UNKNOWN** |
| `proved_on_gpu: true` | **REFUSED** while either Metal file is unpinned or has no FULL reading at its digest. None exists: F-B1 read only the privacy-relevant device paths |
| `proved_on_gpu: false` | admissible; the Metal pins need at least the CPU-path reading |
| any non-boolean value | REFUSED |

A refused backend makes `PINS.ok` false. The record then stays D55-DEV-PASS at best, exactly as an UNREAD pin
does, and it says why (`backend_refused`). The figures are still computed: the gate does not stop early.

**The reading of our own diff.** The change moves `run_capture.rs` from `cbb78dc0` (the run-level reader's HEAD) to
`10b6d3be`. That diff is read in `round26/READINGS_R26_WIRING.json` (with its `.md`, `readings_wiring.py` and
`readings_wiring/*.diff`), in the readers' schema:

* 6 hunks, +20 / -5. 4 are privacy-relevant and argued with line numbers; 1 is an array length; 1 is a comment.
* No transcript, frame, stage, tail or `run.json` byte moves.
* The new field states only how the prover ran. The README's note already said so (`gpu::label()`).

The same file reads the two Metal files at the **CPU-path scope**. When `gpu::enabled()` is false:

* `metal.rs` is reached only through `enabled()` and `label()`. Both return before `ctx()` unless `HL_GPU=1`.
* Every device entry is gated by `gpu::enabled()` at its caller.
* `metal_kernels.metal` is compiled only inside `ctx()`.

All of it is marked SELF-READ, owed an independent check at the v25 freeze review.

## 3. The bundles

The bundles were re-written with the new code on the CPU. The procedure is exactly the previous record's
(`logs/write.cmd`, `run.sh`):

* the ignored test `run_fork::tests::d60_privacy_gate_write_registered_r13_fork_bundles`;
* binary `8f18469b…` (`logs/build1.log`: gpu-metal test build plus the no-feature check);
* `HL_TEST_SOURCE_COMMIT=23199feb` (the code commit);
* `HL_GPU` unset;
* guarded cpu class, 34 s, peak RSS 21.0 GiB (`logs/write.log`).

They are outside the repository, in `/Users/victorrielly/zk60-artifacts/d60_20261102/pg_bundles_r26/` (marked
`TEST_BUNDLES_NOT_FOR_PUBLICATION.txt`). Their manifests and READMEs are in `bundle_manifests/`
(`MANIFEST_SHA256.txt`).

| bundle | run profile (registered D55) | hidden input | size | manifest |
|---|---|---|---:|---|
| `d55-r13_rung_h24-s0` | `…/private-run-rung-lh-t32-dev/1` | the fixture's public sequence | 107 MB | `proved_on_gpu: false`, 75 pins |
| `d55-r13_rung_h24-s1` | the same | rotated by 5, nudged | 107 MB | the same |
| `d55-r13_8b_t128_h24-s0` | `…/private-run-llama-3-8b-t128-lh24-v1-statement/1` | M10's family at s = 0 | 303 MB | the same |
| `d55-r13_8b_t128_h24-s1` | the same | s = 7 | 303 MB | the same |

**The Rust bundle checks**, on each bundle read back from disk, in the same test (`logs/write.log`):

* every bundle: REG, PG-7, PG-8 per fork, PG-10 per fork and tail, and C-2 / C-5 / C-6 fire;
* **12 checks, all PASS**;
* `D60-PG-RUST VERDICT 4 bundles, every check PASS and every control fired`.

Figures:

* PG-7 covers 56,803 fields (rung) and 137,567 fields (8B).
* PG-8 finds 148 A and 54 H claims per fork (rung), and 146 A and 53 H (8B).
* PG-10 compares 18,845 / 45,621 keys per fork, with tails of 4,526 / 4,898 keys.

These are the previous record's figures.

## 4. Per-bundle verdicts

Every Python run was made by `pygate_all.sh` (detached; `logs/pygate_all.done` = 0), on one tool state:

* `zk60_native_rg_d55.py` `c14690f2…`
* `zk60_native_rg_d55r13.py` `927cb408…`
* `zk60_native_rg_d55joint.py` `3fc784d6…` (unchanged)
* `zk60_native_rg_w16.py` `96342f8a…`
* `zk60_native_rg_r26readings.py` `e601e955…`

That is commit 61555926; `tool_sha256` is in every record. Each run was guarded (cpu class). Its log is
`logs/<tag>.log` and its record `records/d55-<tag>.json`. `summarize.py` prints the figures (`logs/summarize.out`)
and `aggregate.py` the totals (`logs/aggregate.out`).

| record | status | pins: at r19b / read (independent + self-read) / UNREAD | backend | R13-3 G per fork, slots | replay challenges / failures | wall / peak |
|---|---|---|---|---|---|---|
| `py-r13-rung-s0` | **D55-PASS** | 75: 41 / 34 (31 + 3) / 0 | CPU, admissible | 20 / 21 / 20, 23 of 23 | 4,934 / 0 | 97 s / 0.59 GB |
| `py-r13-rung-s1` | **D55-PASS** | 75: 41 / 34 (31 + 3) / 0 | CPU, admissible | 20 / 21 / 20, 23 of 23 | 4,934 / 0 | 97 s / 0.56 GB |
| `py-r13-8b-s0` | **D55-PASS** | 75: 41 / 34 (31 + 3) / 0 | CPU, admissible | 19 / 19 / 19, 23 of 23 | 30,339 / 0 | 378 s / 2.0 GB |
| `py-r13-8b-s1` | **D55-PASS** | 75: 41 / 34 (31 + 3) / 0 | CPU, admissible | 19 / 19 / 19, 23 of 23 | 30,339 / 0 | 375 s / 1.7 GB |
| `py-ctl-marked-gpu` (control) | D55-DEV-PASS, **refused** | 75: 41 / 32 / 2 (`metal.rs`, `metal_kernels.metal`: CPU-path only) | `proved_on_gpu: true`: GPU-MADE, refused | as rung s0 | 4,934 / 0 | 97 s |
| `py-old-d60-rung-s0` (old D60 bundle) | D55-DEV-PASS, **refused** | 73: 43 / 30 / **0** | no field: UNKNOWN, refused | as before | 4,934 / 0 | 97 s |
| `py-w16-rung-s0` / `-s1` (regression) | D55-DEV-PASS | 74: 45 / 23 / 6 | no field: UNKNOWN | (W16: T-0 owed) | 4,247 / 0 | 81 s |
| `py-w16r2-rung-s0` / `-s1` (regression) | D55-DEV-PASS | 74: 45 / 23 / 6 | no field: UNKNOWN | (W16: T-0 owed) | 4,247 / 0 | 80 s |

**The four fresh records: every part is true, and all match the previous record's figures.** The parts are D55-0,
D55-1/2, D55-3, R13-H, R13-2, R13-3, R13-6, R13-7, D55-IO, D55-J, D55-C and PINS controls.

* **The registered header** recomputes: the parameter line byte for byte, the schedule digest from its lines, and
  `run_binding`, S0, S1 and the tail's end tag by the replay.
* **The per-commitment ranks:** 40 regular commitments ranked. Every disclosed dimension equals its expectation (28
  at 0, and the 12 H at 2). Every certifying minor has full rank, every reduction hypothesis holds, and the 12 M are
  at 0. The pad margins are 0 (24), 1 (13), 2 (2) and 3 (1). The B0 pad block's exact rank equals its distinct
  columns (255 or 256).
* **Mask / CFS:** 48,375 (rung) and 49,122 (8B) entries recomputed, 0 differing, 768 salted leaves.
* **D55-IO:** 6 claims derived per record.
* **D55-J, the run-level joint rank:**
  * every boundary: reserved rank 6 / 6, disclosed 0;
  * the three roles `A_k, B_k, A_{k+1}`: parts 0 + 0 + 0, joint **0**, block-diagonal (2 identified rows at the
    rung, 64 at 8B);
  * the whole run: 308 × 2,225 (rung) and 308 × 27,009 (8B), joint 6 = sum 6;
  * the adjacent pairs: 4 = 4;
  * J-C3 makes the joint 16,384.

**Pins.**

* All 34 moved pins are read: 21 by the block reader, 10 by the run reader, and 3 self-read (`run_capture.rs`
  `10b6d3be`; `metal.rs` `a96882bc` and `metal_kernels.metal` `be968236` at the CPU-path scope).
* No W16 prefix reading was needed: R26 covers all seven at their full digests.
* The terminal port's 5 refused pins are all read.

**The regressions.**

* The W16 / W16R2 test-only D55 bundles' figures are unchanged (4,247 challenges, joint 6 = 6, 48,375 mask
  entries).
* Their pins go from 7 read / 22 unread (previous record) to 23 read / 6 unread. The 6 left are their test-only
  tree's `run_capture.rs c0492fc2`, `run.rs b21024bf`, `wire.rs cdf122c1`, `run_fork.rs b6963201`,
  `run_fork_wire.rs 0c6ef9e7` and `w16_privacy_gate_tests.rs f305ceec`, which no reader read. Their backend is
  UNKNOWN (the test-only W16 writer does not record the field: note N-R26-W1).
* So they stay DEV-PASS, as they must.

## 5. The controls

* **The GPU-refusal control: a bundle marked GPU-made is refused.**
  * The bundle is `pg_bundles_r26_controls/d55-r13_rung_h24-s0-marked-gpu`: an APFS clone of the fresh rung s0
    bundle with only `"proved_on_gpu":false` changed to `true` in its manifest. The manifest does not list itself,
    so D55-0 still passes, and every part computes true.
  * PINS refuses it: "GPU-MADE BUNDLE (proved_on_gpu = true), and the Metal backend is not admissible (no FULL
    reading at the pinned digest: src/gpu/metal.rs, src/gpu/metal_kernels.metal) …".
  * The two Metal pins classify UNREAD ("only a CPU-PATH reading (F-B1) exists at this digest …").
  * Status: **D55-DEV-PASS**, `backend_refused` set (`logs/py-ctl-marked-gpu.log`).
* **The backend-unknown control on a real bundle.** The old D60 rung s0 bundle (`pg_bundles/`, written at
  dd81ab4f without the field):
  * **every one of its 30 moved pins is now read**, at the dd81ab4f digests for the five files and at HEAD for the
    rest;
  * it is refused as UNKNOWN; status D55-DEV-PASS (`logs/py-old-d60-rung-s0.log`);
  * all four old D60 bundles classify the same way: 73 pins, 43 at r19b, 30 read, 0 unread, backend UNKNOWN, refused
    (`classify_manifests.py` on their manifest copies, `logs/classify_manifests.out`; and
    `test_r26_readings.R26OldD60Bundle`). Wiring the readings alone would have made them PASS; F-B1's rule is what
    keeps them out, because nothing records how they were proved. Their bundle READMEs do say "gpu: off", but that is
    free text, not a field.
* **The PINS controls B-1 / B-2 / B-3 / P-1 / P-2** fire in all 10 records.
* **Every other control fired in all four fresh records:**
  * R13-H's three;
  * the R13 block port's 7 (8 at the rung, with R13-G2);
  * D55-IO's;
  * J-C1 .. J-C6;
  * the exclusivity and the six mask controls;
  * D55-C's two.
  * In all, 106 control verdicts, every one "fires" (`logs/aggregate.out`).

## 6. The floors before the commit

`final_gates.sh` ran detached (`logs/final_gates.done` = 0) on the final code. It used the binary `8f18469b…`
(`logs/binary.sha256`, `logs/build1.log`), built from the Rust of 23199feb; no Rust file changed after it. The Python
suite was re-run alone (`suite.sh`, `logs/suite_v25b.log`) after one stale test expectation was corrected (see the
last row).

| step | result | log |
|---|---|---|
| gpu-metal test build + no-feature `cargo check --release --lib --tests` | ok, both `Finished`; **133 warnings**, the D60 baseline by the same count method (≤ 133) | `build1.log` |
| scans `r19b s24 s25 absorb s33 hash_domain::` | **58 / 58**, including s24's `the_capture_writer_pins_every_run_layer_source_it_depends_on` with the new (d3) F-B1 assertions | `scans_final.log` (and `scans.log` before the bundles) |
| `run_capture.rs` pins and allow-list: `the_bundle_pins_every_source_file_that_decides_its_contents`, `every_key_of_a_bundle_is_on_the_allow_list`, the s24 partition | **3 / 3** | `capture_final.log` |
| dev bytes gate (`HL_GPU_REQUIRED=1 HL_METAL_TIMING=0`) | **01fa1b2e / 992034f8 / 371e6b00 / 3ab090df**, CPU = Metal for all four | `devbytes.log` |
| D55 / D60 set `private_block::run::fork::` (CPU, one thread) | **23 passed, 0 failed, 7 ignored**. The D60 writer test asserts both Metal pins and `proved_on_gpu`, and runs the Rust gate on its bundle: `7 checks, all PASS` | `d55_cpu.log` |
| `private_block::w16_privacy_gate_tests::` | **4 passed, 0 failed, 5 ignored** (the ignored are the bundle writers and the Rust D60 checks, run in `write.log`) | `w16pg.log` |
| W16 / W16R2 one-block gate regressions (`zk60_native_rg_w16.py`) | both W16-DEV-PASS, all 7 parts true. Pins went from 7 read / 19 unread (the privacy re-check) to 23 read / 3 unread (that tree's `run_capture.rs`, `run.rs`, `wire.rs`). The backend is UNKNOWN; the v24 tables still refuse | `py-w16blk-*.log`, `records/w16-blk-*.json` |
| staging_v25 Python suite, with the W16 rung, W16R2 rung, W16 D55 bundle, fresh registered R13 pair and old D60 bundle named | **150 tests: 78 ok, 71 skipped, 1 failure**. The failure is the pre-existing `test_r19b_self_check_and_its_control`, which needs the r16b..r19b CLI binaries left on the laptop (the D60 record and round 25 record the same). Every D55 R13 (8), R26 (11) and W16 (20) test ran and passed. The first run (`suite_v25.log`) had one more failure: `test_w16_gate`'s stale expectation that a pinned `range16.rs` is UNREAD. The block reader read it, so the test now expects it read at `62061f62` and UNREAD at any other digest | `suite_v25b.log` (`suite_v25.log` first) |

## 7. Owed before a v25 freeze

Covered by this round:

* the reading of every moved pin at the registered R13 bases' capture tree;
* F-B1's capture half (pins plus the manifest field);
* F-B1's gate half (refusing GPU-made and backend-unknown bundles);
* F-B4.

Still owed:

* **T-0 and NL-1 on the W16 slots.**
  * The seven W16-redefined slots (SC_LZC 3, SC_DZC 14, SC_QZC 15, SC_KVZC 16, SC_SZC 17, SC_FZC 18, SC_TAB 19) have
    no Python terminal port.
  * NL-1 (S1–S5) is ported to neither W16 nor R13 at D55. The R13 records list it under `not_here`.
* **TS-1 and the claim census:** not run on any D55 capture.
* **The Python hash census:** no Python census reads a D55 bundle. Only the Rust s25 W-2 census measures the
  registered profiles.
* **The full zero-data preimage:** A and H at MSG != PAD, both halves, every opened column and the salted leaves.
  Not run on a D55 capture.
* **The TinyLlama T128 LOW and Shieldstral T128 / T256 registered bases:**
  * They share the same R13 code path but have not been captured.
  * Shieldstral is the first base with per-layer own calibration clauses. That path is untested on real data.
  * The four R13 DD bases are refused by name (SC_DD is not ported).
* **The v25 freeze review**, which must include:
  * the independent check of the three SELF-READ readings (`READINGS_R26_WIRING.json`);
  * the review of this round's gate code.
* **Also open:**
  * G_k is recovered on SC_FZC, not read from a bound line.
  * Two header words are taken as bound bytes (the public-statement and calibration digests).
  * A full reading of the Metal device paths is needed before any GPU-made bundle can be admitted.
  * The test-only W16 fork writer does not record `proved_on_gpu` (N-R26-W1).
  * F-B2 and F-B3 are production text, not changed here.
  * No real trained weights are on this host.

v25 is not frozen; v24 is untouched.

## 8. Files

Commits (worktree branch `worktree-agent-ad2863f50f3102344`, on `perf/zk-batch-optimizations` at `6d06b8b0`):

* `23199feb`: the code. The Rust test-code F-B1 fix and the R26 wiring.
* `61555926`: the PINS controls and the W16 prefix strengthening.
* The records commit that adds this directory, `round26/READINGS_R26_WIRING.*` and the new test file.

The files here:

* Records: `records/` (10 D55 records plus 2 W16 one-block regressions), `bundle_manifests/`.
* Logs: `logs/`.
* Scripts: `build.sh`, `run.sh`, `pygate.sh`, `pygate_all.sh`, `final_gates.sh`, `suite.sh`, `detach.py`,
  `summarize.py`, `aggregate.py`, `classify_manifests.py`.
* The control bundle: `/Users/victorrielly/zk60-artifacts/d60_20261102/pg_bundles_r26_controls/` (marked
  `CONTROL_BUNDLE_NOT_A_CAPTURE.txt`); its manifest is in `bundle_manifests/control-*`.
* Code:
  * `staging_v25/scripts/zk60_native_rg_r26readings.py` (new);
  * `zk60_native_rg_w16.py` (`classify_pins`, F-B4);
  * `zk60_native_rg_d55.py` (status, terminal-port cross-check, PINS controls);
  * `zk60_native_rg_d55r13.py` (texts);
  * `staging_v25/tests/test_r26_readings.py` (new, 11 tests), and `test_w16_gate.py` (one expectation updated);
  * `hashline/src/private_block/run_capture.rs`, `s24_tests.rs`, `run_fork_tests.rs`.
* The readings: `results/zk60_gate_tinyllama_20261017/round26/READINGS_R26_WIRING.{json,md}`, `readings_wiring.py`
  and `readings_wiring/wiring-head-r26w-run_capture.rs.diff`.

To repeat, run in order:

1. `build.sh full build1`
2. `run.sh write cpu 24 96 HL_D60PG_CAPTURE_DIR=<dir> HL_D60PG_CASES=R13_RUNG_H24:0,R13_RUNG_H24:1,R13_8B_T128_H24:0,R13_8B_T128_H24:1 HL_TEST_SOURCE_COMMIT=<commit> -- --ignored --exact --nocapture --test-threads=1 private_block::run::fork::tests::d60_privacy_gate_write_registered_r13_fork_bundles`
3. Clone the control bundle and flip its one manifest field.
4. `pygate_all.sh`
5. `final_gates.sh`
