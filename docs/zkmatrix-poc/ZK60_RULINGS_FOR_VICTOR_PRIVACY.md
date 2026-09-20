# Three privacy rulings for Victor — prepared 2026-09-20, 02:55

> **DECIDED 2026-09-20 13:45 — Victor, at the console: "Yes on D19 D20 and
> D21." All three accepted as recommended** (D19 with the separating hash tag
> in new profiles). Recorded in `ZK60_DECISIONS.md`; the toy-profile privacy
> statement came into force at 13:46 as register entry D22. The two "not
> urgent" items further down (a run's soundness level; the 484 MB receipt) are
> still open and still not urgent.

Prepared by the interactive Claude Fable 5.1 session (the security owner).
**Nothing here is decided until you say so.** Each item gives my
recommendation first, then what it means in plain words, then what reopens it.

## Why these three, and why now

The fast line has one complete hidden transformer block at a toy size. Since
your ruling D18 (the prover seals its own input), the privacy question for it
became a single one: *does a receipt look the same whatever the hidden input
was?* Overnight that question was broken into steps, each drafted by one agent
and attacked by another told to assume it was wrong:

| Step | State |
|---|---|
| The all-zero input really proves and verifies (so "the same whatever the input" has something to compare against) | **done, measured** |
| Nothing is disclosed on any run the prover does not refuse, per commitment | **core accepted** (checked against the four real receipts' own schedules, 126 challenge vectors, no mismatch) |
| A gate that, from each real receipt, *constructs* blinding values reproducing the verifier's view under the all-zero input | **built; 802,920 entries per input, none differing; 10 channels still open** |
| The channels combine into one joint law that does not depend on the input | **core accepted** for the toy block; two gaps: the hash layer, and every larger shape |

What stands between this and my being able to write **"privacy accepted for
the toy block, in the stated model, with these named residuals"** is mostly
*the model itself*, and the model is yours to accept, in the way you accepted
D3, D4, D7 and D9. None of this is a privacy acceptance today, and the 125M
block will owe all of it again at its own shape.

## Proposed D19 — the hash functions are modelled as random oracles

**Recommendation: accept.** It is the standard model for every proof system of
this family; there is no known way to do without it here.

*Plain words.* The proof turns an interactive conversation into a single
message by hashing (the Fiat–Shamir step), and it hides the committed columns
behind salted hashes in a Merkle tree. The privacy argument treats BLAKE3 as
an ideal random function in both places. If BLAKE3 had a structural weakness,
the argument would not cover it — the same is true of essentially every
deployed system of this kind.

*One recorded deviation inside it.* The transcript hash and the Merkle hashes
use the same function with no separating tag. The overnight check narrowed
this a great deal: challenges come from 47-byte inputs, a length nothing else
in the system uses, so a challenge can never coincide with a tree node; the
one 64-byte transcript input collides with the node format only at a fixed
suffix, about 2^-241 (an earlier count of 2^-243 left out one tree and all
the inner nodes; corrected 04:11 by an independent recount — either way it is
far below every other term). **I recommend recording it as a deviation for the toy
profile and adding a separating tag in new profiles** (the 125M profile is
new, so no frozen proof bytes move).

*What reopens it:* a published weakness in BLAKE3's use as a random function,
or an auditor who requires tags everywhere — then the toy profile is re-frozen.

## Proposed D20 — timing, memory and power are out of scope for the first MVP

**Recommendation: accept, with refusals explicitly NOT included.**

*Plain words.* The argument is about the bytes of a receipt. It says nothing
about how long the prover took or how much memory it used, which can depend on
the input. For a first MVP that a regulator verifies from bytes, that is the
usual boundary. **Refusals are different and stay inside the argument**: the
prover sometimes declines to finish (about one run in 2^62), and we showed
that whether it declines depends only on the random challenges, never on the
hidden input. One refusal class out of eighteen does depend on the input, at
about 2^-112, and it is listed as a named residual rather than ignored.

*What reopens it:* a deployment where the verifier can time the prover on
chosen inputs.

## Proposed D21 — rejected receipts are never sent, and saved captures count as publishing

**Recommendation: accept.**

*Plain words.* Two operational facts came out of reading the code. First, if
the prover's own final check fails, it still writes the whole rejected receipt
before saying so; the argument covers only receipts that verify, so a rejected
one must never leave the machine. Second, the diagnostic "capture bundles" we
save for the privacy tools contain the full verifier's view by design; they
are safe exactly because they contain nothing more — so they are to be treated
like published receipts, and nothing derived from a hidden input may ever be
added to them. (I already refused one such addition overnight.)

*What reopens it:* any tool or service that ships a receipt before verifying
it, or a capture format that gains a field computed from hidden data.

## What I am NOT asking

- No new statistical target. You ruled D9: the statement reads
  "indistinguishable up to about 2^-72" at the largest shape. A proposal for a
  100-bit target appeared in a draft overnight and I withdrew it — the design
  would have missed it on day one.
- Nothing about sealing in advance (option B). It stays a recorded todo; the
  choice of hash for it will come to you when it is scheduled.
- Nothing about speed. Unchanged since yesterday afternoon: 58.4 s measured
  for the 8B pass on the laptop, about 4–5 s of measured software gains, the
  rest waits for the 5090 desktop.

## One product fact you should know (not a ruling)

The "about 2^-72 to 2^-78 per proof" you accepted in D9 is **per proof**, and
it adds up: over many proofs by the same prover it grows linearly — about
2^-57.7 at a million proofs of the toy block [COUNTED, checked twice]. That is
still a very small number, and the one-line sampler change D9 describes would
remove it if a deployment ever needed it removed. Nothing to decide now.

Also for services, a rule I am attaching to D21: when the prover refuses an
input it does not admit, **the reason is never shown to anyone not entitled to
the input** — a few refusal messages name what was wrong with it.

## Two more, not urgent (added 2026-09-20 09:46) — for when the multi-block run exists

Neither blocks any work today. Both are yours, and I would rather you see
them coming than meet them in a status line.

- **Soundness of a whole run.** A private run of twelve blocks at the 125M
  shape would have a whole-proof soundness of about **2^-97.5** by the
  project's own accounting [COUNTED; one block measured, the run not built].
  That is the level you accepted for the slow line in D3 (about 97 bits). The
  per-opening figure people quote (about 106 bits) is not the whole-proof
  figure; decision D15 already says so. **Recommendation when it comes:
  accept about 97 bits for native-line runs, as for the slow line.**
- **Proof size.** One private block at the 125M shape is 40.8 MB [MEASURED];
  twelve blocks are about 484 MB [COUNTED], verified one 40 MB segment at a
  time. The contract's budget is 256 KB. The one lever that shrinks the proof
  a lot (decision D10) cannot run privately, which is why you declined it.
  **Recommendation when it comes: record the size as a deviation for the
  first MVP**, and keep "a small outer proof about the big one" (as the slow
  line does with Groth16) as the recorded route to a small receipt.

## If you answer in one line

"D19 yes, D20 yes, D21 yes" is enough. If you want the tag added to the toy
profile too (a re-freeze), say "D19 yes, tag everywhere".
