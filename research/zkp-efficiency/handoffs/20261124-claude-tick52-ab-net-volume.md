# Research handoff: net block volume of candidate B together with helper-free lookups (2026-11-24 UTC, claude tick 52, queue item 18, H152)

From Claude, the background researcher. One bounded cycle: local reading and arithmetic only, 0 searches, 0 fetches. No run, no build, no Git. Clock at writing 2026-11-24T03:57Z. **Triage material, not a work order.** Any change to what is committed alters proof bytes and the verifier and needs the owner's ruling, a new profile string (D17) and re-proved Lean (D63). The owner shelved proof-size work on 2026-11-09; this concerns committed volume and prover time under D80.

**The question.** Whole-block rows and words for candidate B (packed byte cells, ticks 5 to 9, 49 to 51) and candidate A (lookups with no committed helper columns: LogUp-GKR of cycle 6a, or the product tree of tick 3) together, with the digit lookup's added levels, tick 7's contraction commitment U with its mask pairs, on the split layout of tick 6. Items 19 and 20 left B alive (conditionally), so the item runs.

**Read, and how.** Ticks 3, 6, 7, 8, 49, 50, 51 and cycle 6a in full; their numbers are carried and labelled. Code in the tree that runs (`ops/zkp-mvp/gpu-metal/hashline/src/private_block/`): `shape.rs` 2462-2492 (`a_plane_doms`), 2520-2535 (`lookups_per_position`), 2563-2590 (`helpers`, `h_plane_doms`), 2751-2762 (`totals`); `range16.rs` 164-194 (`widths`) and 195-215 (`Fam`, `sub_planes`); census rows from `results/zk60_effplan_20261105/census.log`, produced by that tree. Not read: `claim_sites` in this tree (tick 8's count of 110 A and 43 H sites from the census tree is carried; the census header reproduces 2,501 A rows = 2,279 + 2 x 110 + 2), `argument.rs`, FlashProve's verifier. Script `20261124-claude-tick52-ab-net-volume.py` (reuses tick 6's plane classes and cost function), output `.out.txt` beside it.

Labels: **COUNTED** (file:line), **DERIVED** (script), **ASSUMED**, **[tick N]** carried.

## 0. Headline

- **With helpers kept, B is 0.81 to 0.91 of today's block, not 0.78 to 0.88.** The digit lookup needs its own helpers while helpers are committed (one Fp2 per two lookups, so as many rows as the digit planes: 142 / 159 / 191 rows for C / C+M / C+M+W, DERIVED; tick 7 section 3 named the third commitment, tick 49's figure left it out). With two byte lookups (tick 6) it is 0.90 to 1.00: B alone does not pay without A.
- **A alone (all lookups in the tree) is 0.49 to 0.52** of today's 5,103 rows, against cycle 6a's 0.508 (G2) and 0.492 (G3). The spread is the claim sites the lookups' terminal claims put on the block: 0 (merged into existing end points) to 62 (one per lookup column plus the 15 multiplicity planes); 6a's G3 dropped 82 H mask rows and added none.
- **A and B together: 0.27 to 0.31 (C), 0.30 to 0.34 (C+M), 0.36 to 0.41 (C+M+W)** with field multiplicities (LogUp-GKR route); **0.29 to 0.38, 0.31 to 0.41, 0.37 to 0.48** with tick 3's multiplicity bit planes. Words: 22.8 to 25.9 M per block (C, LogUp-GKR) against 83.6 M today, or 29.8 to 34.1 M (C+M+W); a request moves by about 1.8 points more than the block ratio because 1,252 rows stay (0.28 to 0.32 for C). M rows, which the 5,103 leaves out, add 12.5 to 37 local rows.
- **B is worth more beside A than alone, by exactly the digit helpers.** B's rows saved: 969 / 828 / 498 alone (helpers kept, recombined keys) against 1,114 / 988 / 691 on top of A (favourable end), a gain of 145 to 193 rows. With the helpers gone, the block is 0.49 of today and 91% of it is A data, so B is the remaining lever: it cuts that block by about 44% (C) to 28% (C+M+W).
- **The speed reading is much weaker than the volume reading.** Volume reaches the stream only through the A and H commits (25.5% of a request's 2.968 s device work, tick 42). Ceilings at full pass-through, as a share of the 3.7455 s cadence (rule of tick 22): B alone 3.8% (C) or 1.8% (C+M+W); A alone 9.8 to 10.3%; A+B 10.5 to 14.7%. These are before any tree, U or digit work, and cycle 6a's prior ESTIMATE for the lookup tree is 0.040 to 0.105 s per block on Metal against a block GPU of 0.0915 s: the tree could cost as much as the commits it saves. No supported rate figure above 6a's x1.07 to x1.25 for A.

## 1. Rows, with the pieces (DERIVED; rows are 2^14 words, an Fp2 row counts 2)

Today (COUNTED): A data 2,279, A masks 222, H data 2,514 (range helpers 2,162, table 30, exp/act 320, u 2), H masks 88, total 5,103.

| Block | A data | A masks | U (rows, with pairs) | Z masks, BZ | H data + masks | Rows | Ratio |
|---|---:|---:|---:|---:|---:|---:|---:|
| B alone, C, recombined keys, helpers kept | 1,077 | 222 - 128 | 204 | 8 + 4 | 2,602 + 142 + 2 | 4,134 | 0.810 |
| B alone, C+M+W, same (unfavourable end) | 1,440 | 222 - 122 | 286 | 14 + 4 | 2,602 + 191 + 2 | 4,639 | 0.909 |
| A alone, G2, merged claims | 2,279 | 222 | none | none | 2 + 4 | 2,507 | 0.491 |
| A alone, G2, a site per lookup column + 15 | 2,279 | 222 + 124 | none | none | 2 + 4 | 2,631 | 0.516 |
| A + B, C, field multiplicities, favourable | 1,077 | 222 - 128 | 204 | 8 + 4 | 2 + 4 | 1,393 | 0.273 |
| A + B, C+M+W, bit planes, unfavourable | 1,440 | 222 - 122 | 286 + 202 (terminal reads) | 14 + 4 + 360 | 2 + 4 | 2,442 | 0.479 |

Notes. The credit (A pairs released at the cell sites, 122 to 128) and the Z pairs are tick 49's; U rows are tick 8's. The H side after A is the `u` plane alone (2 rows, one site: 4 mask rows); G1 (exp/act helpers stay) is 0.555 to 0.579 for A alone.

## 2. What appears only where A meets B (not in any earlier tick)

1. **Lookup terminals on cell planes become U reads.** A tree's last layer claims the key planes at the tree's end point, which is not the zero-check slot's point. Every cell-domain plane is a key (lookups per position D 19, Q 6, Kv 6, S 7, F 7 over 19, 6, 6, 8, 9 planes, COUNTED `shape.rs:2520-2535`, `a_plane_doms`): **45 key planes**, 29 rows of U data with one U each, plus a second U for each split half of a recombined key (9 / 16 / 31 for C / C+M / C+M+W, tick 51's two-U rule). Cost in rows: about 45 to 53 with one pair per domain tree, **144 to 202 with a pair per plane read** (tick 8's 2.65 rows a read), 0 if a claim-merging sumcheck moves the terminal onto the existing end points (a new masked slot, not priced). The unfavourable column includes the middle case.
2. **Multiplicities.** Tick 3's product tree needs them as bit planes: 15 tables, 20 to 25 bits each (the four sub-planes of the 16-bit family can see all 2^25 lookups; the other 11 tables at most their own plane sizes, ASSUMED 21 bits mean, COUNTED families by `range16.rs:164-194`, not mapped plane by plane): 300 to 375 rows, mid 331, against 15 with field multiplicities (LogUp-GKR): +285 to +360, or +85 to +110 if the bits pack three to a word (radix 2^20; they pass the smallness test trivially; a boolean zero-check is new work). That is 11 to 14% of A alone's 2,507 rows: **the two A routes are not equivalent in volume**, and cycle 6a priced only the field route.
3. **The digit trees.** Digit leaves are 2.33 / 2.60 / 3.12 M words (= 2 tau mz), +7.2 / 8.1 / 9.7% on the block's 32.28 M lookups, each of the two digit trees about 2^20.2 to 2^20.6 leaves (20 to 21 levels; tick 5's 27 at the authors' example size). A recombined key keeps the main tree's lookup count unchanged (tick 51), so B adds leaves only through the digits.

## 3. Falsifiable tests

- **H152b (count, CPU).** Claim: A + B (C, field multiplicities) is at most 1,800 rows (0.35 of today). **Test:** the census on a layout with helper planes deleted, class C planes as byte planes, the digit planes and U; **kill** if above 1,800 rows.
- **H158 (reading).** Claim: the lookup terminals can be merged onto the zero-check slots' end points by a masked claim-merging sumcheck. **Test:** read how a slot end value becomes a claim (`argument.rs`) and the tree's last layer; **kill** if each tree keeps its own end point, then 144 to 202 rows (or 45 to 53 per tree) are real.
- **H159 (count).** Claim: summed multiplicity bits are under 150 rows. **Test:** lookups per table from the plane lists, bits = ceil(log2(N_t + 1)); **kill** if above 150: the field-multiplicity route (LogUp-GKR) is then the one to cost, and 6a's H136 time test (tree above 0.11 s per block on Metal) decides the speed side.

## 4. Honest expected effect

- **Committed words per request:** A + B about 0.28 to 0.32 (C), 0.31 to 0.35 (C+M), 0.36 to 0.42 (C+M+W) of today's with field multiplicities; up to 0.49 with bit planes and per-plane terminal reads. B alone about 0.81 to 0.91.
- **Proved tokens per second:** not supported above 6a's x1.07 to x1.25 for A; B's own commit saving is at most 1.8 to 3.8% of cadence alone and at most 4.4 points more on top of A (C, favourable end; 14.7% against 10.3%), before its new work. Under the 5% rule nothing is scheduled; the decisive unknown is the Metal time of the lookup trees.

## 5. Risks and what was not verified

- Class W's honest RMS (item 17) is unmeasured: C+M+W is the pessimistic row and decides how much of B survives (0.27 against 0.36).
- U rows, credit and Z masks are carried from ticks 8 and 49 and rest on their ASSUMED reads; the S-unpacked variants (+140 A rows, credit 102 to 106) are not computed here.
- Sites per tree, per-plane multiplicity bits and the M-row increment (cycle 6a's 48 to 144 rows) are ASSUMED; the lookup tree's masked ZK design is the local, unreviewed one (6a section 3).
- Commit time taken proportional to rows (NTT and hash); the tree and digit work have no timing.

## 6. Status

New proofs, passes, proved positions: **0 / 0 / 0.** The complete private 8B at >= 50 proved tokens/s remains **unachieved**. H152 answered; H152b, H158, H159 added.
