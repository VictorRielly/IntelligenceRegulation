# Research handoff: the claims the Theta tie leaves on packed A, and one U or two per split limb (2026-11-23 UTC, claude-tick 49, queue item 21, H155)

From Claude, the background researcher. One bounded cycle: local reading and arithmetic only, 0 searches, 0 fetches. No run, no build, no Git. Clock at writing 2026-11-23T16:40:47Z. **Triage material, not a work order.** Any change to what is committed alters proof bytes and the verifier and needs the owner's ruling, a new profile string (D17) and re-proved Lean (D63). The owner shelved proof-size work on 2026-11-09; this concerns committed volume, and under D80 it prices candidate B.

**Read, and how.** In full: the queue item; tick 8's handoff (sections 1 to 5), tick 5's (sections 1, 2, 4), tick 6's (sections 1 to 4), tick 7's (sections 1 to 4b). Code: `zkp-core/src/pcs.rs:715-980` (`ZPart`, `ZClaim`, `zpart_weights`, `zkey_weights`, `group_zclaims`, `zk_rhos`, `open_zk`, `verify_zk`); `hashline/src/private_block/protocol.rs:60-175` (`part_key`, `audit_claims`, `check_opening`); the census tree's `shape.rs` 2440-2650, 2751-2850 (`a_plane_doms`, `claim_sites`, `totals`, `a_groups`). Not read: `argument.rs` and `argument_accuracy.rs` (how a slot's terminal reads its planes: used from tick 8's table), FlashProve's `11-2` read descriptors (RS, RL, RX), tick 5's text taken as written. Script `20261123-claude-tick49-tie-claims.py`, output `.out.txt` beside it.

Labels: **COUNTED** (file:line), **DERIVED** (script), **ASSUMED**, **[tick N]** (carried, not re-checked).

## 0. Headline

- **H155 holds, by a wide margin: 3 to 6 claims on packed A, not 20, and the kill line (48) is far off.** The tie puts one claim per packed cell matrix on A (NM = 3 to 6 matrices by width); the digit lookup puts none on A. Net A mask rows released at the 67 cell sites: **102 to 128 of the 134** (DERIVED), against tick 8's bracket of 38 (48 claims) to 114 (10 claims).
- **That credit cuts U's net cost sharply.** Tick 8's U share of the saved A rows, 17.0% / 20.3% / 34.1% (classes C / C+M / C+M+W), becomes **6.3-6.7% / 8.6-9.0% / 18.8-19.3%** after the credit (DERIVED; tick 8's own read counts, one U per half everywhere). Z's own pairs are not in this: about +8 to +14 rows (section 3), under one point.
- **One U or two for a split limb: two where the plane's own zero-check reads it, one where only its combined value is read.** Reading-based, so it changes only class W (about 24 extra reads become about 15; U 286 to about 264 rows). With both effects the full C+M+W case is **16.2-16.7%** of the saved rows against tick 8's 34.1%, under the 20% pass line that tick 8 set. Class W is still unmeasured (item 17), so the stop condition for candidate B moves from "fails if W must split" to "marginal if W must split".

## 1. Which claims land on packed A, COUNTED and ASSUMED

- **Today's rule** (COUNTED): a claim is a `ZClaim` of `ZPart`s on one commitment; the schedule audit requires **exactly one reserved pair (two rows) per evaluation claim** (`protocol.rs:70-140`, `audit_claims`); `a_rows = a_data_rows + 2 * a_sites + 2` (`shape.rs:2762`). So mask rows on A follow the claim count and nothing else.
- **Where the digit planes go** [tick 7 section 3, step 3]: the digits `ZZ` and the multiplicity planes `BZ` are committed after Theta is drawn, while M and `U3` must be committed before it. They therefore sit in a separate commitment (Z), not in A. **The digit lookup raises no claim on packed A** (ASSUMED from tick 7's ordering; it follows from the order requirement, not from a code reading of a Z commitment that does not exist).
- **The tie** [tick 5 section 1, point 3]: equation EP is linear in each packed matrix with public coefficients (Theta). FlashProve folds EP and ER by powers of chi into its last batched sumcheck, which includes the column variables, so each packed matrix receives **one point-evaluation claim** (its `NM` term in the claim count `47 + v_Z + NM + NX`) [authors, via tick 5]. The `NX` reads are claims on `U3`, not on M, and are already priced in tick 8's U rows.
- **How many matrices**, DERIVED from tick 6's widths: matrices stack by row width k, so D and Q (4,096), Kv (1,024) and F (7,168 after the split) give **NM = 3** (S in the 4,096 stack) up to **NM = 6** (one per domain, F as two halves). The byte split of classes C, M, W adds cell rows to those matrices, not matrices.
- **Why a one-claim route is not free locally** (COUNTED): `zpart_weights` and `ZKey` build column weights only as an eq table over a point tail or as all ones (`pcs.rs:752-806`). The tie's weights, `sum_u eq(u) Theta[c][u]`, are an arbitrary vector. Two routes give the same claim count: the sumcheck route (as FlashProve; the column weights become an eq table at a shared end point, and the claim fits `ZKey`) or a new key kind (an explicit column vector, which the verifier computes at tau x k = 0.5 M adds per matrix [tick 7 section 4]). Either way one claim and one pair per matrix.
- **Groups.** The cell reads sit in 23 of A's `tzc + 27` column-weight groups (DERIVED from the comment at `shape.rs:2810-2816`: SS, SSM, RS, nine matmul and Wo reads, F, score and PV twice each, the four cubes with their partner planes, IO in and out); the non-cell groups are `tzc` plus four. After B the tie claims form 1 group (if their column tails coincide at one shared end point) to NM groups. A group vector is (2^14 + 256) Fp2 = 33,280 words, 2.03 local rows, so up to 22 vectors (about 45 rows of opening data, a proof-size item, not committed words) leave A and the proof's opening for U takes similar ones: not counted, shelved.

## 2. The count, DERIVED (script)

| Case | Claims moved off A | Pairs freed | Tie pairs kept | **Net rows released** |
|---|---:|---:|---:|---:|
| S packed in the 4,096 stack, NM = 3 | 67 | 134 | 6 | **128** |
| S packed, NM = 5 (one per domain) | 67 | 134 | 10 | **124** |
| S packed, NM = 6 (F in halves) | 67 | 134 | 12 | **122** |
| S unpacked (k = 128 stays on A; its 11 sites stay), NM = 3 | 56 | 112 | 6 | **106** |
| S unpacked, NM = 5 | 56 | 112 | 10 | **102** |

Claims left on A for cell planes: 3 to 6, or up to 17 with S unpacked (11 S sites remain). The pass line of H155 (at most 20) is met in every case; the kill (more than 48) is not near.

Net U cost against the saved A data rows, tick 8's scenarios, the credit 124-128 taken off, S packed (the S-unpacked row of tick 8 counted S reads as U reads and is not reused here):

| Scenario (tick 6, 8) | U rows, tick 8 | Saved A rows | U share, tick 8 | **U share after the credit** |
|---|---:|---:|---:|---:|
| C split only | 204 | 1,202 | 17.0% | **6.3-6.7%** |
| C + M split | 222 | 1,094 | 20.3% | **8.6-9.0%** |
| C + M + W split (one U per half) | 286 | 839 | 34.1% | **18.8-19.3%** |
| C + M + W, one combined U at combination-only sites (section 3) | about 264 | 839 | 31.5% | **16.2-16.7%** |

Z's masks are not in these rows: Z carries 2 to 4 digit-plane claims and 1 to 2 for `BZ` (two tables, 10-bit and 8-bit [tick 5]), so 3 to 6 claims, 6 to 12 rows plus the proximity pair, **about +8 to +14 rows** (DERIVED; counts ASSUMED from tick 5's list), 0.7 to 1.7 points of the shares above. Tick 7's 2 tau mz digit words are already in tick 6's `1/3 + 2 tau / k`.

## 3. One U or two for a split limb (the second part of the item)

A split 16-bit limb is `lo + 256 hi`, with lo and hi byte cells. The tie equation ER is linear in the read's row weights: `sum_i phi'[i] comb(i,u) = sum_c Theta[c][u] U_x[c]`, where `U_x[c] = sum_i phi'[i] cell(i,c)`. Taking `phi'` = phi on the lo rows and 256 phi on the hi rows gives **one U for the combined limb**, sound by linearity (DERIVED; the 2^17 offset in `val` shifts both sides by a public multiple of `sum phi'`).

- **Where two are needed** (ASSUMED from the helper relation, not read in `argument.rs`): a plane's own zero-check slot, where the lookup key relation `h (gamma + key) = 1` takes lo and hi individually (today `helpers(Dom::D)` etc. exist for exactly these keys, `shape.rs:2598-2625`), or a helper-free product-tree lookup whose leaves are the two byte cells. That is every read of the 16 C and M remainder planes, so no change for C and M.
- **Where one suffices:** the reads of W planes that enter only as a combined value: A_X (SS, IO in), A_X1 (SSM), A_X2 (IO out), A_Y (QMM, KMM, VMM, one vector), A_YM (GMM, UMM, one vector), A_H16 (DMM), A_E (RS), A_P (PV): **12 claims, 9 distinct vectors** (COUNTED from tick 8's table). Tick 8's W estimate (24 extra reads on 15 planes, every read doubled) falls to about 15 (the zero-check reads only): about 22 rows saved (9 reads at 2 mask rows plus half a data row each).
- **Condition (unverified):** the source's read descriptor must allow row weights spanning two cell-row blocks. Its reads (RS, RL, RX, `11-2`) are "a combination of `U3` entries" at the end value, which already allows two entries with public coefficients; a single entry with spanning weights is not shown. If not allowed, the two-U count of tick 8 stands and only section 2's credit applies.

## 4. Falsifiable tests

- **H155 (read): result above, holds.** Revised claim: packed A carries at most 6 tie claims per block (17 with S unpacked), so at least 102 of the 134 cell-site mask rows are released. **Kill:** a code or paper reading shows the tie needs a claim per cell plane (about 48) or per read (67). Cheapest decisive step: FlashProve `11-1` "The one equation" on whether EP's `M` term is one evaluation per matrix.
- **H157 (one U for a combination-only read).** Claim: at a site that reads only `lo + 256 hi`, one U with row weights (phi, 256 phi) passes the ER check. **Test (toy, CPU, a few KiB; extends tick 5's toy):** random byte cells, one combined read against the two-read version, honest accepted and one altered entry caught at the 2^-tau rate. **Kill:** the check fails to separate, or the source's descriptor forbids spanning weights.
- **Not proposed:** a prover change.

## 5. Honest effect

- **Committed words per request:** B's volume case improves. Whole block from tick 8's 0.80-0.90 (before helpers) to about **0.78-0.88**, because 102 to 128 rows come back from A and U's net falls (DERIVED: tick 8's whole-block figures less the credit over 5,103 rows, about 2.0 to 2.5 points, minus Z's 8 to 14 rows). Tick 6's helper adjustment (+480 byte-lookup rows if helpers stay committed) is untouched, so with committed helpers B alone is still about 0.84, and the gain needs candidate A's helper removal.
- **Proved tokens per second:** no change from this reading. Volume was 1.2 to 2.5% of the measured Mac request [cycle 4]; the digit lookup (27 + 11 levels) and Theta verification are new work with no timing.

## 6. Risks and what was not verified

- NM is derived from widths, not from a layout built for B; a layout that keeps classes in separate matrices raises it, each matrix costing 2 rows.
- "The digit lookup puts no claim on A" depends on Z being its own commitment (tick 7's order), an inference.
- One claim per matrix assumes the batched-sumcheck route (as the authors) or a new explicit-column-vector key; the local code supports neither today.
- Class W's honest RMS is still unmeasured (item 17); the 16% figure holds only if W must split and the combined read is allowed.
- Privacy: a combined U reveals one linear functional per read, fewer than two; the joint-view argument (tick 7 section 4b) is not redone and the pair-per-claim rule is unchanged.
- The knowledge-soundness question for the smallness test (item 20, tick 9) can still stop B independently of any count.

## 7. Status

New proofs, passes, proved positions: **0 / 0 / 0.** The complete private 8B at >= 50 proved tokens/s remains **unachieved**. Hypotheses: 158 (H157 added; H155 answered). Next queue item: 23 (the wrap count).

## 8. Next concrete actions

1. Item 23 (wrap count), then 18 and 17 per the coordinator's order.
2. H157's toy and the FlashProve `11-1` "one equation" reading, if candidate B is kept alive after items 23 and 17.
