# Research handoff: does the smallness test fit knowledge soundness (T1b), or must the extractor rewind past Theta? (2026-11-17 UTC, claude tick 9)

From Claude, the background researcher (D50). Queue item 20 (H154), the check that could close candidate B.

**Scope.**
- **Read directly (raw files, not through a summarizer):** FlashProve `blocks/iop/rng.h` (40,679 bytes, lines 1-383 and 495-525: the check's statement, the shape rules, the whole comment before `rng_theta()` that is the source's argument, the honest-prover failure rule); `docs/format/11-1-machinery.md` lines 218-250 and 1425-1500 (the page's account of the same limits and the constants). Local: `ZK60_LEAN_PRODUCTION_STATEMENTS.md` section 3 (T1a, T1b), `formal/README.md` lines 160-171 and 234-254 (the straight-line extractor and the round-by-round framework as built), tick 5 and tick 7 handoffs. Not read: the authors' technical report (the comment says the count is argued there), ePrint 2020/1448 and 2021/1397 (cited, not opened), the Lean sources themselves. 2 fetches, 0 searches.
- One small `python3` toy (below, `20261117-claude-tick9-smallness-knowledge.py`, a few MB). No build, proof, GPU run or Git write.
- **Triage material, not a work order.** Any change to what is committed changes proof bytes and the verifier and needs the owner's ruling, a new profile string (D17) and re-proved Lean (D63). The owner shelved proof-size work on 2026-11-09; this concerns committed volume.

Labels: **[AUTHORS]** (their text), **COUNTED** (file:line), **TOY** (script output), **DERIVED** (arithmetic), **ASSUMED**.

## 0. Headline

- **Candidate B survives item 20, conditionally. The test as the authors argue it needs no rewinding past Theta.** Its error is the chance that Theta lets a *fixed, already committed* object pass although it is not explained by small integers. That is a statement about a decoded object, with the object fixed before Theta is drawn; the Lean framework already built here (a straight-line extractor on the commit log; round-by-round soundness with a state function that may read the log) is the form this takes. The authors' "no knowledge error" is a limit on their *printed union-bound number*, not a sign that extraction needs rewinding (my reading; see section 2).
- **Three conditions, none met today:** (1) a new Lean round with its own state function and a new combinatorial lemma (the "neighbouring values" step, section 3); (2) `circuit_iff` must hold for cells in (-2^18, 2^18), not bytes (the test proves less than honest cells meet, section 4); (3) the order requirement of tick 7 (every object and every weight fixed before Theta; joint packing-plus-reads form).
- **New number against B's honest-prover gate:** tick 5 sized the cell cap for a 1% honest failure. T1a's target is `eps_c <= 2^-40`. At 2^-40 the cap on honest RMS falls from about 453 to **about 311 at k = 4,096** (235 at k = 7,168) (DERIVED, section 5). This tightens item 17's threshold.
- The source's step is **argued on paper, not refereed** [AUTHORS]. It is the weakest link, not the extraction.

## 1. What the source says [AUTHORS, `rng.h` 6-25, 332-376; `11-1` 1435-1481]

1. **What RNG shows:** one integer matrix Y with |entries| < 2D (D = 2^17, so 2^18) has the committed packing and the committed reads. "A looser bound than honest cells meet."
2. **Order:** Theta is drawn only after every oracle message with packed cells or reads has its sample answered and the read weights are fixed; "a prover that knows Theta can alter a read by a vector on which all N combinations vanish."
3. **The argument for 2^-N (comment before `rng_theta`):** call a column (its packed entries and its reads together) *explained* if one integer column in (-2D, 2D) has this packing and these reads. Packed cells, reads and weights are "fixed before Theta, each as one object (beyond unique decoding this rests on the answered samples, whose round has its own error), so the first column that is not explained is fixed too." With all other Theta entries fixed, no two neighbouring values of that column's entry let combination u pass, "the difference of the two equations would explain the column." So the passing values lie in {0} or in {-1, 1}: probability at most 1/2 (hence 0 has probability 1/2). The N combinations use disjoint Theta entries: 2^-N. "Nothing is assumed about Psi": a lane may overflow and carry.
4. **Status:** "argued on paper and not refereed", "tried with exhaustive searches at toy sizes"; the Lyubashevsky-Nguyen-Seiler Lemma 2.5 / A.1 line (approximate range check) and the Gentry-Halevi-Lyubashevsky Lemma 3.4 distribution are cited, and the comparison with the second is not done. "A form that takes packing and reads apart has a hole."
5. **The union-bound line:** the printed `N - log2(columns)` bits is "the same event ... counted more coarsely. It does not cover a prover that is not bound to one object, it is no knowledge error, and no verdict depends on it."

## 2. Reading the extraction question

- **Why no rewind is needed.** The argument fixes the object before Theta: the state "some column of the extracted (M, U, phi) is unexplained" is a function of the commit log up to Theta. Theta then escapes that state with probability at most 2^-N, and nothing about the *value* of the witness is learned from the challenge. This is round-by-round soundness with a log-reading state function, the form `FSRbr.lean` / `FSWideRbr.lean` / `FSOpening.lean` already use (README 196-249: "round-by-round KNOWLEDGE soundness" for the opening, extraction from the log cut at the root's absorption). Rewinding would be needed only if the object were determined by Theta (a sigma-protocol special-soundness extractor); here the commitments come first.
- **What "no knowledge error" most plausibly means (ASSUMED, not stated in the text):** 2^-N is the error of a soundness event about one fixed object. It is not itself the probability that extraction fails, and the union-bound number is a coarser count of the same event. The two things T1b still needs come from elsewhere: extraction of M and U from the log (Merkle binding, `SoundExtract`: `collBound T + T(3q1 + 1)/|D|`) and proximity of the committed message to a codeword. The authors' "beyond unique decoding" clause is that second item: it rests on the answered out-of-domain samples in their setting; **locally it rests on the opening's proximity argument, whose bound is ASSUMED at 2^-106 pending F12** (README 252). So B adds no new gap there, and does not close the existing one.
- **Union bound is not needed for the Lean form.** The "first unexplained column" is fixed before Theta, so the event has probability at most 2^-N for it alone; conditioning on every other entry is legal. Tick 5/7's `tau - log2(columns)` (103.6-105.4 bits at tau = 128) is therefore conservative. Under the q-query Fiat-Shamir form the per-query rate is the *maximum* over the rounds (README 245-247), so a 2^-128 round does not move the 135/2^110 per-round maximum; even the coarse 2^-103.6 does not (DERIVED from the README figures, ASSUMED to carry unchanged).
- **Grinding:** under T1b's `q * 2^-lambda1` form the test costs `q * 2^-N` (a prover retries commit and Theta once per hash query), so N >= 100 meets lambda1 >= 100. N = 128 (FlashProve's multiple-of-32 rule [AUTHORS]) has 28 bits of margin (DERIVED).

## 3. The one new combinatorial lemma, tested

The "neighbouring values" step is a finite statement, so it can be checked exhaustively at toy size. **TOY** (`20261117-claude-tick9-smallness-knowledge.py`): D = 2, two lanes, radix 8 (4D-2 = 6 < 8), p = 59 ((4D-2)(1+8) = 54 < 59), one packed entry plus one read of weights (w0, w1) per column. Explained set = integers in (-4, 4); pass set = [-2, 2). For **every** pair of columns (the unexplained one, any other), with Theta in {-1, 0, 1} at (1/4, 1/2, 1/4), five weight pairs including one that does not separate the lanes:

- worst Pr[a combination passes] = **0.5000 exactly** in all five runs. The bound holds and is tight.
- With (1/3, 1/3, 1/3) the worst case is **5/9 = 0.556** in the same toy (above 1/2, approaching 2/3 with other column settings), which shows why 0 must have probability 1/2.
- The unpacking inside (-2D, 2D) is unique at these sizes (asserted). Uniqueness at the real constants is (f1), checked by tick 5.

This checks the single-combination step only (the N-fold product follows from disjoint entries). It does not test the lookup, the digits or the real field. It does support the authors' step as stated (including joint packing and reads).

## 4. What T1b and `circuit_iff` would have to absorb

1. **A relaxed witness.** The extractor returns integer cells in (-2^18, 2^18), where honest cells are bytes. `circuit_iff` ("range checks rule out wrap-around mod p") must then be proved for the looser cells, or the byte bound must be enforced separately by lookups on keys that are polynomials of the cells (tick 5 already said the test is a magnitude test, not an exactness test). **Count needed:** the largest sums of products with cells at 2^18 against p (a local arithmetic item, queued as item 23).
2. **The joint form.** EP (packing) and ER (reads) must share the same digits; the Lean lemma has to be about packing and reads together, as the authors warn.
3. **State function ordering.** Object set before Theta: M, U and phi committed and answered; digits `ZZ` and multiplicities after. Tick 7's schedule satisfies this with 2-3 extra commit-then-challenge phases.
4. **One more round in the composed protocol** (`FSCompose.lean` style, an `RbrWide` round with escape probability 2^-N and a log-reading state), plus the digit lookup's own soundness at n_Z = 26 keys per call (it carries the lookup's usual field-size error, not counted here).

## 5. Honest-prover failure against T1a (new)

[AUTHORS] a combination outside [-2^17, 2^17) has no digits and "there is no honest proof with these sampled entries"; the source counts it in the error of hiding and retries are forbidden unless private randomness is redrawn (`rng.h` 511-516). Locally that is a **refusal**, which T1a puts in `eps_c <= 2^-40` and the declared leakage L counts as one served/refused bit.
- DERIVED (Gaussian, k/2 non-zero terms, 128 x 499,712 combinations as in tick 5's example): cap on honest RMS cell so the total failure is at most the target:

| k | 1% total (tick 5) | 2^-40 total |
|---|---|---|
| 1,024 | 905 | 623 |
| 4,096 | 453 | **311** |
| 7,168 | 342 | **235** |
| 8,191 | 320 | 220 |

  (z = 6.40 vs 9.30 per combination.) A Hoeffding worst case for bounded cells divides these by about 1.4. The 2^-40 reading is mine (T1a's own words are "rare challenge values"); the owner could rule a larger refusal rate acceptable.
- Effect: item 17 (RMS of the int16 word planes) should compare against about 311 / 235, not 453 / 342. Planes with RMS near 100-200 pass either way.

## 6. Falsifiable tests (this project's terms)

- **H156 (Lean-shaped lemma).** Claim: for fixed (M, U, phi) with an unexplained column, Pr over Theta that all N combinations admit in-window digits is at most 2^-N, for the local field, lanes and radix. **Test:** (a) the exhaustive toy above (passed); (b) a second exhaustive run at a size with three lanes and radix 2^20-like proportions (D = 2, radix = 16, lanes = 3 needs p near 2^12 to 2^16, so a sampled check, not exhaustive); (c) the Lean statement. **Kill** if any worst case exceeds 1/2 (the toy did not).
- **H154 (answered):** the extractor need not rewind past Theta **on the authors' argument**; **kill** on paper if the object cannot be fixed before Theta locally (tick 7's order says it can, with new phases) or the local proximity step is not unique-decoding.

## 7. Honest effect

- **Committed words per request:** none changed by this reading. B's volume (tick 6, 8: whole block 0.80-0.90 of today's) stands; the only change is a tighter honest cap (section 5), which can force more splitting than tick 6 counted if the int16 word planes are near the cap.
- **Proved tokens per second:** nothing moved; B's Lean cost is one more round plus the relaxed-cell lemma (small next to the new commit phases), but the round has no timing.

## 8. Risks and what was not verified

- The key step is the authors' own, unrefereed. My TOY covers one combination at toy sizes, not the real constants, not the digit lookup.
- I did not read the technical report, the two cited papers, `rng_prove`'s implementation of the digits, or any Lean file; the framework description is from the README.
- "No knowledge error" is interpreted, not explained by the authors.
- The local proximity step beyond unique decoding is not checked here.
- The 2^-40 refusal reading is a choice; Gaussian tails at z = 9.3 depend on the real cell distribution.

## 9. Status

New proofs, passes, proved positions: **0 / 0 / 0.** The complete private 8B at >= 50 proved tokens/s remains **unachieved**. Hypotheses: 157 (H156 added; H154 answered on paper).

## 10. Next concrete actions

1. Items 21 and 18 can run (B is alive); item 23 (relaxed-cell wrap count) before any Lean statement.
2. Item 17: use caps 311 (k = 4,096) and 235 (k = 7,168).
3. Owner: the refusal-rate reading of T1a (2^-40 against 1%) is a ruling, not a speed tweak.
