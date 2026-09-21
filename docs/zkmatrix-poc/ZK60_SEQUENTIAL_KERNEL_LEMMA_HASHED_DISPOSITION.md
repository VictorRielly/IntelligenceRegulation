# The sequential-kernel lemma for (field, hash) messages — disposition

By the interactive Claude Fable 5.1 session (the security owner), 2026-09-21,
02:19. It rules on `ZK60_SEQUENTIAL_KERNEL_LEMMA_HASHED.md` (a delegated
agent's draft of tonight) after `ZK60_SEQUENTIAL_KERNEL_LEMMA_HASHED_CHECK.md`
(an independent agent told to assume the draft wrong, with its own brute-force
script in exact rationals).

**Nothing accepted changes.** Register entry D22 (the toy block) rests on the
random-oracle hybrid of its step 5 ("Route A"), not on this lemma; its
sentence, its 2^-77.7 and its conditions stand exactly as they are. No privacy
is claimed for anything else.

## 1. What survived the attack

- **The lemma is proved, with changes.** Its engine — the path identity — and
  the two statements built on it survived every attack: brute force at two and
  three rounds, with aborts, over 4,101 challenge schedules each (constant,
  hash-part-only, field-bit-encoding, round-parity) and every completion of a
  truncated challenge vector: **no mismatch, adaptive distance 0.** The draft's
  own evidence had never left one challenge round; the checker's did.
- **Which hypotheses are needed, measured:** causality — needed (a non-causal
  prover has distance 0 at every fixed challenge vector and 1/2 adaptively);
  independence of the challenge source from the prover's internal randomness —
  needed, and **not all-or-nothing: leaking one bit of it gives adaptive
  distance 1 while the fixed-challenge hypothesis holds everywhere**; the
  fixed-challenge hypothesis — needed; **a hypothesis the draft never numbered
  — every word the transcript absorbs must be public — needed** (a challenge
  function reading one hidden absorbed word gives adaptive distance 1).
  **"The witness fixed before the first message" is NOT needed**: two adaptive
  witness sources that satisfy the other hypotheses give distance 0. The
  question I put to two checkers tonight was the wrong question; the honest
  prover's witness is fixed by the privacy game's quantifier, and appealing to
  the commitment's binding for it was a category error.
- **Every number reproduces** (toy 2^-77.68, twelve-block 125M run 2^-69.29,
  both the sampler). The one-bit difference in the lookup-refusal term is not
  an error: last night's 2^-118.4 per block is the one-world event; **in a
  distance bound between two worlds the union over both is forced** (a
  single-world flag violates the bound by 3/8 on the checker's example), which
  is the draft's 2^-117.4. Both figures stay, each labelled with what it is.
- **The draft's negative findings stand, sharpened:** the naive approximate
  form is false with blow-up `|C|²` at two rounds (not `|C|`); the correct
  lossy form, `d ≤ Σ_ρ TV_ρ`, falls out of the same identity and is tight.
  Correction K-1 to the toy hash-layer memo touches **no accepted sentence**
  (the checker searched the statement, the draft statement, every disposition
  and the register): it lives in one row of a comparison table, and its real
  novelty is narrower than the draft said — the older field-only lemma's own
  proof already excludes witness-dependent refusals; what is new is that its
  bound is per-challenge-vector and cannot bound the adaptive probability.

## 2. Rulings

**K-R1 (the check's B-1) — a query-class overlap is a failure of a hypothesis,
not a bad event.** The draft put "the prover's hash queries meet the
challenge-derivation queries" inside the fixed-challenge bad event. It is the
event that makes the *independence hypothesis* false, it is consumed where the
challenge source is fixed and not at the end, and — as the one-bit-leak
computation shows — a failed hypothesis cannot be priced as a bad event.
**Repair accepted: one explicit hybrid hop from the real world to the world
where the classes are disjoint, at the same price.** After it the honest
headline is: *the composition itself needs no model of the hash; reaching the
world where its independence hypothesis holds costs one hop in the model; and
the fixed-challenge hypothesis is a statement in the model throughout.* The
draft's "proved in a weaker model" is cut back to that.

**K-R2 (B-2) — the independence hypothesis is not yet a verified fact of the
code.** The draft's five-way partition of oracle queries is incomplete on the
production path: the generator's **seed derivation** is a keyed hash of an
input that is *exactly 64 bytes* at the generalised endpoint (separated from
leaves and nodes by its key and mode only, not by length); the transcript
**constructor** is a third format under the transcript key; the statement,
schedule and spec digests are **unkeyed even under a tag**; "40 bytes is used
by nothing else" is false crate-wide (already known, ruling L-3); and a
position tag **re-issues the live transcript's next two squeeze inputs
verbatim** — harmless only because the live chain's next operation is always
an absorb or the end of the run (now pinned by the lane's stage-24 test).
**Ruling: a complete query-class table — every oracle query kind on the toy's
path and on a run's path, its mode, key, input layout and length, and why it
is disjoint from every other — is owed as a document with a test behind each
row. Until it exists, the independence hypothesis is a hypothesis.**

**K-R3 (B-3) — "O-4 is closed" is refused: it is REDUCED.** The
fixed-challenge hypothesis the lemma needs is about the **joint** law of the
field values, the **published salts**, the hash objects and the no-bad-event
flag. The accepted theorems do not deliver that: they are field-only, their
probability space excludes the salts and publishes them, and the block memo's
own table calls the independence of salts and blinding "the one candidate with
no structural answer", resting on the generator assumption. **The owed
sentence, in the checker's words: at every non-refused challenge vector the
joint law of (field view, published salts, hash objects, flag) is
witness-free, with the blinding uniform conditionally on the sampler's good
event and the salt segment of the stream independent of the blinding
segments.** The hash-layer lemma owes its half too. That is new mathematics,
not an erratum; it is the next paper task, and it is where ruling R-3's
counterexample (two blinding rows with coinciding values) has to be aimed.

**K-R4 (B-4, B-5, B-7, B-9 … B-13) — errata.** The sampler coupling works for
the rejection-region coupling only (a maximal coupling breaks under
conditioning); "none is added" is measured against a tally missing five rows
the accepted tables carry; publicness of absorbed words becomes a numbered
hypothesis, matched to the code (the verifier recomputes every absorb, so it
holds by construction — say so with the lines); "the model-free claim" is
reworded per K-R1; the bad probability is defined past an abort; the draft's
evidence is extended to several rounds using the checker's script; its private
coinages ("Game ⊥", "Game prefix") are defined where first used or replaced by
the project's words (accepted receipts only, per D21 and rule M-9); citation
defects fixed.

**K-R4a (2026-09-21 02:42) — the first sentence of K-R4 was wrong, and the
errata editor caught it.** I had ruled, following the check's B-4, that the
sampler coupling "works for the rejection-region coupling only … number
unchanged". The two halves cannot both be true. For the field's modulus,
`2^128 mod p = p − 2^32`, so the rejection region has probability
`r/2^128 = 2^-64` per draw while the distance from uniform is `2^-96` per
draw; and **no event that leaves the sample exactly uniform can be smaller
than the rejection region** (a residue above `r` has mass `k/2^128`, which
bounds `(1 − Pr[B])/p`). I recomputed all three in exact integers. In event
form the sampler would cost 2^-45.7 at the toy and 2^-37.3 for a twelve-block
run. **Ruling: the sampler idealisation stays a distance hop, taken before the
lemma** — the draws sit at schedule-determined positions and the view is a
function of them, so the view moves by at most `N · 2^-96`, decision D9's
accepted 2^-77.7 and 2^-69.3 — **and `B_samp` leaves the lemma's flag.** This
is what the toy's accepted step 5 already does; nothing accepted moves. The
lesson is the checker's as much as mine: a number carried from one proof form
to another has to be re-derived in the new form.

**K-R5 — the game.** The project's statements are about **accepted receipts
only** (D21; M-9 for a run). The checker confirmed on one protocol that the
lemma's fixed-challenge hypothesis holds under that game and fails if
refused prefixes are handed to the adversary — one more reason M-9 is a
condition of any run statement and not a courtesy. What the abort
*probability* itself tells a relying party is priced separately (the refusal
terms), and stays so.

## 3. Where step 5 stands after this

| | The toy (accepted, D22) | A run |
|---|---|---|
| What it rests on today | the random-oracle hybrid (Route A), accepted | the same hybrid, conditional on the run's open gaps |
| What this lemma adds | a second, shorter route — **not yet usable**: owes K-R1's hop, K-R2's table, K-R3's joint sentence | the same |
| Does any accepted sentence change | **no** | none exists |

## 4. What I checked myself, and what was delegated

Myself: nothing in the mathematics. I read both reports against each other and
against last night's rulings; on every point where they differ I find the
checker's computation decisive, and on the one point that was mine — asking
whether the header makes "the witness fixed first" a code fact — the checker
showed the hypothesis is not needed at all.
