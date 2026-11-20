# Research handoff: the Shieldstral stream value of dropping committed padding (2026-11-20, claude-tick 27, queue item 46)

From Claude, the background researcher. Triage material, not a work order.

**Question.** Tick 26 bounded the committed padding at 26.96% of rows and 20.5 ms of the Shieldstral block's 174.25 ms. What is that against the Shieldstral prove-call cadence under tick 22's rule (a), and does any retained record give Shieldstral plane counts (test P2c)? Reading only.

**What was read and how.** In full or in the cited ranges: `results/zk60_slot18_14_breakdown_20261117/README.md` (sections 1 and 2.3) and `summary.json` (census keys), `results/zk60_astra_20261026/a30a31_benchmark_review_20261113/REVIEW.json` (whole), `results/zk60_effplan_20261105/census.log` and `a23merge_trained.log:225-259`, `results/zk60_a27_app_20261107/q1_census.log:224-246`, `results/zk60_w16r2_20261101/ACCOUNTING.md:55-70`, `MVP_STATUS.md` (lines 47-49, 855-868, 1187-1196), `ZK60_NEXT_PROTOCOL_CANDIDATES.md` (lines 251-265, 300-312), ticks 21, 22, 26. Web: none (the item is a local reading item). Script `20261120-claude-tick27-shieldstral-padding-stream.py` (arithmetic from typed inputs, under a second). Labels: COUNTED, MEASURED, DERIVED, ASSUMED.

## 0. Headline

- **Tick 26's 11.8% / 20.5 ms is a cross-profile product and must not be used for the app's profile.** It multiplies the W16R2 padded-row fraction (26.96%, from W16R2 row totals 5,103) by the commit time of the **R13_SHIELD** block (76.20 ms = 39.481 + 36.718, README section 1; 8,967 rows by the R13_8B lists). The block GPU 174.25 ms is also R13_SHIELD. The slot breakdown never ran a W16R2 Shieldstral profile (`summary.json` census keys: `r13_8b`, `r13_shield`; arms for `w16r2_8b` and `r13_shield`). Ticks 21, 22 and 26 all say "Shieldstral" for these R13 figures.
- **The installed app is W16R2** (`MVP_STATUS.md:47`, 2026-11-13; benchmark: 29.22 proved tok/s W16R2 against 16.11 R13). R13's own bound is still the same size, because its padded fraction is nearly the same: 26.50% (DERIVED below), 20.2 ms of 174.25 (11.6%), but only 6.6% of the R13 cadence.
- **At the app's profile (W16R2 Shieldstral) the bound is 4.5% of the measured cadence centrally (4.5 to 5.1%), at full pass-through, at the 5% line, not above it.** Under the 5% rule: do not schedule; it also needs a protocol change that tick 26 section 4 shows is a new layout, not a knob.
- **No retained record gives Shieldstral plane counts** at W16R2 or R13 (P2c is still open); the two Shieldstral censuses retained (`q1_census.log`, the breakdown's `census_r13_shield.log`) are slot censuses (cube size, tables, degree), not plane lists.

## 1. Cadences (MEASURED, one review of one benchmark)

`a30a31_benchmark_review_20261113/REVIEW.json`, stream of 8 posts = 24 T128 category proofs, native binary, every receipt proved and checked, startup excluded, two warm samples per arm in ABBA order:

| Profile | stream wall (24 requests) | per request | proof only (checks deferred) | one post (3 requests) |
|---|---:|---:|---:|---:|
| W16R2 (the app) | 105.14 s (29.22 tok/s) | **4.381 s** | 33.34 tok/s = 3.839 s | 26.70 s |
| R13 | 190.74 s (16.11 tok/s) | 7.948 s | 18.44 tok/s = 6.942 s | 39.14 s |

[MEASURED; the review itself says: two samples per arm, different calibrated profiles, host-quiet not retained, binary of 2026-11-12, i.e. before A33 and A35.] Later Shieldstral stream records: none found (the 8B harness's 3.7455 s cadence is a different stack). The 4.381 s includes the verifier's time, which the 8B cadence of 3.75 s does not necessarily include; so the figures are not like for like with the 8B rule's denominator.

## 2. Padded rows at the two Shieldstral profiles (DERIVED)

- **W16R2:** 1,376 of 5,103 rows (26.96%) = tick 26 (plane lists COUNTED at 8B, ASSUMED equal at Shieldstral from equal row totals, `ACCOUNTING.md:68`).
- **R13:** the only retained R13 plane lists are the 8B's (`census.log:239-256`: A D 1,248 rows, A F 2,048, H D 544, H F 1,024; totals A 4,577, H 4,390). At Shieldstral padding (D 25%, F 43.75%) and with the H rows doubled to base rows as tick 26 did: 312 + 896 + 272 + 896 = 2,376 of 8,967 = **26.50%**. ASSUMED: the R13 Shieldstral lists equal the R13 8B lists. Note slot 14 at R13_SHIELD has 64 tables (44 base) and slot 18 has 29 (`q1_census.log:238,242`), against 36 and 19 at W16R2_8B, so the R13 and W16R2 blocks do differ in the slot kernels even at equal geometry.

## 3. The Shieldstral commit time at W16R2 (DERIVED, a bracket)

- Same row total (5,103), same row length 2^14, same code and NTT length as the 8B W16R2 block, so the commit time should be close to the 8B's: production commit_A + commit_H = 30.5% of 91.46 ms = **27.9 ms** (tick 21). Upper end: the retained older M4 phase times show the helper phase 29% longer at W16R2_SHIELD than W16R2_8B (0.062 against 0.048 s, `a23merge_trained.log:256,250`; wall seconds, older code, a single warm pass); applying +29% to the helper half gives 31.9 ms.
- Block GPU at W16R2_SHIELD is **not measured**. The M4 phase sums (warm, gpu=1: 0.281 s Shieldstral, 0.292 s 8B) put it near the 8B's: about 88 to 95 ms (DERIVED from wall-clock phases of older code; a weak estimate). 26 blocks then give about 2.3 to 2.5 s of solo GPU against 4.381 s (52 to 56% of cadence, against 78% at 8B). Treat this as a flag, not a result: either the Shieldstral stream is less GPU-bound than the 8B one, or the old-binary cadence carries things the 8B figure leaves out.

## 4. The answer, by rule (a)

Padded commit time dropped entirely, saved per block x ms, 26 blocks, divided by the cadence (rule (a): at most, at full pass-through):

| Case | saved per block | % of block GPU | per request | % of cadence 4.381 s | at 4.1 s (A35's -6%) | at 3.5 s |
|---|---:|---:|---:|---:|---:|---:|
| W16R2_SHIELD central (27.9 ms commit) | 7.52 ms | about 8.5% (of 88 ms; 7.9% of 95) | 0.196 s | **4.46%** | 4.77% | 5.59% |
| W16R2_SHIELD upper (31.9 ms) | 8.61 ms | about 9.8% | 0.224 s | **5.11%** | 5.46% | 6.40% |
| R13_SHIELD own fraction (76.2 ms) | 20.19 ms | 11.6% of 174.25 | 0.525 s | 6.61% of 7.948 s | n/a | n/a |
| Tick 26 as written (cross-profile) | 20.55 ms | 11.8% | n/a | not meaningful | n/a | n/a |

**5% of the cadence is 8.42 ms per block, which is 30.2% of the 27.9 ms commit time**; the bound is 26.96% of it. So the padded commit time alone sits just under the line, and only if the saving were total (an NTT length of 2^15 that stays leaves none, tick 26 section 7). The realised stream gain is lower again, because the stream is not GPU-paced (rule (a); the 8B stream hides about a third of a prove call's non-GPU time and gains less than the full block saving on the two-lane steady state).

## 5. Falsifiable tests

- **P2c' (CPU census, no GPU, about a second after the build).** Run `effplan_census_of_the_committed_rows_by_domain` (range16_tests.rs:217) with `W16R2_SHIELD_T128_H24` and `R13_SHIELD_T128_H24` added to its profile list. **Pass:** A D/F/Q/Kv/S = 19/9/6/6/8 planes and H 10/5/3/3/5 at W16R2; R13 = 39/16/14/14/13 and 17/8/7/7/9 (the 8B lists). **Kill:** any difference; the figures in section 2 move with it.
- **S1 (slot census at W16R2_SHIELD, the A27 census test `a27_slot_census_at_a_trained_shape` with the W16R2 Shieldstral profile).** It decides whether ticks 11 and 22's "padded-pair skip 5.7 to 10.5% of block GPU at Shieldstral" holds at the app's profile. Those figures come from R13_SHIELD slots 14 and 18 (27.95 and 34.75 ms, `q1_census.log`, README section 2.3). **Pass for keeping them:** W16R2_SHIELD slot 14 and 18 table counts and cube sizes close to R13_SHIELD's. **Kill:** at the 8B-like counts (36 and 19 tables) the saving falls with the table traffic by a factor of about two.
- **B1 (one quiet solo block run at W16R2_SHIELD with `HL_METAL_TIMING=1`, the breakdown harness).** Gives block GPU and commit_A + commit_H at the app's profile; closes section 3. **Pass for the bound here:** commit at most 27.9 to 31.9 ms. **Kill:** commit over 42 ms (then the bound exceeds 5% of cadence even at 4.381 s).

## 6. Expected effect

- **Committed words per request:** unchanged by this reading. A compact layout would remove at most 26.96% of the W16R2 Shieldstral codewords (9.38 GB of 35.11 GB per request, tick 26), minus the stacking metadata.
- **Proved tokens per second:** a compact layout, at most 4.5 to 5.1% of the Shieldstral W16R2 cadence by the commit bound (x1.05 as a ceiling, realised less), against 1.4% at 8B. Not a speed item under the 5% rule at central; revisit only if B1 measures commit time above about 30 ms or the cadence falls below 3.8 s.

## 7. Risks and what was not verified

- Cadence: one benchmark, two warm samples per arm, a binary that predates A33 and A35, verification included in the wall time; Shieldstral cadence after those changes is unmeasured.
- Block GPU at W16R2_SHIELD is not measured; the 88 to 95 ms estimate rests on wall-clock phase sums of older code. The ratio to cadence (52 to 56%) is far from the 8B's 78%, which I cannot explain from the records.
- The R13 plane lists at Shieldstral are assumed to equal the 8B's; the W16R2 lists likewise (tick 26).
- Ticks 11, 21 and 22's Shieldstral shares (padded-pair skip, tail, K5 split 3.36%) rest on R13_SHIELD slots; I did not re-derive them for W16R2.
- Any compact layout changes proof bytes, the verifier and the Lean statements; it needs the owner's ruling and a new profile version (D17, D63). The owner shelved proof-size work on 2026-11-09; this is prover time.

## 8. Status

New full-stack proofs, passes, positions: 0 / 0 / 0. The complete private 8B at >= 50 proved tokens/s remains unachieved. Correction filed against tick 26 (profile pairing). Pointer posted to `ops/zkp-mvp/RECOVERY_COORDINATION.md`.
