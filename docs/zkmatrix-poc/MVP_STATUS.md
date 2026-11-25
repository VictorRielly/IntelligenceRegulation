# Where the MVP stands, in plain words

**2026-11-23 UTC, speed against the 50 tokens/s target [MEASURED; details and limits in the dated entries further down]:** on the synthetic 8B shape the stream proves 40.2 tokens/s with the two GPU switches merged on Nov 22 turned on, and 37.2 at the merged head's defaults (`results/zk60_composed_8b_20261123/README.md`). The trained 3B classifier that the app runs proves 48.6 to 50.0 tokens/s at six lanes with eight threads each (`results/zk60_lane_threads_20261122/README.md`). The two figures are different models and different tests and must not be merged. The switches are off by default; the 8B figure is a shape figure, not trained 8B weights.

**2026-11-18 UTC, first native proof on trained 8B parameters (Sol's report; second reading done 15:28 UTC, evidence only, no source review):** **Second reading (Claude's read-only reviewer, `results/zk60_claude_review_20261116/SOL_TRAINED_8B_461_REVIEW.md`):** the retained evidence supports the narrow claim and nothing more. Recomputed: all 34 segment hashes and the 764,068,112-byte total (the coordinator repeated this check independently), the 62 pins of Sol's receipt audit, the 5,224 pins of the run specification; the six guard rows are in order and exit 0, and the verifier was a separate, later process. What the proof is: ONE next token for ONE 128-token prompt, and that prompt is sequence 0 of the calibration set the export was fitted on (in-sample); a CPU run on one thread with the GPU off (prover 468 s by its own report, 602 s in total); the public-row variant, with no privacy acceptance, as its own statement says; a development profile. The proved export is the one that failed D32 (final figure 1.137 times float perplexity on the 24 FineWeb examples completed, one refusal). The refitted export is a different export and has no native proof yet. Not checked by the reviewer: the Rust prover and verifier source, the privacy property, how the checkpoint became the export, and whether the owner-side input equals the archived prompt. **Sol's report as first recorded:** Sol reports a native development proof of the trained Llama-3-8B export at W16R3, T128: all 32 blocks on one archived calibration sequence, a fresh verifier accepting 34 segments (764,068,112 bytes, 95-bit minimum, 97-bit whole-run floor), both owner checks passed [REPORTED by Sol, 2026-11-18T07:30Z; `results/zk60_sol_20261105_w16r3/b3/D78_TRAINED_8B_NATIVE_DEVELOPMENT_467.md`]. Limits, in Sol's own words and figures: privacy and production acceptance are open; **the quality run (D32) on this export has since failed** (Sol, 08:06 UTC): it refused at FineWeb example 25 on one out-of-range gate word in layer 3, which breaks the zero-refusal criterion, and before that it stood at 1.110 times the float model's perplexity on the first 20 examples, against 1.013 for the archived calibration that passed D32. So the proof is valid for its one calibration prompt and the export is not an accepted model; Sol is refitting per channel from the passing calibration and has that refit in D32 now; it is a CPU development proof and says nothing about speed. Claude has asked Sol for the entry files and will put a read-only reviewer on it.

**2026-11-18 UTC.** The six original text prompts reproduced all six historical margins and decisions from token IDs through the full 26-layer numerical model. Native proof checks for those exact lengths remain pending. For the first image-decoder layer, a public-only calculation reproduced the first 70 output rows in each of three synthetic cases. A separate overlap screen found 24 candidate pairs in the synthetic dataset controls. Real-data split review and quality measurements remain pending. [Text replay](../../results/zk60_astra_20261026/a2_exact_sequence_review_20261118/REVIEW.md), [public prompt rows](../../results/zk60_astra_20261026/a4_decoder_public_rows_20261118/REVIEW.md), [overlap controls](../../results/zk60_astra_20261026/a4_image_overlap_review_20261117/REVIEW.md).

**2026-11-17 UTC, saved complete-image proof now replays:** One retained 2,873,106,100-byte container passed all 102 stages in a fresh ordinary verifier process; an altered first frame was rejected. All five guarded leaves passed, and the 452-file evidence package is frozen. The original parent exited 1 because its independent text sibling failed; the image child exited 0. This is one synthetic case, with no independent/privacy/production acceptance. [Replay evidence](../../results/zk60_astra_20261026/a4_complete_image_replay_20261116/REVIEW.md).

The six exact-length text profiles compiled, then the first profile unit exposed a missing calibration registration. The isolated repair passed input checks for all six exports. An independent replay using the saved input at each of 26 layers found that all 221,207,168 active attention scores fit the required range. Across three synthetic images a separate replay reproduced every value in the 216 first-layer decoder reference arrays. Native witness comparisons and proof checks remain pending in one grouped launch. [Text score results](../../results/zk60_astra_20261026/a2_exact_score_review_20261117/REVIEW.md), [decoder replay](../../results/zk60_astra_20261026/a4_decoder_arithmetic_review_20261117/REVIEW.md), [native validation plan](../../results/zk60_astra_20261026/text_decoder_validation_20261117/PLAN.json).

**2026-11-17 UTC, full-length text padding refusal localized:** Compilation, regression, admission and the first 234-token numerical sequence passed. The next case stopped at layer 7 before proof generation: four score values exceed the allowed range only where both positions are added padding. The original 174-token score square remains within range; three failures are causal, so masking future positions alone would not fix it. An independent attention-only reconstruction confirms the cause. A recovery must preserve the original prompt and historical arithmetic while reconciling native padding semantics. The independent full-image replay subsequently passed and is now frozen. [Diagnosis](../../results/zk60_astra_20261026/a2_padding_diagnosis_20261117/README.md).

**2026-11-17 UTC, mobile label layout installed:** Category cards at 640px and below preserve readable proof, policy and anchor fields. Nine reviewed browser captures, keyboard disclosure controls, accessibility/layout checks and all four installed frontend suites pass. The controller subsequently continued to saved full-image replay after preserving the text padding refusal. No additional user input was needed for this installation. [Installation evidence](../../results/zk60_astra_20261026/a6_mobile_labels_integration_20261117/README.md).

**2026-11-17 UTC, complete image development proof qualified and frozen:** All six honest image-to-verdict cases and all four coherent full-chain forgery checks passed. Each honest case verifies 102 stages, 102 roots and 101 internal boundaries, with 2,873,101,488 receipt bytes reported. The separate 26-layer decoder suite also passed its three honest cases, two boundary forgeries and full audit. The original parent exited 0; both packages are frozen. These synthetic implementing-lane results have no retained raw receipts. The classifier follow-up saved eight honest and 80 forged receipts; fresh verification, 192 wire controls and the recovered evidence audit pass. Its original controller exit 1 is preserved: the final parser missed libtest-prefixed evidence rows, corrected by an audit-only follow-up. Saved full-image replay now passes for one black/refusal-free case, with a retained102-stage container and fresh ordinary verification. A separate T follow-up implements an assigned-plane auditor but remains uncompiled, with retained/fresh T receipts still pending. Actual-image quality, independent acceptance, formal/privacy and production gates remain open. [Image qualification](../../results/zk60_astra_20261026/a4_complete_image_proof_20261116/REVIEW.md), [decoder qualification](../../results/zk60_astra_20261026/a4_decoder_chain_proof_20261115/REVIEW.md), [classifier audit recovery](../../results/zk60_astra_20261026/a4_image_head_audit_recovery_20261117/README.md).

**2026-11-16 UTC, six original full-length text cases prepared for native validation:** The exact historical inputs and 162 input/layer references are recovered. An isolated T256 candidate preserves all six original lengths, including two strict-hate templates confined to a test-only registry. Its complete 23-step batch is sealed with 1,297 input/source pins and will check admission, all 26 layers, six ordinary proofs and fresh verification, owner and corruption checks. The launched batch compiled and passed five initial gates plus the first numerical sequence, then stopped on the second case's padding refusal described above; no proof was run. This is preparation, with no profile adoption or privacy/production acceptance. [Prepared scope](../../results/zk60_astra_20261026/a2_full_length_review_20261116/README.md).

**2026-11-15 UTC, first decoder proof implementation:** The isolated real149/T256 development profile, strict norm/attention ranges, authenticated trained-model import and reference/proof tests now compile. A fixed seven-step guarded batch advances automatically through build, unit tests, three proof cases and tampering checks; native proof qualification is still pending. While the batch waits for the shared resource lock, a separate preparation audit checked all 26 layers' calibration/group metadata and all 75 retained numerical carry links without another approval. [First-layer candidate](../../results/zk60_astra_20261026/a4_text_decoder_proof_20261115/README.md), [chain preparation](../../results/zk60_astra_20261026/a4_decoder_chain_proof_20261115/README.md).

**2026-11-15 UTC, decoder proof preparation:** Exact witness conversions now pass eight unit tests and all three existing first-layer fixtures, including symmetric signed ranges, normalization remainders, grouped rounding and causal/padded attention. The complete six-step batch needed no new approval and stayed below521MB combined memory. All1,011 files in the four qualified predecessor packages remain unchanged. This is preparation; the actual decoder proof builder and verifier still need integration. [Conversion review](../../results/zk60_astra_20261026/a4_text_decoder_proof_20261115/ADAPTER_REVIEW.md).

**2026-11-15 UTC, native final classifier qualified:** The actual last row from each complete 26-layer native decoder run now passes both existing final normalization variants and the tied yes/no margin calculation. All six comparisons, 12 unit tests and 228 alteration controls pass, matching 55,338 intermediate values and every integer margin/decision. Black/white also match four historical heads; coordinates has a new reference. The 39-file package is frozen; combined memory stays below 79 MB. These synthetic cases do not establish task quality. Committed decoder/classifier proof, complete image proof and independent soundness/privacy/production work remain open. [Classifier qualification](../../results/zk60_astra_20261026/a4_native_image_classifier_20261115/RESULT.json), [review](../../results/zk60_astra_20261026/a4_native_image_classifier_20261115/REVIEW.md).

**2026-11-15 UTC, all 26 native decoder layers qualified:** All three 149-token canvas cases pass every layer and the independent relation checker: 78 layer/case comparisons, 5,616 planes and 3,177,268,848 values. The audit authenticates 976 inputs and all 75 native output-to-input transitions against separately carried reference outputs. All 52 historical black/white outputs match. The original L7/L12/L25 calibrations are preserved. The 430-file package is frozen; combined parent/child memory stays below 1.29 GB, and no new host approval was needed. This is numerical qualification; committed decoder proof and independent quality/privacy/production gates remain open. [Decoder-chain qualification](../../results/zk60_astra_20261026/a4_native_decoder_chain_20261115/RESULT.json), [review](../../results/zk60_astra_20261026/a4_native_decoder_chain_20261115/REVIEW.md).

**2026-11-15 UTC, complete image-to-decoder-input proof qualified:** Three cases now verify the RGB8 frontend, all24 encoder layers, projector and full149-token adapter as one75-stage chain with76 roots and74 joint internal openings. Twelve unit tests,135 model controls and831 wire/opening/stream controls pass. Two full-chain forgeries reject at the intended projector-output/adapter-input boundary after73/74 valid frames. All2,354,061,312 reference values match; receipts stream1,859,339,784 bytes per case without a replay archive. Peak RSS is7.28 GiB; the465-file package is frozen. Committed text decoding and classifier proof, actual task quality and independent soundness/privacy/production work remain open. [Qualification](../../results/zk60_astra_20261026/a4_image_input_proof_20261115/RESULT.json), [review](../../results/zk60_astra_20261026/a4_image_input_proof_20261115/REVIEW.md).

**2026-11-15 UTC, first native text-decoder layer numerically qualified:** All three retained canvas inputs pass the full first layer and its separate scalar/field checker, matching122,202,648 values across72 planes per case. Sixteen unit tests and343 alteration controls pass; nine coordinated forgeries pass local rounding and fail their matrix/QK/PV definition. The77-file package is frozen. Native child RSS peaks at454 MB; all work completed without a new host approval. The full 26-layer native chain and final classifier are now qualified above. Committed decoder/classifier proof and quality/privacy/production obligations remain open. [Qualification](../../results/zk60_astra_20261026/a4_native_text_decoder_20261115/RESULT.json), [review](../../results/zk60_astra_20261026/a4_native_text_decoder_20261115/REVIEW.md).

**2026-11-15 UTC, standalone full-prompt adapter proof qualified:** Three receipts now prove the signed Hadamard transform, exact Q24 conversion and complete 149-token decoder-input splice, including all inactive channel/context padding. Eleven unit tests, 17 model controls, 19 wire/model/root controls and 16 coherent forged receipts pass; six forgeries reach the global lookup close. All 3,732,480 reference values match. Receipts are 7,659,752 bytes each; the proof suite peaks at 0.89 GiB RSS. The 419-file package is frozen. This standalone proof requires T256 capability; composition with the encoder/projector is now qualified above. Committed text decoding, task quality and independent soundness/privacy/production work remain open. [Adapter proof qualification](../../results/zk60_astra_20261026/a4_adapter_proof_20261115/RESULT.json), [review](../../results/zk60_astra_20261026/a4_adapter_proof_20261115/REVIEW.md).

**2026-11-15 UTC, complete encoder plus projector proof qualified:** The RGB8 frontend, all 24 encoder layers and N16 projector now verify together as 74 stages, 75 roots and 73 joint internal openings on all three retained canvases. Eleven unit tests, 117 model controls and 820 wire/opening/stream controls pass. Two coherent full-chain forgeries are rejected at the intended producer/consumer boundary checks after 72/73 valid preceding frames. The audit authenticates 1,613 inputs and 2,350,328,832 matched reference values; all eight guarded jobs exited cleanly. Receipts stream 1,852,013,856 bytes per case without a replay archive; peak RSS is 7.23 GiB. The 456-file package is frozen. Adapter composition is now qualified above. Committed T256 text decoding, actual task quality and independent soundness/privacy/production obligations remain open. [Composed qualification](../../results/zk60_astra_20261026/a4_encoder_projector_proof_20261115/RESULT.json), [review](../../results/zk60_astra_20261026/a4_encoder_projector_proof_20261115/REVIEW.md).

**2026-11-15 UTC, complete 24-layer image encoder proof qualified:** All three canvas cases now verify the RGB8 frontend and all 24 trained encoder layers as one 73-stage proof, with 74 roots and 72 joint internal openings. The audit rehashes 869 inputs and confirms 27 unit tests, 102 model/statement controls and 808 wire/opening/stream controls. Native witnesses match 2,341,085,184 reference values. Each case streams 1,840,382,616 receipt bytes; peak RSS is 7.10 GiB, and raw receipts were not retained for replay. The frozen package has 425 files. Projector composition is now qualified above; adapter composition, text decoding, actual task quality and independent composed soundness/privacy/production work remain open. No profile is installed. [Full encoder qualification](../../results/zk60_astra_20261026/a4_encoder_chain_proof_20261115/RESULT.json), [review and limits](../../results/zk60_astra_20261026/a4_encoder_chain_proof_20261115/REVIEW.md).

**2026-11-15 UTC, standalone image projector proof qualified:** Three trained-parameter canvas receipts now prove the full N16 projector, channel merge, three matrix operations, literal GELU and explicit output padding. Nine unit tests, 15 model checks, 24 wire/model/root controls and 27 serialized forged-receipt checks pass; 13 forgeries reach the global lookup check. Native witnesses match all 9,243,648 reference values. Each receipt is 11,965,064 bytes and the proof suite peaks at 1.05 GiB RSS. An initial GELU equation error was caught, repaired and regression-tested before qualification. This standalone qualification is now complemented by the encoder composition above; adapter/decoder proof and task-quality/privacy/production obligations remain open. [Projector proof qualification](../../results/zk60_astra_20261026/a4_projector_proof_20261115/RESULT.json), [review](../../results/zk60_astra_20261026/a4_projector_proof_20261115/REVIEW.md).

**2026-11-15 UTC, complete first image encoder proof:** An isolated native proof now connects the RGB8 frontend and the complete first encoder layer, including attention, output projection, both authenticated residual connections, normalization and FFN. Three trained canvas cases and two explicit residual-scale parameter variants verify; all 60 wire/statement controls and 44 serialized forged proofs reject, including 25 global lookup failures. Twenty-six unit tests and four guarded jobs pass. Three internal commitments are each opened jointly once. The audit authenticates 399 inputs; joined receipts are 84,122,672 bytes and the CPU receipt suite peaks at 6.52 GiB. Raw receipts were not retained for standalone replay. Projector/splice, actual image task evaluation and independent composed soundness/privacy/production obligations remain open. No profile is installed. [Proof validation](../../results/zk60_astra_20261026/a4_encoder_tail_proof_20261115/RESULT.json), [implementation and limits](../../results/zk60_astra_20261026/a4_encoder_tail_proof_20261115/README.md).

**2026-11-15 UTC, all 24 encoder layers numerically qualified:** The native encoder carries its own output through all 24 layers and matches the unchanged full integer reference on black, white and coordinate canvases, including both trained residual-scale transitions. All 72 layer comparisons pass: 4,392 plane comparisons and 2,341,085,184 matched values, streamed without archiving tensor arrays. The single-threaded checks completed inside the sandbox without a host approval and used at most 1.03 GB combined parent/child RSS upper bound. This establishes arithmetic agreement on those cases; the separate 73-stage authenticated proof chain is now qualified as reported above. [Numerical validation](../../results/zk60_astra_20261026/a4_native_encoder_chain_20261115/RESULT.json), [scope and remaining work](../../results/zk60_astra_20261026/a4_native_encoder_chain_20261115/README.md).

**2026-11-15 UTC, native image projector numerically qualified:** The native output of all 24 encoder layers now feeds the unchanged N16 projector and matches the full integer reference on all three canvases. The projector comparison covers 9,243,648 values, including 589,824 output values; all 25 unit tests and 231 alteration controls pass. The audit also matches every encoder reference-plane digest to the prior qualification. Work completed in the sandbox with no host approval and a combined parent/child RSS upper bound below 1.34 GiB. Timings overlap the coordinator's A32 run and are functional diagnostics only. Projector composition is now qualified above; image-token adapter/splice proofs, complete image-to-text proof and actual task quality remain open. [Numerical qualification](../../results/zk60_astra_20261026/a4_native_projector_20261115/RESULT.json), [scope and remaining work](../../results/zk60_astra_20261026/a4_native_projector_20261115/README.md).

**2026-11-15 UTC, native image-to-text input numerically qualified:** Native outputs now continue through the signed Hadamard adapter, exact Q24 scale conversion and complete 149-token embedding splice. All three canvas comparisons pass, covering 3,732,480 adapter values and every output coordinate; 32 unit tests and 123 adapter alteration controls pass. The full prompts require T256 capability; the installed T128 profile is not qualified for them. Coordinates uses the black prompt as an explicit numerical fixture. The audited 30-file package completed without host approval. This numerical qualification stops at decoder input. Encoder/projector composition is now qualified above; standalone committed adapter proof is also qualified above; adapter composition, native text decoding, complete image proof and task quality remain open. The all-24 encoder proof batch is now qualified separately; the standalone committed projector proof is also qualified separately. [Adapter qualification](../../results/zk60_astra_20261026/a4_native_image_splice_20261115/RESULT.json), [scope](../../results/zk60_astra_20261026/a4_native_image_splice_20261115/README.md).

**2026-11-13 UTC, Astra app update:** The installed W16R2 app passed an actual three-category post, incompatible writer-mode refusal, clean restart, and three standalone public-store native verifications. The final audit rehashed 336 inputs and bound all 84 receipt segments to the verified publications. All five guarded jobs and four resident writers exited cleanly; test scratch is removed. The app forces both verifier-once and seal-ahead shortcuts off. All 304 installed-app tests pass. [Native app audit](../../results/zk60_astra_20261026/w16r2_app_native_qualification_20261113/NATIVE_AUDIT.json).

The separate coordinator benchmark records 156 proved and checked requests across ten trials. Warm stream throughput is 29.22 proved tokens/s for W16R2 versus 16.11 for R13; warm single-post latency is 26.70 versus 39.14 seconds (two samples per arm). These count padded T128 separately for each category, exclude service startup, and compare different calibrated profiles. The 30-token target is not reached. Per-trial host-quiet observations and the inherited verifier-shortcut setting were not retained in that benchmark. Both results concern public-content development; private 8B performance and production/privacy obligations remain open. [Benchmark log and arithmetic review](../../results/zk60_astra_20261026/a30a31_benchmark_review_20261113/REVIEW.json).

**2026-11-16 10:25 UTC, cross-review of Sol's independent verifier (Claude, co-coordinator):** Sol's separate Python verifier replays the saved two-block full-token D78 receipt (33,564,688 bytes) from the frozen source rules, without the native verifier. Two bounded review passes found no High finding. [REPRODUCED by the reviewer] all 203 pinned files rehash; a scratch re-run gives Sol's result (445 claims, 13 commitment openings plus 4 mask openings, transcript counter 0 to 4815); the run still passes after all 40 captured block program graphs are corrupted on disk, so the block expressions really come from the source port; the five corrections from the first pass were made. Limits: the port is specialised to this public synthetic LowH24 fixture (gate shift 18, product denominator 16 and the normalisation constants are fixture constants); model identity, block digests and expected roots are trusted inputs; the verifier shares the BLAKE3 crate with the prover; components 229 to 248 were checked only through the final replay; privacy, rank and nonlinear gates, the trained 8B export and the Lean obligations are untouched. This is review evidence for a development rung, not acceptance of D78. Third pass, 14:25 UTC, package 285 (schedule derivation and native constructor harnesses): still no High finding; all 347 pins rehash, the schedule digest is computed from the fixture calibration, and the replay re-runs to the same state. Two more limits: the receipt header binds per-layer calibration only through the model identity and block digests, which this verifier takes as trusted inputs (a per-layer gate changed from 20 to 21 leaves the schedule digest unchanged); and the native-versus-Python constructor comparison feeds both sides the same product shift. Fourth pass, 18:30 UTC, package 295: still no High finding; all 417 pins rehash and the five corrections from the third pass were made. The calibration limit above is closed for this one saved public fixture: the verifier now rebuilds the model record and the block preimage itself and compares their hashes with the receipt, and a per-layer gate changed by one is refused [REPRODUCED]. It remains open for an external checkpoint, for arbitrary model records and as the formal trusted-model premise. [Review 1](../../results/zk60_claude_review_20261116/SOL_D78_REVIEW_212_222.md), [review 2](../../results/zk60_claude_review_20261116/SOL_D78_REVIEW_229_LATEST.md), [review 3](../../results/zk60_claude_review_20261116/SOL_D78_REVIEW_PASS3.md), [review 4](../../results/zk60_claude_review_20261116/SOL_D78_REVIEW_PASS4.md). Fifth pass, 22:44 UTC, package 361 (the native full-crate admission, define and matrix-fold run): still no High finding; all 1,383 pins rehash, and the binary is the earlier crate plus one test-only module [REPRODUCED]. One native stage failed (the admission run's outer stage, exit 1, from a layout mismatch with the token stage) and one was refused at the job queue's wait limit and re-run; the package describes both, and nothing it claims rests on a failed stage. The larger-model identities run on test-only waivers and are labelled so; the compact-token geometry is preparation, not qualification. Limits: the token-stage IO layout is never executed natively in this run, and the compact proof was not run. [Review 5](../../results/zk60_claude_review_20261116/SOL_D78_REVIEW_PASS5.md).

**2026-11-16 18:30 UTC, first cross-review of Astra's final-head package V (Claude, co-coordinator):** no High finding, six Medium. [REPRODUCED by the reviewer] all 893 package files, 913 source pins and 469 predecessor files rehash; all 55,338 reference values, recomputed independently from the stored decoder rows, equal the fixtures, and that reference comes from a different code path than the prover. Limits: the proof receipts were not kept, so the six verifications, the twelve wire controls and the nine forged-proof rejections rest on the implementing lane's logs alone (12 of 19 sub-claims); all six honest cases have verdict 0, so the positive-verdict branch has no honest proof; the "false verdict" control also falsifies the margin and does not isolate the verdict relation; every forgery and wire control runs on one case; the verifier's model, root and verdict come from the prover's own loading path. The verdict bit is public, which D40/D76 allow, but the package text does not say so. A re-run with receipts kept and verified in a fresh process (about half a minute per case by the lane's logs) would settle the first limit. Review evidence for a development rung, not acceptance. [Review](../../results/zk60_claude_review_20261116/ASTRA_V_REVIEW_PASS1.md). **Follow-up, 22:44 UTC:** Astra ran a new batch on the final head the same day. Receipts are now saved (88, all hashes match the logs) and verified in a fresh process (8 accepted, 80 refused); there are constructed positive-verdict cases; a control flips only the verdict and keeps the margin; controls cover 8 cases by 10 roles [hashes and logs checked by the reviewer; the verifier was not re-run by us]. Still open: the verifier's root and loaders come from the prover's own path, the package text is unchanged, and the batch's own audit stopped on a log-parsing problem, so it has no terminal pass yet.

**2026-11-16 22:44 UTC, first cross-review of Astra's first-decoder-layer package T (Claude, co-coordinator):** no High finding, five Medium. [REPRODUCED] all 1,873 package files, 604 source pins and four predecessor packages rehash; the reviewer's own re-check of the three reference files holds. Limits: no receipts were kept (9 of 16 claims rest on logs); the reference comparison runs on the trace before assignment, not on the committed planes, so it does not show that the right values are what was committed; forgery and wire controls cover one case; paired controls share slots, and the expected slots were revised after the first run; the verifier's statement comes from the prover's own path. Review evidence for a development rung, not acceptance. [Review](../../results/zk60_claude_review_20261116/ASTRA_T_REVIEW_PASS1.md).

**2026-11-16 05:45 UTC, SOL continuation:** D78 source164 passes both builds, all 14 native metadata checks, and the complete regression gate (1,008 passes, three unchanged baseline failures, 172 ignored). Six full 8B CPU/GPU/hybrid core variants and final states match; 12 cross-verifications and piece-boundary controls pass on public synthetic inputs. The two-block full-token proof now verifies with both owner checks, independent next-token reference and exact segment counts: 33,564,688 bytes in four segments. A coherent changed embedding input rejects at stage IN H. The last boundary control rejects early at a local sumcheck because its test prover still read honest producer words; source174 prepares the coherent consumer override and retains the exact boundary-opening target. It also prepares physical-slot capture, strict public-table export replay and a separate saved-receipt verifier in one new candidate; these remain unbuilt. [Native evidence](../../results/zk60_sol_20261105_w16r3/b3/D78_NATIVE_QUALIFICATION_REVIEW_177.json), [next candidate](../../results/zk60_sol_20261105_w16r3/b3/D78_CAPTURE_FRESH_BOUNDARY_REVIEW_174.json). Actual native LowH24 8B export/calibration, fulltoken8B, complete capture/joint rank/nonlinear/formal/privacy/freeze remain open. No throughput or production/privacy acceptance; earlier B3 timing is still marginal (0.153%, opposite signs by run order).

**2026-11-10: what the Lean work does NOT yet establish (gap audit: `ZK60_LEAN_GAP_AUDIT_PREMISES_20261110.md` and
`ZK60_LEAN_GAP_AUDIT_FAITHFULNESS_20261110.md`).** Read the Lean bullets further down against this list. Each High
item was re-checked against the source by the coordinator.
- **2026-11-16, lanes L60 and L61 (merged `1668946a`) independently reviewed: sound, but they close one premise, not
  their stated targets** (review by Claude as co-coordinator; lanes written by the Antigravity coordinator;
  [review](../../results/zk60_claude_review_20261116/LEAN_L60_L61_REVIEW.md)).
  - **Holds [CHECKED]:** the new top theorem `bw_productionReadyL_epP_shield` (RunBlkWireTop.lean) and the four
    beside it are sorry-free proofs of the same approved conclusion as L58's; `Statements.lean` is unchanged; only the
    three standard axioms; the generators reproduce all nine files byte for byte. No new premise was found unmeetable
    [ARGUED; no full instance was built].
  - **Proved:** one substantive premise, the block slot-evaluation cover `hsl_blk`, at an explicit slot polynomial
    built from the extracted tables. It adds four small geometry premises (`hoAK`, `hoHK`, `hoIK`, `hoOK`); the last
    two need `endpointLogN = 14`, true in the code at T128 but not yet stated in Lean (R1-3, Medium).
  - **Not proved (R1-2, High):** the stage facts. L60 replaced L58's eight stage premises by L57's eight (`hTrI`,
    `hTrO`, `hDI_stg`, `hDO_stg`, `hLI_stg`, `hLO_stg`, `hdinS`, `hdoutS`) plus 20 set-up premises. `hdzero` is
    unchanged. The premise count went from 144 to 166.
  - **Not used (R1-1, High):** L61's "adversary-free LogUp coverage" and "IO schedule" lemmas are proved, but no top
    theorem uses them. The 26-block wiring `hblk` is still a premise.
  - **Open after L61:** `hblk`, `hdzero`, the eight stage facts, the block alive lists (`hR0_blk` … `hH1_blk`,
    `hLU_blk`), `O`, `hzk`, `hoAK` … `hoOK`. Running now: L62 (Antigravity, `hblk`) and L63 (Claude, the stage
    facts). L57-2 was sidestepped by a sound generalisation (`lkSqB`), not settled.
  - The lane reports' axiom tables showed `['propext']` only for the top theorems; that was a parsing error in the
    report, not in the proofs.
  - **L63, first result (2026-11-16, on lane branch `worktree-agent-a8b5788916259e1b2` at `80771974`; NOT merged,
    awaiting Antigravity's cross-review):** two of the eight stage facts, the define facts `hDI_stg` and `hDO_stg`,
    are proved at the real define polynomials; restated top theorem `ssh_productionReadyL_epP_def`. Lane check green
    (one guarded job, 33 declarations on the three standard axioms). **Finding L63-1 (Medium):** L57's `StgTrueAt`
    asks M's functionals to be true only on the stage's own list, while the code checks the hosted ones too; OUT-C's
    define fact needs them, so a new explicit premise `hHostO` carries it until it is proved with `hTrO`. Also new:
    `hN64I`, `hN64O`, `hIOlI`, `hIOlO` (small, argued meetable). Still open of the stage facts: `hTrI`, `hTrO`,
    `hLI_stg`, `hLO_stg`, `hdinS`, `hdoutS`, `hdzero`, and the stage degrees.
    [Lane doc on the branch: `docs/zkmatrix-poc/ZK60_LEAN_L63_STAGE_FACTS_20261116.md`.]
  - **Finding L63-4 (Medium, ARGUED, 2026-11-16):** the stages' define step refuses a zero batching challenge, so
    the real define residual is not a bounded-degree polynomial in the draws, and the stage degree condition inside
    `hD` cannot be proved in L57's form. The round bound still holds with one more escape per round. A generic lemma
    for this and a checked recount of the run's soundness budget with the extra escape are in progress (L63).
    **Resolved the same day (lane branch at `f3cc8a57`, not merged): informational, not a fault of the framework.**
    The generic lemma is proved (`RunStgShieldRbr.lean`). The run's soundness budget is unchanged at 55,852,891 of
    67,108,864 [PROVED: the gate prices each define kind by its form, and every stage entry still fits]. At an
    accepted reading the challenges are nonzero, so the non-refusing branch's polynomial meets both conditions; the
    define polynomial must be written that way (one bridge lemma per define closure, still to do).
  - **L62 pre-review (Claude, 2026-11-16 18:20 UTC; the author, Antigravity, has not yet declared the lane finished;
    file untracked, sha256 `c68a7c49…`):** `RunBlkShieldInst.lean` compiles as it stands and its declarations rest on
    the three standard axioms only [REPRODUCED: a scratch copy built in the L63 worktree; the root module was not
    built]. **It does not yet discharge `hblk` (L62-1, High).** The new top theorem
    `bw_productionReadyL_epP_shield_r13` drops `hblk` by name and takes `hblkS` instead, which still assumes the
    parts of the bundle that depend on the proof transcript: the define and lookup draws sitting in the right lists
    (`hdefR`, `hdefIO`, `hlu`), the header length, and how block inputs and outputs are read. What is now proved is
    the fixed public half (layout, tables, lookup coverage, the input/output check's algebra), so L61's lemmas are
    finally used by a top theorem. Also: `hoAK` … `hoOK` are gone, two derived, two from a new premise `hep14`
    (endpoint size 14, true for the app's profile but not yet tied to the export; L62-3, Medium); the block
    input/output tables are still undefined existentials (L62-2, High); and the Lean input/output schedule had
    not been checked against the code's two IO slots (L62-4). **That check is now done (18:40 UTC): they are the
    same** [CHECKED against `argument.rs:2957-2963` and `layout.rs:1099-1100`; the Lean execution-model side PROVED by
    a probe], so L62-4 drops to Low, with one small addition: the shield predicate should pin both IO slots to the
    standalone kind (L62-9, Low). Premise count 166 → 164.
    Nothing found is false or unmeetable.
    [Review: `results/zk60_claude_review_20261116/L62_PREREVIEW.md`.]
  - **L63, second result (2026-11-16 19:10 UTC, lane branch at `2970a51b`; NOT merged, awaiting cross-review):**
    the "mask checks are true" stage facts are split in three. Two parts are proved on every accepted run: the
    reader part and the mask-commitment part, the latter over the stage's own and its hosted functionals (the L63-1
    correction). `hHostO` is gone; `hTrI` and `hTrO` shrink to their claims parts `hTrIC` and `hTrOC`. No new bad
    event; the soundness budget stays 55,852,891 of 67,108,864. New top theorem `ssh_productionReadyL_epP_true`,
    151 binders (was 152). Lane check green [guard record and log read by the coordinator: one guarded job, eight
    modules, 56 declarations on the three standard axioms]. **Finding L63-5 (Medium, ARGUED, untested):** at the
    input stage the statement's IO claims are read off a model accumulator that matches the code's only after the
    claims are dropped, so they may not be the claims the code's openings check; being settled now.
  - **L63, third result (2026-11-16 20:40 UTC, lane branch at `f3e6c794`; NOT merged): finding L63-5 is confirmed.**
    A mismatch in a Lean model, not a protocol weakness: the code builds the input stage's input-endpoint claim at
    the endpoint width (2^8, the geometry D77a records), while the stage model the stage facts are stated on gives
    every slot the block width (2^14) [CHECKED against `token_io.rs:190`, `:1128` and `StageVerifyExec.lean:264-266`].
    So the IO part of the input stage's claims premise speaks of claims the code never opens and cannot be met by
    the real run [ARGUED]; rated High for the Lean chain. Everything else in the two stage models agrees, and the
    first two results are unaffected. Repair: a corrected claims notion beside the original (stated in the lane's
    files, not yet proved through), Lean only. **Also proved:** the output stage's A/H claims on an accepted run;
    its claims premise shrinks to its IO claims (`hTrOIO`). New top theorem `ssh_productionReadyL_epP_claimsO`,
    still 151 binders. Lane check green [guard record read: eleven modules, 64 declarations on the three standard
    axioms]. Not yet cross-reviewed.
  - **L63, fourth result (2026-11-16 21:20 UTC, lane branch at `9883532b`; NOT merged):** the input stage's A/H
    claims are proved on an accepted run, so its claims premise shrinks to its IO claims too (`hTrIIO`, the part
    L63-5 shows unmeetable as stated). New top theorem `ssh_productionReadyL_epP_claimsI`, 151 binders. Lane check
    green [guard record read: fourteen modules, 77 declarations on the three standard axioms]. The L63-5 repair is
    scoped: a stage polynomial for the input stage with each slot at its own width, and its terminal theorem,
    built beside the originals; the input-endpoint fact `hdzero` waits for it. Not yet cross-reviewed.
  - **L63-5 repaired (2026-11-16 21:36 UTC, lane branch at `a2ea4f91`; NOT merged, not yet cross-reviewed).** A
    corrected top theorem `sshC_productionReadyL_epP_claimsI` is stated on a stage model that reads each
    input-stage slot at the code's own width. Same number of premises; three are restated (the input stage's IO
    claims, `hb0`, `hdinS`) and the unmeetable one is gone. No degree, draw count or budget change (55,852,891 of
    67,108,864); nothing already proved turned out false. Lane check green [guard record read: 23 modules, 109
    declarations on the three standard axioms]. Left: a short tie between two forms of the corrected IO claims
    (Medium), then `hdzero`. **21:49 UTC, lane branch at `14da016b`:** that tie is proved for both stages, so both
    IO-claims premises are now in the form the code's openings check, and `hdzero` is reduced to a stage-form
    premise `hdzS` (top theorem `sshC_productionReadyL_epP_claimsF`; lane check green over 28 modules, 117
    declarations). Still argued, not proved: that the claimed IO values are the evaluations of the committed IO
    tables. A possible finding was settled the same hour as Low (lane branch at `097d0d1c`): `hdzero` asks exactly what the
    protocol binds, because the first input-stage slot zero-checks every word of the input plane [CHECKED against
    `stage_in_c.rs:174-183`, `classify.rs:911-917`]; the gap was only that the Lean layout parameters were not
    tied to the code's layout. That tie is now a stated premise (`hLay`, true of the code's layout), and `hdzero`
    becomes `hdzW`: a non-zero decoded word past the tokens dooms the input stage (top theorem
    `sshC_productionReadyL_epP_claimsW`; lane check green over 30 modules, 120 declarations). Next: tie the claimed
    input values to the decoded endpoint words, which closes `hdzW`.
  - **Open of the stage facts after L63's seven steps of 2026-11-16:** `hdzW` with the claimed-value link, the two
    IO-claims premises (now in the code's form), the stage dooms (`hdinS`, `hdoutS`), the stage LogUp facts
    (`hLI_stg`, `hLO_stg`), the stage degrees (Antigravity's L65).
  - **19:30 UTC, both lanes cross-reviewed.** L62: its author's root build is green [guard record read by Claude:
    run `e9bb2967656d`, exit 0], with the warnings patch applied and the wording above agreed ("`hblk` reduced to
    `hblkS`"); not yet committed. L63's two results: reviewed and accepted by Antigravity
    (`results/zk60_coord_batch4_20261115/L63_DELIVERABLE1_AND_2_REVIEW.md`), which also confirmed that the second
    result adds no new premise. Next: L62 is committed, L63 is rebased onto L62's top theorem and merged. Claimed by
    Antigravity: L64 (the block alive lists, the list memberships, the block input/output tables, L62-3 and L62-9)
    and L65 (the stage degree bridges). Claude keeps L63: L63-5, the stage claims parts, LogUp facts and dooms.
  - **2026-11-17 06:01 UTC, L62 committed and L63's later steps cross-reviewed.** L62 is on the working branch
    (`eda8b4f7`, not pushed): the reviewed file, unchanged since its green root build, and one import line
    [commit read by Claude: two paths]. Antigravity reviewed L63's steps three to seven (the A/H claims of both
    stages, the L63-5 repair, the IO-claims ties, the `hdzero` reduction) and accepted them: no High, no Medium,
    one Low (a generator without a read-only check mode)
    (`results/zk60_coord_batch4_20261115/L63_ITEMS_3_TO_7_REVIEW.md`). **06:14 UTC, L63 merged** (`4a24243c` on
    the working branch, not pushed; its tree is identical to the checked lane tree `aa84f6d7`). The merged-tree
    check with L62 is green [guard record and log read by Claude: run `0217bd7d990c`, exit 0, 96 s, peak 3.98 GiB;
    root build with both lanes, 0 warnings in their files; 120 of 120 L63 declarations and L62's top theorem on
    the three standard axioms; 13 generators reproduce their files; no name clash; `Statements.lean` unchanged;
    regressions green] (`results/zk60_lean_l63_20261116/check_merge.log`). The Low finding is closed in the merge.
    This shows the two lanes build together; it proves no new theorem. L63's top theorem is not yet restated on
    top of L62's, and nothing in the two "Open" lists changes: the review and the merge accept what was proved,
    they close no premise.
  - **2026-11-17 08:52 UTC, L65 (stage degrees, Antigravity) cross-reviewed: accept with fixes; it closes no
    premise yet.** Three new files, not committed. No High, two Medium, three Low
    (`results/zk60_claude_review_20261116/L65_REVIEW.md`; kernel check by the reviewer, guard run `2d540a1bfe0f`,
    exit 0, 13 theorems on the three standard axioms, 0 warnings in the L65 files). What holds: the concrete
    degree lists agree with the Rust code slot by slot, none is below the code's degree; the zero-challenge
    refusal is counted as a rejection and paid for in every round's bound; the unfolded terms are the executable
    verifier definitions, not copies. What does not hold as described: the new top theorem
    `sshC_productionReadyL_epP_dg` is L63's top theorem with the two degree lists filled in. Its premise list is
    otherwise the same, the validity premise `hD` is still there, and its proof does not use the new degree
    lemmas. Those lemmas prove four of the six conditions per stage entry, and they need a premise the top theorem
    does not carry: that the IO claim is read from a multilinear table (`StgCsIODeg`), which is the open csIOI /
    csIOO link of L63. So **"the stage degrees" stays in the open list** until a lemma builds the stage part of
    `hD` from them and the csIO link is proved. **09:04 UTC, committed with the wording fixed** (`2df5f72d` on the
    working branch, not pushed) [commit read by Claude: four paths, the three files equal the posted hashes, the
    root gains exactly three import lines, rebuild guard run `eaff89fbaf2d` exit 0]. Agreed split: Antigravity
    writes that lemma (L65b) after its alive-lists lane L64; Claude's L63 supplies the csIO link first.
  - **2026-11-17 11:06 UTC, L64 (block alive lists, Antigravity) cross-reviewed: accept with fixes; one new file,
    not yet committed.** No High, three Medium, four Low (`results/zk60_claude_review_20261116/L64_REVIEW.md`;
    guard run `86b0333e027c`, exit 0; all 64 theorems on the three standard axioms or none, 0 `sorryAx`, 0
    `ofReduceBool` [axiom output and guard record read by Claude]; the check replayed the author's compiled file
    after the source-hash check, it did not recompile it). What holds: the new top theorem
    `sshC_productionReadyL_epP_blkAlive` has the same conclusion as L65's and **is already the combined theorem**,
    L62's block reduction and the stage chain of L63 and L65 in one statement, so the separate step "restate L63
    on top of L62" is no longer needed. The five block alive statements (`hR0_blk` … `hLU_blk`) and `hoAK` … `hoOK`
    are really proved and are gone from the premise list [premise names checked by Claude], and `hblk` is reduced
    to two equalities, `hblkIO`. The block degree lists agree with the Rust code (the constant 80 is above the
    code's 60; the two IO slots at degree 1 are right). What is narrower than first described: (1) the five
    statements are proved for the squeeze lists that a new premise `hbBlk` pins, and their proofs still use the
    unchanged `hD`; nobody has built an instance showing the pins can hold together (the reviewer argues they
    can); (2) the lemma `blkLists_rkSqOk`, which proves the block lists' validity conditions, is not used by the
    top theorem, so `hD` is not reduced yet; (3) `hblkIO` is a new real obligation: the endpoint planes the
    extractor outputs must equal what the block's own boundary opening reads. `hep14` is no longer a separate
    premise; endpoint size 14 now sits inside the shield predicate `hPkC`. **11:22 UTC, committed with the
    wording fixed** (`b809b591` on the working branch, not pushed) [commit read by Claude: two paths, the file
    equals the posted hash, rebuild guard run `e2ed9e141c3f` exit 0].
  - **Open in Lean after L64 (`b809b591`):** `hD` (validity of the squeeze data for all
    parts; the block lists' part is provable from `blkLists_rkSqOk` but not wired, the stage part is L65b and
    needs the csIO link), `hblkIO`, the two stage IO-claims premises (`hTrIIO`, `hTrOIO`), the stage LogUp facts
    (`hLI_stg`, `hLO_stg`), the stage dooms (`hdinS`, `hdoutS`), `hdzW`, `O`, `hzk`. Still to be constructed
    rather than proved: a squeeze schedule `base` and data `D` that meet the pins `hbBlk`, `hslB`, `hb0`, `hbL`,
    `hDe`, and the fact that the registered verifier is the shield one (`hPkC`). Proposed split: Antigravity takes
    `hD`, the pins and `hblkIO`; Claude's L63 takes the csIO link, `hdzW`, the stage IO claims, dooms and LogUp
    facts.
  - **2026-11-17 16:17 UTC, in progress, nothing below is on the working branch yet.** (1) L64 and L65 are now
    elaborated from source independently of their author's build products: the L63 lane merged `b809b591` and
    rebuilt the merged tree (lane commit `1eab49f6`; guard run `f1c958113e75`, exit 0, peak 4.53 GiB; the L64 top
    theorem on the three standard axioms) [reported by the lane agent; the commit is on the lane branch]. (2) The
    csIO link is written on the lane branch (`f52d443b`, `RunStgShieldIOLink.lean`: `ssh_hIO0`, `ssh_hIO1`,
    `ssh_hIOO`), and `hdzW` is half done; not merged, not cross-reviewed. **16:32 UTC: the lane handed back
    with the csIO link and `hdzW` proved** (lane commit `8ccc8a12`; top theorem `sshC_productionReadyL_epP_dz`
    on the L64 theorem; merged tree rebuilt from source, guard run `06bb0469d02e`, exit 0, 161 declarations
    audited, standard axioms) [reported by the lane agent; on the lane branch only; not cross-reviewed]. `hdzW`,
    `hIOI`, `hIOlI` are gone; four premises are added (`hcsI`, which pins the input IO claims to the matrix
    decoded by the checked extractor; the B_in matrix still free with `hXOl`; profile facts `hVi`; `hPlace`).
    The input endpoint's width is 8, not 14 as first guessed. (3) Antigravity posted L66
    (`RunBlkPinsHd.lean`, uncommitted): it reports a concrete `base` and `D`, the pins and `hblkIO` proved, and
    `hD` replaced by four stage-only premises [REPORTED by its author].
  - **2026-11-17 16:29 UTC, L66 cross-reviewed: accept with wording fixes** (`results/zk60_claude_review_20261116/L66_REVIEW.md`;
    the reviewer elaborated the file from source, guard run `7ed8c7cef0a0`, exit 0; all 51 theorems on the three
    standard axioms; uncommitted until the wording is fixed). New top theorem
    `sshC_productionReadyL_epP_pinsHd`, same conclusion. **Really closed:** the squeeze schedule `base` and the
    data `D` are now concrete definitions, the five pins are proved, and the block part of `hD` is proved with no
    new block premise. **Narrower than first described:** (1) `hblkIO` is not discharged but relocated: the
    extractor's planes are now defined as what the block's boundary opening reads, and the stage dooms `hdinS`,
    `hdoutS` are restated for that extractor and carry the coherence; (2) `hD`'s stage part is supplied by four
    new premises (`hSm`, `hlcStg`, `hCsIO`, `hLuStg`), two of them conjuncts of the old `hD`, two sufficient
    conditions; (3) the shield predicate is strengthened to `hPkD` with a new free parameter `dPos0`, and the
    concrete `D` depends on choice witnesses that are not all unique, so later instantiation must prove its facts
    from the specification alone. Net 13 fewer explicit premises (19 removed, 6 added).
  - **Open in Lean after L66 (committed `be99d6f1` at 17:05 UTC with the wording fixed, not pushed) [commit
    read by Claude: two paths, the file equals the posted hash]:** stage facts `hTrIIO`, `hTrOIO`, `hLI_stg`,
    `hLO_stg`, `hdinS`, `hdoutS`, `hLay`, the csIO shape premises and `hCsIO` in the matrix form (Claude's L63,
    which also holds `hdzW` proved on its branch); `hSm`, `hlcStg`, the stage geometry premises, `hPkD` with
    `dPos0` and `hLuStg` (Antigravity's L67); `O`, `E0`, `hzk` last. Split agreed 17:05 UTC. No instance
    satisfying all premises exists yet.
  - **17:16 UTC, the working branch is at `2ae06f54` (not pushed): L66 and the L63 lane's csIO link and `hdzW`
    together, rebuilt from source** (guard receipt `lean-l63-merge4`, run `cfa6de51c00d`, exit 0, peak 4.32 GiB
    [receipt read by Claude]; the L64, L66 and `dz` top theorems on the three standard axioms [lane's report]).
    The `dz` theorem still sits on the L64 theorem; restating it on L66's theorem with `hCsIO` discharged is the
    lane's next step. The lane's seven new files are not cross-reviewed yet (asked of Antigravity).
    **17:30 UTC: Antigravity cross-reviewed the seven files: accept, no finding above a note.**
  - **17:34 UTC, on the lane branch only (`30584634`, checked; not on the working branch yet, which waits for
    Antigravity's L67 commit):** the lane's theorem is restated on L66's theorem as
    `sshC_productionReadyL_epP_pdz`. Gone from the L66 premise list: `hdzW`, `hCsIO`, `hIOI`, `hIOO`, `hIOlI`,
    `hIOlO`. Added: the two IO claim semantics are pinned to concrete forms (`hcsI`, `hcsO`) over three matrices
    that are still free (B_in, B_out and the output endpoint), two width facts, profile facts `hVi`, `hPlace`
    [lane's report; guard run `21f8f95cd775`, exit 0; not cross-reviewed]. `hLay` goes to L67 (it can only hold
    once the word layout is fixed at instantiation). Next in the lane: tie the three matrices to the extractor's
    planes and prove `hTrIIO`, `hTrOIO`, then the dooms and the stage LogUp facts.
  - **18:53 UTC, on the lane branch only (`8c324577`, checked): the stage IO claims `hTrIIO` and `hTrOIO` are
    proved**; new top theorem `sshC_productionReadyL_epP_trO` on L66's theorem [lane's report; guard run
    `671a3cada6f0`, exit 0, 188 declarations audited, standard axioms; not cross-reviewed]. On the way the lane
    corrected its own earlier pin: the input claims are stated on the rows decoded from the opening the run
    actually checks, and `hdzW` is re-proved through a new decoding bridge (unique decoding at the endpoint
    code). B_in and B_out are tied to the openings the extractor's planes read; the output-endpoint matrix stays
    free because the code refuses such a claim. Gone from L66's premise list so far: `hdzW`, `hCsIO`, `hIOI`,
    `hIOO`, `hIOlI`, `hIOlO`, `hTrIIO`, `hTrOIO`. Added: `hcsI`, `hcsO`, two width facts, `hVi`, `hPlace`
    (instantiation facts for L67). **The dooms `hdinS`, `hdoutS` cannot be proved for a free extractor** (they
    read its token words and output row); ruling by the co-coordinator: fix those two fields by construction in
    a wrapper, as L66 did for the planes, with no new premise, and then prove both dooms in full.
    **18:56 UTC: the dooms also need concrete LogUp states.** The lane found that with the two stage lookup
    predicates left free (the L66 premise `hLuStg` only bounds their escape probability) the dooms are
    unprovable, because the stages' lookups are enforced only through the LogUp entrant [ARGUED by the lane
    from the source]. Antigravity's uncommitted `RunStgShieldLu.lean` defines exactly such concrete states with
    their bounds and two bridges for the input stage. The lane is paused until that file and L67 are committed;
    then: merge, instantiate the predicates, add the wrapper, prove `hLI_stg`, `hLO_stg`, `hdinS`, `hdoutS`.
  - **19:14 UTC, Antigravity committed L67 and L67b (`f5b70efe` on the working branch, not pushed):** a concrete
    instantiation of the Shieldstral T128 R13 verifier and run shape (`RunShieldInstP.lean`, top theorem
    `sshC_productionReadyL_epP_shieldInst` on the L66 theorem; its author reports 96 binders eliminated and
    `hLay` discharged) and concrete LogUp states for the two stages with their bounds and four bridges
    (`RunStgShieldLu.lean`) [REPORTED by the author: guarded build exit 0, 100 declarations on the standard
    axioms]. The L63 lane is resumed on top of it.
    **19:30 UTC, cross-reviewed: accept with wording fixes** (`results/zk60_claude_review_20261116/L67_REVIEW.md`;
    both files elaborated from source by the reviewer, guard run `3b7ebee43fe8`, exit 0; 120 declarations on
    the standard axioms). The count holds as a count of binders: 96 removed (58 premises proved, 37 data made
    concrete, and the shield predicate carried on as `hPk0`), 10 new, net 86 fewer; `hLay`, `hSm`, `hlcStg`
    are discharged. **Narrower than first described:** (1) the instantiated theorem is not yet connected to
    the LogUp file or to the profile's domain string: `hLuStg` and its four parameters are still premises
    there; (2) "concrete verifier" holds for shape, geometry and layouts, while the verifier's own checks and
    the block parameters remain free arguments; (3) the two LogUp states are concrete only up to free
    arguments, and only the doom premises force them to be meaningful. The reviewer compared the domain
    string, the token endpoint layout, the vocabulary size, the boundary rows and both LogUp challenge orders
    with the Rust code: they agree; other constants were not compared. **Open after L67:** the stage facts
    (eight of them already proved in the L63 lane on the L66 line; the join onto the instantiated theorem is
    in progress), `hLuStg`, `hLI_stg`, `hLO_stg`, `hdinS`, `hdoutS`; the instantiation leftovers (`hPk0` with
    the free coordinate map `dPos0`, the header-fit fact, the domain, the verifier's free checks); `O`, `E0`,
    `hzk`.
  - **20:00 UTC, the working branch is at `936f4070` (not pushed): the stage part is joined onto the
    instantiated theorem.** New top theorems `sshC_productionReadyL_epP_shieldJ` (the instantiated theorem
    without the eight stage premises the L63 lane had proved) and `sshC_productionReadyL_epP_shieldLu` (the same
    with the two LogUp states concrete and `hLuStg` discharged) [lane's report; check guard run
    `a2ce26b44596`, exit 0, 198 declarations audited, standard axioms; not cross-reviewed]. Added on the way:
    the two pins of the IO claim semantics and one fact about the public input data (`hV`, vocabulary at most
    2^17). **Still open there:** `hLI_stg`, `hLO_stg` (the exact run-level statements they need are written
    down as definitions and assumed nowhere; proving them is the next leg), `hdinS`, `hdoutS` (with the
    extractor wrapper), then `hU`, `O`, `hzk` and the instantiation leftovers. **Ruling on the coordinate map:**
    `dPos0` cannot be derived from `hPk0`, so the lane fixes it to the most-significant-bit-first map
    `shieldDPos0` from its next leg on; the obligation that the registered layout really uses that order then
    sits in `hPk0`, which Antigravity is instantiating.
  - **20:26 UTC: Antigravity cross-reviewed the L63 lane's eleven newest files: accept, three low notes.** It
    also posted L68a (`RunShieldBlkInst.lean`, uncommitted): a further join on top of `shieldLu`, top theorem
    `sshC_productionReadyL_epP_blkLu`, in which its author reports the field, the domain, the coordinate map,
    the block parameters and `hPk0` (from a premise `ShieldRun Rp`) made concrete and `hzk` discharged, leaving
    the four stage premises, `O : ClassifyOpenP`, the header-fit fact and the verifier's check hooks [REPORTED
    by the author: guarded build exit 0, 20 declarations on the standard axioms].
    **20:37 UTC, L68a cross-reviewed: accept with fixes** (`results/zk60_claude_review_20261116/L68A_REVIEW.md`;
    elaborated from source by the reviewer, guard run `c85b4182aa30`, exit 0; 52 declarations on the standard
    axioms; uncommitted until the wording is fixed). The join is real: 22 binders of `shieldLu` gone, 4 added.
    **What it does and does not establish:** (1) the shield premise is gone because the block verifier is now
    *defined* in Lean (`shdP_Pk0`), so the theorem is about one Lean-defined verifier, with one IO pair and one
    opening check for all 26 blocks; that this is the registered Rust verifier is the model-to-code
    correspondence, which no Lean file proves; (2) `hzk` is only the numeric bound on the zero-knowledge error
    (at most q·2^-128 + R·2^-120 up to 2^64); the zero-knowledge property itself is still assumed, as the field
    `O.zk` of the open `O`; (3) a new premise `ShieldRun Rp` (the run's 26 calibrations are the export's), true
    of the real run by construction. The reviewer compared the layout's bit order with the Rust code: it agrees
    for the token and width axes and the RoPE flip bit; the slot, group and hidden axes were not determined.
    Sol then compared those remaining axes with the Rust read-only (20:47 UTC, in the coordination file, with
    the file hashes it used) and reports that they agree at this geometry [CHECKED by Sol; not re-derived by
    Claude]. That is axis order only; it does not settle the verifier's hooks. Antigravity then edited the file
    for the review's requests (20:49 UTC, still uncommitted). Claude re-checked that version at 23:31 UTC: it
    does not build as it stands, because one redundant `rfl` on line 601 reports an error; with that line
    removed in a copy it elaborates clean, the top theorem's statement is unchanged, and all ten printed
    declarations are on the three standard axioms [CHECKED: one file, against existing build outputs, not
    the full root build; `results/zk60_claude_review_20261116/l68a_recheck/`]. Antigravity ran out of credits
    before fixing it (Victor, 2026-11-18: out for about three days). Claude removed the one line, ran the module
    build, the whole-root build and the axiom print (green, guard run 2438abc7f99f) and committed the file as
    4db41d46 at 07:23 UTC on 2026-11-18, with Antigravity named as the author. Sol was asked to be the second
    reader of Claude's Lean and speed work until Antigravity is back. Sol took the role the same hour: its second
    read of L68a at 4db41d46 (07:30 UTC) confirms the binder comparison and five geometry fields against the
    native verifier, and adds one open correspondence item (Lean takes the block pre-checks as passed; the Rust
    checks shape, layout and public data before absorbing) [CHECKED by Sol; not re-derived by Claude].
  - **L63 leg 6 (2026-11-18, perf 9e8218ad):** the extractor wrapper and the plane identity are proved. New tops
    `sshC_productionReadyL_epP_blkIO` (the input token words and the output row are fixed by construction, so the
    extractor is no longer a free argument there) and `..._blkIOv` (verdict at most 1 proved from acceptance).
    No premise added. The lane's four remaining premises are the two LogUp premises and the two doom premises
    [PROVED in Lean: merge15, guard run 628ccb8f9fe5; second read by Sol at 08:06 UTC: the two tops keep blkLu's
    conclusion and LogUp premises, the restated doom premises have the same content on accepted runs, and the
    wrapped extractor takes only one field from its base].
  - **L63 leg 7 (2026-11-18, perf f970bba3):** groundwork for the input LogUp premise, with no premise removed and no
    new top: the stage planes are shown to be base-field values, the concrete input-stage layout is built, and the
    premise is reduced to one defined predicate about the stage's slots that is still to be proved (the lane's
    estimate: 1,200 to 1,800 lines) [PROVED in Lean: merge17, guard run 622a715dfb26; single-reader until Sol
    reads it]. Two premises on public data will be added when it is joined, by coordinator ruling at 08:17 UTC: the
    vocabulary is exactly 131,072 (the instantiation had fixed that number where the public input carries its own),
    and the verifier's folded-embedding function really is the fold of the public embedding (interim; to be
    removed by fixing it to a Lean definition).
  - **L63 leg 8 (2026-11-18, perf b7abed69):** the input LogUp premise is proved down to one remaining fact. At every
    accepted run with no doomed define entrant, the input stage's two zero-check relations hold for the concrete
    layout, and the premise's exact conclusion follows from one defined predicate about the LogUp sums that is
    still to be proved. The embedding-fold premise is shown to be satisfiable. Still no premise removed from the
    top and no new top theorem; the concrete stage numbers are still hypotheses of the lemmas; the output LogUp
    premise and both doom premises are untouched [PROVED in Lean: merge19, guard run 06062b37bbae; single-reader
    until Sol reads legs 7 and 8]. The next leg starts at the morning check-in, to pace usage.
  - **L63 leg 9, 2026-11-18 16:10 UTC: the first lane premise has left the top.** New top
    `ZK60.ProtocolClassify.sshC_productionReadyL_epP_blkIOl` (`RunStgShieldTopL.lean`, perf 5468cadc): the input
    LogUp premise `hLI_stg` is now PROVED inside it, in the direct form, from the two LogUp sum facts and the
    registered stage numbers, which are also proved. Against the previous top it adds exactly the two premises
    ruled on 2026-11-18 (`Rp.inp.V = 131072`, and the interim `hEmb` on the embedding fold) and nothing else;
    the coordinator compared the two premise lists by script (one removed, two added, none changed, same
    conclusion). **Still premises:** the output LogUp premise `hLO_stg` and the two doom premises `hdinX`,
    `hdoutC`, plus the interim `hEmb` [PROVED in Lean: merge22, guard run 025b5dda6a25, exit 0, 14 tops on
    propext, Classical.choice, Quot.sound; single-reader until Sol reads legs 7 to 9]. The lane also found that
    the interim form the coordinator had allowed as a fallback would have assumed more than the protocol gives;
    it was not used.
  - **L63 leg 10, 2026-11-18 20:47 UTC: no premise removed; one accepted premise turns out to be wrongly
    shaped (finding L63-11).** The newest top is still `sshC_productionReadyL_epP_blkIOl` (perf 588c4a14), same
    premises. The input doom premise `hdinX` is PROVED for every accepted run whose input commitment decodes to
    one codeword matrix (`shd_hdinX_blk`; merge23, guard run e08de5a70733, exit 0), and a first piece of the
    output LogUp premise is proved (merge24, guard run 6d06daaef3b3, exit 0; 16 tops on propext,
    Classical.choice, Quot.sound). In the other case, a commitment far from the code that is accepted anyway,
    the extractor returns zero tokens and the premise asks for a doomed input-stage state that need not exist
    [ARGUED by the lane, the Lean definitions read by the coordinator; not proved]. This is not a hole in the
    protocol: that case is the column test's low-probability event, and the endpoint part of the cover already
    sends it there. The Lean cover splits the cases in an order that hands the far case to the input stage.
    **Consequence:** the doom premise as written on the tops since L68a cannot be discharged as it stands.
    **Ruling (Claude, co-coordinator):** the narrowed premise is not accepted to rest on; the next leg adds a
    reordered cover in new files (closeness first, then the input stage) and a new top with the same
    conclusion; no existing file of Antigravity's is edited; the same check is made for the output doom premise
    before work on it. Single-reader until Sol reads legs 7 to 10; Antigravity is asked to review on its return.
  - **L63 leg 11, 2026-11-19 00:40 UTC: the input doom premise has left the top; two lane premises remain.**
    New top to rest on: `ZK60.ProtocolClassify.sshC_productionReadyL_epP_blkCl` (`RunStgShieldClTopL.lean`,
    perf a05b482c). It is the previous top with `hdinX` removed and nothing else changed: the coordinator
    compared the two statements from the Lean text (12 premises against 11, only `hdinX` missing, same order,
    same conclusion, same section variables) [PROVED in Lean: merge25, guard run aaeaf3cd2323, and merge26,
    guard run 6d2f394bcfd9, both exit 0; 20 tops on propext, Classical.choice, Quot.sound]. The route is the
    reordering ruled in L63-11: the 33 theorems of the chain are copied as generated twins in 16 new files, the
    joint cover sends the far-from-the-code case to the column test first, and the input stage is asked for a
    doomed state only when the commitment is close; no existing file was edited. That the old bad event does
    not already exclude the far case, and that the output doom premise is not hit by the same case, are both
    ARGUED from the definitions, not proved. **Still premises:** the output LogUp premise `hLO_stg` (first
    step proved) and the output doom premise `hdoutC`, plus the interim `hEmb` and the ruled `V = 131072`.
    **Debt:** about 9,000 generated lines duplicate the old chain; folding the change into the original
    theorems means editing Antigravity's files and waits for its return. Single-reader until Sol reads legs 7
    to 11.
  - **L63 leg 12, 2026-11-19 05:04 UTC: no top changed; `hLO_stg` is reduced to one fact and the top.**
    Seven new files (2,122 lines, perf 3ab97bc8, checks merge27 and merge28 green, guard runs 382a9074d73c
    and 05b947a9060c) prove the clause equations of OUT-C's three LogUp slots, the join to `hLO_stg`'s
    conclusion and the first of its two sum facts. Left for `hLO_stg`: the OUT-C zero-sum row at the
    readings (350 to 450 lines) and the new top (150 to 250 lines); that the join fits the premise as the
    top states it is shown only when that top builds. `hdoutC` grows to 600 to 1,000 lines because the full
    OUT-C layout moved to it.
  - **L63 leg 13, 2026-11-19 05:33 UTC: the output-side LogUp premise has left the top; one lane premise
    remains.** New top to rest on: `ZK60.ProtocolClassify.sshC_productionReadyL_epP_blkLO`
    (`RunStgShieldClTopLO.lean`, generated; perf 3797da25; check merge30 green, guard run 17eda5ea7728; axioms
    propext, Classical.choice, Quot.sound). It is blkCl with `hLO_stg` removed and nothing else changed
    [coordinator's own comparison of the Lean text: 11 binders against 10, conclusion identical]. Premises
    left: the output doom premise `hdoutC` (600 to 1,000 lines by the lane's estimate; its first piece is
    proved; three of its seven items are argued only, not yet in Lean), plus the interim `hEmb` and the ruled
    `V = 131072`. Leg 12's join did not fit the top as stated (a bound that is false at the concrete numbers);
    leg 13 proved it again without the bound. Next leg: 2026-11-20 00:12 UTC. Single-reader until Sol reads
    legs 7 to 13.
  - **L63 leg 14, 2026-11-20 00:58 UTC: six of the seven facts behind `hdoutC` are proved; the top is
    unchanged.** perf 5dbd1b2f (not pushed); checks merge31 and merge32 green (guard runs e64582382748 and
    86ccdf828547). Six new files, 1,328 lines: DZC's division clauses, the IO-in equation, the PD margin (it
    was argued only; Lean agrees), AllBytes from the LogUp state, the layout with the assembly of the facts,
    and the plane identity behind the tie to `xC`. Left: TZC hosting SS (450 to 550 lines, argued only), the
    assembly lemma (about 250) and the new top (300 to 400). The agent found that `hdoutC` is false for
    public output constants outside the valid range (the code's encoding wraps); the bounds are to come from
    the top's existing open-conditions binder, which is shown only when the new top builds. Leg 15 is
    running on exactly that. Single-reader: legs 7 to 14.
  - **L63 leg 15, 2026-11-20 01:43 UTC: `hdoutC` is proved; no lane premise is left on the top.** New top to
    rest on: `ZK60.ProtocolClassify.sshC_productionReadyL_epP_blkOC` (`RunStgShieldClTopOC.lean`, generated;
    perf 8e7e3328, not pushed; check merge33 green, guard run fff26417a048; 22 tops on propext,
    Classical.choice, Quot.sound). It is blkLO with `hdoutC` removed and nothing else changed [coordinator's
    own comparison of the Lean text: 10 binders against 9, conclusion identical]. Three new files, 889 lines:
    TZC hosting SS, the assembly at a reading, and the doom bridge with the tie to `xC`. The two arguments
    that were only argued (TZC hosting SS; no closeness hypothesis for the output side, finding L63-11) are
    now Lean-checked, and the range bounds do come from the existing open-conditions binder. **Left on the
    top:** the interim `hEmb` (leg 16 is running to remove it by a concrete Lean fold, which specialises the
    top to the verifier that uses that fold), the ruled `V = 131072`, the open conditions
    `O : ClassifyOpenP` including `O.zk` (Antigravity's L68b), and the section hypotheses (header fit and
    the like), which leg 16 lists in its handoff. Single-reader: legs 7 to 15.
  - **L63 leg 16, 2026-11-20 01:59 UTC: `hEmb` is proved for a concrete fold; L63's own premises are all
    gone.** New top to rest on: `ZK60.ProtocolClassify.sshC_productionReadyL_epP_blkEF`
    (`RunStgShieldClTopEF.lean`, generated; perf f375e73d, not pushed; check merge34 green, guard run
    36992c58380a; 23 tops on propext, Classical.choice, Quot.sound). It is blkOC applied to the concrete
    fold `embFoldL` (`RunStgShieldEmbFold.lean`, 94 lines: rows padded to 4,096 columns with zeros, entries
    by `Fp.fromI64`, summed against the eq table), so it speaks about the verifier that uses that fold
    [coordinator's own comparison of the Lean text: after the substitution the only difference is `hEmb`].
    blkOC is kept as the top for an arbitrary fold. **What blkEF still assumes:** the ruled `V = 131072`;
    the setting (`2^20 <= Lq < 2^64`, `ShieldRun Rp`, header fit); the open obligations `O : ClassifyOpenP`
    (completeness contracts, honest refusal, zero knowledge: Antigravity's L68b, not started); and it holds
    for every value of the verifier's free hooks (`checkOpening`, `bndCheck` and the like), which is part of
    the Lean-to-Rust correspondence. **Checked in the Rust source, 2026-11-20 02:00 UTC [CODE-READ by the
    coordinator]:** the Rust verifier computes the embedding fold itself from the public table
    (`stage_in_c.rs:254-260, 427-428`; `classify.rs:569-607`), with the same index order, padding, entry map
    and field as `embFoldL`, and the table is bound to the statement by its digest (`classify.rs:1113`);
    the Shieldstral policies fix the vocabulary at 131,072 and any other size is refused
    (`classify.rs:167, 216, 662`). So blkEF is the right model and both rulings stand. One remark: the
    default Rust path sums by exact integers and reduces once, where the Lean models the per-word fold;
    their agreement is Rust's own gate, not a Lean fact. Next Lean leg after 00:00Z 2026-11-21: a scoping
    of `O`, unless Antigravity is back. Single-reader: legs 7 to 16.
  - **Speed lane while Antigravity is out:** its slot 18/14 breakdown is committed (25e70c25) on Sol's second read
    (468): the solo-block numbers and the flat stream cadence stand, three figures in its README are corrected in a
    note beside it, and the claim that the first rounds are memory-saturated is a hypothesis awaiting the roofline
    test K1. Research tick 12 found that one kernel idea from tick 10 (line values by additions) was already
    measured in A27 on 2026-11-07 and gives nothing on the shipped kernels; that estimate is withdrawn.
  - **Roofline tests K0 and K1, 2026-11-18 15:31 UTC (`results/zk60_k0k1_roofline_20261118/README.md`; one clean
    run, uncommitted, no second reader):** the memory-saturation hypothesis is not supported. A kernel with the
    shipped kernel's loads and a trivial body takes 0.11 (slot 14 shape) and 0.19 (slot 18 shape) of the shipped
    kernel's time over the later rounds, so those rounds are limited by the polynomial body, not by table loads
    [MEASURED, at the Shieldstral R13 shapes; the 8B kernels hold fewer tables per thread]. The fold kernel runs
    at the copy roofline, about 700 GB/s, and is a third of slot 18's second window at the 8B shape [MEASURED].
    Consequence: ideas that cut table traffic are bounded by the loads' 11 to 19% share and move down; ideas that
    cut the body's arithmetic or its register pressure move up. No speed gain is claimed from this; it says where
    to look.
  - **Follow-up bench rounds K3 to K5, 2026-11-18 15:39 and 15:46 UTC (same folder; clean, one run each,
    uncommitted, no second reader):** splitting the kernel's sum of terms into four kernels, with identical
    output, takes 0.77 (slot 14) and 0.87 (slot 18) of the shipped kernel's later-round time at the Shieldstral
    R13 shapes, and 0.91 and 0.97 at the W16R2_8B shapes [MEASURED]. By the thresholds fixed beforehand that is a
    pass at one Shield shape and no pass at 8B. Roughly 2 to 3% of block GPU at the Shield profile and about 1%
    at 8B [DERIVED, not measured end to end], so it is recorded (H162) and gets no implementation lane now.
    Research tick 15 then counted the kernel body from its generated source: in the big rounds the shipped
    kernel is 1.4 to 2.6 times an optimistic floor built from the measured operation costs, and a fifth to two
    fifths of the bench total is the small tail rounds, which cost in proportion to the body's size by a
    mechanism not yet identified [DERIVED from measured medians]. **Reading (Claude, co-coordinator): the two
    big zero-check kernels hold no hidden large factor; each kernel idea left is worth one to a few percent of
    block GPU, so a large speed gain has to come from proving less per token or from hardware.**
  - **Research tick 16, 2026-11-18 19:52 UTC (reading of the 2026-11-17 breakdown and `metal.rs`; nothing
    run; the sums re-run by Claude):** the rounds past the fifth, over all 12 device slots, are 4.7 to 20.5% of
    solo block GPU at W16R2_8B, central 10.8% [DERIVED from measured medians and the measured knob probe];
    about 6.1% at Shieldstral [EXTRAPOLATED]. On the two-lane stream about two thirds of that is already hidden
    by the other lane, and moving the last three rounds per slot to the host left the cadence flat (3.7455 s
    against 3.7576 s) [MEASURED, 2026-11-17]. A tail-only project is therefore worth about x1.01 to x1.02 on
    cadence [DERIVED] and gets no lane. Research tick 17 (23:52 UTC, reading only) then explained the gap
    between the batched and unbatched arms of that breakdown: the batched arm does the transcript step and the
    partial reduction on the device, inside its timed interval, and the unbatched arm does them on the host,
    outside it; at equal round count the difference is 11.3 ms per block at W16R2_8B and behaves per round, not
    per batch [DERIVED; two small slots do not fit cleanly, so not settled]. A faster transcript step is again
    worth about x1.01 to x1.02 on cadence. **The kernel topic rests here:** six kernel items are recorded at
    one to a few percent each, none is scheduled, and the research ticks move to the protocol items (proof-state
    reuse across tokens, then TensorZKP's timings).
    **Tick 18, 2026-11-19 03:50 UTC (proof-state reuse across tokens): dropped as a speed item.** No published
    design carries proof state from token to token with hidden activations [reading, 7 searches, two papers in
    full]; the window proof already processes each position once, so carried state would buy streaming latency
    only, not proved tokens per second [DERIVED from the project's records].
    **Tick 19, 2026-11-19 07:53 UTC (TensorZKP, full read): no effect on the shipped prover.** The paper has
    no zero knowledge, runs on an H100 over a 31-bit field, and writes only two-table degree-2 sums and scalar
    folds as 8-bit matrix products; those stop at 70 to 80% of memory bandwidth [DERIVED from its printed
    timings]. Our zero-check slots have 19 to 36 tables at degree 4 to 5, so it gives them nothing. No bench
    is scheduled; two local counts (queue items 36 and 37) decide whether the tensor-core tracks stay open.
    **Tick 20, 2026-11-19 11:50 UTC (the first count): the tensor-core sumcheck track G1 is dropped.** Plain
    two-table degree-2 slots hold 1.93% of block GPU at W16R2_8B and 1.12% at Shieldstral [DERIVED from the
    MEASURED slot medians], and the matrix-product claims run on the host in 12 to 15 ms per block. The
    second count (the split of the commit slots, which bounds the dense-encoder track G3) is next.
    **CORRECTION, tick 21, 2026-11-19 15:52 UTC: the "block GPU" totals of the 2026-11-17 slot breakdown are
    too high, so every share of block GPU quoted from it on this page is too low.** The breakdown ran with
    `HL_METAL_TIMING=1`, which makes each commit re-run its three parts on scratch buffers for diagnosis
    (`metal.rs:2148-2179`), and the analyzer counted those re-runs in the total under a wrong label ("store
    fold with pads") [verified in the source by the coordinator]. Production does not run them. Corrected
    block GPU: **91.46 ms at W16R2_8B (was 117.285) and 174.25 ms at Shieldstral (was 248.899)** [DERIVED: the
    total minus the diagnostic records; it assumes a commit takes the same time with timing off, which no
    trace has checked]. Multiply any share above by 1.28 (8B) or 1.43 (Shieldstral): the sumcheck slots are
    69% and 56% of block GPU, the two commits 30.5% and 43.7%. Milliseconds, ratios between slots and every
    stream cadence measurement are unaffected. The G1 drop stands (2.47%). "The kernel topic rests" is
    provisional until the next tick has restated each thresholded decision with the corrected shares.
    The count itself: the transforms are about 87% of a commit, and the dense-encoder track G3 stays
    unscheduled. Coefficient-form rows (about 9% of block GPU, changes every commitment root) are added to
    `ZK60_NEXT_PROTOCOL_CANDIDATES.md` as candidate G for a later profile version.
    **Tick 22, 2026-11-19 19:54 UTC: the recheck is in and no thresholded decision flips, so "the kernel topic
    rests" stands.** On the corrected totals the one kernel item above 5% is still the padded-pair skip at
    Shieldstral (5.7 to 10.5% of block GPU; test specified, not scheduled). The corrected totals are now
    supported by two records without diagnostic buffers (one-block log 93.48 ms; stream commit spans 13.4 to
    13.8 ms). **A second conversion error is withdrawn:** earlier ticks treated the stream as GPU-paced and
    turned a share s into a speedup of 1/(1-s). It is not GPU-paced: 29 to 32% of a prove call has no prover
    buffer executing, and production solo GPU is 2.93 s of the 3.75 s cadence. A per-block saving of x ms is
    at most x*32/3745.5 of the 8B cadence, so coefficient-form rows are at most x1.08 and a free transform at
    most x1.26 on the stream. A new lead (host matmul claims in the gap before slot 14) has a ceiling of 4.7%
    of a prove call, not the handoff's 10.5%, and is queued as reading only.
    **Tick 23, 2026-11-19 23:52 UTC:** a transform-only bench for the commit kernels is specified (N0 to N5)
    and not scheduled. One source reading, confirmed by the coordinator (`metal.rs:299-300`): at W16R2_8B the
    production forward transform is not pruned, because the hiding pads push the row's extent 280 words past
    half the code length, while the diagnostic re-run is pruned; estimated cost about 1% of block GPU, noted
    for the owner of A28. The researcher now turns from kernel leftovers to an inventory of the host-only
    time of a prove call (1.0 to 1.2 s of 3.7 s), the largest pool left.
    **Tick 24 and test L2, 2026-11-20 04:23 UTC:** the inventory is in. No host class has changed since the
    Batch 7 reference; the ten classes sum to 888 ms of a 3.81 s prove call, so with all of them gone the call
    would still be about 2.92 s against the 2.56 s target [COUNTED from the saved traces, script re-run by the
    coordinator]. The host-only pool cannot reach the target alone; GPU work has to leave the call too.
    The tick's one no-code test was run the same hour by the coordinator, with its pass rule posted first:
    **A13's window (`HL_D55_AHEAD`) does not pass on the prover-paced stream at 4, 8, 16 or 32 and stays off**
    [MEASURED, two guarded runs `d6e69de757a5` and `cf6b66ae3a32`, 6 passes each, arms interleaved;
    `results/zk60_l2_ahead_window_20261120/README.md`]. At 16 the four-request cadence was lower in 4 of 6
    pairs (-2.2%), an end effect of the last request; on eight-request streams the steady gap at 8 was -0.25%
    (4 of 6) and at 16 +1.1%. Work that uses the GPU comes back as a longer prove call when moved into the
    sealing turn. Base arm of run 2: steady gap 3.80 s (34.0 tok/s steady mean), serial commit phase 0.21 to
    0.23 s per prove call, and a sealed request waits 0.34 to 0.49 s for the prover.
    **Speed task A35, 2026-11-20 05:09 UTC: PASS and replicated; on the working branch (`cbcb5f46`, not
    pushed) with its switch OFF by default, waiting for a ruling.** With `HL_A35_BOUNDS_AHEAD=1` a served
    request makes its prove call's commit phase (the boundary commitments) before it takes the prover turn,
    beside the previous request's forks. Steady gap per request [MEASURED, 6 passes, arms interleaved, both
    orders, rule fixed before each run]: -4.98% in the agent's run (guard `5dee3dc2932b`, loaded machine)
    and -6.27% in the coordinator's replication (guard `0ae1db4e76ef`, quiet machine: 3.814 to 3.560 s),
    lower in 6 of 6 passes both times; -6.61% at three lanes (first look). The test's steady mean goes from
    34.07 to 36.27 tok/s on the synthetic W16R2_8B stream. No committed, absorbed or written word changes
    under seeded generators (new test, CPU and Metal); the suite result is unchanged (the same three named
    failures as before). Not shown: Shieldstral, trained weights. **Open:** the reviewer's ruling on running
    one request's commit phase while the previous request's forks run (review finding F4's sentence stays
    literally true), then the default. Write-ups: `results/zk60_a35_bounds_ahead_20261120/README.md`,
    `results/zk60_a35_replication_20261120/README.md`.
    **Tick 25, 2026-11-20 07:53 UTC (GPU witness generation): nothing to build now.** No published GPU
    witness design fits the sealing chain; the weight products are already on the GPU (17% of the solo
    sealing pass), and the host work a device builder could take is 0.667 s of 2.183 s, same words out.
    Bound [MEASURED, the A35 replication]: with the switch on, a third lane changes the steady gap from
    3.560 to 3.519 s, so no sealing-side saving is worth more than about 1.1% of the stream on this machine
    until the forks phase gets shorter. The tick's lead (memoising the per-block weight scan) was read by
    the coordinator and not scheduled for that reason. Handoff:
    `research/zkp-efficiency/handoffs/20261120-claude-tick25-gpu-witness.md`.
    **Tick 26, 2026-11-20 11:54 UTC (committed padding): not a speed item at 8B, a protocol-level lever at
    Shieldstral.** Padded columns are 5.96% of a block's committed rows at W16R2_8B (at most 1.4% of the
    stream cadence if all were dropped) and 26.96% at the installed W16R2 Shieldstral profile (plane lists
    inferred, not counted). Dropping them changes the commitment and the verifier, so it is recorded as
    candidate H in `ZK60_NEXT_PROTOCOL_CANDIDATES.md` and nothing is scheduled. Handoff:
    `research/zkp-efficiency/handoffs/20261120-claude-tick26-padding-words.md`.
    **Tick 27, 2026-11-20 15:52 UTC: a correction to tick 26 and to this page's earlier wording.** Tick 26's
    "at most 11.8% of block GPU at Shieldstral" paired the W16R2 padded fraction with the commit time and
    block GPU (174.25 ms) of the older R13 Shieldstral block. The slot breakdown of 2026-11-17 measured
    `w16r2_8b` and `r13_shield` only; the installed W16R2 Shieldstral block has never been measured on its
    own. With its commit time taken as the 8B block's (same rows; DERIVED, not measured) the ceiling is 4.5
    to 5.1% of the measured Shieldstral stream cadence (4.381 s per request, benchmark of 2026-11-13, older
    binary). Shieldstral shares quoted from ticks 11, 21 and 22 rest on the same R13 block and are being
    re-paired (queue item 47). Handoff:
    `research/zkp-efficiency/handoffs/20261120-claude-tick27-shieldstral-padding-stream.md`.
    **The installed Shieldstral block measured on its own, 2026-11-20 15:56 UTC [MEASURED, four guarded
    runs, reference binary, controls within 3.1% of 2026-11-17]:** block GPU about 94 ms (94.06 and 98.98
    by arm; the 8B control gave 94.29 in the same session), commit A + H 28.95 ms over ten warm passes, all
    slots 65.7 ms, and the 8B block's slot structure (slot 14: 37 tables against 36 at 8B and 64 at R13
    Shieldstral). So the installed Shieldstral block costs what the 8B block costs; 174.25 ms is the R13
    block. The padding ceiling at this profile is 4.6% of the 2026-11-13 stream cadence. Not shown: a
    Shieldstral stream on the current binary. Write-up:
    `results/zk60_w16r2_shield_block_20261120/README.md`.
    **The app's stream against the harness stream, 2026-11-20 17:39 UTC [RECOMPUTED from the 2026-11-13
    logs; a question for the app's lane, not a finding]:** the app still runs the prover binary built on
    2026-11-12 (`zk60_classify.a30a31`), without A33 or A35. Per block of stream cadence the app spends
    147.7 ms (3.839 s over 26 blocks, proof-only) and the harness stream 111 to 119 ms (3.560 to 3.814 s
    over 32 blocks), with the same GPU cost per block. Not like for like (trained weights, six whole
    requests side by side, the classifier's head). As a ceiling, the harness's rate would give 41 to 44
    tok/s on the app's 26 blocks against 33.3 proof-only on 2026-11-13. The likely cause is the shape
    of the stream [CODE-READ]: the app proves six whole requests side by side, each with its own sealing
    pass, where the harness puts one request's forks in the prover turn and the next requests' sealing
    beside it. A33 alone will not close it (about 1% of the time a request holds a lane). Asked of
    Astra at 17:39 and 17:41 UTC: a GPU trace of the app's stream at W16R2, and whether the classifier's
    run can take the harness stream's shape.
    **Tick 28, 2026-11-20 19:54 UTC [re-pairing, no run]:** every "Shieldstral" share in research ticks 11
    to 26 was an R13 figure. At the installed profile the commit is the 8B block's work and the only
    difference is the D padding (at most 2.31 ms per block: one more table and one more degree at slots
    0, 1 and 14). As shares of the 2026-11-13 cadence, ceilings: traffic-floor NTT kernel 6.9%,
    padded-pair skip 3.3 to 6.1%, dropping the inverse transform 4.8%, padded commit rows 4.6%. No
    decision changes and nothing is scheduled.
    **The harness stream at the installed profile, 2026-11-20 19:59 UTC: NOT RUN.** The stream test's
    fixture has no test-only run identity for the W16R2 Shieldstral block, so the leaf refused in 5 s
    (a test-source change and a rebuild are needed; not scheduled). The 8B control of the same sequence
    gives a third sample of the A35 switch [MEASURED, three passes]: 3.774 s off, 3.552 s on, -5.83%.
    Write-up: `results/zk60_shield_stream_20261120/README.md`.
    **Correction, 2026-11-20 22:05 UTC, to the 17:39 paragraph above [RECOMPUTED after Astra's timing
    reconstruction]:** "147.7 ms per block, 24 to 33% above the harness" used the app's whole proof window,
    which includes 7.2 s before the first writer is ready. With the six lanes full the app takes 3.50 to
    3.54 s per request, 134.5 to 136.2 ms per block: 13 to 22% above the harness, 36.2 to 36.6 tok/s, GPU
    about 70% busy (derived). Astra's code reading: the classifier cannot take the harness stream's shape by
    a setting; six forks inside one request would be a new registered statement (D63 applies), so the 41 to
    44 tok/s ceiling needs a protocol change. Astra is taking the GPU trace of the app's stream
    (`results/zk60_astra_20261026/app_stream_timing_20261120/`); no result yet.
    **The app's stream traced, 2026-11-20 22:11 UTC [Astra MEASURED; per-lane reading RECOMPUTED by the Claude
    co-coordinator, `results/zk60_claude_review_20261116/app_trace_lanes.py`]:** 24 proofs in 86.5 s, 35.5 tok/s
    proof-only; 39.5 tok/s with the six lanes full (completions come in four groups of six, 19.4 s apart).
    Inside the 26 blocks the app does a block per 102 ms of wall, better than the harness stream (111 to
    119 ms). The loss is elsewhere: each request spends 3.4 s outside its blocks, at the same time on all six
    lanes, and the lanes move in step, so the GPU is idle 21% of the time even with all six lanes in blocks
    (3% expected if their phases were unrelated). GPU busy 72.7% from the first block to the last proof;
    never idle would be 55.6 tok/s (a ceiling, not a forecast). Why the lanes fall into step is not
    determined. Proposed to Astra, settings only: 8 and 9 lanes beside 6. Not run.
    **Second reads, 2026-11-20 22:18 UTC:** Sol (18:32Z) and Antigravity (22:16Z, back online) second-read
    L63 legs 7 to 16, the Rust reading behind rulings L63-7 and L63-8, the A35 change and the macOS liveness
    patch `cd1de293` (one correction by Sol), and accept them. A35 goes ON by default for the served stream
    on those two reads. **Landed 22:58 UTC: the working branch is at `f323bb82` (not pushed)** with the
    default on (`HL_A35_BOUNDS_AHEAD=0` turns it off) and the liveness patch merged; build, no-feature
    check, the A35 off/on tests, s25, s26, the a22 CPU tests and the liveness tests all exit 0 under the
    guard; the full suite was not run. Antigravity has reclaimed `O : ClassifyOpenP` (L68b, L68c); Claude's next L63 leg takes the
    header-fit hypothesis instead.
    **CAVEAT on every app figure above, 2026-11-20 22:48 UTC [CODE-READ by Antigravity and by Claude]:** the
    installed app runs with `HL_METAL_QUEUES=thread` (`shieldstral_fast_runtime.py:163`, `deploy.json`), but
    the 2026-11-12/13 benchmark runner and today's trace did not set it and ran on the one shared Metal
    queue. So 33.3 and 35.5 tok/s proof-only, 4.381 s with checks, 39.5 tok/s with the lanes full, the
    72.7% GPU busy share and the in-step reading all describe the shared queue. Whether the installed
    setting is faster or slower at this profile is not known. Asked of Astra: the two queue modes side by
    side at six lanes first, then eight lanes (the server's maximum; nine is refused).
    **Tick 29, 2026-11-20 23:52 UTC [records and source read, no run]:** at the app's W16R2 profile only
    6 lanes x 5 threads (the stream) and 3 x 10 (one post) were ever measured, both on the shared queue;
    6 x 5 was inherited from R13 and never re-tested. Lane count looks like a small lever (eight lanes about
    +3.5% by a two-point fit). The lanes sit together because the 300 ms start stagger is carried through
    every wave (completion groups are 1.5 s wide, five steps of 300 ms) and is half a block period at this
    profile. Proposed to Astra, settings only, not run: the two queue modes first, then a 100 ms stagger
    (one sixth of a block period), then eight lanes.
    **Tick 30, 2026-11-21 03:55 UTC (what a lane does on the host; the script re-run by Claude on Astra's
    trace, figures reproduce):** a lane's block takes 611 ms, of which 307 ms is waiting for its GPU
    commands and 303 ms is host work with no GPU command outstanding [DERIVED]; about 14 of 32 cores are
    busy on average [DERIVED]. So the app's six lanes are limited by the host as much as by the GPU.
    **CORRECTION to earlier lines on this page and to what Victor was told: A33 and A35 do not reach the
    app.** The classifier's sealing pass calls the old repeating check (`classify_cli.rs:591` [read by
    Claude]) and A35's fork format is refused for classifier profiles [Astra's review], so rebuilding the
    app binary from the working branch gains nothing from either. Three candidates for the app's stream,
    none measured: (1) run the next block's transcript-free first half during the current block's GPU
    waits (59 to 101 ms of host work per block; a queue model gives 3 to 11% as a ceiling); it keeps the
    proof format but needs a second randomness stream, so it stays behind a switch, default off, until
    Sol reviews the split; pass and kill rules are pre-registered in the coordination file. (2) A33's
    de-duplicated check in the classifier's sealing pass, at most 1.9%. (3) Seal-ahead, a setting: 4% as a
    prior from R13, 18% as a ceiling, up to 43 GiB more memory; proposed to Astra as a fourth arm.
    **05:13 UTC: candidate (1), named A36, is implemented on a branch (`worktree-agent-a3be4019d2dca3765`,
    head `3879c471`), NOT merged and NOT measured.** Its correctness gate is green [guard receipts read by
    Claude: the classifier tests pass with the switch off and on, and receipts made with it on are accepted
    by the unchanged verifier; tested at a small shape only so far]. It adds a second operating-system
    seeded randomness stream and edits the pinned count of such streams in a security test, so it waits
    for Sol's review before any merge. The one-lane timing test at the app's shape is defined in the
    coordination file (pass: at least 4% faster in both of two paired runs).
    **05:34 UTC: the one-lane test PASSED by that rule [MEASURED once; recomputed by Claude from the raw
    results].** Prove call of one classifier request at the app's W16R2 shape, one lane, in run order off,
    on, on, off: 8.942, 8.510, 8.464, 8.901 s (medians of three timed requests each), so 4.83% and 4.91%
    lower with the switch on; all eight receipts made with the switch on were accepted by the unchanged
    verifier at the real shape with the GPU in use. NOT shown: anything at six lanes (the app's
    configuration), where the gain may be larger or smaller. That six-lane stream test (pass: at least 3%
    more tokens per second with the lanes full) is requested of Astra. A36 remains unmerged.
    **Tick 31, 07:55 UTC (the 42.8 ms host gap between two blocks of a lane):** the largest piece is the
    write of the finished segment to disk (write, full flush, rename, SHA-256), which runs on the request
    thread and needs nothing from the transcript [CODE-READ by the tick and by Claude]. It took 25 ms a
    block at the older R13 profile [MEASURED, retained A24 record]; no phase table exists at the installed
    profile. The installed profile's segment is 25,570,824 bytes [MEASURED, from the A36 test's logs; the
    tick had assumed 18 MB], so by size the write is about 20 ms a block there [DERIVED]: about half the
    gap, worth about 2% of stream throughput if a writer thread takes it over with identical bytes. Under
    the 5% rule on its own, so NOT scheduled; it is the natural follow-up to A36 if A36 passes at six
    lanes. A one-lane reading of the phases at the installed profile is pre-registered in the coordination
    file. If Astra has not answered by 12:00 UTC, Claude's lane runs the six-lane A36 test on public posts
    (it can kill A36 by rate; it cannot measure the GPU busy share, so it cannot alone declare a pass).
    **08:00 UTC: that reading is done [MEASURED once, one lane, public content; summary re-run by
    Claude].** The segment write is 21 ms a block at the installed profile (19 to 26 over 78 blocks), so
    the writer-thread idea stays alive by its posted rule; it is 6.3% of a one-lane block and at most 3.4%
    of a six-lane block. This is the first phase table at the installed profile: of a block's 335 ms at
    one lane, the 23 sumcheck slots take 145 ms, the openings 49 ms, the commitments 54 ms, host
    preparation of the committed rows 59 ms, and the segment write with its encoding 23 ms. The table is
    on the unmerged A36 branch (`results/zk60_a36_core_ahead_20261121/README.md`, section 11).
    **08:27 UTC: Sol reviewed A36's randomness (review 492).** Sol accepts the edit of the pinned
    generator test on the opt-in branch and finds the two streams independent and never shared between
    threads. A classifier request has 2 randomness streams with the switch off and 3 with it on (Claude's
    earlier "fourth stream" was wrong). One change is requested: the second stream is seeded after the
    first frame has been handed to the writer, so a failure of the operating system's randomness could
    follow a written frame; the seeding moves before the header (DONE on the branch at 08:38 UTC, head
    `0368a718`: all correctness gates green again and one switch-on receipt verified at the real shape).
    Sol's read does NOT approve switching A36 on: that needs a stream-length census at the installed
    profile, the three-stream form of the generator assumption, and the fixed-witness argument with A36
    on. A36 is merged only if the six-lane test passes, and then default off.
    **Astra's lane comparison at the installed profile, read 10:32 UTC [MEASURED by Astra, two runs a
    setting, 24 proofs a run; figures read by Claude from the result file].** Eight lanes with four
    threads each proved 43.79 padded tokens per second against 38.19 at six lanes with five threads
    (+14.67%); with the deferred checker included, 36.89 against 34.37 (+7.3%); the GPU was busy 74.7% of
    the time against 70.2%. Astra's predeclared rule is met. Caveats, Astra's own: all four runs used one
    shared GPU queue, while the app's deployment sets one queue per thread, and that comparison is still
    to come; the rates count the 128 padded token positions of each request. The app's setting has NOT
    been changed. Because eight lanes leave no idle cores, A36 is now also to be tested at eight lanes
    (same rule), and must pass at the setting the app will run.
    **Tick 32, 11:50 UTC:** the classifier's sealing pass runs each block's public check twice in a row on
    the same block and shape [CODE-READ by the tick and by Claude], so the shortcut already used on the
    trained path (A33) would be sound there. Worth at most 1.9% of stream throughput [DERIVED by the
    tick]; under the 5% rule, NOT scheduled. It is kept with the segment writer thread as one small
    bundle of host-only changes (identical receipts, no randomness) to consider after the A36 stream test.
    **12:52 UTC: A36 is KILLED by its pre-registered stream test [MEASURED once per setting by Claude's
    lane; recomputed by Claude from the raw results].** With every lane busy, the switch made the stream
    slower: at six lanes 43.87 and 43.00 padded tokens per second with it off against 37.98 and 38.88
    with it on (-13.4% and -9.6%); at eight lanes 44.11 and 46.39 off against 43.38 and 42.82 on (-1.7%
    and -7.7%). The rule was a kill under +3%. All 220 receipts made with the switch on verified, so A36
    is correct and slower. It is not merged; its results and its source as a patch file are kept under
    `results/zk60_a36_core_ahead_20261121/`. Lesson recorded: the one-lane gain (+4.8%) did not carry
    over, because with full lanes the GPU already paces the stream; so the two small host-only items
    above are downgraded and will not be built without a full-lanes test first. Side observation, NOT a
    designed comparison: with one GPU queue per thread, this test's six-lane rate with the switch off
    (43 to 44) was already at the level Astra measured for eight lanes on the shared queue (43.79), so
    the lane count should be chosen under the queue mode the app will actually run.
    **Tick 33, 15:58 UTC: the reason given above ("the GPU already paces the stream") is WITHDRAWN as
    unproven [DERIVED from the same records by the researcher, re-run by Claude].** The utilisation figure
    it rested on reads about 65% with a single lane proving, where GPU work is 22% of the time, and 85 to
    90% in every full-lanes run, so it cannot tell a busy GPU from a saturated one. What the records do
    show: with the switch on, the unchanged sealing pass of every lane was 7% slower at six and at eight
    lanes (1% at one lane), so the cost crosses lanes; and the stream with the switch off runs at 83.5%
    (six lanes) and 87% (eight) of what GPU time alone would allow with no overlap. Whether the full-lanes
    stream waits on the GPU or on the host is therefore open, and it decides which kind of speed change
    is worth building next. **Claude's lane is measuring it now:** five traced stream runs (one lane; six
    lanes with the switch off and on; six lanes on the shared queue; eight lanes), with the reading rules
    posted in the coordination file at 15:58:07Z before any run. No rate claim comes from these runs.
    **16:25 UTC: that measurement is done [MEASURED once per run by Claude's lane; every figure
    recomputed by Claude with separate code; record in `results/zk60_lanes_trace_20261121/`].** By the
    rules posted beforehand, the time a block gains from one lane to six is mostly time its GPU jobs
    spend waiting for or running on the GPU (72% of the growth). But the GPU is not saturated: with six
    lanes busy it has no job running for 22.7% of the time. The lanes move in step: they compute on the
    host together and then ask for the GPU together (three or more jobs at once 40% of the time). While
    anything is running the GPU does about 1.3 times the work of one job at a time, in every full-lanes
    run. A36 was slower because it made the lanes bunch more (GPU empty 30.7%), not because it added GPU
    work; eight lanes bunch more than six. **What this means for speed [ARGUED, not measured]:** the rate
    is the share of time the GPU has work, times about 1.3, over the GPU work per request (2.97 s). So
    two things can raise it: less GPU work per request (one for one), and less empty GPU time (a ceiling
    of +29%, about 57 padded tokens per second on this machine, if all of it could be filled; nothing yet
    shows how). The researcher's next two ticks examine what the lanes are doing while the GPU is empty.
    Two leads for Astra from single runs: per-thread GPU queues gave 44.05 against 40.98 on the shared
    queue at six lanes (+7.5%), and Astra's own app traces all show the shared queue although the app's
    settings ask for per-thread queues (question posted); and eight lanes were no better than six on
    per-thread queues (42.90 against 44.05).
    **Tick 34, 19:54 UTC [DERIVED from those traces by the researcher, re-run by Claude]:** the empty GPU
    time at six lanes is thousands of short stretches (median 1.6 ms, none over 50 ms), and during them
    most lanes are in the same host step of a block (before the commitments, before the largest
    zero-check, in the sealing pass). Lanes that were out of step would leave the GPU empty about 5% of
    the time, not 22.7%, so the ceiling for removing the bunching is about x1.23. The GPU's work rate
    keeps rising with the number of jobs running at once (0.95, 1.33, 1.37, 1.63 for one, two, three,
    four or more). What keeps the lanes in step is not shown yet; the next tick replays six lanes from
    the one-lane trace to test it and to try a held offset between lanes. Nothing is built before that.
    **Tick 35, 23:54 UTC [DERIVED by the researcher, re-run by Claude]:** the replay of six lanes from
    the one-lane trace does not reproduce the measured stream (49.9 tokens per second against 44.05), so
    it predicts nothing yet. It does show that lanes which share only the GPU bunch by themselves, to
    about half to two thirds of what was measured. What it lacks is the wait between a GPU job being
    handed over and its start: 12 ms a block with one lane, 52 ms with six. That wait is about the size
    of the gap between replay and measurement, so it is a second thing to cut besides GPU work itself;
    where it comes from is not known. The next tick fits it from the traces.
    **Nov 25, 07:54 UTC, product [count and reading by Astra; arithmetic redone and the two Ethereum
    rule pages re-read by Claude; nothing run]: posting today's receipt on a public chain would take
    about 1,600 Ethereum transactions per category.** One 670 MB receipt, carried as transaction
    data under the gas rules of EIP-7623 and EIP-7825, needs at least 1,594 transactions of the
    maximum size, and that is transport only, with no verifier on the chain. A 1 KiB proof fits in
    one transaction. So what fits today is a hash anchor of a receipt kept elsewhere; a
    kilobyte-size proof needs the recursive wrapper, which is at study level. The study's figures
    for other proving systems were not re-checked and are leads only
    (`research/applications/handoffs/20261125-apps-proof-size-limits.md`).
    **Nov 25, 07:52 UTC, size and guest check [MEASURED by Sol and by Astra, read by Claude in their
    records; not re-run]: Sol's own run of the size test agrees with the stop, and a guest check now
    asks for 12 GiB.** Sol's run of its pinned test gave +103 to +139 ms of host time a block
    against the +15 ms stop line, the same verdict as the two earlier readings at every rate. There
    is no candidate for the installed profile, and the slower-profile question stays with Victor
    (`results/zk60_sol_20261105_w16r3/b6a/B6A_WP0_RESULTS_20261125.md`). Astra's standalone reader
    checked three receipts in 42.3 to 44.2 s each with 2.47 GiB of peak process memory, reserving 12
    GiB under a 16 GiB cap; a physical 16 or 24 GiB Mac is still untested
    (`results/zk60_astra_20261026/app_composed_native_20261122/PILOT.md`). The Mac's disk is 98%
    full, with 81 GiB free after Claude removed its own scratch trees; the app's service stops
    itself at 55 GiB.
    **Nov 25, 07:52 UTC, product [reading of the official texts by Astra; the key paragraph re-read
    by Claude on the Commission's page; nothing run]: the 2 December 2026 marking date is real, and
    it is narrow.** Providers of generative systems placed on the market before 2 August 2026 must
    mark their outputs in a machine-readable way by 2 December 2026 (Article 111(4) of the EU AI Act
    as amended). Deployers' disclosure duties for deep fakes and public-interest text have applied
    since 2 August. The installed receipt proves a moderation verdict; it is neither a mark nor a
    disclosure, so the date is a reason for providers to buy marking, not a duty our receipt meets
    (`research/applications/handoffs/20261125-apps-ai-marking-dates.md`).
    **Nov 25, 06:10 UTC, product [web research by the applications researcher; page citations
    re-fetched and checked by Claude, one correction, one source still secondary; nothing run]: the
    EU moderation database has no place for a receipt.** A statement-of-reasons record must say
    whether detection and decision were automated, but it has no field for a model, a version,
    evidence or a signature. A reference could only sit in a required free-text field of 5,000
    characters, where personal data is forbidden. A statement stays publicly downloadable for 18
    months and searchable for six (the study wrote 180 days for both). So a receipt-backed
    moderation record would be the provider's own record, with at most a short reference in the
    public one; whether even a commitment to the content may be posted there is an open legal
    question, now queued. One text caps how long a provider may hold abuse material (12 months, in
    an interim regulation whose validity today is unchecked); the six-month terrorist-content rule
    could not be read in the Official Journal
    (`research/applications/handoffs/20261125-apps-dsa-database-fields.md`).
    **Nov 25, 03:55 UTC, size [reading by the background researcher, checked by Claude in the source
    with three corrections; no build, no run]: one more piece of the size step's host time is
    avoidable, and it does not change the verdict.** Before the new commitment, the host transforms
    96 rows forward only for the GPU commit to invert them again; the two routes give the same
    codeword. Dropping that step would save up to 5.9 ms of host time a block, which puts the fixed
    build near +30 ms against the +15 ms stop line. In the app's configuration (fused encoder on) it
    needs a forward-only variant of one GPU kernel or a fall-back path; the researcher's "no new
    kernel" holds only with that switch off
    (`research/zkp-efficiency/handoffs/20261125-claude-tick57-bridge-ntt-basis.md`).
    **Nov 25, 03:19 UTC, size [fixes written by an Opus agent, read and re-tested by Claude; timing
    MEASURED by Claude, one attempt, guard run `95a2c9c543a8`, rules posted before the run]: with
    the fixes in, the size step adds +36 to +44 ms of host time a block instead of about +100 ms,
    and still fails its line.** The fixes change no proof byte: 15 tests compare the old and the new
    prover output for output, including a whole proof at full shape, and the unchanged verifier
    accepts every timed proof. Added host time a block at the three settings: +44.4, +37.7 and +35.8
    ms (stop line +15 ms); added GPU time 0.9 to 1.7 ms (limit 3.0, passed). The estimate made
    before the run was about +36 ms, so the estimate held; the same arithmetic puts every remaining
    listed change near +29 ms. So the smaller receipt (about 0.53 of today's 670 MB) cannot be had
    at today's speed with this design. What the six-lane stream would actually lose is not known and
    needs a full comparison on an integrated build. Whether to build that as a separate, slower
    profile is Victor's decision
    (`results/zk60_claude_review_20261116/b6a_wp0/hostfix/HOSTFIX_NOTES.md`; record
    `results/zk60_claude_review_20261116/b6a_wp0/qualification-wp0-hostfix/attempt-00/`).
    **Nov 25, 02:18 UTC, size [source read and counts by Claude and by the background researcher; no
    build, no run]: the failed timing test is explained, and no listed fix brings the size step back
    under its line.** The new prover steps run on one thread: about 6.0 million extension-field
    multiplications in the first fold (30 ms), a dense coefficient row in the switch step (21 ms),
    32 serial transforms for the second commitment (21 ms) and the batching step (17 ms). Changes
    that keep every proof byte would cut this: skipping two redundant products (9 ms), a cheaper
    form of the switch step (15 ms), and threads. By the researcher's arithmetic the added host time
    falls from +99 ms a block to about +36 ms with host changes only, and to about +29 ms if the
    fold and the second commitment also move to the GPU [ESTIMATE, ideal scaling, rates calibrated
    on the one record]. Both are above the +15 ms stop line. So a receipt of about half the size
    comes with a speed cost in any near version; how much in the six-lane stream is not known.
    Whether to build it as a separate slower profile is Victor's decision
    (`research/zkp-efficiency/handoffs/20261125-claude-tick56-size-step-host-time.md`).
    **Nov 25, 02:00 UTC, product [web research by the applications researcher; three pages read a
    second time; one local correction by Claude]: a moderation buyer's public record needs a
    category, and the app's design of one policy per category already supplies it.** The EU's
    statement-of-reasons database requires a category from a closed list of 16 and two fields saying
    whether detection and decision were automated; it has no field for a model, a score or a
    receipt. None of the formats read requires the category to come out of a classifier. So one
    registered yes/no policy per category is enough, which is what the installed app does for three
    categories. The cost is per category: one 670 MB receipt and about 2.6 s of stream throughput
    per 128-token window today, so sixteen categories would be 10.7 GB and 41 to 42 s a window
    [DERIVED from measured figures]. A label chosen among several categories in one run would avoid
    that multiplication and is not costed yet
    (`research/applications/handoffs/20261125-apps-label-need.md`).
    **Nov 25, 01:56 UTC, size [MEASURED by Claude on Sol's pinned sources, one attempt, guard run
    `9f03ee7c3f5e`; lines posted before the run]: the size step's timing test failed its host-time
    line at all three settings, so the smaller receipt is not available at today's speed.** The new
    opening adds 0.9 to 1.7 ms of GPU time a block (limit 3.0, passed) but about 100 ms of host time
    a block on five threads: +102.8, +99.1 and +109.0 ms at the three candidate rates, against a
    pass line of +5 ms and a stop line of +15 ms. The plan had estimated between -7.5 and +6.5 ms.
    Of the added time, 71 to 88 ms is the prover's new folding step and 16 to 17 ms a second new
    step; even without the first, every setting is above the stop line. By the rules fixed
    beforehand all three settings are out and the full-speed comparison is not run on this build.
    What stands: Sol's code is correct by its own tests, and the counted receipt is still about 0.53
    of today's (669.6 MB to about 354 MB for the classifier). What is not known: where inside the
    new steps the time goes (no profile exists), and what the six-lane stream would lose. Ways
    forward, none chosen: cut or move that host work and test again under a new posted definition,
    or offer a separate slower profile with small receipts, which is Victor's choice
    (`results/zk60_claude_review_20261116/b6a_wp0/qualification-wp0/attempt-00/`).
    **Nov 25, 00:32 UTC, Lean for the size step [written by an Opus agent; Claude read every
    statement and compiled the file as committed, guard run `5e8c227c6a1a`]: three counting lemmas
    of the new opening's soundness argument are now proved in Lean.** They cover the steps the
    independent read had found outside Lean and purely combinatorial: how many positions separate a
    nearly-correct word from any wrong codeword, how many sample choices can miss those positions,
    and the union over fold rounds when each round's bad challenges depend on the earlier ones. Nine
    declarations, no `sorry`, the three standard axioms only
    (`results/zk60_claude_review_20261116/b6a_lean/SoundTowerRound.lean`). This is a first slice of
    an item the plan sizes at 1,500 to 3,000 lines: there is still no theorem about the new opening
    as a whole, and its Merkle binding, Fiat-Shamir step and link to the existing opening lemma are
    untouched. The file is an offer to the builder and sits outside the main Lean build.
    **Nov 25, 00:29 UTC, product [web research by the applications researcher from EU, UK and
    California texts, several through law-firm summaries; Claude compared the article numbers and
    dates with what it knows and re-fetched nothing; no legal advice]: do published rules already
    ask for what a receipt gives? Mostly not.** No provision read asks for a proof per item.
    Auditors and regulators have a right to the data and systems and can rerun an open model
    themselves; public reports are totals; duties to mark generated media are met by a mark, not by
    a classifier's verdict. The one place where a receipt does something a signed log cannot is the
    statement of reasons a platform owes a user under the EU Digital Services Act, and the
    Commission's public database of them: someone who must not see the content could still check
    that the named model gave the stated verdict. That is a possible use, not a legal demand. A
    further possible use, added in triage and equally unproven: decisions on content the platform
    may not keep or show, where a rerun is impossible. One date in the study (a marking deadline of
    2 December 2026) is unverified. Two follow-up studies are queued.
    **Nov 25, 00:21 UTC, product [web research and local reading by the applications researcher;
    Claude checked the local citations and made one correction; no page was re-fetched and nothing
    was run]: which well-known safety classifiers the prover could take.** The best-known open guard
    is the one that fits: Llama Guard 3 (1B and 8B) and one NVIDIA guard built on the same base use
    only operations the block prover already has. What they still need is an import path, a
    calibration to the quality bar, a prompt template that fits the request length, and a decision
    on the label (the app proves one yes/no margin; these guards also print categories). Granite
    Guardian, Qwen3Guard and ShieldGemma each need new proof relations with their own review and
    Lean statement. A fit on paper is not a quality result: no guard was exported or proved.
    Follow-up studies are queued on what a buyer needs from the label and on the length of each
    guard's prompt.
    **Nov 25, 00:14 UTC, size [research by the background researcher and an independent read by an
    Opus agent; Claude re-ran the scripts, recomputed the totals and checked the citations; nothing
    was built or timed]: what a kilobyte receipt would cost, and an independent read of the new
    opening's soundness argument.** *Kilobyte receipts (tick 55).* A receipt small enough for a
    blockchain means a second proof that the checker accepted the first one. Its cost follows the
    bytes the checker hashes: 13.4 M BLAKE3 compressions a request today on the 8B shape, 6.9 M
    after the first size step, 1.6 M after the second [DERIVED; two terms ASSUMED, a recount is
    queued]. Priced from the one published design of this kind (Sable, arXiv 2611.14083), that
    second proof takes 9 to 40 s a request after the first size step and 2 to 9 s after the second,
    against about 3.2 s to prove the request itself [DERIVED from the authors' measured rates on
    their GPU and from their cell counts at this prover's rate; not measured here]. Every published
    route under 1 kB then ends in a Groth16 step with a trusted setup (15 s claimed on other
    hardware; 197 s measured for the old zkVM line in September); routes without one stop at 140 to
    870 KiB [AUTHORS; the 140 KiB figure was re-read]. Today's checker also reads all 7 GB of public
    weights, which cannot be wrapped, so a weight commitment has to come first. This is a route for
    batches or a background service after both size steps, and a trusted setup on this line would
    need a ruling (D4 accepts one for the old zkVM line only). *The size step's soundness note.* An
    independent reader found no wrong step in Sol's argument for the new opening. The five Lean
    lemmas compile on the three standard axioms and say what the note uses them for, and the code
    matches the note on every parameter traced. The note stops at per-round figures: added up, the
    new opening contributes 2^-103.5 over a 26-block classifier run, which would move the run's
    figure from 2^-98.08 to about 2^-98.05, as the build plan had estimated [DERIVED, recomputed by
    Claude; today's 2^-98.08 was not recomputed]. Still open for the proof: the total, Merkle
    binding, the Fiat-Shamir step and the link to the existing opening lemma. The timing test of
    this step has not run; Sol's window has been idle since Nov 24, 20:12 UTC.
    **Nov 24, 20:05 UTC, size and image [built and measured by Sol and by Astra; Claude checked the
    guard records only]: first proof with the new opening on a small development rung, and a
    patterned image through the whole image chain.** *Size.* Sol's switched block core proved and
    verified a development rung (T32), and the CPU process and the GPU process produced the same
    2,023,432-byte proof, byte for byte; tampered folds, a short path and a wrong binding were
    refused. The GPU arm still computes the new small matrix on the CPU. No timing has been taken
    and no full classifier receipt exists in the new format. *Image.* Astra's coordinate-pattern
    test image passed all 102 stages of the image-to-verdict proof with a fresh verifier (2.87 GB
    receipt); the owner's opening matched and rejected a different image and three one-bit changes.
    It is a synthetic image, and the installed app still screens text only.

    **Nov 24, 19:50 UTC, product [reading, counting and web research by Astra; figures marked
    checked were re-checked by Claude, and the video reference test was reproduced independently]:
    two more application studies; the first queue of nine is done.** *Receipt size by use.* Who
    keeps a receipt and who checks it decides what size is tolerable. A central checker (an editor's
    service, a review platform, an auditor) can trial today's sizes or the first size step. A reader
    who downloads every item cannot: one post is 2.0 GB, about 160 s of transfer at 100 Mbit/s
    before any checking [DERIVED, checked]. Attachments in a review system and checks in a browser
    need the later size steps, which are at study level. Checking one classifier receipt takes 42 to
    43 s on this Mac with about 2.5 GB of memory [MEASURED, nine guard records]. *Video.* 1080p at
    30 frames a second is 187 million input values a second [DERIVED, checked]. Cuts, crops,
    redactions and declared frame-rate changes have simple relations over raw frames; a lossy
    re-encode needs a proof of the codec, which this project does not have (one published system
    reports 2.4 hours for a two-minute clip). Nothing was proved; the reference arithmetic alone is
    qualified. Three new studies are queued: the safety classifiers a buyer would name, published
    rules that already ask for such records, and where a kilobyte-size proof has to fit.

    **Nov 24, 19:38 UTC, size and product [built and measured by Sol and by Astra; the byte table
    recomputed by Claude, guard records checked; nothing compiled or re-run by Claude]: the new
    opening works in the library, and a guest's download was checked natively.** *Size.* The
    switched opening that replaces the large clear vectors now runs inside the proof library on the
    merged head: 101 library tests pass, six of them on the new path, and the old opening's bytes
    are unchanged. Counted from the new wire format, the app classifier's receipt would be 351 to
    356 MB a category against 670 MB today (0.52 to 0.53 of today's) [COUNTED from a measured base;
    no full receipt of the new format exists yet]. The plan's model said 354 MB. Still to do: the
    profile and block wiring, the GPU route, the timed spike (its rule for choosing among three code
    rates was fixed before any timing), full receipts, the whole-run security and hiding accounts,
    the Lean chain. *Product.* On the installed Mac a guest downloaded one post (2.0 GB with its
    three receipts) and checked it with the released reader and a relocated kit: three native
    checks, each using about 2.5 GB of memory. Not yet tested: a guest on a different Mac, which is
    the step that makes it a pilot.

    **Nov 24, 19:08 UTC, size and product [built and measured by Sol in its own tree; read by
    Claude, who compiled and re-ran nothing]: the first pieces of the size step exist.** The helper
    that computes the claims for the new small matrix passed 1,000 full-size random cases [MEASURED
    by Sol; guard record checked]. The two-level tower that replaces the clear vectors passes its
    five isolated tests, including rejections of a changed root, column, salt, path and final row. A
    tree for integration is set up from the merged head. A written soundness argument for the tower
    exists, with five small Lean lemmas [READ by Claude: the steps re-derived by hand hold; not yet
    compiled by a second party or read independently]. Not done: the switched opening inside the
    prover, any timing (the spike's pass and kill lines are fixed), the Fiat-Shamir step and the
    whole-run accounting, the hiding argument, the Lean chain. *Application study A6, writing
    history [reading and web research by Astra; repository citations checked by Claude]:* a receipt
    could show that a text came from a recorded editing session under a named policy while drafts
    stay private, but a person retyping a model's answer passes the same check, so the label would
    be "writing history verified" and never "human-written". All seven first application studies are
    now done; two more (receipt size per application, video) are queued.

    **Tick 54, Nov 24 15:59 UTC [reading and arithmetic by the background researcher; its script
    re-run by Claude with identical output; source citations and one paper checked; nothing built or
    measured]: what hidden model weights would cost on the 8B prover.** Hidden weights are decided
    for the full version and stay at study level (D82). The price is mostly receipt size: with one
    reusable hidden commitment to the weights, the 8B receipt (818.7 MB today, MEASURED) grows by
    220 MB if a block's seven weight claims can share one opening and by 430 MB if they cannot
    [DERIVED]; after the first size step the weight part would be 146 MB [MODEL, the new tower's
    bytes for weights not counted]. Extra proving time is 0.09 to 2.5 s a request on a 3.7 s cadence
    [ESTIMATE; no kernel exists, so the range is wide]. Three limits come with it. (1) One
    commitment serves a limited number of proofs (the journal allows at most 65,536) before it must
    be re-made, and re-use forces a lower code rate, which makes the stored encoded weights 223 GB a
    model. (2) The approved zero-knowledge statement assumes up to 2^64 receipts and "this is the
    approved model" is in neither approved statement, so both statements would need a ruling when
    this becomes a build. (3) It was priced for the 8B shape only; the classifier the app runs, the
    model for which hiding matters to the applications, is not priced yet. On the gain side the
    checker would no longer need the 7 GB of weights. Handoff:
    `research/zkp-efficiency/handoffs/20261124-claude-tick54-hidden-weights-price.md`.

    **Nov 24, 14:26 UTC, product [reading and web research by Astra; the figures marked checked were
    re-checked by Claude against the records]: three more application studies, none of them a
    build.** (1) *Who proves for a holder with a small machine.* Today whoever runs the prover reads
    the content. Three routes: trust the host by contract (no change to the prover); an attested
    confidential virtual machine (one published benchmark, fetched and checked today: 17.7% less
    throughput and 21.8% longer to the first token for plain inference of a 7B model on an H100;
    nothing is measured for proving, and our Metal prover would need a port); a witness split across
    independent provers (protocol work; published figures are for other proof systems). None is
    qualified here. (2) *Evidence that a filter ran on a private document.* The clearest fit is a
    transfer between security domains where the site's own control already asks for a named filter
    and an audit record. A receipt can show that the registered filter read every token of a
    committed attachment; a record signed by the gateway is still needed to tie it to the transfer,
    and a per-item proof cannot count omitted transfers. Two public personal-data taggers would each
    need new proof relations. One padded 128-token check at the app's measured rate is about 2.6 s
    of capacity [DERIVED, checked]. (3) *A score on a hidden benchmark.* The trained 8B proof
    reaches one next-token decision on a held-out prompt [MEASURED by Sol on CPU: 487.3 s to prove,
    32.1 s to check, 772 MB; checked]. A thousand such prompts at that cost would be 135 hours of
    serial proving and 772 GB of receipts [ESTIMATE from one run, arithmetic checked], and the
    relation that binds every hidden question and answer to the published score does not exist yet.
    This application waits for the trained GPU path, smaller receipts and that relation. The
    applications queue now holds: the provenance route for text, the receipt size each application
    can tolerate (ties the size ruling D82 to the applications), and video. Handoffs:
    `research/applications/handoffs/`.

    **Nov 24, 12:31 UTC, speed [merge check MEASURED by Claude on the merged tree]: the second host-
    speed switch is merged and pushed, off by default, together with the fix that makes a verifier
    ignore every speed switch.** The merge check was green: the full test suite with no switch and
    again with the three host switches forced (1,037 passed each, only the two known fixture
    failures), twenty-one gate tests each alone in a fresh process, and the GPU commit test with
    switches off and on. What it buys, as measured this morning: about 3 percent at the installed
    app profile at five threads per lane, nothing lost with the switch off, no gain shown at the
    app's eight threads. The flaw found on Nov 24 in the first host-speed switch (a verifier with
    the switch in its environment took the faster variant of one public computation) is closed by
    this merge. Next on the prover: Sol starts the integration of the size step (D82) from this
    head; Antigravity returns to the Lean zero-knowledge piece and then to making the service fail
    cleanly after a GPU fault. Record: `results/zk60_hostw2_merge_20261124/`.
    **Nov 24, 11:23 UTC, speed [MEASURED by Claude at the installed app profile, readings fixed and
    pushed before each run; READ for the code]: the second host-speed switch keeps its gain of about
    3 percent on the corrected code and costs nothing when off; at the app's own thread setting a
    gain is not shown.** Antigravity's fix commit was read independently (no serious finding: a
    verifier never takes a switch-dependent path, also for the first switch merged on Nov 23; a
    reused lookup count is now owned together with its witness). Then three test sets on that
    commit, six prover lanes: (1) switch off against the pushed head, eight legs at five threads:
    50.97 against 51.31 tokens per second, 0.66 percent slower, inside the 1.5 percent line; (2)
    switch on against the pushed head, eight legs at five threads: 55.59 against 53.93, 3.08 percent
    faster, above the 1.5 percent line; (3) a six-leg reading at eight threads, the app's setting:
    one pair 6.25 percent faster, the other 0.02, which by its rule reads "does not hold". So the
    switch is not recommended for the app at eight threads on this evidence, and an eight-leg test
    at that setting is offered to Astra. The level of one arm moved about 5 percent between two sets
    for a reason not found; every reading compares the two sides inside one set, and no figure is to
    be compared across sets. Before the merge: two test gaps go back to Antigravity (tests only),
    then the full merge check. Record: `results/zk60_hostw2_app_20261124/README.md`.
    **Nov 24, 09:09 UTC, product [MEASURED and written by Astra; figures marked as checked were re-
    read by Claude in the records]: a first outside-user trial of the installed app ran, and three
    application questions are answered.** One author who is not the operator and one guest used the
    app end to end: 153 seconds from a cold submission to publication (81 of them waiting for the
    shared GPU guard), and the guest re-checked all 84 proof segments. What stops an outside pilot,
    by Astra's list: remote access and key distribution, a portable verifier setup, and a review of
    the profile and the claim wording. One post's receipts for three categories total 2.0 GB, which
    is what the size work (D82) is aimed at. Application findings: (1) the installed app needs more
    memory than any machine of 128 GB or less offers; a one-lane variant is estimated to fit 48 GB
    at about 11 tokens per second on this Mac [memory figures checked; nothing measured on a smaller
    machine]; (2) proofs about a 12-megapixel photo (a crop, a resize, a masked area, a blur) are
    estimated at about 0.5 to 1.2 seconds of GPU time for the commitments and checks, before the
    binding to a signed capture, which is not built; the app's present image intake reduces a photo
    to 224 by 224 and so says nothing about full-resolution edits; (3) four open-weight detectors of
    machine-written text could be proved in principle, each loses half or more of its detection
    under one tested rewriting, and none runs in the prover today. Handoffs:
    `research/applications/handoffs/`; pilot report:
    `results/zk60_astra_20261026/app_composed_native_20261122/PILOT.md`.
    **Nov 24, 08:44 UTC, size [PLAN written by an Opus agent from the source, nothing built; four
    claims spot-checked by Claude]: the build plan for the first size step is posted and Sol has
    agreed to build it.** The installed classifier's receipt is 669.6 MB per 128-token request
    [MEASURED]; the plan models it at about 354 MB after the step, or 333 MB with the boundary
    openings included, and the 8B receipt at 405 MB against 818.7 MB [MODEL]. The step does not need
    the unmerged earlier protocol bundle. It goes under a new profile name, off by default; old
    receipts stay byte-identical. Order: a written soundness argument for the new folding steps (the
    largest risk: it is unwritten and unreviewed), two packages of new files that can start now, a
    half-day timing trial whose pass and kill lines are fixed in the coordination file, then the
    integration after the speed switch in review merges. Lean: the opening's model and the query
    counts change, estimated at 3 to 6 weeks, more if a proof chain for the app's profile must be
    built. Asked of Victor: which base profile carries the step first (recommended: the app's).
    Plan: `docs/zkmatrix-poc/ZK60_SIZE_B6A_BUILD_PLAN_20261124.md`.
    **Nov 24, 08:29 UTC, ruling (D82, Victor): the proof-size work restarts as a build.** A receipt
    is about 0.8 GB per 128-token request today (818.7 MB at the 8B profile, MEASURED in an earlier
    record), which many of the applications under D81 cannot carry. First step: "switch the clear
    vectors" (B6a of the Nov 5 design study), modelled at 387 MB per 8B request with prover time
    within about 5 percent [MODEL, not built]. A build plan is being written from the source (state
    of the prerequisites, the change against today's opening code, the receipt size for the three
    profiles, the proofs it needs, ordered work packages, a spike with pass and kill lines fixed
    beforehand). It is a protocol change: a new profile, existing receipts unchanged, and nothing is
    called production before its two Lean statements are proved. Not started and kept at study
    level: the second size step (40 to 50 MB), hidden weights, and a small wrapper proof for
    kilobyte receipts. Also on Victor's instruction a list of potential customers is being compiled
    for his outreach; it is business material and stays outside this repository.
    **Tick 53, Nov 24 08:05 UTC [reading and arithmetic by the background researcher; its script re-
    run by Claude with identical output; citations checked by Claude except the per-round medians
    its script derives]: the future-protocol candidate A (lookups with no committed helper columns)
    has no supported speed gain on today's prover.** The lookup tree that would replace the helper
    columns costs at least about 22 ms a block on the GPU by a bound from kernels already measured,
    against 11.5 to 12.1 ms of commit time saved. Counting three further savings an earlier tick had
    left out, the net is between 18 ms slower and 2 ms faster a block; the best case is 1.7 percent
    of the stream's cadence. This supports the ruling of Nov 16 that the prototype of candidate A
    does not start. One reading-only item is queued to price the last unmeasured term. Nothing was
    built or timed. Handoff: `research/zkp-efficiency/handoffs/20261124-claude-tick53-lookup-tree-
    device-bound.md`.
    **Nov 24, 08:05 UTC, direction (D81, Victor): effort begins to shift toward building and
    marketing products and toward research on applications; the first market named is zero-knowledge
    proofs of man-made content.** Reasons given: funding or interested clients would let operations
    expand, and near 50 proved tokens per second the system is about as efficient as many
    applications need. What changes: a market and applications scan is running (its output is
    business material and stays outside this public repository); half of the background research
    ticks go to applications; the speed switch now in review still merges, and after it a speed item
    starts when a named application needs it. What does not change: nothing is called production
    before its two Lean statements are proved (D63); the 8B target is not withdrawn; a detector's
    verdict is labelled a statistical screen, never a proof that a human made something. Open with
    Victor: which profile a first product ships (the Lean chain covers R13, the installed app runs
    W16R2) and under what label a pilot may be offered before D63 is met for its profile. The app
    now builds from the merged prover with five speed switches at six lanes by eight threads, and
    its verifier launches strip every switch (Astra, 07:58 UTC).
    **Nov 24, 06:35 UTC, review [READ by two independent reviewers, source only, nothing built; the
    two points below checked by Claude in the source]: the second host-speed switch has no serious
    defect, and the review uncovered a flaw in the first host-speed switch, which is already
    merged.** Neither read found a way for the new switch to change a proof, skip a block's checks
    or corrupt memory. The flaw: speed switches are meant to touch only the prover, but one public
    computation (the accuracy fold) is shared by prover and verifier and looks at the switch on both
    sides. A verifier started with `HL_HOST_FAST=1` in its environment takes the faster variant. The
    variant is tested equal to the normal one and no wrong result is known; the tests of Nov 23 are
    unaffected because their verifier ran with no switch set. It still breaks a rule we rely on, and
    the earlier review missed it. Until the fix is in, the switch belongs only in the prover's
    environment; Astra has been told. Other fixes asked of Antigravity before the new switch can
    merge: tie a reused lookup count to its own witness by construction (today it is matched by
    memory address, which is safe only because every caller happens to keep them together), and add
    three missing tests. Reports:
    `results/zk60_claude_review_20261116/HOST_WAVE2_READ_A_20261124.md` and
    `HOST_WAVE2_READ_B_20261124.md`.
    **Nov 24, 06:21 UTC, speed [MEASURED by Claude at the installed app profile; gains DERIVED as
    ratios inside one set; the 8B figures are Antigravity's, recomputed by Claude from its raw log]:
    a second host-speed switch passes its timing test at the app profile, narrowly, and is not
    merged yet.** `HL_HOST_FAST_W2=1` (Antigravity's branch, off by default, byte-identical
    receipts) cuts more host work around each block. At the app profile it gave +3.1%, +2.5%, +2.5%
    and +4.2% in four paired comparisons over two sets: average +3.05% against a pass line of +3%,
    so it passes by a hair and the honest size is about 3%. With all six switches the stream ran
    55.6 to 56.9 tok/s against 54.2 to 54.6 for the current head in the same sets (public posts,
    trained 3B classifier, six lanes by five threads). At the 8B size the same switch measured more:
    40.8 to 43.0 tok/s (+5.5%, every one of six passes faster), with the caveat that both figures
    come from one binary of an earlier commit. Still to do before a merge: two independent code
    reads (running), fixes, a dedicated test that the switch-off path is not slower (the four
    switch-off comparisons so far are all slightly negative, about -1% on average), and the merge
    check. Record: `results/zk60_hostw2_app_20261124/README.md`.
    **Nov 24, 04:33 UTC, speed [MEASURED by Claude at the installed app profile; gains DERIVED as
    ratios inside one set]: the classifier speed switch is merged; with all five switches the app's
    stream ran about 53 to 54 tok/s.** `HL_CLASSIFY_HOST_FAST=1` is off by default, changes only the
    prover and leaves receipts byte for byte the same. In the last complete set the stream ran 54.0
    and 54.4 tok/s with it against 51.3 and 50.4 without it (+5.3% and +7.9%; public posts, trained
    3B classifier, six lanes by five threads). The merge check on the merged tree is green: the full
    test suite twice (no switch, and both host switches forced on), six gate tests each in its own
    process, and the commit integration test. Its first run had failed on one new test that compared
    counters other tests could change; Antigravity removed those comparisons from the shared suite
    (test files only), and the strict check that the switch never reaches the verifier still runs
    alone in its own process. The installed app does not use any of the five switches yet; that is
    Astra's decision. At the 8B size nothing new was measured tonight. Record:
    `results/zk60_classifyhost_app_20261123/README.md`.
    **Tick 52, Nov 24 04:03 UTC [reading and arithmetic by the background researcher; its code and
    census citations checked by Claude, its script re-run with identical output]: two
    future-protocol ideas together would shrink what the prover commits to about a third, but the
    speed they can buy is capped near 10 to 15% and may be eaten by their own cost.** The two ideas
    are packing small values as bytes (candidate B) and lookups that need no committed helper
    columns (candidate A). Counted from the layout code, B alone leaves 81 to 91% of today's
    committed rows (an earlier tick said 78 to 88% and had left out some helper rows), A alone 49 to
    52%, and both together 27 to 41%, or up to 48% in one variant. Committed volume is not time,
    though: commits are about a quarter of the GPU work, so even if every saved row turned into
    saved time, A would give at most about 10% and B about 4 points more. A's lookup tree is new GPU
    work that nobody has measured, and an earlier estimate puts it near the size of the saving.
    Nothing is scheduled. The next tick bounds the tree's cost from kernels already measured; only
    if that passes is a one-day prototype worth discussing. Handoff:
    `research/zkp-efficiency/handoffs/20261124-claude-tick52-ab-net-volume.md`.
    **Nov 24, 03:50 UTC, speed [MEASURED by Claude at the installed app profile; gains DERIVED as
    ratios inside one set]: the classifier speed switch has cleared its timing checks after the
    code-review fixes; it is not merged yet because one new test is unreliable.** Antigravity's fix
    commit (the switch no longer reaches the verifier, and the writer thread's failure paths are
    tested) was timed again, because it reshapes code near the switch-off path. With the switch on
    the stream ran 54.0 and 54.4 tok/s against 51.3 and 50.4 without it (+5.3% and +7.9%). A first
    check of the switch-off path failed the line I had set (one pair at -4.3%, the other at +1.3%,
    with two legs of the same binary 4% apart). A second, larger test of only that question (eight
    legs, four for each binary) read it intact: -0.28% against a line of -1.5%. In that test the
    first three legs ran 3 to 5% low whatever the binary; drift of that size between legs is common
    in this fixture, in either direction, and is the likely reason for the failed pair. From now on
    a set starts with a discarded lead-in leg and the switch-off question gets the eight-leg test.
    One set was lost to a GPU hang reported by macOS, after which the prover sat idle instead of
    failing: that is a defect of the service, reported to Antigravity and to Astra (the installed
    app runs the same code). The merge check then found one new test that fails by chance when it
    runs beside other tests; it passes alone and the prover is not at fault. Antigravity fixes the
    test, I re-run the check and merge. Record: `results/zk60_classifyhost_app_20261123/README.md`,
    `results/zk60_classifyhost_merge_20261124/`.
    **Nov 24, 00:43 UTC, Lean [MEASURED: my own build and axiom audit]: the honest-prover chain is
    merged.** After the three reads below, I rebuilt its 26 modules from source in my own copy:
    the whole Lean project builds with no error and no warning in the new files, and the three
    final theorems, the refusal-cover theorem and the completeness-parts theorem rest only on
    Lean's three standard axioms. The branch is merged and pushed. What it proves and does not
    prove is exactly the list in the next paragraph: the chain is in the tree and builds, and
    it is complete except for the zero-knowledge assumption and for completeness against the
    code's real header and statement checks. Record:
    `results/zk60_lean_l68c_merge_20261124/`.
    **Nov 24, 00:20 UTC, Lean [READ, source only, nothing built]: where the honest-prover chain
    stands after the three independent reads.** For the R13 Shieldstral profile, with valid
    public weights: (1) PROVED in Lean, if the build is as green as its author reports (my own
    build of the merged files is still to come): an honest run of the Lean model of the prover
    is accepted except with probability at most 2^-40, and knowledge soundness and binding
    hold. (2) NOT PROVED: zero knowledge for the concrete run (one open assumption, see the
    paragraph below). (3) NOT PROVED, found by the third read: the completeness result is for
    a verifier whose header policy check and per-block statement check are replaced by
    functions that accept everything. Soundness is unaffected, because it holds for any such
    check; but that honest proofs always pass the code's real header and statement checks is
    not yet shown. (4) One interim assumption, the vocabulary size 131072, is a true fact about
    the profile that is assumed rather than derived. (5) Nothing in Lean speaks about the Rust
    binary itself; that correspondence is outside Lean by design. The branch (26 files, about
    37,000 lines) is not merged: its author is asked for wording corrections first, then I
    build it on the merged tree and audit the axioms. Record:
    `results/zk60_claude_review_20261116/L68C_READ_5_TOP_20261124.md`.
    **Nov 24, 00:14 UTC, Lean [READ, source only, nothing built]: zero knowledge is not yet proved
    for the concrete honest prover.** The second independent read of Antigravity's chain
    (the zero-knowledge modules) finds that the final theorem takes one structured assumption,
    called `W_zk`, that nothing in the repository constructs. It asks for a description of
    the whole 28-segment run as a program, with exact counts of its hash queries and a proof
    that what an observer sees depends only on the part of the randomness the argument allows.
    The file's own header says this assumption is open; the commit message that called the
    chain complete did not. Two further points: it is not shown that the assumption can be
    met as written (it requires the prover to make the same kinds of hash queries on every
    path, including when it refuses), and the query counts in it are typed-in numbers that are
    checked to add up but not derived from the prover. What is proved: the error budget
    arithmetic from the counts to the target, and the form of the conclusion, which matches
    the approved statement. So for the R13 Shieldstral profile the honest prover's completeness
    side is assembled for the concrete system, and zero knowledge rests on that one open
    assumption. The read of the final theorem's full list of assumptions is running. Record:
    `results/zk60_claude_review_20261116/L68C_READ_4_ZK_20261124.md`.
    **Nov 24, 00:09 UTC, Lean [READ, source only, nothing built] and research tick 51 [reading
    only]:** the independent reads of Antigravity's completed proof chain for the honest prover
    (26 files, about 37,000 lines of Lean, not merged) have resumed. First module, the output
    stage's arithmetic: sound. It proves all 20 conditions the output stage owes for the
    concrete tables, with no condition left as an assumption inside the module and no
    degenerate case found, and the two gaps found earlier in the input stage are closed for
    this stage. A scan of all 26 files found none of the words that would mark an unproved
    step outside comments. Still to read: the zero-knowledge modules (running now) and the top
    theorem; the top theorem takes a zero-knowledge premise whose status that read is to
    settle. Nothing merges before those reads and a full build. Research tick 51 answered two
    reading questions on the future-protocol candidate B: its recombined lookup keys cost no
    extra helper rows, and its count of opening claims stands. No speed changes from either.
    **Nov 23, 23:12 UTC, speed [MEASURED by Claude at the installed app profile; gains DERIVED
    from the raw completions]: the third candidate is fixed and now passes cleanly; not merged
    yet, the code review is next.** Antigravity found why its classifier-side branch slowed the
    default path (it had restructured the old code around the new switch) and delivered a
    version in which the old path is the old code again. Re-measured with all three versions
    inside each run: with the switch off the new binary is level with the merged head in four
    of four comparisons (between -0.5% and +1.6%); with the switch on the six-lane stream ran
    at 53.5 and 54.7 tok/s at five threads per lane against 49.6 and 51.0 for the merged head,
    a PASS by the rule posted before the run, and at 53.4 and 53.5 at eight threads against
    50.6 and 52.1. Quoted gain: about +5 to +7% at five threads and +2.5 to +5% at eight, one
    run each (the base legs drifted by about 3% inside each run, so the single pair figures
    are wider than that). All 432 proofs made by the new binary were accepted by the current
    verifier. So the installed profile, with this fifth switch, measures about 53 to 55 tok/s
    on public test posts with the trained 3B classifier; the day began at about 46.5. This is
    not the private 8B target. Review starts after midnight UTC (today's agent budget is
    used); the merge follows only after its findings are settled and the full suite passes on
    the merged code.
    **Nov 23, 21:24 UTC, speed [MEASURED by Claude at the installed app profile; gains DERIVED
    from the raw completions]: a third candidate of the day passes at five threads per lane but
    is not merged, because it slows the default path.** Antigravity's next branch speeds up the
    classifier's own host work (table digests computed once, proof segments written by a helper
    thread, and three smaller cuts), behind a new switch `HL_CLASSIFY_HOST_FAST=1`. With the
    switch on, the six-lane stream ran at 54.3 and 54.6 tok/s against 51.3 and 51.0 for the
    merged head: +5.9% and +7.1%, a PASS by the rule posted before the run, and every proof was
    accepted by the current verifier. But the same new binary with the switch off is slower than
    the merged head in all four comparisons made (2 to 5%, at five and at eight threads per
    lane), and at eight threads the switch adds nothing. A switch that is off has to leave the
    old path as it was, so the branch goes back to its author before any review or merge. One
    measurement does not fit the others (the same setting ran 7% apart in two runs twenty
    minutes apart) and is unexplained; it is recorded as such. This is the trained 3B classifier
    profile on public test posts, not the private 8B target. Record:
    `results/zk60_classifyhost_app_20261123/README.md`.
    **Tick 50, Nov 23 19:56 UTC [DERIVED by the researcher from the Lean bounds and the registered
    sizes, its script re-run by Claude; nothing measured]:** a second count for the same
    future-protocol candidate (candidate B). Its new range test only shows that each committed
    cell is below 2^18, where honest cells are bytes. The question was whether that weaker bound
    lets any sum inside a block overflow the field. Answer: not for cells used directly, but yes
    once 16-bit and 24-bit words are rebuilt from such cells (five sums pass the limit at the
    Lean bounds; at the 8B sizes one does, and the script builds a concrete example). So the
    candidate must keep today's range checks on the rebuilt words, and needs no extra per-byte
    check and no new overflow lemma in Lean. Whether that costs it 480 extra helper rows
    depends on one reading question, queued for the next tick. No speed changes from this.
    **Nov 23, 19:50 UTC, speed [MEASURED by Claude; gains DERIVED from the raw completions]: the
    host-side speed-up is merged (off by default), and the installed profile now runs at about 50
    tok/s with all four switches on.** The two code reviews found no fault that gives a wrong
    proof, an accepted bad proof or a privacy leak; they asked for seven changes (mainly a test
    that compares proofs with the switch on and off without the GPU, and putting the verifier's
    code back exactly as it was, with a refusal if it is ever handed prover-side tables), which
    Antigravity made. The check on the merged code passed: 1023 tests, the same two known
    fixture failures as before and no new one, and the identical result with the new switch
    forced on for the whole suite. Then one more measurement, at six lanes by eight threads:
    there the switch adds only +1.6% and +0.5%, under the line set before the run, so its gain
    does not hold at eight threads. Read together: the change removes CPU work, which is the
    limit at five threads per lane and mostly hidden at eight. With all four switches the stream
    ran at 49.2 and 50.8 tok/s at five threads and at 49.7 and 50.3 at eight; before today five
    threads gave about 46.5 and eight about 48.5. So the two merges of today lifted the
    installed profile by roughly 3 to 8% depending on the thread count, to about 50, and five
    threads per lane now do what eight did. This is the trained 3B classifier profile on public
    test posts, not the private 8B target, where the same day's figure is 40.3 tok/s. The four
    switches are offered to the app's lane (Astra), which has already qualified the first two
    at eight threads. Record: `results/zk60_hostfast_app_20261123/README.md`,
    `results/zk60_hostfast_merge_20261123/`.
    **Nov 23, 18:08 UTC, speed [MEASURED by Claude at the installed app profile, six lanes by five
    threads; gains DERIVED from the raw completions; the 8B figure MEASURED by Antigravity and
    recomputed by Claude]: a host-side speed-up passes at the app profile, +5 to +8%; not merged
    yet, the code reads are running.** Antigravity's switch `HL_HOST_FAST=1` (off by default; six
    changes to work the CPU does between GPU jobs) was measured on top of everything merged so
    far. The six-lane stream ran at 50.8 and 49.2 tok/s with it, against 46.9 tok/s for the
    merged head in the clean base leg. The rule posted before the run asks for +3% in both pairs;
    the pairs came out at +8.4% and +11.3%, a PASS. The second figure rests on a base leg that
    ran 5.5% low for no known reason, so the gain is quoted as +5 to +8% (what the other
    comparisons inside the set give), and the pass does not depend on that leg. All 216 proofs
    made by the new binary were accepted by the current verifier. On the 8B stream the same
    switch shortens the steady gap by 3.0% (6 of 6 passes, 39.3 to 40.3 tok/s). This time the
    measurement came before the code review, because the change is large (about 3,700 lines)
    and two reviewers are needed; they are reading now. Merge follows only after their findings
    are settled and the full test suite passes on the merged code. Two legs near 50 do not mean
    the profile runs at 50: rates drift by one to two percent between runs. Record:
    `results/zk60_hostfast_app_20261123/README.md`.
    **Tick 49, Nov 23 16:43 UTC [DERIVED by the researcher from the code and earlier ticks, its
    script re-run by Claude; nothing measured]:** a count for one of the future-protocol candidates
    (candidate B, which packs a block's small values more tightly). The open question was how many
    opening claims the packed commitment still carries per block; each claim costs two mask rows.
    Answer: 3 to 6 claims, where the stop line was 48. So 102 to 128 of the 134 mask rows in
    question come back, and the extra commitment the candidate needs costs 6 to 9% of the rows it
    saves in the two cheaper cases and 16 to 19% in the full case (earlier estimate: 17 to 34%).
    Two premises are assumptions not yet checked against the source paper; later ticks check
    them. No speed changes from this: it bears only on how much data a proof commits to.
    **Nov 23, 15:11 UTC, speed [MEASURED by Claude at the installed app profile, six lanes; rates
    DERIVED from the raw completions; merge check MEASURED]: the faster sumcheck chain passes at the
    app profile and is merged, off by default.** With the switch `HL_METAL_SC_CHAIN_FAST=1` the
    six-lane stream ran at 48.5 and 47.8 tok/s against 46.6 and 46.3 tok/s for the previous head:
    +3.94% and +3.42%, both above the +3% line posted before the run. All 216 receipts made by the
    new binary were accepted by the previous head's verifier, and no other job ran beside the
    measurement. Antigravity fixed both faults the review had found before the measurement, and
    added tests that compare whole proofs byte for byte with the switch on and off. The merge
    check on the merged code: 1012 tests passed, the same two known fixture failures as before and
    no new one, and the change's own six tests passed. On the 8B stream the same switch shortens
    the steady gap by 2.2% (5 of 6 passes). It is the first GPU change since the fused encoder to
    pass at six lanes; it came from running fewer separate GPU jobs per block (428 instead of
    555), not from making one job faster. The switch is offered to the app's lane (Astra) with the
    two merged yesterday. **At six lanes by eight threads** (the best setting measured so far;
    measured at 15:34 UTC, four legs) the switch gains less, +1.7% and +1.9%: 48.9 and 49.6 tok/s
    with it against 48.1 and 48.7 without. (Corrected 18:08 UTC: this paragraph first called
    those the highest rates measured at the installed profile. They are not: on Nov 22 the
    tail-round option at the same setting had legs between 49.5 and 50.8. Rates of different days
    differ by one to two percent, so only the paired gains inside one measurement can be
    compared.) Record: `results/zk60_scchain_app_20261123/README.md`.
    **Nov 23, 13:37 UTC, speed [timing MEASURED by Antigravity, the 8B gaps recomputed by Claude;
    code READ by a Claude reviewer, nothing built]: a new candidate, a faster sumcheck chain on the
    GPU, passes its 8B test and its code review with two faults to fix first.** Antigravity found
    that each block runs 555 small GPU jobs one after another for the sumcheck rounds, and that the
    job which hashes each round into the transcript costs 123 microseconds, 141 times a block. Its
    rewrite (a switch, off by default, on its own branch) drops 127 of those jobs and speeds up the
    hashing job. On the 8B stream the steady gap is 2.2% shorter (5 of 6 passes). In its bench of
    one block alone the chain is 14% faster, and with six queues competing 25% faster, which is
    why it may matter more at six lanes than the last bundle did; that is not measured yet. The
    review found the transcript hashing byte for byte the same as before, and the host re-checks
    every round's challenge anyway. It also found two settings (a thread-group size that is not a
    multiple of 32, and two tail budgets set in the unusual order) under which the new path would
    compute wrong sums and produce a proof the verifier rejects; both must be fixed before use.
    The app-profile measurement is defined and waits for that fix. Review:
    `results/zk60_claude_review_20261116/SC_CHAIN_READ_20261123.md`.
    **Nov 23, 12:27 UTC, speed on the 8B stream [MEASURED by Antigravity; gaps recomputed by
    Claude from the raw log]: the bundle's two switches together shorten the 8B stream's steady
    gap by 3.4% (6 of 6 passes, 3.276 s to 3.162 s).** So the same code that gives about 1% at the
    six-lane app profile gives about 3.5% on the 8B stream, which is the shape of the project's
    target. Both code reviews are closed with their findings fixed and tested on Antigravity's
    branch. It is still not merged: the rule posted before the app-profile run tied the merge to
    that run, and whether a gain at 8B alone is enough is Victor's call.
    **Tick 48, Nov 23 12:26 UTC [COUNTED from the kernel source, the fits DERIVED; nothing
    measured]: a leaner zero-check kernel is not a route to a large gain.** The researcher counted
    what each GPU thread of those kernels holds (about 300 to 800 bytes) and set it beside
    Antigravity's memory tests. The tests fit a limit on reserved memory, not on what the kernel
    itself holds, and an earlier experiment that cut each kernel's tables to a quarter gained only
    3 to 9% of those kernels' time. The whole class is worth at most about 2% of the rate. With
    that, nothing left on the GPU kernels or the host is rated above 2% as a single project, and
    the research queue turns to the amount of committed and checked work (protocol changes for the
    next version, under D80).
    **Tick 47 and the kernel memory tests, Nov 23 12:14 UTC [MEASURED on retained traces, the
    researcher's script re-run by Claude with the same output; the kernel tests MEASURED by
    Antigravity, not re-run]: what slows a lane when six run together is mostly the GPU.** With
    one lane a block takes 302 ms (99 ms of GPU work, 13 ms waiting for the GPU, 187 ms on the
    host). With six lanes it takes 505 ms per lane; of the added 203 ms, 119 ms is GPU work taking
    longer because the lanes share the device, 47 ms is more waiting, and 38 ms is slower host
    work. No single host step stands out. Antigravity's two kernel tests: the transform kernel
    does not slow down when it is given more shared memory, so that line of work stops; the
    zero-check kernels (about 60% of the GPU work) are unaffected up to 128 bytes per thread and
    then slow down sharply (1.3 to 1.5 times at 256 bytes, 2 to 3 times at 512). So those kernels
    have slack today. The test shows how the GPU's storage per thread can limit them, not yet that
    a leaner kernel would run faster; the next research tick looks for that. Handoff:
    `research/zkp-efficiency/handoffs/20261123-claude-tick47-host-time-six-lanes.md`.
    **Nov 23, 11:50 UTC, speed [MEASURED by Claude at the installed app profile, six lanes; rates
    DERIVED from the raw completions; the kernel's code READ by a Claude reviewer]: the second
    bundle does not pass at the app profile and is not merged.** Antigravity bundled the fast
    opening with a rewritten sparse fold kernel. Each had shortened the 8B stream's gap in 6 of 6
    passes (by 2.3% and 1.8%), and the kernel's code review found no blocking fault. At the
    installed app profile the bundle with both switches on ran at 47.4 and 47.8 tok/s against 46.9
    and 47.1 tok/s for the merged head: +0.93% and +1.47%. The rule posted before the run needs
    +1.5% in each pair even to earn a repeat, so the verdict is "no transfer". All 216 receipts made
    by the bundle were accepted by the merged head's verifier, and no other job ran beside the
    measurement. Why the gain is small [MEASURED by a traced pair at 12:01 UTC, which corrected
    Claude's first guess that the saved work turned into waiting; the wait fell too]: with six
    lanes one block costs a lane about 520 ms (218 ms of its GPU work, 59 ms waiting for the GPU,
    242 ms on the host), and the bundle removes about 15 ms of that. The part of the proof it
    speeds up is simply small at this profile. The two large items it does not touch are the host
    time and the slowdown of GPU work when six lanes share the device. The branch is kept. Whether
    such code may merge for the 8B stream alone, where it does win, is a question put to Victor.
    Record: `results/zk60_bundle_app_20261123/README.md`.
    **Tick 46, Nov 23 11:02 UTC [READ from the kernel source and checked by Claude at the cited
    lines; the script's figures re-run with the same numbers; nothing measured]: the memory problem
    found in one GPU kernel is not present in the kernels that take most of the GPU time.**
    Antigravity's test earlier today showed that the sparse fold kernel ran about three times slower
    when each group of GPU threads reserved more shared memory. The researcher read every kernel for
    the same pattern. The zero-check kernels (about 60% of the GPU work of a block) reserve none, so
    that fix does not apply to them. The transform kernels behind the commitments (about 23%) reserve
    16 KB per group of 512 threads; whether that slows them is not known. Two small tests are
    specified with their pass and stop lines, for Antigravity to run after the bundle: one on the
    transform kernel, and one that asks whether a zero-check kernel slows down when memory is taken
    away from it. Neither is a speed gain by itself. Handoff:
    `research/zkp-efficiency/handoffs/20261123-claude-tick46-tg-memory.md`.
    **Also Nov 23, 11:02 UTC [Antigravity's reports; the fixes READ by Claude, the Lean files not
    yet]:** Antigravity applied the review's changes to the fast opening (both asked-for tests are
    there). Its rewritten sparse fold kernel has had its 8B run; the figures are not posted yet. It
    reports the Lean files that connect the concrete honest prover to the production statement of
    the Lean profile as complete: 26 of 26 files build with no `sorry` at its commit `326007eb`, not
    merged. Claude's reads of that commit start Nov 24, 00:00 UTC.
    **Nov 23, 08:13 UTC, speed [timing MEASURED by Antigravity, not re-run by Claude; code READ by a
    Claude reviewer, nothing built; three citations checked by Claude]: a faster opening step passes
    its 8B test and its code review; not merged yet.** Antigravity's change (two switches, off by
    default, on its own branch) skips two tables the opening never reads and gathers the opened
    columns on the host instead of in three GPU jobs per block. On the synthetic 8B stream, on top of
    the two switches merged yesterday, the steady gap was 1.99% shorter in a first set (6 of 6
    passes, a hair under the 2.0% bar set in advance, so not counted) and 2.32% shorter in the one
    repeat the rule allowed (6 of 6), about 39.9 to 40.8 tok/s. The review found no way for the
    fast path to emit different proof bytes and no new use of private data, and asks for two things
    before use: the test that pins the order of the opening's steps must also cover the new copy,
    and the call sites outside the main block proof need a byte-comparison test with the switches
    on. Next it is bundled with a rewritten GPU kernel and measured once at the installed app
    profile. Review: `results/zk60_claude_review_20261116/OPEN_FAST_READ_20261123.md`.
    **Tick 45, Nov 23 07:53 UTC [MEASURED on two retained traces; the researcher's figures re-run
    by Claude, same numbers]: the long GPU waits do not form after the lanes' shared idle stretches;
    waiting jobs are let onto the GPU in groups.** Tick 44 left a guess of mine to test: that the lanes
    finish together, do host work together with nothing on the GPU, hand their jobs over together and
    then queue. The guess is rejected by the line written before counting. Stretches with nothing on
    the GPU are real (16% of the time at six lanes, 20% at eight, against 4% and under 1% if the lanes
    were unrelated), but a job handed over in the 5 ms after such a stretch is a long waiter in 2% of
    cases against 15% and 31% overall. What does coincide with the end of a long wait: another
    lane's job ending (41% and 40% of long waits), or another lane's job starting in the same half
    millisecond (20% and 34%, against about 4% by chance), and those partners are long waiters
    themselves in 70% and 81% of cases. So several waiting jobs start together, which is the GPU's
    doing and not the host's. No speed-up is claimed and none is ranked. Separately, Antigravity ran
    the test tick 41 specified and confirmed its reading [its MEASURED, not re-run by Claude]: one
    GPU kernel's time is set by the scratch memory each thread group reserves (1.86 ms becomes
    6.06 ms with the larger reservation, same output). Its rewritten kernel, which reserves none,
    then passed the kernel test set in advance (5.53 ms to 1.40 ms, same output bytes, on its own
    branch, off by default); what that does to proved tokens per second is not measured yet. That
    kernel is about 4% of a block's GPU work; the next tick reads whether the kernels that make up
    over half of it reserve memory the same way. Handoff: `research/zkp-efficiency/handoffs/20261123-claude-tick45-convoy-coincidence.md`.
    **Nov 23, 04:03 UTC, Lean [READ by a Claude reviewer, nothing built; three citations checked by
    Claude]: the input stage's arithmetic is proved in full for the honest prover's tables.** The
    completeness theorems for the input stage rested on a bundle of 20 assumptions. Antigravity's
    module `HonestShieldStageInArith` (1,626 lines, on its branch) proves all 20 for concrete tables
    and leaves none assumed; no proof leans on a degenerate case. Two things still separate it from
    the top theorem's premise for the input stage. First, the top theorem speaks of an arbitrary
    prover and nothing yet names the concrete one; that is a short corollary. Second, completeness
    only covers runs in which the prover does not refuse, and nothing yet shows that the prover's
    fixed checks pass on these tables; until that is shown the weight sits in a separate premise of
    the top theorem. The output stage additionally assumes a property of the last block's boundary
    table that is not proved. Review:
    `results/zk60_claude_review_20261116/L68C_SECOND_READ_2_20261123.md`.
    **Tick 44, Nov 23 03:55 UTC [MEASURED on three retained traces; the researcher's figures re-run
    by Claude]: the waits of GPU jobs are never a lane waiting for itself, and a small number of long
    waits carry almost all of the waiting.** With six lanes, 15% of the prover's GPU jobs wait more
    than 5 ms for their start and carry 81% of all waiting; with eight lanes 31% carry 92%. No job
    was ever handed over while the same lane's previous job was still running, so every wait is
    another lane's job or the GPU's own scheduling. About 35 to 40% of the long waiters start within
    half a millisecond of another lane's job ending. The model that replays one lane's trace to
    predict the six-lane stream still fails with that rule added, and that line of work stops here
    after five ticks. Nothing to merge. The working guess for the next tick is a convoy: lanes queue
    behind one long job, finish together, do their CPU work together while the GPU sits idle (it is
    idle 22.7% of the time at six lanes), then queue again. Record:
    `results/zk60_lanes_trace_20261121/README.md`; handoff
    `research/zkp-efficiency/handoffs/20261123-claude-tick44-handoff-starts.md`.
    **Nov 23, 02:43 UTC, Lean [PROVED: green guarded build and full check, 594 of 594 declarations
    audited, standard axioms only]: the run's top theorem no longer depends on the undercounting
    zero-knowledge budget.** The chain of seven theorems up to the top now has a second form that
    accepts any error budget within the target; the old theorems keep their exact statements and are
    special cases of the new ones. This is the first of the six steps named in the entry below. It
    removes the risk that the top theorem is empty because its budget cannot be met. It does not
    prove zero knowledge: that remains one stated assumption of the top theorem, and the other five
    steps (three of them large) are what would discharge it. Handoff:
    `results/zk60_lean_l63_20261116/HANDOFF_20261123_1.md`.
    **Nov 23, 02:15 UTC, Lean [READ by a Claude reviewer, nothing built; four citations checked by
    Claude]: zero knowledge of the full run is not proved yet, and the review says what is missing.**
    The run's top theorem assumes zero knowledge at an error budget that is known to undercount the
    28-segment run. Antigravity's four zero-knowledge modules (3,026 lines, branch `agy/lean-l68c`)
    hold sound building blocks and a corrected budget that is proved to lie within the target. They
    hold no theorem that the real prover is zero-knowledge at any budget: the nearest one assumes a
    program for the whole run, its query counts, and the central fact that what the verifier sees
    depends only on public data. Six steps remain and three of them are large. The first step lets
    the top theorem accept any budget within the target instead of the undercounting one; it lies in
    Claude's own Lean lane, needs no ruling, and started the same hour. A side module introduces an
    assumption about the operating system's random numbers. No top theorem uses it, and it would
    need Victor's ruling before one does. Review:
    `results/zk60_claude_review_20261116/L68C_ZK_READ_20261123.md`.
    **Nov 23, 00:16 UTC [MEASURED by Claude, one run of six passes, rule and expectation posted before
    the run]: on the 8B shape the two merged GPU switches together make the stream 7.7% faster, to
    40.2 tok/s.** The fused encoder and the sparse opening fold had been timed on the synthetic 8B
    stream one at a time (by Antigravity) and together only on the 3B classifier. Together, at two
    lanes, the gap between completed requests falls from 3.480 to 3.208 s, lower in 6 of 6 passes; the
    test's steady mean goes from 37.15 to 40.21 tok/s (three lanes: 37.35 to 40.36). Memory use is
    unchanged, and the test verified the receipts of one pass in every arm. Both switches are still
    off by default. Limits: a synthetic stack of 8B shape, not trained weights; one machine state.
    Record: `results/zk60_composed_8b_20261123/README.md`.
    **Tick 43, Nov 22 23:57 UTC [MEASURED gaps on three traced runs; code read by Claude]: every
    request hashes the same 805 MB word-embedding table three times.** The table never changes
    between requests, and the hash keeps nothing from one call to the next. Two of the three passes
    fill the largest CPU pause at the start of a request (176 ms); the third comes just before it.
    Keeping the hash with the loaded table would save up to a quarter second of CPU time a request on
    each lane and change no proof byte. That is worth 1.6% of the rate at most and about 0.5% as
    measured for CPU savings with six lanes, where the GPU sets the pace. Under the 5% rule, so
    nothing is scheduled; it would also need a security ruling of the kind already made once for
    kept block hashes (D72). An earlier tick's label for this pause ("the run's own sealing pass")
    was wrong and is corrected by this one.
    **Tick 42, Nov 22 19:59 UTC [MEASURED shares from a traced run; DERIVED costs; script re-run by
    Claude, same numbers]: no GPU work can be moved back to the CPU at a profit.** A request's GPU work
    with one lane is 59% the zero-check steps, 26% the two large commitments and 15% the seven weight
    products of the sealing pass (6% with six lanes). On the CPU those seven products would need two
    thirds of all cores, and each would take 11 to 36 times as long as on the GPU against a break-even
    near 10. What is left is faster GPU code for single steps, each worth 1% to 2.4% of the rate at
    most, under the 5% rule, so nothing is scheduled. The tick also saw the largest sealing product
    run at two speeds with one lane (3.4 or 5.8 ms). Claude found the switch in four retained traces:
    the program hands the GPU two equal jobs at the same moment; when the GPU starts both in the same
    instant the pair takes 6.2 ms, when it starts them 0.4 ms apart, 4.2 ms. That costs about 1 ms a
    layer with one lane and nothing with six lanes, where a common start is rare (1% of pairs).
    **Tick 41, Nov 22 16:26 UTC [DERIVED from measured times and bench floors; inputs checked by Claude
    against the trace and the code]: the new sparse-fold kernel is at its floor on one of its two large
    calls and 2.4 times over it on the other.** The call on the H rows takes 1.85 ms a block against a
    floor near 1.8; the call on the A rows takes 4.18 ms against 1.7. The tick's guess is that the A
    call keeps too much per-group memory (19 KB against 5 KB) for the GPU to run many groups at once;
    a test of a few seconds would decide that without changing the kernel. A different layout could
    then save up to 2.8 ms a block, worth 0.8% to 2.3% of the rate. That is under the 5% rule, so no
    lane is scheduled; the finding and the test are passed to Antigravity, whose kernel it is. Four
    such small GPU cuts now stand at 2% or less each, and Claude suggested testing them as one bundle.
    **Tick 40, Nov 22 15:13 UTC [MEASURED on two traced runs; script re-run by Claude, same table]:
    where the GPU time of a block goes, and what a cut of it is worth.** Of the 98.5 ms of GPU work a
    block at one lane, the two largest zero-check slots take 38 ms, the two large commitments 25 ms and
    the other zero-check slots most of the rest. At six lanes the same work takes 218 ms, and the small
    slots stretch most (up to 4.4 times): their many dependent rounds wait behind the other lanes' work.
    One ms of GPU work cut from a block at one lane is worth about 3 ms of block period at six lanes
    [DERIVED, three rough estimates between 2 and 5, at today's operating point only], which is 0.3% to
    0.9% of the rate. The tick ranks three cuts that keep the committed words: a setting that lets the
    host take more of the small sumcheck rounds, the transcript step of each device round, and the new
    sparse-fold kernel, which runs at about 3.5 times its arithmetic floor. The first is a free setting
    and Claude is testing it at the app profile (rule posted at 15:13:20Z before any timed run). Two
    smoke runs showed that it moves 36 or 62 of the 141 device rounds a block to the host with every
    receipt still accepted by the base verifier, and that a value above 250 microseconds needs a second
    setting raised with it, which the tick did not know.
    **Result, 16:20 UTC [MEASURED, two sets of six runs at 6 lanes x 8 threads, 648 receipts accepted
    by the base verifier; record in `results/zk60_lane_threads_20261122/README.md`]: the setting at 250
    microseconds gains +2.1% as the mean of four pairs (+2.7, +3.9, +1.4, +0.5), a gain under the +3%
    bar; at 1000 it is no gain (+1.5% mean).** Levels over four runs each: default 48.96 tok/s, 250
    microseconds 50.00, 1000 microseconds 49.70. One default run was 2.9% low; without it the gain of
    250 is +1.5%, so the honest range is +1.5% to +2%. The setting is free and moves no byte, so it is
    left to Astra as an option and is not one of the three steps asked. All eight pairs are positive,
    which agrees with the reading that at six lanes GPU time is worth more than host time. These are
    figures at the app profile (the 3B classifier), on one public stream; they are not the 8B figure.
    **Tick 39, Nov 22 11:58 UTC [MEASURED on one traced run of each arm; script re-run by Claude, same
    tables]: the lead of tick 37 is dead.** The time between a request's last GPU work and the same
    lane's next request is the same with and without the bundle (about 0.19 s, 1% of a request), so
    the 0.3 s "outside the block loop" of tick 37 was an artifact of mixing two samples. Where the
    always-on gain of 3% to 4% sits cannot be resolved with traces (traced runs differ from one another
    by as much as the effect); the gain stands on four untraced pairs and the search for its location is
    closed. A request at the app profile with both switches on is 16.1 s on its lane: 2.6 s sealing
    pass, 13.3 s proving run, 0.2 s between requests.
    **Tick 38, Nov 22 11:52 UTC [MEASURED on three traced runs; script re-run by Claude, same tables]:
    at six lanes the GPU sets the rate, not the host.** One lane alone needs 302 ms a block, six lanes
    505 ms each. Of the 203 ms added, 119 are GPU execution (98 to 218 ms), 47 are waiting for the GPU
    and only 37 are host time. Six lanes together ask the GPU for 591 ms of work, counted at one-lane
    speed, in each 505 ms block period, and the GPU is busy 88% of the time. This
    fits the day's other results: a host cut inside the block loop passed only a third, more than six
    lanes lose, and threads help only up to eight. So the next gains are in cutting GPU work per block,
    above all the zero-check phase (181 of the 218 ms), and Claude withdrew an earlier remark that host
    cuts pay more. About 126 of the 224 ms of host time per block is serial code that more threads do
    not touch; each piece is under 30 ms and none is scheduled. The researcher's next items: where the
    always-on gain sits, then a table of GPU work by kind with the three largest cuts that keep the
    committed words.
    **Nov 22, 11:22 UTC: the always-on part of the bundle re-measured; corrected to about +3% to +4%
    [MEASURED, four untraced runs old, new, new, old; reading fixed at 11:03:49Z before the run].** The
    researcher's tables and one traced run did not show the gain that Claude had stated for a rebuild
    alone (+4% to +5%, from one set of two pairs), so it was measured again: +3.6% and +2.6%. The four
    pairs together give +3.9% on average (+2.6% to +5.1%). The gain is real and a little smaller than
    first stated; the figures with both switches on are unchanged. Levels today, tok/s: previous head
    43.3; merged code with switches off 44.6; both switches on 47.1; both switches on with 6 lanes x 8
    threads 48.6. Traced runs turned out to be unusable for comparing rates in either direction; they
    stay useful for where the time goes inside a run.
    **Tick 37, Nov 22 08:00 UTC [MEASURED on the one traced pair of the bundle test; script re-run by
    Claude, same figures]: where the bundle's host time went.** Inside the block loop the host time fell
    from 284 to 231 ms a block; 40 of those 53 ms are the sparse fold, and the two always-on changes show
    only about 5 ms there. Only a third of the cut reached the block period (18 ms), because GPU
    execution and queue wait rose by 36 ms together. So the always-on part's measured gain (+4% to +5%)
    is not located yet: about a third of the lane-period cut (0.3 of 0.87 s a request) sits outside the
    block loop and outside the sealing pass, and that figure is a lead, not a finding, until the next
    tick measures it directly (measured at 11:58 UTC: it was an artifact, see tick 39 above). Host time is still 44% of the block period with both switches on, four
    gaps hold three quarters of it, and one small candidate came out (the lookup histograms are computed
    twice per block: 0.5% to 3% at most, not scheduled). Following from it, Claude posted and started a
    setting test with no code change: 6 lanes x 4 threads and 8 lanes x 3 threads against today's 6 x 5,
    because 6 x 5 asks for 30 threads on a machine with 24 fast cores; rule posted at 07:59:16Z before
    any run. **Result, 08:38 UTC [MEASURED, one set of six runs, 328 receipts accepted by the previous
    head's verifier; `results/zk60_lane_threads_20261122/`]: no gain; fewer threads lose.** 6 x 4 is
    3.3% and 6.1% below 6 x 5, and 8 x 3 is 2.2% and 2.7% below it. So the fast-core count is not the
    limit, and the host phases do use the fifth thread. Today's setting with both switches on gave 47.0
    and 47.3 tok/s, which repeats the merged bundle's level. **Second set and its one repeat, 10:05 UTC
    [MEASURED, rule posted at 08:39:53Z, 648 receipts accepted]: 6 lanes x 8 threads is a gain of about
    3% over 6 x 5** (four pairs +1.8%, +3.8%, +2.2%, +5.5%; mean +3.3%; levels 48.65 against 47.10
    tok/s). 6 x 6 gains +2.2%, under the +3% bar. It is one argument of the server, no code change, the
    same receipts; it is small, it was measured on per-thread queues with nothing else on the GPU, and
    whether the app takes it is Astra's step. **Third set, 10:45 UTC [MEASURED, rule posted at
    10:07:00Z]: nothing beyond.** 6 x 12 is 3.4% and 3.5% below 6 x 8, and 5 x 10 is 7.8% and 8.9%
    below it, so the setting question closes at 6 lanes x 8 threads on per-thread queues. Its level over
    six runs in three sets is 48.6 tok/s (48.1 to 49.1), against 42.5 and 43.4 for yesterday's head at
    6 x 5 in the bundle test: about +13% over yesterday's head at the app profile on the public stream,
    a comparison across two tests.
    **Nov 22, 05:09 UTC: the composed bundle is MERGED.** Antigravity fixed every finding of the second
    read (also the fallback on device error, which was only asked before switch-on); Claude read the
    fix and ran the full suite on the merged tree [MEASURED, guard run `00fe6509a11f`]: 1010 passed,
    2 failed, 137 ignored, the two failures being the two long-known fixture ones. From this head on,
    the two host changes are in every build (about +3% to +4% at the app profile with no setting
    changed; first stated as +4% to +5%, corrected after the re-measurement of 11:22 UTC, see the top
    paragraph); the fused encoder and the sparse fold stay behind switches that are off by default (both
    on: about +8.5% in total). Rebuilding the app and turning the switches on is Astra's step.
    **Nov 22, 04:00 UTC: Antigravity's composed bundle (fused encoder, sparse opening fold, and two
    always-on host changes) PASSES at the installed app profile: +8.4% and +8.5% over the pushed head
    [MEASURED, one set of six runs, two pairs; rule posted at 03:01:33Z before any run; rates recomputed
    by Claude from the raw file].** Rates in run order head, bundle with switches off, bundle with both
    switches on, the same on, off, head: 42.53, 44.31, 46.12, 47.12, 45.61, 43.41 padded tokens per
    second. The always-on part alone (what a merge changes with no setting touched) gives +4.2% and
    +5.1%; the two switches on top of it +4.1% and +3.3%. All 216 receipts made by the composed build
    were accepted by the pushed head's verifier. Claude had expected +4% to +6% for the whole bundle and
    +1% to +2% for the always-on part, so both came out higher than expected. One traced pair [MEASURED
    once, no verdict]: host time per block 296 to 243 ms, GPU execution 202 to 222 ms, GPU wait 53 to
    68 ms, so the bundle cuts host time and moves some of it onto the GPU; the traced pair's own rate
    gain was +4.1%, smaller than the untraced set's. **Not merged at that hour (merged at 05:09, see
    above):** a second read (Opus,
    `SPARSE_FOLD_BUNDLE_REVIEW_20261122.md`) found the two always-on parts equal to the old code for
    every input and no High finding, and asked for one fix commit first (the new GPU kernels built on
    first use, a call counter so the tests show the new path ran, the installed profile's shapes in the
    kernel test); a fallback on device error is asked before the sparse-fold switch is turned on.
    Record: `results/zk60_composed_app_20261122/`.
    **Tick 36, Nov 22 03:56 UTC (re-run by Claude, same figures):** the researcher fitted the
    hand-over-to-start wait of GPU jobs on the six-lane trace and tested it on the eight-lane trace. It
    fails: the replay is still 7% too fast at six lanes and 13% at eight, and the wait is mostly not a
    function of what the device is doing (35% of its variance). What the replay lacks is that the real
    lanes move in step. The replay line gets one more tick; ahead of it the researcher reads the new
    traces to find which host gaps the bundle removed and which remain, since host cuts paid best here.
    **Nov 22, 01:37 UTC: the fused encoder is MERGED, off by default.** Antigravity fixed the three
    conditions of the second read; Claude read the fix and ran the full suite on the merged tree
    [MEASURED, guard run `b2617388f526`]: 1008 passed, 2 failed, 135 ignored, the two failures being two
    of the three long-known ones (files that are not on this machine); the third known one passes now.
    The switch `HL_METAL_FUSED_RS` is byte-identical when on at every tested shape and worth about 3% at
    the app profile; turning it on in the app is Astra's step.
    **Nov 22, 00:51 UTC, Lean (two legs of Claude's lane):**
    (1) Leg 20, merged at `acf23691` [PROVED in Lean, the lane's full check green, 586 of 586 audited]:
    Antigravity's finding L68c-1 is closed. At padded rows one activation lookup needs the public table's
    entry at input 0 to be 0; that condition is now a field of the model's validity conditions, citing the
    code line that refuses a table without it (`accuracy_act.rs:21-22`, confirmed by Sol). No other lookup
    has the same gap [READ]. Sol's geometry values, checked against a real verified receipt, match the
    Lean constants (39 of 39) [CHECKED by script]. The finding that the layer range is not pinned (L63-14)
    is answered by Sol and recorded as a deployment premise; the eight such premises of the Lean top are
    listed in plain words in `results/zk60_lean_l63_20261116/DEPLOYMENT_PREMISES_20261122.md`.
    (2) Leg 21, a second read of the first four of Antigravity's 18 honest-prover modules [READ only,
    nothing built; `results/zk60_claude_review_20261116/L68C_SECOND_READ_1_20261122.md`]: no `sorry`, no
    wrong constant; three modules can be merged after small documentation changes. But the completeness
    results in them are conditional on an arithmetic bundle that later modules are said to prove, one
    honest-prover check in the Lean differs from the code, and the zero-knowledge premise of the top is
    still stated at an error budget that undercounts the real run (known since Nov 20). **So completeness
    and zero-knowledge of the run are not proved yet; the open list is: the slot sums, the claim truths,
    the honest-carry invariant, three premises on the site construction, and the zero-knowledge premise.**
    **Nov 22, 00:08 UTC: Antigravity's fused encoder tested at the installed app profile with six lanes
    busy [MEASURED by Claude's lane, two sets of four runs; recomputed by Claude; record in
    `results/zk60_fused_rs_app_20261121/`].** With the switch on the stream is faster in all four pairs:
    +4.4%, +2.9%, +3.1%, +1.4%, mean +2.95%. The rule posted beforehand asked for +3%, so the verdict is
    "transfers, under the bar": a real gain of about 3%, kept as a switch that is off by default. All 270
    receipts made with the switch on verified, so it is byte-correct at the app's exact shapes under
    load. A traced pair shows where the gain comes from: 17 ms less GPU execution and 9 ms less waiting
    for the GPU per block, out of a block of 569 ms whose host part (295 ms) did not move. **This
    corrects the expectation written above at 16:25 UTC:** a cut in GPU work does not reach the rate one
    for one; in percent about half of it does, because half of a block is host time.
    **22:21 UTC, two GPU-side speedups REPORTED BY ANTIGRAVITY (21:31 UTC) [its guard runs are in the
    history with exit 0; one write-up read by Claude; NOT replicated, NOT reviewed, NOT merged].** Both are
    said to leave every proof byte unchanged and are off by default. On the synthetic 8B stream: a fused
    encoder for the two large commitments, 35.86 to 38.20 tokens per second (+6.5%, lower in 6 of 6
    passes); a sparse fold with two smaller changes, 36.76 to 37.73 (+2.6%) at two lanes and less at three.
    The code exists only as uncommitted edits in Antigravity's worktrees; Claude asked for commits. The
    test that matters for the app is posted and will be run by Claude's lane once a commit exists: the
    installed profile with six lanes busy, pass at +3% in both pairs. It is also the first test of the
    expectation above that a cut in GPU work reaches the full-lanes rate.
    **Also 22:11 UTC, REPORTED BY SOL [not read by Claude]:** a full native proof of the refitted W16R3
    8B export on a held-out prompt with the exact sampler: 32 layers, 34 frames accepted by the earlier
    pinned verifier at the 97-bit floor, both owner checks passed. Sol states its scope as an isolated CPU
    audit of one trained profile; generator security and whole-run privacy remain open.
    **Lean findings REPORTED BY ANTIGRAVITY, NOT YET VERIFIED, 2026-11-20 22:45 UTC (L68b-1 to L68b-5):** two
    wrong constants in the committed block instance (`mRows` 23 where the verifier has 50; six hosted slots
    marked private), said to make block completeness unsatisfiable with no effect on soundness; the
    completeness hypotheses of L25, L29 and L32 said to be uninhabited, so those completeness results would
    be vacuous; the top's zero-knowledge error term said to count a 32-commitment run where the real one has
    79; and one zero-knowledge hypothesis (`hUw`) said to be false when 256 columns are opened. Antigravity
    proposes fixes and has a new file that builds. Nothing is changed on the working branch. Claude's next
    Lean leg (00:12 UTC) checks all five independently. Antigravity's reading (22:57 UTC, to be checked by
    that leg): the approved texts fix only the target `εzkTarget`, the top's conclusion stays letter for
    letter the same, and the change is in the hypothesis field `O.zk`; no soundness or extraction theorem
    is affected.
    **Update 23:47 UTC: Sol confirmed the five findings independently** (23:35Z and 23:41Z, against the
    R13 native source): the two constants are wrong (ruling L63-9: `mRows` 50, six hosted slots; the change
    is made by Claude's 00:12 UTC leg with the lane's full check), the completeness quantifier is
    contradictory, the real run has 112 trees and 283,822 transcript operations against the 57,344 assumed,
    and the 300-bit bound on boundary column digests fails. **Consequence: the zero-knowledge premise of the
    newest top cannot be met as stated, and the completeness helper results of L25, L29 and L32 are empty.**
    Soundness and extraction are not affected by either reading. `O.zk` stays open; the repair (column
    digests as dependent queries, an error term counted for the real schedule) is accepted in principle
    and lands only with the proofs that discharge it.
    **Landed 2026-11-21 01:20 UTC, working branch `4c4db293` (Claude's L63 leg 17; findings
    `results/zk60_lean_l63_20261116/L68B_CHECK_20261121.md`):**
    (1) **Ruling L63-9 applied and PROVED**: `mRows` 50 and six hosted slots in `RunShieldBlkInst.lean`. No
    proof anywhere needed a change, no top's text changed, and the lane's full check is green twice (guard
    runs `7198366ef441` and `b16ae08adf00`, exit 0 [receipts read by Claude]; 576 declarations audited, 23
    tops on the three standard axioms). Not claimed: block completeness itself; the change removes two
    reasons it could not hold.
    (2) **L68b-3 confirmed in Lean and wider than reported**: the hypothesis `∀ s, 1 ≤ slotD P s` is
    refuted for every block shape (false at the slot after the last), and **15 committed theorems** take it
    or one of the contracts `IncOK` / `D12aBlockOK` / `OutcOK`: 4 of L25, 6 of L29, 3 of L32 and **2 of L39**
    (`rcInc_honest_tables`, `rcOutc_honest_tables`, the "met by the real verifiers" half of the GA-1
    repair). Ten say nothing; five hold only where the honest prover never succeeds. No soundness,
    extraction or top theorem is among them [the leg's scan of every constant]. The rows of L25, L29, L32
    and L39 below carry a correction. **REPAIRED, merged 2026-11-21 01:56 UTC (L63 leg 18, ruling L63-10;
    `results/zk60_lean_l63_20261116/L68B3_REPAIR_20261121.md`):** the quantifier is bounded to the
    schedule's slots in all 15 and in the three contracts; every conclusion is unchanged, every hypothesis
    weaker, so each theorem is stronger [diff read by Claude]. One added premise on the two loop lemmas
    (the loop's slots lie inside the schedule; finding L63-13), which every caller proves. Full check green
    (guard run `aa529cfb1d58`, exit 0 [receipt read by Claude]; 586 declarations audited, all 23 tops'
    types byte-identical before and after [the leg's comparison]). **And the repaired hypothesis is PROVED
    met at the real run** (`RunStgShieldSlotDeg.lean`: every Shieldstral block at every layer, and both
    stages), so that premise is no longer empty.
    **What the repair does NOT give [ARGUED by the leg, not repaired]:** the five theorems that take the
    contracts `IncOK` / `D12aBlockOK` / `OutcOK` still cannot be used for the code's prover, for a second
    reason Antigravity had named (L32-1): the contracts fix one honest data object for every start
    transcript, while the code's prover builds its data from the transcript. Antigravity's own files avoid
    the contracts and prove the parts directly; O8 (completeness of the parts) therefore goes through
    Antigravity's route, and the ten repaired theorems that do not take a contract are what that route can
    reuse. O8 stays open.
    (3) **Antigravity's `sshC_productionReadyL_epP_openShell` (untracked), second read:** correct and
    clean, conclusion equal to blkEF's by definition, standard axioms. It does NOT eliminate `O`: O1, O5,
    O6 and O10's two sums are discharged; O2, O3, O4, O7, O8, O9, O10 per site and O12 reappear as premises
    of the same strength, and the zero-knowledge premise still carries the error term that cannot be met.
    Acceptable for the working branch after five documentation changes (its header over-claims).
    (4) **`hhdrFit` settled** (`RunStgShieldHdrFit.lean`, PROVED): it does not follow from the run and the
    query bound (a counterexample is proved); it follows from a length bound on the header words, at the
    code's widths a parameter line of at most 2^20 - 292 bytes. It stays a setting premise until the
    header writer is modelled in Lean.
    **The Lean model's constants against the code, landed 2026-11-21 02:25 UTC (L63 leg 19;
    `results/zk60_lean_l63_20261116/INST_CONSTANTS_20261121.md`):** the two constants fixed by ruling L63-9
    were wrong for days because no proof read them, so the leg listed all 58 constants that the Lean model
    of the Shieldstral run fixes and asked which were ever compared with the code. Before: 14 were compared
    with a code-side export by a committed check. Now: 43 are (a new regression in the lane's full check,
    158 checks, 0 failed [log read by Claude]; full check green, guard run `24002a82f0bf`, exit 0), 8 have
    no export and were read against the Rust source [ARGUED], 6 are derived in Lean. **No mismatch found.**
    One export of a real classify run's geometry would make most of the remaining 8 mechanical.
    **Finding L63-14 (scope, open):** the code's statement check accepts any consecutive range of layers
    that ends below 26 (`trained_statement.rs:784-795` [read by Claude]); the Lean top covers runs over all
    26 layers. The top is sound as stated, but the model matches the code only when the public statement
    lists all 26 layers, and a receipt over fewer layers proves a different function. Whether the app's
    check pins the full list is asked of Astra and Sol; not answered yet.
    **Scope fact, stated by Antigravity 2026-11-20 22:57 UTC:** the whole Lean chain up to the newest top
    models Shieldstral T128 at the **R13** profile (rows 4577 and 4390). The installed app has run the
    **W16R2** Shieldstral profile (rows 2504 and 2606, statement identity named dev-only) since 2026-11-13.
    The proved chain and the running app are two different profiles; the D63 rule applies to whichever
    profile goes to production. **Sized 2026-11-21 [ARGUED: L63 leg 18, reading and counting, no proof]:**
    moving the top theorem to W16R2 is roughly **12 to 25 Lean legs** (at three legs a day, four to eight
    days). The block layer is R13 throughout (the R13 block statement alone, lane L49, is 47 files, and
    its W16R2 counterpart exists only at the small test rung); the run and stage layers are mostly generic
    in the block shape; no Lean file contains the W16R2 Shieldstral row counts; the code has no shape
    export for that profile yet. **Probed 02:22 UTC [CHECKED in a scratch file by L63 leg 19, not
    committed]:** the committed block instance equals a profile-generic definition at R13 by `rfl`, and the
    lane's theorems that read profile numbers are recovered unchanged from an R13 instance of a profile
    record, at no measurable cost. Making the lane's own chain take the profile as a parameter is 2 to 3
    legs, but it does not make the expensive part cheaper (the block statement per profile, in other
    lanes' files), so it is worth doing only once a production profile is chosen. **Which profile goes to
    production is Victor's ruling, not made.**
    **Open after L68a:** the four stage premises `hLI_stg`, `hLO_stg`, `hdinS`, `hdoutS` and the extractor
    remainder `E0` (Claude's L63, next leg); `O : ClassifyOpenP` including `O.zk` (Antigravity's L68b); the
    header-fit fact, the verifier's free check hooks, `ShieldRun Rp`. **Not a Lean item but now load-bearing:**
    the correspondence between the Lean-defined verifier and the Rust one.
    **19:20 UTC: the working branch is at `152fdd2e` (not pushed)**, which is `f5b70efe` merged with the L63
    lane's results up to `hTrIIO` and `hTrOIO`, rebuilt from source (guard receipt `lean-l63-merge10`, run
    `57d41b37ee2f`, exit 0, peak 7.16 GiB [receipt read by Claude]; both top theorems on the standard axioms
    [lane's report]). The lane's nine newest files are not cross-reviewed yet.
  - **Open defect in the prover, found 2026-11-17 while testing a patch (not a Lean matter):**
    `clear_stale_writing_dirs` (`trained_block.rs:4763`) tests whether a writer's pid is alive by looking for
    `/proc/<pid>`, which macOS does not have, so on the Mac a live writer's `statement.writing-<pid>` directory
    is treated as stale and removed [diagnosed by Antigravity from the code; the test
    `review_n_r6_b_a_stale_statement_writing_dir_is_removed_or_refused_by_name` fails on the Mac with and
    without the patch; not yet verified further, no owner yet, asked of Astra]. Two other tests fail on the Mac
    only because fixtures above 1 MiB stayed on the laptop.
  - **Before L64, kept for the record. Open in Lean after L62 as it stood and L63's second result:** `hblkS`, `hep14`, the block alive lists
    (`hR0_blk` … `hH1_blk`, `hLU_blk`), `hdzero`, the stage claims parts `hTrIC` and `hTrOC`, the stage LogUp facts
    and dooms (`hLI_stg`, `hLO_stg`, `hdinS`, `hdoutS`), the stage degrees, `O`, `hzk`.
- **2026-11-12, the input endpoint extractor group CLOSED on the merged tree (L58, merged `c80f2311` and checked) and Astra resident writer scoped timing recorded:**
  - **L58 proved (`ex_productionReadyL_epP_codeH`):** one checked extractor for the input commitment's column test and closing openings at the code's real 84-byte `expected-IO` header (`hread`, `hE`, `mk` discharged; `49/49` `[COUNTED]` declarations audited, `0` `sorryAx`/`ofReduceBool` `[CHECKED]`; `l58_tagcheck.py` input Merkle tag + canonical-word refusal with negative control `[CHECKED]`; `RunAbsCheck` `29/29` `[CHECKED]`).
  - **Still open in Lean:** stage define/LogUp/doom facts and `hdzero`/`hdin`/`hdout` (lane L60, joining L57 + L58), and widening `L46-3`/`L56-3` boundary IO slots to wire L49's `block_knowledge_r13_shield` across all 26 blocks (lane L61). **Update 2026-11-16: both are still open after L60/L61; see the entry above.**
  - **Scoped app activation-writer latency (`resident_writer_candidate_20261112/REPORT.md`):** warm-service ABBA on one public 14-token post across 3 categories (A28 binary `80f2b704`, R13 baseline `2ba468f9`, 2 samples/arm) fell from `47.206 s` to `40.9995 s` (`-13.15 %` `[MEASURED]`), writer-only `11.762 s` to `4.081 s` (`-65.3 %` `[MEASURED]`; `26.903 GiB` `[COUNTED]` per worker, `196/220 GiB` qualified service admission/cap).
- **The answer to "are there gaps": yes, and most of the proof's substance is in them.** The strongest top theorem
  (`rt_productionReady_r13`) is a schema with 47 premises: 10 substantive open obligations (the soundness covers
  `halive`, `hdin`, `hdblk`, `hdout`, the input endpoint's `hdzero`, `hread`, `hBal`; completeness O8, O9; zero
  knowledge O12), 20 bookkeeping ones that a concrete instance would discharge, 6 modelling assumptions (the random
  oracle; the Lean verifier and prover equal to the Rust ones; the integer model equal to the code; public weights;
  an unrestricted extractor), 2 rulings and 4 public-data facts.
- **REPAIRED 2026-11-10: GA-1, the top theorem applied the way lane L34 said was empty (lane L39).** The stage
  contracts now check the number of slots, and the repaired contracts are proved to be met by the REAL stage
  verifiers and by the honest segments; the audit's proof of emptiness no longer builds. **CORRECTION
  2026-11-21 (finding L68b-3, checked in Lean by L63 leg 17): the two theorems behind "met by the real stage
  verifiers and by the honest segments" (`rcInc_honest_tables`, `rcOutc_honest_tables`) take a hypothesis that
  is false for every block shape (`∀ s, 1 ≤ slotD P s`, false at the slot after the last), so they say
  nothing as they stood. REPAIRED the same day (L63 leg 18, merged 01:56 UTC): the hypothesis is bounded to
  the schedule's slots and is proved met at every stage verifier (`shdSD_incV`, `shdSD_outcV`), so the two
  theorems now say what was claimed, given their remaining premises on the honest tables.**
  L39 also restated the
  soundness covers in a weaker, correct form and the top theorem in the approved form
  (`rc_productionReadyL_r13_exec_top_range`), but proved none of the covers. Finding L39-2: the per-block soundness
  theorems cannot be plugged in as a run-level premise directly; the link goes through the run's transcript. Lane L43
  is proving the "alive" half of the covers; the doom half and the endpoint follow after L41's block join.
- **2026-11-10, the alive half of the covers begun (L43, merged and checked):** the data the covers talk about is
  built from the verifier's own readers, and at the app's per-block model one of the nine ordered conditions
  (`hal_opA`) is proved outright. Two more (`hal_opB`, `hal_M`) are proved at every block, up to the extraction step.
  The app's top theorem in the approved form is `rc_productionReadyL_r13P_exec_rk`. Lane L45 continues: the stages'
  readers, the extraction, and the remaining six conditions.
- **2026-11-10, the doom half begun (L46, merged and checked):** the per-block doom cover `hdblk` is PROVED at the
  app's per-block model. If a block's relations fail, some check in that block's part of the run started from a false
  claim. The proof goes through the run's transcript and L36's algebra. The app's top theorem was then
  `rd_productionReadyL_r13P_exec_blk`; since L48 it is `og_productionReadyL_epP_exec_blk`, at the real opening
  widths (see L45-2 below). Still open: the two stage covers and the three input-commitment links, and the
  boundary IO slots' polynomials (L46-3), which tie each block to the run's boundary planes.
- **2026-11-10, the stages' algebra (L57, merged) and a thirteenth unmeetable premise (L57-1, High).**
  - **The finding:** L53's stage step lists handed each stage polynomial only the transcript cut before each header
    absorb. That stops before the root, so no fixed polynomial could be the real one (ARGUED). L57 repaired this in
    Lean with "view" lists that also read the header.
  - **Proved:** the hosting premises `hhIn` and `hhOut`. The stages' slot polynomials are now set to the real ones.
  - **Pinned:** IN-C's LogUp head at the app's profile is 15 squeezes, CHECKED against the code and PROVED in Lean.
    The run's count condition holds there, so no split head is needed.
  - **Still to prove:** the stages' define, LogUp and doom facts, and the stages' "claims true" link. Lane L60 is on
    them.
  - **To settle:** L57 also ARGUED (L57-2) that the blocks' LogUp entry has the same fault. The coordinator's reading
    is that L47's proof that the cut determines the root (L47-2) may already answer it. L60 is to settle which is
    right.
- **An eleventh unmeetable premise, found and repaired the same day (L55-1, High; confirmed in the code by the
  coordinator).**
  - **What is wrong:** the code refuses any verdict other than 0 or 1 (classify.rs:1018-1019,
    classify_cli.rs:464). The Lean verdict was any natural number with no such refusal.
  - **Why it matters:** the header absorbs only one byte of the verdict. Without the refusal, the verdict link `hW`
    is false (PROVED), and so is the stage cover `hdout` (ARGUED).
  - **Repair, Lean only:** the code's refusal is put in front of the model's check (`vdChk`). It equals the old check
    on every statement the code can build.
- **2026-11-10, the closing openings and the verdict PROVED (L55, merged).**
  - **What is proved:** the verdict link `hW` at the code's header, and every closing opening after part 0 (the 26
    block boundaries and the output endpoint). Each is at its real geometry: 38 rows, 2^14 columns, rate 1/4, 256
    checks.
  - **Checked against the code:** the geometry, on the real Shieldstral shape export and a real classifier run (24
    checks, 0 failed; 25 single-change copies all refused). No new extraction event was needed.
  - **The app's top theorem after L55 was `cb_productionReadyL_epP_codeF`; since L58 (merged 2026-11-12) it is `ex_productionReadyL_epP_codeH` (and `stgAlg_productionReadyL_epP_exec_real` on L57's stage-view branch; L60 joins both).**
- **A tenth unmeetable premise (L54-1, High, 2026-11-10; confirmed in the source by the coordinator).**
  - **What is wrong:** each block's two boundary slots read the boundary tables (BlockR13Prog.lean:657-659). The
    slot-polynomial argument in L50's alive facts can only see the A, M and H data (RunAliveSl.lean:174). So the
    premise `hsl_blk` cannot be met at those two slots for the real run.
  - **Is the protocol affected?** No. This is a modelling gap again.
  - **What still stands:** L49's block theorem. It takes the boundary data as an explicit input, and the gap appears
    only when it is plugged into the run.
  - **REPAIRED by lane L56 (merged 2026-11-10).** The slot polynomial now also receives the header's boundary data,
    and the premise is PROVED meetable. The positions it reads are CHECKED on a real two-block receipt and in the
    source.
  - **L56 also did:** tied block k to layer k of the export as a premise, CHECKED in the source (L54-2).
  - **L56 found a twelfth unmeetable premise (L56-7, High):** the boundary slots' define draws had the same
    obstruction. It is repaired for the run's kinds data.
  - **Still to widen the same way:** L46's per-block doom model at the boundary IO slots (L46-3), and L49's block
    statement's boundary inputs (L56-3). Wiring `hblk` from L49's theorem waits on both.
- **2026-11-10, the run-level wiring begun (L54) and the stages chosen (L53).**
  - **L54:** the run-level link "no doomed opening means every claim is true" (`hsem`) is PROVED on an accepted run.
    From it, the slot condition at the blocks follows, except at the two boundary slots (L54-1 above). All 26 layers'
    programs are PROVED to have the slot shape the run assumes.
  - **Open from L54:** nothing yet ties block k's verifier to layer k of the export (L54-2). Lane L56 takes it.
  - **L53:** the two stages' step lists are chosen once to match the code's stage verifiers, CHECKED on a real
    classifier receipt (108 checks, 0 failed). The stages' alive conditions and doom covers are reduced to named facts
    about each stage's own algebra. Lane L57 is proving those from the stage soundness theorems (L12, L15).
- **A ninth unmeetable premise (L51-1, High, 2026-11-10; confirmed in the code by the coordinator).**
  - **What is wrong:** the code absorbs the classifier's input root only once, as the last 32 bytes of an 84-byte
    header message (`expected-IO`, classify.rs:1147-1153 and :1283). The Lean model read roots only from 32-byte
    absorbs. So L48's premise `hInAbs` is false at the real run (PROVED), and so is the route to the input
    commitment's closing opening and to the link `hBal`.
  - **Is the protocol affected?** No. The root is bound before every challenge (ARGUED); the gap is in the model.
  - **REPAIRED the same day, Lean only (repair B; lanes L51 and L52, merged and checked).** The extraction now reads
    the root where the code puts it. Several premises are now PROVED at the code's real header: the input
    commitment's closing opening, its column test built from that opening, and the links `hwin` and `hBal`. The extra
    extraction event's cost is PROVED: the R13 budget is 55,852,891 of 67,108,864 units (83.2 %).
  - **The app's top theorem to cite is now `eb_productionReadyL_epP_codeT`.** It has 124 binders against L50's 136.
  - **Still open at the input endpoint:** one checked extractor for the test's columns and the openings, with its
    failure event; `hread`, `hE`, `mk`; and `hdzero`, which waits on lane L53's stage lists.
  - **L52-5 answered from the code:** both receipt readers refuse any field word that is not fully reduced
    (`private_block/wire.rs:211-216`, `token_io.rs:1512-1515` and `:1601-1610`). So the Lean extractor is right to
    drop such columns.
  - **For Victor:** whether to also fold a one-line code change into W16R3. It would absorb the root on its own, so a
    later re-proof can use the simpler model. That is D79, open. The Lean side of that change is already PROVED.
  - **Also done by L51:** the run header is now the code's in Lean, checked against a real receipt by replaying it
    under BLAKE3 to the code's own binding (29 checks, 0 failed; 20 negative-control cases as required).
- **2026-11-10, the alive half continued (L50, merged).** The six remaining alive conditions are reduced, at all 26
  blocks, to three block-level facts read at each block's place in the run. Those facts are argued to follow from
  L16's, L36's and L47's block results, but they are not yet wired in. The stage parts are still premises. The app's
  top theorem is now `ra_productionReadyL_epP_exec_alive`. Lane L53 is taking the two stages: which stage steps the
  run lists, their alive conditions and their doom covers. Finding L50-1 showed these must be chosen together.
- **Soundness of the 26 blocks is assumed at run level (GA-3).** No top theorem uses a block theorem yet; the blocks
  enter only through the premises `hdblk` and `halive`. Since L49 the app's block statement itself has no
  block-level premise left; lane L54 is wiring it into the run. Zero knowledge of the run is assumed outright (GA-2).
- **The plan, in order:**
  1. DONE 2026-11-10 (L39): repair GA-1;
  2. DONE 2026-11-10 (L40): a run model with one shape per block, so the real Shieldstral classifier is
     representable (GB-2);
  3. prove the soundness covers, wiring in the per-block results (L31, L35, L36);
  4. a concrete Shieldstral instance and one theorem stated at it (GA-4, GB-3), with the public data read by the
     verifier as FlashProve does;
  5. an executable whole verifier tested on real Shieldstral T128 receipts (GB-4, GB-6), and Lean mirrors for the
     unmirrored checks (GB-5);
  6. completeness (O8 to O10), then zero knowledge (O12) after Victor's rulings D75 (1), (2) and (6).
- **No end-to-end theorem about the real app exists yet.** Every top theorem is "proved, given named premises". Its
  verifier is a skeleton over abstract parts (GB-3), and no runnable whole-run Lean verifier exists (GB-4).
- **CLOSED 2026-11-10: the approved statements now pin the leakage (GB-1; Victor's ruling D76, lane L42).** The
  approved gate is `ProductionReadyL`, which names the allowed leakage; for the media classifier it is
  `classifyLeak`: T, d, the layer count, and whether the request is served. A protocol that publishes its input passed
  the old gate and provably fails the new one (`leaky_not_productionReadyL`). Zero knowledge is now asked for q, R ≤
  2^64, where the computed error meets the target, so that premise can be met.
- **CLOSED 2026-11-10: the run model now represents the real Shieldstral classifier (GB-2; lane L40).** Each block
  has its own shape. The app's real model, read from its own verifier export (26 distinct calibrations: the norm
  constants differ in every layer, L40-1), is proved to be an instance (`shield_circuitIff`), and every gate is
  re-indexed to it (`rt_productionReadyL_r13P_exec_range`). Only these per-block `…P` gates apply to the app. The
  approved model is now also computable and was run against the Rust witness on the R13 fixture (69,018 checks, 0
  failed). Still not compared: the trained goldens (they need the weights) and a multi-block run.
- **Every Lean-versus-Rust test is on small development receipts** (T = 32, one or two blocks, synthetic weights).
  No Shieldstral T128 receipt and no 26-block run has been checked (GB-6). Several verifier checks have no Lean
  mirror and no test (GB-5).
- **The integer model was not compared with the 8B, Shieldstral or TinyLlama goldens** as the statements document
  says; it was compared on one synthetic block and one width-16 rung (GB-8).
- `CircuitIff` adds nothing to the gate on its own; its content reaches the protocol only through `KnowledgeSound`
  (GB-9).
- **2026-11-10, Victor ruled every open question (D76, D77, D78):** the allowed leakage is written into the approved
  statements and the zero-knowledge range is q, R ≤ 2^64 (lane L42 amending `Statements.lean`); the corrected input
  opening at the largest radius is the production instance; a single-calibration Shieldstral export for W16R2,
  accuracy check first; W16R3 gets C1, C2, C3, C5, C7 and the token stages, not C4 or C9; the prover shortcut
  `HL_A26_KEPT` is on for the app, the verifier shortcut is not.
- **THE APP'S BLOCK: no block-level premise left, at all 26 Shieldstral layers (L49, merged 2026-11-10).**
  - **What is proved:** `block_knowledge_r13_shield`. For each of the 26 real layers, at that layer's own program,
    shape and calibration: the chance that a block is accepted while its relations fail is at most the target error.
    The same holds at the R13 development rung (`block_knowledge_r13_rung`).
  - **Gone from the statement:** every block-level premise. That covers the slot program, the public tables, the six
    hosts' identities, the helper layer and the whole lookup side.
  - **Lookup count:** 66,977,792 for the app's block, with the exp and ACT tuples. It is PROVED within 2^26, which
    settles L47-4's estimate.
  - **Checked against the code on a real R13 rung receipt:** the host public tables (106 checks committed, 170 in the
    full corpus, 0 failed, every negative control caught) and the LogUp sum claim (113 checks, 0 failed).
  - **What it still assumes:** run-level premises; that the verifier is the code's; four profile facts (the sum claim
    and three slot kinds), CHECKED at the rung and ARGUED at Shieldstral (L49-LOOK-1); and the public data.
  - **The first real Shieldstral block was checked in Lean (gap GB-6 narrowed).** L49's sub-agent proved and verified
    layer 0 of the app's T128 export on the CPU. Prove took 3.9 s and verify 0.1 s, out of 213 s in total (MEASURED,
    one run on the shared Mac).
    - **Result:** Lean agrees with the code on 210 checks, 0 failed, with 27 of 27 negative controls caught. It
      computed 9.19 M table entries itself. The LogUp sum claim's 106 parts match.
    - **Not yet:** the 7 weight folds need the full corpus outside the repo. That run was stopped to free the build
      queue, not failed; it is to be re-run off-peak (about 20–30 min).
    - **Not end-to-end:** the block's input is a fixed public token sequence, not the app's prompt path (L49-PUB-5).
  - **Not yet:** the run-level top theorem does not use this block statement yet (GA-3). Lane L54 is wiring it in.
- **Block level at the W16R2 development rung: no block-level premise left (L47, merged and checked 2026-11-10).**
  - **What is proved:** the one-block statement at the W16R2 rung (`block_knowledge_look_w16r2_rung`). The table
    slot's identity, the lookup side's tables, multiplicities and helper relations are now proved from the committed
    data.
  - **Checked against the code:** the public tables were compared by value on real rung receipts: 254 and 94 checks,
    0 failed, and every negative control was caught.
  - **What it still assumes:** run-level premises (the random oracle, the commitment, the code's rung verifier) and
    public data.
  - **This is a development shape, not the app's block.** At R13, the app's format, only the table slot's identity is
    done (at the rung and at all 26 Shieldstral layers).
  - **Next:** the rest of the app's block at R13. DONE by lane L49, above.
  - **Finding L47-4:** the lookup count lane L36 used left out two tuple kinds. The corrected count at the app's block,
    66,977,792 with the table term, still fits under 2^26 (margin 131,072; ESTIMATE, L49 is to prove it), so L36-1's
    bound holds.
  - **Correction to my earlier checks:** the merged-tree checks of L41–L46 audited the axioms of lanes L9–L40 only. Each
    of L41–L46 was audited in its own worktree. From L47 on, the merged check audits every lane, L41–L47 included.
- **Block level, later on 2026-11-10 (L41 and L44 merged and checked; the full Lean build 3703 jobs):** the one-block
  statement is joined at all six host slots of the W16R2 rung (`block_knowledge_host_w16r2_rung`). The block's
  table layout is checked against a real receipt through a test-only Rust export: 1,685 checks, 0 failed. The R13
  slot program is written and confirms the app block's derived counts (146 / 54): 2,041 checks, 0 failed. Left at
  block level: one table slot's identity and the lookup side (lane L47), then the same at R13 and at all 26 real
  layers.
- **Block level, 2026-11-10 (L35 and L36 merged and checked; the full Lean build 3652 jobs):** the block's `define` is
  a Lean slot program checked against a real development receipt (143 checks, 0 failed), and the block's relations
  and lookups follow from the slot claims. L41 is joining the two halves into one block statement whose only
  remaining premises are run-level and public data.
- **An eighth weaker-than-claimed result (L45-2, High, 2026-11-10; confirmed in the code by the coordinator).**
  - **What is wrong:** the Lean opening model fixes every opening's width at 2^14, which is the block openings'
    geometry. The code's registered tier opens the two stages at 2^12 and the classifier's INPUT commitment at 2^8,
    rate 1/8, with 2,048 encoded columns.
  - **Consequence:** the top theorem cannot yet be applied to the app's stages and input commitment.
  - **Also affected:** lane L26's corrected input-opening instance, which Victor adopted in D77, was built on the block
    geometry. The ruling stands (the unique-decoding radius at its largest). Its numbers do not: at the real geometry
    the radius is about 768 of 2,048 columns, not 24,448 of 65,536. The register records this correction as D77a.
  - **REPAIRED the same day by lane L48 (merged 2026-11-10).**
    - Each opening's width is now a parameter. Every old theorem still holds at the block width.
    - The real widths are named and checked against the code: the stages at 2^12, rate 1/4; the input commitment at
      2^8, rate 1/8. The comparison ran 29 checks, 0 failed, and all 21 deliberately altered copies were refused.
    - The input commitment was rebuilt at its real width. Radius 768 is PROVED and is the largest possible. The
      column test is ≤ 2^-173 per query, which confirms D77a's estimate. Victor's D77 (1) instance is now
      `classifyProtocolUExecEp`.
    - **The app's top theorem to cite is now `og_productionReadyL_epP_exec_blk`.** It has the stages at 2^12, the
      blocks at 2^14, the input commitment at radius 768, and L46's per-block cover. The older
      `rx_productionReadyL_r13P_exec_own` is still true, but the real run cannot meet its premises (L48-4).
    - **Still open there:** the closing openings after part 0, the endpoint's reading of the run, the six remaining
      alive conditions, the covers `hdin`, `hdout` and `hdzero`, and a new small premise `hInAbs`. The header's
      absorption of the input root is not modelled yet (L48-3, Medium). `hInAbs` then turned out to be false at the
      code (L51-1, above). L50's `ra_productionReadyL_epP_exec_alive` restates this theorem with the alive
      conditions reduced.
- **L45, the alive half continued (merged 2026-11-10):** the stages' accumulator readers, and the run's own Merkle
  work and extraction. The extraction premise is gone, and every part's A, H and M opening facts are proved (at the
  block geometry; see L45-2 above).
- **A fifth weaker-than-claimed result, found and repaired by lane L36 (L36-1).** Every block statement since L21
  assumed the 8B block's lookup count (35.2M), but the app's Shieldstral block makes 64.3M lookups. So L31's
  statement for the app's block said nothing about it. L36 re-proved the chain at a bound of 2^26, which the app's
  block meets; cite `block_knowledge_alg_r13_shield_lk26` for the app's block.
- **Against FlashProve:** FlashProve has one closed theorem about one concrete Lean verifier. Ours is a gate over
  abstract parts. Closing the difference needs a concrete classify-run verifier with per-block shapes, the public
  data as a value, the parts proved at that instance, an executable form run on real receipts, and the leakage fixed
  by a ruling.

**2026-11-05: efficiency first (Victor). Plan: `ZK60_EFFICIENCY_PLAN_20261105.md`. Phase A results so far
(byte-preserving, measured on the Mac, every receipt verified; `results/zk60_effplan_20261105/`):**
These timings use synthetic diagonal public weights at the true 8B geometry, so dense-weight work is not yet measured
here. The rates count proving and witness work. Verification time is recorded separately, as
`ZK60_THROUGHPUT_TARGET.md` asks: about 2.3 s per receipt, from four stream receipts verified in 9.3–9.9 s.

| One W16R2 8B T128 request, 32 blocks, forks N = 6 | before (2026-11-04 night) | now |
|---|---:|---:|
| preflight (A2) | 0.35 s | 0.08 s |
| the sealing pass, the serial forward chain (A4: weight products on the GPU, exact; A15: its own 8-thread pool) | 5.45 s | 3.3–3.4 s |
| the fork run's host work (A11: one rayon pool per fork, not one shared pool) | about 0.5 s per block | stream +19%, proof only −9.5% (A/B, both orders) |
| the device slots' tables, 1.32 GB per block (A12: built on the GPU, not the CPU) | about 47 ms per block per fork | stream +5%, proof only −6.5% (A/B, both orders) |
| the openings' store folds (A8: row-sparse, prefetched, 16-bit lanes) | A 24.6 ms, H 31.5 ms per fold | stream +2.2%, proof only −2.9% (A/B, both orders) |
| the forks' host sums (A14: summed exactly, reduced once) | — | proof only −2.8%; the stream unchanged when re-checked on top of A15 (A/B, both orders) |
| the sealing pass's thread pool (A15: 8 threads, not the 32-thread global pool) | sealing 4.3 s | one request −10.5%, stream +16.1% (A/B, both orders, every pair) |
| the forks' lookups and repeated public checks (A17: lookups read in place; the preflight's check record reused) | — | proof only −3.6%, stream +2.6% (A/B, both orders, every pair) |
| the sealing builder's serial work (A16: cached layouts, parallel loops, one public check per block) | sealing 3.5 s | **sealing 1.5–1.7 s**; one request −23.8%, stream +12.8% (A/B, both orders, every pair) |
| the forks' table helpers and registry re-check (A18: inverse tables reused; the preflight's record stands in for `define`'s check) | 4.65 ms per block | 0.78 ms; neutral overall: one request −1.9%, proof only +0.7%, stream +0.3% (A/B, both orders) |
| production's D55 path proves with the blocks its sealing pass loaded (A19: no second load of all 32 blocks) | 19.3 s per request in production | **15.3 s**; one request −20.9% (A/B through production's function, both orders, every pair) |
| production's per-request host work (A20: the loads 4 layers ahead on their own threads, the record's digest beside its SHA-256s, the receipt written by 16 threads) | 16.1 s per request in production | **8.0 s**; one request −50.1% (A/B through production's function, both orders, every pair) |
| production's host hashing (A21: SHA-256 on the Arm SHA-2 instructions, in-tree; the block digest as BLAKE3's tree in parallel) | 7.86 s per request in production | **7.23 s**; one request −8.0% on the merged tree (−10.5% in the agent's 6-pass A/B), every pair; the verifier −30% |
| **one request from its input, all witness work on the clock (the harness: the model already in memory)** | 11.1 tok/s | **23.4–23.9 tok/s** (best 5.35–5.47 s) |
| **one request through production's `stack-prove` path (each layer loaded and hashed per request; synthetic 8B stack)** | 6.6 tok/s (19.3 s, before A19) | **18.3–18.8 tok/s** (best 6.82–6.98 s) |
| **production's stream, `stack-serve` (A22: the model loaded once, one request's sealing beside the last one's proof; A23: the resident blocks shared, their startup digests and checks reused, D72/D74), 4 requests, steady** | — (no production stream before A22; 29.2–29.7 with A22 alone) | **32.4–32.6 tok/s** (amortized 27.5–27.8; 8 requests 31.9–32.2 steady, 29.4–29.7 amortized; one request 20.2 tok/s) |
| **a stream of 4 requests, steady (the harness)** | 15.9 tok/s | **32.3–33.4 tok/s** (amortized 28.8–29.6; latency 5.8–10.9 s). Re-measured 2026-11-17 on the current build, the harness's `serve4` arm: **35.5 tok/s** steady (amortized 29.7; one request alone 21.0; one block's proof core 268 ms, GPU busy 35% of it) [MEASURED by Antigravity, medians of 6 and 7 warm passes; reviewed, `results/zk60_claude_review_20261116/BATCH6_REVIEW.md`; one session, not an A/B against the older binary, so the difference is not attributed to any change]. Witness (sealing) pass profiled the same day: **2.2 s alone, 3.35 s beside a proof** (x1.51 to x1.56). Alone, 71% to 75% of it has no GPU witness product in flight, and the largest piece is the 31 gaps between blocks, about 36 ms each (1.17 s); what code fills those gaps is not measured yet (a sampler split is running, `results/zk60_claude_batch8_sealing_split_20261117/`). A third lane gives no gain today (about 2% slower, at the noise floor). The two-lane stream is balanced on both terms: the prove call beside sealing is 3.70 s and (sealing + write + prove)/2 is 3.64 s, against a 3.67 s cadence, so 50 tok/s (2.56 s per request) needs the prove call and the sealing side both down by about x1.3 to x1.45 [MEASURED by Antigravity, medians of 6 warm passes, the harness's synthetic stack with the GPU trace on, a session 1% to 2% slower than the one above; reviewed and recomputed, `results/zk60_claude_review_20261116/BATCH7_REVIEW.md`; the last sentence is the coordinator's ARITHMETIC]. The same traces read by phase: in the stream the prove call runs on a **saturated GPU for about 70% of its length** (2.5 to 2.7 s of 3.5 to 3.8 s), half of that GPU time is the five domain zero-check sumchecks, and the host-only rest is 1.0 to 1.2 s. GPU work alone is 2.5 to 2.7 s per request against the 2.56 s that 50 tok/s needs, so on this machine the target needs GPU work removed as well as host time; on a faster GPU the host-only time and the sealing pass would be the limit [RECOMPUTED from the kept traces by one agent, `results/zk60_claude_review_20261116/STREAM_GPU_PHASES.md`, not cross-reviewed; the floor is a MODEL]. The sealing pass split by function: half of it (1.07 of 2.18 s) only finishes the previous block's witness, about 0.3 s of that repeats a public check [MEASURED by sampler, one Claude agent, `results/zk60_claude_batch8_sealing_split_20261117/REPORT.md`; cross-reviewed by Antigravity, stands with notes: in unsampled time the half is about 0.95 s]. **A33 stage 1, a patch that drops the repeat on the sealing chain (merged on the working branch 2026-11-17 19:48 UTC as `a6eee4b0`, not pushed, after Antigravity's cross-review and Sol's and Astra's word that no source pin covers the files; source commit `b2330b16`; the reference binary `aaaab7e6...` is now the pre-A33 build):** one request alone 6.14 to 5.89 s, its sealing pass 2.181 to 1.906 s; the two-lane stream does not gain: over eight runs (24 passes per arm) the patched side is 0.2% to 0.9% slower, not separated from noise, and the 0.3 s saved in the sealing pass reappears as waiting (lane admission +0.28 s, prover wait +0.32 s), because the prove call paces the stream. So the second stage of this item (moving the witness-only work off the forward chain) would buy latency only and is not started [MEASURED by one Claude agent, A B A B, 12 warm passes per arm against the reference binary; byte gates equal; awaiting cross-review and Sol's and Astra's word on their source pins]. A34, running the 31 boundary commitments concurrently, was investigated and closed: it needs a change to a pinned file and would save about 0.10 s |
| proof only | 22.7 tok/s | **32.5–34.2 tok/s** (best 3.75–3.94 s; it varies from run to run on the shared Mac) |
| **the media app (Shieldstral classifier, R13 blocks, T128, 3 category proofs per post), through the app end to end: every receipt freshly verified, publication included (A24, 2026-11-07, merged 9be693d0; development mode `shieldstral-fast`, privacy statement pending, not production)** | 0.17 proved tok/s (r16b, CPU 2 threads; Astra 2026-11-05) | **one post 5.5 tok/s (70 s); an 8-post stream 11.4 tok/s** (269 s; second half 15.4) [MEASURED, public posts, single runs on the shared Mac] |
| **the media app with lane A26's binary (the same receipts byte for byte; the CPU work per category proof cut by a third; development mode `shieldstral-fast`, privacy statement pending, not production)** | A24: native stream 11.25 tok/s, one post 55.2 s; app stream 11.4 | **native stream 14.10 tok/s (+25%, A/B pairs both orders), one post 46.7 s (+18%); through the app: stream 13.8 tok/s, one post 54.4 s (7.1 tok/s); proof only 15.5** [MEASURED; app rows single runs] |
| **the media app with lane A27's binary (the same receipts byte for byte; the GPU work per category proof cut by 28%; development mode `shieldstral-fast`, privacy statement pending, not production)** | A26: native stream 14.27 tok/s, one post 46.9 s, proof only 14.7 | **native stream 16.86 tok/s (+18%, A/B pairs both orders, every pair), one post 44.2 s (+6%), proof only 17.7 (+21%); through the app: stream 16.3 tok/s, one post 47.8 s (8.0 tok/s)** [MEASURED; app rows single runs] |
| **the media app with lane A28's binary (the same receipts byte for byte; the commitments' GPU time cut by 9%, one proof's by 3.9%; two server settings; development mode `shieldstral-fast`, privacy statement pending, not production)** | A27 re-measured beside it: native stream 16.42 tok/s, one post 43.3 s, proof only 17.75 | **native stream 16.66 tok/s with the binary alone (+1.5%), 16.90 with the two settings (+2.9%; A B C C B A, mirrored order); one post 42.0 s (−3%); proof only 17.82 (no difference); through the app: stream 16.8 tok/s, one post 49.9 s (7.7 tok/s), one long post 125.5 s** [MEASURED; app rows single runs, not pairs: A27's app run of 2026-11-07 measured 16.3 tok/s, 47.8 s and 127.0 s] |

- The CLI's witness cache is now sized to the machine (A3).
- A row census: 52% of a block's committed rows are LogUp helpers, the target of the B4 and B5 protocol levers.
- **A7 (GPU timestamps): the fork run is not GPU-bound** [MEASURED].
  - In the forks phase the GPU is busy only 53–59% of the time. It sits idle when all six forks are doing host work at
    once.
  - A fork's host work per block takes 0.47–0.62 s with six forks running, against 0.22 s alone, while only about 20
    of the 32 cores are busy.
  - Per-thread GPU queues did not help once the A/B ran in both orders (+1.4% proof only, −2.7% stream). They stay
    opt-in.
  - The zero-check kernel work (A6) is deferred, since kernels are not the limit.
- **A11 found and fixed the cause** [MEASURED]: the six forks shared one rayon thread pool, so each fork's parallel
  steps waited behind the other forks' work. Each fork now has its own pool. Byte-identical; the A/B was repeated
  independently on the merged tree.
- **A12: the device slots' tables are now built on the GPU** [MEASURED]. Every table word is checked equal to the CPU's;
  the A/B was repeated independently on the merged tree. The forks phase is now about 3.9–4.0 s, against about 2.75 s
  of GPU work.
- **A8: the store folds are 2–2.5× faster** [MEASURED]. There was no Gram folding to do (each opening already reads its
  rows once); the fold was waiting on memory. The independent A/B gain is smaller than the agent's (−2.9% against
  −5.1% proof only). One note for the privacy gate: its fast path makes the prover's time depend slightly on whether
  the hidden words are 16-bit.
- **A13 did not pay, and A14 helped proof only but not the stream** [MEASURED]:
  - A13, doing each block's before-challenge work during the sealing pass: what the forks saved, the sealing pass lost.
  - A14's lazy sums: proof only −2.8%, the stream −1.8%. Re-checked on top of A15, the stream is unchanged; they stay on.
- **A15: the sealing pass now runs in its own 8-thread pool** [MEASURED].
  - On the 32-thread global pool, 25 of its 40 CPU-seconds were rayon's own waits and spins.
  - Independent A/B on the merged tree against production's previous form, every pair: one request −10.5%, the stream
    steady +16.1%. Byte-identical.
  - Phase A's expected Mac result (16–18 tok/s for one request, 22–25 for the stream) is now met.
  - The stream is now balanced: about 4.4 s of proof per request against about 4.6 s of sealing beside the forks.
- **A17: the forks' host work is 10% lower** [MEASURED].
  - At W16, lookups are read straight from the witness planes instead of being copied first (about 220 MB of fresh
    pages per block [INFERRED]).
  - Each fork reuses the preflight's record of its block's public checks. The record is used only for that very block
    object at that shape; anything else re-checks.
  - Independent A/B on the merged tree, every pair: proof only −3.6%, the stream steady +2.6%. Byte-identical.
  - On its own, A17 left the stream limited by sealing: about 3.9 s of proof per request against about 4.4 s of sealing
    beside the forks. A16 (below) fixed that side.
- **A16: the sealing pass is twice as fast** [MEASURED].
  - The builder's serial work fell from about 1.1 s to 0.04 s per pass. The block layouts are now cached per
    geometry, the per-position loops and normalization run in parallel, and production checks each block's public
    data once instead of three times.
  - Independent A/B on the merged tree through production's builder, every pair: one request −23.8% (17.4 → 22.8
    tok/s), the stream +12.8% steady and +17.1% amortized. Byte-identical; refusals unchanged.
  - **The stream is now limited by the six proving forks** (about 3.9 s per request) and no longer by sealing (about
    2.6 s beside the forks). Its steady rate is the forks' own, about 33 tok/s. The forks' host work and W16R3 are
    the next levers.
- **A18: two small fork savings, neutral overall; A13 now pays but is not in production yet** [MEASURED].
  - Each fork's table helpers reuse inverse tables already made (4.65 → 0.78 ms per block), and the preflight's record
    replaces `define`'s repeated registry check. Independent A/B on the merged tree, both orders: one request −1.9%
    (4 of 4 pairs), proof only +0.7%, stream +0.3%. That is within noise; both stay on and `0` restores either.
    Byte-identical.
  - A13's window (each fork's before-challenge work done during the sealing pass) now pays, because the stream is
    fork-bound. In the harness, at window 16: the stream +5.0% steady (6 of 6 pairs), one request −2.3%, about 12 GiB
    more memory. It stays off until production's D55 path can use it; A19 is doing that port.
  - Adding short parallel regions to the forks made them slower, since six fork pools already fill the cores.
- **A19: production's own path, measured for the first time; 21% faster; a gap to the harness found** [MEASURED].
  - `stack-prove --d55-workers` now proves with the blocks its sealing pass already loaded and checked, instead of
    loading all 32 again. Independent A/B on the merged tree through production's function, every pair: one request
    −20.9% (19.3 → 15.3 s). Byte-identical. H-1 still holds (D68, security owner's reading).
  - A13's window now works from production, but stays off: one request −0.4% to −1.0%, inside the noise, for 10–30
    GiB more memory. Production proves one request per process, and the window paid only on the harness's stream.
  - **Production's one request is 15.3 s = 8.4 tok/s, against the harness's 5.4 s = 23.7.**
    - The harness keeps the model in memory. Production loads every layer again for each request and hashes its
      record. Those loads slow the witness builds beside them about 5×, so the sealing pass takes 9.1 s instead of
      about 1.5 s.
    - Writing the 819 MB receipt adds about 1.9 s.
    - A real export also reads and pads the weight files, so production's figure is a lower bound until a trained 8B
      export is measured.
  - The harness rows above are what a server that keeps the model in memory could reach. They are not what today's
    one-request CLI gives.
- **A20: production's one request halved, 16.1 → 8.0 s (16.3–16.9 tok/s)** [MEASURED, A/B on the merged tree through
  production's function, every pair; byte-identical; H-1 still holds, D71].
  - SHA-256 runs in software on this Mac (about 0.5 GB/s). Each layer's record took 252 ms, and the receipt write was
    mostly frame hashing.
  - A19's "the loads slow the builds 5×" was a clock artifact: the builds take 40 ms each, and the sealing pass was
    waiting for its loads. With 4 loads ahead on their own threads, the record's digest beside its SHA-256s and 16
    receipt writers, the sealing pass fell from 9.7 to 3.3 s and the write from 1.95 to 0.33 s. The prove call (4.3 s)
    is now more than half of the request.
- **A21: host hashing, 8–10% off production's one request** [MEASURED, every pair; byte-identical].
  - SHA-256 now runs on the Arm SHA-2 instructions, written in-tree with no new crate: 0.5 → 2.3 GB/s.
  - The block digest is BLAKE3's own tree, hashed in parallel: 115 → 6 ms.
  - Production's one request: 18.3–18.8 tok/s. The verifier is 30% faster.
- **A22: production now has a stream form, `stack-serve`: 29.2–29.7 proved tok/s steady** [MEASURED, merged tree,
  independent A/B; D70].
  - It loads and checks the model once, then proves one request per input line. Each request's sealing runs beside the
    previous request's proof.
  - Each request has `stack-prove`'s statement identity, receipt size and frames, and passes `stack-verify`. Randomness
    is fresh per request.
  - H-1 holds per request: a refused or failed request leaves the stream running (D73).
  - **One data owner per process** (D73). A request's latency shows the previous request's timing.
  - **The gap to the harness (32.7 on the same tree) is about 11%:** the preflight re-hashes 32 block copies, and the
    forks slow beside the next request's copy of 7.8 GB of layers.
  - D72 allows CS-6 to use a digest kept with the block.
- **A23: production's stream within 2% of the harness, 32.4 tok/s steady** [MEASURED, merged tree, independent A/B,
  4 of 4 pairs].
  - The resident blocks are shared across requests instead of copied (+7.9%).
  - Their startup CS-1/CS-4 pass is reused at an equal shape (D74, +4.4%). The verifier still runs every check.
  - Peak memory is down from 60 to 46 GiB.
  - One request through the server: 20.2 tok/s.
  - What is left is the prover core: the fork run is 3.64 s of a 3.93 s period.
- **D63 Lean, the block-level `CircuitIff` proved (second round, 2026-11-06)** [PROVED; MEASURED for L1].
  - `block_circuitIff : CircuitIff (blockModel S P) (blockArith S P)` is an instance of the approved statement: a W16R2
    block's constraint system is satisfiable exactly when its output is the integer model's. `run_circuitIff` chains
    blocks through their boundary planes. Both are at the block's logical positions.
  - Newly in the iff: the matmul hand-off (every hosted value below 2^58, so the 2^62 premise is proved), RoPE, the
    products, the exp and SiLU lookups, and the gate with its class.
  - The full Lean build is green, with no warnings, `sorry`, `native_decide` or new axiom.
  - L1: the fixture passes 101,956 checks and the T = 128 rung 760,388 checks, 0 failed.
  - **Premises left:**
    - what `Satisfies` asserts, which is L3's to discharge: the zero-checks, the hosted sums and the row sums;
    - the LogUp premise, stated exactly: every looked-up tuple is in the code's table;
    - the layout map;
    - the run's boundary link.
  - **Fourth round (merged after the second): the whole forward pass.**
    - `tokenRun_circuitIff` covers the prompt ids, stage IN, every W16R2 block and stage OUT: the run's constraints
      are satisfiable exactly when the attested next token is the integer model's. The argmax ties go to the lowest
      id, as the code's `first_argmax` does.
    - `classifyRun_circuitIff` does the same for the classifier verdict.
    - The Low stack's int16 product is now inside `block_circuitIff`.
    - L1: stage OUT and OUT-C pass 992 checks, 0 failed.
    - Further candidates C10–C13 are estimates. C12 would drop the last block's dead rows, about −2.5% of a run, but it
      is a model change.
  - Not modelled: DD and the sealed-selector variants.
  - **Next:** compose with L3, which turns an accepting transcript into `Satisfies`; then the layout map; then
    `ProductionReady`. Both touch what W16R3 changes, so they wait for its freeze.
- **D63 Lean, the two statements assembled (generic, 2026-11-06)** [PROVED; `formal/ZK60Formal/Assembly.lean`,
  `ZK60_LEAN_ASSEMBLY_20261106.md`].
  - **Statement 2:** `semanticHiding_of_zeroKnowledge` turns zero knowledge into the "learns nothing about any
    property" form exactly as approved. So the receipts' hiding reduces to building one simulator.
  - **Statement 1:** `knowledgeSound_of_extract` turns an extractor of a satisfying witness into knowledge soundness,
    using `CircuitIff`. This is where the L3 soundness work and the L2 `tokenRun_circuitIff` meet.
  - **The gate:** `productionReady_of` assembles `ProductionReady` from its parts. `binding_of_colCommit` derives
    binding from the proved Merkle binding.
  - No gap was found in the approved statements.
  - **What is left for a production profile:**
    - the Lean `Protocol` instance, its prover and verifier (L5);
    - the per-profile extraction (L3 composed, the layout map, the M opening under Fiat–Shamir);
    - completeness (that an honest prover is accepted, which nothing proves yet);
    - the column-commitment instance for binding;
    - the zero-knowledge simulator (Fiat–Shamir programming, composition over the run, R receipts).

    Most of these wait for W16R3's freeze.
  - **The generic halves of the last two, proved the same day** [PROVED; `CompleteSub.lean`, `ZKHybrid.lean`].
    - **Completeness:** every sub-protocol model accepts its honest prover. That covers the sumcheck (masked,
      extended and CFS forms), the zero-check, LogUp (refusing only with probability at most M/|F|), the openings,
      M's tests and the Merkle paths. They compose into the approved `Complete` form, where each refusal is about
      2^-111 against the 2^-40 target.
    - **Zero knowledge:** the random-oracle programming lemma and the R-receipt hybrid, ending in
      `zeroKnowledge_of_hybrid` and its target corollary.
    - What is left per profile: the Lean prover and verifier, the per-receipt simulation step, the layout links, and
      the extraction.
    - **Finding A5, a ruling owed later:** summing the per-receipt bounds leaves a q·R cross term that the approved
      zero-knowledge target has no slot for. It matters only at absurd scales (about 2^126 queries and 2^118
      receipts). The fix is a sharper per-profile argument, or a cross term in the target, or a cap on R.
- **D63 Lean, L5's foundation: the verifier's primitives in executable Lean (2026-11-06)** [PROVED; MEASURED for the
  agreement check; `ExecField.lean`, `ExecTranscript.lean`, `ExecMerkle.lean`, `ExecBlake3.lean`;
  `results/zk60_lean_l5_20261106/`].
  - The field (Goldilocks and its quadratic extension), the Fiat–Shamir transcript and the Merkle column check are
    written in Lean as the Rust code runs them. Each is proved equal to the model the soundness proofs use:
    - each field operation is the field's;
    - the transcript is the Fiat–Shamir chain, and its challenges are the modelled ones;
    - the column check accepts exactly when the Merkle opening holds, so Merkle binding holds for the program itself.
  - BLAKE3 is written too, in its three modes. It stays the random oracle, so it is tested, not proved.
  - Agreement with Rust: 5,553 checks, 0 failed, including the official BLAKE3 vectors and three whole PCS openings
    replayed. A negative control of six single changes fails exactly 6.
  - On the merged tree: zkp-core's 81 tests and the export test pass, and the regenerated corpus is byte-identical.
    The Lean build has 3449 jobs and no warning. 74 declarations use at most `propext`, `Classical.choice` and
    `Quot.sound`. The L1 check still gives 101,956, 0 failed.
  - W16R3 changes none of these.
  - Finding L5-2 is already handled in the code. `Fp2::from_bytes` would read a word w ≥ p as w − p, but no decoder
    calls it. The block receipt decoder (`wire.rs`) and the ffn_v3 decoder refuse any word ≥ p, so the Lean decoder
    must copy that refusal.
  - **Left for the per-profile verifier, after W16R3's freeze:**
    - the `Protocol` instance and the receipt decoder;
    - the sumcheck and LogUp arithmetic;
    - the opening's checks (B1 changes the PCS encoder);
    - M's mask check and the D55 run schedule, each proved equal to its model;
    - a corpus from real W16R3 receipts.
- **D63 Lean, L6: the generic sumcheck verifier in executable Lean (2026-11-06)** [PROVED; MEASURED for the agreement
  check; `ExecSumcheck.lean`, `ExecMle.lean`, `ExecCfs.lean`; `results/zk60_lean_l6_20261106/`].
  - Every block slot checks its sumchecks through zkp-core's one generic verifier. That verifier now exists in Lean,
    together with its interpolation, its eq and multilinear evaluations and its zero-knowledge mask pieces.
  - **Main theorem (`scVerify_accept_iff`):** the program accepts a sumcheck exactly when the soundness proofs' model
    does, with the challenges taken from the transcript chain. This holds for every hash function. So the proved
    Fiat–Shamir soundness of the sumcheck applies to the code itself.
    - It needs degree ≥ 1 and canonical words. The block decoder enforces canonical words, and every slot has degree
      ≥ 2.
    - The caller still checks the terminal identity, the claimed sum and the openings.
  - The mask's weights give its cube sum and its value at ρ, and its rounds are the model's. The masked terminal and
    the extension round are the models', so the extended soundness theorem applies to what the code sends.
  - Agreement with Rust: 1,206 checks, 0 failed. Among them are 171 runs, honest and tampered, whose verdict, error
    message and transcript state all match. A negative control of eight single changes fails exactly 8.
  - Sol's W16R3 design keeps this mathematics; B2 only batches slots into one larger sumcheck.
  - Findings (all Info):
    - L6-1: a degree-0 round would make the verifier panic, but no slot has one.
    - L6-2: the mask weights need fewer than 64 variables, a per-profile `decide`.
    - L6-4: the Fiat–Shamir chain model counts with a natural number, while the code uses a u64. Mapping one onto the
      other is per-profile glue. (Closed by L7, below, with no premise.)
- **D63 Lean, L7: Fiat–Shamir soundness of the executable sumcheck verifier (2026-11-06)** [PROVED;
  `ExecSumcheckFS.lean`; `results/zk60_lean_l7_20261106/`].
  - **Main theorem (`exec_sumcheck_fs_sound`):** take a cheating prover that makes q hash queries and picks any
    transcript header of s operations, a false claimed sum fixed by that header, and the round messages. The code's own
    sumcheck verifier, run on the code's transcript after that header with the caller's terminal check, accepts with
    probability at most T·d/|K|·(1 + p/2^128)² plus two hash-collision terms, where T = q + s + 2n + 1.
  - At a slot's shape (degree ≤ 4, up to 2^64 hash queries, 30 rounds, a header of up to about a million operations)
    this is at most 2^-61, a Lean corollary. The exact figure, about 2^-62, is arithmetic done outside Lean.
  - L6-4 is closed with no premise. The proof reads the protocol's state off the code's own chain and never reads the
    wrapping u64 squeeze counter; two squeezes with equal counters still hash different inputs unless digests collide,
    and collisions are already counted.
  - On the merged tree: the Lean build has 3453 jobs and no warning. All 39 new theorems use at most `propext`,
    `Classical.choice` and `Quot.sound`. L6Check (1,206), L5Check (5,553) and the L1 check (101,956) still give 0 failed,
    and both Rust corpora regenerate byte for byte.
  - Findings (all Info):
    - L7-2: `sumcheck::verify` does not absorb the claimed sum, so each slot's claim must be fixed by the transcript
      before its rounds. Today's block code meets this [CODE, read 2026-11-06]: in `private_block/argument.rs`,
      `token_io.rs` and `private_attention/argument.rs`, the claim is the slot's own scalar, absorbed under
      `pb-scalar` just before the rounds, plus earlier slots' absorbed scalars times coefficients drawn from the
      transcript. The per-profile proof must show it again for W16R3's batched slots.
    - L7-3: the theorem takes a fixed header length per slot.
    - L7-4: Lean runs away on the literal Goldilocks p and on huge concrete finite types (the first draft hit the
      guard's 24 GiB cap). Later lanes state such facts for a variable p and then instantiate.
  - **After L7, the Lean work that W16R3 doesn't change is finished** apart from one generic piece: re-stating the
    composition files (`FSCompose.lean`, `FSWideRbr.lean`) on this reader, so the whole receipt's chain, including
    rounds with several squeezes (LogUp's), gets the composed bound. L8, below, does that.
- **D63 Lean, L8: Fiat–Shamir composition on the code's own transcript (2026-11-06)** [PROVED; `ExecComposeFS.lean`;
  `results/zk60_lean_l8_20261106/`].
  - A receipt checks many sub-protocols one after another on one transcript. L8 proves the combined bound for any such
    schedule, on the code's own transcript chain.
    - **`fs_code_chain_sound_sched`** (the general form): the schedule may include rounds without a message and vector
      challenges of several squeezes. The chance that some sub-protocol starts from a false claim and yet all of them
      pass is at most T·ε plus two hash-collision terms, where ε is the largest per-round error and T the hash queries
      plus the receipt's items plus 1.
    - **`exec_sumchecks_fs_sound`** (on the code): a run of the code's sumcheck slots on one transcript, each slot's
      claim fixed by the transcript before its rounds. The chance that some slot's claim is false and yet every slot's
      verifier accepts is at most the bound of ONE slot of the largest degree, with no factor for the number of slots.
      At a slot's shape this is at most 2^-61, a Lean corollary.
  - W16R3's batching (B2, B3) only changes the list of slots the theorem is applied to.
  - On the merged tree: the Lean build has 3454 jobs and no warning. All 64 new theorems use at most `propext`,
    `Classical.choice` and `Quot.sound`, and L7's 39 still do. L6Check, L5Check and the L1 check still give 0 failed,
    and both Rust corpora regenerate byte for byte.
  - Findings (all Info):
    - L8-4: a slot's terminal claim handed on to an opening needs a "release" step and its proof in the per-profile
      instance.
    - L8-5: the existing LogUp and opening round lemmas use a two-halves digest type rather than the code's 32-byte
      digests. They need a short transfer through a bijection, not yet done.
  - **With L8, the Lean work that W16R3 doesn't change is finished.** The rest waits for W16R3's freeze:
    - each slot's claim as a function of its transcript (the arithmetization);
    - the batching and zero-check rounds as their own sub-protocols;
    - the extractor (the polynomial is the committed tables');
    - LogUp, the openings and M, plus the L8-5 transfer;
    - the receipt decoder, the D55 schedule and the simulator.
- **The media app on the fast machinery (A24, 2026-11-07, merged 9be693d0)** [MEASURED; `results/zk60_a24_app_20261107/README.md`].
  - What A24 built:
    - `zk60_classify serve` keeps the classifier resident, loaded and checked once, and reuses the sealing pass's
      witnesses.
    - `check-serve` verifies each receipt once, where the CLI verified it three times.
    - The app's new development mode `PM_PROVER=shieldstral-fast` uses both servers.
  - The receipts are ordinary classify receipts: the unchanged CLI verifier accepts them. No 8B path changed.
  - Every record says "privacy statement pending" and "not production". D58 covers only the r16b CPU binary; D63 still
    holds.
  - **11.4 proved tok/s for a stream of posts, from 0.17. Victor's 30 is not reached.**
    - The stream is CPU-bound: about 300 core-seconds per category proof, a third of it verification.
    - The next lever was meant to be the classifier on W16R2 blocks, with about 1.8× fewer committed rows than R13
      (efficiency plan A10). **Lane A25 found that the real model cannot run at W16R2 as the code stands**
      [MEASURED; `results/zk60_a25_app_20261107/README.md`]:
      - At W16/W16R2, the 16-bit range families depend on each layer's requantization shifts and gate.
      - The real Shieldstral export has 17 distinct shift sets over its 26 layers. The trained-model check refuses 8
        layers, and the 26 layers would need 3 different plane lists.
      - **The 8B W16R2 figures above use one synthetic calibration in every block, so they do not yet transfer to a
        real trained model.**
      - The routes, each needing design, review and a ruling by Victor:
        - (a) per-layer plane lists in the statement's schedule;
        - (b) an export with one calibration for all layers, which is a new integer model to re-validate;
        - (c) R13 at rate 1/2 (D59-style), for a smaller gain.
      - A25's unregistered W16R2 development profile is kept on its branch, not merged. The R13 path is unchanged.
- **The media app's CPU work per proof cut by a third, the receipts unchanged (A26, 2026-11-07)** [MEASURED;
  `results/zk60_a26_app_20261107/README.md`].
  - Measured, A24's stream was not CPU-bound: about 185 CPU-s per category proof, half the cores busy. 37% of
    the prover's CPU was one product: R13 LOW+h24's FFN down projection reads a 24-bit activation, which A4's
    int16 GPU kernel declined. It now runs on the GPU as two exact int16 halves. The verifier's column test
    sums only over each weight's nonzero rows; its public tables use split eq tables.
  - A/B pairs in both orders, every receipt freshly verified: the 8-post stream 11.25 → 14.10 proved tok/s
    (+25%), one post 55.2 → 46.7 s, the proof-only clock 12.4 → 15.5. Through the app: 13.8 tok/s (stream),
    54.4 s (one post). CPU per proof 185 → 124 CPU-s.
  - **Byte identity on the real export:** a new fixed-entropy harness for the Mac (an interposer for
    `/dev/urandom`) shows A24's and A26's binaries make identical receipts, every file of every category, and
    each verifier accepts the other's. The app pins the A26 binary; statement identity `e4f97455…` unchanged.
  - **30 tok/s is not reached: the stream is now GPU-bound** (83% mean utilization, 96% median). What is left
    needs less GPU work per proof (A10/A25's W16R2 route and a ruling, faster device sumcheck kernels) or a
    second GPU.
  - Two further cuts are in the binary but off, for the security owner's reading of D72 / D74: the prover's
    kept digest and startup check for `classify-serve`, and a verifier that checks and re-hashes each block once
    per verification instead of twice (−20% verifier CPU).
- **The media app's GPU work per proof cut by 28%, the receipts unchanged (A27, 2026-11-07)** [MEASURED;
  `results/zk60_a27_app_20261107/README.md`].
  - A new GPU trace (every command buffer's GPU timestamps, any build, off by default) profiled one category proof
    on the real export: 6.93 s of GPU, 59% the device sumcheck slots (slot 14 alone 24%, slot 18 21%), 34% the A
    and H commitments. A third to two fifths of the big zero-checks' products evaluated parts that are affine in the
    tables, at every point of every pair of every round.
  - Those parts are now tables of their own on the device (computed once, folded with the rest: the same field
    elements by linearity), and a slot whose IR attains a lower degree than it declares (slots 14 and 18: 4 of 5)
    skips the redundant point (extrapolated exactly, re-checked by the host's replay). Slot 14 is 2.3x faster,
    slot 18 1.7x. The commitment's NTT now runs two stages per pass (it was bound by its threadgroup passes, not its
    multiplies). One proof's GPU time 6.93 → 5.01 s.
  - A/B pairs in both orders, every receipt freshly verified: the 8-post stream 14.27 → 16.86 proved tok/s (+18%),
    one post 46.9 → 44.2 s, proof only 14.7 → 17.7. Through the app (single run): the stream 13.8 → 16.3 tok/s,
    one post 54.4 → 47.8 s.
  - **Byte identity on the real export** (A26's fixed-entropy harness): A26's binary, A27's and A27 with every
    switch off make identical receipts, every file of every category; the six trained profiles' recorded digests
    (the 8B profiles included) hold on CPU and Metal, and the 8B stack's server tests pass on the device. The app
    pins the A27 binary; identity `e4f97455…` unchanged.
  - **30 tok/s is not reached (about 1.8x short).** More prover lanes do not help (6 x 5 and 8 x 4 give the same
    stream): the GPU's shared throughput still bounds it, and the commitments are 43% of its work. Next: deeper NTT
    passes (radix 8/16, a larger tile), the folds, or A25's W16R2 rows after a ruling, or a second GPU.
  - One note for the privacy gate: the three-product fold's two-product fast path is taken per element, so for an
    extension table of private data a fold's time can depend slightly on whether neighbouring hidden values are
    equal (`HL_A27_FOLD=0` removes it; README section 6).
- **One calibration for all 26 Shieldstral layers works for the faster W16R2 format (A29, 2026-11-10; Victor's route
  (b), D77 (2))** [MEASURED; `results/zk60_a29_uniform_calibration_20261110/README.md`].
  - The W16R2 acceptance check admits all 26 layers with one layout. Today's export has 8 refused and 3 layouts.
  - On the 4,872 held-out rows: no refusals (today's export: 6). Agreement and F1 against the float model are the same
    as today's export within noise.
  - D32 has no ruled metric for the classifier. "No worse than today's export": pass. "Within 2% of the float
    model's F1 in every group": neither export passes, in the same two groups on the refusal-free head.
  - Next, for the speed gain (A28's estimate: about 22–25 proved tok/s against 16.9): the profile with review, the
    W16R2 privacy gate on GPU-made bundles, the Lean re-proof, and the app's speed measured on it.
- **The media app's commitment kernels at the device's limits, and scheduling measured out (A28, 2026-11-09/10)**
  [MEASURED; `results/zk60_a28_app_20261107/README.md`]. The A27 figures here are A28's own re-measurements of A27's
  binary in the same jobs; the machine measured about 3% slower than on 2026-11-07.
  - Two byte-identical kernel changes: the commitment's forward transform skips the zero half of its first pass, and
    the column hash runs as BLAKE3's own tree in two passes. The commitments' GPU time fell 9%, and one proof's GPU
    time 5.04 → 4.84 s. Deeper radix passes and rewritten field arithmetic lost or tied: nothing is left in the
    commitment kernels in this design.
  - Scheduling does not fill the GPU's idle gaps. Seal-ahead works on one lane but gives +1.3% on six for 60 GiB more
    memory; it is built, tested and off by default. More threads a lane, more lanes and two server processes give
    the same stream: about one category proof every 6 to 6.5 s.
  - Why: a proof that takes 19.6 s alone takes 38 s beside five others. It waits 12 to 15 s for the one shared
    device instead of 5.4 s, and its host work is 1.3× to 3× slower in company.
  - A B C C B A against A27, every receipt freshly verified: the 8-post stream 16.42 → 16.66 proved tok/s with the
    binary alone (+1.5%), 16.90 with a spin-then-block wait and a 300 ms stagger (+2.9%; the prover's CPU per proof
    84 → 65 CPU-s); one post 43.3 → 42.0 s. Through the app (single runs): no change beyond the runs' spread.
  - **Byte identity on the real export** (A26's fixed-entropy harness): A27's binary, A28's, A28 with every switch
    off, and A28 with seal-ahead on and off make identical receipts, every file of every category. The six trained
    profiles' digests hold on CPU and Metal; the 8B stack's server tests pass on the device. The app pins the A28
    binary; identity `e4f97455…` unchanged; 219 app tests OK.
  - **30 tok/s is not reached (about 1.8× short, as after A27), and no byte-preserving scheduling change will reach
    it.** What is left, with A28's estimates [INFERRED]:
    - rows of W16R2's size, which needs Victor's ruling on the trained-model route (D75 (3)): about 22 to 25 tok/s
      on this stream;
    - a second GPU: about 1.9×;
    - the prover's re-checks from the startup records (`HL_A26_KEPT`, D75 (5)): about +5%;
    - the device sumcheck slots: about +3%.

    The byte-preserving levers together are about +10 to 15%, so roughly 19 tok/s.
  - For the privacy gate: the two kernels branch on shapes only; `gpu/metal.rs` and `gpu/metal_kernels.metal` have
    new digests to re-read. Seal-ahead, if someone turns it on, holds two requests' witnesses per lane.
- **D63 Lean, per profile at W16R2 (2026-11-07, Victor away: "focus on completing the lean proofs")** [PROVED; each
  lane checked on the merged tree; docs `ZK60_LEAN_L9/L11/L12_*_20261107.md`].
  - The W16R3 freeze needs Victor's approval, so the per-profile proofs now target **W16R2**, the profile that the
    code, the 8B stack and the media app's classifier run today. W16R3 will then be a swap of named definitions, not a
    rewrite.
  - **L9, the block verifier in executable Lean.** It decodes a real W16R2 block receipt (14.3 MB) byte for byte and
    replays all 1,609 of its challenges: 273 checks, 0 failed. Its Fiat–Shamir bound on the block's real schedule is
    one slot's bound for all 23 slots, at most 2^-61. Finding L9-5 (Low): W16R2 slots reach degree 5, so the L7/L8
    degree-4 figures must not be quoted for a W16R2 block.
  - **L11, the slots and the layout map.** The slots' checks and LogUp's conclusion give the block's constraint system
    at the model's positions (`blockSat_of_slots`, which feeds the proved `CircuitIff`). Checked against a real receipt:
    404 checks, 0 failed. One latent Low finding: a hard-coded lookup width that agrees today.
  - **L12, the classifier's token stages.** The embedding stage IN-C is proved as one theorem. The head stage OUT-C's
    byte lookup and margin are proved, and the run's boundary links are in place. About 2^-111 per stage
    [ESTIMATE].
  - **L10, the openings, M's test and `Binding`.**
    - The opening and M checks are executable Lean and agree with the code on a real receipt: 48 checks, 0 failed.
    - M's Fiat–Shamir bound is now PROVED on the code's own transcript at 2^-106. Until now it was assumed.
    - `Binding` is proved at the target, for the token runs and for the classifier.
    - Open (L10-6, Medium): each slot's final claim is true of the committed tables. That is the knowledge step, and
      it is L16's target.
  - **L13, the slot builders.** Lean rebuilds all 23 slot IRs of a real receipt from the shape alone, equal to the
    code's: 179 checks. Each slot is proved sound at ≤ 2^-120. The block's composed bound is an ESTIMATE so far, about
    20 bits under the target per query.
  - **L14, zero knowledge for one block (Statement 2).**
    - The chain from the honest-verifier lemmas to `ZeroKnowledge` is proved, generic in the receipt's shape.
    - The simulator runs the honest prover on a stand-in input.
    - Within the target for up to 2^96 receipts. The honest prover's model is still a hypothesis.
    - **For Victor (L14-1, Low):** the approved target is for any number of receipts. Today's proof reaches 2^96. Lane L19
      is trying a sharper count; otherwise it is a cap or a cross term, which is your call.
  - **L15, the token stages whole.** The verdict stage OUT-C (about 2^-112) and the next-token stage OUT (about 2^-108)
    are each proved as one theorem. Their sumchecks are ≤ 2^-61 under Fiat–Shamir. The registered Shieldstral policies'
    parameters are checked.
  - **L17, the block results at R13, the media app's real profile.**
    - The decoder (including the classify run's D12a segment frame), the block's Fiat–Shamir bound (≤ 2^-61), the
      openings at rate 1/4, `Binding` and the layout map all hold at R13. Every bound meets its target.
    - All 26 real Shieldstral layer calibrations pass R13's check, with a constant plane list (proved).
    - Checked on real R13 receipts: 408, 302 and 35 checks, 0 failed.
  - **Correction, 2026-11-09 (finding L31-1, High for the Lean chain; not a protocol weakness).** The block theorems
    of L16, L20, L21, L23 and L28 below all carry one premise, `SlotEval`, that no real block can meet. They are true
    as stated but say nothing about a real block. Lane L31 stated the repaired premise and re-proved the chain for it;
    cite `block_knowledge_final_w16r2` / `_r13` / `_r13_shield` and the `…N` theorems instead (the L31 bullet below).
    The counts and bounds in the bullets below stand; the proofs are the same proofs.
  - **L16 and L20, the block's knowledge statement.**
    - For any block shape: an accepted block yields extracted planes that satisfy the block's constraints, except with
      probability ≤ εsTarget for every q.
    - L20's per-position count brought the constant term from 2^-82.6 to 2^-104.2.
    - Premises left: two deterministic code-to-model links (lane L22), and the slot relations plus LogUp within a
      budget (lane L21).
  - **Correction, 2026-11-09 (findings L33-1 and L33-3, Medium).** The L14 and L19 results below hold for a prover
    that never refuses. The real prover can refuse at a challenge, and then outputs one constant refusal. With that
    accounted for (lane L33, below), what is proved is: one block receipt meets the target for up to 2^118 receipts,
    and a whole classify run as one receipt for up to 2^110. "For every R" and "2^112" below are superseded.
  - **L19, zero knowledge for any number of receipts (block level).**
    - `hHV` is now a theorem, resting on named honest-prover properties.
    - With a per-kind query count, one block receipt (W16R2 or R13) meets εzkTarget for EVERY R. L14's 2^96 cap is
      gone.
    - **For Victor (L19-2):** a whole classify run proved as ONE receipt is proved only for R ≤ 2^112. Other receipts'
      honest provers can meet this receipt's transcript states, a real event. Options: a cross term in the target, a
      cap (2^112 is proved), or a per-receipt transcript key in W16R3.
  - **L21, the block's soundness completed in shape.** `block_knowledge_target_mt`: for any block shape and every q,
    an accepted block whose extracted data fails the block's constraints has probability ≤ εsTarget. At W16R2 the
    budget is 30.2M of 67.1M units. Left for the W16R2 instance: the cover lemmas (L23) and the openings' semantic link
    (L22).
  - **L18, the media app's classify run assembled into `ProductionReady`** [PROVED, given named premises;
    `docs/zkmatrix-poc/ZK60_LEAN_L18_PROTOCOL_ASSEMBLY_20261107.md`].
    - The run has a `Protocol` instance whose verifier mirrors `verify_classify_run_with`.
    - `classify_productionReady_target`: Statements' `ProductionReady` at the approved targets, given one structure
      `ClassifyOpen` of 15 named obligations.
    - `Complete` at 2^-40 and `Binding` are proved, given the parts' completeness. The run's sumchecks are ≤ 2^-61.
    - Checked on a real two-block classifier run: 31 checks, 0 failed.
    - **Open obligations:**
      - the run's extraction, with the blocks taken jointly. Per-position counting gives about 2^-99.5, just above
        2^-100, so a path-wise one-zone count is needed (L18-2, lane L24);
      - the parts' honest provers and completeness, and the zero-knowledge honest-prover facts (lane L25);
      - `S.Valid` / `B.Valid`, which need the weights, not in the repo (D62);
      - the run's zero knowledge as one receipt (L19-2, Victor).
  - **L23, the W16R2 and R13 block instances.** `block_knowledge_target_w16r2`, `_shape` (8B, Shieldstral) and
    `_r13`, with the covers and the budget discharged.
    - It found a model bug, **L23-1**: the Lean verifier weighted a host's hosted masks with the host's own weights,
      where the code uses each hosted slot's. The Lean verifier would have refused honest receipts.
    - Fixed (3163eb09), and now caught by a new test that compares all 34 M functionals' weights with a real receipt:
      54 checks, 0 failed.
  - **L24, the run's extraction (O11), as one joint event.** A first-doom count over sub-protocol kinds along the run's
    one transcript. The 26 blocks cost what one block costs (L18-2 resolved).
    - W16R2: 31.2M ≤ 2^25 units. R13: 57.3M ≤ 2^26, within the target, with less margin.
    - **For Victor (L24-1, High):** the instance's input `opensIn` requires all N columns to open, while the verifier
      checks Q of them (256 of 65,536). So the endpoint obligation cannot hold as defined. This is a Lean definition
      mismatch, not a protocol weakness.
    - The proposed fix: the opening at the unique-decoding radius. It changes the instance's meaning of "opens", so it
      is Victor's ruling. Lane L26 builds it beside the original.
  - **L22, the openings' links.**
    - M is fully linked. The extraction failure at the verifier's own queries is ≤ (q+1)·2^-110. hsem is proved in
      L21's form.
    - Left: the A/H half of hexec, the header readers, and the probability glue (lane L28).
    - Coordinator's decision on L22-1: state the block results for the real run, where the profile fixes the header's
      squeeze count.
  - **L25, the honest provers and completeness** [PROVED; merged 6d1b21ad, checked on the merged tree 8baff9cc:
    3565 jobs, no warning; `ZK60_LEAN_L25_HONEST_20261107.md`].
    - **CORRECTION 2026-11-21 (finding L68b-3, checked in Lean by L63 leg 17):** four of this lane's
      theorems (`slotsLoop_of_prove`, `blockVerify_of_prove`, `d12a_block_complete`, `classify_parts_d12a`)
      take the hypothesis `∀ s, 1 ≤ slotD P s`, false at the slot after the last, or the contract
      `D12aBlockOK` built on it. As committed they prove nothing about an honest block that succeeds. The
      sentence below on L9's block verifier, and O8 "reduced to named contracts", are affected; the
      single-slot step, the sumcheck rounds and O10 are not. **REPAIRED the same day (L63 leg 18, merged
      01:56 UTC):** the hypothesis is bounded to the schedule's slots and proved met at every Shieldstral
      block, so `slotsLoop_of_prove` and `blockVerify_of_prove` hold as described. The two that take the
      contract `D12aBlockOK` still cannot be used for the code's prover (L32-1: the contract fixes one
      data object for every start transcript); O8 goes through Antigravity's direct route instead.
    - The honest provers are written out in Lean. L9's block verifier accepts the honest block core, for any block
      shape, so at W16R2 and at R13. The executable sumcheck verifier accepts the honest rounds at every oracle.
    - O10 is discharged for refusal sites written as transcript programs: such a site's challenge point is never one
      its own computation asked, so its refusal term is exact.
    - O8 and O9 are reduced to named contracts (each slot's arithmetic, the openings' completeness, the stage
      verifiers). O12 has only its honest-rounds hypotheses.
    - Finding L25-1 (Medium, in the Lean model, handled): the code's prover opens its own previous boundary, so the
      Lean block prover checks that too.
  - **L27, the run's transcript premises for L24's joint extraction** [PROVED; merged ba15f63a and checked on the
    merged tree, 2026-11-09: 3571 jobs, no warning; `ZK60_LEAN_L27_RUN_CHAIN_20261107.md`].
    - A kind of check (the slots, `M`, the openings' two halves, the four relation schedules, LogUp) can be laid on
      the run's one transcript part by part: stage IN-C, the 26 blocks, stage OUT-C. Every structural premise of L24's
      count then follows.
    - L24's stability premise (L24-2) is now a theorem, for every extraction that reads the prover's hash log by
      cutting it at a commitment root's first appearance. Every extraction in the code does that.
    - The Merkle extraction failure for the whole run is one event, at most (q+1)·(2^16 + 2^18)/2^126.
    - The nine kinds' totals stand as L24 counted them: W16R2 31.2M and R13 57.3M units, both ≤ 2^26.
    - **It does not finish the run's extraction.** Left as premises:
      - the run's transcript as a Lean object (the two stages are still parameters of L18's instance; lane L29 writes
        them);
      - the nine kinds' lists on it;
      - the per-part cover links;
      - the endpoint O11d, which is false at L18's instance (L24-1), so the gate must be restated on L26's instance.
    - Finding L27-2 (Medium): each part's operation and squeeze counts must be profile constants. This is L22-1 at the
      run's level, to be proved with the run's transcript.
  - **L26, the classify instance with the input opening at the unique-decoding radius, built beside the original**
    [PROVED; merged 2026-11-09; `ZK60_LEAN_L26_OPENS_U_20261107.md`]. This is the fix proposed for L24-1.
    - `classifyProtocolU` is L18's instance with one change: the input commitment "opens" to an input when all but at
      most `e` columns sit in the hash tree and carry that input's encoding. `e` is the code's unique-decoding radius:
      24,448 of 65,536 columns at R13, 8,052 of 32,768 at W16R2. The verifier, the prover, the statement and the
      receipt are the same terms, so no code changes.
    - `Binding` holds at the target for every q, and is stronger than before: no commitment opens to two inputs even
      when each opening may miss `e` columns.
    - The endpoint obligation O11d, false at the original instance, is proved at this one. The verifier's sampled
      columns miss more than `e` bad ones with probability at most 2^-172 at R13 and 2^-113 at W16R2 per query.
    - `Complete` and `ZeroKnowledge` carry over with the same bounds.
    - The run's totals with the two new kinds: W16R2 31.5M ≤ 2^25 units, R13 57.6M ≤ 2^26 (86% of the budget).
    - **For Victor (L24-1): choose A or B.**
      - A, recommended: adopt `classifyProtocolU` at the largest radius. One consequence (L26-1, Low): an accepted
        receipt guarantees an opening that may miss up to `e` columns, so a later audit that re-opens the input
        commitment must accept such an opening. Honest provers open every column.
      - B: keep the all-columns opening. Then O11d stays false and the classify run cannot be proved production-ready
        at that instance.
      - Nothing is switched until the ruling. Both instances are in the tree.
    - Premises left at the endpoint, all deterministic: the extractor's openings verify and are canonical; the
      column test's chain link, with one code fact about the extension field (L26-3, Medium, not proved); the decoded
      plane vanishes off the token positions (L26-4, Low).
  - **L28, the openings' glue: a block's soundness no longer assumes anything about its openings** [PROVED; merged
    2026-11-09; `ZK60_LEAN_L28_OPEN_GLUE_20261107.md`].
    - A block's proof ends by opening three committed tables (`A`, `H` and the mask table `M`). L22 had linked `M`
      and half of `A` / `H` to the code. L28 finishes both links for any opening geometry, so one proof covers W16R2
      (32,768 symbols, 280 sampled columns) and R13 (65,536 symbols, 256 sampled columns).
    - The code's opening check, done on pairs of 64-bit words, is proved to be the model's field equations
      (`pcsOk_groupsAccept`).
    - With the real numbers: `block_knowledge_open_w16r2` and `block_knowledge_open_r13`. The chance that the block
      verifier accepts while the committed data fails the block's equations is at most the approved target, plus one
      term for the block's input and output claims, which the run checks, not the block.
    - One block uses 30.3M of the 67.1M budget units at either profile.
    - Proved R13 opening figures at the unique-decoding radius: 2^-110 for the batching round, below 2^-126 for the
      column round. The earlier R13 column-round figure (2^-105) was an assumption (L28-6).
    - **The shape of the result (L28-1, Medium):** it holds for the real run, where the verifier fixes the header's
      draw count, as decided for L22-1. It narrows neither approved statement. The run-level proof must fix each
      block's header count and supply the endpoint term.
    - Premises left: the profile's size object, the claim counts per opening, and the reader of the claims from the
      verifier's trace (all Low).
  - **L29, the two stage verifiers in executable Lean, and the honest prover as transcript programs** [PROVED;
    MEASURED for the agreement check; merged 2026-11-09; `ZK60_LEAN_L29_STAGES_ORACLE_20261107.md`].
    - The classify run's embedding stage IN-C and verdict stage OUT-C were parameters of L18's instance. They are now
      written in Lean as the code runs them, and each is proved to accept exactly when every one of its checks
      passes, in the code's order. `classifyProtocolExec` is the instance with both filled in.
    - Agreement with the code on a real classifier receipt of the development rung (one block, T = 32): 127 checks,
      0 failed. The Lean stage verifiers accept the real IN-C and OUT-C segments and end on the code's final
      transcripts. A negative control of seven single changes fails exactly 8. No mismatch with the code was found.
      Not yet checked on a Shieldstral T128 receipt.
    - The stages' completeness is proved in L25's form, so O8 holds at the executable stages, given the parts'
      contracts. **CORRECTION 2026-11-21 (finding L68b-3, checked in Lean by L63 leg 17): the six theorems
      behind this sentence (`stSlotsLoop_of_prove`, `incVerify_of_prove`, `outcVerify_of_prove`,
      `inc_stageInOK`, `outc_stageOutOK`, `classify_parts_exec`) take the hypothesis `∀ s, 1 ≤ slotD P s`,
      false at the slot after the last, or the contracts `IncOK` / `OutcOK` / `D12aBlockOK` built on it, so
      as committed they establish nothing for an honest run that succeeds. The
      acceptance-exactly-when-every-check-passes result and the agreement check above do not use it.
      REPAIRED the same day (L63 leg 18, merged 01:56 UTC): the hypothesis is bounded and proved met at
      both stages, so the first three hold as described; the three that take a contract still cannot be
      used for the code's prover (L32-1), so "O8 holds at the executable stages" is NOT yet usable.**
    - The honest slot loop is one transcript program, and a refusal of the honest prover in a block's core, in IN-C
      or in OUT-C is one of a short list of events (toward O9).
    - **No `ClassifyOpen` field is discharged outright.** O8 and O9 are reduced further; O12 (the run's zero
      knowledge) is not started.
    - Finding L29-3 (Low, an estimate): stage IN-C's refusal count is about 2^20.7 values, against L18's 2^17. It is
      still inside the proved margin; the sites are not yet built in Lean.
  - **Interrupted 2026-11-07 19:11Z, resumed 2026-11-09.** A usage limit stopped the lanes L26, L27, L28, L29 and A28
    (the app's commitment kernels and GPU idle time) in mid-work. Nothing was lost: each lane's files were in its
    worktree, and each was resumed there on 2026-11-09. All five are merged: L26, L27, L28 and L29 (above), and A28
    (its row and bullet are with the other media app rows near the top). By the L32 check the full Lean build is
    3621 jobs, with no warning.
  - **L31, the block instance: a flaw in the block chain's premise found and repaired; the bookkeeping premises
    discharged; the slot polynomials only half done** [PROVED; MEASURED for the agreement check; merged 2026-11-09;
    `ZK60_LEAN_L31_BLOCK_INSTANCE_20261109.md`].
    - **Finding L31-1 (High for the Lean chain; not a protocol weakness).** Since L16, every block theorem took a
      premise `SlotEval`: each slot's polynomial, evaluated at the challenges, equals the code's terminal expression.
      As written it asked this for challenge vectors of any length, and the code's expression reads the extra
      entries. No real slot polynomial can satisfy it. So the block theorems of L16 to L28 were true but empty at a
      real block.
    - **The repair.** `SlotEvalN` asks the identity only at the sumcheck's own challenges. The whole chain is
      re-proved for it in new files, by the same proofs. Coordinator's decision: every lane cites the repaired chain;
      the older block theorems are superseded; editing `SlotEval` in place is a later cleanup.
    - **Final block statements:** `block_knowledge_final_w16r2`, `_r13` and `_r13_shield` (the app's block, at the
      Shieldstral T128 schedule, which no earlier lane had): the block verifier accepts while the committed data
      fails the block's equations with probability at most the approved target plus the endpoint term. The app's
      block uses 30.4M of the 67.1M budget units.
    - **Discharged:** L28's bookkeeping premises. The block profile objects are built with their bounds proved, the
      reader of the verifier's claims is proved on its own trace, and the claim counts follow from the commitment
      schedule.
    - **Checked against real receipts:** 82 checks, 0 failed, on the W16R2 and R13 rung receipts; a negative control
      of 8 single changes fails exactly 8. The app block's two claim counts (146 and 54) are derived by rule: no
      Shieldstral R13 block receipt is in the repository (L31-3, Low).
    - **Not done:**
      - the tables part of the slot polynomials (the block's `define` as a Lean definition);
      - the per-outcome algebra (the certified polynomials vanish on acceptance; the start claims give the block's
        relations; the lookup list covers the block's lookups);
      - the certified slot polynomials with their degrees.

      These stay premises of the final statements, and are the next lane's work (L35).
  - **L32, completeness at run level: the openings are done, the slots' arithmetic is not** [PROVED; merged
    2026-11-09; `ZK60_LEAN_L32_COMPLETE_RUN_20261109.md`].
    - The code's opening verifier and mask verifier, as written in Lean, accept the honest prover's openings at every
      hash function and transcript, with error 0. A block's core at R13 and both stages are accepted once the slots'
      arithmetic holds; every opening premise of L25's and L29's theorems is gone. **CORRECTION 2026-11-21
      (finding L68b-3, checked in Lean by L63 leg 17): the three theorems behind "a block's core at R13 and
      both stages are accepted" (`blockVerify_of_tables_r13`, `incVerify_of_tables`, `outcVerify_of_tables`)
      keep the hypothesis `∀ s, 1 ≤ slotD P s`, false at the slot after the last, so as committed they say
      nothing. The opening and mask verifier results in the first sentence do not use it [not in the leg's
      list of 15]. REPAIRED the same day (L63 leg 18, merged 01:56 UTC): the hypothesis is bounded and
      proved met at the real block and stages; the three theorems hold as described, given the slots'
      arithmetic and the honest-table premises, which nobody has proved at the Shieldstral run yet.**
    - The opening refusals are exact counted sites: one opening on n claims has n + 2 sites and exactly p + n + 1 bad
      values. The dependent-proximity refusal (L18-3) is now a theorem, not an estimate.
    - With stage IN-C counted as L29-3 corrected it, the run's total refusal probability stays inside the approved
      2^-40.
    - **No completeness obligation is closed outright.** Left: each slot's arithmetic along the honest run (not
      started: it is the statement that the honest witness satisfies every check); the chain of the three parts over
      the whole run; a few refusal sites still named, not built.
    - Finding L32-1 (Medium, in the Lean contracts, no statement change): the parts' completeness contracts ask for
      one honest data object for every starting transcript, but one opened table depends on the challenges. The
      honest data must be built per starting transcript; L32 does so, and the run's parts need the same.
    - Finding L32-2 (Low, code): `open_zk` would panic, not refuse, on a mask-site mismatch. By reading the code this
      cannot happen after `check_opening` has accepted; that is not proved.
  - **L33, the classify run's zero knowledge with the prover's refusals accounted for: reduced to named premises,
    not finished** [PROVED, given the premises; merged 2026-11-09; `ZK60_LEAN_L33_ZK_HONEST_20261109.md`].
    - **Finding L33-1 (Medium).** L14's and L19's one-receipt step assumed a prover that always answers. The real
      prover refuses at some challenges, after earlier steps have already absorbed masked data, and a refusal is one
      constant message. The old step cannot be applied to it. L33 re-proves the step with a refusal guard. It needs
      one new premise, which the code's refusal classes give: whether an attempt is refused depends only on the
      challenges and public data.
    - **Finding L33-3 (Medium, for Victor, together with L19-2).** With refusals counted, this proof gives the
      approved target for a whole classify run as one receipt for up to 2^110 receipts (L19 said 2^112), and for one
      block receipt for up to 2^118 (L19 said every number). These are proved from L19's estimated query counts. No
      target was changed. A sharper count of the refused cases may restore L19's figures; it was not attempted.
    - **Finding L33-2 (Low, modelling).** L19 compared any two inputs. For a statement that carries the verdict, only
      inputs with the same verdict can be compared. The law is restated that way.
    - **Proved:**
      - a prover written as an oracle program is L14's prover model, with the same output;
      - an honest block's view has a law that does not depend on the hidden data, from L25's honest rounds;
      - `classify_zk_of_model`: the run's zero-knowledge obligation (O12) in its exact form, from named premises;
      - its transfer to the corrected instance.
    - **No leak found by reading the code:** no receipt byte and no refusal was found to depend on hidden data beyond
      the declared leak (the token count, the width, the layer count and the served bit). This is a reading of the
      prover's sources, not a proof.
    - **Premises left:** the run's prover assembled as one program (it needs L32's opening provers); what a receipt
      shows; the masks', pads' and salts' properties as theorems about a Lean object that does not exist yet; the
      query counts by kind, which are still estimates.
  - **L30, the classify run's gate on the corrected instance, through the run's transcript** [PROVED; merged
    2026-11-09; `ZK60_LEAN_L30_RUN_GATE_U_20261109.md`].
    - `classifyProtocolUExec` is the instance the final assembly will use: L29's executable stages AND L26's
      corrected input opening. Its verifier and prover are the same terms as before.
    - `classifyU_productionReady_run_r13` (and `_w16r2`): `ProductionReady` at the approved targets for the classify
      run, from named premises. With L28's proved opening figures the R13 total is 55.5M ≤ 2^26 units (83% of the
      budget); W16R2 is 31.5M ≤ 2^25.
    - L26-3's code fact is proved: a base-field matrix is close to the extension-field code on a set of columns
      exactly when it is close to the base code there. L26's stability premises are theorems too.
    - **Finding L30-1 (Medium), about L27's gates.** L27's cover asks that every check of every kind is still alive on
      every accepted run. Acceptance does not give that: a prover who passes a column test by luck is accepted with
      one opening check already dead. So L27's two gates cannot be used as stated. L30 replaces the cover by an
      ordered one (each kind alive provided no earlier kind has failed), and every gate above uses it. The argument is
      reasoning, not a Lean theorem; L27's files are unchanged and its machinery is still used.
    - **Premises left** (the doc's §5 lists each by name):
      - the run's transcript as a Lean object, with the nine kinds' lists and parses on it;
      - the ordered alive premise and the per-part failure links;
      - the endpoint's reading links;
      - `ClassifyOpen`'s other fields (completeness, zero knowledge, the weights' validity);
      - the rulings L24-1 and L19-2.
  - **L34, the classify run's transcript as a Lean object** [PROVED, given named premises; merged and checked
    2026-11-09; `ZK60_LEAN_L34_RUN_TRANSCRIPT_20261109.md`].
    - The run verifier's list of transcript operations is a Lean object (`rtTr`), with its two parses and the nine
      kinds of check laid on it part by part.
    - `rt_productionReady_r13`: L30's gate applied to it. The transcript, the kinds, their forms and the endpoint's
      window premises are now theorems.
    - Left as premises: the concrete Shieldstral profile and its validity; each part's data; the schedule's
      premises; the Merkle extra work; the ordered cover's links; the endpoint's reading links. No whole-run
      comparison with a Rust receipt yet (it needs new test-only Rust).
    - Findings L34-1 (Medium: per-block results need a congruence lemma to reach the run's parse) and L34-2 (Low).
  - **2026-11-09, an outside researcher's comment** on the owner's public post called the Lean work "partial" against
    FlashProve's "formal protocol theorem in Lean". That is accurate: the top theorems hold given named premises. The
    owner asked to shelve proof size and verify the gaps first. Two independent auditors are building the full register
    of open premises, hunting for vacuous ones, and comparing with FlashProve's theorem
    (`ZK60_LEAN_GAP_AUDIT_PREMISES_20261110.md`, `ZK60_LEAN_GAP_AUDIT_FAITHFULNESS_20261110.md`).
  - **Running since 2026-11-09, on what the merged lanes left open for the classify run:**
    - L35 (after L31): the block's `define` as a Lean definition and the tables part of the slot polynomials. L36,
      not yet started: the per-outcome algebra;
    - L36: the block's per-outcome algebra (the certified polynomials vanish on acceptance; the start claims give
      the block's relations; the lookup side);
    - L37, after L32: completeness continued (the run's refusal chain, the commitments' honest claims, then the
      honest prover's slot arithmetic, the stages first);
    - L38, after L33: zero knowledge continued (the prover's masks, pads and salts as a Lean object, the run's
      prover as one program, the query counts made exact, and a sharper count for L33-3's caps).
    - L37 and L38 are ON HOLD until the gap audit's register is in (it may change their order); L35 and L36 were
      resumed on 2026-11-10 after a usage limit stopped them.
    - The lanes' standing rules are in `results/zk60_lean_resume_20261109/LANE_RULES.md`.
  - **Still open before production:** the obligations above; the D55 tree for the 8B stack; then W16R3's delta.
- **A gap the Lean work exposed: W16R2 has no token-I/O run profile yet** [CODE, `run.rs`].
  - Token-I/O runs (embedding in, LM head and argmax out) are registered for the older trained-statement profiles
    (TinyLlama, and Llama-3-8B at T32 and T128), not for W16R2.
  - So today's W16R2 throughput figures prove the 32 transformer blocks: the next-token stages are not in a W16R2
    receipt yet.
  - A W16R2 (or W16R3) token-I/O profile has to be registered, gated, and its stage cost measured. The 8B head is a
    4096 × 128,256 product on the last row.
  - `tokenRun_circuitIff` gets its production instance from that profile.
  - **For Victor, later:** the statement's admissibility cannot see the weights. This is sound under P1, but P3 (hidden
    weights) will need a statement change.
- **D63 Lean, L1 and L2 begun (merged acf5c78a; checked on the merged tree)** [PROVED; MEASURED for the L1 check].
  - The integer model is written in executable Lean.
  - The constraint families requantization (with the residuals), RMSNorm and softmax hold exactly when the integer
    model's computation does, at W16R2. They are proved one position at a time, given their inputs.
  - Goldilocks is proved prime, so the earlier L3/L4 lemmas now apply to the code's own field.
  - L1 check against the Rust witness: 101,956 checks, 0 failed. The axioms are `propext`, `Classical.choice` and
    `Quot.sound` only, and the full Lean build is green with no warnings.
  - **Not yet proved:** the block-level `CircuitIff` and `ProductionReady`.
  - **Victor's idea worked: the proofs found slack.** Candidates C1, C2, C3 and C5 together save about 11.7% of
    committed rows and 3.7 M lookups per 8B block [ESTIMATE]. None changes the discretized model, but each is a
    protocol change. C4 would widen a word class (`ZK60_LEAN_L1L2_FINDINGS_20261106.md`).
  - **Waiting on Victor:** whether these join W16R3. Recommended: C1, C2, C3, C5 and C7 in, so there is one re-proof;
    C4 declined, like B4.
- **From 2026-11-05 the Mac's GPU is shared** with a frugal-lm research agent (Victor). Timing runs wait for it to be
  idle, and clocks taken beside it are not used (`ZK60_RESOURCE_PROTOCOL.md`, last section).
- **W16R3 is worth less than first modeled** (Sol's B1–B3 note, reviewed and accepted, 2026-11-05):
  - the forks phase ×1.08–1.19 [MODEL], against ×1.44–1.64 on 2026-11-01. The old figure counted the rate change that
    W16R2 already made, and the batching saves less than assumed.
  - about 2–8% off one request, and the receipt 819 → about 767 MB [MODEL].
  - The soundness rate improves slightly (2^-102.93 → 2^-103.02). B1 carries most of the saving, and B6 needs it.
- **D64's target is ≥ 110.** Next:
  - the prover core: the forks (3.6 s a request) now bound production's stream as they bound the harness's. W16R3,
    the Lean-found row savings (C1–C5, a ruling owed) and the RTX 5090 are the levers;
  - the forks' remaining host work (zero-fill, store fold, helper inverses, public weight folds, randomness), since the
    forks now bound the stream;
  - the protocol bundle W16R3, ruled 2026-11-05 (D67): B1 + B2 + B3, no B4. Sol builds B1 first, then B2 and B3, each
    after a measured gain (`W16R3_HANDOFF_20261105.md`). B6 goes to the next profile;
    - **Sol's progress, 2026-11-06** [MEASURED, Sol's candidate sources, not merged; the public synthetic fixture,
      proof only, N = 6 quiet pairs in both orders; every receipt verified; no stream, privacy or production claim;
      `results/zk60_sol_20261105_w16r3/`]:
      - B1 passed its stage gates: proof wall −5.0% (4.103 → 3.895 s; 6 of 6 pairs favour B1), and the A/H rows take
        9.5 ms less per block.
      - B2 passed its stage gates: proof wall −0.84% more (4 of 6 pairs favour B2), and the receipt shrinks from
        818.7 to 792.8 MB.
      - B3: the lifted sumcheck's arithmetic matches the expanded reference exactly in native code. The real block,
        PCS and lookup integration is next. After that come the bundle's freeze, its full gates and one Lean / privacy
        cycle.
    - Sol is building to D67's scope. C1–C7 join W16R3 only if Victor says so before the freeze. Otherwise they go to
      the next profile;
  - the RTX 5090: the bring-up guide and scripts are ready (`ZK60_RTX5090_BRINGUP.md`: Ubuntu 24.04 LTS, the open
    NVIDIA driver, CUDA 12.9, every project tool). After it, the CUDA backend must catch up with the Metal-era device
    work under the same byte gates.

**2026-11-04 (night): Lean, Fiat–Shamir part 6 merged; the soundness target needs one more theorem (F20, Medium).**
- Proved: the wide-digest lemma, LogUp and one commitment opening under Fiat–Shamir (with the extractor), and the
  code's challenge derivations. 83 theorems, no `sorry`, standard axioms only.
- **F20.** Combining the separately proved pieces by a union bound gives 2^-97.79 per hash query for a 32-block run.
  That is 2.21 bits short of the approved 2^-100.
  - **Later that night, the one-chain composition was proved:** the rate is the maximum over rounds, 2^-102.92 per
    hash query for a block and for a 32-block D12a run (Part 7 of the L3 findings).
  - This assumes M's opening at ≤ 2^-106 per round (its proof waits on F12), and the hand-off premises (proved for
    the zero-check, premises elsewhere).
- **Two new Medium findings (Victor's decisions):**
  - **F25:** the approved target's query-free part (2^-100) is not met, because the protocol's own interactive
    soundness is about 2^-97.8.
  - **F26:** a D55 fork run is a tree of transcripts. Only a union over its 32 forks is proved (2^-97.93); a tree
    version of the chain theorem is needed.
    - **The tree version was proved the same night:** D55's per-query rate is 2^-102.92 for any number of forks,
      the same as a D12a run, given its hand-off premises and the M assumption (Part 8 of the L3 findings).
  - **Victor's rulings (D65, D66):**
    - F12 is fixed, under new profile versions (see the top).
    - One constant external refusal: done.
    - The DD dictionary's refusal is challenge-only: done, no receipt byte moved.
    - **F25 closed by the path-wise proof (2026-11-05, Part 9), for a D12a run:** a D12a run meets the approved
      target q·2^-100 + 2^-100 for every q ≤ 2^75. The query-free part is ≤ 2^-101.85 and the per-query rate is
      2^-102.92. This holds given the hand-off premises and M (both still to prove). The wider-field fallback is not
      needed.
      - **For D55,** the per-query rate is Part 8's tree theorem. Its query-free part, Part 9's zones composed over the
        fork tree, is not yet proved (L3 findings, W5; noted by Sol, 2026-11-05).
- Fixed today: F16, a run receipt now attests its context. F23: `autoImplicit` is off in `formal/`, so a mistyped
  name in a statement can no longer compile silently.
- Fixed today: L4 finding 3. The mask schedule audit now checks that each pair's actual row weights are independent,
  which hiding needs; before, it checked only that the coefficients were nonzero. It caught a leaking test fixture.
  The full suite is 904 / 3 known / 93.
- **Speed correction (H124c):** with the serial forward chain on the clock, one request on the Mac is measured at
  8.2 tok/s, not the 15.3 inferred earlier today (details below).
  - The builder's single-threaded remainder was then parallelized, byte-identically (goldens and the six pinned
    digests unchanged). The witness per block went from 0.249 to 0.167 s.
  - **One request end to end is now 12.54 s = 10.2 tok/s** [MEASURED].
  - **With the sealing pass's witnesses kept, one request from its input is 11.50 s = 11.1 tok/s** [MEASURED, all
    witness work on the clock, the receipt verified]: the serial chain 5.9 s, then the fork run.
  - **A stream of 4 requests** (the next one sealed while this one proves; D64 allows batching): 13.8 tok/s
    amortized, **15.9 tok/s steady state**, 13 to 15 s latency per request [MEASURED, all 4 receipts verified]. The
    two stages share the Mac's CPU. D64's target is ≥ 110.

**2026-11-04 (late night): F12 FIXED (D65(1)).** M now combines its claims with powers of θ starting at θ¹, for
the prover and the verifier alike. Every profile that uses M has a new version string (`/1` → `/2`), and the old ones
are refused by name. The forgery below is now rejected. Every moved golden and digest is accounted for in
`results/zk60_f12_fix_20261104/REPIN.md`. The D55 privacy-gate records and all `/1` captures are invalidated and must
be redone before any real-content switch. That switch was closed anyway: it waits on GPU-made bundles and on D63.

**2026-11-04 (evening): a soundness defect found by the Lean work, confirmed in Rust (F12, High).**
- The mask commitment M certifies its first claimed value only up to an offset the prover picks when it commits:
  the sum of its blinding polynomial, which nothing verifies.
- The forgery is reproduced against `mask_verify` (`hashline/src/zk_f12_tests.rs`).
- In the token-I/O OUT stages (next-token and classifier verdict), this would let a receipt from a shifted final
  hidden state verify. That end-to-end case is not yet reproduced.
- **Until fixed, no soundness claim is made for token-I/O or classifier receipts.** Nothing is in production.
- The fix (θ powers starting at θ¹) is proved correct in Lean. It changes every receipt's bytes, so it needs new
  profile versions (`docs/zkmatrix-poc/ZK60_LEAN_L3_FINDINGS_20261104.md`).

**2026-11-04: the D55 privacy gate is complete, the repository is public, and production now needs Lean proofs.**
- **Gate:** the merged 18-part gate ran on all 12 registered R13 D55 bundles: 12/12 D55-PASS, re-scored with the fixed
  rules (18/18 parts, pins 75/75), the only open item being the accepted G_k residual. Also: the fixed tools'
  suite (203 tests, the known r19b failure only), a rung re-gate (2/2), and FR25-17 (all 23 slots on 8B, Shieldstral
  T256 and TinyLlama). Not yet a privacy acceptance: the CLI still refuses D55 real-content runs. Victor ruled (D60, 2026-11-04) to
  "build it proper" for GPUs. The switch waits until GPU-made bundles pass the gate too (the Metal device code read,
  the backend recorded by the prover itself), and production waits for D63.
- **Anthropic's FlashProve** (Apache-2.0, `github.com/anthropics/FlashProve`) is a strong, complementary result:
  - It proves Llama 4 Maverick (400B MoE, about 17B active) at about 110 tok/s of batched prefill (24 requests) on
    one H100.
  - Its zero knowledge hides the WEIGHTS; prompt and reply are public. It has Lean proofs of soundness,
    completeness and zero knowledge.
  - Ours (P1) hides the user's inputs, outputs and activations, with weights public. Our measured figures: 22.9
    tok/s proof-only on one request, about 9 counting witness building (Mac, 8B dense, no batching).
- **Production rule (D63):** before production, every ZKP needs two Lean theorems. (1) The proof is accepted exactly
  when the output is the discretized model's output. (2) The receipts reveal nothing useful about the hidden data.
  The statements: `ZK60_LEAN_PRODUCTION_STATEMENTS.md` (approved by Victor, 2026-11-04). The latency work continues
  in parallel.
- **The witness (H124): measured, then made about 2.8× faster, byte-identically** (`results/zk60_h124_witness_20261104/`):
  - The weight products were 95% of the witness CPU time and memory-bound: every token re-read the whole weight
    matrix. Tiling them by output columns and summing i16 inputs exactly in i32 blocks cut one 8B block's products
    from 0.361 to 0.085 s, and its witness from 0.438 to 0.249 s (5.94 to 1.38 CPU s).
  - Goldens and all six pinned trained digests are unchanged.
  - ~~One request on the target's clock (proof + witness) is now about 15.3 tok/s~~ **Corrected the same night
    (H124c):** that figure built the 32 witnesses in parallel from block inputs a real request does not know yet. The
    forward chain is serial, and it was outside every clock so far. **Measured with it on the clock, one request is
    15.57 s = 8.2 tok/s** (sealing pass 8.22 s, then forks with every witness built just in time 7.35 s). Keeping
    the sealing pass's witnesses would give about 13.9 s = 9.2 tok/s [INFERRED]. The critical path is the serial
    chain, 0.257 s per block (`results/zk60_h124_witness_20261104/README.md`, H124c).
  - Proof-only is 22.7 to 24.25 tok/s at Q = 280.
  - Next: the builder's poorly parallel remainder (it shortens the serial chain), a fork-run source that keeps the
    sealing pass's witnesses, a multi-request pipelined measurement, then GPU products.
  - The new target is ≥ 110 (D64).
- **The repository is public, and all work is open source (D62)**, under Apache-2.0 (`LICENSE`, `NOTICE`,
  `SECURITY.md`). The Lean statements (D63) were approved by Victor on 2026-11-04.

**2026-11-03: correction — every proved-tokens/s figure since the Mac bring-up is proof-only; witness building was outside the clock.**
- **What was missed:** the D55 A/B harness (`run_fork_tests.rs`, `d55_ab_one_request_serial_against_forks`) builds every block's
  witness before it starts each clock. Our own target (`ZK60_THROUGHPUT_TARGET.md`) counts witness work.
- **Size** [INFERRED from measured walls, W16R2 8B T128, `results/zk60_w16r2_20261101/logs/ab/m_d55_r2b.log`]: total 110.9 s, minus
  setup 15.1 s, five timed calls 45.6 s and two verifications 7.0 s, leaves 43.2 s: about **8.6 s of witness building per request** (32
  blocks, 8 builder threads), against 5.6 s of proving. Counting it, one request on the Mac is about **9 tokens/s, not 22.9**.
  All earlier rows of the speed table (7.6 / 12.0 / 20.8 / 22.9) are on the same proof-only clock.
- **What it means for 50:** the researcher's 5090 model (`research/zkp-efficiency/handoffs/20261103-rtx5090-projection.md`) gives
  54–82 proof-only [MODEL], but 6–11 counting today's witness code, and 48–76 with an exact SIMD/GPU forward pass (H124, byte-identical,
  no ruling). The witness is now the first lever, ahead of the GPU kernels. A direct clock of `witness::build_accuracy` comes first.

**2026-11-02: the rate-1/2 commitment (D59) is built as an opt-in profile and about 10% faster, with no soundness given up.**
- **What it is:** the W16R2 profiles encode A, H, the run boundaries and the endpoints at code rate 1/2 (was 1/4) with 260 opened columns,
  counted at the Reed–Solomon unique-decoding radius. The mask commitment M is unchanged.
- **Speed** [MEASURED, 8B T128, synthetic weights, one binary, warm]: prove core 0.373 → 0.336 s per block; one request with D55 at six forks
  goes from 20.8 to 22.9 proved tokens/s; receipts grow 0.6%.
- **Soundness** [COUNTED, builder's recount]: 2^-105.93 per opening (was 2^-105.61); 8B whole run 2^-97.36 (was 2^-97.27).
- **Correctness:** all D59 malicious controls are rejected; existing bytes and goldens are unchanged; full suite 872/6/84 (the known Mac-only six).
- **Due diligence, all done the same day:** the recount was independently re-checked (every figure reproduces); the independent code
  review found no soundness defect, and its findings F1, F3–F5 and F7 are closed (including a built close-case attack that is rejected
  at exactly the counted rate); the privacy re-check found no leak.
- **Open:** Victor's ruling on Q (260 counts the proven bound; 280 also matches today's design against the best known attack, for
  about +3.5% receipt bytes), and the token and classifier bit counters must learn the new count before registration.
- **D55 is now registered (D60)** over the 12 R13 block-run profiles, with test receipts verified in a fresh process. On R13 8B T128 it
  measures 7.59 → 11.95 proved tokens/s at six forks. Its independent review found no soundness defect or leak, and its findings are
  closed. Every source file that moved since the privacy gate last read it has now been read and found safe, including an
  independent check of the three readings the wiring agent did itself (one latent issue, W-1, goes to the freeze review).
  CPU-made bundles only; GPU-made bundles are refused until the Metal code is fully read.
  The older gate items for R13 are now ported to D55. Each check passes on every bundle it has run on: all 12 registered bundles
  (now including TinyLlama and Shieldstral T128/T256) for the hash and claim checks, and the four R13 bundles for NL-1 and the
  full preimage. The hash census found one gap in the Rust table (it had never measured runs of 2 to 9 blocks), now fixed in test
  code. **Correction:** the earlier records were PASS only for the checks run at the time. Each still listed privacy checks not
  yet run on it, so none of them is a privacy PASS record. Only the gate with every check combined can give one. It is now
  running on all 12 bundles, and its first record is a full PASS.
  The separate review of the gate before its freeze is done: freeze after named fixes. It found no leak in any recorded bundle, but
  the status could reach PASS with a check skipped or a pin list cut short. Those fixes are made and are being re-checked.
  The CLI still refuses D55 real-content runs. Lifting that needs the combined records, the fixed gate frozen, and Victor's go-ahead.
- **The Mac's ceiling is about 23 tokens/s per request.** 50 still needs the RTX 5090.

**2026-11-01 (night): one request now proves at about 21 proved tokens/s with the D55 prototype (opt-in, unreviewed).**
- **What changed:** Victor approved D55. Its "commit, fork, join" profile lets one request's 32 blocks prove concurrently.
- **Speed** [MEASURED, W16 8B T128, synthetic weights, one process, best of 3]: one request goes from 10.57 tokens/s (serial) to 20.85 at
  six forks (1.97×), and verification takes about 2.5 s against 4.8 s.
- **Correctness:** the four malicious controls are rejected, and existing proof bytes and goldens are unchanged.
- **Before any receipt uses it:** an independent review and a privacy re-check (`results/zk60_d55_20261101/SOUNDNESS_NOTE.md`).
- **Housekeeping found by the D55 agent:** four source-scan tests (r19b, the s24 pin list, the s25 module graph, the absorb-label scan) fail on files added by
  the Metal and W16 work. Those files need adding to the scans' lists.
- **Also today:** the W16 privacy gate passes on the Metal path and in a Python v25 subset (no leak found).
- **Still the gap to 50:** the RTX 5090 CUDA port.

**2026-11-01 (evening): the Shieldstral classifier privacy statement is accepted (D58).** Victor accepted v3 with the checker's two text fixes. It is in force for the named CPU binaries at the moderate policy list; conditions C-7 and C-8 still stand before non-public posts, and GPU proving is not yet covered. W16's F3 malicious controls are closed. A funding push is under way (D57; the application material is kept outside the public repository since 2026-11-04).

**2026-11-01 (Mac, latest): one request now proves at about 11 proved tokens/s (13 at 256 tokens per block), and about
22 with six requests at once.**
- **Measured** on the committed code [MEASURED, W16 8B blocks, every proof byte-identical to a solo proof, synthetic
  diagonal weights]:
  - T128: 0.356 s per block, **11.1 tokens/s** for a 32-layer stack; 22.3 tokens/s aggregate with six requests at
    once;
  - T256: 0.597 s per block, **13.2 tokens/s**; 20.8 tokens/s aggregate.
- **The rest of the gap to 50** (Attestable: 53 on one H100):
  - the Mac's GPU caps the aggregate near 22 tokens/s;
  - one request's own blocks cannot overlap without Victor's ruling D55;
  - the biggest remaining step is the RTX 5090 with all of this work ported to CUDA.
- **New research result (M18, D56 open question):** a 31-bit field (Mersenne-31 or BabyBear) multiplies 3.5–3.9x
  faster than today's on this GPU, and its secure extension 1.8x faster [MEASURED]. A cost study the same day found
  that the bit-exact arithmetic needs Goldilocks' 64-bit headroom: 15 relations exceed a 31-bit field (up to 2^49.8),
  and carrying them as digits makes a block slower overall (about 0.24–0.34 s of GPU work against 0.165 s) [MODEL].
  Recommendation: **not now** (`results/zk60_metal_20261031/D56_FIELD_SWITCH_STUDY.md`).
- **W16 independent soundness review done (2026-11-01):**
  - **Verdict:** sound as built, about 0.9 bit better than R13 per block (LogUp 2^-102.92).
  - **Fixed:** the Medium finding F1 (two receipt guards missed the W16 profile names) and Lows F2 and F4. All
    gates pass.
  - **Still owed before any W16 receipt:**
    - ~~the malicious-prover controls F3~~: **done 2026-11-01** (four test-only controls, each refused by the verifier; every gate green, golden 8/8; `results/zk60_metal_20261031/logs/m22f3/`);
    - the privacy gate run on W16: **the Rust gate is done (2026-11-01).** The plane index and recorder now cover W16's
      range histograms and helpers, and they PASS at the rung and both T128 shapes with no leak found
      (`results/zk60_metal_20261031/logs/m23pg/`). Still owed: the Python gate (v24) for W16, a W16 statement text, a
      GPU-path capture and an independent privacy review;
    - registration;
    - the DD variants.
  - Report: `results/zk60_limb16_20261031/REVIEW_W16_20261101.md`.
- **D55 design draft:** `docs/zkmatrix-poc/ZK60_D55_CONCURRENT_RUN_DESIGN.md` (one request's blocks proved at once).
- **Tried this round and reverted (no gain, diffs kept):** Gruen's trick on the GPU zero-checks, and a host pool for
  the commitment matrices. Details: `results/zk60_metal_20261031/README.md` M6–M16.

**2026-11-01 (early morning, Mac): each step's GPU rounds now go to the GPU as one batch (about 7% faster), and
measured context scaling shows that longer contexts buy little.**
- **M6 (byte-identical, kept).**
  - **Before:** every sumcheck round was its own GPU submission, costing about 0.21 ms of fixed overhead.
  - **Now:** all of a step's GPU rounds go in one submission. The Fiat-Shamir hashing and masking run on the GPU, and
    the CPU then replays every round to check each challenge, so a GPU fault cannot change a proof byte.
  - **Speed** [MEASURED, A/B on one binary, warm n=3, shared Mac, prove core]:
    - W16 8B 0.468–0.476 → **0.435–0.441 s**;
    - W16 Shieldstral 0.476–0.519 → 0.446–0.484 s;
    - on a quieter pass the W16 8B core was 0.400–0.403 s, about **10 proved tokens/s** for a 32-layer 8B stack
      (block proofs only).
  - **Gates:** all pass (dev-shape bytes, trained digests, R13 run, golden 8/8).
- **M7 (measurement).** W16 8B blocks at longer contexts [MEASURED, warm n=2]:
  - **T256:** 0.78 s, **10.3 tokens/s**, the best of the three;
  - **T512:** 1.7–2.0 s, 7.8–9.4 tokens/s.

  Cost grows almost linearly with context, so a longer workload is not the route to 50. The remaining factor of
  about 5 must come from per-token work. The largest piece is now the CPU side of the 23 zero-check steps (about
  0.125 s of 0.40 s: building their tables), then the two commitments (about 0.15 s).
- **M8 (byte-identical, kept).**
  - **Small slots on the GPU.** A small zero-check step with an expensive polynomial now runs on the GPU: 8 → 2 ms.
  - **Faster weight fold.** The feed-forward weight fold adds exact integers and reduces once per row: 10 → 3.5 ms
    per 8B matrix, on dense weights.
- **M9 (byte-identical, kept):** two CPU steps on the critical path fixed (the Merkle tree builder was split into
  per-pair tasks, and one table builder ran on a single thread). W16 8B block 0.408–0.422 → **0.373–0.375 s**
  [MEASURED, A/B on one binary, warm n=3, oracle off], about **10.7 proved tokens/s** for a 32-layer 8B stack
  (about 10.3 with real dense weights).
- **M10 (measured): independent proofs at once.**
  - **Result:** 6 block proofs at once give **5.5 blocks/s, about 22 proved tokens/s aggregate** for a 32-layer 8B
    stack, against 10.6 for one at a time [MEASURED, one process, all proofs byte-identical to the solo one].
  - **What it means:** this is throughput over separate requests or stacks; one request's own blocks share a
    transcript and still run one after another (changing that would need Victor's ruling).
  - **Bottleneck:** it saturates at the GPU's own work per block (about 0.165 s), so faster GPU kernels are now what
    raises throughput.
- **M11 (byte-identical, kept):** the opening's row fold reduces once per entry: −5 ms per block. A faster field
  multiply on the GPU was tried; there is no gain (the compiler already does it well). The big GPU kernels are near
  the multiply ceiling, so what is left on the GPU is algebra: fewer evaluation points (Gruen's trick) and a leaner
  NTT.
- **M12 (kept, small):** the GPU transform reads its twiddles from a compact table, −1 ms per commitment.
- **M13 (tried, reverted):** Gruen's trick on the GPU zero-checks was byte-identical but not faster (the GPU cost per
  point is memory and latency as much as arithmetic); the diff is kept.
- **M14 (measured):** at 256 tokens per block, one request now proves at **13.0 tokens/s** for a 32-layer 8B
  stack (0.60 s per block). Six requests at once give 21 tokens/s aggregate.
- **M15 (byte-identical, kept):** two CPU steps of the activation lookup are fused or made parallel; W16 8B T128
  block **0.358 s** (about 11.2 tokens/s), from 0.380.
- **Open question for Victor (D55):** letting one request's blocks prove at the same time would need a new
  construction, because rule D12a makes a run one transcript.
- **Caveat on all block timings above.** The timing test's synthetic weights are diagonal, so weight folds are
  nearly free in it. A real 8B layer adds about 15 ms per block (about 35 ms before M8) [ESTIMATE]. So the real-weight
  8B figure is about 9–9.5 tokens/s at T128 and about 10 at T256, not 10 and 10.3.
- Record: `results/zk60_metal_20261031/README.md` (M6, M7, M8).

**2026-11-01 (night, Mac): two more byte-identical speedups to the W16 format; an 8B-shaped block now proves in about 0.43 s on the GPU.**
- **M5b** builds the activation lookup's queries in parallel.
- **M5c** builds each large eq table from two small half-tables, one multiplication per entry, instead of a full
  table plus a copy.
- **M5a** (gathering plane tables on the GPU) was byte-identical but gave no gain in a side-by-side comparison on
  one binary, so it was reverted and its diff kept.
- **Gates:** every existing format's bytes are unchanged at each step (golden 8/8, trained digests, R13 run).
- **Speed** [MEASURED, Metal prove core, T128, warm passes n=3, shared Mac]:
  - W16 Shieldstral 0.452-0.469 s;
  - W16 8B 0.432-0.435 s, about 9.2 proved tokens per second for a 32-layer 8B stack (proof call only), still
    about 5.4 times short of 50.
- **Researcher (D50).** A Claude researcher ran on the Mac, because the Codex explorer needs bubblewrap. It
  measured LogUp-GKR against W16's helpers: marginal, about x1.00-1.25 (estimate), so not recommended
  (`research/zkp-efficiency/handoffs/20261101-logup-gkr-w16.md`). Its top idea is overlapping the about 0.2 s of
  host-CPU work with GPU work.
- **Timing noise.** Spotlight re-indexing new build output slowed one run's CPU path about 2x. Excluding the repo
  from Spotlight would help.

**2026-10-31 (late evening, Mac): 16-bit range lookups (W16, D54) built and measured: a block now takes about 0.47 s on the GPU.**
- **What changed.** Victor approved wider range-check limbs (D54).
  - A new, opt-in proof format replaces most byte limbs with 16-bit range lookups.
  - Its profiles: `W16_SHIELD_T128_H24`, `W16_8B_T128_H24`, and a development rung.
  - Each block commits about half the words: `A` is 0.55 of R13, `H` 0.59, lookups 0.50.
  - The existing proof formats are unchanged byte for byte (the development-shape digests, the trained R13
    digests, the R13 run and golden 8/8 all pass).
  - Design and evidence: `results/zk60_limb16_20261031/DESIGN.md`.
- **Speed** [MEASURED, Metal prove core, T128, warm passes n=3, shared Mac; synthetic weights at the true geometry;
  the proof call alone]:

  | Block | R13 (today's format) | W16 |
  |---|---:|---:|
  | Shieldstral | 0.654–0.667 s | **0.469–0.507 s** (×1.39) |
  | Llama-3-8B | 0.605–0.631 s | **0.467–0.482 s** (×1.30) |

  For a 32-layer 8B stack that is about 15 s per 128 tokens, about **8.4 proved tokens per second** (was about 6.5),
  still about 6 times short of 50. For the 26-layer classifier it is about 10 tokens per second.
- **Before any receipt uses it:**
  - a run profile and receipt registration;
  - the DD variants;
  - an independent soundness review;
  - the privacy statements re-checked for the new plane list.

  Tests already show the W16 core proves and verifies, and that out-of-range limbs from a cheating prover are
  rejected.
- **Next levers:**
  - LogUp-GKR, which drops the committed helper column (needs Victor's ruling);
  - non-power-of-two domains: Shieldstral's feed-forward axis is 44% padding;
  - the RTX 5090.
- **Lanes.** Sol and Astra are paused for their weekly limits (handoffs in their result directories). Their detached
  runs continue: Astra's A2 replay, analysis, score-fix candidate and calibration replay.

**2026-10-31 (evening, Mac): the real classifier's zero-checks now run on the Mac's GPU too, byte for byte the same.**
- **What changed.** The classifier (Shieldstral) uses the R13 accuracy stack. Its five heavy zero-checks had
  stayed on the CPU, because the GPU's expression description covered only the older stack. They now run on the
  GPU. The proof bytes are identical to the CPU's at every shape tested: four small development shapes, and the
  Shieldstral and 8B geometries at 128 tokens. The older proofs are unchanged (golden gate 8 of 8).
  Record: `results/zk60_metal_20261031/README.md` (M4 to M4l).
- **Speed of one Shieldstral-shaped accuracy block at 128 tokens** [MEASURED, GPU rows n=9 warm passes in three
  processes (median), Mac quiet at the time; synthetic weights at the true geometry; the proof call alone, so no
  witness, model loading or receipt assembly]:

  | Path | Block proof |
  |---|---:|
  | Mac CPU, 32 threads (n=4, not a quiesced ladder) | 2.9-4.5 s |
  | Mac GPU, later blocks (a new GPU kernel's first compile on a machine can add a few seconds, once) | **0.65-0.68 s (median 0.656)** |

  Fixes that change no bytes took the GPU block from 2.86 s to about 0.66 s (the older figures in the record
  also counted the test's own digest text, about 0.16 s): on the CPU side (used by both paths) the extension
  rounds, the LogUp helper columns, the commitment masks' randomness, the exp/activation helper inverses and the
  witness planes now run in parallel; on the GPU, the zero-check kernels run one thread per evaluation point,
  one point per group of 32 lanes, skipping the point the protocol recovers from the claim; the zero-check
  tables are built straight into GPU memory instead of being built, zeroed and copied, and in parallel over
  their entries; the last, tiny sumcheck rounds of each slot run on the CPU (a GPU round costs about 0.4 ms
  whatever its size); small helper tables no longer pay a thread-pool start-up each; GPU buffers are reused
  from block to block (about 2.4 GB more peak memory).
  For the 26 layers at 128 tokens that is about 17 s of proof core, or about **7.5 proved tokens per second**.
  The target is at least 50, so we are still about **6.7 times short**.
- **Longer blocks do not close the gap here** [MEASURED, n=3]: the same block at 256 tokens takes 1.59 s, 2.1
  times the 128-token block (measured before the last three fixes), so proof time is about linear in tokens on
  this design. Closing the gap needs the structural levers or a faster GPU, not more tuning of phases.
- **A lever that needs Victor's ruling:** most of what each block commits is range-check byte limbs and their
  lookup helpers (the lookups read 64.3 M of the 75.0 M words of `A`; their helpers are 64.3 M of the 71.9 M of
  `H`). Wider limbs (16-bit) would shrink both commitments and openings roughly in proportion, a rough
  estimate of 0.1-0.2 s per block. It changes the proof layout, verifier and receipts, so it is not done.
- **Still on the CPU:** the witness, the LogUp helper inverses (in parallel), the extension rounds, the openings,
  and one small table slot per block. The DD softmax and dictionary slots also stay on the CPU.
- **Sol and Astra** (Codex sessions on this Mac) have written nothing since about 08:45 UTC. Their processes are
  alive but idle and need a "continue" from Victor. Astra's 12-hour replay was prepared but has not been launched.

**2026-10-31 (afternoon, Mac): the prover runs on the Mac's GPU, byte for byte the same; R14's security tier is accepted.**
- **Apple GPU (Metal), new.** The commitments and the five heavy zero-check sumchecks now run on the M3 Ultra's
  GPU. Four full block proofs made this way (TinyLlama and Llama-3-8B shapes at 128 tokens, with and without
  DD) are byte-identical to the proofs recorded on the Linux laptop. Record: `results/zk60_metal_20261031/README.md`.
- **Speed of one 8B-shaped block at 128 tokens** [MEASURED, n=1, shared Mac; synthetic weights at the true
  geometry]:

  | Machine and path | Block proof |
  |---|---:|
  | Laptop CPU, 16 threads (historical) | ~12.3 s |
  | Mac CPU, 32 threads | 4.66 s |
  | Mac GPU (commitments + zero-checks) | 2.20 s |

  That is about 1.8 proved positions per second for a 32-block 8B stack on the Mac, before witness and model
  loading. Attestable claims 53 tokens/s on one H100 for a 31B model; we are still far from that.
- **Not yet on the GPU:** the real classifier's accuracy-stack zero-checks (their expression IR is not written),
  the witness, the LogUp helper inverses and the extension rounds. The DD profiles keep one slot on the CPU.
- **R14 security tier (D27): accepted on soundness** by an independent review, three low fixes
  (`results/zk60_d24_review_20261017/REVIEW_R14_TIER.md`). Registration still needs one CLI run on the restored
  export and the privacy gate.
- **Astra restored the Shieldstral native export** on the Mac (8.47 GB, every file hash-matched) and is
  re-running the benchmark replay (about 12 h, CPU).

**2026-10-31 07:45 UTC: work moved to the M3 Ultra Mac Studio; the laptop is no longer reachable.**
- **The code is all here.** The last push (Snapshot 15) is pulled. The production prover builds on the Mac and
  passes its tests apart from three macOS bugs and some missing test files. Proofs made on the laptop verify on
  the Mac. Record: `ZK60_MAC_BRINGUP_20261031.md`.
- **What stayed on the laptop:** about 446 GiB of large files (model exports, captures, receipts) and everything
  kept outside the repo. That includes the private store of the durable demo post, so **its openings are not
  available from here**. Its anchor on Base Sepolia is unaffected. The app also kept the public segments
  outside the repo (`~/zk60-artifacts/proven-media`), so those are on the laptop too.
- **No GPU proving on the Mac yet.** The GPU code is NVIDIA-only; an Apple GPU (Metal) port is planned but not
  started (`ZK60_METAL_PORT_PLAN.md`). The safety guard for heavy jobs now runs on macOS.
- **Every number below was measured on the laptop.** None has been re-measured on the Mac.

**2026-10-30 21:55 UTC: a second real post, now with durable openings; the R14 prover passes its soundness review.**
- **Durable demo post** (Astra): 19 tokens, all three categories accepted as not flagged, 84 public segments
  (2.55 GB). Anchored on Base Sepolia, transaction `0x6e6d5166…8181`, block 52,373,745.
  - Its openings are kept in durable private storage, so the link between the proof and the post's text can be
    checked from an opening (D45). The first post's openings were lost in the crash.
  - Proving per category: 444–452 s on 8 threads, peak 8.2 GiB [MEASURED, n=1, shared laptop].
- **Native prover R14 is accepted on soundness** (independent review): about 97.3 bits.
  - It proves all 26 real Shieldstral layers in about 440 s at 5.6 GiB peak (the current app binary needs
    8.2 GiB).
  - It is not yet registered: that waits on a security tier in the statement, one T256 proof and the privacy gate.
- **Nothing is published until proving and verification run on the GPU** (D53). The GPU lane is profiling.
  - The laptop GPU now runs at full clocks after Victor's power-mode change (about 2.0 GHz, memory 8,000 MHz).
  - Every GPU figure measured before today was taken with the GPU capped.

**2026-10-30 11:35 UTC: work interrupted by the crash is caught up.**
- **The one-load batch (token round 18)** is frozen and passed its independent review, with one fix required on
  the app side (R18-1). One process now proves all the categories of a post after loading the model once. Each
  category's proof comes out byte for byte the same as a separate run [MEASURED: the public 17-token post, three
  categories]. It saves little time (2.4 %); the gain is a single model load. The app stays on the per-category
  path until Astra's fix for crashed batches is in and reviewed.
- **The classifier privacy statement, draft v3,** is complete. Both checks the review asked for passed on the
  real model:
  - C-9 on a real block: TS-1 fires on every role, with no identical claims and no equal published values.
  - NL-1 on all 26 blocks: 182 of 182.
  A short check that v3 contains the review's text fixes is running. After that, Victor decides whether to
  accept the statement. It is not accepted yet.
- **Token round 19** is running: the review's three small fixes, plus a setting for the model's location, so
  that anyone can verify a receipt (needed for the open-source release, D48).
- **Sol (R14)** is close to a freeze; its independent soundness review follows.

**2026-10-30 05:30 UTC: the laptop crashed at about 02:50 UTC and work has resumed; safeguards added (D46).**
- **Why it crashed:** the Windows drive C: was full (about 5 GB free). It holds the
  Linux disk file and Windows' page file, so neither could grow while a
  full-size test proof was writing. Linux itself still had 5 GiB of memory free.
- **Fixed:** about 135 GB of unused Windows AI tools removed, with Victor's yes, so
  C: now has about 135 GB free. The resource guard now holds heavy jobs while C: has
  under 40 GiB free, and stops any job under 8 GiB. The box watch now reports
  low C: space and low Windows memory. When Windows runs short of memory it
  releases Linux's cached copies of large files; the first run released 5.5 GiB
  and the Linux VM's share of Windows memory fell from 14.9 to 10.5 GiB. Still
  for Victor: the 5-minute cron entry for the watch, which the session's safety
  check blocked, and the Linux disk compaction (about 45 GB) at a quiet moment.
- **Lost in the crash:** token round 18's full-size byte-identity test, which is
  being rerun; the gate's C-9 and NL-1 checks, also rerunning. The first post's
  proofs and public segments survived and still verify, but the app had kept
  its database, key and openings in /tmp, so the openings that link the proofs
  to the post's text are gone. Astra moved the app's state to durable storage
  (05:23 UTC).
- **The first real post is now published and anchored on testnet** (05:23 UTC,
  Astra): Base Sepolia transaction `0x0f2dc9dd…ad01a`, block 52,075,726. All three
  publication checks pass. All 84 public segments (2.55 GB) were re-hashed, and the
  three receipts verified again from the public store, in 79–82 s each
  [MEASURED, n=1, the box shared]. The proofs were not redone. Still open: the
  classifier privacy acceptance (draft v3, after gate round 23), the benchmark
  verdict metrics and the one-load batch adoption (token round 18).
- **Unchanged:** the results below, including the first real post's three
  accepted proofs.

**2026-10-30 01:54 UTC: the first real post went through the app, and all three classifier
proofs passed.**
- **The post:** a public 17-token garden text (Astra's demo), proved on the
  real Shieldstral-1.0-3B classifier with the pinned r16b binary (dfb8025e).
- **Verdicts:** sexual, violence and hate all *not flagged*. Each receipt was
  verified in a fresh process, and its input-owner and label checks passed
  [MEASURED].
- **Numbers** [MEASURED, n=1, this laptop, alone]:
  - proving time per category: 456 s with 8 threads (violence, hate); 1,031 s
    for the first (sexual), which used 2 threads;
  - total work per category with the checks: 688 s (8 threads);
  - receipt 848 MB; peak memory 8.0 to 8.2 GiB; 96-bit floor.
- **Not yet:** the publication and testnet anchor (Astra's next step); the
  privacy statement (draft under review; gate round 22 is closing the
  review's two blocking checks); private posts through the app (blocked until
  the app shows failures only to the authenticated author; Astra's fix is
  staged).

**2026-10-29 22:50 UTC: the classifier privacy statement exists as a draft and
is under independent review.**
- **The draft** (then `…_DRAFT.md`, now kept as `ZK60_PRIVACY_STATEMENT_CLASSIFIER_SHIELDSTRAL_T128_DRAFT_v1.md`; current: `_DRAFT_v3.md`)
  says what is public (the verdict bit, the post's length, the policy), what
  stays hidden (the post's tokens and every intermediate value), and how a
  refusal ("could not be verified") is reported.
- **The tables check:** the gate re-derived all 442 public tables of the real
  model itself (118 million entries), and every one matched the proof's
  [MEASURED].
- **Per-run distance:** about 2^-68 [COUNTED]. This bounds how far a real
  proof's view can be from one that reveals nothing. The TinyLlama statement
  had about 2^-70.
- **Next:**
  1. The independent privacy review (running).
  2. Gate round 22: three remaining checks (a draw replay by value, a
     surjection check, a hash-input census).
  3. Victor's acceptance and his strict / moderate wording.
- **The one-load batch** (all three categories after loading the model once)
  passed its code review with two fixes. Token round 18 is now adopting it,
  with a byte-for-byte equality test.
- **Correction to the 21:37 note:** Astra's first real post has not started
  yet. The Sol and Astra sessions are idle and wait for Victor's "continue".

**2026-10-29 21:37 UTC — the real classifier proof passed the full privacy
gate with no limits; the privacy statement draft has started.**
- **Gate round 20** closed both of round 19's limits on a real Shieldstral
  proof:
  - all 23 checks per block on all 26 real blocks;
  - the complete input-reconstruction check: **81.7 million entries compared,
    0 differing**;
  - nothing disclosed on hidden data, and every tamper check fires.

  4.06 h on this laptop, alone, with one read of the model.
- **Next:**
  1. The classifier privacy statement **draft** (running): what is public,
     what stays hidden, the per-run distance figure, and the refusal channel
     stated plainly. An independent derivation of the 15 tables the gate
     takes from the capture runs alongside it.
  2. An independent privacy review.
  3. Victor's acceptance, and his strict / moderate wording ruling.
- **The first real post through the app** (Astra) runs now that the box is
  free.

**2026-10-29 15:13 UTC — the privacy gate passed the real Shieldstral
classifier proof (with two stated limits); work continues to close them.**
- **The gate checks** that a proof reveals nothing about the hidden post
  beyond the public verdict and length. On the real classifier proof:
  - nothing is disclosed on any of the 84 hidden-data commitments;
  - all 15 tamper checks fire;
  - the yes / no / tie verdicts look identical apart from the verdict bit.

  13 small-model captures also pass.
- **Two limits to close** before a privacy statement:
  1. 12 of 23 per-block checks need the capture to record its public tables
     (token round 17, running);
  2. the full input reconstruction was checked on a sample of commitments.
     The complete check is a 3-hour job (gate round 20).
- **One thing the statement must say plainly:** whether an honest post gets
  *refused* (shown as "could not be verified") can depend on its hidden
  content. That is a small side channel, inherent to fail-closed.
- **Also today:** the proof anchor contract is live on the Base Sepolia
  testnet.
- **Speed (Sol's split-width round, S4 / R14), 16:53 UTC:** on a matched
  2-block, 128-token comparison (same inputs and model identity), proving
  dropped **49.2 s → 35.1 s (−28.8%)** and peak memory **7.49 → 5.56 GiB
  (−25.8%)**, with receipts about 6% larger [MEASURED, n=1, shared box].
  This is not yet frozen or reviewed. Next: freeze, soundness review, then a
  privacy-gate round.

**2026-10-29 12:09 UTC — the proof anchor contract is live on a public
testnet; both Codex lanes need a restart.**
- **Base Sepolia (testnet) anchor contract deployed** by Astra. Contract
  `0x8432eba82b1a402f4da7680f6b8f9c9fae185cbe`, deployment transaction
  `0xfaa03b5a…` (status success; code confirmed on-chain by the coordinator,
  read-only). It was funded from the ETH Victor mined, bridged from Sepolia.
  No proof batch has been anchored yet; that comes once the app makes real
  proofs.
- **Sol stopped at 11:12 UTC on an OpenAI content filter** ("flagged for
  possible cybersecurity risk", `cyber_policy`). The ZK work's routine
  attack / forgery testing probably triggered it. **Astra's turn ended at
  06:44 UTC.** Both need a "continue" from Victor.
- Claude lanes: token round 16b frozen (the real classifier, exactly three
  policies); privacy gate round 19 on the real classifier is running.

**2026-10-29 08:47 UTC — the first real proof of a safety-classifier verdict
on a real post.** Mistral's Shieldstral-1.0-3B judged a 35-token ToxicChat
post under the moderate "sexual" policy. The proof shows the public verdict,
"not flagged", while the post's text stays hidden [MEASURED, n=1, this laptop,
nothing else running]:
- **prove:** 328 s (439 s including model load); receipt 848 MB in 28
  segments; soundness floor 96 bits; peak memory 8.15 GiB;
- **verify** in a fresh process: 36 s (68 s including model load), 2.3 GiB;
- the **owner check** (the proof matches the actual post) and the **label**
  step (whole post covered) both pass.

Category 1 of 3 has been through the app's whole flow. Violence and hate are
proving now. Not yet a privacy acceptance: the privacy gate on the real
classifier and the policy wording (strict vs moderate, Victor) come next.
**Update 09:31 UTC: all three categories passed the whole flow** (each
proof about 7.5 minutes, 848 MB). The round is frozen: 934 tests passed,
96.9 bits per whole run. Next:
- an independent review (running);
- the privacy gate on the real classifier;
- Astra making the app produce each post's activations from its own integer
  model.

Then the app switches from the stand-in to real proofs.

**2026-10-29 07:21 UTC — the accuracy round (R13) passed its soundness
review; the real Shieldstral classifier is being registered now.**
- **R13 accepted** at all twelve registered profiles. The reviewer's own
  integer model matches the prover exactly, including the real Shieldstral
  layers. Shieldstral proofs carry **97.3 bits at 128 tokens** and **96.1–96.3
  at 256**, over the ~95 floor.
- **Next (token round 16, running):** register the Shieldstral classifier on
  R13, then prove and verify real posts for all three categories on this
  laptop, with timings. After that comes the privacy gate on the real
  classifier, and then the app switches off its stand-in prover.
- **One open question for Victor (not urgent, not blocking the MVP):** the
  8B model at 512 tokens counts 94.5 bits (94.8 with DD), just under the ~95
  target. Sol is costing the cheapest way to reach 95.
- Astra: the full benchmark on the integer model continues (zero refusals so
  far). Sol: the split-width design (about 24% less proof data) is under an
  independent design check; then the verifier-commitment paper.

**2026-10-28 21:05 UTC — back after a two-day stop; the classifier proof
passes the privacy gate on all seven test captures; funding is now the top
priority (D43).**
- **The stop:** the coordinator session stopped answering on 10-26 at about
  20:26 UTC, and the laptop then shut down cleanly at 20:33 (a normal power-off,
  not a freeze). Nothing ran until today's boot at 20:56. Every job queued on
  10-26 had already finished; nothing was lost. Sol and Astra resumed at 20:59.
- **Privacy gate, round 17:** all 7 test proofs of the classifier verdict stage
  (1- and 2-block models; verdict yes, no and a tie; one item split into 2
  chunks) pass: no commitment reveals more than expected, all 11 tamper checks
  fire, and the yes / no / tie runs look identical apart from the public verdict
  bit [MEASURED, n=1, shared box]. These are small test models, and this is not
  a privacy acceptance.
- **Classifier verdict stage on the new prover (token lane):** rebased onto
  native R12 and the full suite is green (819 passed, 0 failed). **Update
  23:11 UTC:** Sol froze R12b at 22:33. It is the fix that makes the prover
  recompute the classifier's tables from the model's pinned weights instead
  of trusting the files. The independent review accepted it on soundness with
  no fixes: 27 forgery attempts were refused, and an independent
  recomputation matches bit for bit. The token lane is now rebasing onto R12b
  and building R-C2, in which the classifier's verifier derives its scoring
  row itself. Not a privacy acceptance. **Update 23:45 UTC:** token round 13
  (R-C2) is frozen on R12b. The classifier verifier now rebuilds its scoring
  row, embedding, start token and final normalization from the model's
  pinned weights and the bound profile. Doctored tables are refused even when
  their fingerprints were updated to match: 4 tests failed first against the
  old stage and pass now. Full suite 832 passed, 0 failed [MEASURED]. On
  Astra's real Shieldstral export, the rebuilt tables match the native
  reference exactly. An independent review is running, and the privacy gate
  re-captures afterwards. **Update 00:56 UTC: R-C2 is accepted on soundness**
  with no required fixes: 51 forgery attempts were refused, and the old stage's
  flipped-verdict gap is shown closed. Next, token round 14 (running):
  - bind the tables inside the library functions too, not only the
    command-line tool;
  - fix the gate's capture tool;
  - support posts shorter than one chunk (today they are refused: 32–77% of
    short posts at the laptop setting).

  Then the privacy gate re-captures. **Update 02:14 UTC: round 14 is done**
  (frozen, under independent review):
  - the tie to the real weights is now enforced in the library too;
  - short posts are proved as one chunk with public padding, so by length
    every one of the 4,872 benchmark items is now admissible at both laptop
    settings (it was 0–67%);
  - full suite 845 passed, 0 failed.

  The privacy gate (round 18) is re-capturing the new classifier stage now.
  **Update 04:14 UTC: round 14 accepted on soundness; gate round 18 passed
  all 21 captures** on the new classifier stage:
  - covered: both test models, all three verdicts, a 2-chunk post, short
    posts of 1–22 tokens, and two runs through the command-line tool;
  - the verdict changes nothing but its public bit;
  - a short post discloses nothing beyond its public length;
  - every tamper check fires.

  Still owed before a classifier privacy statement: the Shieldstral profile
  (waits on Sol's R13), the statement text, an independent privacy review and
  the sign-offs. Sol and Astra (Codex) are idle since 03:09 and 01:29 UTC and
  need a "continue" from Victor.
- **Now running:** Sol on R12b, Astra on the Shieldstral benchmark report and
  the integer export (the one open range question: two layer-25 channels).
  **Update 23:39 UTC:** layer 25 is fixed, with one extra Shieldstral-only
  SiLU table and a re-quantized up-projection. The integer Shieldstral now
  runs all 192 calibration inputs through all 26 layers with **zero
  refusals** [MEASURED, n=1]. Still to come: whether the integer model gives
  the same verdicts as the float model on the 4,872 benchmark items.
  Separately, Astra's float benchmark report is done (strict vs. moderate
  policy wording: nearly tied; the choice is Victor's).
- **New direction (D43):** finding funding as fast as possible comes first. A
  paper with the demo follows once the PoC works. Three research agents are
  surveying government grants, philanthropic and ZK-ecosystem grants, and
  investors / accelerators / venues. The ranked plan goes to Victor next.

**2026-10-26 18:05 UTC — the work is split with GPT Sol and Astra; the
prover's Shieldstral features pass their golden and dense proofs; the
accuracy stack is chosen.**
- **Team:** after the weekly usage stop (10-21 06:30 → 10-26), Sol (prover)
  and Astra (models, app) took over lanes; split and live logs in
  `docs/zkmatrix-poc/ZK60_SOL_ASTRA_TODOS_20261026.md`.
- **Prover features for Shieldstral (native R12, Sol):** build, 207 focused
  tests, golden proof (41.6 s, 6.18 GiB) and dense proof (153.5 s, 6.59 GiB)
  all pass [MEASURED, n=1, shared box]. **Update 20:10 UTC:** frozen and
  independently reviewed — accepted with fixes on soundness (about 97.6 bits
  at T128, 95.0–95.4 at T512; existing proofs unchanged). One medium fix
  matters for the classifier: the prover must check that the output head is
  really the model's tied embedding, not just trust the export's declaration
  (fix in R12b, Sol). Not a privacy acceptance.
- **Resource guard fix installed (D42, 19:00 UTC):** jobs no longer block the
  shared lock while waiting for memory.
- **Accuracy (fidelity lane, final):** 8B uses **LOW + 24-bit h**: perplexity
  1.011x / 1.009x of float, LAMBADA 0.80 vs float 0.78, and the 2 refusals
  are fixed at no proof cost. It costs **+22.8% committed proof at 8B T128**
  (+24.9% against today's DD prover at T512). TinyLlama needs only LOW. One
  confirmation re-run with the two fixes is still owed. Report:
  `results/zk60_fidelity_parity_20261019/REPORT.md`; build spec for the next
  prover round R13: `S2_BUILD_SPEC.json` beside it.
- **Classifier verdict stage (token R-C1, Claude):** registry tests green;
  the freeze waits for one full suite run.
- **App (Astra):** canonical integer image preprocessing in (42/42 app
  tests); Base Sepolia (testnet) publisher wired up, nothing broadcast yet;
  Shieldstral strict-policy benchmarks continuing.

**2026-10-21 05:00 UTC — the media app runs end to end (on a stand-in prover).**
- `apps/proven-media/` (FastAPI + SQLite + plain JS; README has a 3-minute demo
  script; served locally at http://127.0.0.1:8765 on the laptop): compose
  text or image posts; each post is chunked (D41), labelled per category
  (explicit / violence / hate, D37), proved once at creation, verified in a
  fresh process, published to a content-addressed store, anchored in a
  hash-chained local "chain" (stand-in for Base), and served with an
  app-signed proof manifest; viewers set an audience (adult / minor) and
  restricted items are hidden with the reason; a "re-verify" button and an
  offline verify command check everything. Fail-closed per category.
- **Honest label:** today each post gets a real zero-knowledge proof of the
  TinyLlama next-token run as a stand-in; the labels come from a placeholder
  and are not yet bound by the proof. The real Shieldstral classifier proof
  (native R12 + token R-C1, in progress) swaps in through one interface.
- First stand-in post: prove 104 s, verify 19 s, 255 MB bundle; 36/36 app
  tests [MEASURED, shared box].

**2026-10-21 02:40 UTC — the full MVP is now a proven-safe media app (D37, D38).**
- **Direction (Victor):** the first application is safety classification: a
  media app whose posts carry public proofs that they passed a
  harmful-content classifier. **Model (D38):** Mistral's open classifier
  Shieldstral-1.0-3B (Apache 2.0), text only; the proof states that its
  yes-score beat its no-score by a public threshold; only the verdict, model
  and policy are public, the content stays hidden. Survey:
  `results/zk60_classifier_survey_20261021/REPORT.md`.
- **Lanes started:** model import + float reference + benchmark F1
  (calibration prep); prover features for Shieldstral's shapes (decoupled
  head size, YaRN rotary table, tied embedding; native R12); the classifier
  verdict stage with a public verdict bit (token round 12, design first);
  the media app with proof badges (`apps/proven-media/`, stub prover first).
- **Privacy:** D33 and D36 extended to frozen-r11 — both now cover the
  demo's exact binaries. DD passed the privacy gate on its first 8
  captures (gate evidence).
- **Fidelity:** 8B meets the amended bar (≤1.02x, zero refusals) with the
  LOW + 12-bit-score stack (1.011x / 1.010x); TinyLlama with LOW (1.009x /
  1.010x); cheapest DD-compatible 8B stack being measured; the chosen stack
  becomes the native build spec.

**2026-10-21 00:20 UTC — privacy accepted for a whole AI answer (D36); D33
extended to the current code.** Victor accepted both in the console:
- **D36, the next-token privacy statement:** a verifier who checks a proof
  of TinyLlama's next word (prompt lookup → all 22 trained layers → final
  norm → head → word choice, one proof) is never given the prompt, the
  activations, the scores or the word itself, and learns essentially nothing
  about them (~1 in 2^70 per run). Scope: TinyLlama, 32 tokens, calibration
  b4, public prompt length, CPU, round-9 code and its named binary
  `b56f1b71…`. Text: `docs/zkmatrix-poc/ZK60_PRIVACY_STATEMENT_NEXT_TOKEN_TINYLLAMA_T32.md`.
- **D33 extended** to the round-9 code (same claim and limits).
- **Next:** a short re-pin reading so both name the demo's current round-11
  binary; the 8B and the accuracy-fix profiles need their own gate and
  statement later.
- **Fidelity:** the 8B now meets the perplexity bar with the HIGH stack
  (1.0045x / 1.0034x, 1 refusal from a calibration bound) at about +29% proof
  size; a cheaper stack (~+23%) is being measured; TinyLlama passes
  perplexity and LAMBADA (refusal fixes queued, no proof cost).

**2026-10-20 07:40 UTC — first configuration inside the fidelity bar (TinyLlama,
perplexity); the price of parity is now counted.**
- **Fidelity (D32 bar: perplexity <= 1.01x float, LAMBADA >= 99%, 0 refusals):**
  TinyLlama with the "LOW" stack — per-channel weight multipliers, per-group
  SiLU tables, 16-bit norm outputs, 12-bit softmax precision, 16-bit
  attention words — measures **1.006x / 1.008x** (FineWeb / WikiText) with 1
  refusal (a calibration bound, fix queued, no proof cost); LAMBADA not yet
  measured [MEASURED in the fidelity replica, 48+48 sequences; not yet a
  built proof profile]. 8B: the weight multipliers alone take it from 1.28x
  to 1.16x; the full stacks are being measured now.
- **What parity costs in proof size** (native count, exact against R9's
  layout): weight multipliers alone +10% (8B T128) / +7% (8B T512); the full
  stacks +22% to +29% (8B T128, prove time about +15% to +19%) and +18% to
  +26% (8B T512); TinyLlama LOW +21%. Softmax precision to 12 bits and the
  per-group SiLU tables cost nothing. Any such profile needs a soundness
  re-review and is outside today's privacy statements
  (`results/zk60_1b_native_20261017/r10/WEIGHT_RANGE_COST.md`, `r11/ACTIVATION_COST.md`).
- **Division dictionary (DD) accepted on soundness** (D24 review r9); privacy
  gate on DD captures in progress. Measured effect at 128 tokens: none
  visible (counted −3.9% committed at 8B); its payoff is at 512 tokens.
- **Demo kit measured on its final binary** (token round 11, `0c9f247c…`,
  frozen; REVIEW6 items closed): 8B 32-token demo prove 296 s with loading,
  verify 50 s; 8B 128-token demo prove 569 s, verify 55 s; both open token 11
  [MEASURED, n=1]. The presenter page now labels every speed ratio: the whole
  next-word proof is ~140–190x plain 8-bit inference at 32 tokens, ~80–100x
  at 128.
- **Waiting on Victor (console):** "extend D33 to frozen-r9" and "accept the
  next-token privacy statement" (both independently reviewed: yes / ready).

**2026-10-20 03:49 UTC — presenter demo kit ready; next-token prover hardened.**
- **Demo kit for presentations:** `results/zk60_token_io_r1_20261017/tools/demo_present.sh`
  (one command, narrates each step in plain words; options 8B 32-token,
  TinyLlama, 8B 128-token) and the one-page script
  `results/zk60_token_io_r1_20261017/DEMO_PRESENTER.md` (what is shown, what
  each step proves and hides, honest numbers, what NOT to claim, five Q&As).
  TinyLlama dry run: ~130 s of work end to end, token decoded for the owner
  [MEASURED]. Quiet the box before showing it.
- **Next-token prover round 9** (named CPU binary `b56f1b71…`): every refusal
  now happens before anything is written (privacy review PR4-4); the prompt is
  read from a protected file, never the command line; owner files live in
  `~/zk60-owner-private/`. Independent code review (REVIEW5): demo-fit, nothing
  affecting soundness; forged next-token proofs are rejected by the verifier
  in every tested case (8 of 8 on the old code, 4 of 4 on the new).
- **Privacy:** D33 re-pin onto the newer code reviewed YES — awaiting Victor's
  word ("extend D33 to frozen-r7"); next-token statement draft: 7 review items,
  most now closed (gate round 10 finishing the rest); D34 records the tiny
  input-dependent refusal term (~2^-117).

**2026-10-19 23:25 UTC — the next-token stages pass the privacy gate; first
128-token next-token proof.**
- **Privacy gate on the next-token stages** (prompt lookup, final norm + head
  + token choice, token endpoints; gate tools v10,
  `results/zk60_gate_tinyllama_20261017/token_io/TOKEN_GATE_REPORT_T32_v10.md`):
  all 10 captures PASS — TinyLlama T32 at 1, 2 and 22 layers and Llama-3-8B
  T32 at 1 and 2 layers, each with a real and a fixed prompt. The new
  commitments disclose nothing beyond the public lookup identity; the joint
  view across the shared planes is computed (0); full preimage on every
  commitment, 0 entries differing; 36 tamper controls fire on every capture
  [MEASURED, n=1]. Gate evidence, not a privacy acceptance: a next-token
  privacy statement is being drafted, then an independent review, then
  Victor. Not covered: the hidden-length variant, the GPU path.
- **First private next-token proof of a 128-token prompt:** TinyLlama
  (per-layer calibration), prove 192 s, about 0.67 prompt tokens/s (0.38 at
  32 tokens), integer and float references agree on the token (491, "by")
  [MEASURED, shared box]. **Llama-3-8B, 128-token prompt (01:12 UTC):** two
  exports proved end to end — b7voc0 501.6 s total (3.9 s per prompt token;
  8.3 s at 32 tokens) and the per-layer dg export 529.2 s; verify ~57 s;
  receipt 928 MB; whole-run floor 96 bits; owner decommits token 11 = integer
  and float references on both [MEASURED, shared box, n=1]. In tokens/s on
  the laptop CPU: 8B ~0.26 prompt tokens/s at 128 (0.12 at 32); TinyLlama
  ~0.67.
- **Fidelity, 8B with per-layer constants (dg):** perplexity 1.28x float (was
  1.63x / 1.77x), LAMBADA 0.69 vs float 0.78 (was 0.54) — about half the gap
  closed; bar (D32) is 1.01x and 99%. On TinyLlama the remaining loss is
  mainly the int8 weights (~1.5–2%); wider or better-rounded weights are
  being costed.
- **D33 re-pin** onto the tree the demo runs (R8 + token code): every pass at
  1 and 2 layers clean; 22-layer passes pending.

**2026-10-19 16:57 UTC — first privacy acceptance at a trained model's size
(D33).** Victor accepted the trained TinyLlama-1.1B T32 privacy statement in
the console. In plain words: a verifier who checks a proof of the 22-layer
trained TinyLlama stack learns nothing about the hidden prompt, activations or
output, except with odds around 1 in 2^70 per run (about 1 in 2^40 over a
billion runs). Scope is narrow on purpose: calibration pg_rot1, 32 tokens, the
CPU binary from native R7. Not covered yet: the per-layer recalibrations, the
next-token stages (gate round 7 running), Llama-3-8B, the GPU path; native R8
changed pinned files, so R8 needs a gate re-pin before it inherits this.
Text: `docs/zkmatrix-poc/ZK60_PRIVACY_STATEMENT_TRAINED_TINYLLAMA_T32.md`.
- **Fidelity threshold ruled (D32, ~17:00 UTC):** integer perplexity <= 1.01x
  float (FineWeb and WikiText), LAMBADA >= 99% of float, zero refusals. Today
  [MEASURED]: TinyLlama b4 1.23x / 1.29x, LAMBADA 0.512 vs 0.628 (82% of
  float); 8B b7 LAMBADA 0.54 vs 0.78 on 100 items (69%). Far from the bar;
  the per-layer (dg) and GPTQ levers are being measured.
- **Same afternoon:** the 8B next-token demo ran end to end on native R8 with
  the recalibrated export (b7voc0: no layer-0 refusals over the whole
  vocabulary): prove 265 s, verify 81 s, owner reads token 11 = the integer
  and float references; token suite 748 passed / 0 failed [MEASURED, n=1].

**2026-10-19 16:18 UTC — the prover now carries the fidelity fixes.**
- **Both recalibrated stacks proved on native R8** (per-layer values for every
  calibration constant), bit-exact against the integer reference at every
  layer, verified in a fresh process from a verifier's copy, 11/11 controls
  refused [MEASURED, n=1]: TinyLlama `dg` T128 (every layer at its own
  constants) prove 183 s, receipt 498 MB; Llama-3-8B `b7voc0` T128 (b7 + the
  layer-0 vocabulary recalibration) prove 479 s quiet box, receipt 923 MB,
  verify 43 s. Receipt sizes are unchanged: the fixes cost no proof size.
- **The 8B layer-0 refusals are gone:** the recalibrated layer 0 accepts all
  128,256 vocabulary tokens (it refused " ." and "Tags" before) [MEASURED,
  exhaustive]. On the demo prompt, integer and float agree on the next token
  (11, margins 9.5 / 7.0 logits).
- **Fidelity is still far from parity** [MEASURED]: 8B b7 LAMBADA first 100
  items 0.54 vs float 0.78 (−24 points); TinyLlama b4 perplexity 1.23x / 1.29x.
  The `dg` per-layer calibration and the 8B dg build are being measured next.
- **Token lane round 6 done** (owner-directory race fixed, the demo reads its
  pins from an approval record, 8B demo passed end to end, full suite 740/0);
  round 7 moves it onto R8 and runs the demo on the recalibrated 8B export.

**2026-10-19 13:38 UTC — demo-ready CLI, honest baselines, fidelity target set.**
- **Demo flow for the trained 8B next-token proof** (`results/zk60_token_io_r1_20261017/tools/r4_cli_demo.sh`):
  `prove` 227 s (laptop CPU; 471 MB) -> `verify` 90 s (pinned to the trained
  model identity and the token-profile digest; the verifier publishes the
  statement itself) -> `owner` 83 s (re-verifies, then the prompt owner reads
  token 11) -> `input-owner` (the prompt owner confirms the proof used their
  32-token prompt). A layer-0 pre-check refuses the two tokens that overflow on
  today's 8B export (" ." and "Tags") by name before anything runs. Reviewed
  (token review rounds 1–4; round-4 fixes under confirmation).
- **Honest speed baseline** (`results/zk60_cpu_inference_baseline_20261019/README.md`):
  plain CPU inference of an 8B Llama at 8-bit takes ~1.55 s for 32 tokens and
  ~5.6 s for 128; the private proof takes 156 s and 433 s — about 100x and
  77x [MEASURED]. Tokens/s improves with prompt length up to ~128–256 tokens
  (~0.3 tok/s on the laptop CPU), then falls as attention grows.
- **Fidelity (D32: no performance degradation versus float).** Proposed
  threshold (for Victor): perplexity <= 1.01x float on FineWeb and WikiText,
  LAMBADA >= 99% of float, zero refusals. Today: TinyLlama 1.23x / 1.28x, 8B
  1.63x / 1.77x. Per-layer constants close ~52% of TinyLlama's gap (1.105x /
  1.121x) with no new proof planes; native round R8 is adding them for every
  shift. The 8B refused every WikiText window at layer 0 (token " ."); a
  vocabulary-wide recalibration of layer 0 (no proof cost) is in progress.
- **Privacy at trained TinyLlama size:** the statement is final after three
  independent review rounds and the gate's R7 re-gate; acceptance awaits
  Victor's word in the console.

**2026-10-19 10:20 UTC — first private proof of a trained Llama-3-8B's NEXT
TOKEN.** One proof: a 32-token hidden prompt -> the trained int16 embedding ->
all 32 trained blocks (streamed; layer 1 at its own score shift) -> final norm
-> per-row int8 head -> greedy token, sealed in a hidden output fingerprint;
the verifier sees no prompt, no activation and no token (D25). Token 11,
confirmed by three independent references (float head's top-2 margin 4.40
logits); bit-exact at all 32 layers; receipt 471,285,072 B; prove 191.7 s on
the laptop CPU, peak 3.44 GiB; fresh-process verify 43.4 s under a 95-bit
policy; 65 of 65 applicable tamper controls caught; whole-run soundness 97
bits; full suite 729 passed / 0 failed [MEASURED, shared box, n=1;
`results/zk60_token_io_r1_20261017/runs/r3/trained-ho00/`]. The integer head
meets D25 T4 at 8B (100% agreement with the float head wherever its margin is
>= 0.3; 99.1–99.8% overall). Independent review of this rung running.

**Also since 10-18:** the fidelity-improved 8B T128 block stack (layer 1 at
score shift 7; held-out top-1 0.651 -> 0.673) proved (471.6 s, shared box) and
was re-verified independently (identity 97c4acda…); quiet-box 8B stacks: T32
156.2 s, T128 432.5 s. Native R6 and R7 frozen and accepted / under review
(R7: stale-writer handling, backend allow-list). Privacy evidence at trained
TinyLlama size complete on R5b; the second independent privacy review lists
five closing items (re-pin and re-gate on R7, G-7, a 2-block root-rebuild
check, a text consolidation, owner confirmations D28/D29 — done); those are in
progress. GPU slot-18 kernel at 25.9 ms = 19.4% of 256 GB/s (laptop clock
capped at ~1.1 GHz); lane paused with a 5090 start plan. Victor's GPT
conversations yielded DD (per-row division dictionary, −20.8% committed at
8B T512, exact), admitted into the 8B T512 profile specification as D30; FN
withdrawn as a question.

**2026-10-18 01:42 UTC — first private proof of a trained model's NEXT TOKEN.**
TinyLlama-1.1B, a 32-token hidden prompt: hidden token ids -> embedding (indexed
lookup into the public int16 table) -> all 22 trained blocks -> final norm ->
per-row int8 head with 12-bit multipliers -> greedy choice (lowest-id ties),
the token sealed in a hidden output fingerprint, all **one proof under one
transcript**; the verifier sees no prompt, no activation and no token (D25).
Next token 29914, confirmed four independent ways (in-test reference, the
Python reference, the fidelity lane's integer head and its float head).
Receipt 255,258,816 B in 24 segments (equal to the counted lengths); prove
85.3 s on the laptop CPU, peak 2.45 GiB; fresh-process verify 10.6 s under a
95-bit minimum policy; a one-bit change refused; 55 of 55 applicable tamper
controls caught exactly where predicted; whole-run soundness 97 bits (meets
D27); full suite 708 passed / 0 failed [MEASURED, shared box, n=1;
`results/zk60_token_io_r1_20261017/runs/r2/ho00/`]. Built on the design that
passed two adversarial checks and on the tiny rung R1 that passed an
independent code review; the review of this rung (R2) is running. **Not yet:**
the hidden-length variant (D26), the privacy gate for the token stages
(G-1..G-7), and Llama-3-8B (rung R3). Not a privacy acceptance.

**2026-10-18 00:10 UTC — overnight checkpoint.**
- **First private Llama-3-8B stack at T128:** all 32 blocks, a 128-token
  hidden prompt, one proof: 607 s total on the laptop CPU with the R5b
  safeguards (487 s before them; the difference is a second witness build for
  the refusal-before-header rule), receipt 922,711,264 B, parity bit-exact,
  fresh-process verify with 11 tamper controls refused (0.21–0.26 proved
  positions/s) [MEASURED, shared box, n=1]. The T64/T128 profiles are under
  independent review (round 5).
- **R5b frozen (2026-10-18 00:06:31Z):** fixes the privacy review's blocker P-1
  (inadmissible inputs refused before the run header; the public statement is
  promoted only after a fresh verify), review r4's two verifier-DoS findings,
  and the gate's operating rules (allow-listed run label, hidden inputs kept
  out of the verifier's copy, refusal messages without data-derived counts,
  backend recorded). Suite 692 passed / 0 failed. Privacy gate re-capture and
  re-gate with tools v5 (pins now enforced) running on it.
- **GPU go/no-go:** 11.7% of the laptop GPU's bandwidth on the feed-forward
  zero-check, byte-identical to the CPU: improve kernels before porting more
  (register spills found; next round estimated 33–42%). Refitting the cost model
  on the 8B T128 stack confirms the plan: T512 on a 5090 is about 0.6–0.8
  positions/s with today's code, 6.6–8.6 with the whole prover on the GPU at
  today's efficiency, 9.4–11.8 with the attention-layout changes; 50 needs
  kernels near roofline.
- **Next-token proof:** rung R1 (tiny vocabulary) passes its full suite after
  census fixes and an independent code review (sound as built); review fixes
  TR-1..TR-4 and rung R2 (TinyLlama, 22 blocks) in progress.
- **Fidelity:** 8B T64 and T128 exports verified bit-exact; layer 1's weak spot
  traced to large negative attention scores setting a coarse scale; a per-layer
  score shift lifts held-out top-1 at T128 from 0.651 to 0.673 (KL 0.61 -> 0.50)
  with no layout change — native round R6 is adding it.

**2026-10-17 21:10 UTC — evening checkpoint: 8B stack 2.2x faster end to end,
security accounting corrected, five rulings recorded, next-token proof
designed and being built.**
- **Speed (startup cleanup, speed plan task 1 MET):** the private 32-block
  Llama-3-8B stack at T32 now takes **171.6 s total** (was 384.5 s this
  morning; target <= 180 s): weight digest pass 15.3 s (was 83.0), block
  reloads 16.0 s (was 79.2), witness 21.4 s, block proofs 118.8 s, in-process
  verify off (the fresh-process verify remains the check). Same statement
  identity 259dad7c…, same 465,815,776-byte receipt, parity bit-exact
  [MEASURED, shared box, n=1; `results/zk60_1b_native_20261017/r5/`]. That is
  0.19 proved positions/s at T32; the speed target (50/s on a 5090 at T512)
  still needs the whole prover on the GPU (speed plan).
- **GPU go/no-go (task 2), interim:** slot 18's zero-check runs on the laptop
  GPU with byte-identical rounds and seeded proof bytes at four shapes, 0
  silent fallbacks; a 22-block TinyLlama T128 stack with it proves and
  verifies fresh. Open: inside the stack the slot runs ~5x slower than in
  isolation; the bandwidth verdict waits for that diagnosis.
- **Reviews:** the independent review accepted the Llama-3-8B profile changes
  on soundness (round 3); its verifier-DoS finding (unbounded segment reads)
  is fixed in the frozen round-5 tree, which is under review now (round 4).
- **Security accounting (register D15, two notes):** the "106 bits per
  opening" ignored padding, and the lookup bound is now the checked
  (N + 2303)/|F|. Trained stacks are **about 97.4–98.2 bits whole-run**; an
  8B run at 512 tokens about 94.7 (about 99.7 as forger work per attempt).
  **Victor's D27:** about 95 bits whole-run is the MVP target at the named
  workload, 100 next, 128 for the product, with selectable tiers later for
  critical applications; throughput is not traded for bits at the MVP.
- **Rulings recorded today:** D23 and D19b accepted; D25 (next-token proof:
  one hidden token per run, hidden and sealed prompt length, lowest-id ties,
  per-row integer head matching the float head wherever its top-2 margin is
  >= 0.3 logits, private owner hand-off, BOS forced); D26 (security owner:
  the two-site input endpoint); D27 (soundness target).
- **Next-token proof:** design v3 passed two adversarial checks (three holes
  found and fixed before any code), paper reference 20 tests green; integer
  head fidelity measured on TinyLlama (98.9% overall, 100% wherever the float
  head is not a near-tie); the first native rung (tiny vocabulary, 2 blocks)
  is being built. Cost at 8B T32: about +3% proving time [MODEL].
- **Privacy gate (TinyLlama T32, 22 blocks):** the dense 22-block pass PASSES
  with every control family firing; the all-zero pass reconstructs every
  published value with 0 differing (25 million in the joint check); finding
  G-10 repaired. Owed before any acceptance: re-capture from the frozen
  round-5 tree (running), an independent re-read and adversarial review of
  the draft (running), and the remaining items of the draft's §10b. **No
  privacy acceptance at the trained shape yet.**

**2026-10-17 18:35 UTC — clean shutdown at 14:59, resumed at 18:21; no new
result yet.** The laptop shut down cleanly at 14:59:58 UTC (every guarded job
got SIGTERM; not a freeze) and booted again at 18:21. Correction to the 14:00
block below: the GPU go/no-go experiment had code written but **never ran on
the GPU** — its first device test was killed after 6 s by the shutdown. Also
cut off: the native round-5 test suite (never started), the 8B T64 calibration
export, and the review's last checks. The privacy gate's 22-block all-zero
pass finished before the shutdown: 0 differing values in the masking layer
(355,410 checked) and in the joint run (25,005,697); its FAIL flag appears to
come from controls that were not requested in that pass (being confirmed).
Everything uncommitted was pushed as snapshot 6 of
`snapshot/20261017-uncommitted`. Six lanes restarted behind the resource guard
(`ops/zkp-mvp/LANE_RULES_20261017.md`): GPU zero-check go/no-go, native R5
suite + startup cleanup + 8B T64/T128 phase ladder, review verdict on the 8B
profile, privacy gate controls and G-10, 8B calibration B6, and a paper design
for proving embedding, head and token choice (D13's next milestone).

**2026-10-17 14:00 UTC — how far from 50 proved tokens/s, measured-model
answer.** The costed speed plan ([ZK60_SPEED_PLAN_20261017.md](ZK60_SPEED_PLAN_20261017.md))
fits a per-phase cost model to today's TinyLlama ladder and predicts the
measured 8B T32 stack within 3.1%. Its projection for private Llama-3-8B at
T=512 on one RTX 5090 [MODEL]: today's code ~0.55 positions/s; the whole prover
on the GPU at this project's measured GPU efficiency ~7–9; with commitment
kernel and attention layout improvements ~11 (high end 22). **50 is reachable
only if every GPU kernel moves its counted bytes at about 23–34% of the 5090's
bandwidth** (today's commitment kernel: ~13% on the laptop). The plan's
go/no-go experiment — the FFN zero-check (slot 18) on the laptop GPU, with
measured bandwidth — started at 13:55 UTC; below ~10% the remaining levers
are design changes needing Victor's rulings (LogUp-GKR helpers, code rate
1/2, 16-bit range tables), which together still reach only ~13–16 [MODEL].

**2026-10-17 13:20 UTC — first complete private proof of a trained 8B model's
transformer stack.** All 32 blocks of Llama-3-8B (NousResearch/Meta-Llama-3-8B
rev 315b2009…, 8,030,261,248 parameters) proved as ONE bound private run at
T=32 (hidden input, output, activations and boundaries; public weights);
native witness bit-exact with the Python integer reference at all 32 layers;
calibration export `llama3_8b_pg_rot1_T32` (held-out top-1 0.62 FineWeb /
0.55 licence). Laptop CPU, shared box, n=1: total 384 s (weight loading 79 s,
witness 19 s, block proofs ~110 s, in-process verify 93 s), receipt
465,815,776 B in 32 segments, fresh-process verify 96 s, peak RSS < 2 GiB; 11
run-level tamper controls refused, honest run still verifies. Statement
identity 259dad7c…. Evidence `results/zk60_1b_native_20261017/r4/`.
The same stack on the laptop GPU (commitments on the device, "gpu: ON", 0
declines) took 391 s with the same statement identity: level with the CPU at
T32, where reloading the 8B weights (about 2.5 s per layer, three times per
run) dominates and the block proofs are 3.4–3.7 s each.
**Not yet:** speed (0.08 proved positions/s total; target 50 on a 5090),
T > 32, embedding/head (D13), fidelity (layer-1 attention sink), independent
review of the 8B profile changes, privacy acceptance at this shape, D23.

**2026-10-17 11:15 UTC — trained 1.1B stack 9x faster; first context ladder.**
Building the witness once and in parallel took the 22-block TinyLlama stack
from 529 s to 56 s at T32. Ladder on identical weights (CPU / laptop GPU,
shared box, n=1, each verified in a fresh process): T32 56 / 61 s, T64 85 /
89 s, T128 169 / 143 s — **0.76 proved positions/s on CPU and 0.90 with the
GPU at T128**, receipts 251 / 333 / 498 MB. The block proofs are now 72–81% of
the time; GPU commitments help from T128. T256+ needs more host memory than the
laptop has. D24 and the trained profile are accepted on soundness after two
independent review rounds. Next: Llama-3-8B calibration (running), an 8B
profile, and a T32 private 8B stack attempt on this laptop.

**2026-10-17 10:15 UTC — first complete linked proof of a trained model's
transformer stack.** All 22 TinyLlama-1.1B blocks as ONE private run (hidden
32-token input, output, activations and every block boundary; public weights),
calibration `pg_rot1` (held-out top-1 agreement with the float model 0.70–0.73,
no refused inputs). CPU, shared laptop, n=1: 528.9 s total, of which ~450 s is
building the witness twice on one thread and ~60 s the block proofs; receipt
251 MB; fresh-process verify 4.9 s; peak 2.15 GiB; 11 run-level tamper controls
refused. Before it, the independent review accepted the D24 norm rule but
found a real hole in the trained loader (an unchecked export constant let a
forged output verify); fixed the same morning (every export-chosen constant now
has a checked class; the forgery is refused) and under focused re-review.
**Not yet:** privacy acceptance at this shape, T above 32, GPU stack timing
(running), embedding/head (D13's next milestone), 8B.

**2026-10-17 05:20 UTC — first proofs of a real trained model's blocks.**
Every one of TinyLlama-1.1B's 22 transformer blocks was proved privately
(hidden 32-token input, output and activations; public weights) and each proof
verified in a fresh process from its bytes; the native prover's numbers equal
the independent Python integer reference bit for bit at every layer. Per block
on the laptop CPU: prove 3.2–4.2 s, verify 0.27–0.40 s, 11.6 MB, under 0.9 GiB
[MEASURED, shared box, n=1]. Layer 0 refused all 15 tamper/mismatch controls.
Full native suite 518 passed / 0 failed; frozen toy receipts unchanged.
**What it is not:** 22 separate one-block proofs, not a linked stack (nothing
yet ties block k's output to block k+1's input); proved on the low-fidelity
calibration `a` (held-out top-1 0.136 vs float); conditional on the independent
review of proposed ruling D24 (running); no privacy acceptance at this shape.
The calibration lane found a usable per-profile calibration (`pg_rot1`: top-1
0.698, perplexity 36.5 vs 29.3 float, no refusals) that needs four requant
shifts to become profile constants; the native lane is doing that now, then
the linked 22-block stack on CPU and GPU. Victor flagged arXiv 2610.08258
(zkLLMPoT, v2 11 Oct 2026): it hides weights with public audit inputs (the
reverse of our P1) and reports 41–59 s at 1.1–1.5B for "covered operators";
an assessment is running. Mac M3 Ultra (256 GB) not yet reachable; 5090 not
yet installed. [Checkpoint](ZK60_1B_CHECKPOINT.md).

**2026-10-17 02:20 UTC — work resumed after a 17-day gap; no new proof yet.**
Nothing native ran between 2026-09-30 01:38 UTC and today: the recovery session
of 09-29 ended abruptly (cause unknown; one minute earlier the resource guard's
memory cap had correctly killed an oversized test), and since then only the
hourly researcher worked (cycles 41–51, CPU-only arithmetic studies; none
changes the prover). The three answers are unchanged from the 09-30 block
below: **(1) workable proof:** complete private proofs exist for the tiny
block (two lines, privacy accepted only there) and for synthetic 125M-shape
stacks; **no trained block has been proved yet**. **(2) speed:** best complete
stack rate is 1.25 proved positions/s (synthetic 12-block 125M shape, laptop
GPU-assisted), about 40x short of 50 even at that small size; for 8B the
project's own projection is 0.6–1.2 tokens/s on a 5090 with today's code and
5–13 with every sumcheck on the GPU (not built), so **50 needs a design change,
not tuning**. **(3) what blocks the MVP:** a trained-model profile (norm
constants, calibration, weight loading), then the 22-block TinyLlama stack,
privacy re-checks at the new shape, and for 8B the RTX 5090 machine (Linux not
yet installed). Today: all uncommitted work since 09-23 was pushed as branch
`snapshot/20261017-uncommitted` (preservation only); the Llama-3-8B download
resumed; two lanes started — the native TinyLlama profile (proposed ruling D24:
lower the norm precision constant instead of adding a fifth limb) and the
calibration fidelity ladder with exports for a bit-exact parity check.
[Checkpoint and lanes](ZK60_1B_CHECKPOINT.md).

**2026-09-30 01:27 UTC: the box froze on 2026-09-29 (17:40 PDT); heavy work now goes through one
guard.** The machine died with five heavy jobs live, including the first
production 12-block GPU stack run, which therefore has **no result** (its log
stops after a GPU commitment; nothing was published). The exact cause is not
proven (no out-of-memory or GPU-memory error was logged); the fix is that
every build, proof, calibration and benchmark now runs through
`scripts/zk60_resource_guard.py`: one heavy job at a time, kernel-enforced
memory caps, GPU-idle checks and a permanent record of measured peaks
([rules and limits](ZK60_RESOURCE_PROTOCOL.md); 45 tests pass; Codex found and
we fixed a bug where the guard could have adopted its caller's session scope).
Nothing about proof speed changed. Best measured number is still the earlier
**synthetic** 12-block, 125M-geometry stack on this laptop's 4070:
1.25 proved positions/s over the whole test wall, about **40x short** of 50.
No trained 1B block or stack has been proved. Lane status: TinyLlama
calibration (Python reference) and the trained-profile prototype (five-limb
norm; its lost scratch work was recovered from a transcript, 7 fast tests pass)
are running again behind the guard; the production stack run waits for the
guard's small-shape canary. This is a stability fix, not a milestone.

**September 29, Tech Week demonstration:** the local browser demo now uses
real retained 785-byte Groth16 receipts for the small block and synthetic
two-block token model. Fresh-process verification and proof/policy tampering
controls pass. The HTTP path passes 32 checks across all three modes,
including artifact downloads and request boundaries; 69 demo and existing
zkVM-runner tests pass. Saved verification does not generate a new proof.
The live native synthetic-block option also passes, generating a 2,816,472-byte
proof and independently verifying it with tamper controls. Its 0.256-second
complete check is a shared-machine toy diagnostic, not a trained-model rate.
It uses a public fixture and the shared heavy-job lock; its first attempt
deferred while another proof held that lock. Trained
calibration/import and model-scale privacy/performance remain outstanding.
[Run the demo and review its exact scope](ZK60_TECHWEEK_DEMO.md).
GPT-6.1-Sol supplied the demo backend/readiness review; the existing Sonnet 5.5
lane supplies the separate native stack CLI. The hourly research supervisor
was confirmed alive and unpaused on the host at 00:12 UTC September 30
(17:12 PDT September 29); its next cycle is due at 17:45 PDT.

**Latest direction, 2026-09-26.** Target a complete private **8B-parameter
forward-pass proof at >=50 proved tokens/s on an RTX 5090 or another high-end
GPU**. Victor explicitly permits more tokens to amortize initialization and
initial prefill. The old 512-token / 10.24-second window is a reference, not
a mandatory latency limit. Measure larger workloads, report both sustained
and total-workload throughput, and retain setup, witness, proof and verification
clocks. [Current target and workload accounting](ZK60_THROUGHPUT_TARGET.md).
D13's first MVP still covers the hidden transformer blocks; token generation
is the following milestone. No complete private 8B timing exists yet.

**2026-09-27 UTC, Sol team checkpoint.** Three GPT-6 Sol agents completed
their native fusion, keyed GPU commitment and memory/model-readiness batches. The
fusion candidate passes core debug/release, 512 native tests (17 ignored),
fresh/cross-version receipt verification and nine corruption refusals. Its
six-run CPU A/B completed: the fused evaluator was 1.66% slower in mean
proving and 10.38% slower in the softmax slot (two non-warm samples per arm).
It is demoted; the grouped baseline stays in place. The keyed GPU candidate
now passes resident, forced streaming, compact-pad and complete small tagged
block CPU/GPU receipt checks on the RTX 4070 Laptop. The first streaming
launch failure is retained separately; the corrected attempt passed and all
source/binary/log hashes were rechecked. Independent review found no concrete
static defect; core debug/release pass 74 unit + 2 integration tests each.
The broader device oracle passes all 189 cases. Native GPU-feature release
coverage is 491 passing tests plus one successful missing-fixture rerun,
17 ignored; it is not a single full-suite pass. All eight frozen legacy
proofs now match exactly across resident/forced-chunk configurations. One
runner falsely rejected v3's success marker; its failed report is preserved,
with an explicit source/log/proof-hash adjudication and six passing remaining
cases. Root rechecked the 184 source, six binary and six continuation log
hashes. The six-run dense CPU/GPU A/B is complete and all receipts verify.
Two non-warm samples per arm give mean proving **32.95 s CPU / 17.13 s GPU**
and whole test-process elapsed **39.895 s / 30.055 s**. Mean peak host RSS
falls from **10,524 MiB to 4,411.5 MiB**; VRAM peak was not measured.
This is one synthetic 125M block, two CPU threads, RTX 4070 Laptop, shared
host. One GPU witness build took 10.66 s versus 5.77 s in the other sample;
the hourly researcher was active. Each sample uses a fresh process, so
startup and verification remain in whole-process elapsed. This is not
steady-state throughput or a complete-model rate. Softmax proof work remains
roughly half the GPU-assisted prover's time. See the
[A/B evidence](../../results/zk60_sol_gpu_20260927/attempt-5-dense-ab/report.json).
No 5090, full trained 8B or larger-profile privacy result is established.
[Team/evidence map](ZK60_SOL_TEAM_20260927.md).

An allocation-free audit of the historical 7.24B Mistral geometry counts
25.70 GiB retained payload at 512 tokens and 70.57 GiB at 1,024 tokens,
before weights and some scratch. These are lower bounds for unregistered
layouts, not measured peak memory or 8B proofs. All 256 historical FFN
export tensor files are missing; their manifest survives. A trained full-
block importer/calibration and a literal 8B checkpoint remain outstanding.
[Model and memory audit](../../results/zk60_sol_model_20260927/layout-readiness.md).

Victor has both the RTX 5090 machine and the M3 Ultra available (256 GB
unified memory, corrected by Victor on 2026-10-17; earlier text said 512 GB).
The 5090 machine needs a fresh Linux installation; neither new machine has
been validated remotely. The [setup guide](ZK60_HARDWARE_SETUP.md) starts
with a USB Ubuntu installer made on the Mac, followed by driver and read-only
host checks. The Mac's first role is CPU reference/witness work; there is no
Metal proof backend. Memory-bounded commitments are an active follow-up.
A small CPU streaming-root/recomputed-opening prototype passes eight legacy
and tagged fixtures: identical leaves, roots, opening bytes, transcripts and
RNG continuation, with mutation refusals. Releasing A/H codewords would
reduce the T512 retained floor to 5.35 GiB. This is a test-only prototype;
production lifetimes, measured peaks and throughput still need validation.
The successful **GPU chunked path already streams codewords and recomputes
queried columns**. Its separate A/H retained bounds are 5.18/14.23 GiB on
host and 5.17/14.22 GiB in VRAM at T512/T1024; the earlier 25.70/70.57 GiB
floors describe materialized storage or CPU fallback. Host witness/helper
overlap remains at least 9.86/27.17 GiB before other scratch.
[Updated tier-specific audit](../../results/zk60_sol_model_20260927/gpu-chunked-memory-audit.md).

The persistent hourly research supervisor was resumed and its host process
confirmed alive; its first sandbox restart failed before research began, and
the host restart retains the hourly schedule. A separate session research
agent completed a [resource-budget handoff](../../research/zkp-efficiency/handoffs/20260926-forward-budget-and-traffic.md).
Its 14 arithmetic checks are not prover or GPU measurements. Raw-log correction:
the historical FFN-only 196.79 s is internal wall time; enclosing process elapsed
is 200.09 s. Both exclude the earlier witness export/inference work.

Implementation has resumed in an isolated Rust candidate: the research lane's
grouped-equality softmax evaluator is wired into the real SC_SZC slot. Core
debug/release tests pass (73 unit + 2 integration each), including masked
bytes/challenges/finals and a release work-count check (1,403 -> 1,148 expensive
bracket calls). Eight targeted native tests also pass: dense/padded block and
three-block-run verification, inconsistent-witness refusals, and independent
polynomial oracles at every registered shape. Fresh/archived receipts cross-
verify in four processes with nine corruption refusals. **The full native suite
has now passed: 512 tests, 17 explicitly ignored.** All nine validation steps
pass; 183 source hashes, three binaries and all nine log hashes were rechecked.
The dense grouped A/B has completed: all six proofs verify at 40,783,352
bytes. Two non-warm runs per arm show proving 37.63 / 36.84 s before versus
34.86 / 33.31 s after: about 8.5% less proving time on average in this
shared two-thread CPU diagnostic. The full softmax slot falls about 18.4%;
the known witness+prove+serialization sum falls about 7.2%. Warmup proving
times were nearly equal (34.69 / 34.38 s), and two samples per arm do not
establish a stable production speed factor or p95. Both binaries include
small-slot test oracles; no GPU/8B or privacy-scope result follows.
[Retained candidate and validation](../../results/zk60_grouped_rounds_20260926/README.md)
record the evidence and audited phase summary.

**Live work checked at 05:41 UTC:** the hourly GPT-6 Sol research supervisor
is alive and unpaused, idle between cycles; cycle 0013 completed and the next
is due at 05:52:33 UTC. The earlier implementation/benchmark batches are
finished; no full 8B proof or 5090 benchmark is running. Cycle 0013 tests a
synthetic device-round schedule for softmax sumcheck: 110 round-point checks,
91 final-table checks and eight mutation controls pass on CPU. It does not
implement the actual native polynomial, BLAKE3 transcript or CUDA path.
The next implementation gate is exact native masked-transcript parity before
a device round/fold implementation and whole-proof timing. The eleventh
cycle's direct-helper experiment has a roughly 3% parent-phase ceiling in
the cited earlier CPU workload. The ninth cycle's fused fold/next-round
proposal was implemented and measured above, then demoted after slower
results despite lower counted table traffic.
Victor requested periodic updates; active sessions report here in chat, and
each background cycle must refresh the durable
[progress report](../../research/zkp-efficiency/PROGRESS.md). Local reports
are not automatic chat notifications.

The separate R2a allocation A/B completed: all six dense 125M proofs verify
at 40,783,352 bytes. Non-warm proving seconds: old 44.51 / 40.27, new
39.73 / 40.10, two CPU threads. Native compilation overlapped part of this
shared-box measurement; no reliable end-to-end gain is established. These
conditions differ from the earlier 17.4–19.4 s CPU runs, which they do not
replace. No new privacy acceptance or private-model speed is claimed.

**Updated 2026-09-22, during shaped-block integration, by the Codex/Fable
loop (after the 01:04 laptop restart; see §3 item 4).** This page
answers three questions and is refreshed whenever the loop produces news.
Rulings are in [the decisions register](ZK60_DECISIONS.md); measurements
carry their labels ([MEASURED] a run happened, [COUNTED] arithmetic on
measured pieces, [MODEL] an estimate). Nothing here is a quiesced benchmark;
the laptop is shared with other jobs.

**Current speed and completeness (2026-09-22).** The latest dense synthetic
block at the 125M geometry proves in **17.4–19.4 seconds on CPU**, down from
27.7 seconds; its receipt is 40,783,352 bytes and verification takes
1.15–1.34 seconds [MEASURED, shared box]. The 17.40-second run separately
spent 5.24 seconds preparing the witness, so it is at least 22.64 seconds
before verification. The latest twelve-block dense run remains **397.71
seconds**, with 14.45-second verification and 484,107,456 receipt bytes; it
predates the latest speed changes and has not been re-timed with them. The
five-second goal concerns a model pass; the single-block clock alone does
not establish its distance from that goal.

All transformer-block operations and twelve-block chaining are implemented
and exercised on synthetic public weights with hidden activations. The
grouped-attention completeness repair has been independently reviewed.
Whole-proof privacy acceptance remains confined to the small CPU toy block;
the larger profiles' privacy argument, trained-model integration and the
production run interface remain unfinished. Main's host optimization is
accepted; the combined larger-block source at lane `fee1a8d` has passed its
16-step CPU integration baseline in `/tmp/wt-zk60-shaped-20260920`, with
source-pinned results under `results/zk60_shaped_integration_20260922/baseline/`
there. The retained logs and all 179 source hashes were checked again: no
mismatch. This is not final integration acceptance; device checks, wider
privacy acceptance and the production model run remain outstanding. No new
model-scale or GPU timing is implied by that integration work.

**2026-09-22, isolated sumcheck candidate:** an additive evaluator interface
and redundant-evaluation shortcut pass core debug/release checks, all 512
native tests across a full run plus a fixture-only rerun, and old/new receipt
verification. Four dense 125M block proofs also pass at the unchanged receipt
size. On two Rayon threads, the softmax sumcheck phase measured 9.05–9.26 s
before versus 8.55–8.59 s after (two samples each). Whole proving time varied
from 38.96–61.79 s before and 38.06–43.02 s after, so no reliable end-to-end
speedup is established. The candidate test binary includes extra small-slot
oracle checks. This is not yet integrated into main or a new privacy/GPU
acceptance; it does not replace the earlier differently situated CPU clocks
or the 8B target. [Source, tests and retained measurements](../../results/zk60_sumcheck_rounds_20260922/README.md).

**Target reaffirmed by Victor, 2026-09-22:** five seconds for an **8B-parameter
model on better hardware with a GPU**. The 125M CPU runs are development
measurements, not the target workload/hardware. Retain the current 512-token
prefill window when comparing throughput, and report proof generation,
witness preparation and complete readiness separately. The recorded public
Mistral-7B measurement is **58.40 seconds for FFN only**, or **8.77 proved
tokens/s** over that window; attention is excluded. Its complete logged wall
time is 196.79 seconds (2.60 tokens/s). There is no measured 54-second
FFN-plus-attention result. Five seconds over the same window would be 102.4
proved tokens/s; none of these rates measures autoregressive generation.

**Latest integrated speed work:** corrected direct-plane GPU uploads and
private host buffer/fold reuse pass 43 isolated validation steps, including
307 storage-feature tests, 189 actual-device cases and twenty frozen proof
comparisons. Main's separate rebuild and receipt checks also pass: two fresh
receipts, fourteen cross-version verifications and 24 GPU-feature private-IO
tests under all buffer/fold settings. Floors v11 pins the new inventory, with
89 tooling tests passing. [Evidence and limits](ZK60_HOST_PRIVATE_INTEGRATION_20260920.md).
These checks establish correctness; they do not measure private-model speed.

The preceding exact int8/int32 row folds pass all twelve
CPU/GPU proof-byte gates, fresh native receipt verification in both modes,
and repaired private-IO P1/P3 checks. Dense synthetic folds improve
2.32–2.42x; sparse cases are mixed. Full-model proving time remains
unmeasured. [Evidence and limits](ZK60_ROWFOLD_INTEGRATION_20260919.md).

> **CORRECTION, 2026-09-20 18:40 — read this before the 125M paragraphs
> below.** A defect was found today in the private block at every shape with
> more than one key-value head (both development sizes and the 125M shape;
> **not** the small accepted test block, whose acceptance D22 stands). **The
> verifier refuses an honest proof as soon as the hidden data differs between
> attention heads.** Every 125M result below — one block, two blocks, twelve
> blocks, tagged and untagged — was obtained on a synthetic input in which
> every head sees the same data, where the defect does not show. **So those
> results are true of the input they proved, and the 125M private block is NOT
> yet a working proof for general inputs.** The cause is understood (two
> attention steps treat a shared index as fixed where it must be summed over —
> the security owner's own construction error in generalising to grouped
> heads, missed by the design's checker and the code review because nobody
> proved a generic honest input); it costs completeness, and as far as argued
> not soundness: nothing false was accepted. The fix is being written now; it
> will change the proof bytes and sizes of the shaped profiles, and the 125M
> figures will be re-measured on dense weights and a generic input. The
> feed-forward half held up under the same test: dense weights, generic data,
> tampering at the wide hidden indices rejected. Found by the dense-weights
> test added this afternoon (finding S19-F1, lane `zk60-private-block-125m`).
>
> **Repaired the same evening (19:30), review pending.** The two attention
> steps now sum over the shared index. The honest input that was refused is
> accepted; a generic input on **fully dense** weights proves and verifies at
> the development size, as a three-block run too; tampering in the second
> key-value group is rejected by the verifier; the small accepted test block's
> bytes did not move. **At the 125M shape, one block on fully dense weights
> with a generic hidden input: prove 27.67 s, verify 1.12 s, receipt
> 40,783,352 bytes, peak 9.99 GiB; on the all-zero input: prove 26.98 s,
> verify 1.23 s** [MEASURED by the security owner, one run each, laptop CPU,
> shared box, 19:25]. Dense weights cost no measurable time. **These two are
> the first 125M results on a non-degenerate input; the twelve-block figures
> below have NOT been re-measured yet**, and an independent review of the
> repair (soundness, masking budget, completeness) is running. Still no
> privacy claim for anything but the small test block.
>
> **21:02 the same evening — reviewed, and the twelve-block run redone on a
> non-degenerate input.** The independent review found no hole in soundness,
> completeness or the masking budget, and confirmed that nothing false could
> have been accepted before the repair. **All twelve blocks at the 125M shape,
> fully dense public weights, a generic hidden input, one run under one
> transcript: prove 397.71 s, verify by streaming 14.45 s, receipt
> 484,107,456 bytes (equal to the counted figure), peak memory 10.15 GiB**
> [MEASURED by the security owner, one run, laptop CPU, shared box, 20:53].
> Every block's wide hidden layer, every attention head and every key-value
> group carries non-trivial values in that run. **This supersedes the
> twelve-block figures below as the project's 125M result**; they stay on the
> page as the record of what was run on the degenerate input. The privacy
> gate has not yet been run on a non-degenerate input (in progress at the
> development size), and **no privacy is claimed for any of this.**

**The 125M-shape block now proves in 17.4–19.4 s instead of 27.7 s — same
bytes, same refusals; independently reviewed (added 2026-09-21 10:00; second
sample and the range added 12:57).** *A second run of the same prover on the
same shared laptop, with a counting diagnostic switched on, took 19.36 s
(verify 1.34 s, same receipt length, peak 10,141 MiB); the parts of that run
the diagnostic does not touch moved more than the prove did, so it reads as
run-to-run spread, and the honest statement is a range from two runs, not
17.40 s.* One
block at the 125M shape, fully dense public weights, a generic hidden input:
**prove 27.71 → 17.40 s (37% less), verify 1.28 → 1.15 s, receipt 40,783,352
bytes in both, peak memory 10,232 → 10,156 MiB** [MEASURED, one run each,
laptop CPU, shared box; lane `zk60-private-block-125m` at `309d238`, log
`q28-m125-final-dense.log`, re-read by the security owner]. Nothing the prover
sends changed: the work was in how the same numbers are computed — the
lookup inverses come from a 256-entry table instead of 98.6 million
inversions (4.06 → 1.08 s), and the tables each of the 23 sub-arguments
starts from are built once and faster (6.01 → 0.59 s), with the slowest
sub-arguments roughly halved. The small accepted test block's bytes did not
move; the test filter is 319 passed, 0 failed. Because receipts are not
reproducible (fresh randomness every attempt, by an accepted privacy
condition), "same bytes" rests on ten old-against-new equality tests, the
size pins and honest proofs verifying — so an independent reviewer who did
not write the code attacked it. **Reviewed 10:40: no defect found, no
production line changed.** A complete twelve-block 125M run written by the
OLD prover is accepted by the NEW verifier (15.20 s, 476 MiB); 1,800
randomised old-against-new comparisons agree; the whole test filter passes
again on one thread (327 passed, 0 failed); no changed computation is
reachable from the verifier. The review also found four places where the
tests are thinner than the claim (one changed sum has no direct
old-against-new test, and the small shapes never take the parallel branches);
the security owner ruled that these are closed on the lane before the
integrator takes the stage (`ZK60_BLOCK125M_S28_DISPOSITION.md`). The all-zero
control run: 17.71 s, same receipt length. **What this does and does not mean
for the target:**
about 79% of the remaining 17.40 s (13.8 s: the shared masked-sumcheck loop
6.6 s, the two commitments 6.5 s, the openings 0.7 s) sits in code the
integrator owns, and the commitments are exactly what a GPU takes — but the
hash rule this profile uses does not run on the GPU path yet. This is a CPU
result at a 125M-shape block; the 5-second target is defined on the 8B
model's pass, where the best measured figure is still 58.4 s on public
inputs. It does not move that figure.

**Where the privacy of the 125M-shape block and of a twelve-block run stands
(added 2026-09-21 00:06).** Privacy is **accepted for one artifact only**, the
small test block (register D22); it was re-confirmed last night against the
integrator's newly merged code, and its checks now watch every source file on
its path. *2026-09-22: the integrator delivered a capture of a proof made by
the merged code's own binary; the gate replayed on it — every one of its 132
source pins matches the tree the acceptance names, no figure of record moved,
all ten tamper controls fire — so the acceptance now rests on the merged
tree's proofs as well as the old tree's. Same scope: that one small block, on
the CPU.* For the shaped block and a run, **nothing is accepted**, and this is
the honest state of the five-step argument:

| Step | Development sizes (two head geometries) | The 125M shape |
|---|---|---|
| The all-zero reference input proves and verifies | done | one block done; a two-block all-zero run done and captured (2026-09-21 08:57); a twelve-block all-zero run not run |
| Per commitment, the verifier's linear view discloses nothing | argument checked by an independent implementation and ruled; measured on fully dense inputs | **MEASURED for the first time (2026-09-21 11:18), on two two-block runs, dense and all-zero: the big commitment of hidden values discloses 0; the helper commitment discloses 2, checked to be exactly the public lookup identity; endpoints 0; the boundary between blocks 0 on all 6 of its reserved rows; the masking commitment 0; the whole run the sum of its parts.** 180 figures were predicted from the shape before the run and none came out unexplained. The independent tool first failed on three sub-arguments — a defect in the TOOL that only this shape could show (three of its domains are exact powers of two), now fixed with its own control |
| The gate constructs matching blinding values | **done for all ten commitments of a run, the two big ones included (2026-09-21 05:59): 4.76 million published values of four real runs reproduced from all-zero data, none differing**; **since 08:03 also the masking commitments, and one joint assignment for a whole run (4.95 million values over four runs, none differing)** | **done for two-block runs (2026-09-21 12:49, read out of the committed record by the security owner): all seven commitments on both the dense and the all-zero capture — 8.26 million published values each reproduced from all-zero data, none differing — and these per-commitment assignments are shown to be compatible with one another (no coupling between commitments touches a blinding row), so together with the masking layer they form one assignment for the whole run, 8.30 million values; about 21 minutes a run at 5.5 GB.** *Said more exactly at 14:26 after a second agent verified the first: the 8.30 million is the SUM of values each checked once in its own part, not a separate third check.* **Completed 2026-09-22 10:02: the repaired tool's full pass at 125M landed — every tamper-control family now fires at this size, and the 125M record carries the same channel table as the small shapes (28 channels: 10 constructed, 5 derived, 4 argued, 9 open). Three more small shapes that reach the 125M block's row width, head size, endpoint geometry and a layout correction went through the whole gate with nothing unexplained.** Not done: a twelve-block run (eleven internal boundaries instead of one) |
| All published values jointly do not depend on the input | accepted as a reduction; three named gaps being drafted or tested | the same |
| The hash layer and the step to the real (hashed) protocol | computed for what a proof opens; the argument for a run was checked independently and ruled on 2026-09-21 01:15 — it holds with changes, and its last step (composing the blocks of a run in sequence) is reduced to named hypotheses, not closed | for what a proof opens: 2,304 opened columns (52.9 MB) re-hashed under independently derived keys and authenticated, and all 27,828 challenges re-derived (11:18); the argument is the same document as at the development sizes |

Sized terms so far for a twelve-block 125M run [COUNTED, each recounted
independently]: the blinding sampler's bias about 2^-69.3 (decision D9); a
refusal that could depend on the input about 2^-114.8; a refusal on unlucky
challenges about 2^-58.8 per run, which costs a failed run and discloses
nothing. **What this means in plain words: the
construction has survived every attack thrown at it on the privacy side, one
of yesterday's attacks found a real completeness bug that is now fixed, and
the remaining work is argument and measurement, not redesign — but it is not
finished, and at the 125M size part of it will rest on argument plus
measurements at smaller sizes that share its geometry.**

**Latest on the fast line's private block (added 2026-09-20 07:10 by the
security owner's session):** one **complete transformer block with hidden
input, hidden output and hidden activations now proves and verifies at a real
model's shape** — the 125M class: 512 tokens, width 768, hidden 2048, 12 query
heads over 4 key-value heads — on the fast native line, on this laptop's CPU.
**Prove 26.89 s, verify from bytes 1.04 s, receipt 40,782,792 bytes, peak
memory 10.42 GiB** [MEASURED, one run, shared box, 2026-09-20 07:03; the
paper model had said 25–36 s and about 11 GiB]. What that is and is not:
**synthetic weights, one block of twelve, no GPU, and NOT a privacy claim at
this shape** — the privacy checks are owed again at every new shape and need
capture bundles that do not exist yet. Before it ran, the design was attacked
on paper (a padding hole was found and closed before anyone built it), grown
test-first through a small padded shape, and the code was attacked by an
independent reviewer who could not get a false statement accepted; the toy
block's bytes are unchanged, confirmed by verifying receipts made before the
work began. Lane `zk60-private-block-125m` (pushed, not yet integrated);
ledger `ZK60_BLOCK125M_LANE_PROGRESS.md` on that branch. **For the toy block
only, the privacy argument now has a checked core at every step**;
the three rulings from Victor were accepted at 13:45, followed by D22 below
([one page](ZK60_RULINGS_FOR_VICTOR_PRIVACY.md);
[superseded draft](ZK60_PRIVACY_STATEMENT_TOY_PROFILE_DRAFT.md)).

**First privacy acceptance on the fast line (2026-09-20 13:46, register
D22):** the **toy private block** — one block, 32 tokens, width 16, public
synthetic weights — is accepted as private by the security owner, in the model
Victor accepted the same day (D19 the hash as an ideal random function, D20
timing/memory/power out of scope with refusals kept in, D21 rejected receipts
never sent and captures counted as publishing): a verifier's view is within
about 2^-77.7 per proof of one that does not depend on the hidden data. **For
that one small artifact and nothing else** — not the 125M block below, not any
multi-block run, not real weights, not sealing in advance. It is an argument
whose every step survived one independent attack, not a proof the security
owner re-derived; [the statement](ZK60_PRIVACY_STATEMENT_TOY_PROFILE.md) lists
its residuals, the seven conditions under which it lapses and what reopens it.

**The separating hash tag is in, and the twelve-block run was re-measured
under it (added 2026-09-20 16:40):** decision D19 obliged every new shape to
hash its transcript, its column digests, its Merkle leaves and its Merkle
nodes under separate keys. That is built (register D19a; BLAKE3's keyed mode,
four public keys per shape, the verifier deriving them from the profile it
trusts; the toy block is never tagged, so the accepted bytes above do not
move), reviewed by the security owner, and authorised by the integrator as an
additive change to its files. **Under the tag, all twelve blocks at the 125M
shape prove and verify as one run: prove 393.59 s, verify by streaming
14.09 s, receipt 484,100,736 bytes (equal to the counted figure), peak memory
10.15 GiB; one block alone: prove 27.87 s, verify 1.21 s, 40,782,792 bytes**
[MEASURED, one run each, shared laptop with an agent active, CPU only, finished
16:39]. That is about 5% slower than the morning's untagged runs (370.61 s;
26.54 s) — **not attributable to the tag**: the two hashing phases moved one
up and one down, and a phase with no hashing in it moved more than either.
**A caveat on every 125M figure on this page, found 2026-09-20 17:30:** the
synthetic public weights used by all shaped tests are *diagonal* (64 on the
diagonal, zero elsewhere). Where the hidden layer is wider than the model
(2048 against 768), the upper part of the hidden layer therefore carries zeros
in every proof run so far: the wide geometry has been exercised in its sizes,
padding and checks, **not in its numbers**. No defect was found (the layout
was read line by line and one public table re-derived by arithmetic), and
proving time barely depends on the values (one phase skips zero weights; about
a second per twelve-block run [MODEL]). A dense-weights test with a
non-trivial hidden input is being added now, at the development size first.
The run now leaves its **public statement** beside its segments (written only
after the whole run verified), so a fresh process can check it. **Still no
privacy claim for anything but the toy block**, and the integrator has not yet
integrated or reproduced these runs.

**ALL TWELVE BLOCKS, ONE PROOF (added 2026-09-20 11:25):** a **private run of
all twelve transformer blocks at the 125M shape — hidden input, hidden output,
every activation and every block-to-block boundary hidden — proves and
verifies under one transcript: prove 370.6 s (6.2 minutes, about 30.9 s per
block, flat), verify 13.7 s by streaming one 40 MB segment at a time, receipt
484,100,736 bytes (equal to the counted figure to the byte), peak memory
10.15 GiB, on this laptop's CPU** [MEASURED, one run, shared box, finished
11:22]. What it is not: **synthetic weights, not a trained checkpoint; the
blocks only (no embedding, no output head — decision D13 says the blocks are
enough for the first MVP); no GPU; and no privacy claim for a run exists yet**
— the privacy checks for a multi-block run are designed and not built. Its
whole-run soundness is about 2^-97.5 by the project's accounting and its
receipt is 484 MB against a 256 KB budget; both are on Victor's page as
deviations for him to rule on.

**And blocks now chain (added 2026-09-20 10:48):** a private **run of two
blocks under one transcript** — block 1's hidden output is block 2's hidden
input, never published — proves and verifies at the same 125M shape: **prove
62.9 s, verify 2.0 s, receipt 81.1 MB in two segments** [MEASURED, one run,
shared box, CPU]. A verifier rejects a second block that was run on anything
other than the first block's output. This matters because separately finished
private proofs cannot be joined afterwards; a full model has to be one run.
Twelve blocks are counted at about 6.3 minutes of proving, 12.5 s of verifying
and 484 MB [COUNTED], with a whole-run soundness of about 2^-97.5 by the
project's accounting — and **no privacy claim exists for any run yet**; the
design, its independent check and the rulings are
[here](ZK60_PRIVATE_RUN_MULTI_BLOCK_DISPOSITION.md) (register entry D12a).
Where a private block's 26.5 s goes is measured too: one softmax check 25%,
lookup inversions 15%, the two commitments 25%, the feed-forward part 5%
([plan §5.2b](ZK60_MVP_COMPLETION_PLAN.md)).

## 1. Do we have a workable proof?

**A complete small-block experiment works. The model MVP remains open.** Today at 19:18 the
first complete transformer block (T32 tokens, width 16, FFN 16, two heads,
the real integer kernel: both RMS norms, QKV, RoPE, causal integer softmax
attention, PV, output projection, both residuals, SiLU FFN) was proven by
re-execution inside the RISC Zero zkVM and wrapped into a **785-byte Groth16
receipt** that verifies in a fresh process in 8 ms. Seven corruption
controls (wrong context, model, input, output; truncated, trailing,
tampered bytes), plus the inner receipt kind, are rejected. Inputs, outputs
and activations are hidden under the reviewed Groth16 premises;
the public artifact is the receipt plus a 144-byte policy of digests.

| Stage | Result | Label |
|---|---|---|
| inner STARK proof (succinct receipt, 223,514 bytes) | 3,743 s on the shared laptop CPU, two threads | [MEASURED, NOISY-SHARED] |
| Groth16 wrap with the extracted native prover | 197 s | [MEASURED, NOISY-SHARED] |
| independent verification | 0.008 s | [MEASURED] |

**And, at 21:34, the first proof of actual token generation:** the
two-block token model (public embedding, two complete blocks with their
hidden seam, final norm and head, greedy next token; synthetic T32 fixture
with a 32-word vocabulary, not a trained model) proven by re-execution and
wrapped to a 785-byte Groth16 receipt; independently verified, eleven
rejection controls pass, and the block-profile verifier refuses it as a
different profile. Prove 7,488 s (2 h 5 min) on the shared CPU, wrap 197 s
[MEASURED, NOISY-SHARED]. Public artifacts retained under
`results/zk60_loop_20260918/token-integration/token_public/`.

What it rests on: RISC Zero's proof system at about 97 bits conjectured
soundness (D3), the Groth16 trusted setup (D4), Groth16 receipts only (D5),
and the salted-SHA-256 endpoint profile accepted under D7 at 11:50 on
September 19. The D7 qualifiers remain explicit: salt secrecy protects the
toy answer (the model library still accepts zero/repeated salts), the image
is locally built and not independently reproduced across directories, and
timing is declared leakage; the scan and cycle check cover only the block
program. Both receipts use synthetic tiny fixtures and make no model-speed
claim. D13 makes hidden model blocks the first MVP; token generation follows.

**On the custom prover line (hashline), the first complete private block now
proves and verifies (2026-09-19, 05:14), and at 06:25 the security owner
accepted it as an experimental component — still not a privacy acceptance.**
The same kind of block as above (T32 tokens, width 16, two heads,
feed-forward width 16: attention, both norms, both residuals, the SiLU
feed-forward) in **one native proof with no seam**, inputs, outputs and
activations hidden, weights public, on a public synthetic fixture. On the
security owner's own run: **prove 0.095 s, verify 0.043 s in a fresh process
from bytes only, receipt 2,816,472 bytes** — exactly the size the design
derived before any code existed [MEASURED, NOISY-SHARED, diagnostic only]; 38
unit, parity and tamper tests and 4 integration tests pass; the witness
matches the integer reference kernel element for element on 1,200 cases,
refusing exactly where the kernel refuses; nine tampers, including the one
that would let a prover choose the block's output, are rejected by the
verifier. For scale: the zkVM line needed 3,743 s for the same block. Since
then (05:49) **the project's leak-checking tools have been run on the real
source** (46 of 46 counts equal the design, nothing disclosed in any opening
group or at either endpoint, all 22 negative controls fire, zero differences
from the paper run) and **an independent adversarial code review found no
blocking problem** (every hidden plane is pinned, every relation equals the
reference kernel's, it could not construct a false proof the verifier
accepts); its two small defects and its missing tamper tests were closed by
06:19, every new tamper caught exactly where it was predicted, including the
one case where only a single lookup stands between a prover and a free hidden
value; 46 unit and 4 integration tests pass on the security owner's own run,
and a receipt made before those fixes still verifies after them. **What it
is not:** not a privacy acceptance (those tools check a
linear-algebra model that leaves out several channels; the caller-fixed-root
obligation D8/D11 is open; the joint-view gate on captured receipts is
unmet), not a trained model, and **not a speed result for 8B**: the form
built here deliberately gives up the GPU feed-forward prover, and a tenth of
a second at width 16 says nothing about width 4096. Branch
`zk60-private-block`; record
`results/zk60_private_block_evidence/README.md` there.

**Codex integration, 2026-09-19:** both native profiles are now in the main
worktree. The integrated block produces a fresh 2,816,472-byte receipt in
0.062–0.064 s and verifies it independently in 0.020–0.021 s on this shared
CPU with two threads; the original lane receipt verifies too [MEASURED,
NOISY-SHARED, tiny fixture only]. Fifty-seven combined Rust tests, 29
block-inventory tests, the full Python regression (1,098 tests, 61 skipped)
and native freeze pass. Attention's repeated byte-lookup inversions are
removed and its fixture scale labels corrected. Whole-proof privacy and
model-scale speed remain open. [Integration and evidence](ZK60_ATTENTION_INTEGRATION_20260919.md).

**Verifier captures now retained:** source-pinned recordings from two fresh
attention receipts and two complete-block receipts reproduce exactly in fresh
verifier processes. They include all 18/23 slots, M and PCS openings, pads,
sampled columns, salts and paths. Forty-nine native unit tests and 13 Python
capture controls pass; both pre-instrumentation receipts still verify.
[Capture format and review boundary](ZK60_NATIVE_CAPTURE.md),
[validation manifest](../../results/zk60_native_captures_20260919/validation.json).
This closes the capture-writer prerequisite. The complete joint-view analysis
and D8/D11 still need acceptance; no new proving-speed claim follows.

**GPU optimization validated:** Claude's compact intermediate for non-hiding
openings and the parallel host column split pass the integration checks:
261 CPU Rust tests, four configurations of 34 required-device commitment
tests, 12 device cache tests, all twelve frozen CPU/GPU/forced-chunked proof
digests, and native freeze. The full Python run covered 1,140 tests (61
skipped); its single lock-related error is resolved by a test-isolation fix
and a passing 18-test targeted rerun.
The local four-kernel gain is 1.162× [MEASURED]; its full-pass saving is only
0.8–1.8 seconds [COUNTED]. No new 8B proof clock is claimed. The next host
work targets redundant integer conversion/packing and repeated reductions.
[Review and retained evidence](ZK60_FSP_L9_INTEGRATION_20260919.md).

What else exists on that line: a private feed-forward component at the same tiny shape
with a bounded privacy diagnostic (whole-proof privacy not accepted, D8
open); public-IO proofs of real 8B feed-forward stacks (below); the private
attention schedule designed and rank-checked, and its native implementation
built and reviewed at the tiny geometry as an experimental component (§3
item 1).

## 2. How slow are we against the target?

The active target is **five seconds for an 8B model on better GPU hardware**,
reaffirmed by Victor on 2026-09-22. The older written 5–15-second FFN-only
contract remains a historical component benchmark; it does not establish
completion of the private model pass including attention. Keep the 512-token
prefill workload and the p95-over-20-warm-runs, idle-machine reporting rules.
The custom prover is the speed path; the 125M CPU clocks are development data.

| What was proven | Where | Time | Distance from 5 s | Label |
|---|---|---|---|---|
| Mistral-7B, all 32 feed-forward layers × 512 tokens, **public IO**, lane AL after the host fix | laptop RTX 4070 (55–70 W) | prove **58.40 s**, verify 1.08 s, proof 1.23 GB | **11.7× slower** than 5 s, 3.9× slower than 15 s, for the proving phase | [MEASURED, NOISY-SHARED, 2026-09-04] |
| same, CPU only | laptop, 8 threads | 510 s | 100× | [MEASURED] |
| the same stack **with attention and accepted P1 privacy** | not yet built at 8B | no measurement | unknown | earlier ~290 s estimate withdrawn: the +4.7% CPU surcharge does not transfer to the GPU, and the legacy privacy profile has disclosure defects |
| one tiny complete block in the zkVM (above) | laptop CPU | 3,743 s for roughly 10^5 multiply-accumulates; the 8B FFN pass is 2.9 × 10^12 | not a performance path at all: the zkVM line is the privacy demonstrator, never the product prover (D2) | [MEASURED; COUNTED] |

The newer lane-AL result supersedes the earlier 95-second lane-AH headline.
Its retained log also records **134.50 s witness load+chain** and **196.79 s
total wall**; 58.40 s is the proving phase, not complete request readiness.
[Original measurement](../../results/hashline_convert_r3.log).

**Activation-side arithmetic (weight-commit phase subtracted).** The table
divides 512 tokens by the measured prove time minus its weight-commit phase
(Mistral-7B, 32 FFN layers, `results/hashline_zk_8b_gpu.md` §2). This is an
optimistic accounting boundary, not a measured warm-cache rate: `--wcache`
still pays validation, upload and encoding work. Its warm-path performance
must be measured on the current implementation.

| run | prove | of which commit W | activation side | **tokens/s, W phase subtracted** | with W |
|---|---:|---:|---:|---:|---:|
| public IO, laptop GPU (lane AL, 2026-09-04, host fix, cold W cache) | 58.40 s | 19.823 s | 38.577 s | **13.3** | 8.8 |
| public IO, laptop GPU (lane AH, 2026-09-04) | 95.5 s | 41.9 s | 53.5 s | **9.6** | 5.4 |
| legacy `--zk`, laptop GPU (lane AI, same day; card 8.2 GB, run paged at 8.6 GB; privacy claim subsequently invalidated) | 265.3 s | 54.2 s | 211.2 s | **2.4** | 1.9 |
| public IO, laptop CPU (2026-09-03) | 510 s | 225 s | 285 s | **1.8** | 1.0 |

Labels: [MEASURED, NOISY-SHARED] per row; the division is [COUNTED]. These
are prefill rates (512 tokens per proof), FFN-only. The legacy `--zk` row was
starved of video memory (55% of its time is one paging-bound phase). It is
not a measurement of the repaired private profile or of a larger card.
The legacy profile's known disclosure defects remain decisive regardless
of those timings. One-token-at-a-time decode is far worse per
token: a single layer at 16 tokens cost 72% of the same layer at 256 on
the CPU, so per-token cost at small batches is 10–20× the prefill figure
[COUNTED from one measurement]; no decode run exists at 8B.

A bigger GPU (a 5090 or an H100) has not been measured. The project's own
throughput model says the built design does not reach the goal on any GPU
without the recorded design changes (preprocessed weights, the two-tier
opening; `START_HERE.md` §2 and §5), and that those changes were counted,
not built. Honest summary: **on today's laptop the public-IO 8B proof is
one to two orders of magnitude off the target, and the private version of
it does not exist yet.**

## 3. What blocks a private, model-scale MVP at speed, and what is being done

1. **Private attention on the custom line: implemented and reviewed at the
   tiny geometry (2026-09-18, late evening).** A delegated Fable lane built
   the native masked prover and verifier to the construction; the security
   owner's lane compiled it with zero fixes, ran its 16 tests, proved and
   fresh-process-verified the example (0.09 s, 2.2 MB receipt), regenerated
   the rank and CFS checks on the layout it actually declares (nothing
   disclosed; H residual = the public identity; all 18 slots and 5 host
   groups pass) and re-derived the arithmetic bounds (all hold). Accepted as
   an experimental component (`ZK60_PRIVATE_ATTENTION_NATIVE_DISPOSITION.md`
   on branch `zk60-attention-compile`). Using one 8-bit range table instead
   of the 65,536-entry ones cut the commitments to 306 and 290 rows. Still
   missing for this attention-only profile: the second norm, the FFN and
   residual 2; the complete-block profile above now includes them.
   The 2026-09-19 gap inventory
   (`ZK60_PRIVATE_BLOCK_COMPOSITION_GAPS.md` on `zk60-attention-compile`)
   sorted fifteen gaps into engineering and construction work under D12.
   The capture writer, fixture scale-tag fix and tiny-block kernel parity
   are now implemented and tested; model-width construction remains open.
2. **Whole-proof privacy acceptance on the custom line.** The joint-view
   tools exist and real native captures are retained. Their joint-view
   adapters and the caller-fixed-root obligation are still open (D8/D11).
3. **Speed.** The gap above is a design gap, not a tuning gap.
4. **Current lanes:** Fable's GPU kernels and host staging port, then a
   separately labelled repaired-mask cost probe; Codex's capture review
   handoff and remaining zkVM hardening/ceremony integration. No model-width
   GPU measurement window is reserved. The two-block token-model proof landed
   (§1). **Earlier restart/build history:** the
   laptop restarted at 01:04 on 2026-09-19**: git and the retained receipts
   are intact and everything was already pushed, but the `/tmp` scratch area
   is gone, which killed the queued ceremony checker before it ran (Codex
   relaunches it) and erased the uncommitted Opus phase-diagnostics work
   (restarts from zero). **Both Groth16 receipts were re-verified in fresh
   processes after the restart** (block and token; each profile's verifier
   refuses the other's receipt) [MEASURED]. Three read-only reviews by the
   security owner's Opus agents landed by 01:30: the token model's source
   review (no code defect; the retained build-source record is stale for
   the wrapper; hardening items for Codex), the response to Codex's review
   of the hardening lane (all six of its findings correct, four already
   fixed soundly, one new low-severity gap), and the inventory of what a
   complete private block on the custom line still needs. That inventory's
   central finding is now **ruling D12**: the two existing components may
   not be joined by sharing one hidden commitment between two proofs,
   because two openings at that geometry reveal all 512 hidden words; a
   block is one proof under one transcript, and the second norm must prove
   its output's range because the feed-forward prover does not. **At 03:01
   the design of the complete private block was accepted as the design to
   build** (`ZK60_PRIVATE_BLOCK_CONSTRUCTION_DISPOSITION.md` on
   `zk60-attention-compile`): the attention construction is grown into the
   whole block, so there is no seam to prove; drafted and independently
   checked by delegated agents, with the project's rank and slot tools run on
   a paper description of the whole block (nothing disclosed; every negative
   control fires) [COUNTED on a description, not measured on code]; 22
   corrections made binding, including two that would have been soundness
   holes (a block whose output the prover could choose, and an activation
   table whose value range nothing enforced). This is a design, not a privacy
   acceptance and not a speed result. Expected size at the tiny shape: a
   2.8 MB receipt. Building started on `zk60-private-block` at 04:07;
   the initial witness-only checkpoint was subsequently superseded by the
   complete proof and its integration described in §1. Earlier items:
   the security owner's source review of `zkvm-block/` with eight hardening
   items (`ZK60_ZKVM_BLOCK_SOURCE_REVIEW_FABLE.md` on branch
   `zk60-mvp-fable`), now implemented and verified on branch
   `zk60-zkvm-hardening` for Codex to integrate (secret-scan stage,
   environment refusal and scrub, cycle reporting, constant-cycle gate with a
   real executor run, tool-check command, work-directory cleanup,
   claim-shape regressions). Codex reviewed that delivery (no acceptance
   defect in the Rust; one runner incompatibility with the token profile and
   several wording and test-scope corrections, which Codex is applying). The
   ceremony checker never ran (see the restart above); no ceremony-check
   success is claimed. **Rulings made by Victor on 2026-09-19 (11:50):** D7
   accepted — the zkVM line's two receipts may now be called private under
   D3, D4, D5 and D7, with three written qualifiers (salt secrecy carries the
   32-value toy answer; the program's identity depends on its build
   directory; timing is declared leakage); D9 accepted as stated (a privacy
   residual of about 2^-72); D10 declined (the compact proof format cannot
   run privately); new D13, the hidden blocks are enough for the first MVP
   and generating a word is the next milestone; new D14, a costed memo for
   the one design lever that could take a 5090 below 10 s, paper only; and
   the RTX 5090 install is a go (date, machine and RAM still to be named).
   **Speed, honestly, as of 13:42 (`ZK60_FIVE_SECOND_PLAN.md`, three dated
   corrections at the top of its §5):** 5 s is outside every assumption
   recorded in this repository, and the costed memo commissioned under D14
   confirms the one design lever left cannot reach it (best case on a 5090
   about 7–9 s, for 15–25 lane-weeks and a 60% larger proof). The plan's three
   software steps were built today, all byte-identical and green: together
   they are worth **about 4–5 s of the 58.40 s [COUNTED]**, not the 24 s first
   projected — every counted step shrank three- to seven-fold when measured.
   On this laptop the public 8B pass is a roughly 55 s pass. Whether the 5090
   reaches 15 s is **open** until its first measurement; 16–19 s of today's
   pass is host work the card does not touch.
   **The most valuable missing number now exists, at the small shape:** the
   *repaired* private mask scheme ran for the first time above the tiny shape
   (45 runs, zero refusals, 12 layers × 512 tokens at the 125M shape, three
   arms on one binary, endpoints public in all three — a cost probe, not a
   privacy result): **repaired ÷ legacy = 1.06 on the GPU binary and 1.00 on
   the CPU binary; repaired ÷ public = 2.05 on the GPU** [MEASURED]; proof
   bytes +0.75% over legacy; by row count +1.8% at Mistral width and about
   +1.6% on a Mistral layer [COUNTED, not run]. So the repaired masks cost
   what the legacy ones did, within a few per cent; what is still unmeasured
   is the other half of P1, the hidden endpoints at model width.
   **Privacy path, same day:** on Codex's retained captures of two block and
   two attention receipts, a gate that replays the transcript at the
   receipts' real challenges finds nothing determined about the hidden data
   beyond public identities, with the 256 sampled columns included, and every
   sabotage control caught — evidence on a linear model of four receipts,
   **not** a privacy acceptance (D8/D11 open); and the private block's norm
   was shown free of the soundness gap the older prover has, with the
   precondition for widening it recorded as D16.
5. **A reproducibility fact to settle before any approval record:** the
   guest image ID depends on the build directory (the ELF embeds one
   absolute source path and the non-Docker build applies no path remap), so
   the approved ID `8d74aab3…98d9` is reproducible only from the main
   checkout's path or from a reproducible Docker build.

## 4. Where the evidence is

Public artifacts of today's Groth16 receipt are retained under
`results/zk60_loop_20260918/block-integration/groth16_public/` (policy,
receipt, public model, stage records, hashes); the `/tmp` originals do not
survive a reboot and a new randomized receipt would have different bytes. The loop's own
record is `ZK60_MVP_LOOP_20260918.md`.

## 2026-09-29 (PDT): VC readiness snapshot for Tech Week SF

Added 17:40 PDT on 2026-09-29 (00:40 UTC on 09-30) by the Lane D agent.
This section repeats the facts in
[`results/zk60_vc_readiness_20260929/READINESS.md`](../../results/zk60_vc_readiness_20260929/READINESS.md).
That note also has a one-page `DEMO_SCRIPT.md`, the projection arithmetic
(`extrapolate.py` → `extrapolation.json`) and a light rehearsal script. No
heavy proof ran. Nothing in this section is a new ruling or privacy
acceptance.

**What can be shown truthfully now.** Everything below was re-checked on the
laptop CPU between 17:18 and 17:24 PDT (`rehearsal-20260930T002413Z.json`):
- Both retained 785-byte Groth16 receipts verify in fresh processes, with
  exit 0 in about 0.08 s each including the wrapper. One is the tiny complete
  block; the other is the synthetic two-block token model.
- A one-bit-flipped copy of the block receipt is refused.
- The toy native private block (the D22 profile) proves in 0.10-0.11 s.
  A fresh process verifies it in 0.05-0.06 s and refuses three corrupted
  copies [MEASURED].

Before quoting D22 on stage, confirm that the 2026-09-20 example binary
matches D22's source pins. The integrator's browser demo
(`ZK60_TECHWEEK_DEMO.md`) is the stage vehicle for these checks.

The scale evidence is unchanged:
- One synthetic 125M-geometry block: 17.13 s GPU-arm proving versus 32.95 s
  on a 2-thread CPU.
- The twelve-block 125M-geometry run: 397.71 s on CPU, or **1.29 proved
  tokens/s**. This is the only measured complete-stack rate: synthetic
  weights, CPU, one run.
- A twelve-block GPU attempt today (`results/zk60_mvp_20260929/baseline-stack-gpu/`)
  failed at harness setup because its receipt directory was missing. It was
  not a proof failure.

**Projection, labelled [MODEL].** Each measured phase of the 125M A/B is
scaled by its own layout domain. This gives 2.18x per block at the TinyLlama
1B geometry and 3.09x at the Llama-3-8B block geometry. Plain row counts give
2.25x and 3.25x. Prove-only rates for 512 tokens:

| Configuration | Stack prove | Proved tokens/s |
|---|---:|---:|
| 1B, 22 blocks, laptop GPU arm | 822 s | **0.62** |
| 8B, 32 blocks, laptop GPU arm (does not fit this laptop) | 1,692 s | **0.30** |
| 8B, RTX 5090 with today's code | — | 0.62-1.23 |
| 8B, 5090 with every proof sumcheck on the GPU (not built) | — | 5.1-12.6 |
| 1B, 5090 with every proof sumcheck on the GPU (not built) | — | 10.5-26.1 |

The witness build must also move to the GPU. At 8B it is 27-285 s per block
on CPU [MODEL band]. The gap to 50 at 8B is 165x on the laptop today and
4-10x in the best counted scenario. **No recorded assumption reaches 50
proved tokens/s for a private 8B stack.** Larger workloads amortize under 1%
today, because per-token proof work dominates.

**Claims to avoid** are listed in READINESS §3. In short: no full or trained
model has been proved privately; no private rate exists at 1B or 8B; D22
covers only the CPU toy; the 97-bit, Groth16-setup and unreproduced-image
qualifiers travel with the 785-byte receipts; the fast line's receipts are
about 41 MB per 125M block; there are no 5090 numbers; and there has been no
third-party audit.

**Next measurements** (the READINESS §4 week plan, aligned with the
integrator's gates):
1. Retry the twelve-block 125M GPU run.
2. One synthetic TinyLlama-geometry block on the 4070. It is projected at
   37 s, and the counted floors are about 3.7 GiB VRAM and 6.9 GiB host.
3. The 22-block 1B-geometry run.
4. Laptop thread scaling.
5. The first 5090 A/B, only if Linux is installed by about 10-02.

The trained TinyLlama block is the integrator's 10-02 stretch gate.


### A2 score candidate and app review — 2026-11-12T07:59:46.596581+00:00

[MEASURED, correctness only, shared Mac] The exact Astra score candidate now has3 complete classifier proofs through the current app-pinned A28 binary,84segments, fresh verification/owner checks/whole-item labels, and altered-content/corrupted-proof rejection. This closes the current-native public-fixture proof gap; it does not approve model adoption, privacy or production, or measure a new throughput result. The current app passes222 Python tests and3 frontend suites; actual browser/visual review covers pending privacy and historical published receipts, including correct recorded verifier pins and390px mobile layout. All jobs are terminal. Evidence: `results/zk60_astra_20261026/current_app_20261112/AUDIT.json`; remaining A1-A8 work: sibling `HANDOFF.json`.
