# Research handoff: how many cell-plane reads per block, and what contraction vectors cost (2026-11-17 UTC, claude tick 8)

From Claude, the background researcher (D50). Queue item 19 (H153, added by tick 7). Local reading only: 0 searches, 0 fetches.

**Scope.**
- **Read directly (code):** `shape.rs` (`a_plane_doms` 2466-2516, `claim_sites` 2597-2643, `totals` 2751-2779), `layout.rs` (`A_SITES`, `HOSTS` 1107-1137; the toy gate 1227-1250), `argument.rs` (the `B` site helpers 1524-1667 and the slot bodies: SS, SSM, TZC 2016-2060; QMM/KMM/VMM/WO 2144-2180; SCORE, PV 2225-2290; GMM/UMM/DMM 2293-2320; DZC 2327-2346; FZC 2485-2494; QZC/KVZC 2538-2565; SZC 2626-2682; TAB 2806-2819; IO 2943), all in the retained census tree `results/zk60_sol_20261105_block_inventory/census-source/hashline/src/private_block/`; plane counts from `results/zk60_effplan_20261105/census.log`; tick 5, 6, 7 handoffs.
- Not read: `argument_accuracy.rs`; the PCS code beyond tick 7; the Theta tie (tick 5 only). One standard-library script, `20261117-claude-tick8-cell-read-count.py`. No build, proof, GPU run or Git write.
- **Triage material, not a work order.** Any change to what is committed alters proof bytes and the verifier, and needs the owner's ruling, a new profile string (D17) and re-proved Lean (D63). The owner shelved proof-size work on 2026-11-09; this concerns committed volume.

Labels: **COUNTED** (file:line), **DERIVED** (script), **ASSUMED**, **[tick N]** (carried).

## 0. Headline

- **Tick 7's "120 sites" was the toy's count, not the 8B's.** `A_SITES` summing to 120 is the toy shape's declared table (`layout.rs:1118`, asserted only in the toy gate, `layout.rs:1239`). The shape-driven rule `claim_sites` gives **110 A sites** for the 8B profile W16R2_8B (DERIVED; reproduces the census's 2,501 A rows: 2,279 + 2 x 110 + 2) and 146 for R13_8B.
- **Of the 110, 67 are reads of cell planes** (planes on D, Q, Kv, S, F, the ones candidate B would pack); 43 are not (22 on the four T planes and their limbs, 2 + 2 on T and Ht slices, 2 on L, 15 on the table planes). All 67 are plane-at-a-point reads whose point is a sumcheck end point (COUNTED, `argument.rs`).
- **H153 result: passes only conditionally.** With U (one contraction vector per read, 2k words each) plus two mask rows per read plus the proximity pair, U is **179-204 rows** with the class-C split only: **17.0-18.7% of the A data rows B saves** (pass: at most 20%). It is 20.3% with class M also split and **34-37%** if the int16 word planes must split too (fail). The answer therefore rests on class W, which is still unmeasured (item 17).
- **Whole block** (tick 6's 0.76-0.85, before helpers): about **0.80** (C only) to **0.90** (C+M+W), against tick 7's 0.79-0.94. Tick 7's upper bound came from 120 reads at the worst k.

## 1. The sites, COUNTED and DERIVED (W16R2_8B)

`claim_sites` makes one site per A plane of each own-domain slot, plus fixed extras; each site is one `a_slice` or `a_at` call that pushes a private table with its own reserved mask pair (`argument.rs:1552-1569`; `finish` checks the count, `:1653`).

| Slot | Sites | Reads | Domain (k) |
|---|---:|---|---|
| SS, SSM | 1 + 1 | A_X, A_X1 | D (4,096) |
| TZC | 22 | 4 T planes, 18 norm-limb slices | T, 1 row each, **not cell** |
| LZC | 2 | L planes | not cell |
| RS | 2 | A_E, A_ZSEL | S |
| QMM, KMM, VMM | 3 | A_Y at (r_q, sumcheck columns) | D |
| WO | 1 | A_O8 | Q (4,096) |
| GMM, UMM | 2 | A_YM | D |
| DMM | 1 | A_H16 | F (14,336) |
| SCORE | 2 | A_QR8, A_KR8 | Q, Kv (1,024) |
| PV | 2 | A_P, A_V8 | S, Kv |
| DZC | 21 | the 19 D planes, plus 2 T slices | 19 D, 2 not cell |
| QZC | 7 | 6 Q planes + the flipped RoPE partner | Q |
| KVZC | 7 | 6 Kv planes + the flipped partner | Kv |
| SZC | 10 | 8 S planes + A_MX, A_SUM | 8 S, 2 Ht (not cell) |
| FZC | 9 | 9 F planes | F |
| TAB | 15 | 3 + 12 range sub-planes | not cell |
| IO_IN, IO_OUT | 1 + 1 | A_X, A_X2 | D |

Cell reads by domain (DERIVED): **D 28, Q 9, Kv 9, S 11, F 10 = 67**; non-cell 43; total 110.

## 2. Cost of U per read, DERIVED (script)

U per read is the row-contracted vector: k Fp2 entries = 2k words, with k the channel width [tick 6]: D 4,096, Q 4,096, Kv 1,024, F 14,336 (two 7,168-column matrices after the split; the entry count is the same), S 128 or 4,096 (orientation not read, tick 6). Entries over the 67 reads: **349,184** (S at 4,096) = 43 local rows of 2^14 words. Mask rows: 2 per read (the local rule, `protocol.rs:70-140` [tick 7]) = 134, plus 2 for the proximity pair.

| Scenario (tick 6 table) | Cell reads | U rows | A data rows saved | U share of saving |
|---|---:|---:|---:|---:|
| No split (hypothetical) | 67 | 179 | n/a | n/a |
| C split only, S one 4,096 matrix | 76 | 204 | 1,202 | **17.0%** |
| C only, S unpacked (k = 128) | 76 | 198 | 1,060 | **18.7%** |
| C + M, S 4,096 | 83 | 222 | 1,094 | 20.3% |
| C + M + W, S 4,096 | ~107 | 286 | 839 | 34.1% |
| C + M + W, S unpacked | ~107 | 277 | 747 | 37.1% |
| Every read doubled (bound) | 134 | 356 | 747-839 | 42-48% |

Extra reads for splits are COUNTED from the plane classes: C = 9 planes (six D, one S, two F; 480 rows, checks against tick 6), M = 7 planes (two Q, two Kv, one F, two S; 272 rows, checks). W (about 24 reads on 15 planes) is an ESTIMATE from the named list in tick 6. Each C and M plane is read once, in its own slot's range read. This assumes **each half of a split plane needs its own U**; see §3 for the alternative.

## 3. Does a claim with several parts need several reads?

- **Different planes at one point: yes, one U each.** DZC reads 19 D planes at one point; the zero-check's terminal formula uses each plane's end value separately (the planes enter products), so a lambda-batched single U cannot replace them. (Counted already in the 67.)
- **Same plane, same row point: one U serves several reads.** QMM, KMM and VMM all read A_Y with the same fixed token point `r_q` (only QMM draws it, `argument.rs:2146`) and differ only in their sumcheck column coordinates; GMM and UMM share `r_tf` on A_YM (`:2295-2298`). Their U (the token-axis contraction) is identical: **64 distinct vectors for 67 claims** (DERIVED). The saving in words is small (3 x 4,096 entries); the saving in claim pairs depends on whether pairs are per read or per vector.
- **A split limb: probably two U, possibly one.** A read of a split 16-bit limb is `lo + 256 hi`. If the two byte planes sit in different packed lanes, the tie to the packed words is per cell matrix, so two U (the table above). One combined U would need a tie on the linear combination of cell matrices, which tick 5's mechanism does not state. ASSUMED two; the other case only lowers the cost.
- **Row-axis point fixed before the sumcheck.** For the matmul slots the token point is drawn before the slot's rounds; only the column part is a sumcheck end point. So for these 7 reads the contraction vector does not depend on the end point at all, which relaxes tick 7's ordering concern for them (the zero-check reads still depend on the end point).

## 4. A credit tick 7 did not take (open)

Today's A already holds a mask pair per site: `a_rows = a_data_rows + 2 * a_sites + 2` (`shape.rs:2762`), and tick 6's whole-block fractions keep those 222 rows. If B moves the 67 cell-site claims off the packed A and onto U, the 134 rows of A pairs at those sites are no longer needed; what remains on packed A are the Theta-tie claims, whose number I did not count. DERIVED credit: **114 rows** at 10 tie claims, **38 rows** at 48 (one per cell plane), 0 at 67. On this accounting U's net cost is about 90 to 165 rows, not 179 to 286. This turns on how many claims the tie places on A (item for a later tick) and is not assumed in the headline.

## 5. Falsifiable tests

- **H153 (read count): result above.** Revised claim: with the C split, U (with its pairs) is at most 20% of B's saved A rows; **holds** (17-19%), **fails** if class W must split (34-37%). Kill test remains item 17 (per-plane RMS from a one-block trained capture).
- **H155 (tie claims).** Claim: the Theta tie places at most 20 claims on packed A per block, so the 134 A pairs at the cell sites are mostly released. **Test (read, no proof):** from tick 5's description and `zpart_weights` / `group_zclaims` (`pcs.rs`), count the claims on packed A that the tie and the digit lookup need; **kill** if more than 48.
- **Not proposed:** a prover change.

## 6. Honest effect

- **Committed words per request:** candidate B's saving is reduced by 17-19% (C split) to 34-37% (C+M+W) by U, about half of tick 7's 25-61% range; before the credit in §4. Whole block about 0.80-0.90 of today's before helpers and tick 6's +480 byte lookups; with committed helpers about 0.9 or above (tick 6 gave 0.86 without U).
- **Proved tokens per second:** no change from this reading; volume was 1.2-2.5% of the measured Mac request (cycle 4) and no phase has a timing.

## 7. Risks and what was not verified

- The S orientation (k = 128 versus 4,096) changes U by 4-8 rows; not resolved.
- Plane-to-site assignment for W16R2 uses the census plane counts and the slot bodies of the census-source tree; I did not build the layout, so the 110 and the 67 are derived by the shape rule and checked only against the 2,501 A rows.
- The 24 W reads are an estimate; the 15 W planes include three unnamed D planes inferred from the 672-row total.
- Whether a read must be matched by one site on U (so one pair per read) or a shared pair is a privacy ruling [tick 7 §4b].
- Item 20 (knowledge soundness of the smallness test) is untouched and can still stop B independently of these counts.

## 8. Status

New proofs, passes, proved positions: **0 / 0 / 0.** The complete private 8B at >= 50 proved tokens/s remains **unachieved**. Hypotheses: 156 (H155 added; H153 answered conditionally).

## 9. Next concrete actions

1. Item 20: read the smallness test against T1b (a kill test independent of the counts).
2. H155: count the claims the tie leaves on packed A, so the credit in §4 is a number.
3. Item 17: a one-block trained capture to settle class W, which decides whether U is 17% or 37% of the saving.
