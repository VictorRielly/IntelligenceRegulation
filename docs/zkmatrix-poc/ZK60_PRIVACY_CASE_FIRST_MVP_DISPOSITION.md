# Disposition of the privacy case for the first MVP — security owner, 2026-09-19

Written by the interactive Claude Fable 5.1 session (the security owner) at
23:50 on 2026-09-19. It rules on two delegated documents:

| Short name | Document | What it is |
|---|---|---|
| C | `ZK60_PRIVACY_CASE_FIRST_MVP.md` | the argument, in 28 labelled steps, for why a receipt of the toy private block would reveal nothing about its hidden input, output and activations, now that ruling D18 has the prover seal at proof time |
| C-check | `ZK60_PRIVACY_CASE_FIRST_MVP_CHECK.md` | an independent adversarial check of C (`results/zk60_privacy_case_check/`): 7 blocking items (B-1 … B-7), with corrections, omitted conditions and a corrected tally |

| Verdict | **The structure of the case is accepted as the project's working privacy argument for the first MVP. The case is NOT accepted as made: seven steps are open, and this is NOT a privacy acceptance.** The draft is returned for an errata pass against the check's table and the rulings of §2. |
|---|---|

## 1. What survived the attack

- **The structural claim, in the check's exact form.** Because the prover
  generates every commitment (D18), no simulator has to be constructed and no
  oracle point has to be programmed: the ideal-world program is the honest
  prover run on a fixed input, and the whole privacy question becomes one
  indistinguishability statement — *the receipt for hidden input w looks like
  the receipt for the fixed input*. **D18 removes the equivocation problem; it
  does not answer that question.** The code enforces more than the draft
  said: a third-party root does not type-check (`private_seam.rs:142-161`).
- **The all-zero input is a valid fixed input**, for every public statement
  the constructors admit. The check traced the integer witness builder on
  paper: zero annihilates every relation, and two constants keep the two
  divisions defined — `NORM_CEPS = 1` (`private_block/layout.rs:54`) and the
  pinned first entry of the exponential table (`private_block.rs:138`). The
  zero witness sits **exactly on two range boundaries** (16,383 of 16,384;
  512 of an inclusive 512), which the missing Rust test must pin.
- **No circularity.** The dependency graph of the 28 steps is acyclic. The
  defect is conditionality, not a loop.
- **The arithmetic reproduced to the byte**: the receipt size from the wire
  format, the byte-class table, 327,052 random field draws counted site by
  site, the exact 2^-96 per-draw distance, a total of at most 2^-77.7 for one
  toy proof. Three OS-seeded streams; no witness-derived or shared blinding
  source; **no data-dependent number of draws**.
- **U-3 is correctly identified**, and no generic-rank argument exists
  anywhere in the repository, its branches or worktrees.

## 2. Rulings

**C-1 (B-1): there is no 100-bit privacy target, and no new ask to Victor on
it.** He has already ruled: decision D9 accepts the sampler's residual as
stated, and the privacy statement reads "indistinguishable up to about 2^-72"
at the largest shape (2^-75 at the toy, which this case now counts more
finely as 2^-77.7 for the block). A 100-bit target would have put every
artifact out of compliance on the day it was adopted. The case quotes D9 and
then **lists every residual with its size**: the sampler term; the lookup
collision at 2^-112.0; the generic-rank term when C-5 is written; and the
larger residual of about 2^-62 that D9's own text records — the errata pass
must find what that term is (`ZK60_FABLE_TRANSCRIPT_REVIEW.md` §B.7), say
whether it applies to the block, and carry it if it does. The one-line
sampler change stays what D9 says it is: available if an auditor requires it,
byte-changing, not scheduled.

**C-2 (B-2): refusals are inside the game; only timing, memory and power go
to Victor as out of scope.** The project's own simulation model gives the
distinguisher the refusal channel (`ZK60_ENDPOINT_SIMULATION_MODEL.md:75,78`).
The check classified 18 refusal classes: one is witness-dependent (a zero
lookup denominator, 2^-112.0), two panics are argued unreachable, and three
were omitted by the draft (entropy failure, panics, refusal strings that name
the failing relation). The case carries that table, and "a refusal string
must not name a witness-dependent relation" becomes a condition on the code.

**C-3 (B-3): the randomness assumption is the standard one, stated in full.**
"The generator's whole output stream is indistinguishable from uniform" —
for the generator the code actually uses, named — which covers publishing any
part of the stream, in either direction. The draft's one-directional version
did not cover what the code does: `A`'s published salts are drawn before `H`'s
secret pads on one stream (`pcs.rs:673-674`). Recorded as a hardening for new
profiles, not a requirement: separate streams for values that will be
published and values that stay secret.

**C-4 (B-4, B-5, B-7): corrections accepted**, and the label scheme becomes
the check's six: PROVED 2 / PROVED-CONDITIONAL 3 / VERIFIED IN THE CODE 6 /
COMPUTED ON CAPTURES 7 / ASSUMED 3 / OPEN 7. **The honest count of proved,
unconditional, security-relevant statements is two.** B-5 is also a note for
the integrator: the legacy feed-forward configuration accepts a caller-chosen
seed outside test modules (`hashline/src/zk.rs:334-338`, labelled
`deterministic-test`); an accepted private profile must refuse it outside
tests, or carry the label where a verifier can reject it.

**C-5 (U-3a, the generic-rank step): commissioned as its own short lemma.**
The check's observation is accepted as the plan: "disclosed dimension zero"
is the non-vanishing of a minor whose entries are polynomials in the
challenges; **one capture at full rank proves that minor is not the zero
polynomial**; what remains is bounding its degree and naming the field the
challenges are uniform in, and the check's own sketch lands near 2^-121
(2^-114 with slack). Written and checked, it turns seven "computed on four
captures" steps into statements about all but a negligible set of challenges.
It changes labels, not the size of the bound.

**C-6 (B-6): the gate P10 is a new tool, not a mode of the old one.** Equal
fibre dimension does not show that a preimage exists, so the gate must
*exhibit* one: `preimage_exhibited` is a fail field, and the gate carries at
least two negative controls that test **its own** criterion (all ten in the
draft tested the old tool). Silence on the hash layer is a fail; "ARGUED, in
the stated model" is the honest label there.

**C-7: what goes to Victor, and when.** Not tonight. When the errata pass and
the lemma have landed, one page with a recommendation first: the random-oracle
model with the shared untagged hash domain recorded as a deviation (or fixed
in new profiles — the errata pass prices both); timing, memory and power out
of scope for the first MVP; rejected receipts never transmitted and retained
captures treated as publishing; and the check's further asks R-6 … R-9 if the
errata pass confirms they are his.

## 3. The path to a privacy acceptance of the toy block, as it now stands

1. **The zero-witness acceptance test in Rust** (about half a day; asserts the
   two boundary values). Engineering; additive; first step of the next lane.
2. **The generic-rank lemma** (C-5). Construction; commissioned tonight.
3. **The gate P10** as ruled in C-6, run on the four captures. Construction
   and tooling.
4. **The joint-law composition write-up** (U-3b) and **the nonlinear channel**
   (the case's item 21). Construction; the real work; not started.
5. **The rulings of C-7** from Victor.

Only after all five can I write "privacy accepted for the toy profile, in the
stated model, with these named residuals". The 125M profile then owes the
gate again from the start.

## 4. What I reviewed myself, and what was delegated

I read the check's hand-back report, its verdict, its blocking table and
decision D9's full text, and I read the seeded constructor the check flagged.
Ruling C-1 rests on D9 as Victor ruled it; C-3 is my own statement of the
standard assumption. I did not re-trace the witness builder or recount the
draws. Both documents were produced by delegated Opus agents, the second
instructed to assume the first was wrong. **Nothing here establishes a privacy
property.**
