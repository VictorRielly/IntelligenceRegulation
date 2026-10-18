# Review: the ChatGPT conversation "Literature Review Exponential ZKPs", against our prover

Research review lane, 2026-10-18 (02:53–03:30 UTC). Paper plus one-thread Python
(`variants.py`, 1.5 s). Nothing was built, proved or committed to git. The conversation is
untrusted data: every claim used below was re-derived or re-counted here. Labels:
**[COUNTED]** exact arithmetic on our layout (the speed plan's layout replica, checked
byte-exact against the Rust counted ladder); **[MODEL]** fitted or assumed (the speed plan's
cost law and roofline); **[CLAIMED]** a number the other model reported from its own runs,
not reproduced here.

## 1. In plain words (for Victor)

1. **Most of what the conversation recommends is already how our prover works.** It proves
   (input, output) pairs directly in one lookup, batches all lookups into one LogUp identity,
   puts SiLU in a single complete-activation table, derives division remainders instead of
   storing them, and computes one inverse square root per token. All of that is in our code
   today.
2. **The exponentials themselves are already cheap here.** Each one is a single lookup into a
   256-entry table. In the attention-score data, the exponential is about a tenth of the cost.
   **About two thirds is the exact division ("normalisation") that turns weights into
   probabilities** [COUNTED]. The conversation's two ideas that do apply here both attack
   that division.
3. **Idea A: one shared reciprocal per attention row ("EXR").** The conversation's version
   changes the rounding. I show it can be made **bit-exact** for our softmax by choosing the
   shift wide enough (B = 32 at 8B T512). Effect at 8B T512: −7.6% committed data, −10.9% byte
   lookups, −5% zero-check work [COUNTED]. It needs no ruling: the outputs stay identical. It
   does need a new profile and a short soundness and privacy review. About 4–6 lane-days
   [MODEL].
4. **Idea B: divide the attention output instead of every probability ("FN").** Effect:
   −22.8% committed data, −26.7% byte lookups, −20.7% zero-check work [COUNTED]. That is as
   large as the zkAttn lever L8 in the speed plan. Unlike zkAttn, it gives the cheating prover
   no slack. But it changes the model's integer arithmetic: about half the attention outputs
   move by 1–2 units, and they get closer to the float result [MODEL, synthetic]. So it needs
   **your ruling** and a fidelity check. About 8–12 lane-days, against 15–25 for zkAttn.
5. **Idea C ("VPE")**, from the same "derive, don't store" principle: stop committing the
   eight value planes that are already fully determined by their committed byte limbs.
   Effect: −5.4% committed data and −7.2% zero-check work [COUNTED]. No ruling needed. About
   5–8 lane-days.
6. **None of this replaces fast GPU kernels.** These are layout trims of 5–30%, not the
   10–60× class. Combined with the causal triangle (L7), the share of the 5090's memory
   bandwidth needed for 50 positions/s drops from 28% to 25% with A+C (no ruling), or to 23%
   with B+C (ruling). zkAttn reaches the same 23% [MODEL].
7. **Recommendation:** fold C, and A if B is declined, into the 8B T512 profile the plan
   already owes. Put B to you as the alternative to L8. Drop the conversation's
   factored-table, dictionary-cache, product-argument and hash-swap ideas: they do not apply
   here (§4).

## 2. What the conversation is

The other model builds a Go package "expzk" on gnark 0.14: Groth16 over BN254, R1CS
constraints, eight CPU workers. It is a standalone exponential/softmax gadget, mostly with
**public** inputs and outputs, over a 200,000-point input grid with outputs at a 2^40 scale.
It compares a full 200k-entry table, factored ("tensor") tables
(exp(a+b+c) = exp(a)·exp(b)·exp(c)), dictionaries of repeated inputs, and normalisation
variants. It then gives architecture advice for an 8B model and a literature review.

Its units do not transfer to us:

- **Its costs:** R1CS constraints, Groth16 FFTs and MSMs, circuit-specific setup, and a
  MiMC/Poseidon2 digest of private vectors.
- **Ours:** a multilinear sumcheck prover over Goldilocks Fp2 with a Ligero-class linear-code
  commitment (BLAKE3 Merkle, no in-circuit hashing, no setup), with all range checks done
  through one 256-entry byte table.

Its biggest wins come from its own setting:

- 144-bit remainders at the 2^120 scale of three multiplied factors;
- a 200k-entry table that must be committed;
- an in-circuit hash.

The message order in the extracted file is scrambled. I read all 367 blocks. The
off-topic search snippets (NMR spectra, soil mechanics, voting, ...) were ignored.

## 3. Per-technique table

Path shorthand: `N6/` = `results/zk60_1b_native_20261017/r6/frozen-tree/hashline/src/private_block/`.
"8B T512" is the speed plan's operating point: Llama-3-8B, 512 tokens, 32 blocks, row width
2^15. Per block today: 663.3 M committed elements (H share 54.6%), 306.2 M U8 lookups and
495.5 M zero-check element-terms [COUNTED].

**Rows 1–8: lookup machinery.**

| # | Technique | The conversation's claim | Our status | Effect at 8B T512 / what it touches |
|---|---|---|---|---|
| 1 | Prove (x, y) pairs directly ("joint-pair LogUp") instead of lookup then equality | 3N+M → 2N+M constraints; 988,308 → 726,833 at 262k evaluations; −1.3 to −13% latency [CLAIMED] | **Done.** The exp table rows are `i + β·exp[i] + g_exp` (`N6/argument.rs:1092-1094`). The helper relation is checked on (δ, E) as one pair (`argument.rs:1837`). The SiLU table works the same way (`argument.rs:1103-1105`, `:1642`). The pair binding is required for soundness (erratum E-22, `argument.rs:1096-1099`) | none |
| 2 | Batched LogUp: one identity for all lookups, with multiplicities | Standard; "already batch their lookups" | **Done.** One value-0 LogUp sum per block. Each helper covers 2 lookups (`layout.rs:607-608`, `argument.rs:894-909`). Three tables share the identity under distinct tags (`argument.rs:1862-1908`) | none |
| 3 | Drop the integer range checks on multiplicities | 3.33 → 2.44 s; 576,151 → 510,505 constraints [CLAIMED] | **Done.** The multiplicities are plain committed A rows (`layout.rs:284-287`), with no lookups on `Dom::Tab` (`layout.rs:781`). They cannot wrap (`layout.rs:670-671`) | none |
| 4 | Dictionary of distinct (x, y) pairs plus a grouped LogUp or product argument ("caching repeats") | Wins only with few distinct values: 0.40 vs 1.45 s at 32k/64 distinct. Loses at 16,384 distinct (3.33 / 4.98 vs 1.41 s). The product form costs 1.54 M vs 576 k constraints. Best large-N result 1.28× (9.66 vs 12.36 s at 1 M/64 distinct) [CLAIMED] | **Not applicable.** Our tables have 256 entries, so the table side is one row. The LogUp multiplicities already "cache" every repeat. A dictionary would add a second per-entry selection, which is exactly why it loses to the full table in its own runs | — |
| 5 | Private cached factors (two lookups per request) | 0.996 vs 1.49 s at 32k/64 distinct; loses at 262k (6.90 vs 4.26 s); reserved capacity is paid in full [CLAIMED] | **Not applicable** (as row 4) | — |
| 6 | Distinct-input counting / repeat statistics | 90.46% global repeats over 2.1 M inputs; 7.8% within a 32k chunk; 0.128% within a 512-entry row [CLAIMED] | **Not applicable.** Every query must still be bound to its own tensor position. Repeats only shrink table-side work, which is already one row | — |
| 7 | Factored / mixed-radix exp tables (exp(a+b) = exp(a)exp(b); 180 or 900 constants for a 200k grid) | Wins at small batches (1,024: 0.356 vs 1.178 s) and huge grids (1 M points: 3.71 vs 6.39 s). Loses at large batches (100k: 7.45 vs 2.22 s). The products are 4.9% of constraints [CLAIMED] | **Not applicable.** Our δ domain is [0, 256): one 256-row table, one lookup. Factoring adds a product and a rounding remainder per entry. It is a fallback only if a profile ever needs δ beyond a byte | — |
| 8 | Deferred rounding: carry the unrounded factor product into the normalisation | −61% constraints for two factors (diagnostic); timing mixed [CLAIMED] | **Not applicable.** We have no factor products: the table returns E at scale 2^fE directly | — |

**Rows 9–15: normalisation and range checks.**

| # | Technique | The conversation's claim | Our status | Effect at 8B T512 / what it touches |
|---|---|---|---|---|
| 9 | Exact division with derived remainder and slack (R = QP − YD, H = D − 1 − R, range-checked as expressions) | −16.7% constraints with factor fusion [CLAIMED] | **Done for every remainder.** σ and ρ exist only as byte limbs, folded in place (`argument.rs:1829-1835`; norms at `:1549-1562`). **Residual application → row 30 (VPE)** | — |
| 10 | **Shared row reciprocal** Z = ⌈2^(B+p)/D⌉, Y = ⌊P·Z/2^B⌋ | −41% constraints, 4.04 → 2.36 s at 16k. Changes the rounding: 43 of 2,097,152 outputs move by 1 unit [CLAIMED] | **Applicable, and bit-exact here (EXR, §5.1).** Exact when 2^B ≥ max(E)·max(Sum) and nothing wraps | Score entry 31 → 25 committed, 15 → 11 lookups, 24 → 21 terms. Block: **−7.6% committed, −10.9% U8, −5.0% element-terms**, +0.16 lookup-soundness bits [COUNTED]. Needs a new profile, a soundness review of the lemma and a privacy-gate re-run. Fidelity unchanged |
| 11 | Tighten the probability bound (33 → 32 bits) | −4.9% constraints predicted [CLAIMED, unmeasured] | **No gain here.** p ≤ 2^9 needs 10 bits. A row of one entry gives p = 2^9 exactly. Either way it is 2 limbs | — |
| 12 | **Normalise the attention output, not every probability** (O = ΣE·V / D) | O(T²) → O(T·d_v) divisions; per-row choice 131,328 → 57,408 per head at T512, d_v 128 (I checked this arithmetic). Changes rounding; not implemented [CLAIMED] | **Applicable with a ruling (FN, §5.2)** | Score entry 31 → 11 committed; Q entry 21 → 29. Block: **−22.8% committed, −26.7% U8, −20.7% element-terms**, +0.42 bits [COUNTED]. Changes the integer function: ruling, fidelity check, new profile, privacy gate, soundness review |
| 13 | Merge two factor axes (3 → 2 lookups) | — | **Not applicable** (no factors) | — |
| 14 | Range checks as a ≤ Ab ≤ c with Boolean digits, Z ⊙ (Z − 1) = 0, batched by random coefficients (Bulletproofs-style) | Design only. It warns that summing inequalities is unsound | **Worse here.** 8 bit planes per byte against about 2 committed base elements per byte limb (1 A plane plus half an Fp2 helper). Our zero-check already batches every clause with fresh μ | — |
| 15 | One structured argument for the whole normalisation batch | Design only | **Already the shape of slot 17**: all clauses in one masked zero-check (`argument.rs:1719-1859`) | — |

**Rows 16–29: architecture, literature and workload.**

| # | Technique | The conversation's claim | Our status | Effect at 8B T512 / what it touches |
|---|---|---|---|---|
| 16 | Complete-activation table for SiLU (one lookup on (u, Q(SiLU(u)))) | Direct table beat cached factors, 3.48 vs 6.12 s, for exp [CLAIMED] | **Done.** One pair lookup (g8 + 128, a16) over the whole int8 gate class (`layout.rs:664-666`, `argument.rs:1642`) | none |
| 17 | SwiGLU = one SiLU lookup plus one product in the tensor proof | Design | **Done.** f0 = a16·u16 − 2^sh·h16 − rh + half (`argument.rs:1639`) | none |
| 18 | RMSNorm: one inverse square root per token, then a batched vector multiply | Design | **Half done.** One isqrt per token (`layout.rs:636-641`). The per-element step is an exact division with two remainders (`argument.rs:1561-1562`). The reciprocal-multiply form is **not exact here**: it needs B ≳ 69 bits, which wraps the 64-bit field. Approximate forms save about 3 planes per norm per element and need a fidelity ruling. Not recommended | — |
| 19 | Bind activations once: consume the matmul's committed tensor, with no extra hashes | Design | **Done.** One A and one H commitment per block, each opened once (D12; `layout.rs:1-5`) | none |
| 20 | Function-tagged queries sharing one lookup argument and table across layers | Design | **Done within a block** (three tags, one identity). Across blocks the table side is negligible | none |
| 21 | LogUp-GKR (Papini–Haböck): commit only the multiplicities | Literature | **Already lever D1** in the speed plan: privacy design plus a ruling. The researcher found counterexamples to naive private ports (`research/zkp-efficiency/handoffs/20261017-logup-star-private-view.md`) | −55% committed (H) [COUNTED, plan] |
| 22 | Lasso / TaSSLE / Shout / cq structured-table lookups | Literature | **Not applicable.** They pay off for huge or decomposable tables. cq is univariate KZG. Our tables are 256 entries | — |
| 23 | "MulLookup"-type permutation-map lookup with "poly-logarithmic soundness error" | One snippet [CLAIMED, unverified] | **Soundness-only pointer**, not a speed lever. The LogUp term sets the whole-run level at 8B T512 (94.7 bits, `results/zk60_soundness_recount_20261017/RECOUNT.md` §1). D27 already prefers LogUp-GKR with a 256-bit challenge for the next tier. Pass to the soundness lane as literature | — |
| 24 | Low-degree or piecewise polynomial approximations as a comparator | Suggested, unmeasured | **Worse here, and changes fidelity.** The table lookup also range-checks its input. A polynomial needs its own rounding remainders | — |
| 25 | Remove publicly masked (causal) entries | Design | **Already lever L7** (profile plus soundness review) | −19.6% committed [COUNTED] |
| 26 | Sigmoid through e^(−\|z\|) on a shared negative-exponential backend (ZKMath) | Literature | **Not applicable** (direct SiLU table) | — |
| 27 | Spend precision per stage (address width, rounding, normalisation) | Design | **Partly done** through calibrated profiles (D16, D24). Lowering fE would save softmax limbs but is a fidelity trade owned by the calibration lane, which fears the opposite at T512 | — |
| 28 | Workload: 369.36 M exponentials for Llama-3.1-8B at T512 (134.48 M causal attention plus 234.88 M SiLU; 503.32 M dense) | Arithmetic | **Verified.** We prove 268.4 M exp pairs (the dense score cube) plus 268.4 M SiLU pairs (F padded 14,336 → 16,384) = 536.9 M per pass. That is 45% above "useful". L7 removes the masked half. The F padding is about 3.6% of committed data (not costed here). **These pair lookups are only 5% of our 9.8 G byte lookups per pass**: range checks, not exponentials, are our lookup bill | — |
| 29 | Poseidon2 instead of MiMC; packing pairs per hash element; Groth16 key reuse; GKR product batching | 2.48× private (10.42 → 4.26 s); 2.95 → 1.18 s; GKR product: no gain [CLAIMED] | **Not applicable.** No in-circuit hashing, transparent setup, no factor products | — |

**Row 30: my extension of row 9.**

| # | Technique | The conversation's claim | Our status | Effect at 8B T512 / what it touches |
|---|---|---|---|---|
| 30 | **"Derive, don't store" applied to value planes (VPE)**. Its rule (row 9) applied to our remaining redundant planes. My extension, not in the conversation | — | **Applicable (§5.3).** X, AO, X1, X2, Z16 (D), U16, H16 (F) and P (S) each have a committed plane **and** full byte limbs tied to it by a clause (`argument.rs:1563-1573`, `:1640-1641`, `:1836`) | D 69 → 64, F 23 → 21, S 31 → 30 committed per entry. Block: **−5.4% committed, −7.2% element-terms**, U8 unchanged [COUNTED]. Needs a new profile, an update to the pad-zero lists, a privacy-gate re-run (IO and boundary claims move to limbs) and a GPU slot-18 kernel update |

## 4. Why most of it does not carry over

The conversation's own measurements end in the same place it lands in its last messages. The
cost that does not go away is **binding every request to its result**, plus **proving that
each rounding was done correctly**. Table construction is not that cost.

Our construction already pays the minimum for the binding: one pair lookup per entry into a
one-row table. That is why rows 4–8, 13, 22 and 26 have nothing left to offer.

The rounding cost is where we are heavy. A score entry at T512 has 31 committed base
elements [COUNTED], split as follows:

- **about 20.7 (≈ 67%): the exact division.** That is P, its 2 limbs, 3 σ limbs and 3 ρ limbs,
  plus their 11 lookups' helpers;
- about 3 (≈ 10%): the exponential;
- about 6: the score requantisation;
- 1: the argmax selector.

At T512 the score domain is 40% of all committed data, so the softmax division alone is
about 27% of a block. Rows 10 and 12 attack exactly that, which is why they are the two that
matter.

## 5. The applicable ideas in detail

### 5.1 EXR — exact shared row reciprocal (no ruling)

**Today** (`argument.rs:1834-1836`; S cube):

- c2: mask·E·2^F_P − p·Sum − σ = 0;
- c3: ρ + σ + 1 − Sum = 0;
- σ and ρ each lie in [0, 2^wρs), held in 3 byte limbs plus a top pin at T512 (wρs = 18).

So p = ⌊E·2^F_P / Sum⌋, with **two** wρs-bit range checks per score entry.

**Candidate:**

- **Per row (h, t):** commit Z with Z·Sum = 2^(B+F_P) + z_r and z_r ∈ [0, 2^wρs). That is one
  range check of 3 limbs plus a pin, per row.
- **Per entry:** mask·E·Z = p·2^B + r with r ∈ [0, 2^B). At B = 32 that is 4 byte limbs and no
  pin.
- c3 is deleted. p keeps its own limbs, as today.

**Lemma (exactness).** Assume:

- E ∈ [0, 2^fE], Sum ∈ [2^fE, 2^wρs], p ∈ [0, 2^(F_P+1)), r ∈ [0, 2^B), z_r ∈ [0, 2^wρs), all
  range-checked integers;
- 2^B ≥ 2^fE · 2^wρs;
- both 2^fE·(2^(B+F_P) + 2^wρs) and 2^wρs·2^(F_P+1+B) are below q.

Then the field relations force p = ⌊mask·E·2^F_P / Sum⌋, today's value.

*Proof.*

1. Multiply the entry relation by Sum and substitute the row relation:
   mask·E·(2^(B+F_P) + z_r) ≡ Sum·(p·2^B + r) (mod q).
2. Both sides are non-negative integers below q, so the equality holds over the integers.
   Hence p = ⌊mask·E·2^F_P/Sum + mask·E·z_r/(Sum·2^B)⌋.
3. The fractional part of the first term is at most 1 − 1/Sum. The second term is below
   2^fE·2^wρs/(Sum·2^B) ≤ 1/Sum.
4. So the floor does not move. ∎

What the proof also shows:

- **Z need not be an integer and is not range-checked.** The integer identity in step 1 is all
  that is used.
- **The window on z_r can be one-sided and wider than Sum.** That is why the per-row cost is a
  single range check.
- **Completeness:** the honest Z = ⌈2^(B+F_P)/Sum⌉ gives z_r < Sum ≤ 2^wρs.
- **Masked positions:** they give p = r = 0, as today.

**Checks** [COUNTED, `variants.py` part A]:

- **Exhaustive small cases:** fE 3–5, T 4–16, F_P 3 and 9, with z_r at the top of its window,
  which is the worst case. **0 mismatches in 140,708 cases** at B ≥ fE + wρs. With B below that
  bound, 864 mismatches, in all 36 configurations, so the bound is needed.
- **8B T512 geometry** (fE 9, wρs 18, F_P 9): 485,744 cases (every Sum at E = 2^9, a sweep of E
  near powers of two, and 200,000 random pairs). **0 mismatches at B = 27 and at B = 32; 8 at
  B = 26.**
- **No wrap at B = 32:** the largest side is 2^60, below q ≈ 2^64.

**Admissibility.** Exactness and no-wrap together allow B ∈ [27, 35] at 8B T512 with fE = 9,
F_P = 9. That is also true at F_P = 12, the calibration lane's possible precision increase,
where B ∈ [27, 32]. EXR is **not admissible for fE ≥ 12 at T512**: the trained class allows fE
9–16 (`N6/shape.rs:142`). So a profile using EXR must refuse such shapes by name, or fall back
to today's relation. The exp table already guarantees E ∈ [0, 2^fE], monotone
(`results/zk60_1b_native_20261017/r6/frozen-tree/hashline/src/tables_attn.rs:134-136`).

**Counts at 8B T512** [COUNTED]:

- **Score entry:** A 13 → 11, U8 15 → 11, Fp2 helpers 9 → 7, committed 31 → 25, slot-17 terms
  24 → 21.
- **New per-row data:** 4 A planes and 2 helpers on `Dom::Ht`, lifted to the row width by P-3
  (`layout.rs:170-176`). That is 8 rows, 0.04% of a block.
- **Block:** **−7.6% committed, −10.9% U8 lookups, −5.0% zero-check element-terms**. Laptop CPU
  law −5.4%. Roofline 37.1/57.3 → 39.8/61.4 positions/s at 25/40% of a 5090 [MODEL].

**What it touches:**

- **Soundness.** The lemma above needs an independent review (short). The LogUp term gains
  0.16 bits.
- **Privacy.** `Dom::Ht` becomes a lookup domain: a new part in the single LogUp sum claim,
  under the P-3 lift (the `log(Tab) == log_cols` invariant is untouched). The rank/CFS gate
  must be re-run on the new layout. Z and z_r are hidden per-row values of the same class as
  `A_SUM`.
- **Fidelity.** Unchanged, bit for bit: the witness p is identical.
- **Profile.** A new profile beside the old ones (D17).

Engineering: 4–6 lane-days plus one review round [MODEL]. Slot 17 is not yet on the GPU, so
no kernel is reworked.

### 5.2 FN — normalise the attention output after PV (needs a ruling)

**Today:**

- p_j = ⌊E_j·2^F_P/Sum⌋ per score entry;
- o8 = round(Σ_j p_j·v_j / 2^sh_o), with a 9-bit remainder (the Q-domain planes RO0 and RO1).

**FN:** o8 = round(2^(F_P−sh_o)·Σ_j mask·E_j·v_j / Sum).

- One division per (t, h, channel), with a two-sided remainder ρ ∈ [0, 2·Sum).
- PV multiplies the masked E instead of p.
- P, its limbs and σ/ρ disappear from the score domain. The argmax selector stays: the honest
  max still pins E.

**Counts** [COUNTED]:

- **Score entry:** A 13 → 5 (4 if PV reads the public mask trilinearly), U8 15 → 4, committed
  31 → 11 (10), terms 24 → 10 (9).
- **Q entry:** A 7 → 11, U8 13 → 18, committed 21 → 29, terms 15 → 22.
- **Block:** **−22.8% committed, −26.7% U8, −20.7% element-terms**, +0.42 lookup-soundness
  bits. Laptop CPU law −16.8%. Roofline 47.2/72.3 positions/s [MODEL].
- **With L7:** −29.8% committed, against −33.7% for the plan's L7 + L8 zkAttn sketch.

**Why it needs a ruling.**

- The quantized model's integer function changes. In a synthetic check, o8 moved in 52.7% of
  1,152 outputs (by at most 2 units). The mean error against float softmax fell from 0.64 to
  0.26 units [MODEL, synthetic exp table and random scores; indicative only, `variants.py`
  part B].
- So bit-exact parity with today's reference kernel is lost by construction. The reference
  kernel, the trained calibration and the fidelity acceptance must be redone, for example with
  a D25-T4-style token-agreement test.
- This is a **numerical-contract** ruling of the D24 kind. It is milder than L8's: the relation
  stays exact and deterministic, so the prover gets no slack and no adversarial bias.

**Comparison with L8 (zkAttn):** about the same data reduction for about half the cost (8–12
against 15–25 lane-days) [MODEL]. The privacy re-check is the same kind: new Q-domain limbs
and one new claim site on `A_SUM`. **FN and L8 are alternatives, and FN supersedes EXR**: all
three rebuild the same softmax division.

What it touches:

- **Soundness:** no wrap; |2N| < 2^27. Needs a review.
- **Privacy:** gate re-run.
- **Fidelity:** a ruling plus a calibration check.
- **Profile:** a new profile.

### 5.3 VPE — do not commit value planes that equal their limb sum (no ruling)

Eight planes are each tied to their byte limbs by a defining clause (for example
`c2: x + 32768 − l2(XL) = 0`, `argument.rs:1563`):

- **D:** X, AO, X1, X2, Z16;
- **F:** U16, H16;
- **S:** P.

Substituting the limb expression for the plane deletes the plane and its clause.

- **Inside their own zero-check** (slots 14, 17, 18) the limbs are already claimed at the same
  terminal point, so the claim count *falls* by one per plane.
- **Outside it,** each reader gains one claim site (2 mask rows):
  - SC_SS on X and SC_SSM on X1 (`argument.rs:1163-1178`);
  - IO-in on X and IO-out on X2 (`:1925`);
  - SC_DMM on H16 (`:1429`);
  - SC_PV on P (`:1404`).

**Counts** [COUNTED]: D 69 → 64, F 23 → 21, S 31 → 30 committed per entry. Block: **−5.4%
committed, −7.2% element-terms**, lookups unchanged. Laptop CPU law −5.5%.

What it touches:

- **Semantics:** unchanged (definitional substitution).
- **Padded domains (F pads at 8B):** the substituted value is −32768, not 0, on padded
  positions. Every clause and host term that reads it is already gated by the support
  indicator, and the padded weights are zero (P-2). But the pad-zero plane lists
  (`pad::zero_rule_a_planes`) change and must be re-reviewed.
- **IO and boundary claims** (D12, D12a, D17) move from X/X2 to their limbs. That changes the
  disclosed functionals, so the privacy gate must be re-run.
- **GPU:** slot 18 is the GPU lane's ported kernel, so it needs coordination.

Engineering: 5–8 lane-days plus review [MODEL]. VPE stacks with every other lever.

## 6. Ranking, and against the speed plan

All rows are at 8B T512 and are cumulative against today. "Bandwidth needed" is the
achieved fraction of a 5090's 1.79 TB/s at which the plan's roofline model gives 50
positions/s.

| Layout | Committed | U8 | Zero-check element-terms | Roofline pos/s at 25% / 40% | Bandwidth needed for 50/s | Cost (lane-days) | Ruling? |
|---|---:|---:|---:|---:|---:|---:|---|
| today | 663 M | 306 M | 496 M | 37.1 / 57.3 | 34% | — | — |
| + VPE | −5.4% | 0 | −7.2% | 39.0 / 60.3 | 33% | 5–8 | no |
| + EXR | −7.6% | −10.9% | −5.0% | 39.8 / 61.4 | 32% | 4–6 | no |
| + EXR + VPE | −13.0% | −10.9% | −12.2% | 42.1 / 64.8 | 30% | 9–14 | no |
| + FN + VPE | −27.0% | −26.7% | −26.2% | 49.6 / 75.8 | 25% | 13–20 | **yes** |
| L7 (plan) | −19.6% | −20.5% | −20.3% | 45.6 / 69.9 | 28% | 10–15 | profile + review |
| L7 + EXR + VPE | −28.2% | −26.0% | −29.2% | 50.5 / 77.1 | 25% | 19–29 | no |
| L7 + FN + VPE | −33.9% | −32.2% | −34.7% | 54.5 / 83.0 | 23% | 23–35 | **yes** |
| L7 + L8 (plan) | −33.7% | −35.6% | −33.9% | 54.4 / 82.9 | 23% | 25–40 | **yes** (slack) |
| L7 + L8 + VPE | −37.8% | −35.6% | −39.4% | 57.7 / 87.6 | 21% | 30–48 | **yes** (slack) |

Labels: the counts are [COUNTED]; the rates and the bandwidth figures are [MODEL], from
`results/zk60_speed_plan_20261017/projection.py`, reused unchanged. On the anchored basis
(plan step 4, whole prover on the GPU at the measured ratio bands, before L5):

| Layout | Positions/s, central |
|---|---:|
| today | 6.89 |
| + EXR + VPE | 7.66 |
| L7 | 8.20 |
| L7 + EXR + VPE | 8.96 |
| L7 + FN + VPE | 9.40 |
| L7 + L8 | 9.36 |

**By gain per lane-day:**

1. **FN** (if ruled): about 2.3% of committed data per lane-day.
2. **EXR**: about 1.5% per lane-day, which is L7's ratio (about 1.6%), with no ruling.
3. **VPE**: about 0.8% per lane-day, but it stacks with everything.

**Does any of it beat the speed plan's levers?**

- **Not the decisive ones.** L3–L5 (whole prover on the GPU, kernels at ≥ 25–35% of
  bandwidth) remain the necessary condition. Nothing here substitutes: the commitment kernel
  still decides the budget.
- **Among the layout levers, FN is the best ratio found so far.** It matches L8's reduction
  without prover slack, for about half the cost.
- **EXR and VPE are the cheapest reductions that need no ruling.** Together they are worth
  about two thirds of L7, for a similar cost.
- **Soundness side effect:** all three cut lookups, and the LogUp term is what holds the 8B
  T512 run at about 94.7 bits (D27's MVP target is about 95). FN adds +0.42 bits and L7 + FN
  +0.55.

**Integrated sequence** (one decision, not a menu):

1. Ask Victor the FN-versus-L8 question now; it is one ruling.
2. Meanwhile write VPE into the spec of the 8B T512 profile the plan already owes, so the
   profile, review and privacy-gate costs are paid once.
3. If FN is declined, add EXR to the same profile. If FN is accepted, skip EXR.
4. In either case the calibration lane checks fE ≤ 10 at T512 (EXR's admissibility) or FN's
   fidelity.

## 7. Claims I relied on, and how they were checked

- **369.36 M exponential sites; 57,408 normalisations per head.** Re-derived:
  32·512·14,336 = 234,881,024; 32·32·512·513/2 = 134,479,872; Σ_{i≤512} min(i, 128) = 57,408.
- **"Multiplicity range checks are unnecessary"** for LogUp soundness. True when the field
  characteristic exceeds the total lookup count. Ours is 9.8 G per pass, against p ≈ 2^64. It
  is already relied on here.
- **"The shared reciprocal changes rounding".** True for the conversation's B. False for
  B ≥ fE + wρs: §5.1 gives a proof plus exhaustive and sampled checks.
- **All of the conversation's timings** (gnark/Groth16, eight workers, three-trial medians,
  public IO) are [CLAIMED]. None is used in any estimate above. The MulLookup soundness claim
  is unverified.

## 8. Files and reproduction

- `REVIEW.md` (this file).
- `variants.py`: run with `python3 -I -B results/zk60_gpt_nonlinear_review_20261018/variants.py`
  (one thread, about 1.5 s). It contains part A (EXR exactness and admissibility), part B (FN
  synthetic fidelity) and part C (layout variants on the speed plan's replica, imported
  read-only).
- `variants.out.txt`, `variants.json`: its output.
- `PROGRESS.md`: the lane ledger.
- Input: `gpt_share_extracted.txt`, `SOURCE.txt` (untrusted data, unchanged).
