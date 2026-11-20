# Research handoff: how FlashProve serves a claim on one cell from packed words (2026-11-16, claude tick 5)

From Claude, the background researcher (D50). Queue item 2b (candidate B's paper step, `ZK60_NEXT_PROTOCOL_CANDIDATES.md` section 6), which also covers item 14.

**Scope.**
- **Full text, read directly (not through a summarizer):** the raw files `docs/format/11-1-machinery.md` (all 112,280 characters downloaded; read lines 185-335, 455-545, 855-890, 1040-1500: the smallness test, the arrays, the equations, the claims, the constants and the source's own caveats), `11-2-feed-forward-segment.md` (all 83,202 characters downloaded; read lines 120-165, 384-410, 478-527: the parts of `U3` and the reads), from the project's public repository on its main branch. `11-3` was downloaded and **not read**. 3 fetches, 0 searches. Tick 3 and tick 4 read these through the fetch tool's summarizer; this tick replaces that for the packing mechanism.
- No prover run. One small `python3` toy (below) with random data, a few KiB of memory. No Git write.
- **Triage material, not a work order.** Anything here changes what is committed, so it changes proof bytes and the verifier and needs the owner's ruling, a new profile string (D17) and re-proved Lean (D63). The owner shelved proof-size work on 2026-11-09; this concerns committed volume.

Labels: **[AUTHORS]** (their text, with section), **DERIVED** (my arithmetic), **TOY** (my script output), **ASSUMED**.

## 0. Headline

- **Yes, a mechanism exists, and it is not an opening.** FlashProve never evaluates a packed word at a verifier point to learn one cell row. A sumcheck's claim on cell rows ends on entries of a committed vector `U3` of E elements (the "reads"), each the cell tensor contracted along its row axis with a public weight vector. `U3` is tied to the packed matrix `M` by a **random ternary column-compression** (entries 0, +1, -1) whose results are small integers, committed in two digits (10 + 8 bits, array `ZZ`) and range-checked by a lookup. The radix powers appear only on the digit side, where a small value unpacks uniquely. [AUTHORS, 11-1 "The smallness test", "The equations"]
- **It answers cycle 6b's one-line objection in its premise, not in its saving.** 6b said an opening of `W = sum 2^(16 s) V_s` gives one combination of k unknowns and binding them needs a non-low-degree unpacking. Here the unpacking is done on committed digits of the *compressed* values, with the relation `val(3i') + 2^20 val(3i'+1) + 2^40 val(3i'+2) = sum_c Theta[c] M[i'][c]` (linear in M, public coefficients) and a uniqueness lemma (f1: `(4 x 2^17 - 2)(1 + 2^20 + 2^40) < p`) [AUTHORS, constants (f1)]. I confirmed (f1) by arithmetic (TOY: true for three lanes, false for four).
- **The saving is conditional on wide rows:** cell part (packed M plus digits) is `1/3 + 2 tau / k` of the unpacked cells, k = columns per cell matrix, tau = number of combinations (DERIVED, §3). It is **0.40 at k = 4,096 and 0.365 at k = 8,191 with tau = 128**, and the verifier rejects k above 8,191 [AUTHORS]. The check is **statistical (error 2^-tau per column)** and the source says it gives no knowledge error and no cover for a prover not bound to one object (§4).
- **Pass for B, as written in the candidates table** ("a mechanism that serves per-cell claims from packed words, with its cost"): **met on paper.** The second pass condition (mean at most 2 bytes per value) is untouched here, and a new gate appears: honest cells must be byte-scale (§3).

## 1. The mechanism [AUTHORS, 11-1 and 11-2]

1. **Committed.** `M_mu`: `ceil(m_mu/3)` rows by `k_mu` columns over F, entry `cell(3i') + 2^20 cell(3i'+1) + 2^40 cell(3i'+2)`, negatives entering as negative integers then reduced mod p.
2. **Read.** A sumcheck over a cell tensor ends on a point z. The weight vector `phi` (short: `eq(z, t)` over T tokens; long: `eq(first ls of z, c2) eq(last lt of z, t)`) is public from z. The prover then commits `U3[at(f) + c nb(f) + b] = sum_r phi[r] cell(b len + r, c)`, one E element per column c and block b. Every sumcheck end value is declared to equal a combination of `U3` entries (`RS`, `RL`, `RX`, 11-2). So the per-cell claim becomes a claim on `U3`, not on M.
3. **Tie, by the smallness test (no rounds of its own).** After M and `U3` are committed, V samples `Theta`, tau ternary entries per column. P commits `ZZ` (tau rows, 2 mz columns): the low and high digit of `comb(i, u) + 2^17`, `comb(i,u) = sum_c Theta[c][u] cell(i, c)`. Two equation families, both linear in committed entries with public coefficients, folded into the segment's one final batched sumcheck by powers of chi:
   - **EP** (per packed row i', per u): `val(u, 3i') + 2^20 val(u, 3i'+1) + 2^40 val(u, 3i'+2) - sum_c Theta[c][u] M[i'][c] = 0`.
   - **ER** (per read, per u): `sum_r phi[r] val(u, crow + r) - sum_c Theta[c][u] U3[...] = 0`.
   Digits are range-checked by a two-call lookup (2^10 and 2^8 tables, 32 multiplicity bit-planes per entry in `BZ`).
4. **Order matters** [AUTHORS, 11-1 "The sampled matrix"]: M and `U3` are committed and their out-of-domain answers given **before** Theta is sampled; `ZZ` and `BZ` after. Otherwise a prover could add to a read a vector that Theta maps to zero.

**Why it works, my reading (DERIVED, TOY):** if a read differs from the true contraction in some column, then for a random ternary Theta the discrepancy survives with probability at least 1/2 per combination, so tau combinations miss it with at most 2^-tau. TOY (k = 64, 6 rows, tau = 8, random bytes): honest passes; one altered `U3` entry was caught in 1,994 of 2,000 runs (bound allows about 8 misses; 6 observed). The toy checks the algebra of EP and ER, not the digit ranges.

## 2. Cost, in this project's units [AUTHORS formulas; example numbers DERIVED]

| Item | Size | Source |
|---|---|---|
| Packed matrices | `sum_mu ceil(m_mu/3) k_mu` F words | 11-1 |
| `ZZ` digits | `2 tau mz` F words (127.9 M at tau = 128, mz = 499,712, tick 3's example) | 11-1; DERIVED |
| `BZ` | 32 x 2^11 = 65,536 F words (once per segment) | 11-1 |
| `U3` | `sum_f k nb(f)` E elements; E element read as three F coordinates (the text writes `(x, 0, 0)`; ASSUMED degree 3) | 11-1 |
| Rounds | the digit lookup is "as for a lookup with NC = 2": `v_Z = n_Z + 1` product-tree levels plus 11 table levels, `n_Z = max(10, clog2 tau + clog2 mz)` = 26 at the example, so 27 + 11 sumcheck levels; the equations add **no round** (folded into the last `BAT-sigma`, whose n is NCm + Q) | 11-1 |
| Claims added | `47 + v_Z + NM + NX` (NM matrices, NX reads) | 11-1 |
| Equation numbers | `Q = sum_mu tauP 2^clog2(mp_mu) + NX tauP`, tauP = 128 at tau = 128 | 11-1 |
| Parameter limits | tau a multiple of 32 in 32..256; at most 255 matrices; k from 1 to 8,191; `2 mz < 2^32` | 11-1 |

No prover seconds for the test are published in what I read; the claim, equation and level counts are what exist.

## 3. Derived consequences for candidate B (DERIVED; script output reproduced in `python3`)

- **Words per cell:** packed M costs 1/3, digits cost `2 tau / k`. At tau = 128: k = 2,048 gives 0.458 of unpacked cells; k = 4,096 gives 0.396; k = 8,191 gives 0.365. Digits over packed words is `6 tau / k`: 0.375, 0.188, 0.094. The candidates document's "1.6% for the smallness digits" is against unpacked cells at k = 16,384; FlashProve's cap forbids that row width (k at most 8,191), so a local row of 2^14 message symbols would need splitting into two matrices, and then the digits count per matrix.
- **Honest-prover completeness gate (the new finding for B).** An honest combination must land in the window [-2^17, 2^17); one miss means no honest proof for that Theta. With ternary entries (0 w.p. 1/2) the combination's standard deviation is `sqrt(k/2) x RMS(cell)`. For 1% total failure over all `tau mz` = 6.4 x 10^7 combinations (z = 6.4): **max RMS cell about 453 at k = 4,096 and about 320 at k = 8,191** (uniform half-range about 784 and 554). TOY/DERIVED: int8 and 10-bit uniform cells pass; **12-bit uniform cells fail about 1.4% of combinations (about 9 x 10^5 failures); 16-bit uniform cells fail 88%.** So B's "re-express as byte cells" step is not optional, and any plane with a large dynamic range (24-bit product limbs, residual stream sums) cannot be a cell as it stands. This sharpens tick 3's one-line completeness remark into numbers.
- **Soundness for the exact-word classes (D67):** the test is a magnitude test (bound 2^18 for the integers behind M and `U3`), not an exactness test; remainders and windows still need lookups on keys that are polynomials of the cells, as candidate B already says.

## 4. What the smallness test must guarantee, and the source's own caveats [AUTHORS, 11-1 "The purpose that the source states"]

- Guarantee wanted: for each matrix there is one integer matrix, every entry in (-2^18, 2^18), whose packing is the committed M and whose contraction is the committed `U3`.
- The round error is 2^-tau for **one column**, the first that no matrix of small integers explains and which is fixed before Theta; a union bound over columns gives `tau - log2(columns)` bits. The header comment calls this "no cover for a prover that is not bound to one object, and no knowledge error"; the count is adapted from ePrint 2020/1448 (Lemma 2.5) and argued anew for packed cells and reads; its comparison with ePrint 2021/1397 Lemma 3.4 is not done; by the authors' own row SO-17.6.1, how much of the step is the project's own is unknown. A false acceptance was reported (a cell of 1,000 accepted under bound 32 when two descriptions of the digit positions disagree in a test harness). The authors' verifier runs a second implementation of the test that the library tests do not cover. **Treat the 2^-tau as the authors' claim, not a verified bound.** Tick 3 had 113.44 bits for the union bound (paper Remark G.2).
- For this project's ~100-bit budget the union-bound form needs tau - 13 >= 100 at k = 8,191, so tau >= 113 and the parameter file's multiples of 32 force 128.
- **Hiding.** ZZ and `U3` are committed and masked like other arrays (FlashProve's zero-knowledge theorem covers its own setting; I did not check it for the digit and read arrays). In P1 the compressed combinations are linear images of hidden activations opened at a few columns; whether that adds to the joint view is **not reviewed** here.

## 5. Falsifiable tests in this project's terms

- **H150 (packed-plus-digits ratio).** Claim: the cell part of A-plane volume falls to `1/3 + 2 tau / k` of unpacked cells, i.e. at most 0.40 when message length k >= 4,096 and tau = 128. **Test (count, CPU, no proof):** read k per cell matrix from the layout code and apply the formula to the 2,279 A rows. **Kill** if the weighted k is under 2,048 (ratio above 0.46) or if the matrices must be split to stay under k = 8,191 so that digits double.
- **H151 (byte-scale honesty).** Claim: after byte re-expression every A plane's honest combination stays inside the window. **Test (count plus numerics, small):** per plane, honest RMS cell from the Rust census's witness (or a recorded sample) times `sqrt(k/2)`, against 2^17 / 6.4. **Kill** if more than 10% of A rows (by words) have RMS above about 450 at k = 4,096.
- **Not proposed:** any change to the prover. The order requirement (commit `U3` after the sumcheck point, before Theta) is the item a schedule review must answer; I did not read the local D55 schedule for it.

## 6. Honest expected effect

- **Committed words per request:** unchanged from tick 3's range on the packing part (it already assumed 3 per word); the new content is that the digit term `2 tau mz` is real and is carried in §2 (about 0.36 to 0.46 of the cells' words after packing and digits, plus `U3`, which I could not size without the layout's parts). Candidate B's volume table stands only if H150 and H151 hold; I support no new multiplier.
- **Proved tokens per second:** not moved by this reading. Volume was 1.2 to 2.5% of the measured Mac request (cycle 4); the added lookup (27 + 11 levels), the equation folding with `Q` terms and a possible second commitment round are new work with no published timing.

## 7. Risks and what was not verified

- `11-3` (attention) not read: the causal-mask blocks use their own parts of `U3`; `11-4` and `11-5` unread. I did not read the prover source or the paper's text for the test.
- I did not read the local verifier or the local D55 schedule, so "fits our Ligero-style opening check" is unverified. FlashProve folds every claim into one linear form on committed arrays (11-1 "The one equation"); this project's check differs, and whether `U3` is simply our "combined row" message needs a local reading.
- The 1/2 miss probability per combination is my argument, matching the source's 2^-tau statement; the TOY exercises algebra, not digits or lookups.
- The honest-completeness numbers use a Gaussian approximation and uniform cells (the example mz = 499,712 and tau = 128 are 11-2's); real planes are not uniform, so H151 uses a measured RMS.
- "Tick 3's 0.14 to 0.25 M" figure is unchanged; this tick does not re-derive it.

## 8. Status

New proofs, passes, proved positions: **0 / 0 / 0.** The complete private 8B at >= 50 proved tokens/s remains **unachieved**. Hypotheses: 151 (H150, H151 added).

## 9. Next concrete actions

1. Count k per A matrix and honest RMS per plane (H150, H151); a CPU census extension.
2. Read the local transcript schedule against the order requirement (commit contraction vector after the point, before the compression).
3. Coordinator: B's paper step is passed on mechanism; decide whether B waits for the counts or is costed beside A as it stands.
