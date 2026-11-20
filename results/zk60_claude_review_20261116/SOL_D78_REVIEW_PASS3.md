# Third cross-review: Sol's D78 package 285 (chains 262, 270, 277)

Reviewer: Claude (Sonnet 5.5), 2026-11-16. Read-only on Sol's directory. I did not edit `SOL_D78_REVIEW_212_222.md`, `SOL_D78_REVIEW_229_LATEST.md` or `sol_d78_review_scripts/`. Kept scripts are in the scratchpad `.../sol-review/`: `sched_check.py`, `ctl284.py`, `extract_check.py`, plus `rerun269/`. CONFIRMED = I ran or computed it; READ = code or reports only. A newer package (287, `d78-native-fold287`, one guarded build row at 11:44 in `history.jsonl`) exists; I did not review it.

## Verdict

Package 285 is supported with corrections, for its stated scope (public native constructor component qualification plus the unchanged 269 saved-receipt replay). The pins, the 269 replay under `python -O`, the schedule derivation and the native-versus-Python comparisons all reproduce. The corrections are disclosure: the specifics of what the header does not bind are scattered across older reports and not restated in 285, and one constant is shared by the native harness and the Python side.

## Findings

No High findings.

**Medium**

1. What the header does not bind is not restated in 285 (CONFIRMED). The native header absorbs `parameters`, `calibration` (= BLAKE3 of the opaque `model_identity` and the token profile digest, `token_io/run.rs:416-422`), `schedule` and the block digests (`run.rs:541-546`, `:957`). `layout_digest` is only a struct field (`run_capture.rs:906,1517`) and is never absorbed. Per-layer gate-common is not in `stage_lines` (native `OWN_FIELDS` has sh_g, not the common denominator). I changed the per-layer gate-common from 20 to 21 (structure-preserving): schedule digest and stage lines are identical, only the layout-digest annotation differs (`sched_check.py`). So an altered per-layer gate or activation record is invisible to header binding. It is detected only because the replay uses literal `gate_shift=18` for every layer (`probe_aligned_source_integration269.py:123-124`; `stage_gates` only feeds the rendered text, `d78_schedule256.py:132-136`), and because it would then disagree with the capture. The verifier proves consistency with the supplied record, not that the record equals what `model_identity` and `block_digests` commit to. 285 `remaining` bullets 1 and 3 state the second half. The `layout_digest` fact is only in the 259 docstring, the 260 scope and the 269 scope, not in 285 (partly).
2. A shared constant makes one native comparison weaker than it reads (CONFIRMED). The native harness hard-codes `folds: Folded{shift:16}` and ids `i%2` (`native_all_constructor_source282.py:71`). The Python side sets `g["aligned"]={"product":{"shift":16}}` (`probe_all_constructors283.py`, `derive_case`). If the true product shift were different, both sides would still agree. 265 qualifies the alignment derivation separately (1,977 native cases), so the link is by composition only. 272's scope names a "product16 input facade"; 283 and 285 do not.
3. "Derived from explicit activation records" is partly a relabelling (CONFIRMED). The records come from `public_fixture_activation` (`d78_alignment263.py:98-102`), a hand-transcribed copy of `range16_tests::case(…,2)`. The derived values equal the old literals by value (product shift 16; gate multiplier doubled for even channels; gate shift 18). The path is exercised and mutating a record changes results (269 controls refuse at `fold:g`), but one literal remains by stack name: `263:68` returns 16 for any non-"Low" stack. This is disclosed as hand-transcribed.

**Low**

4. 276's "20,480 named refusals" are the native code's own refusals recorded by 275 (2,048 per control, one per shape-mode case; 276 says "no native rerun"). They show native validation clauses, not Python checks. The count overstates the number of distinct controls.
5. 260 peaked at 1,581,400,064 B (1.47 GiB), unguarded, 14.1 s. It is under the 1.5 GiB rule by 2%, and the figure is a parent-plus-child upper bound.
6. 285 pins my pass-1 report and two scripts by absolute path, which stay mutable; only the pass-2 report is captured as a copy. Not a technical defect.
7. `assert` still sits at `probe_source_definition_integration254.py:141,149`; 261 and 269 have none (CONFIRMED).

## 1. Pins (CONFIRMED)

347 of 347 match, 0 missing, 0 symlinks. The 341 source files match. The 97 pinned non-absolute `.py` import no unpinned local module. Reviewer references: the pass-2 copy `reviewer-authored-reference262/SOL_D78_REVIEW_229_PASS2.md` has hash `cb4ed6cc…`, identical to the original as it stands now; the pass-1 report hash `db6621fe…` also matches. 31 pins hash to the empty string (0-byte rustc and stderr logs of the small harnesses).

## 2. Pass-2 corrections

- LowH24 qualifier: **yes.** `probe_source_schedule_integration261.py:4`, the 269 scope ("LowH24 noncompact public synthetic rung with pinned public fixture parameters") and 285's "Previous 269 remains the complete saved LowH24 noncompact … replay". The 285 top sentence itself carries "public native constructor component".
- `require` instead of `assert`: **yes.** No `assert` in 261/269 or `d78_capture_chain234.py`. I re-ran 269 under `python3 -O` from a scratch copy: it passes (section 7).
- "Hand-transcribed" and the two numbers kept distinct: **yes.** 269 scope: "1975296 capture cells match; 10496 quantizer words are native-compared in 268 against pinned 253 output … Parameters remain hand-transcribed"; 285 `review_corrections` bullet 6.
- Reviewer files as references only: **yes.** 285 `reviewer_authored_references` and `reviewer_scripts_counted_as_sol_independent_evidence: false`; 262 records `reviewer_scripts_executed_by_this_package: false`.

## 3. Schedule and header derivation (256-261)

Computed, not taken from the capture (CONFIRMED): `d78_schedule256.py:114-142` renders the parameter line, block and token layout text, stage lines and the BLAKE3 digest from `fixture_calibration()` (11 integers, hard-coded at 256:24-25), the literal gate 18 (261:55), the registered profile tables, and `run["shape"]` and `run["token_io"]` (capture fields, already checked against the registered profile). `shape["norm_wrho"]` and `["wrho_s"]` from the capture are consistency-checked against derived values (256:119-121). My run derives `5c5f546b180b459a60bdc3e992943faf298e411de7d0cc5dfcb2072cd8e4db03`, equal to the capture's. Rebuilding the header from the derived text and digest gives counter 0 and state equal to `run_binding` (`sched_check.py`, E). Controls re-run: base `sh_g` 7 refused at "source-derived run parameter_line"; one layer's `cn_a` 3999 at "source-derived run stage_lines"; a mixed 18/20 gate at "source-derived uniform D78 token block layout".

Native absorbs and what an altered calibration changes: see Finding 1. Calibration values are caller trust inputs (256:3).

"WholeRun numeric counter": `whole_run` (256:70-107) recomputes in Python floats the column, LogUp and omitted terms and takes the floor; it reproduces the 101 and 17 inside the capture's parameter line (`whole-run-floor-101-bits-17-openings`). It is a reproduction for this one input, guarded by a stability `require`. 258 says "not a new security/privacy proof", and 285 `remaining` bullet 4 says "not a soundness proof". No soundness claim is made.

## 4. Alignment derivation (263-269)

The records are `public_fixture_activation` (Finding 3). Diffing 250 against 264 and 252 against 267 shows the only replaced items are the product shift (`f0`, 264:217-218), the SiLU table scales and group IDs, and the gate fold multipliers (267), plus consistency checks (`aligned["gate"]["shift"]==gate_shift`). 266 imports and calls 264's `evaluate_family`; 268 and 269 import 267 and 264, so the new path is exercised and the old 250/252 are not used. 266 repeats the 40 expressions and 640 native-IR vectors with 362 controls; 268 repeats the 126 tables with 126 same-MLE controls plus 5 activation and 4 overflow controls.

## 5. Native harnesses

All five compile Rust assembled by Python text slicing of `source-d78-188` (`item()`, `prepare_capture_index146.py:14-22`, brace matching), then `rustc --edition=2021 -O -C codegen-units=1 [-C lto=fat --extern zkp_core=<pinned rlib>]` with a 45 s timeout, run as a subprocess; no cargo.

| Harness | Replaced by facade or adapter (stated in its scope) |
|---|---|
| 265 | none for the group/aligned/table functions (extracted verbatim); model admission not run |
| 272 | Shape/Layout metadata facades; AccuracyPublic geometry/IDs/product16 facade; F-only pad adapters |
| 275 | synthetic family closures (not native logical define closures) |
| 279 | Shape/Layout/model facades; other logical draws are placeholders |
| 283 | fixture dispatcher; Shape/Layout/model inputs; zero-column matrix-fold adapter (`282:48-54`, seven matmul slots) |

Extraction check (CONFIRMED, `extract_check.py`): regenerating the 283 fixture source reproduces the saved `fixture.rs` byte for byte; all 11 base match arms are verbatim substrings of the pinned `argument.rs` and of the fixture. 283 itself does not assert this; it holds by construction. The generator also applies string edits that are not verbatim (`282:17-20,38-45`, extra struct fields, `norm_ceps`), which are stated only as "fixture". The matrix-fold zero columns mean fold table content is never compared natively.

Shared-mistake example: see Finding 2. The unkeyed definition-only draw stream (`public-native-all-283`, no absorbs) is replayed in Python and matches every native draw, the counter and the state (`probe_all_constructors283.py:83-105`). This checks the squeeze chain and request counts, not the keyed proof stream.

Guard table: every harness run peaked at or below 0.62 GiB and 28 s (283: 0.58 GiB, 28.0 s; 279: 0.41 GiB, 11 s); the one above 1.2 GiB is 260 at 1.47 GiB, 14.1 s. None of the harness compiles ran under the guard (no `history.jsonl` rows between the native 190 runs at 07:10 and `fold287-build` at 11:44). The native 190 build (4.7 GiB, 195 s) and full run (9 GiB, 799 s) were guarded.

## 6. Controls sampled

| Probe | Control | Check that refused |
|---|---|---|
| 258 | change block layout line 0 | "source-derived block layout description" (recorded) |
| 258 | base `sh_g` 7 (mine) | "source-derived run parameter_line" |
| 258 | layer `cn_a` 3999 (mine) | "source-derived run stage_lines" |
| 260 | layer changes gate with coherent text and digests | "source-derived uniform D78 token block layout" (also mine, 18/20) |
| 266 | coherent graph, terminal and masked-final forgery | "independent source block terminal expression" (recorded) |
| 266 | changed equality family scale | "equality or private table" (recorded) |
| 268 | two words changed, digest recomputed, MLE preserved | "source-derived public synthetic block table: <label>", 126 of 126 (recorded) |
| 276 | 10 control kinds | native clauses (Finding 4) |
| 281 | helper alpha, host coefficient, cube length | "native W16 polynomial at public input", "hosted coefficients", "table metadata" (recorded) |
| 284 | challenge word, final state, request partition, logical and physical host coefficient (re-run, 2 modes) | respective "native definition-only…" / "request partition" / "host coefficients" (CONFIRMED) |
| 284 | counter set to boolean, logical index boolean | type checks, by design (CONFIRMED) |

None was refused by an unintended generic check; the boolean cases are type controls by design.

## 7. Re-run (CONFIRMED)

I ran 269 once under `python3 -O` from a scratch copy (it opens its outputs in Sol's directory): 31.9 s, 400 MB; Sol 34.7 s, 373 MB. All report fields equal Sol's except time, peak and the progress-log pin: 33,564,688 bytes, 445 claims, 3 joins, counter 4815, terminal state `b7c34669…f505`.

## 8. Wording versus evidence

- "Execute all 23 original constructor bodies": true for execution (11 verbatim base arms, W16 functions, `accuracy::define`), but seven matmul constructors run with zero-column folds, the dispatcher is fixture code, and the source is edited as above.
- "Every native constructor challenge and the terminal state/counter match independent replay": true for the unkeyed definition-only stream; 285 states "no proof-message absorbs".
- "Fifteen token and forty block expressions independently evaluated": carries the 254-era limits (LowH24 noncompact, fixture constants).

## Not checked or dropped

Not checked: 262, 270 and 277 internals beyond their pins; 272/275/279 report parity counts; 281 controls re-run (recorded traces read); 276's 8 MB list beyond counts; `d78_token_geometry223` internals; cross-platform libm behaviour. No rustc or cargo was run.
