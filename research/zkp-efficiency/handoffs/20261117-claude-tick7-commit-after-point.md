# Research handoff: can the local schedule commit a contraction vector after the sumcheck points and before a random compression? (2026-11-17 UTC, claude tick 7)

From Claude, the background researcher (D50). Queue item 16 (the order requirement left open by tick 5). Local reading only: 0 searches, 0 fetches.

**Scope.**
- **Read directly (code, not summaries):** `hashline/src/private_block/protocol.rs` (current tree, lines 1-140 and the `prove_inner` / `verify_inner` order), the R13 frozen tree's `protocol.rs` (lines 1-60 and 1286-1340, the 8B-shaped `prove_core`), `shape.rs` (`a_groups`, `totals`, lines 2440-2560), `layout.rs` (`A_SITES`, `A_GROUPS`, `HOSTS`, lines 385-530 and 1082-1203 of the frozen tree), `zkp-core/src/pcs.rs` (`row_weights`, `zpart_weights`, `group_zclaims`, `zk_rhos`, `open_zk`, lines 200-260 and 700-945), `ZK60_D55_CONCURRENT_RUN_DESIGN.md`, `ZK60_LEAN_PRODUCTION_STATEMENTS.md` (T1b, T2), tick 5 and tick 6 handoffs. The "D55 schedule" the queue names is the D55 fork schedule; the order that matters for this question is the per-block slot-then-opening order, which D55 leaves unchanged inside a fork.
- Not read: the argument code that turns a slot's end value into a claim (`argument.rs`, `argument_accuracy.rs`); the hosting arithmetic; any verifier timing. One standard-library script, `20261117-claude-tick7-commit-after-point.py`. No build, proof, GPU run or Git write.
- **Triage material, not a work order.** Any of this changes what is committed, so it changes proof bytes and the verifier and needs the owner's ruling, a new profile string (D17) and re-proved Lean (D63). The owner shelved proof-size work on 2026-11-09; this concerns committed volume.

Labels: **COUNTED** (file:line), **DERIVED** (script), **ASSUMED**, **[tick 5/6]** (carried, not re-checked).

## 0. Headline

- **The order is satisfiable, but not by anything that exists.** Today's local "combined row" is **not** FlashProve's `U3` and cannot stand in for it. A new committed object and two to three new commit-then-challenge phases are needed after the 23 slots.
- **Cost not counted by ticks 5 and 6:** the contraction vectors need their own hiding commitment, and the local rule of one reserved mask pair per claim makes that commitment mostly mask rows: **302 to 452 rows per block if every one of the 120 A claim sites is a cell read** (DERIVED), 25% to 61% of the A data rows that candidate B saves (747 to 1,202). Whole-block volume moves from tick 6's 0.76-0.85 to about **0.79-0.94** of today's, before tick 6's helper adjustment. The lower bound depends on how many of the 120 sites are cell reads, which I did not count.
- **Also unresolved:** the authors' own caveat that the smallness test gives "no knowledge error" against the local gate T1b, which is knowledge soundness (§5).

## 1. The local order, COUNTED

`prove_inner` / `prove_core`: header, A root, M root (all 23 CFS masks, "committed before any challenge"), beta/gamma/alpha, H root, **23 masked sumchecks** (end values are hidden terminals, one claim site each), one M opening, then **one opening per commitment** (A, H, endpoints). `protocol.rs:1-3` and `prove_inner` lines 142-267 (current tree); `prove_core` lines 1129-1318 (frozen tree). The A claim sites total 120 at every shape (`A_SITES`, asserted `layout.rs:1203`); A has 35-ish column-weight groups (`shape.rs:2516`: `tzc + 15 + 4 + 8 (+2)`); `a_rows = a_data_rows + 2 * a_sites + 2` (`shape.rs:2472`).

`open_zk` (`pcs.rs:915-944`): claims are grouped by identical column weights; per group draw lambdas, form `rho = sum lambda * coef * eq(row part of point)` (`zpart_weights`, `zk_rhos`), send **`rho^T [M | pads]`** (n message plus Q pad entries, Fp2), absorb it, draw the proximity rho, send the proximity vector, absorb, **then** draw the column indices. So the order "row-contracted vector fixed after the claim points, before a later random choice" already holds, for the column challenge.

## 2. Why the group vector is not `U3`

1. **It contracts packed rows.** `rho` weights the committed rows. Candidate B commits `cell0 + 2^20 cell1 + 2^40 cell2` per word. `rho^T M` is then a sum of three lane contractions with weights 1, 2^20, 2^40 and cannot be separated; this is cycle 6b's objection, restated. A claim on one cell row needs the **cell** contraction `sum_r phi[r] cell(r, c)`, which no function of the committed words gives. (DERIVED from `zpart_weights`.)
2. **It is a lambda mixture** over all claims in a column-weight group, so it does not give one contraction per sumcheck end value.
3. **It is not committed.** It is a masked message; the mask comes from the reserved pair rows (`audit_claims`, `protocol.rs:70-140`: "every reserved pair row is touched by exactly one claim").

So a `U3` must be a separate vector per read, sent into a **hiding commitment** (an unmasked contraction of hidden activations would be a leak: k linear functionals of them). The local scheme already has several hiding commitments (A, H, two endpoints), so this is a new commitment of an existing kind, not a new primitive.

## 3. The schedule that would satisfy FlashProve's order [tick 5, mapped locally]

Today's phases, then (all after slot 23, because every read point is a slot end point):
1. **Commit U** (one read per cell-plane claim site; entries in Fp2), absorb root. Needs M and U before Theta.
2. **Draw Theta** (tau ternary entries per column).
3. **Commit Z** (the digit planes `ZZ`, plus the multiplicity bit-planes) after Theta.
4. Draw the digit-lookup challenge(s). With committed-helper LogUp (today's) a **third** commitment (helpers) follows; with FlashProve's product tree, none.
5. One new masked slot: the digit lookup (tick 5: 27 + 11 levels at the example size) with the EP / ER equations folded into its last batch (no round of their own, per tick 5).
6. Openings of A, H, U, Z (and helpers), each with its own group vectors and Q = 256 columns.

Extra commit-then-challenge alternations: **2** (product tree) or **3** (committed helpers). **Constraint from the local rules:** all CFS masks are committed in M before the first challenge, so M must be sized for the new slot(s) up front. The slot count is static, so this is legal; a 38-level slot's message length (about 40 rounds x degree 3) fits the one-row-per-slot budget "L + 256 <= 512" (`shape.rs:2452`) (ASSUMED; the message length for a 38-round slot is `(main+ext)*degree+2`, so check). Cost: a few M rows.

## 4. Cost, DERIVED (script)

- **U.** Reads at most 120 per block (one per A claim site; the number that are cell planes is **not counted**). Width k per read is its matrix's k: 4,096 (D, Q) to 14,336 (F, before the split). Data: 60 to 210 local rows (2^14 words); **mask pairs: 240 rows** (one pair per claim); plus the proximity pair: **302 to 452 rows**, or 152 to 227 if only half the sites are cell reads (ASSUMED).
- **Z.** At the local width, `2 tau mz` is 2.31 M words (141 rows) at k = 4,096 and 1.32 M (81 rows) at k = 7,168, i.e. 0.0625 and 0.036 of the cells; already in tick 5's `2 tau / k`. Z's own claims need their own mask pairs (a few).
- **Net on candidate B.** A data rows saved 747-1,202 (tick 6). U costs 25%-61% of that at 120 reads, 13%-30% at 60. Whole block **0.79-0.94** of today's.
- **Soundness.** Smallness test union bound: at most 48 matrices x k x 32 blocks gives 103.6 bits (k = 14,336) to 105.4 bits (k = 4,096) at tau = 128 [authors' form; tick 5]. Added to the 2^-97.3 whole-run bound (D55 review) the sum is 2^-97.28: negligible, if the authors' bound holds.
- **Verifier.** Theta is tau x k ternary entries per matrix point (0.52-0.92 M entries); at about 30 column groups x 32 blocks that is 0.5-0.9 G adds per receipt (DERIVED, ASSUMED unstructured Theta). Today's verifier time is not in the files I read; unmeasured.

## 4b. The mask-pair rule is the load-bearing cost

U is mask-dominated (240 of 302-452 rows) because the local audit demands one reserved pair per claim, which is what gives the opened vectors joint uniformity (`protocol.rs:70-90`). Sharing a pair between several U claims would shrink U to about 60-210 rows, but it changes the privacy argument (the block-triangular full-rank step) and needs the joint-view argument re-done. I did not evaluate it.

## 5. Falsifiable tests

- **H153 (read count).** Claim: cell-plane reads per block, with k per read, make `U` plus its mask pairs at most 20% of candidate B's saved A rows. **Test (count, CPU, no proof):** from the layout's site-to-plane map, count claim sites that touch cell planes (not tables, endpoints, H), sum k per read, add 2 mask rows per read. **Kill** if the total exceeds 20% (that is, above about 150-240 rows).
- **H154 (knowledge and the smallness test).** Claim: the smallness test can be stated inside the local T1b (extractor with binding) without a new assumption. **Test (paper):** read the source's argument and the Lean statement together; **kill** if the extractor must rewind past Theta (the authors' own note: no knowledge error).
- **Not proposed:** a prover change.

## 6. Honest effect

- **Committed words per request:** candidate B's saving shrinks by a quarter to a half once the contraction commitment is counted; the lower bound is uncertain. This is on top of tick 6's byte-split lookups.
- **Proved tokens per second:** no change from this reading; the added phases (2-3 commit rounds, a long masked lookup slot, a verifier-side Theta term) have no timings. Candidate A (lookups without committed helpers) is unaffected.

## 7. Risks and what was not verified

- I did not read how a slot's hidden end value becomes a claim site (`argument.rs`), so "one read per site" is a bound, not a count; claims with several parts could need several reads.
- The R13 frozen tree is the 8B-shaped source; the current tree's `private_block` is the toy (log_cols 8). `A_SITES` is shared; the 8B plane lists are in the R13 tree.
- No timing of any new phase. FlashProve's paper claims are [authors'] from tick 5.
- The D55 fork structure is untouched: new phases stay inside a fork. The order argument assumes a per-block transcript.

## 8. Status

New proofs, passes, proved positions: **0 / 0 / 0.** The complete private 8B at >= 50 proved tokens/s remains **unachieved**. Hypotheses: 155 (H153, H154 added).

## 9. Next concrete actions

1. H153: count cell-plane claim sites and k per read (CPU, small).
2. Coordinator: decide whether B is still costed beside A; with U counted, B's value depends on H153.
3. Owner: the mask-pair sharing question (§4b) is a privacy ruling, not a speed tweak.
