# Disposition of the hash layer and the Fiat–Shamir lift — security owner, 2026-09-20

Written by the interactive Claude Fable 5.1 session (the security owner) at
04:11 on 2026-09-20. It rules on two delegated documents:

| Short name | Document | What it is |
|---|---|---|
| L | `ZK60_HASH_LAYER_AND_FS_LIFT.md` | a draft of the last named gap of the toy block's privacy argument: the hash layer, and the lift of the fixed-challenge theorem to the real protocol in which every challenge is a hash |
| L-check | `ZK60_HASH_LAYER_AND_FS_LIFT_CHECK.md` | an independent adversarial check (`results/zk60_hash_layer_fs_lift_check/`): 4 blocking items (B-1 … B-4), corrections, a table of code conditions with their truth today, a corrected tally |

| Verdict | **The core is accepted for the toy block, in the random-oracle model — which is a PROPOSED ruling (D19), not an accepted one: the hash layer adds nothing a verifier can use, and the whole view of a verifier making `q` oracle queries is within a listed sum of residuals of the honest prover's view on the all-zero input, dominated at every `q` up to 2^128 by the sampler term decision D9 accepted (2^-77.7).** The draft is NOT accepted as written and goes back for an errata pass. **This is not a privacy acceptance**: the model is unruled, one hop of the hybrid is missing, and every larger shape owes all of it again. D8 and D11 are untouched. |
|---|---|

## 1. What survived the attack

- **Every number.** The check recomputed each term from its own script and
  all agree; the sum at `q = 2^128` agrees to eleven figures. It also
  re-derived the 327,052 random field draws call site by call site: exact. No
  term of the form `q · 2^-k` hides near `k = 128`.
- **The central move is the right one**: the argument is about the
  *conditional* law of the hash objects given the field view, not a second
  marginal — which is exactly what the project's known counterexample
  requires. **The bound rests on the 256-bit salt alone; it does not use the
  entropy of the hidden columns**, and that is how it must be read: given the
  view and the hidden data an unopened column is determined, and only the salt
  hides it.
- **Challenge queries are 47 bytes, unique unconditionally.** No commitment in
  the toy block has 5 or 8 rows (455 / 384 / 50 / 7 / 7), so no column hash
  lands on a reserved length.
- **The overlap term is 2^-241.42, and the draft was right**; the earlier
  2^-243 counted the four 2,048-leaf trees' leaves only. Corrected in the
  owner-facing documents today. (The true bound, using both halves of the
  64-byte input, is nearer 2^-497.)
- **Many proofs compose by a union bound**, with no cross-proof object: one
  policy admits at most one proof, and the legacy seeded constructor is
  unreachable from the block. **The sampler term grows linearly with the
  number of proofs: about 2^-57.7 at a million proofs** — a product fact for
  Victor, added to the rulings page.

## 2. Rulings

**L-1 (B-2): the missing hop is written.** The hybrid invokes a theorem stated
for uniform blinding without first replacing the real, slightly biased
blinding by uniform. That hop is where decision D9's 2^-77.7 enters, once per
proof, and it must be an explicit step — together with the statement that the
generator's refills are non-adaptive.

**L-2 (the generator): the standard assumption stays primary.** The draft's
observation is real — the generator is unkeyed BLAKE3 over key and counter, so
inside the random-oracle model its pseudorandomness could be derived rather
than assumed — but the derivation needs the hash to be *indifferentiable* from
a random oracle, not merely consistent as an extendable output, and I will not
put that to Victor as a side effect. **The privacy statement keeps the named
assumption of ruling C-3 (the generator's whole output stream is
indistinguishable from uniform); the in-model derivation is recorded as an
alternative, labelled ASSUMED.** The generator term is completed with the
route the draft missed (guessing the operating-system entropy): `6q · 2^-256`.

**L-3 (B-3): "40 bytes is unique" is false across the crate and is rescoped.**
Two other transcripts start with 40-byte inputs (`private_seam.rs:26`,
`public_block_receipt.rs:20`), both off the block's path. The claim becomes
"unique on the block profile's path", is demoted accordingly, and the code
conditions the check tabulated become **assertions or tests, byte-free, on the
125M lane**: C-H1, C-H4, C-H8 and the new C-H4′ (no 28- or 35-byte transcript
domain). C-H2 is recorded as false crate-wide and irrelevant to the block.

**L-4 (B-4): the refusal rate is counted, not imported.** The draft quoted
2^-62.0 against the privacy case's own "open, do not guess". The check's count
rescues it for the block — four base-field determinants, `4/p ≈ 2^-62.0` — and
that count, with its provenance, replaces the import. The privacy case's open
item on the block's refusal rate is closed by it, as a liveness figure.

**L-5 (B-1): provenance is brought up to date.** The terminals step was
independently reviewed at 03:49; its three conditions travel with the theorem
wherever it is cited: the reserved pair's weight *shape*, the helper
commitment's shared zero-sum pair as a stated exception, the pad budget.

**L-6 (refusal strings): a service-boundary rule, not a blocker.** Some
refusal strings are data-dependent (`private_block/witness.rs:80, 271, 287`),
but only for inputs the statement does not admit; the statement as quantified
is unaffected. Rule for any service built on this: **a refusal reason is never
returned to anyone who is not entitled to the input.** It joins proposed D21.

**L-7 (flagged, not chased): node and salted-leaf inputs are both 64 untagged
bytes.** For hiding it is a 2^-484.8 term. For *binding* it is the classic
internal-node-as-leaf ambiguity; with fixed-depth trees and position-checked
paths it would need a preimage, and I do not believe it is exploitable — but
nobody has checked soundness here. It goes to the integrator as a note, and it
is one more reason for the separating tag in new profiles.

## 3. Where the privacy path now stands — every paper step has a checked core

1. The all-zero input proves and verifies — **done**, measured.
2. The generic-rank lemma — **core accepted**; its reduction now includes the
   individual claims.
3. The block-scope gate — **built**; 10 channels open (the masking
   commitment's own opening above all); batched-group tests being added.
4. The joint-law composition — **core accepted**; its one unreviewed step is
   now independently reviewed and corrected.
5. The hash layer and the lift — **core accepted here**, errata pass owed.
6. **Victor's rulings D19–D21** — the item on the critical path.

What I can write once 3's open channels are closed, 5's errata are in and
Victor has ruled: **"for the toy private-block profile, in the random-oracle
model, the view of a verifier is within about 2^-77.7 of a distribution that
does not depend on the hidden input, per proof; residuals listed; side
channels out of scope; refusals in scope."** For the toy profile only. The
development rung and the 125M profile owe every step again, at their own
layouts, with a separating hash tag.

## 4. What I reviewed myself, and what was delegated

I read the check's hand-back report. L-2 is my own judgement: a privacy
statement should not quietly depend on a stronger property of the hash than
the one being put to the project owner. I did not re-derive any term or
re-read the hashing code. Both documents were produced by delegated Opus
agents, the second instructed to assume the first was wrong. **Nothing here
establishes a privacy property.**
