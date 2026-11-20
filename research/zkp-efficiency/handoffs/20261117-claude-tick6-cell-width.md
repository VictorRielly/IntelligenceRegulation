# Research handoff: columns per cell matrix and honest cell size per plane (2026-11-17 UTC, claude tick 6)

From Claude, the background researcher (D50). Queue item 15 (H150, H151 of tick 5). Local counting only: no web search, no page fetch.

**Scope.**
- **Read directly:** `accuracy_layout.rs` (the W16 plane list `new_w16` lines 113-160 and the lookup list `lookups_w16` lines 296-343), `range16.rs` (`limbs_of`, lines 114-121), `accuracy_precision.rs` (the derived remainder windows, lines 55-100), `shape.rs` (profile W16R2_8B_T128_H24, line 302) and `results/zk60_effplan_20261105/census.log` lines 218-237, all in the retained census tree `results/zk60_sol_20261105_block_inventory/census-source/hashline/src/private_block/`. Tick 5's handoff for the mechanism and the window numbers.
- No prover run, no witness capture, no build. One standard-library script, `20261117-claude-tick6-cell-width.py` (under a second, reads no file). No Git write.
- **Triage material, not a work order.** Any change to what is committed alters proof bytes and the verifier and needs the owner's ruling, a new profile string (D17) and re-proved Lean (D63). The owner shelved proof-size work on 2026-11-09; this concerns committed volume.

Labels: **COUNTED** (file:line), **DERIVED** (arithmetic in the script), **ASSUMED**, **[tick 5]** (carried from the prior handoff, not re-checked).

## 0. Headline

- **H151 is killed as written, by a count, independent of the calibration.** 480 of the 2,256 A cell rows (21.3%; 21.1% of all 2,279 A data rows) are 16-bit lookup limbs, which are uniform on [0, 2^16): centred RMS 18,919 against a cap of about 453 (k = 4,096) or 342 (k = 7,168). The pass condition was "under 10%". **The W16 layout's 16-bit limbs are the opposite of what the smallness test needs**; byte re-expression undoes D54's widening in A (R13 had byte limbs).
- **H150 holds only where rows are wide.** Row width k follows the per-token channel count (below). D, Q and F pass (k = 4,096 to 7,168, cell part 0.40 to 0.37 of unpacked); Kv (k = 1,024) gives 0.58; scores S as a T by T matrix (k = 128) would cost more than today and stay unpacked.
- **Honest total for the cell part:** after byte splitting and digits, the 2,279 A data rows become **about 1,080 to 1,530**, i.e. **0.47 to 0.67 of today's A data rows** (DERIVED, five scenarios in §3), not the 1/3 of a naive three-cells-per-word count. Against the whole block's 5,103 rows that is **0.76 to 0.85 of today's volume**, before helpers and masks change. A new cost appears: every split limb is two byte lookups where one 16-bit lookup stood (§4).
- Pass for B (queue text: weighted k >= 4,096 and under 10% of A rows above RMS 450): **k part met (5,149 to 5,599 row-weighted), RMS part failed.**

## 1. k per cell matrix (item 15, first half)

FlashProve's matrix has rows along the contracted axis and k columns; the verifier rejects k above 8,191 [tick 5]. Here the natural column count is the per-token channel width of the plane. The domains (`shape.rs:302`, census.log): T = 128 tokens, width 4,096, hidden 14,336, 32 query heads, head dim 128, 8 KV heads.

| Domain | Planes (A) | Rows per plane | k (natural) | Note |
|---|---:|---:|---:|---|
| D (residual, norm, projections out) | 19 | 32 | 4,096 | COUNTED |
| Q (q, qr, o) | 6 | 32 | 4,096 | 32 heads x 128 |
| Kv (k, v, kr) | 6 | 8 | 1,024 | 8 heads x 128 |
| F (gate, up, h) | 9 | 128 | 14,336, so **7,168 after splitting in two** | 14,336 > 8,191, tick 5's cap |
| S (scores, exp, prob, remainders) | 8 | 32 | **128** per head, or 4,096 if heads sit in the columns | orientation is a layout choice that must match the sumcheck's contracted axis; ASSUMED, not read |

DERIVED (script): row-weighted mean k = 5,149 (S at 128) or 5,599 (S at 4,096). The digit term follows the **harmonic** k, which is 939 (S at 128) or 4,847 (S at 4,096): the arithmetic mean flatters the S and Kv planes. Per-cell packed cost `1/3 + 2 tau / k` at tau = 128: D and Q 0.396, F 0.369, Kv 0.583, S 2.33 at k = 128 (so S stays unpacked, or is reshaped).

The local row of 2^14 message words is a flat slice of the domain (4 tokens of 4,096), so the FlashProve-style matrix is a reshape, not the present row; the present layout does not choose k.

## 2. Honest cell size per plane (item 15, second half)

Cap: an honest combination must stay in +-2^17; max honest RMS about 453 at k = 4,096, 342 at 7,168 [tick 5, reproduced in the script]. **Classes, plane by plane (COUNTED from the plane list; remainder windows from `accuracy_precision.rs`):**

| Class | What | Rows (A) | Share of 2,256 |
|---|---|---:|---:|
| **P pass by range** | int8-class words (Q, QR, O, K, V, KR, S8, G8: calibration line `classes int8=[-127,127]`, `layout.rs:1556`), ZSEL, and the top limbs and short remainders of at most 8 bits (norm, ao, down, score and gate top limbs; rope remainder 7 bits, `layout.rs:67`; HT 8 bits) | 832 | 36.9% |
| **C certain fail** | the **low 16-bit limb** of every two-limb remainder: NR, NS, MR, MS (24-bit, `accuracy_layout.rs:305,307`), RAL (ao 17 to 24 bits), RDL (down 17 to 24), RSL (score 17 to 24), RGL (gate, two planes in the census), and RH (16 bits, `:324`) | 480 | 21.3% |
| **M conditional** | remainders of 9 to 16 bits whose width the calibration sets: RQL (q), RO (pv), RKL (k), RVL (v), RU (up), and the division remainders SR, SG (width `wrho_s`) | 272 | 12.1% |
| **W unmeasured** | int16 words: X, Y, AO, X1, YM, Z, X2, A_SCALED, U, H16 (low part of H24), E and P in S | 672 | 29.8% |

**Why C fails (DERIVED, ASSUMED uniform):** a remainder of a wide value is close to uniform on its window, and a 16-bit limb is looked up directly as an integer in [0, 65,536) (`range16.rs:13`). Centred uniform RMS is `2^b / sqrt(12)`: 8 bits 74, 9 bits 148, 10 bits 296 pass; 11 bits 591, 12 bits 1,182, 16 bits 18,919 fail (TOY of tick 5: 12-bit cells fail 1.4% of combinations). **Any remainder of 11 or more bits fails; the threshold for class M is therefore the calibration: at most 10 bits passes.** The derived windows are 9 to 16 bits for q, k, v, pv, up (`accuracy_precision.rs:80`), so M can land anywhere from fully passing to fully failing. The owner's trained calibrations are not in the retained tree I read (not found; the example numbers in the unit test are not the 8B's).

**Class W is not measured.** No record of honest RMS per plane exists in the repository files I searched (`docs/zkmatrix-poc`, the h124 witness folder, the effplan results): a search for `rms_cell`, `abs_max`, `max_abs` and `activation_rms` found nothing. Residual and norm-output words are int16 with an `int16-endpoint=32768` calibration (`layout.rs:1556`), so a full-scale mapping makes RMS in the thousands plausible; **that is a guess, not a count.** A trained witness capture is the missing input.

## 3. Cost after byte re-expression (DERIVED, script)

Per plane: cells needed (1 if it passes; 2 byte cells if a 16-bit limb, an int16 word or a 9-to-16-bit remainder must be split), each cell costing `1/3 + 2 tau / k` words, against 1.0 today; a plane that would cost more than 1.0 stays unpacked. T/Ht/L and table rows (23) unchanged. tau = 128.

| Scenario | A data rows (today 2,279) | Fraction | Whole block (today 5,103) |
|---|---:|---:|---:|
| Only class C split; S unpacked (k = 128) | 1,219 | 0.535 | 0.79 |
| Only class C split; S one 4,096-column matrix | 1,077 | 0.473 | 0.76 |
| C and M split; S at 4,096 | 1,185 | 0.520 | 0.78 |
| C, M and W split; S at 4,096 | 1,440 | 0.632 | 0.84 |
| C, M and W split; S unpacked | 1,532 | 0.672 | 0.85 |

(The whole-block column holds H, masks and everything else at today's 2,824 rows: DERIVED, 2,824 + the row column, over 5,103.) Tick 5's per-cell 0.40 at k = 4,096 was against unpacked cells; this is against today's committed rows, with splitting.

## 4. New cost that the splitting creates (DERIVED)

A 16-bit limb is one lookup today (`range16.rs:127`: one query for a remainder of at most 16 bits). Two byte cells are two lookups on the existing U8 family. With committed helper columns (one H row per lookup, cycle 6a), the 480 split rows add **about 480 H rows to today's 2,514 (+19%)**, which cancels a part of the gain: whole block with C split, S at 4,096, today's helpers: (2,824 + 1,077 + 480)/5,103 = **0.86**. The saving is not real until the lookups carry no helper (FlashProve's product-tree lookup, ticks 3 and 5; or LogUp-GKR, cycle 6a). So **candidate B's volume gain depends on candidate A-type helper removal**; B alone is about a 14% cut of the block, not a 3x cut of the cells.

## 5. Falsifiable tests

- **H150 (ratio, revised):** the cell part is `1/3 + 2 tau / k` per cell: 0.396 (D, Q), 0.369 (F), 0.583 (Kv). **Result:** survives for D, Q, F; fails for Kv and for S as 128-column matrices.
- **H151 (byte-scale honesty): KILLED as written** (21.1% > 10% on class C alone; counted, not measured). Revised H151b below.
- **H152 (post-split volume).** Claim: with byte cells and digits the A data rows fall to 0.47 to 0.67 of today's. **Test (CPU count, no proof):** rerun the Rust census on a layout with the class C planes replaced by byte planes and the packed ratio applied; **kill** if the result exceeds 0.70 or if the extra helper rows push the whole block above 0.90 with helpers still committed.
- **H151b (class W honesty).** Claim: after centring and the calibrated scales, every int16 word plane has RMS under 453 / 342. **Test:** one trained witness capture (T = 128, one block), per-plane RMS, `sqrt(k/2) x RMS` against 2^17 / 6.4. **Kill** if more than 150 of the 672 W rows exceed the cap (then W planes also split and the 0.63 to 0.67 rows apply).
- Nothing proposed changes the prover now.

## 6. Honest expected effect

- **Committed words per request:** A data rows 0.47 to 0.67 of today's; whole-block 0.76 to 0.85 before the helper count moves; **about 0.86 if helpers stay committed and the splitting adds lookups**. Tick 3's 0.14 to 0.25 M words per token-layer (derived, wide range) is not confirmed: that figure assumed three cells per word without the width gate.
- **Proved tokens per second:** not moved by this reading. Volume was 1.2 to 2.5% of the measured Mac request (cycle 4); the digit lookup (27 + 11 levels, tick 5) is added work with no timing.

## 7. Risks and what was not verified

- Uniform remainders: ASSUMED. A remainder concentrated near a value would pass; the claim is that wide-valued numerators make low limbs near-uniform. A sample would settle it.
- Plane widths for NR, NS, MR, MS (24 bits, from `rem(...,24)`), RAL, RDL, RSL, RGL, RH are COUNTED from the lookup list; the remaining class M widths depend on the 8B calibration I did not find.
- S orientation (k = 128 versus 4,096), the contracted axis of each plane and whether D, Q, F rows align with the sumcheck variable order are not read; the attention page `11-3` was never read (tick 5).
- I did not check whether the packed digits can reuse the existing U8 table family or add a table; the cost of 10+8-bit digit lookups was taken from tick 5.
- The window cap uses tick 5's Gaussian model and z = 6.4.

## 8. Status

New proofs, passes, proved positions: **0 / 0 / 0.** The complete private 8B at >= 50 proved tokens/s remains **unachieved**. Hypotheses: 153 (H152, H151b added; H151 killed as written).

## 9. Next concrete actions

1. Coordinator: B is not a stand-alone volume gain; it needs the helper-free lookup (A-type) to realise it. Cost B and A together, not B alone.
2. A trained witness capture of one block's A planes (per-plane RMS) would resolve class W and M; check whether one already exists in the owner-private store (not on the Mac, per the bring-up notes).
3. Read the local D55 schedule against the order requirement (queue item 16).
