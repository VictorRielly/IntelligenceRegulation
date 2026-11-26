# Research handoff: can one opening group carry a block's seven committed-weight claims (2026-11-26, claude tick 63)

From Claude, the background researcher (D50). Queue item 106 (added by the co-coordinator at the triage of tick 61; tick 54's test T-P3c). Clock at writing 2026-11-26T03:52Z.

**Scope.** Local reading and arithmetic only: 0 searches, 0 fetches. No build, run or Git. Written: this file and `20261126-claude-tick63-weight-group-merge.py` / `.out.txt`. Read (tree that runs, `ops/zkp-mvp/gpu-metal`): `zkp-core/src/pcs.rs:832-973` (ZPart, ZClaim, ZKey, `zpart_weights`, `group_zclaims`, `zk_rhos`); `hashline/src/private_block/argument.rs:3218-3259` and `:3367-3400` (the seven matmul slots, where each folds the public weight and sets its point); `slot_ir.rs:1264-1265, 1328-1330, 1386-1414` (hosted matmul totals); `shape.rs:2607, 2683-2693` (per-slot main rounds); `layout.rs:112-164` (the P-3 lift, the other place the refusal is documented); ticks 54 and 61 and their scripts. **Triage material, not a work order:** any merge changes the slot schedule, the transcript, the verifier and the Lean statements; it needs the owner's ruling, a new profile and re-proving (D63). P3 stays at study level (D82). Labels: COUNTED (file:line), DERIVED (script), ASSUMED, NOT VERIFIED.

## 0. Headline

- **No, not in today's protocol.** The seven claims are at seven different points, and the column tail of each contains that slot's own sumcheck challenges. One group needs one tail (`group_zclaims` asserts `key2 == key` inside a claim and groups across claims by `ZKey` equality, `pcs.rs:934, 939`); seven independent tails give **seven groups a block**. A merge to one group exists on paper, with a named change (section 3), but it is a rewrite of the matmul slots, not a PCS option.
- **The four figures (n = 2^16, rate 1/4, k = 16, Q' = 172, wire formula as in ticks 54, 59, 61; DERIVED, script B):**

| profile | layout | 1 group a block | 7 groups a block | G=7 / G=1 |
|---|---|---:|---:|---:|
| 8B (32 blocks, today 818.7 MB) | dense (3,328 rows) | 219.9 MB (x1.27) | **429.6 MB (x1.52)** | x1.95 |
| 8B | padded (3,712 rows) | 236.8 MB (x1.29) | **446.5 MB (x1.55)** | x1.89 |
| classifier (26 blocks, today 669.6 MB) | dense (1,776 rows) | 123.1 MB (x1.18) | **293.6 MB (x1.44)** | x2.38 |
| classifier | padded (3,712 rows) | 192.4 MB (x1.29) | **362.8 MB (x1.54)** | x1.89 |

  "x" is (today + added) / today. Four groups (the partial merge of section 3): 324.7 / 341.7 MB at 8B, 208.3 / 277.6 MB at the classifier.
- **Restatement of earlier megabytes with their group count.** Tick 54's 220 MB (x1.27) is dense rows at **one group** (its 430 MB is seven; matches 429.6 here). Tick 61's 219.9 / 236.8 MB (8B) and 123.1 / 192.4 MB (classifier) are all **one group a block**; at seven groups they are the figures above. Tick 59's 13.32 MB each for embedding and head is one group each (ASSUMED one claim a table; the head claim form was not read); a second group adds 1.09 MB each. **The one-group figures therefore understate the weight opening by x1.9 to x2.4 unless the merge below is built.**

## 1. Where each claim's point comes from (COUNTED)

Each of the seven matmul slots is its own sumcheck with its own challenges (`shape.rs:2683-2693`: main rounds `clog2(d_pad)` for Q, K, V, G, U; `clog2(q_pad)` for Wo; `clog2(f_pad)` for Wd). In each, the verifier first draws the output-axis point `r_j` (`argument.rs:3236`; `:3373`), folds the public weight by `eq(r_j)` into a table (`fold_rows_i8` / `fold_cols_i8`, `:3243-3251`, `:3383-3392`), and the sumcheck then ends at the slot's own `rho`. The weight claim a P3 prover would need is the committed weight at (r_j, rho), where the verifier now computes it by folding.

- `r_j` is a verifier draw made before the slot, and K and V draw their own (`:3236` runs for each); only `r_q` (Q, and K, V reuse it) and `r_tf` (G, U) are shared (`:3220, :3369`).
- `rho` is the slot's sumcheck output: seven slots, seven independent vectors. Hence **seven distinct column tails** whenever the 2^16 columns contain any inner-axis coordinate.
- Bit counts at the 8B profile (script A): r_j 12, 10, 10, 12, 14, 14, 12 bits; rho 12, 12, 12, 12, 12, 12, 14 bits (Wq, Wk, Wv, Wo, Wg, Wu, Wd). The smallest output axis is 10 bits, so a tail of verifier-drawn bits only can be at most 2^10 columns wide.

## 2. Why no cheaper layout fixes it

- A layout is a free bit permutation of the claim point, so it can choose which 16 coordinates form the tail, but it cannot make a sumcheck output common to seven slots.
- A tail of r_j bits only (which could be shared by drawing them once) needs n <= 2^10. At n = 2^10 a block has 212,992 rows and the column part alone, at Q' = 172 (a lower bound, Q' grows for narrow rows), is **293.1 MB a block, 9.4 GB at 32 blocks** (DERIVED, script C). Tick 54's width argument (2^16 is the byte minimum) stands.
- The cost of a group is its vector: (n + q_pad) x 16 B = 1,092,608 B a block, **34.96 MB at 32 blocks, 28.41 MB at 26** (script C), independent of the layout.

## 3. The change that would give one group (paper design, not verified in the code)

Replace the seven matmul slots by one batched matmul sumcheck of 14 rounds in which every instance uses the **same first 12 challenges** (a shorter instance runs only those; the 14-bit Wd instance runs two more), and draw **one common 4-coordinate low output point** `r_lo` that every r_j ends in. Layout: row-major with the column axis (16 bits) = `r_lo` (4) + the 12 shared inner coordinates; Wd's two extra inner coordinates and every matrix's remaining output coordinates go on the row axis (row weights are arbitrary vectors, `pcs.rs:957-964`, and tick 61's odd-factor parts keep one tail). Then all parts of all seven claims have the tail (r_lo, c_1..c_12), one `ZKey`, one group.

Consequences, each NOT verified in the code:
1. **Soundness of correlated r_j.** Each slot's check sees r_j marginally uniform, so each slot's error is unchanged and the union over seven slots applies; a Lean statement is needed that says so. Hiding (T2): fewer opened vectors, not more, but a new simulator case.
2. **Hosted totals.** Each matmul total is consumed by a hosted term of a later zero-check slot (`slot_ir.rs:1264-1265` Wo and Wd in the D slot, `:1328-1330` G and U, `:1413-1414` the Q-PV and K-V pairs, each batched there with its own nu). A batched matmul slot still has to hand each hosted term its own total at its own point, so the totals must be separate claims plus a lambda drawn after them. That is a change to the schedule (`slots()`), the transcript order and the hosted-term list, not read through here.
3. **Activations.** Q, K, V read `A_Y` at (r_q, rho): after the merge the three A claims are one point (saves two A claim reads, ASSUMED). G, U read `A_YM` at (r_tf, rho); Wo reads `A_O8`; Wd reads `A_H16`; each stays a separate A claim at the shared rho.
4. **Partial merge, four groups.** Only Q, K, V (same plane, same r_q, same inner d) and G, U (same plane, same r_tf, same inner d) can share a sumcheck without changing which planes are read together: groups become {QKV}, {Wo}, {GU}, {Wd}. Bytes in the table (4 groups). Whether Wo and Wd can join is the question of item 2 above.
5. A profile change: new slot schedule, new transcript, verifier change, the Lean statements of D63 (T1a/T1b: the extractor's claim list; T2: the simulator), all after the owner's ruling.

## 4. Effect

- Committed words: none. Receipt bytes of a P3 profile only: the weight opening is **x1.5 (dense) to x1.55 (padded) of today's 8B receipt at seven groups, x1.27 to x1.29 at one** (classifier x1.44 to x1.54 against x1.18 to x1.29). The merge is worth 209.7 MB at 8B (both layouts) and 170.5 MB (dense) or 170.4 MB (padded) at the classifier, a receipt. The device and host time of a batched sumcheck are not estimated (a sumcheck over 2^12 to 2^14 is small next to the 3.7 s call, but this tick counted nothing about it). No proved-tokens-per-second effect at P1.

## 5. Falsifiable tests (not run)

- **T-G1 (the groups, Rust, no GPU).** Build the seven weight claims of a toy block at small shape with the points the slots draw today, call `group_zclaims` through `pcs`, count groups. Pass: 7 (the "no" of section 0). Fail: fewer, then two slots share a tail and the figure above is too high.
- **T-G2 (the merge, paper then Rust).** Write the 14-round batched instance at a toy shape (d = 16, q = 16, kv = 4, f = 64) with a common r_lo and verify that the seven claims fall in one `ZKey`. Pass: one group and the sumcheck verifies honest and rejects each tampered round; fail: any claim's tail differs.
- **T-G3 (the bytes).** `open_zk` wire length at 1/64 scale with 1, 4 and 7 groups (same harness as ticks 59 and 61's T-C1/T-D2). Pass: within 1% of the table.

## 6. Risks and what was not verified

- The slot-level reading of section 3 item 2 is shallow: the hosted-claim mechanism (`hosted = vec![...]`, `slot_ir.rs:194-202`) was not read, so a merged slot may be harder or easier than stated.
- P3 does not exist in the code: no weight claim site, no commitment. Everything about the claim is inferred from the public fold (`argument.rs:3243-3251`).
- A profile with different inner and output widths changes the bit counts (a 12-head profile, Shieldstral's 3,072 = 3 x 2^10 widths under tick 61's layout); the 8B counts were used and the classifier reuses them for G (same padded axes: d_pad 4096, f_pad 16384 at both, from tick 61).
- Q' = 172 and the wire formula are tick 54's; no opening of a weight commitment has been measured.

## 7. Status

Proofs / passes / positions: 0 / 0 / 0. Complete private 8B at the target: unachieved. Hypotheses: H170 (seven weight claims are seven groups today, 429.6 / 446.5 MB at 8B; one group needs one batched matmul sumcheck with a common r_lo, 219.9 / 236.8 MB; tests T-G1 to T-G3).
