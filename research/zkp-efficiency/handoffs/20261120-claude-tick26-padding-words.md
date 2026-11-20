# Research handoff: committed padding words and the pad rule's cost, per profile (2026-11-20, claude-tick 26, queue item 27)

From Claude, the background researcher. Triage material, not a work order.

**Question.** Padded columns are committed and proved zero. From `shape.rs`, `layout.rs`, `pad.rs`, the census and the generated kernel, count the committed words and pad-rule (`IrPad`) terms this costs per block at W16R2_8B and the Shieldstral profile, and say what a compact layout would change.

**What was read.** Code in full or in the relevant ranges: `shape.rs` (`a_plane_doms`, `natural_log`, `true_size`, `pads`, `totals`, `h_plane_doms`), `layout.rs` (`domain_log_at`, `carries_h_planes`), `pad.rs` (rules, `zero_rule_a_planes`, `indicator_slots`), `slot_ir.rs:790-836` (`IrPad`), `slot_ir_accuracy.rs:499-553` (`fzc_w16`), all under `ops/zkp-mvp/gpu-metal/hashline/src/private_block/`. Records: `results/zk60_effplan_20261105/census.log`, `results/zk60_w16r2_20261101/ACCOUNTING.md` (line 68), the generated `results/zk60_k0k1_roofline_20261118/build/k5_b18.metal`, ticks 11, 15, 21, 22. Web: 2 searches, 2 page reads (ePrint 2025/917 abstract page and a third-party explainer; **not** the paper). Script: `20261120-claude-tick26-padding-words.py` (arithmetic only, reads no file, under a second). Labels: COUNTED, MEASURED, DERIVED, [authors], ASSUMED.

## 0. Headline

- **Committed padding is 6.0% of a block at W16R2_8B and 27.0% at the Shieldstral profile** (DERIVED from COUNTED plane lists). The plane lists and row totals are identical in the two profiles (A 2,501, H 2,602 rows, `ACCOUNTING.md:68`), so a Shieldstral block commits the same 1.338 GB of codewords as an 8B block while holding 27% fewer live words.
- **At 8B the dropped-everything bound is small:** 304 of 5,103 rows, 79.7 MB per block, 2.55 GB of the 43.14 GB request (5.9%); commit time bound 1.82% of block GPU = 1.66 ms, at most **1.4% of the stream cadence** at full pass-through (rule (a) of tick 22). Under the 5% rule: not a speed item at 8B.
- **At Shieldstral it is large:** 1,376 rows, 360.7 MB per block, 9.38 GB of the 35.11 GB request (26.7%); commit bound 11.8% of block GPU = 20.5 ms per block of 174.25 ms. This is the one case above the 5% line, and it comes with a protocol change.
- **The pad rule's own cost is small** (section 3): at 8B one group of 9 planes in slot 18, 2 of 25 `f2_mul` and one extra table of 21 in the kernel; lazy construction after round 6 is worth 0.4 to 1.3 ms per block, at most 1.1% of the cadence. Dropped at 8B.

## 1. Which domains pad (COUNTED)

`pads(dom)` is `size != true_size` (`shape.rs:2460-2462`); `size = 2^max(natural_log, 14)` for domains that carry H planes (`layout.rs:175-181,198-200`).

| Profile | D (T x width) | F (T x hidden) | Q, Kv, S |
|---|---|---|---|
| W16R2_8B | 2^19 exact | 14,336 of 16,384 columns (12.5% pad) | exact |
| Shieldstral | 3,072 of 4,096 (25%) | 9,216 of 16,384 (43.75%) | exact |

`T` and `Ht` do not lift and do not pad at either; `L` and `Tab` are lifted to 2^14 and pad (section 2). The padding sits inside every row, as the tail of each token's column segment (`flat = t * f_pad + j`, tick 11 section 4): an F row of 16,384 words holds 14,336 live words at 8B; a D row at Shieldstral holds four tokens of 3,072 live words in 4,096.

## 2. Committed words (DERIVED from census.log plane lists, script)

Plane counts per domain (the same in both profiles): A: D 19, F 9, Q 6, Kv 6, S 8, T 4, Ht 2, L 2, Tab 15; H (Fp2 planes, two base rows each): D 10, F 5, Q 3, Kv 3, S 5, L 1, Tab 16. Rows per plane: D 32, F 128 (2^19 or 2^21 words over 2^14).

| | W16R2_8B | Shieldstral |
|---|---:|---:|
| padded A rows (D / F) | 0 / 144 | 152 / 504 |
| padded H base rows (D / F) | 0 / 160 | 160 / 560 |
| total padded rows of 5,103 | **304 (5.96%)** | **1,376 (26.96%)** |
| per block, codewords at rate 1/2 | 79.7 MB | 360.7 MB |
| per request (32 / 26 layers) | 2.55 GB | 9.38 GB |
| lookups on padded positions of the counted 32,276,480 | 1.84 M (5.69%) | 8.91 M (27.61%) |

Rows that are not padded columns, as an upper bound on the rest: 10 rows of the short domains T, Ht, L (one 2^14 row each, at most 2^12 words used, 0.20%) and 47 `Tab` rows (3 byte tables with 256 of 16,384 entries, and the range sub-planes, which for narrower families repeat their entries, `range16.rs:229`; 0.92%). I did not list the family widths. Upper bound with these: 7.07% (8B), 28.08% (Shieldstral).

What the padded words hold: A planes are proved zero off support, except `A_E` and full-width range sub-planes (`pad.rs:291-315`); LogUp helpers are exempt, nonzero constants (`pad.rs:317-345`). With every looked-up value zero and the public activation `group` column 0 at padded columns (tick 11 section 4), each helper is one constant per helper plane, computable by the verifier from the challenges (DERIVED, as tick 11 argued; not tested).

## 3. The pad rule's terms (COUNTED)

- One `IrPad` group per padded domain in the domain's own zero-check: `mu_pad * (1 - supp) * sum_j zeta^j plane_j`, one `zeta` power per ZERO-rule A plane (`slot_ir.rs:790-836`; `pad.rs:313`, `zero_rule_a_planes`).
- **8B:** slot 18 (F): one group, 9 planes (all 9 A F planes are ZERO-rule, `A_E` is on S); slot 19 (`Tab`) and the L slot carry their own. Slots 14, 15, 16, 17 carry none.
- **Shieldstral:** slot 14 (D): one group, 19 planes; slot 18 (F): 9 planes; plus the support factor on the norm sums in slots 0 and 1, which read the padded D cube (`pad.rs:228-245`, `INDICATOR_SLOT_DOMAIN`; the test-only listing mirrors `argument::define`; ASSUMED for the W16R2 IR).
- **In the shipped 8B slot 18 kernel** (`k5_b18.metal`, `k_v13`): the 9-plane batch is a materialised extension table (`xtabs` index 2, `v21`, `n17`), `n16 = 1 - v18`, and the term is `f2_mul(f2_mul(CF(38), n16), n17)`. So the term costs 2 of 25 `f2_mul` (8%) and one extra table that must be built (2^21 extension cells, 9 `f2_mulb` each), read and folded every round: 1 of 21 live tables (4.8%). `v18` (the support) is read by the gate anyway.
- **Honest-prover observation (DERIVED, new):** in rounds 0 to 6 the first seven rounds bind t, a pair keeps its column (tick 11), so `supp` is constant across a pair; the pair is either live (anti = 0) or padded (planes 0 at both ends): **the term is 0 at every pair and every evaluation point**. It only becomes nonzero once the column bits fold (0.8% of cube volume). The batch is linear in the planes, so it can be built after round 6 from the folded planes (2^14 cells) with identical values: no change of bytes, no verifier change.
- **Value of that lazy node:** `bw / 21` of the bandwidth-bound phases (round 0 plus rounds 1 to 4 = 15.40 ms) with a 0.6 realised factor, to that plus a third of the 1.70 ms table build: **0.44 to 1.30 ms per block at 8B** (0.48 to 1.42% of 91.46 ms; at most 0.38 to 1.11% of the 8B cadence at full pass-through). Shieldstral slots 14 and 18 on the same assumption (one extra table of 67 and of 32): 0.68 to 2.55 ms of 174.25 (0.4 to 1.5%). Under the 5% rule at its ceiling: dropped at 8B; at Shieldstral it overlaps tick 11's padded-pair skip, which already removes the padded pairs' reads of every table, this one included. Same words out, prover-only.

## 4. What a compact layout would change (protocol change; report only)

1. **Which part of the cost is the commitment, which the cube.** The padded F cube (2^21 cells) is what slots 14 and 18 iterate; a compact commitment does not shrink the zero-check cubes unless the domains are reshaped too. Padding words in the commitment cost NTT, hashing and traffic (commit_A+H is 30.5% / 43.7% of block GPU, tick 21); padding in the cube costs tick 11's 1 to 2% (8B) and 5.7 to 10.5% (Shieldstral).
2. **Published route: jagged commitments** (Hemo, Jue, Rabinovich, Roh, Rothblum, ePrint 2025/917; abstract page and an explainer only). Non-dummy columns are stacked into one dense vector with a metadata vector of cumulative heights; [authors] "prover cost dominated by 5 field multiplications per element of the trace area"; no extra oracle commitments; I could not confirm which PCS it supports or any zero-knowledge statement (the abstract names none). The explainer says the stacked length is still a power of two. For this project the heights are public (`true_size`), the open question is whether a Ligero-style row code can use the stacked vector with the row-opening and zero-knowledge masks as designed.
3. **Shortened rows would need a non-power-of-two code length.** Each row has 14,336 live words of 16,384 (8B) or 9,216 (Shieldstral, F). The codeword length stays 2^15 under the radix-2 NTT; shrinking k alone shrinks no committed words. Search found no source that states how Ligero or Brakedown handle widths off a power of two (one library zero-fills); I did not read AHIV17.
4. **Exact fit at 8B:** 8 F planes of 14,336 words are 7 planes of 16,384 (114,688); a stacking of eight planes into seven needs the sumcheck tables and 9 ZERO rules per plane re-indexed, so it is a new circuit layout, not a knob.
5. **What disappears with it:** the `IrPad` group, its support table, the `zeta` challenge and its `mu` slot in each padded slot, and the 304 / 1,376 rows; what appears: a public height vector and a stacking map in the verifier. The 34 exempt helper constants would become either verifier-computed (an exact sum for the padded part of each helper plane) or stay committed.

## 5. Falsifiable tests

- **P2c (count, CPU, no GPU; the census test with a padded profile).** Run `effplan_census_of_the_committed_rows_by_domain` at `W16R2_SHIELD_T128_H24` (the retained test only lists the 8B, R13_8B and rung profiles). **Pass:** A 19 / 9 / 6 / 6 / 8 and H 10 / 5 / 3 / 3 / 5 planes, total rows 5,103. **Kill:** any difference (my Shieldstral columns assume identical lists, from the row totals alone).
- **P3 (prover-only, tick 11's P1 on CPU).** On an honest witness at the Shieldstral profile, evaluate the pad term's IR at every pair of rounds 0 to 6. **Pass:** 0 at every pair and point. **Kill:** any nonzero (a ZERO plane is not zero at padding or the support is not column-constant). If it passes, the lazy node is bit-identical in `part` buffers (digests of ticks 11 and 12).
- **Lazy-node bench (GPU, only if P3 passes and the coordinator runs it with the padded-pair skip):** slot 18 at 8B at least 0.44 ms faster batched; kill below 0.2 ms.

## 6. Expected effect

- **Committed words per request:** none for the lazy node. A compact layout: at most -5.9% at 8B (2.55 GB) and -26.7% at Shieldstral (9.38 GB) of the codewords, minus the stacking metadata.
- **Proved tokens per second (8B stream):** lazy node x1.00 to x1.01; a compact layout at most 1.4% of cadence at 8B by the commit bound. At Shieldstral the commit bound is 11.8% of block GPU, a stream figure not computed (the Shieldstral stream cadence is not in my sources).

## 7. Risks and what was not verified

- The commit-time bounds assume cost linear in committed rows and all padded rows dropped; a code length that stays 2^15 gives none of it.
- The Shieldstral plane lists are inferred from identical row totals; the kernel structure of Shieldstral slots 14 and 18 (one extra extension table each) is assumed from the 8B kernel and tick 15's table counts.
- The 1/21 table-traffic share assumes equal bytes per table; the build share (a third of 1.70 ms) is a guess with no phase split.
- Jagged commitments: abstract and one explainer read, no paper; zero knowledge and PCS compatibility unknown. Search on Ligero width handling returned nothing relevant.
- Any compact layout changes proof bytes, the verifier and the Lean statements; it needs the owner's ruling and a new profile version (D17, D63). The lazy node alone changes none of them. Proof-size work was shelved on 2026-11-09; this is about prover volume and time.

## 8. Status

New full-stack proofs, passes, positions: 0 / 0 / 0. The complete private 8B at >= 50 proved tokens/s remains unachieved. Hypothesis H165 added (lazy construction of the pad batch; kernel-side, same words out). Pointer posted to `ops/zkp-mvp/RECOVERY_COORDINATION.md`.
