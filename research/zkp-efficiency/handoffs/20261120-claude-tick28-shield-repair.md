# Research handoff: re-pairing the Shieldstral shares of ticks 11 to 27 to the app's profile, W16R2_SHIELD (2026-11-20, claude-tick 28, queue item 47)

From Claude, the background researcher. Triage material, not a work order.

**Question.** Ticks 11, 15, 16, 20, 21, 22, 26 and 27 quote "Shieldstral" shares taken from the R13_SHIELD block (block GPU 174.25 ms). The app is W16R2 (since 2026-11-13). Which shares can be re-derived for W16R2_SHIELD_T128_H24 by reading, and which need a test? Since tick 27 the coordinator measured the block (`results/zk60_w16r2_shield_block_20261120/README.md`: tests B1 and S1 done), so this tick re-pairs every share from those records.

**What was read and how.** Local only, no web (a re-pairing item). In full: that README and its `summary.json`; the four externalized GPU traces (gzip TSV, 199 lines each: W16R2_SHIELD twice, the 8B control, the R13_SHIELD control), read by my script; ticks 11, 22, 27 (full), ticks 15, 21 (the Shieldstral lines); `REVIEW.json` of the 2026-11-13 benchmark (whole); the slot breakdown README sections 2.2 to 2.3 (by grep). Script `20261120-claude-tick28-shield-repair.py` (standard library; reads the four traces; under a second). Labels: MEASURED (record), COUNTED, DERIVED (script), ASSUMED.

## 0. Headline

1. **The app's block has the 8B block's costs, so the 8B figures carry over, with three small differences that the traces show.** Commit A + H is the same work: diag split inverse / forward / hash per block at W16R2_SHIELD 4.02+4.13 / 6.85+7.12 / 1.66+1.73 ms against 3.95+4.12 / 6.83+7.13 / 1.65+1.72 at the 8B control (MEASURED, trace diag records; f = 0.867 in both, 0.855 at R13). Slots 15, 16, 17, 18 and 19 agree to under 0.1 ms. The differences are D-domain padding: slot 14 has 37 tables against 36 (+1.57 ms), and slots 0 and 1 have 3 tables against 2 (+0.34 and +0.40 ms). The extra table is the gate table that exists only when a domain pads (`slot_ir.rs:693-699`, tick 11 section 2); that the table counts move exactly where tick 11 predicted is a small confirmation of its model. The measured excess of the D pad over the 8B block is +2.31 ms of the +2.27 ms slot-sum difference (DERIVED, script).
2. **Re-paired shares (section 1) change no decision.** Two sit at the 5% line on cadence at full pass-through: the padded-pair skip (3.3 to 6.1%, mid 4.7%) and H117b (4.8%). Nothing is scheduled by this tick.
3. **A flag from tick 27 survives and gets sharper:** block GPU is 56% of the app's cadence (94.7 ms against 168.5 ms per block, 64% with checks deferred) against 78% at the 8B harness. Every cadence figure below is at full pass-through, so with this much non-GPU time they are ceilings that I expect to realise less than the 8B ones. The cause is not in the retained records (section 3).

## 1. The re-pairing, share by share

Block GPU at W16R2_SHIELD: **94.06 and 98.98 ms** (two arms; pooled 94.7), commit A + H 28.72 and 32.60 (pooled 28.95), all slots 65.67 [MEASURED, coordinator]. Cadence 4.381 s per T128 request, 26 blocks [MEASURED, REVIEW.json: 105.14 s per 24; binary of 2026-11-12]. "% cad" = ms x 26 / 4,381, at full pass-through (tick 22 rule (a)).

| Share (source tick) | Old (R13_SHIELD) | At W16R2_SHIELD | Status | % cad |
|---|---|---|---|---|
| Block GPU (21, 22) | 174.25 ms | 94.06 / 98.98 ms | MEASURED | |
| Commit A + H share (21) | 43.7% | 30.5% / 32.9% (pooled 30.6%) | MEASURED | |
| NTT share f (21) | 0.855 | 0.867 (= 8B) | MEASURED (diag split) | |
| Free-NTT ceiling (21) | x1.60 | x1.36 block (25.1 ms) | DERIVED | 14.9 |
| Traffic-floor kernel (21) | x1.25 | x1.14 block (11.6 ms) | DERIVED; floor 10.5 ms assumed equal to the 8B's (same rows and length) | 6.9 |
| H117b, drop the inverse (21) | x1.09, 14.5 ms | x1.09, 8.16 ms | MEASURED diag, DERIVED share | 4.8 |
| Padded-pair skip, slots 14 + 18 (11, 22) | 5.7 to 10.5% | 5.5 to 10.2 ms = 5.8 to 10.8% | DERIVED, phase split ASSUMED from the 8B arm B | 3.3 to 6.1 |
| Tail, rounds 5 on (16, 22) | 5.1 / 8.7 / 16.1% | 5.9 / 13.5 / 25.6% (5.5 / 12.7 / 24.0 ms) | the 8B ms carried over, ASSUMED | 7.5 central, if free (hiding unmeasured at this profile) |
| K5 mixed split (15, 22) | 3.36% (5.85 ms) | about 1.74% (1.65 ms, the 8B bench figure) | DERIVED by substitution | 1.0 |
| Plain two-table slots 20 to 22 (20) | 1.12% batched | 2.72 ms = 2.87% (8B control 2.83%) | MEASURED slot medians; unbatched not measured | 1.6 |
| Padded commit rows (26, 27) | 7.5 to 8.6 ms | 26.96% of 28.95 ms = 7.8 ms | the coordinator's figure, accepted | 4.6 |
| Pad rule and gate table (H165, 26) | not sized at Shield | at most the measured D-pad excess, 2.31 ms (slot 14 +1.57, slots 0 and 1 +0.75) | MEASURED difference, an upper bound | at most 1.4 |

How the padded-pair skip was re-derived (tick 11's method, its inputs swapped): slot 18 has the same tables, cube (2^21) and time (21.28 against 21.34 ms) at both W16R2 profiles, so the 8B arm B phases (table build 1.70, round 0 6.38, rounds 1 to 4 9.02 ms) apply; the F pad is 0.4375, not 0.125: 4.04 to 7.48 ms. Slot 14 has the 2^19 cube with the D pad 0.25 and the 8B phases scaled by 15.52/13.96: 1.48 to 2.75 ms. Slots 0 and 1 (D-cube row sums, a gate table too) were not counted in tick 11 and are not here: up to about 0.4 ms each if their pairs also vanish on padding, unread (ASSUMED). The lower end keeps tick 11's 0.6 realised fraction.

**What still needs a test, and what does not.**
- **No test needed to retire the R13 figures:** block GPU, commit share, f, H117b, G1, K5 and the tail are re-derived above from measured diag and slot medians; the old values should be labelled "R13_SHIELD" wherever they remain.
- **Needs a test:** (a) the arm B phase split of slots 14 and 18 at W16R2_SHIELD (the padded-pair skip's phase assumption; **pass:** slot 18 rounds 0 to 4 within 5% of 8B's 15.4 ms, slot 14 within 12% of 9.9 ms x 1.11; a kernel lane P2 would then be measured against 5.5 ms); (b) the unbatched arms for tick 17's gap and tick 14's traffic caps at this profile (not re-paired; carried values would be the 8B's, 12.4% equal-round gap); (c) plane lists (P2c'): the commit records give **A 2,504 + H 2,606 = 5,110 rows at both W16R2 profiles and A 4,577 + H 4,390 = 8,967 at R13_SHIELD**, equal to the 8B lists' totals (MEASURED), which turns the equal-row-total assumption of tick 26 into a measurement of totals; per-domain plane counts stay ASSUMED. The 7-row difference to tick 26's 5,103 is not explained here (rows the record counts and the plane list does not; unread).

## 2. What this means for the Shieldstral figures in the open lists

- Ticks 11, 12, 21, 22 and 26 quoted "5.7 to 10.5%", "43.7%", "x1.60", "tail 6.1%" and "K5 3.36%". The first now stands at the app's profile by accident of the arithmetic (the larger padded fraction offsets the smaller block); the others move to the table above. Label every earlier figure "R13_SHIELD".
- **Ranking at the app's profile, cadence at full pass-through, largest first:** free NTT 14.9% (not a project: dense GEMM was dropped, tick 21), the traffic-floor NTT kernel 6.9%, padded-pair skip 3.3 to 6.1%, H117b 4.8% (the owner's deferred ruling, DEFERRED.md), padded commit 4.6% (new profile), plain two-table 1.6%, pad rule 1.4%, K5 1.0%. The tail's 7.5% is a free-tail ceiling against an unmeasured hiding ratio; at 8B two thirds of it was hidden (tick 16), so expect x1.01 to x1.03 only if Shieldstral's stream hides it likewise.
- Under tick 22's rule (a) and the 5% rule, only the traffic-floor kernel and the padded-pair skip's upper end are above the line, and both are ceilings that need a kernel at its floor or a full skip. This is no change to "no kernel idea above a few percent" in the 8B case; at the app's profile it is "a few percent to 7%".

## 3. The 56% against 78% (reading only; not explained)

Per block, the app's stream takes 168.5 ms (147.7 ms proof only) and the 8B harness 117.0 ms, with the same 91 to 95 ms of block GPU. The app figure is from 2026-11-13 (before A33 and A35), includes verification, and is the app path, not the harness; `REVIEW.json` limits say the two arms differ in binaries and calibrated profiles. A single post (3 requests) is 26.70 s, 8.9 s per request, so the stream overlaps about 2.0x. Nothing retained splits the 168.5 ms into sealing, prove call and checks for Shieldstral.

**Test S2 (a stream run, not scheduled):** the stream harness that produced the 8B figures (`STREAM_GPU_PHASES.md`) at W16R2_SHIELD on the current binary, A35 off and on. **Pass for treating Shieldstral like 8B:** cadence at most 3.4 s per request and GPU-busy union above 70% of a prove call. **Kill:** cadence above 4.0 s, in which case every "% cad" above shrinks by the same factor as the unexplained time and the 8B levers (A35 and the like) are worth more here than the GPU ones.

## 4. Falsifiable tests for new claims

- **H-S1 (the substitution):** the app's slot 18 phases equal the 8B's (test (a) above). The table counts, cube and slot times already match (MEASURED); the phase split is the part assumed.
- **H-S2 (the pad rule's ceiling):** removing the whole D pad cost (gate table in slots 0, 1, 14, plus the pad term) saves at most 2.31 ms per block. This is a measured difference between two profiles, not a measurement of the term, so the test is a CPU-count check: **pass** if the gate table and the pad planes are the only table-count difference between the two W16R2 slot IRs at slots 0, 1 and 14 (read from the slot census labels, no run); **kill** if any other table differs, in which case part of the 2.31 ms is something else and the bound is void.

## 5. Honest expected effect

- **Committed words per request:** none (reading and re-pairing).
- **Proved tokens per second:** none from this tick. It stops three mispairings and changes no decision: the largest at-the-line item at the app's profile is the padded-pair skip (4.7% of cadence mid, ceiling), which needs a kernel lane and byte-identical `part` buffers; the commit-side items change proof bytes and need the owner's ruling, a new profile version and re-proving in Lean (D17, D63). The 2026-11-09 shelving of size work stands.

## 6. Risks and what was not verified

- The phase split of slots 14 and 18 at W16R2_SHIELD is not measured (batched traces give slot totals only); substitution from the 8B arm B is my assumption.
- Block GPU has a slow commit-A mode (about 2.2 ms mean, the coordinator's addendum of 17:36 UTC); the pooled 94.7 ms mixes both. Shares above use the pooled value; at 94.06 they rise by 0.7%.
- The cadence is one benchmark, two samples per arm, an older binary, verification included; the 8B cadence is a harness. Every "% cad" is at full pass-through.
- Trained weights: the block fixture is the test's own at the profile's shape. Slots 0 and 1's padding behaviour is unread. The 7-row discrepancy against tick 26's total is unexplained.
- Everything here is triage material, not a work order. Any change to what the prover commits alters proof bytes and the verifier.

## 7. Status

New full-stack proofs, passes, positions: 0 / 0 / 0. The complete private 8B at >= 50 proved tokens/s remains unachieved. Pointer posted to `ops/zkp-mvp/RECOVERY_COORDINATION.md`.
