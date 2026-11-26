# Research handoff: odd-factor layout for the embedding and head tables (2026-11-26, claude tick 66)

From Claude, the background researcher (D50). Queue item 105 (added by tick 61; follows tick 59's rows and tick 61's map). Clock at writing 2026-11-26T15:51Z.

**Scope.** Local reading and a toy computation only: 0 searches, 0 fetches. No build, run or Git. Written: this file and `20261126-claude-tick66-odd-factor-embedding-head.py` / `.out.txt`. Read (tree that runs, `ops/zkp-mvp/gpu-metal/`): `hashline/src/private_block/token_io.rs:350-352, 545-563, 620-766` (`MULT_BITS`, `voc_log`, `emb_fold`, `head_fold`); `token_io/stage_in.rs:160-190, 235-285` (`tau_table`, `challenges`, the TZC slot); `token_io/stage_out.rs:408-420` (`SO_HEAD`); `token_io/classify.rs:896-935`, `token_io/stage_in_c.rs:155-165, 240-260` (the classifier's fold and table); `zkp-core/src/pcs.rs:832-973` (`ZPart`, `ZClaim`, `zpart_weights`, `group_zclaims`); ticks 59 and 61 handoffs. **Triage material, not a work order:** committing the embedding or head changes what the proof commits; it needs the owner's ruling, a new profile and Lean re-proving (D63); P3 stays at study level (D82). Labels: COUNTED (file:line), DERIVED (script), ASSUMED.

## 0. Headline

- **Pass, with two corrections to the plan the item implied.** The embedding's claim point is public, so the vocabulary axis carries its odd factor as parts. But (1) at 8B the stage's table repeats row 0 on the padded vocabulary rows, which makes the odd-factor layout lose to a plain padded commitment; (2) the head's per-row multiplier is not expressible in the claim grammar at n = 2^16, so the head needs the multiplier folded into the committed words.
- **Where the odd-factor layout pays: Shieldstral (W16R2) embedding.** V = 131,072 = 2^17, d = 3,072 = 3 x 2^10: **3 parts of 2,048 rows, 6,144 rows**, **10.75 MB** an opening against **13.56 MB** padded on the width (8,192 rows, x1.333); saves 2.82 MB a request (DERIVED, script B). No pad vocabulary rows there, so no row-0 term.
- **At 8B, do not use 501 parts.** Dense is 8,016 rows (13.32 MB) plus a second column-weight group for the row-0 claim, +1.093 MB (one group = (n + qpad) x 16 B), i.e. 14.41 MB; the padded vocabulary with row-0 copies is **one plain claim, 8,192 rows, 13.56 MB**, no parts (script A1b). Padded wins by 0.85 MB for the embedding.

## 1. The embedding claim: is the point public (the item's fail line)

No: the fail line does not fire. The verifier's O(V d) fold is `emb_fold(r_emb)` (`token_io.rs:710-717`, classifier `classify.rs:896`), with `r_emb` a transcript challenge of `clog2(d_pad)` bits (`stage_in.rs:277-282`, `stage_in_c.rs:249-253`). Its output `ef[v] = E~(v, r_emb)` enters only the public table `tau(v) = v + beta ef[v] + g` (`stage_in.rs:185-187`), which the TZC slot reads as a public column (`stage_in.rs:244`). A sumcheck over that slot ends at a challenge point rho over `voc_log` bits (`token_io.rs:545-547`; `max(log_v, stage_log_n)` and the one tier constant found, R1_MVP, has `stage_log_n = 12`, `:190`, so 17 bits at both profiles; other tiers not read). The verifier's evaluation of the public column at rho is therefore a claim `E~(rho, r_emb)` on the committed embedding at a public point. The hidden token index enters only the A side (`tok`, committed). Both coordinates are challenges, so the grammar of `ZPart`/`ZClaim` applies as in tick 61.

## 2. Embedding counts (COUNTED shapes, DERIVED arithmetic)

| | 8B embedding | W16R2 Shieldstral embedding |
|---|---|---|
| V, d | 128,256 = 501 x 2^8; 4,096 = 2^12 | 131,072 = 2^17; 3,072 = 3 x 2^10 (d_pad 4,096) |
| words | 525,336,576 | 402,653,184 |
| rows at n = 2^16, dense | **8,016** (tick 59 confirmed) | **6,144** |
| rows, padded | 8,192 (x1.022) | 8,192 (x1.333) |
| parts a claim | 501 (16 rows each) | 3 (2,048 rows each) |
| one opening, dense / padded | 13.32 / 13.56 MB | 10.75 / 13.56 MB |

Part geometry: at 8B each part is the 2^8 low vocabulary indices x 2^12 widths = 2^20 words = 16 rows; coef = `eq(rho[..9])[v_hi]` for v_hi < 501; the part's point is `rho[9..17] ++ r_emb` (20 bits), `lr = 4`, tail = the last 16 bits, the same for every part, so `group_zclaims` (`pcs.rs:934`) keeps one group. At Shieldstral the odd factor sits on the width: coef = `eq(r_emb[..2])[d_hi]`, d_hi < 3, slice = V x 2^10 = 2^27 words, `lr = 11`, tail = 16 bits. Toy check (script A1, Goldilocks, n = 2^3, five shapes with odd factors on V, on d, or both): the parts reproduce the padded table's multilinear value in all five.

**The row-0 term (COUNTED, new).** `tau_table` gives padded vocabulary rows the value `beta ef[0] + g` (`stage_in.rs:185-187`; the classifier's the same with `ctl`, `stage_in_c.rs:160-163`). So `tau~(rho) = ident + beta * E~(rho, r_emb) + g * (1 - m) + m * (beta E~(0, r_emb) + g)` with `m = sum_{v >= V} eq(v; rho)`. The second claim `E~(0, r_emb)` is a one-row slice with column key (tail = `r_emb`, 4,096 columns), different from the main key, so it is a second group (+1.093 MB). Script A1 checks this identity. Options at 8B: (a) dense + row-0 group, 14.41 MB; (b) commit the vocabulary padded to 2^17 rows with rows >= V holding a copy of row 0: one plain claim, 13.56 MB, no parts (script A1b, three shapes pass); (c) change `tau_table`'s pad rows to a constant (a stage change). (b) is simplest and smaller than (a). At Shieldstral V = V_pad, so there is no row-0 term and the dense odd-factor layout is the right one.

## 3. The head (8B only; the classifier has no head)

`head_fold` (`token_io.rs:733-750`) builds `wf[i] = sum_{j<V} eq(r_j)[j] m_j W'[j][i]` over `d_pad` entries, and `SO_HEAD` multiplies it by the committed `y` at a point over the width bits (`stage_out.rs:408-419`); `r_j` is a transcript challenge (`vo_log` bits), pad rows are excluded by `e[..tp.v]`. So the claim point is public here too. But `m_j` is a per-row public integer in `[1, 2^12]` (`MULT_BITS`, `token_io.rs:352`), and `zpart_weights` can weight a row only by `coef * eq(point[..lr])` (`pcs.rs:869-909`).

- **Left outside the words, the claim does not fit at n = 2^16.** A commitment row holds 65,536 / 4,096 = 16 vocabulary rows with 16 different `m_j`, so the claim's column-weight vector differs on every commitment row: up to **8,016 groups**, 8.76 GB a request (DERIVED, script C). The only in-grammar form is n = 4,096 (one vocabulary row per commitment row, one part per row), which multiplies the column part of tick 54's best row by 16; not priced.
- **Folded into the words it fits.** Commit `W''[j][i] = m_j W'[j][i]` (|w| <= 127 x 2^12 = 520,192 < 2^19; one 8-byte field word, no extra receipt bytes). The claim is then an ordinary `W''~(r_j, rho_d)` at a public point (script A2, three shapes pass; parts as in section 2: 501 at 8B). Pad rows are zero, so the padded form needs no row-0 term: **8,192 rows, 13.56 MB, one part**, against 13.32 MB dense with 501 parts (+0.24 MB for dropping the parts). Recommendation as a reading, not a decision: padded for both tables at 8B (27.12 MB, against tick 59's 26.64 MB dense).
- What a folded `W''` costs the statement is NOT verified: the keyed-difference bound (`token_io.rs:511-513`) is built from the int8 class and the multiplier class separately; a committed `W''` is bound by the model's identity (an outside hash), not by the proof, so the bound's premises move from "checked" to "committed". Whether that is acceptable is the owner's and Lean's question. Alternative, not costed: commit `W'` and `m` apart and reduce the product with a 17-round masked sumcheck (a new slot).

## 4. Effect

Committed words a request: embedding + head 8B 1.0507 G dense, 1.0737 G padded (+2.2%); Shieldstral embedding 402.7 M dense against 536.9 M padded (-25%). Receipt bytes of P3: embedding + head at 8B 27.1 MB padded (+3.3% of today's 818.7 MB, as tick 59's dense 26.6 MB); Shieldstral embedding 10.75 MB, 2.82 MB less than padded. Proved tokens per second: none; the row combination is after the stream's per-block clock (tick 59).

## 5. Falsifiable tests (not run)

- **T-E1 (Rust).** In a small `TokenProfile`/`ClassifierProfile` with V = 12 (odd factor 3) and d = 8, compute `tau_table`, commit the padded vocabulary with row-0 copies via `commit_zk`, open one `ZClaim` at a random public rho and `r_emb`, and compare `tau~(rho)` computed from the table with `ident + beta claim + g`. Pass: equal; fail: any difference, then the copy rule or the point order is wrong.
- **T-E2 (head).** Commit `m_j W'` for a small head and compare `head_fold` contracted with a random `rho_d` against the opened claim. Pass: equal.
- **T-E3 (bytes).** `open_zk` wire length at 1/64 scale for 8,016 and 8,192 rows and for the 3-part Shieldstral claim. Pass: within 1% of section 2.

## 6. Risks and what was not verified

- The toys are algebra over the base field; the Rust opening was read, not run. The bit order of rho (vocabulary bits first) is as the stage's table indexing (`tau_table` over `v`), not read in the sumcheck end-point code.
- Only tier R1_MVP's `stage_log_n` was found; a tier with `stage_log_n > 17` would make the vocabulary cube larger and add pad rows.
- Layout, copies and `W''` are new committed objects; today's statement hashes `emb` and `head` words and `mult` separately (`token_io.rs:664-689`), so a P3 statement, profile and Lean model are needed (D63). The margin vector `w_delta` (tick 59: one extra row) was not reread.
- Tick 59's 8B `emb` and `head` rows (8,016) stand; its "embedding at V_pad" row (8,192) is now the recommended 8B form.

## 7. Status

Proofs / passes / positions: 0 / 0 / 0. Complete private 8B at the target: unachieved. Hypotheses: H171 (P3 embedding and head claims have public points; at 8B commit them padded with row-0 copies and a multiplier-folded head, 27.1 MB; at Shieldstral the 3-part odd-factor layout saves 2.82 MB; T-E1 to T-E3).

## Coordinator's check (2026-11-26)

The script was re-run by the co-coordinator with the heavy lock free: the output is identical. Read by me in the code that runs (`ops/zkp-mvp/gpu-metal/`): `stage_in.rs:185-186, 244-249, 283`; `stage_in_c.rs:160-163, 221, 258, 272`; `token_io.rs:190, 352, 513, 545-546, 641-689, 706-717, 729-750`; `stage_out.rs:411-419`; `classify.rs:167, 1222-1223`; `zkp-core/src/pcs.rs:832-951`. The row, part and byte figures of sections 0, 2 and 4 were recomputed by me from the same formula.

**Carried forward [reading and formula-level arithmetic; nothing built or run]:** the item's fail line does not fire (both tables enter their slots as public columns built from transcript challenges; the hidden token is on the committed side); the row and part counts of section 2; the row-0 term of the stage's table and its cost of one more group at 8B; the three-part layout for the classifier's embedding.

**Corrected: section 3's count for the multiplier left outside the committed words.** The handoff says the claim "does not fit" at n = 2^16 and counts up to 8,016 groups, 8.76 GB. That is the count for ONE claim holding every vocabulary row, which the grammar refuses (`pcs.rs:934`). But the grammar also takes a slice smaller than a row at a column offset (`pcs.rs:900-905`; its column weights are placed on that range, `:911-923`). So the head claim splits into one claim per column range of a commitment row: 65,536 / 4,096 = 16 claims, each with one part per vocabulary row at that offset, coefficient `eq(r_j)[j] * m_j`, point `rho_d`. That is **16 groups: 29.71 MB dense, +16.39 MB over the folded form** (same formula). `20261126-claude-tick66-odd-factor-embedding-head-crosscheck.py` ports the three grammar functions and reproduces the head claim's value on five toy shapes with exactly n / d_pad groups (output beside it). This route keeps the int8 words and the multiplier class of the keyed-difference bound as they are today, but the coefficients contain the multipliers, so it needs them public. Whether a hidden-weights profile may publish them is the owner's question; if not, the folded form or the product sumcheck of section 3 remains.

**Line corrections.** `r_emb` is drawn at `stage_in.rs:283` (cited 277-282) and at `stage_in_c.rs:258` and `:272` (cited 249-253). `token_io.rs:664-689` is the head's digest, which hashes the head words and the multipliers under one hash; the embedding's digest is `:641-662`.

**Not carried:** the byte figures as more than formula-level (they use tick 54's parameter row for a profile that does not exist); "padded for both tables at 8B" as a recommendation; the bit order of the end point and tiers other than R1_MVP (the handoff says neither was read).

**My own remark, read and not tested.** The stage-IN slot forces the multiplicity and the helper to zero on padded rows (`stage_in.rs:249`, `pad = (1 - supp)(m + zeta h)`), and its relation at `:248` then holds there for any table value. So option (c) of section 2, a constant on the padded rows, would remove the row-0 term and leave the dense 8B embedding at 13.32 MB in one group. Either way it is a change of the stage's table definition for a new profile.
