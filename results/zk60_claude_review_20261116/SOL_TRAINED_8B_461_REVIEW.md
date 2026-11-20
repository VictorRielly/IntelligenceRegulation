# Second reading: trained Llama-3-8B native proof (461 / report 467)

Reviewer: Claude (read-only). Written 2026-11-18 15:28 UTC (python3 clock). Paths are under `results/zk60_sol_20261105_w16r3/b3/` unless noted. Labels: [R] recomputed by me, [F] read from a retained file, [T] taken from the report only.

## Verdict

The retained evidence supports the narrow claim. One native proof of one calibration prompt, 32 blocks, on export 459, was produced and then accepted by a separate verifier process. Every pin I could recompute matched. The report is accurate about the proof but stale and incomplete about quality: report 467 says the D32 evaluation "is in progress", yet 465 finished as D32_REFUSED. The proved export failed quality.

## What the proof covers

- One next token (selected token 311) for one 128-token prompt, on export 459. [F] 460 `result.head.selected_token`; the owner `next_token` file equals it [R].
- The prompt is sequence 0 of the archived 30-sequence calibration set. [F] `check_8b_token_chain458.py` (`SEQUENCE = 0`, `calibration30.npz`). This is in-sample for the calibration.
- All 32 blocks, the embedding stage and the head and argmax stage, in one run. [F] `statement.json` `blocks`, `scope`.
- Model: the integer export 459, which carries the trained weights after rounding and a score-scale change at layers 1, 2 and 31. [F] 459 `revised_layers`.
- A CPU build, GPU off. [F] `statement.json` `prover_reported.backend`.

## What it does not cover

- Quality: 465 is `D32_REFUSED`, `D32_pass` false, FineWeb ratio 1.137 against the 1.02 limit on 24 of 296 sequences, one refusal. [F] The refused site was gate word -2071 (violations 1) in the last progress row [R].
- Privacy: `statement.json` `scope` ends "NO privacy acceptance (the rank / CFS gates on the token stages are owed)". The variant is "public-row". Despite "private" in the profile name, no zero-knowledge claim is supported. The report says privacy is open, which is right.
- Production: development profile, not Lean-gated (D63).
- Any other prompt, any held-out text, any later token.
- The link from the original Llama-3-8B checkpoint to export 459 is not part of the proof (the verifier reads the export's arrays). Not checked by me.
- Export 474 (the refit) has no native proof. No native run directory for it exists beside `d78-trained-8b-native461`. [F]

The D32 pass in 476 says nothing about the proved export. 476's `profile_sha256` is d4a27934..., not a9add24a... (459). [F] It is evidence about 474 only, and 477 itself says the refit's native checks "remain open".

## Headline claims

| Claim | Evidence path | Checked how | Result |
|---|---|---|---|
| W16R3, T128 | `attempt-000/receipt/statement/statement.json` `run_profile`, `parameter_line` | read | holds |
| 32 blocks | same, `blocks`; `prove.log` `parity_layers` | read | holds |
| One calibration sequence | `check_8b_token_chain458.py`, 460 `prompt_sha256` | read | holds; in-sample |
| 34 segments, 764,068,112 bytes | `segments.json` | summed file sizes | holds [R] |
| 95-bit min, 97-bit floor | `verify.log` `min_bits`, `whole_run_floor_bits` | read | holds [F] |
| Fresh verifier accepted | `verify.log` `published_by: this verifier` | read | holds [F] |
| Two owner checks | `input-owner.log`, `owner.log` | read; owner file vs 460 | holds, see finding 3 |
| 129 head checks, 16,777,216 score words in [-118, 61] | 460 layers | summed words, min, max | holds [R]; 0 violations |
| Prove 468.474 s, verify 33.660 s | `prove.log`, `verify.log` | read | holds [F]; see finding 4 |

## Pins recomputed

- All 62 pins in the 466 audit: 62 match, none missing [R]. These include the audit script, the binary, the six guard files, the logs, `statement.json`, `segments.json` and all 34 segments.
- All 34 segment hashes and sizes in `segments.json`: 34 match; total 764,068,112 bytes [R].
- 5,224 pins in the 461 spec (source tree, export arrays, tables): 5,224 match [R].
- Not recomputed: the local owner directory contents beyond existence and size (input.dec and output.dec are 90,144 bytes each, mode 0600 [R]); the archived calibration `.npz`; the 129 head checks themselves.

## Verifier and guard rows

- The six guard files match the rows in `results/zk60_resource_guard/history.jsonl` field for field [R]. Order: build, profile, prove, verify, input-owner, owner. All exit 0, none killed. Run ids: db8d58a7e418, 5efe0cee5a28, bad4f7477857, 2c9236853b7b, ef0cebfbd2c9, f3f2314521c5.
- Times (UTC end): prove 07:18:26 after 612.3 s; verify 07:19:35 after 68.8 s. Verify started as prove ended, so it ran after the prover finished [R from `ts_end` minus wall time].
- The verifier was a different guarded process, a separate `verify` command of the same binary, run on the files on disk. Its own statement says it was written "after its fresh-process verification of the run directory" [F].
- It checked the segments against the statement, the chaining and the public tables (via the verifier's published statement). I could not see inside the Rust verifier. I read only its output. Source review was not done.
- Not checked by the verifier: that the weights are the real Llama-3-8B; the GPU claim ("not verified by the proof", per the statement itself); privacy.

## Findings, by severity

1. **High: the proved export failed quality.** The report says evaluation is "in progress". 465 is final and refused (file times: 467 at 23:29, 465 at 23:49 on Nov 17). Settle by updating 467 and saying plainly that 459 failed D32.
2. **High: the proof is in-sample and one token.** Sequence 0 of the calibration set was used. A pass here says the arithmetic is consistent, not that the model is accurate. Settle by a proof of a held-out prompt on a D32-passing export (474 or later).
3. **Medium: owner checks are thin.** The logs only say "checked against the published statement". The audit confirms files exist and next_token matches 460. It does not compare input.dec to the archived prompt. I did not either, since I do not know the format and did not open the private data.
4. **Medium: timing context.** 468.474 s is the prover's own figure; its total is 602.2 s and guard wall 612.3 s [F]. Threads were pinned to one (`RAYON_NUM_THREADS=1`, run script) [F]. The report omits the 602 s and the single thread. The 95-bit minimum is the D27 tier, 97 bits is the whole-run floor.
5. **Low: the "same token as the legacy path" check is weak.** The legacy run (458) is a different, older profile (235facaf...) and one token out of 128,256. Both chose 311; margins differ (94,149,094 against 234,044,515) [F].
6. **Low: the refit's D32 has overlap.** 477 discloses calibration overlap at perplexity indices 22, 62 and 72, so the 476 pass is not fully held-out.

## Not checked

The Rust prover and verifier source; whether privacy works; the Llama-to-export derivation; the prompt contents; the float-reference numbers; the 129 head checks; any GPU behaviour.

## Coordinator note (Claude, co-coordinator, 2026-11-18 15:29 UTC)

- **Independent spot check of this review.** I re-hashed the 34 segments myself against the verifier-written segments.json: 34 of 34 match, 764,068,112 bytes. I read the verify.log fields (min_bits 95, whole_run_floor_bits 97, published_by this verifier), the statement's prover_reported backend (GPU off), the run script's single-thread setting, and the fields of 465 (D32_REFUSED, FineWeb ratio 1.137 on 24 completed sequences, one refusal, profile a9add24a...). All agree with what is written above. I did not repeat the 62 audit pins or the 5,224 specification pins.
- **Times in finding 1 are local (PST).** In UTC, report 467 was written at 07:29 on 2026-11-18 and 465 finished at 07:49.
- **Fairness to the author on finding 1.** Report 467 predates the D32 result by twenty minutes. Sol stated the failure plainly in D78_TRAINED_8B_CHANNEL_REFIT_477.md (08:05 UTC) and in the coordination file, so nothing was withheld; what is asked for is a one-line pointer from 467 to the result, since 467 is the file a reader opens first.
- **Finding 2 is the one that sets the next step.** The proof that would count is a held-out prompt on an export that passes D32.
