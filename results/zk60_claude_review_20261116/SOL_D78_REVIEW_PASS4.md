# Pass 4: Sol's package 295 against my pass 3 (package 285)

Reviewer: Claude (Sonnet 5.5), 2026-11-16. Package 295 (sha256 `62f39605…`, sealed 16:12Z; chains 291, 293, 294). Read-only on Sol's directory. One new helper script: `results/zk60_claude_review_20261116/sol_d78_review_scripts_pass4/gate_probe.py` (prints to stdout only). Labels: REPRODUCED, CHECKED, ARGUED, NOT VERIFIED. Newer artefacts by name only: `d78-native-private297`, `d78-native-admission303` (guard rows at 17:42 and 18:18); not reviewed.

## Verdict

The gap claim is closed for the exact saved public synthetic fixture, and only for it. The verifier now builds the 4,575-byte model record and the 3,197,317-byte block preimage itself, hashes them, and compares the results with the identity and block digests carried in the receipt. A changed per-layer gate changes a derived value that is compared with the receipt, and the check refuses. Sol's scope text says "exact fixture" and keeps the external checkpoint open. No High finding.

## 1. Pins (REPRODUCED)

417 of 417 pins match; 0 missing. The 341 source files match. The 109 pinned non-absolute `.py` files import no unpinned local module. The only absolute pins left are the three `.rlib` files and `scripts/zk60_resource_guard.py`; reviewer files are now pinned as copies under `reviewer-authored-reference290/`, with recorded hashes equal to my files today (pass 1 `db6621fe…`, pass 3 `59933e85…`, pass 2 `cb4ed6cc…`). 31 pins hash to the empty string (0-byte rustc and stderr logs, as before).

## 2. The five pass-3 corrections

1. Header-binding limits restated: **made.** `D78_PASS3_REVIEW_CORRECTIONS_290.json` `header_limit` states that layout digests are not absorbed, per-layer common gate is absent from `stage_lines`, and "20 to 21 can preserve stage lines/schedule". 295 `new_evidence[2]` says layout hashes "remain unabsorbed capture annotations" and `remaining[2]` says "model identity/full schedule supply actual header binding" (CHECKED). It names source locations for the native identity path (`run.rs:416-422`, `private_block.rs:914-966`, `trained_statement.rs:920-975`).
2. Shared product shift 16: **made for the new harness, partly overall.** 290 `shared_input_correction` says 272 and 283 gave 16 to both sides. In the new 286/288 the native side calls original `derive_aligned_for` (`native_matrix_fold_source286.py:74-75`, asserting the derived gate shift equals the shape's) and the Python side takes `derive_alignment` from 263 (`check_native_matrix_folds288.py:119-122`); product shift is no longer supplied by the harness (CHECKED). Both sides apply the same normative literal (native `accuracy_aligned.rs:25-29`; Python `d78_alignment263.py:68`), which 290 and 295 `remaining[2]` state. The 288 grid shrinks to three registered axes with base calibration, gate 18, wrho 17 (`286:39-40`), whereas 283's 384 axes keep the old shared constant (historical). The guarded 287 run passed: 3 axes, 21 fold columns, 86,528 words, 3,088 expression checks, both B2 modes (`d78-native-fold287/*.qualification.json`, READ; I did not re-run it, since it opens its outputs in Sol's tree).
3. Activation records hand-transcribed: **made.** 290 `activation_record_correction`; 292 docstring ("The recipe is transcribed from frozen188 test code"); 295 `remaining[2]`.
4. 276's 20,480 refusals: **made.** 290 `native_B2_control_correction`: 10 controls times 2,048 runs, authored by native `compose_zero_batch`, "no new Python rejection coverage".
5. 260 unguarded at 1.47 GiB: **made.** `D78_HISTORICAL_RESOURCE_DISCLOSURE_289.json` lists 256 to 285 as unguarded and says "do not rerun". The new 287 batch ran under the guard in three rows (`history.jsonl`: build 0.27 GiB / 15 s, outer 0.44 GiB / 11 s, scaled 0.25 GiB / 11 s, cap 1.5 GiB). 295 records `resource_guard_used_this_milestone: false` for the new Python-only work (292-295 peaks 37 MB to 374 MB).

Also made: asserts (261, 269, 294 and 292 contain none; 290 `historical_asserts`); reviewer references as copies, `executed: false`.

## 3. The model-record gap

What 292-295 compute (CHECKED, `d78_fixture_identity292.py`, `probe_fixture_identity_integration294.py`):
- 292 rebuilds from the fixture calibration (11 integers) and activation record only; it imports no capture data. It streams the nine padded matrix and gamma byte sets (diagonal value 64) and regenerates EXP, RoPE, the legacy int8 ACT table and the two int12 ACT tables. It encodes AccuracyPublic (31,466 B), BlockPublic (3,197,317 B), the two layer records and the TrainedModelStatement, and hashes them with BLAKE3 (292:123-157, 160-231).
- `check_fixture_identity` (292:261-272) compares that derived identity and the two derived block digests with `public["model_identity"]` and `public["block_digests"]` from the receipt side and with `run["block_digests"]`. It is not a saved record compared with itself.
- 294 then feeds the same reconstructed calibration, base shifts, gate (derived from the activation record, no longer literal 18) and activation into schedule, definition, expression and public-table checks (294:55-57, 75, 93, 111, 142-143). The header chain is: transcript header, then calibration digest, then `model_identity`, which is now compared with the derived value.

Probe (REPRODUCED, `gate_probe.py`, 0.8 s, 261 MB): the derived identity `49419d09…3014` and derived block digest `2e66592e…8f32` equal the receipt's. Changing layer 1's per-layer accuracy-gate record by +1 (or layer 0 by +3) changes the identity and the check refuses at "source-derived fixture model identity" while the block-digest field is unchanged, because the per-layer gate lives in the model statement, not in BlockPublic. Altering the receipt-side identity is refused at the same check. At schedule level the pass-3 blind spot is unchanged (module 259 is unchanged); the new identity check covers it. The 33 controls in 293 all stop at that one message (the identity comparison), so the report does not distinguish field-specific reasons; each mutation is a record-level change, which is the intended scope ("encoding/binding, not acceptance of arbitrary changed model records").

Fail-closed note (ARGUED): the verifier uses one uniform calibration for both layers, so a real model with different per-layer constants is refused rather than accepted.

## 4. Product-shift point

See correction 2: for 286/288 the constructor comparison is no longer fed the same shift on both sides; the two derivations are independent code applying one normative literal. For 292/294 the shift (16) comes from `derive_alignment` and is bound by the block digest through the AccuracyPublic encoding. The 283 comparison itself is unchanged historical evidence.

## 5. Wording against evidence

The 295 scope and `fixture_model_binding` carry the qualifier ("Exact saved public fx_d78_rung recipe only", "does not authorize an external checkpoint, prove arbitrary model admission, or discharge the formal trusted-model premise"). Sol's coordination sentence also says "for the exact saved public synthetic fixture". Trusted inputs are still listed: the recipe constants (calibration set hash `0x06…`, quantizer hash `0x05…`, source labels, norm and shift integers), which are code, are correct only because the hash equality holds; `remaining[0]` lists external checkpoint authorization, model roots and generic layer-record admission, and states that the encoder covers untied, unscaled-RoPE records only. One overstatement risk: "independently encodes" is a hand-written encoder verified by reproducing the hashes; correctness of the encoding is shown by those matches, not separately.

## 6. High findings

None.

## Limits that remain

External checkpoint authenticity; generic record admission; the formal trusted-model premise; Python `math` libm determinism across platforms (a mismatch would fail closed; NOT VERIFIED); the 294 complete replay under `python -O` was not re-run by me (NOT VERIFIED here; passes 2 and 3 did reproduce 269 under `-O`); `native` private-descriptor and full-admission work in 297/303 not reviewed.
