# Independent first review, Astra package T (first trained image-decoder layer proof)

Reviewer: Claude (Sonnet 5.5), read-only pass 1, 2026-11-16. Scope: `results/zk60_astra_20261026/a4_text_decoder_proof_20261115/`
plus `a4_component_review_20261116/REVIEW_INDEX.json`; part 2 reads the author's response to the V review.
Labels: REPRODUCED (I re-ran or re-derived it), CHECKED (read against a cited file and line), ARGUED, NOT VERIFIED.
Scratch: `/private/tmp/claude-501/-Users-victorrielly-IntelligenceRegulation/39cab447-559b-4f13-981d-d0346f20681a/scratchpad/astra_t_pass1/`
(rehash.py, src.py, pred.py, rederive.py, distinct.py, recv.py).

## Plain-words summary

1. Both gate hashes match (PACKAGE.json dbbd7ae4..., REVIEW_INDEX.json a127a753...). All 1,873 files the package pins, all 604
   external source pins and all four predecessor packages (465, 77, 430, 39 files) rehash cleanly. Zero mismatches.
2. T claims a proof of the first text-decoder layer (real weights, 149 real tokens padded to 256) for three synthetic canvas
   images, plus 11 forged proofs refused. The proof receipts (about 40 MB each) were not kept. So every statement
   that "the proof verified" or "the forgery was refused" rests on Astra's saved logs of a 5-minute run, not on files I can re-check.
3. What I could re-derive today: the numerical reference (122 million values, 72 arrays per case) was made by Python/numpy, not by
   the Rust prover. I re-checked its internal arithmetic myself on all three cases (norms, rounding, softmax, residual sums):
   everything holds. That the Rust prover's values equal this reference is a log-only claim.
4. A gap that V did not have: the reference comparison is run on the prover's intermediate trace, before it is converted to the
   planes that are actually committed and proved. The committed input/output roots come from the converted planes.
5. The forgery and wire controls are real (a false value is refused by the verifier at a slot named in advance) but cover only the
   "black" image, one cell of one array, and several pairs of controls share the same refusal slot.
6. The verifier's statement is built from the prover's own objects; the only independent check is the numpy reference.
7. Privacy: the package says only that it does not establish "whole-proof privacy". It does not say which things are public
   (statement roots, the public prompt rows) and no zero-knowledge argument is given. The weights are public, which the
   project allows. Wording ("qualified", "retained cases", "forged receipts pass") reads stronger than the evidence.
8. T proves one layer of 26, for 3 synthetic inputs, as a development profile. No composition with the image producer or classifier.

## Findings (T)

### AT-1 (Medium) Central claims rest on saved logs of receipts that no longer exist
All three honest "ordinary serialized-proof verification passes", the 39,607,720-byte size, the 12 wire controls, the 11 forged
rejections and the 10.54 / 11.34 GiB peaks come from `attempts/20261116T055053.916315Z/{black,white,coordinates,forgeries,unit}/leaf.log`
and `guard.json`. CHECKED: logs agree with RESULT.json (sha256 of receipts, bytes, peaks 10.54/10.53/10.54/11.34, 6 passed / 2 ignored).
`raw_receipts_retained=false` is in RESULT.json and in the log lines; REVIEW.md says "retained canvas cases" and never says
the receipts are gone. Receipts cannot be byte-reproduced (prover seeds masks from OS entropy, `token_io/run.rs:901` `ZkRng::from_os`),
so the three receipt hashes are unverifiable even in principle. "Verification" is `run::verify_run(&st, blocks, &frames)` on the
in-memory frames in the same process as the prover (`tests.rs:337`), not a separate verifier run on a file. Re-run is possible
(about 1 min per case, but 10.5 GiB peak, above my limit; binary `563067c8...` and all inputs are still in /private/tmp and hash-match).

### AT-2 (Medium) The reference comparison is on the pre-assignment trace, not on the committed planes
`tests.rs:188-216`: `trace = witness_accuracy::build(..)`, then `reference::compare(i,&trace,..) == 40734216`, and only afterwards
`w = witness_accuracy::assign(.., trace)`. The proof commits `w.planes`; the endpoint statement is built from `w.planes[A_X]` and
`w.planes[A_X2]` (`tests.rs:230-253`). `compare` (reference.rs) converts the Trace with the author's own `conversion::Rounded::rescale`
and compares to the reference file; it never sees `assign`'s output. So "all 122,202,648 intermediate values match" is a statement about
the builder's trace, not about the values in the proof. ARGUED mitigation: a plane mis-assigned in a relation-visible way would fail
the honest proof; a relation-neutral mis-assignment (for example the output plane that feeds the public output root) would not be caught
by this comparison. V did not have this gap (V logged hashes of the assigned planes and compared them to fixtures). T's logs carry no
plane hashes. NOT VERIFIED either way: the log cannot discriminate.

### AT-3 (Medium) Forgery and wire controls cover one case, one cell
The 11 forgeries and the 12 wire controls run on `black` only (`tests.rs:339` `if name=="black"`, `tests.rs:350` `witness(&i,"black")`);
white and coordinates have `wire_controls=0` and no forgery. Each forgery changes element `[0]` of one limb plane (`tests.rs:374`, `:400`):
one cell, always head 0 / token 0 / channel 0. No forgery for: a lookup-table miss (the `CheatingProver` skips exactly those refusals,
protocol.rs 462-467, so lookup misses are only covered by the static test `actual_lookup_queries_enforce_all_eight_symmetric_roles`,
which checks constants, not a refused proof), padded rows 149..255, the exp table/mask relation (the plan lists it as required),
RoPE tables, gamma/weight substitution, or a wrong model/layer statement. REVIEW.md does not say "one case".

### AT-4 (Medium) Several controls share a refusal slot; slot expectations were revised after a first run
Forged roles map to slots Rq,Ro to 15; Rk,Rv to 16; Rao,Rd to 14; Rg,Ru to 18 (RESULT.json, log `IMAGE_DECODER_FORGED`): the logs cannot say which
relation inside the shared zero-check refused. The assertion matches only `"slot {n} ["`. README says the first forgery was refused at slot 15 but the test
had expected the private Q slot 5, and "the revised assertions now require the declared host"; i.e. expected slots were changed
after seeing the verifier's answer. ARGUED mitigation: the verifier's own labels list the hosts (`[04 Q zero-check (hosts 09Q, 11)]`),
so the revised expectation is the documented one. For `Nr`, `Ms` (scalar-preserving +65536/-1 carry) the assertion is only prefix `H: pcs zk: group ` and suffix
`<v, c> != combined claim` (`tests.rs:412`); the log shows group 8 for both. That group 8 is "the global lookup opening" (RESULT.json
`scalar_preserving_global_lookup_rejections: 2`) is the author's reading, ARGUED.

### AT-5 (Medium) Verifier inputs and the statement come from the prover's own code path
`load()` builds `Imported {sh, block, statement, numeric, context}` for both sides. `bound()` derives the expected input/output roots from the witness
(`prepare_endpoints(spec,&input,&output)`) and the test passes the same `st`, `i.block` to `verify_run`. Nothing compares the receipt or statement to an externally
computed root, model digest or context. Wire controls assert `is_err()` only (`tests.rs:283,288,293,295,299,320`), no refusal reason recorded, so framing/length
errors cannot be told apart from the three statement-binding controls (context, input root, output root flips), which are the only three that hit the claimed relation.
There is no wrong-model / wrong-layer / wrong-weights statement control. Model controls (11 = 4 unit-parse + 4 geometry + 2 norm + 1 exp, all
constructor rejections in `tests.rs:27-85`) are self-referential by design: constants are in the same file.

### AT-6 (Low) Model identity chain not tied to the checkpoint inside this package
The statement binds: `model.bin` sha256 (MODEL_METADATA.json, `image_decoder.rs:139`), export profile sha, layer manifest sha (compared to a file hash
of `layer_00/manifest.json`, `image_decoder.rs:297-301`), a literal metadata digest in the provenance label, and a fixed context
`sha256("Astra image decoder real149 T256 development/2")`. CHECKED. Whether `model.bin` weights equal the checkpoint's layer-0 weights is established by
`a4_native_text_decoder_20261115` (predecessor, pinned), not re-checked here: NOT VERIFIED by me. `export.source.checkpoint_layers == 26` is required
although only one `LayerRecord` is in the statement.

### AT-7 (Low) Privacy: package says almost nothing about what is public
Package text (README.md:46, REVIEW.md:21, ADAPTER_REVIEW.md:65) only disclaims "whole-proof privacy"; `production_or_privacy_acceptance:false`. It does not list
what is public: the statement (context, the two endpoint roots over a 256x4096 matrix, `endpoint_rows=261` = data rows plus `endpoint_g::MASK_ROWS`, CHECKED
`token_io.rs:1306`, `tests.rs:58`), the model, and the public prompt rows of the layer input (the 64 image rows replace token-id-10 rows of a public
embedding matrix, prepare_layer.py:30,38; the other 85 rows are public text embeddings). Whether the receipt hides the input/output/activations
(zero knowledge) is not argued or tested here; ARGUED that the endpoint is a hiding commitment because of the mask rows and OS-entropy prover randomness.
Intermediate activations: no values and no plane hashes appear in the package logs (only word counts). The arrays (inputs, references) are in /private/tmp, not in the repo. The three
inputs are synthetic canvases, so even a leak would not be real data. Against ZK60_PRIVACY_REQUIREMENTS (inputs/outputs/activations hidden, weights may be
public) the open question is the receipt, not the repository.

### AT-8 (Low) Wording stronger than evidence
See table below. Main: title "First trained image-decoder layer qualified" (implementing-agent qualification; REVIEW_INDEX says
`implementation_reviewed_independently:false`; REVIEW.md has no qualifier); "passes all three retained canvas cases" (cases retained, receipts not; "ordinary verifier" =
in-process); "11 coherent forged receipts pass" (they are refused; the tests pass); "Each receipt is 39,607,720 bytes" (also identical for forged ones, a fixed-size artifact
of the profile). "Unique reference words" is accurate: REPRODUCED that 0 of 72 planes are identical between black/white or black/coordinates.

### AT-9 (Low) Parent-failure explanation not checked
REVIEW.md attributes the parent exit 1 to "test-accounting assertions" in two downstream children. CHECKED: the parent terminal's sha256 (2ffc37ec...) equals
`ORIGINAL_SESSION.json parent_terminal_sha256`, state `failed`, and the child job (pid 9762) is `complete` with batch_exit 0. The session number 53835 appears only in ORIGINAL_SESSION.json
(handle, not re-checkable). The "test-accounting" cause: NOT VERIFIED (I did not open the downstream attempts, possibly still live).

### AT-10 (Low) Evidence outside the repository is volatile
Test binary, `model.bin`, 3 inputs, 3 references (326 MB each), the 3B safetensors and the fixtures sit under /private/tmp (hash-pinned in SOURCES.json, 604 pins, all REPRODUCED today,
binary 563067c8... REPRODUCED). A reboot ends the re-run. The repo itself holds only sources, logs, pins.

### AT-11 (Info) Positive: independent numerical reference, clean pins
REPRODUCED: I parsed `black/white/coordinates.reference` (ATXREF01, 72 planes x 40,734,216 words) and `.input` and verified with my own numpy code, for all three cases:
norm_a ss/root/lower/upper recomputed from the input alone (ss = 2439 + sum x^2, isqrt); norm rho+sigma+1 = 2*(root<<9) for both norms; norm_m ss/root recomputed from residual1; |q|<=32767;
residual1 = x + ao_q and output = residual1 + down_q; for all 12 rounded sites (q,k,v,qr,kr,score,pv,ao,gate,up,product,down) rem+comp+1 is a power of two and q*den + rem = acc + den/2;
product_acc = activation * up_q; best = causal row max; delta = best - masked score; exp is zero on future cells and a function of delta; total = sum exp; prob*total + rho = exp*4096; sigma = total - 1 - rho.
All True. Not re-derived (needs weights/tables): matmul accumulators, gamma, RoPE, exp table values, silu activation table. The reference file is made by `a4_native_text_decoder_20261115/prepare_layer.py` with numpy and the older Python reference decoder, and it asserts equality with the old trace and (for black/white) historic outputs.

### AT-12 (Info) Development rung, not acceptance
`RUN_PROFILE_IMAGE_DECODER_T149` is a development profile; context a fixed constant; no formal (Lean) statement for this relation set (D63 production rule); not installed (CHECKED: main `hashline/src/private_block` has no `image_decoder`).

## Claim table (item 2)

| # | Claim (REVIEW.md / RESULT.json) | Class | Basis |
|---|---|---|---|
| 1 | Package pins: 1,873 package files, 604 source pins, 4 predecessors (465/77/430/39) rehash | (a) REPRODUCED | rehash.py, src.py, pred.py: 0 bad, 0 missing |
| 2 | REVIEW_INDEX pointers (6 hashes, prepare.py) | (a) REPRODUCED | all equal |
| 3 | Reference values are numerically self-consistent (internal arithmetic) | (a) REPRODUCED | rederive.py on the 3 reference files |
| 4 | 122,202,648 values (3 x 40,734,216) match the reference | (b) | `IMAGE_DECODER_PLANE` / `WITNESS` log lines; compares trace, not assigned planes (AT-2) |
| 5 | Three cases pass ordinary serialized-proof verification | (b) | black/white/coordinates leaf.log; in-process; receipts gone |
| 6 | Each receipt 39,607,720 bytes; receipt hashes | (b) | log only; not reproducible (OS entropy) |
| 7 | Six unit tests pass | (b) | unit/leaf.log `6 passed; 2 ignored`; static content CHECKED in tests.rs; binary on disk, not run by me |
| 8 | 11 model controls | (b) | log lines (4+4+2+1); CHECKED tests.rs 27-85: constructor rejections |
| 9 | 12 wire/statement controls | (b) | black only; `is_err()` only |
| 10 | 11 coherent forgeries refused; nine at stated zero-check hosts | (b) | forgeries/leaf.log; slots CHECKED in tests.rs 358-366; black only; one cell |
| 11 | Two scalar-preserving carries reach the global lookup opening | (b) | log `pcs zk: group 8`; "global lookup" ARGUED |
| 12 | Peaks 10.54 / 11.34 GiB, timings are shared-host diagnostics | (b) | guard.json CHECKED equals RESULT.json; disclaimer accurate |
| 13 | Parent exit 1 / child 9762 exit 0 / audit 0 | (a) CHECKED | parent terminal sha matches; child complete; session handle 53835 only in ORIGINAL_SESSION.json |
| 14 | Parent failed because downstream children failed test accounting | (c) | not found in package; NOT VERIFIED |
| 15 | No 26-layer / composition / task-quality / formal / privacy / production claim; no adoption | (a) | negative claims; CHECKED consistent with code and main tree |
| 16 | Trained weights (not synthetic) | (a)/(c) split | model.bin sha pinned and REPRODUCED; link to the checkpoint via predecessor package, NOT VERIFIED by me |

Tally of 16 rows: (a) 6 (rows 1, 2, 3, 13, 15, plus 16 for the pinned file), (b) 9 (rows 4-12), (c) 1 (row 14); row 16 is half (a), half not verified.

## Independence versus self-comparison (item 3)

| Check | What refuses / compares | Independent? |
|---|---|---|
| Reference planes vs Rust | `compare` of ATXREF01 (numpy, prepare_layer.py) against the Rust Trace converted by `Rounded::rescale` | Reference independent (numpy, my re-check passes); compared object is the pre-assign trace (AT-2); result log-only |
| Rq, Ro, Rk, Rv, Rao, Rg, Ru, Rd, Rs (+1 on a remainder limb) | verifier zero-check host slot named in advance; `CheatingProver` skips lookup-miss refusals only | Yes for what it tests (relation acc = q*den+rem...), pair-shared slots, one cell, black only |
| Nr, Ms (+65536 / -1 carry) | H opening `<v,c> != combined claim`, any group | Yes, a real scalar-preserving case; reason text only; two controls |
| wire: 3 byte flips, 3 truncations, extra byte, empty, extra frame | any error | Not shown; reasons not recorded |
| wire: other context / input root / output root | statement binding | Plausible; unrecorded; expected roots computed from the prover's own witness |
| model controls (11) | constructor rejections | Self-referential by design |
| Statement/model passed to verifier | same `load()` as the prover | No external reference for root, model digest, context |

## What the verifier trusts (item 4)

Taken as given: `model.bin` (sha in metadata; weights, per-channel multipliers, shifts, RoPE tables, exp table, silu tables); export profile sha and layer manifest sha (file-hash
checks only); the calibration constants (tn 9, ceps 2439, cn_a 848, cn_m 1716, shifts sh_*, silu member, exp_e_s, groups); the per-layer residual unit (26 units equal); the checkpoint
identity (from the export); the fixed development context; the geometry (149 tokens, T256, width 3072/4096, 261 endpoint rows); the endpoint roots (computed by the prover side,
supplied to the verifier); the development hash profile; fixture inputs are inputs to the prover side only. Nothing ties row content of the input matrix to the image producer.
Public in this package: the weights/model digests, statement, context, three synthetic canvas names, plane word counts, receipt sizes/hashes. Not in the package: arrays, inputs, receipts.
Privacy claim of the package: none beyond "does not establish whole-proof privacy"; no zero-knowledge argument.

## Wording against evidence (item 5)

| Sentence | Issue |
|---|---|
| "First trained image-decoder layer qualified" | implementing-agent qualification, no independent review; REVIEW.md says nothing |
| "passes all three retained canvas cases under the ordinary verifier" | cases retained, receipts not; in-process verify |
| "Each receipt is 39,607,720 bytes" | log value; same for forged ones |
| "All 122,202,648 intermediate values match the archived numerical reference" | trace, not the committed planes; log-only |
| "11 coherent forged receipts pass" | they are refused; tests pass |
| "Nine ... fail at their zero-check hosts" | slot level; pairs share slots; one case, one cell |
| "scalar-preserving byte carries reach the global lookup opening" | log supports `pcs zk group 8`; naming is the author's |
| "Timings describe shared-host functional checks" | accurate |
| "Those failures do not change this child's evidence" | argued; cause unseen |
| "does not establish ... whole-proof privacy ... production acceptance" | accurate and appropriately cautious |

## Not established by T (item 5)

- A proof for all 26 layers, the final classifier, or the complete image-to-verdict pipeline; composition with the image-input producer (`composed_with_image_producer:false`).
- Behaviour on any input beyond three synthetic canvases (black, white, coordinates); task quality.
- Verification of retained receipts, or in a separate process or build; byte-reproducible receipts.
- Forgery/wire coverage on cases other than black, on any cell other than index 0, on lookup misses, padding, weights, model/layer substitution.
- That the compared reference values are the committed values (AT-2).
- Zero knowledge of the receipt; formal (Lean) soundness; production hash profile or context; any adoption. A development rung, one layer, one profile.

## Package V follow-up

Read: `a4_component_review_response_20261116/RESPONSE.json` (19:30Z, only file there), RECOVERY_COORDINATION entries (line 2703 V review response; 2862 registry note), follow-up
`a4_image_head_review_20261116/` (manifest e5af2e7c...). Guard history (`history.jsonl`): all eight `astra-head-review-*` leaves ended (check 19:28Z ... fresh_forgeries 21:20:20Z, all exit 0), so I read their outputs.
Terminal state of the batch is `failed`: after the eight native leaves exited 0 the Python audit raised `AssertionError: ('IMAGE_HEAD_FORGED_FRESH','incomplete evidence')` (`evidence.py:32`). No RESULT/REVIEW/FREEZE exists there.
ARGUED diagnosis (REPRODUCED counts): in `fresh_forgeries/leaf.log` the first forged line is glued after the test-name prefix; only 79 of 80 `IMAGE_HEAD_FORGED_FRESH index` lines start at column 0, and `rows()` keys on `startswith`. The 80 rejections are all in the log; the audit stopped on a log-format issue.
RESPONSE.json says "acknowledged", `fixes_validated:false`, nothing claimed closed; its follow-up fields (state running, build) are stale relative to the later outcome.

| AV | Status | What / re-derivable? |
|---|---|---|
| AV-1 receipts not retained | **Answered by new evidence, audit not passed** | 8 honest + 80 forged receipts saved (88 files, 3,071,168 bytes each, 224-byte header + receipt + trailer) in /private/tmp (volatile, not in repo); REPRODUCED: all 88 file sha256 equal the `IMAGE_HEAD_SAVED` / `FORGED_SAVED` log values. A separate native test run (`fresh`, `fresh_forgeries`, `witness_loaded=false`) verified 8 and refused 80 with recorded reasons. I did not run the verifier. Same checkout and binary, not an independent build; independent Python audit failed (log-parse issue, above). The six original V receipts remain unretained. |
| AV-2 no honest positive verdict | **Answered (constructed)** | Cases index 6 (cn 1024) and 7 (cn 7009) have verdict=1, saved and fresh-verified. They are negated row-148 inputs (margins +5,872,972 / +40,686,770 per README), labelled constructed standalone head inputs, not decoder output or task quality. Margins/references NOT re-derived by me (README says standard-library prep matches 55,338 + new words). |
| AV-3 verdict control entangled with margin | **Answered** | New role `verdict_only` keeps real margin, row, boundary and all planes, flips only the verdict; refused at OUTC-04 (CHECKED black log; summary `margin_preserving_flag_controls=8`). Legacy combined control kept and labelled. Refusal text equals the margin control's, but the construction now isolates the flag. |
| AV-4 one case only | **Answered** | 80 forgeries = 8 cases x 10 roles (both cn 1024/7009, three images, two positives, refusal_free and calibrated arms), CHECKED counts; fresh honest verifier runs 24 controls per case (192). |
| AV-5 verifier inputs from prover path | **Partly answered** | Fresh run records a reason for each control (`IMAGE_HEAD_REPLAY_REJECT`, 191 lines plus one glued line = 192); an independent Python recipe serialises the public model and is compared with the loaded model. Not independent: the root is taken from the receipt's statement, checkpoint/margin loader and BLAKE3 are the native ones; most of the 24 controls refuse at the envelope/header stage ("head ... reconstructed statement", "envelope"), only `payload` and `rebound_*` (4) reach the cryptographic verifier. |
| AV-6 wording | **Acknowledged; text of V unchanged** | RESPONSE says V is unchanged; follow-up README states the verdict bit is public (D40/D76), constructed positives are not quality evidence, "fixed per case" prompts (PROMPT_PROVENANCE.json: differing ids traced to query strings, no retokenization), and that retention is a "prepared capability until native execution succeeds". V's REVIEW.md still says "qualified" / "retained cases". |

Also: AV-10 (text OUT-C regression) answered by the `text_regression` leaf: 15 tests passed (CHECKED log). AV-8 answered by PROMPT_PROVENANCE.json (not re-derived).

## Not reached

- I did not run any binary or the verifier; the 88 receipts are hash-checked only. Not re-derived: matmul accumulators, gamma, RoPE, exp/silu tables, the constructed-positive margins, the follow-up's Python reference preparation.
- Not opened: downstream decoder-chain attempts (possibly live), TrainedExport derivation, 3B weights, the full CheatingProver implementation beyond the cited lines.
- Suggested pass 2 (coordinator-run, under the resource guard): re-run `trained_first_decoder_proof` for one case, save and re-verify the receipt in a fresh process (as the V follow-up now does), add plane-hash logging of the assigned planes against the reference, add forgeries on white/coordinates and cells away from index 0, and one wrong-model statement control.
