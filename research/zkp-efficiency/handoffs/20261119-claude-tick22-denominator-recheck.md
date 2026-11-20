# Research handoff: every thresholded decision of ticks 11 to 21 against the production denominator (2026-11-19 UTC, claude-tick 22, queue item 38)

From Claude, the standing researcher. Triage material, not a work order.

**Question.** Tick 21 found that the slot breakdown's block GPU (117.285 ms at W16R2_8B, 248.899 ms at Shieldstral) includes diagnostic commit re-runs; production is 91.462 and 174.249 ms. Which decisions rested on a share of block GPU, which on milliseconds against the stream cadence, and does any decision change?

**What was read and how.** Local only, no web, nothing run. Full: ticks 11, 14, 15, 16, 20, 21 handoffs; tick 17 and the K0/K1 README by grep of the figures used; the slot breakdown README sections 1 to 2.3; `STREAM_GPU_PHASES.md` sections 0, 3, 9 and 10 (the stream's GPU-busy union and host-gap tables). Script: `20261119-claude-tick22-denominator-recheck.py` (standard library, reads no file, takes the quoted figures as inputs; every DERIVED number below is its output). Labels: MEASURED (record), DERIVED (script), COUNTED.

## 0. Headline

1. **No decision flips.** Every drop and every "no lane" call stands. Four shares move up by x1.28 (8B) or x1.43 (Shieldstral), none across a decision line except one that was never decisive (the generous G1 reading at 8B, 7.6%, still under 15% and not tensorizable).
2. **A second error sat beside the first and nearly cancelled it.** Ticks 14, 16, 17 and 20 treated the stream as "GPU-paced" with cadence 3.7455 s against a solo block sum of 3.753 s (117.285 ms x 32). That equality was an accident of the inflated denominator: cadence / 32 = 117.05 ms. Production solo GPU is 91.462 x 32 = 2.927 s, 78.1% of the cadence; the stream's prove-call has a prover buffer executing 68 to 72% of its length, and 29 to 32% (1.0 to 1.2 s) is host-only [STREAM_GPU_PHASES.md section 0, MEASURED]. An independent figure agrees with the production block: 32 x 93.48 ms (one-block log, no diag records in those traces) = 2.99 s, 2.2% above 91.462 [MEASURED vs DERIVED].
3. **Consequence for conversions.** A per-block saving of x ms is x*32/3745.5 of the 8B cadence if fully passed through. Because 117.285 happens to equal cadence/32, the OLD "share of block GPU" figures equal the cadence shares numerically for the 8B profile. So every 8B figure that was computed in milliseconds against the cadence (ticks 11, 16, 17, 20) is unaffected, and so is tick 14's "x1/(1-s)" upper bound, but it is an upper bound at full pass-through, and pass-through is below 1 (host-only 29 to 32%, overlap stretch). Do not apply 1/(1-s) to the new shares: a share of 91.462 overstates the cadence share by 1.28.
4. **Tick 21's cadence conversions need the same care.** Block-GPU ratios stand (x1.10 for H117b, x1.36 for a free NTT, x1.15 at the traffic floor); as upper bounds on cadence at 8B they are x1.076, x1.261 and x1.112 (DERIVED: 8.30, 24.2 and 11.8 ms x 32 over 3745.5 ms). Shieldstral has no measured stream cadence, so no cadence figure can be given there.

## 1. The recheck, decision by decision (DERIVED; "ms/cad" = computed from milliseconds against the cadence, unaffected)

| # | Decision (tick) | Rested on | Old figure | Corrected | Verdict |
|---|---|---|---|---|---|
| D1 | G1 dropped, under 5% (20) | share of block GPU | plain two-table slots 1.93% batched / 0.68% unbatched (8B); 1.12% / 0.33% (Shield) | 2.47% / 0.87%; 1.60% / 0.47% | **Stands.** Generous reading (slots 0, 1, 4, 20 to 22 included): 5.93% / 1.85% (8B), 3.26% / 0.98% (Shield) becomes 7.60% / 2.37% and 4.66% / 1.40%. The batched 8B figure now exceeds 5% but is under 15%; those extra slots are degree-3 products with an eq wrapper (not tensorized, tick 19) and the batched figure is mostly the barrier gap (tick 17). Unbatched useful work stays 2.4%. |
| D2a | Padded-pair skip dropped at 8B (11, 12) | ms/cad | 1.15 to 2.14 ms of slot 18; "1.0 to 1.8% of block GPU" | 1.3 to 2.3% of production block; **1.0 to 1.8% of cadence at full pass-through** | **Stands** (the cadence figure is what the stream sees; both under 5%). |
| D2b | Padded-pair skip kept at Shieldstral (11, 12) | share | 4.0 to 7.4% | **5.7 to 10.5%** (tick 21 section 4 wrote 5.7 to 10.0; 18.3 ms / 174.249 is 10.5%) | **Stands and strengthens** on solo GPU. Test P2's pass line (at least 8 ms) is 4.6% of production block, not 3.2%. |
| D3 | Tail project gets no lane (16) | ms vs cadence (hiding ratio 64 to 77% from 52 to 82 of 228 ms) | tail 4.7 / 10.8 / 20.5% of block GPU (8B), 3.6 / 6.1 / 11.3% (Shield) | 6.1 / 13.8 / 26.3% (8B), 5.1 / 8.7 / 16.1% (Shield) | **Stands.** The decision figure, 2.5 to 3.9% of cadence at the central tail if free (x1.01 to x1.02 realistic), is ms-based and unchanged. Tick 16's "above the 5% stop rule" held before and holds more. |
| D4a | "No kernel idea above a few percent" (15) | share, partly | tail quarter-length at 8B slot 18: 1.1 ms = 0.94%; K5 mixed split: 1.4% (8B, bench ms) and 2.35% (Shield) | 1.20%; **1.81% (8B), 3.36% (Shield)** (1.65 ms and 5.85 ms of the bench v13 times, mixed schedule 0.862/0.925 and 0.75/0.84) | **Stands**, with the Shield figure the closest to the line (3.4% of 5%). The coordinator's "1 to 3% at Shield" becomes 1.4 to 4.3%. |
| D4b | H162 (four-way split) gets no lane (15) | ratio to v13 (0.77 to 0.97) | unchanged | unchanged | **Stands**; ratios do not depend on the denominator. |
| D5 | H133 / H161 / H134 caps (14) | share, bytes-proportional upper bounds | windows 0 to 4: 28.6%; H133 both 4.3 / 15.6 / 12.7%; H161 4.5%; H134 0.1 to 0.2% (8B). Shield: both 3.5 / 13.2 / 12.2%, H161 4.7% | 36.7%; 5.5 / 20.0 / 16.3%; 5.8%; 0.1 to 0.3%. Shield: 5.0 / 18.8 / 17.4%, H161 6.7% | **Superseded, not changed.** K1 (ratios, unaffected) already put the loads at 0.11 to 0.19 of the body, so traffic ideas are capped at 3.7 to 6.4 ms of the 33.6 ms of windows 0 to 4, i.e. 4.0 to 7.0% of production block GPU and 3.2 to 5.5% of 8B cadence at full pass-through. H134 stays dropped (under 0.3%). H161 (6.7% at Shield by the old bytes bound) stays unscheduled behind K1's cap. |
| D6 | Batch-gap fix x1.01 to x1.02 (17); K9 unscheduled | ms/cad | equal-round gap 11.30 ms = 9.6% (8B), 5.0% (Shield); total gap 15.8% / 7.5% | 12.4% / 7.1%; total 20.3% / 10.7% | **Stands.** The cadence figure (2.2 to 3.5% if it vanished, hidden-adjusted; x1.01 to x1.02 realistic) is ms-based. |
| D7 | G1/G3 and H117b (19, 21) | already on the new denominator | x1.10 / x1.36 / x1.15 block GPU | cadence upper bounds x1.076 / x1.261 / x1.112 at 8B | **No decision change** (G3 was dropped on arithmetic, H117b is the owner's deferred ruling); the cadence conversion is new. |
| D8 | Tick 14's "x1/(1-s), GPU-paced" rule | accident of the old denominator | cadence 3.7455 s vs 3.753 s solo sum | 3.7455 s vs 2.927 s production sum (78%) | **Rule withdrawn as an equality.** The old 8B shares equal cadence shares numerically, so its numbers survive as full-pass-through upper bounds only. |
| D9 | Host matmul claims "hidden" (20) | assumed GPU-paced | 14 ms per block, 0.45 s per request, "hidden" | not hidden by that argument | **Premise withdrawn; decision unaffected** (G1 stays dropped). New lead in section 2. |

Not on a share: tick 10's withdrawn line-value estimate and tick 12's H158 (ms of a kernel, A27 measured); tick 13's H133 figures (superseded by 14 and K1); K1b's line-value ceiling (15% and 7% of v13, a ratio); tick 15's 0.91 microsecond law (ms per round); tick 19's TensorZKP verdict. None needs restating.

## 2. What the correction does reveal (a lead, not a finding)

Section 9 of `STREAM_GPU_PHASES.md` ("host gap of a fork thread", serve4 beside, per call) lists "slots to slot 14: 1.06 thread-s, 0.40 s exposed (37%)", "between small slots: 0.45 thread-s, 0.16 s exposed (35%)". Tick 20 found the nine matmul claims (slots 5 to 13) are host work of 12 to 15 ms per block, i.e. 0.38 to 0.48 thread-s per request over 32 blocks (DERIVED). The match in size (0.45) is suggestive, not shown: those gaps are bracketed by device slots and the host matmuls sit between slot 4 and slot 14. If they are the content of those gaps, the exposed part is up to 0.40 s of a 3.8 s prove call (10.5%), which is larger than any kernel idea left on the list (all 1 to 3%). That is the reverse of tick 20's "hidden" assumption. It is a host-side item (the 1.0 to 1.2 s host-only time is already known; what is new is a candidate attribution). Queued as item 40.

## 3. Falsifiable test (reading only)

**T1.** The `PB-SLOTSTEP` host lines in `raw/w16r2_8b_armA_prod_batched.log` give the host seconds of slots 5 to 13 per block. Sum their host time inside the gap between the last device slot before slot 14 and slot 14's first buffer (trace `tsv` rows of one prove call). Pass for the lead: the matmul host time is at least 60% of the 16.2 ms mean "slots to slot 14" gap; fail: under 25% (then the gap is something else and D9's "hidden" stays unproven either way). Needs the externalized traces (`/Users/victorrielly/zk60-artifacts/slot18_14_traces_20261117/`) paired with the stream trace; the stream trace for it is the Batch 7 one, which is a different window from the breakdown, so the pairing is by slot name and call index, not by clock.

## 4. Honest expected effect

- **Committed words per request:** none (reading and arithmetic).
- **Proved tokens per second:** none from this tick. It prevents one mis-conversion: a share of production block GPU must not be fed to 1/(1-s) for the 8B cadence.

## 5. Risks and what was not verified

- The production denominator rests on tick 21's reading that the only addition of `HL_METAL_TIMING=1` is the diag records; the Batch 6 one-block figure (93.48 ms, no diag rows in that trace) agrees within 2.2%, which is the first independent support, and tick 21's T1 is still not run.
- The "old shares equal cadence shares" statement holds for 8B (ratio 0.998). It is a numerical coincidence and does not extend to Shieldstral, whose stream cadence is unmeasured here.
- D4a's K5 savings use the bench's v13 times (rounds from cap/4) for the Shield slots, not production slot times (27.95 and 34.75 ms); the production gain is what the bench's round range covers, which is an assumption.
- Full pass-through is an upper bound; the realized fraction was not measured (host-only 29 to 32%, overlap buys 1.11 to 1.19x).
- Any change named here to the prover would need an exact-equality gate and, for a protocol change, the owner's ruling, a new profile version and re-proving in Lean. The 2026-11-09 shelving of size work stands.
