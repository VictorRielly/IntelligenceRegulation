# Pass 5: Sol's package 361 against my pass 4 (package 295)

Reviewer: Claude (Sonnet 5.5), 2026-11-16. Package 361 (sha256 `5ce3e404…`, sealed 20:33Z; previous seal 343). Read-only on Sol's directory; no native build, run or proof by me. New helper: `results/zk60_claude_review_20261116/sol_d78_review_scripts_pass5/admission_probe.py` (stdout only). Labels: REPRODUCED, CHECKED, ARGUED, NOT VERIFIED. Later artefacts by name only, not reviewed: guard rows `sol-d78-census349-*` (21:00 to 21:19Z; its `-full` stage exited 1 after 798 s at 9.52 GiB), `d78-census-validation365`, `d78-correction-bundle368`.

## Verdict

361 is narrower than the story around it: it seals one thing, the native "ordinary-layout" admission, define and real matrix-fold run (stage 346) on the exact 301 binary, and it says so. Its claims rest only on stages that passed. Nothing in 361 presents the compact test geometry or the Shield/8B test profiles as qualification. No High finding.

## 1. Pins (REPRODUCED)

1,383 of 1,383 match; 0 missing; 0 symlinks. Both source trees (188 and 301) hash correctly (341 files each). The 161 pinned non-absolute `.py` files import no unpinned local module. Reviewer references are pinned as copies (pass 1, 2 and 3 hashes equal my files today; pass 4 is not listed, which is harmless). 35 pins are 0-byte logs. 130 pins are absolute paths: three `.rlib` files, `scripts/zk60_resource_guard.py`, one Lean merge log under `b2/`, and 125 git-tracked synthetic loader fixtures under `results/zk60_1b_native_20261017/r13/loader-fixtures/` (profile "rung-hd-t32-dev"; read by the native cache and context tests; they predate this work and are already in the repository).

## 2. What is new since 295, in groups (CHECKED unless marked)

- **296-298 (native private descriptors, batch 297):** native constructors (all 23 bodies from 282) emit private descriptors; 298 compares them with the independent Python derivation (243/249). A native-versus-Python comparison, not self-comparison.
- **299-305, 344-348 (full-crate admission):** 301 is a copy of the 188 crate with one 15,831-byte `#[cfg(test)]` module appended to `argument.rs` (REPRODUCED: the other 340 files are hash-identical; the appended module starts at the old end of file). It calls the real `Shape`, `Layout::for_shape`, `BlockPublic`, `AccuracyPublic`, `CheckedPublic`, `TrainedModelStatement`, `define` and `accuracy_fold`. 345 compares each native case with Python: draw stream replay, `derive_alignment` (263) against native gate shift, Boolean-channel fold columns, 6,176 expression checks per mode, plus 84 Python controls and 50 native-side refusals (counted, authored by native code; same pattern as 276). The 8 "cache/context units" are native self-tests with no Python side.
- **306-323, 329, 316, 322, 332 (compact token, test geometry):** preparation only. Source delta, Python predictions of preimages, schedule and public recipe (308, 310-312), a claims-semantics check against an analytic oracle (314) and a full replay module (319). The guard history has no compact-leaf row, so no native compact receipt existed at 361; 361 excludes it.
- **324-327 (M-functional rank, constructive minor):** exact finite-field rank diagnostic in Python; 361 does not claim a privacy gate.
- **328, 334-343, 347-353 (guard policy, recovery, census/validation bundles):** launch preparation and audits.
- **354-360 (larger-fixture identity):** Python preimage generator plus a 256 MiB BLAKE3 worker; prepared, not run (361 `larger_fixture_independent_identity_parity_qualified_by_this_seal: false`).

Self-comparison watch: Shield and 8B model identities are native observations only (361 says so; only the rung identity `49419d09…` has the independent 292 reconstruction). `d78_native_admission_io344.py:41` still sets `g["aligned"]={"product":{"shift":16}}` in the descriptor path, which only descriptors consume (the comment at 344:38-40 says so; 345 swaps in the 263 result before any expression is evaluated, `check_native_admission345.py:66-70`).

## 3. The native runs (guard history plus Sol's logs)

| Run | Outcome |
|---|---|
| 297 first attempt, 18:18:58Z | refused after waiting 7,200 s ("another heavy guarded job is live"); no compiler started (exit 70) |
| 297 recovery332 build, outer, scaled | all exit 0 (0.29, 0.24, 0.24 GiB; 16 to 20 s) |
| 303 build, 17:42Z | exit 0, 4.47 GiB, 193 s, cap 9.0 GiB |
| 303 outer, 19:06Z | **exit 1** after 11 s; the Python checker refused the native output |
| 303 scaled | never run (no guard row) |
| 346 outer, scaled, cache (reuse the 303 binary, no new compile) | all exit 0 (0.74, 0.74, 0.03 GiB; 14, 13, 11 s) |

Is it honest? 361 does not print "exit 1" but says "Original 303 actual mask row failure and 332 early stop retained" and gives the cause. The 297 refusal is described in 343, which 361 chains. `guarded_stages` mixes the 303 build with unprefixed "outer, scaled, cache" that are 346's runs (I matched the run IDs to `history.jsonl`); the scope text names 346. No 361 claim rests on a failed stage.

Cause of the 303 failure (REPRODUCED from saved data, `admission_probe.py`): the 301 driver uses `Layout::for_shape`, where the IO mask row defaults to `endpoint_rows - 5` for both ends (`layout.rs:1458`); real token stages override it with `with_io_mask_rows` (`token_io/run.rs:687`, `run.rs:980`). The saved native case passes the ordinary expectation, is refused with "native private descriptor fields" under the token-stage expectation, and the 14 controls all refuse at the same message. This is a legitimate source-based diagnosis, not fitting.

## 4. Test-only scaffolding

CHECKED: `TrainedModelStatement::new_synthetic_at_trained_profile_for_tests` and `W16_TEST_RUN_PROFILES` are `#[cfg(test)]` (`trained_statement.rs:735-736`, `private_block.rs:294-295`; `run.rs:342-348` says "W16 registers no run profile yet … absent from every production build"). The harness asserts that the production constructor refuses a synthetic source at the Shield and 8B profiles (`prepare_native_admission301.py:123`, "pinned"), so those two geometries run on test waivers and test run IDs (`-t/2`, `-tst/2`). Only the rung runs on a production constructor and the registered `-dev/1` profile (identity asserted equal to `49419d09…`). 361 labels the waivers and test IDs and does not claim larger-fixture parity. It also does not present the compact geometry (306, profile name ends "development-only"; Python adapters `d78_compact_profile309.py` and `d78_compact_token_adapter313.py` restore their registries in `finally`).

What non-test code would need: register the Shield W16R3 run profiles (and the 8B model-run profile) in `run.rs`; supply a real pinned `ModelSource` for those profiles; for the compact geometry, remove `cfg(test)` from the constant and the profile-to-shape branch (`diff` of 188 against 306: `run.rs:136-137, 317-321`; `token_io/run.rs:299-302`) and add the profile to `TOKEN_IO_RUN_PROFILES`.

## 5. Scratch re-run

One small probe (0.2 s, 46 MB, no native run) on the saved sanitized 346 cases: positive accepted; the same data against the token-stage IO row refused; 14 field and site controls refused at "native private descriptor fields"; metadata gate +1 refused at "all native constructor draw counts". An altered draw word is accepted by this descriptor check alone, because draw-stream equality is a separate check (`check_native_admission345.py:62`); I did not re-run that.

## 6. Wording against evidence

- "Actual API coverage includes Shape/Layout/… full original define/native folds": CHECKED, but only for `Layout::for_shape`; the token-stage layout (`with_io_mask_rows`, row 3) is never natively executed in 346. It is covered only on the saved rung receipt by the Python replay (294). 361 states the cause but not this coverage consequence.
- "50 native refusal executions": native-authored; 361 labels them separately from the 84 Python controls.
- Shield and 8B: native observations under test waivers; stated.
- `guarded_stages` labels (above): minor.
- No claim of compact proof, full suite, fresh verification or privacy; stated in `scope` and `remaining`.

## Limits that remain

External checkpoint authenticity; production registration of larger profiles; native execution of the token-stage IO layout; independent identity for Shield and 8B; the compact proof; 349 and later artefacts; cross-platform libm. NOT VERIFIED: the draw-stream replay in 345 (read, not re-run) and the 8 cache tests (native self-tests, not re-run).
