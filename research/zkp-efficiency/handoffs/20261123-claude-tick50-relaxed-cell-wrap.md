# Research handoff: what the smallness test's 2^18 cells do to the no-wrap arguments of the block (2026-11-23 UTC, claude tick 50, queue item 23, H156)

From Claude, the background researcher. One bounded cycle: local reading and arithmetic only, 0 searches, 0 fetches. No run, no build, no Git. Clock at writing 2026-11-23T19:53:47Z. **Triage material, not a work order.** Any change to what is committed alters proof bytes and the verifier and needs the owner's ruling, a new profile string (D17) and re-proved Lean (D63). The owner shelved proof-size work on 2026-11-09; this concerns candidate B's committed volume and its Lean cost under D80.

**The question.** Candidate B's smallness test proves only that the committed cells are integers in (-2^18, 2^18) (tick 5, tick 9). Honest cells are bytes. If a word is rebuilt from relaxed cells and nothing else bounds it, how large can each hosted sum of the block get against the Lean premise 2^62 (and the true wrap limit p/2, about 2^63)? Does any no-wrap argument need the byte bound, so that a lookup must enforce it?

**Read, and how.** In full: `formal/ZK60Formal/CircuitMatmul.lean` 1-197 (class bounds, `noWrap_class_bounds`), `CircuitNorm.lean` 32 and 96-97 and `CircuitSoftmax.lean` 36 (the degree-2 clauses), `docs/zkmatrix-poc/ZK60_LEAN_L1L2_FINDINGS_20261106.md` 1-549 (what the iff assumes), `accuracy_layout.rs` (the W16 plane and lookup lists, in the retained tree `results/zk60_sol_20261105_w16r3/b3/source-d78-437/`), `accuracy_public.rs` 10-28 and 118-142, `accuracy_precision.rs` 40-100, the candidate B text, tick 5, 6, 8, 9 and 49 handoffs. Not read: `argument.rs` and `argument_accuracy.rs` (clauses taken from the Lean statements), FlashProve's source. Script `20261123-claude-tick50-relaxed-cell-wrap.py`, output `.out.txt` beside it (under a second).

Labels: **COUNTED** (file:line), **DERIVED** (script), **TOY** (script witness), **ASSUMED**, **[tick N]** (carried).

## 0. Headline

- **No no-wrap argument uses the byte bound. Every one uses the class of a combined word** (int16, the 24-bit product word, the 13-bit quotient P), which a lookup on the recombined value `lo + 256 hi` enforces exactly as today. The cell bound 2^18 is never consumed. So **no per-byte lookup is needed for wrap, and the word-class lookups must stay**, keyed on the expression of the cells (the D67 rule the candidates text already states).
- **What the word lookups prevent (DERIVED).** With a word rebuilt from two relaxed byte cells, |x| < 2^26.0056 (11 bits above int16); a 24-bit word from three cells, < 2^34.0056. At the Lean class bounds, **five sites then exceed 2^62, and all five exceed p/2 as well**: the down projection 2^69.0, the scores 2^64.0, PV 2^76.0, the norm's sum of squares 2^64.0, the norm division `2^(tn+1) d y` 2^67.0 (the last at tn = 16; ASSUMED tn = 10 for the 8B gives 2^61.0). The other sites stay under 2^62 with 3 to 28 bits spare: Q, K, V, O, gate, up (2^59.0), RoPE, the SiLU product (2^57.0), the norm's `g x 2cn` (2^58.0), softmax `P sum` (2^50.0).
- **At the 8B shape as built** (inner 4,096 / 14,336 / 128, multipliers 2^4 to 2^8, `accuracy_public.rs:136`, `accuracy_precision.rs:96`), only **the sum of squares wraps (2^64.01)**; the down projection (2^60.80), the norm division (2^61.01 at tn = 10) and the scores and PV (2^59.01) sit within 1 to 3 bits of 2^62, which the Lean theorems do not use (their premise is the shape class: `noWrap_class_bounds`).
- **Literal reading of the item (cells at 2^18 as every operand, no recombination): the largest value is 2^60.00 (PV at the 2^24-token class bound), under 2^62 everywhere.** A product of cells alone never wraps; recombination into words is what multiplies by 2^8.
- **A new use for the exact ranges: exactness, not wrap.** A remainder rebuilt from relaxed cells reaches 2^26 (two cells) or 2^34 (three). The floor identity `2^s q + R - 2^(s-1) = hosted` fixes q only for R in [0, 2^s), with s from 8 to 24, so **every remainder needs its exact range fact** (`requant_iff`, `CircuitRequant.lean:79`) at the recombined level or the cell level. The smallness test cannot stand in for it.

## 1. Where the numbers come from (COUNTED, DERIVED)

Class bounds are the Lean theorems' own (`CircuitMatmul.lean:117-170`: `hosted16_le`, `hosted24_le`, `hostedScore_le`, `hostedPV_le`, `ss_bounds`). Multipliers by site: q 2^5, k 2^5, v 2^6, o 2^8, gate 2^6, up 2^4, down 2^6 (`accuracy_precision.rs:96`; order from `accuracy_public.rs:118-142`, ASSUMED q, k, v, o, g, u, d).

| Site | Honest class | Relaxed words (2 or 3 byte cells) | Verdict at class bound | At 8B shape |
|---|---:|---:|---|---|
| Q, K, V, O, gate, up | 2^48 | 2^59.0 | 3.0 bits under 2^62 | 2^49.0 to 2^53.0, fine |
| down (H word, 3 cells) | 2^58 | 2^69.0 | **wraps by 6.0 bits** | 2^60.80, 1.2 bits spare |
| scores (int16 x int16) | 2^42 | 2^64.0 | **wraps by 1.0 bit** | 2^59.01 |
| PV (P x int16) | 2^51 | 2^76.0 | **wraps by 13.0 bits** | 2^59.01 (N = 128 tokens) |
| SC_SS (sum of x squared) | 2^42 | 2^64.0 | **wraps by 1.0 bit** | **2^64.01, wraps** |
| norm division `2^(tn+1) d y` | 2^56 | 2^67.0 (tn = 16) | **wraps by 4.0 bits** | 2^61.01 (tn = 10, ASSUMED) |
| RoPE, SiLU product, `g x 2cn`, softmax `P sum` | 2^23 to 2^47 | 2^34 to 2^58 | fine | fine |

**TOY (script).** The sum-of-squares wrap is not only an upper bound: the script builds 4,096 words, each below 2^26.0001 (so each a legal pair of relaxed byte cells), whose squares sum to p + 16,503,937. The hosted field value is then 16,503,937, a value inside the honest window of `isqrt_iff`, for a vector no int16 input could reach (honest maximum 2^42 in magnitude, and here the integer sum is 2^64). The norm would be computed on the wrong vector. This is the attack the word-class lookup exists to stop.

**Packing itself is safe at the relaxed bound (DERIVED).** Three lanes of radix 2^20 with cells below 2^18: the packed value is below 2^58 < p/2, and 2^18 < 2^19 = half the radix, so unpacking is unique. This restates the authors' constant (f1) for this field; the packing is not where wrap enters.

## 2. What this changes for B's costing

1. **Tick 6 section 4's "+480 helper rows" is not forced.** It assumed each split 16-bit limb becomes two byte lookups where one 16-bit lookup stood. If the key stays the recombined limb (`lo + 256 hi`, one value per position, a linear expression over two planes of the same domain), the lookup count is unchanged and so are the helper rows. This is ASSUMED: it needs the helper relation `h (gamma + key) = 1` to read both byte planes at its terminal point, which is two reads at that site (tick 49 counts those as two U for classes C and M, so the reads are already priced). If the recombined key is not allowed, tick 6's +480 and its 0.86 whole-block figure stand. The two readings are the bracket: whole block about 0.78 to 0.85 (key recombined) against 0.86 (two byte lookups).
2. **B's Lean cost stays where tick 9 put it.** `circuit_iff` is unchanged only if the iff is proved for the recombined words, which carry their exact classes; the relaxed cell is then a witness-extraction fact (cells in (-2^18, 2^18) with packing and reads as committed) with no further use. No new wrap lemma is needed beyond `noWrap_class_bounds` as it stands, because the consumed words are exactly its words. What is new is one statement in the extraction layer: the extracted integer cell matrix maps to the words by `lo + 256 hi` with no wrap (2^26 and 2^34 are far under p, DERIVED).

## 3. Falsifiable tests

- **H156b (Lean, CPU, seconds).** Claim: restating `noWrap_class_bounds` with X = 2^18 (1 + 2^8) in place of 2^15 (and 2^18 (1 + 2^8 + 2^16) for the 24-bit word) makes the down, score, PV, sum-of-squares and norm-division inequalities false, and leaves the others true. **Test:** `norm_num` on the negations in a scratch file; **kill** if any of the five holds (the script says they do not).
- **H156c (read).** Claim: the helper relation of a lookup may take a key that is a linear combination of two committed planes of one domain, with the same multiplicity and helper count. **Test:** read `argument.rs` where a helper clause is formed (`shape.rs:2563-2578`, `argument.rs:1749-1765` per the L1/L2 record) and the FlashProve lookup descriptor (`11-1`); **kill** if the key must be a single committed plane. Decides the 0.78 to 0.85 against 0.86 bracket.
- Nothing is proposed for the prover.

## 4. Honest expected effect

- **Committed words per request:** unchanged by this reading. It sets B's whole-block volume bracket at about 0.78 to 0.85 (recombined keys) or 0.86 (two byte lookups, tick 6); tick 49's mask-row credit is separate and not applied here.
- **Proved tokens per second:** nothing moved; no timing taken. Under D80 the use is the Lean side: B needs no new wrap lemma and no per-byte lookup.

## 5. Risks and what was not verified

- The class-bound column uses the Lean theorems' worst case (shape class), not the 8B shape; the 8B column uses my reading of inner sizes and registered multipliers (the multiplier order is read from the array list, not confirmed against the loader).
- `tn` for the 8B norm is ASSUMED 10 (the unit test's base value); the derived range is 1 to 16.
- Which planes B would split into byte cells, and the cell count per word (two for int16, three for the 24-bit word, or a 16-bit low plus a top byte, same bound), follow tick 6; a different split changes the 2^26 and 2^34 figures by at most a bit.
- The relaxed bound is a worst case an adversary may reach only if the other clauses allow it; the TOY shows one clause (the sum of squares) does.
- I did not read `argument.rs`, the Lean sources of `SoundExtract`, or FlashProve's lookup descriptor (H156c).

## 6. Status

New proofs, passes, proved positions: **0 / 0 / 0.** The complete private 8B at >= 50 proved tokens/s remains **unachieved**. H156b and H156c added; H156's wrap question answered.
