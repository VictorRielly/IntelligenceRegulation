# Independent first review, Astra package V (final image-classifier head proof)

Reviewer: Claude (Sonnet 5.5), read-only pass 1, 2026-11-16. Scope: package
`results/zk60_astra_20261026/a4_image_classifier_proof_20261115/` plus
`a4_component_review_20261116/REVIEW_INDEX.json`. Labels: REPRODUCED (I re-ran or
re-derived it), CHECKED (read against the cited file and line), ARGUED, NOT VERIFIED.

## Plain-words summary

1. Both gate hashes match (PACKAGE.json b86c2253..., REVIEW_INDEX.json a127a753...). All 893 files the
   package pins, all 913 source pins and all 469 files of the two predecessor packages rehash cleanly.
2. The package says six final-head proofs (three synthetic images, two normalization constants) were
   built and verified, and nine forged proofs were rejected. The proof receipts were not kept. So those
   statements rest on Astra's saved logs of a 29-second run; I could not re-check them from the files.
3. What I could re-derive today: the 55,338 "reference values". I recomputed all six cases from the
   stored decoder output rows and the margin vector with my own Python and they equal the reference
   fixtures exactly. The reference was made by a different code path (numpy plus the old reference head)
   than the Rust prover, so that comparison is a real independent check of the witness values.
4. The forgery controls are mostly meaningful (a proof built from a false value is refused by the
   verifier at the slot named in advance). Two weaknesses: the "false verdict" control also falsifies the
   margin, so it does not isolate the verdict relation; and every forgery and wire control runs on one
   case only (black, cn 1024).
5. Every honest case has verdict 0 and a very negative margin. The positive-verdict branch has no honest
   proof at all.
6. The verdict bit is public in the statement. The project's decisions D40/D76 allow that leak, but the
   package text does not say so. The review wording ("qualified", "retained cases") reads stronger
   than the evidence, and REVIEW.md never says the receipts were not retained (RESULT.json does).
7. A cheap re-run is possible (about 29 s, 0.13 GiB per leaf, binary and inputs still in /private/tmp). I
   did not run it: the one attempt to execute the 4 small unit tests from the pinned binary was refused by
   the permission classifier, and I did not retry or work around it.

## Findings

### AV-1 (Medium) Central claims rest on saved logs of receipts that no longer exist
All six "ordinary serialized-proof verification passes", the 3,070,936-byte size, the 12 wire controls, the
9 forged rejections and the 0.13 GiB peaks come from `attempts/20261116T062924.242868Z/{proofs,forgeries,unit}/leaf.log`
and guard.json. CHECKED: those logs say what RESULT.json says; the plane hashes in the proofs log equal the
`FIXTURES.json` plane hashes for all 60 planes in order (REPRODUCED), and the audit asserts this (evidence.py).
Receipts cannot be byte-reproduced even in principle: the prover draws masks from OS entropy
(`ZkRng::from_os`, bridge.rs), so the six receipt sha256 values in RESULT.json are not checkable. Verification
here means in-memory `Vec<u8>` bytes verified in the same process as the prover (image_head/tests.rs 344-359),
not a separate verifier run on a file. The retained receipt hashes would only matter if receipts existed.
Mitigation: a coordinator re-run is cheap (see "Not reached / next step").

### AV-2 (Medium) No honest positive-verdict proof
All six verdicts are 0; integer margins are -5,872,972 / -40,686,770 (black), -7,864,891 / -53,489,024
(white), -6,394,598 / -43,741,760 (coordinates) (REPRODUCED from native rows). The `flag` plane hash is the same
for all six cases in the log. The flag=1 branch (sigma=+1, gap = delta-1) is only reached through forged
witnesses and one statement-level flip; no honest receipt with flag=1 verifies. A completeness gap for the
verdict-positive path (the case a classifier proof must handle).

### AV-3 (Medium) The "false verdict" control does not isolate the verdict relation
tests.rs 416-419: the control flips `verdict` and also sets `margin = +1 / -1`. The honest dot product w.y is about
-5.9 million, so the proof also violates the margin identity. It is refused at slot 04, exactly like the
"margin" control (same reason string). ARGUED: a verifier that did not enforce sign(margin) = verdict would still
refuse this control. A sharper control keeps the true margin and flips only the flag. The same pair-sharing applies
to "wrong_row"/"input_boundary" (both IO-in, identical text), "norm"/"padding" (both slot 05) and
"rho_byte"/"x_byte" (identical text). Each is distinct as a construction; the log cannot tell which relation inside the slot refused.

### AV-4 (Medium) Forgeries and wire controls cover one case
`coherent_head_forgeries` uses `entries[0]` (black, refusal_free, cn 1024); wire controls run when `index == 0`
(evidence.py 33: `wire_controls == 12 if index == 0 else 0`). Nothing on cn 7009, white or coordinates.
RESULT.json lists "wire_controls: 12" at top level; its per-case records show the 0s, but REVIEW.md does not say one case.

### AV-5 (Medium) Verifier inputs and "expected" values come from the prover's own code path
`model::load`, `Statement::new` and `owners` build the Model, the context, the root and the verdict. `verify(&m,&st,...)` is
then given those same objects. The only independent reference in the package is the witness comparison
(fixtures vs Rust trace). Nothing compares the receipt/statement to an externally computed root, prompt digest or
model digest. Wire controls assert only `is_err()` (tests.rs 263-330) and record no reason, so a control that fails
for an unclaimed reason (a trivial framing/length error for truncations, magic flip at offset 0) cannot be excluded.
Controls 10-12 (statement with other context/root/verdict/model) refuse because the statement binding changes, which is
the claimed reason but is also not proven by the log.

### AV-6 (Medium) Wording that says more than the evidence
See the wording table. Main items: title "qualified" with no statement that this is implementing-agent
qualification (the predecessor REVIEW says so; this one does not; REVIEW_INDEX says
`implementation_reviewed_independently: false`); "retained cases" and "each receipt is 3,070,936 bytes" with no mention that
no receipt is retained; "nine coherent forged receipts pass" (they are rejected; the tests pass).

### AV-7 (Low) Privacy: public verdict bit; wording silent on it
The verdict is public in the statement (`Statement.verdict`, absorbed as `public-verdict`, bridge.rs 59; stage_out_c.rs 678
"the verdict is the STATEMENT's (public)"). ZK60_PRIVACY_REQUIREMENTS.md lists outputs as Hidden, but D40 (public verdict bit
for classifier profiles) and D76 (allowed leakage includes the public verdict) rule this leak in. CHECKED. REVIEW.md
does disclaim "whole-proof privacy" and RESULT sets `production_or_privacy_acceptance: false`; it does not name the
public verdict. The row-148 input is held in a hiding commitment (4 mask rows, ZkRng) and only its root is public;
no raw input, activation or intermediate is in the package's artifacts except as below. Whether the receipt is zero
knowledge is not established (no simulator argument; package disclaims it). The proof logs print sha256 of every
intermediate plane (q, rho, sigma, delta, gap) and `FIXTURES.json`/RESULT carry margins and verdicts; these are for
three synthetic images and are not a leak of private data, but would not be acceptable for real inputs.

### AV-8 (Low, question for the author) Public prompt differs by case
MODELS.json: black and coordinates share one prompt digest (byte-identical file; the splice README says coordinates
deliberately reuses the black prompt); white's public ids differ at positions 58, 59, 60, 62, 63, 64 (text ids before
the image block that starts at 70), so its public_prompt digest differs. The package README speaks of "the fixed image
prompt". NOT VERIFIED why white's text ids differ. If any public text id depended on image content it would be a public
channel; if it is just a different test prompt, "fixed" is imprecise.

### AV-9 (Low) Literal booleans in RESULT.json
`audit.py` writes `checkpoint_margin_rederived=True`, `public_prompt_rows_authenticated=True`, `ordinary_verifier=True`,
`committed_classifier_proof=True` as Python literals. They are backed only by the Rust test not panicking
(`model::load` requires them; the test prints `ordinary_verifier=true` as a literal string). The margin derivation
itself (`TrainedExport::load`, `export.tied_derivation`) is outside this package's diff and leaves no log line.

### AV-10 (Low) Shared-file change not regression-tested
`stage_out_c.rs` was refactored into `prove_at_site/verify_at_site`; the existing entry points pass `claim_site = 1`.
CHECKED by diff against `a4_text_decoder_proof_20261115/source`: the claim-site-1 branch of `boundary`/`claim_sources`
is unchanged. But the only test selector run is `private_block::token_io::image_head::tests::`, so no evidence in the
package that the text-classifier OUT-C suite still passes.

### AV-11 (Low) Evidence outside the package is volatile
The test binary and 14 input files (decoder rows, prompts, fixtures) live under `/private/tmp/...`, hash-pinned but not
archived. All matched today (REPRODUCED), including the binary sha 1e6cb017.... The classifier source/margin live under
`results/zk60_shieldstral_export_20261026/` (in repo, matched). A reboot or tmp cleanup would end the cheap re-run.

### AV-12 (Low) Development profile, constant context
`PROFILE` is a "development" string; `HashTag::for_profile` is a profile-derived keyed rule. The statement context is a
fixed constant (`sha256("Astra final image classifier real149/T256 development/1")`), not input- or session-derived, and
the model digest ends with the literal "development-only". The joint-boundary figure 262 rows is asserted only by
`BoundarySpec::new_with_tag` accepting author-chosen parameters (tests.rs 250-259); nothing ties it to the real decoder boundary.

### AV-13 (Info) Retry history is clean
Four attempts. 053825 and 062002 died on `sysmond`/`pgrep` (host check). 055053 passed five leaves except the first forged
receipt: the assertion expected `slot 0`, the verifier says `slot 00` (SLOT_FORMAT_REPAIR.md). The repair changed only the
formatting; the expected slots [0,0,2,5,4,4,-,-,5] were in the source before any forgery had run in that attempt and
match the final log. CHECKED. The 4.1 GiB python process in `proofs/host-before.txt` is not the leaf (guard samples the leaf tree: 0.13 GiB).

### AV-14 (Info) Hygiene for a public repo
No emails or credentials found; `telemetry.jsonl` and `host-before.txt` contain host process lists (window server, Cursor,
user path). Not private values, but unneeded noise in a public repository.

### AV-15 (Info) Positive: independent reference and clean pins
`prepare.py` (predecessor) builds fixtures with numpy and the original reference head `D.head`, asserts equality with the
native row and, for black/white, with retained historical heads. My re-derivation matches all 6 x 9223 words.

## Claim table (item 2)

| # | Claim (REVIEW.md / RESULT.json) | Class | Basis |
|---|---|---|---|
| 1 | Six cases pass ordinary serialized-proof verification | (b) | proofs/leaf.log `IMAGE_HEAD_PROOF` x6; receipts not kept |
| 2a | 55,338 reference values, row-148 norm, margin, verdict are what the fixtures say | (a) REPRODUCED | my Python from `native-output` + `margin_int16.bin` vs the 6 fixtures; 60 plane hashes in log == FIXTURES.json |
| 2b | The Rust witness equals those references | (b) | `compare()` assertions; log only |
| 3 | Each receipt 3,070,936 bytes | (b) | log |
| 4 | Four unit tests pass | (b) | unit/leaf.log; re-runnable (binary on disk), I was blocked from running |
| 5 | 12 model controls | (b) | log; the 12 mutations CHECKED in tests.rs 199-217 and each hits a stated `validate` clause |
| 6 | 12 wire controls | (b) | log; one case, `is_err()` only |
| 7 | 9 coherent forged receipts rejected at stated relations | (b) | forgeries/leaf.log; expected slots CHECKED in code (a) |
| 8 | 2 scalar-preserving carries fail the global lookup opening | (b) | log: `pcs zk: group 4: <v,c> != combined claim` |
| 9 | Native proof leaves peak 0.13 GiB | (b) | guard.json (watchdog-only, sampled) |
| 10 | Timings are shared-host diagnostics | (b) | guard.json; the disclaimer itself is accurate (CHECKED) |
| 11a | Coordinator 94718 reaped child 79697 exit 0 incl. audit; parent exit 1 | (a) CHECKED | `a4_decoder_head_retry_20261116/.../terminal.json` (sha 3d9e4779 matches) lists the child complete, exit 0; handle number only in ORIGINAL_SESSION.json |
| 11b | Parent failed because the decoder chain rejected a per-layer layout change before proving | (c) | parent terminal says only "black failed; inspect retained logs"; I did not open that decoder attempt (possibly live) |
| 12 | Standalone one-site input proof; joint needs two-site, 262 rows | (a) CHECKED | bridge.rs/stage_out_c.rs diff, tests.rs 238-261 |
| 13 | Margin re-derived from checkpoint; prompt rows authenticated | (b) | literals in audit.py; backed by loader requirements (model.rs 79-100, 147-162); weights not re-derived by me |
| 14 | No application, profile or model adoption | (a) CHECKED | main `hashline/src/private_block` has no `token_io` or `image_decoder`; sources exist only in results snapshots |
| 15 | Pins/hashes: 913 source pins, 893 package files, predecessors 39 and 430 files | (a) REPRODUCED | all rehashed, 0 mismatches |
| 16 | Not established: composition, task quality, formal soundness, privacy, production | (a) | negative claims, consistent with the code and the index |

Tally of the 16 rows (19 sub-claims counting 2a/2b and 11a/11b): (a) 6, (b) 12, (c) 1.

## Pins (item 1)

- PACKAGE.json sha256 = b86c2253... (matches). REVIEW_INDEX.json sha256 = a127a753... (matches).
- Package files: 893 of 893 rehashed (33,909,481 bytes, equals the index figure), 0 mismatches, 0 missing; the only file on disk not in PACKAGE.json is PACKAGE.json itself.
- SOURCES.json pins: 913 of 913 rehashed (includes the in-package source plus external inputs), 0 mismatches.
- Predecessors: a4_native_image_classifier (39 files) and a4_native_decoder_chain (430 files): package hashes match, 0 bad file hashes.
- External: test binary sha 1e6cb017..., 14 input/fixture/prompt/margin/classifier files all match MODELS.json; REVIEW_INDEX RESULT/REVIEW/FREEZE/ORIGINAL_SESSION/SOURCES hashes and its prepare.py hash match.
- Pins only prove the logs are the logs Astra saved; they say nothing about whether the run was what the logs say.

## Controls traced (item 3)

| Control | Refusing check | Independent of the thing under test? |
|---|---|---|
| wrong_row (row 147 witness) | OUTC-00 IO-in, sumcheck round 0 | Yes: the statement root commits the true 256x4096 matrix; the witness (same builder) disagrees with that commitment. |
| input_boundary (matrix cell changed) | OUTC-00 IO-in | Yes, same relation, same text as above. |
| root (isqrt d+1) | OUTC-02 TZC isqrt | Yes (verifier relation); builder is the same code but the verifier checks the polynomial identity. |
| norm (one q +1, margin/verdict recomputed) | OUTC-05 DZC quotient | Yes, and it is the intended relation. Only slot 05 can catch it (margin limbs stay consistent). |
| margin (+1) | OUTC-04 | Yes. |
| verdict (flip + margin = +-1) | OUTC-04 | Weak: refused partly for the false margin (AV-3). |
| rho_byte / x_byte (carry, value kept) | stage H opening, `pcs zk group 4 <v,c> != combined claim` | Yes, a true scalar-preserving case; the slot check only matches the substring `pcs zk: group` and `combined claim`, the group index is only in the log. |
| padding (y[WIDTH] = 1) | OUTC-05 | Yes. |
| wire: byte flips/truncations/extra byte | any error | Not shown; reason not recorded. |
| wire: other context/root/verdict/model | statement binding | Plausible; unrecorded. |
| model mutations (12) | `Model::validate` clauses | Self-referential by design: constants hard-coded in the same file; each hits a distinct clause (CHECKED). |

All forgeries run with the test-only `CheatingProver` (skips lookup-miss refusals only, protocol.rs 462-467, 581-585); ordinary hooks are installed and
`cheating_prover_is_on()` is asserted false before verify.

## What the verifier trusts (item 4)

Taken as given: the pinned checkpoint identity (`ModelSource::shieldstral_1_0_3b()` weights/config hashes, a code constant); the
export profile sha and tied derivation (loaded by the same code that proves); the margin vector (equal to the derived one and to
`margin_int16.bin`); classifier.json constants (g0 127, tn 10, ceps 2439, cn 1024/7009, yes 13059, no 2649, threshold 0, scale);
the public prompt digest (ids and embedding rows); the constant context; the statement root; the public verdict bit; the geometry
(row 148, 149 tokens, T256, width 3072/4096, 260 rows); the development hash profile. The fixtures and the native decoder rows
are inputs to the prover side only. Nothing ties the committed 256x4096 matrix to a decoder run: rows other than 148 are unconstrained.

Privacy in this package: verdict public (allowed by D40/D76); root public as a handle; prompt public by design; inputs hidden in the
commitment only; zero-knowledge of the receipt not established. Package wording (REVIEW.md "does not establish ... whole-proof
privacy", RESULT `production_or_privacy_acceptance: false`) is modest and matches, except for not naming the public verdict.

## Wording against evidence (item 5)

| Sentence | Issue |
|---|---|
| Title "Final image classifier development proof qualified" | "qualified" = Astra's own audit passed; no independent review (index says false); no qualifier in REVIEW.md. |
| "All six retained cases pass ordinary serialized-proof verification" | cases retained, receipts not; REVIEW.md never says so; "serialized" = in-memory bytes, same process. |
| "Each receipt is 3,070,936 bytes" | log value of receipts that no longer exist; also identical for forged ones. |
| "nine coherent forged receipts pass" | they are rejected; "pass" means the tests pass. |
| "reject at their intended relations" | slot level only; verdict control entangled with margin (AV-3). |
| "Two scalar-preserving byte carries reach and fail the global lookup opening" | supported by log text; not independently re-run. |
| "Both native proof leaves peak at 0.13 GiB sampled RSS" | accurate as stated (watchdog sample); the build step peaked 5.51 GiB (not mentioned). |
| "Timings are shared-host functional diagnostics" | accurate. |
| "does not alter this classifier child's evidence" | argued; only the parent's terminal hash is pinned, cause unseen. |
| "Synthetic cases do not establish task quality ..." | accurate and appropriately cautious. |
| RESULT `checkpoint_margin_rederived`, `ordinary_verifier`, `committed_classifier_proof`: true | audit literals (AV-9). |

## Scope (item 6): what this package does NOT establish

- Task quality: three synthetic images (black, white, coordinates), every verdict negative; no real or labelled images.
- A proof of the whole image-to-verdict pipeline: the head is standalone; nothing binds the committed matrix to the decoder output; decoder chain failed in the parent run.
- Verdict-positive behaviour of an honest proof; forgery/wire coverage for cn 7009 and for cases other than black.
- Receipts you can verify later; verification by an independent process or a separate verifier build.
- Formal soundness (no Lean statement for this head; D63 production rule), zero knowledge of the receipt, repeated-proof behaviour, production hash/profile keys.
- That the existing text OUT-C path still passes after the claim-site refactor.
- It is a development rung (development profile and context), not acceptance; no adoption, no installation.

## Not reached / suggested pass 2

- I could not execute the 4 pinned unit tests: the permission classifier denied running the test binary from /private/tmp; not retried.
- Not run: `trained_final_heads` and `coherent_head_forgeries` (about 29 s each, 0.13 GiB). A coordinator-run re-run under the resource guard
  with `ASTRA_IMAGE_HEAD_MODELS=<package>/MODELS.json` would convert claims 1, 2b, 3, 6-9 from (b) to REPRODUCED. Better, add an honest flag=1 case and
  a margin-honest flag-flip forgery, and save the receipts.
- Not opened: the decoder-chain attempt (possibly live), the stage OUT-C verifier internals beyond the slot labels, the TrainedExport derivation, the 3B weights.
- Scratch files: `/private/tmp/claude-501/-Users-victorrielly-IntelligenceRegulation/39cab447-559b-4f13-981d-d0346f20681a/scratchpad/astra_v_pass1/` (rehash.py, ext.py, rederive.py, planes.py, pred.py).
