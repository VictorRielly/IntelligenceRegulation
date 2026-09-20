# Privacy statement for the toy private-block profile — DRAFT, NOT IN FORCE

Written by the interactive Claude Fable 5.1 session (the security owner) at
05:32 on 2026-09-20.

| Status | **DRAFT. This is the statement I am prepared to sign for ONE profile once the project owner has ruled on proposed D19, D20 and D21. Until then it is not in force, and no page of this repository may quote it as an acceptance.** It assembles the conditions of five dispositions into one text so that the acceptance, when it comes, is a change of status and not a new argument. |
|---|---|

## 1. Scope — exactly one artifact

The profile `hashline-zk-mr1/private-block-t32-poc/1`: one complete transformer
block at 32 tokens, width 16, hidden 16, on **public synthetic weights**, with
hidden input, hidden output and hidden activations, the prover sealing its own
endpoints at proof time (decision D18, option A). Receipt 2,816,472 bytes.

**Not in scope, each owing the whole argument again at its own layout:** the
toy private-attention profile taken alone (the gates cover it; the composition
and hash-layer memos were written for the block); the development rung and the
125M profile (different matrices, padding, grouped heads, a pad-zero term, a
generalised endpoint, a separating hash tag); any feed-forward-only private
pass; any proof on real weights; sealing in advance by a third party (decisions
D8 and D11 bind that configuration and are untouched); the zkVM line.

## 2. The statement

> In the random-oracle model for BLAKE3 (proposed D19), and assuming the
> prover's randomness generator's output stream is indistinguishable from
> uniform, a verifier who receives an **accepted** receipt of this profile and
> makes at most `q ≤ 2^128` hash queries sees a view whose distribution is
> within **about 2^-77.7** of a distribution that does not depend on the
> hidden input, output or activations — per proof. Whether the prover
> **refuses** is, up to 2^-112, a function of the verifier-visible random
> challenges alone and carries no information about the hidden data.

## 3. What it rests on

| # | Step | State | Where |
|---|---|---|---|
| 1 | The all-zero hidden input is admissible, proves and verifies | measured (Rust test, pinned boundaries) | `zero_witness_tests.rs`, lane `zk60-private-block-125m` |
| 2 | Per commitment, the linear view discloses nothing on any run the prover does not refuse | core accepted; reduction includes the individual claims | `ZK60_GENERIC_RANK_LEMMA_DISPOSITION.md` |
| 3 | The gate constructs blinding values reproducing each captured view under the all-zero input; joint figure computed; masking commitment closed | measured on four real receipts; 11 channels constructed, 7 open by design | `ZK60_PRIVACY_CASE_FIRST_MVP_DISPOSITION.md`, step-3 blocks |
| 4 | For fixed challenges the *joint* law of all published field values is input-free (uniform-blinding idealisation) | core accepted; its one supplied step independently reviewed and corrected | `ZK60_JOINT_LAW_COMPOSITION_DISPOSITION.md`, `ZK60_TERMINAL_SURJECTION_REVIEW.md` |
| 5 | The hash layer adds nothing, and the fixed-challenge theorem lifts to the hashed protocol | core accepted, in the model of D19 | `ZK60_HASH_LAYER_AND_FS_LIFT_DISPOSITION.md` |

Every step was drafted by one delegated agent and attacked by another
instructed to assume it wrong; I ruled on each check. **I have not re-derived
the mathematics myself, and the Python ports of Rust code used by step 3 are
equal to the Rust by one agent's reading each.** Those two sentences are part
of the statement.

## 4. Residuals, listed and sized

| Term | Size | Kind |
|---|---|---|
| The sampler's reduction bias (decision D9, accepted) | 2^-77.7 per proof; grows linearly — about 2^-57.7 at a million proofs | distance |
| Zero lookup denominator (the one input-dependent refusal class of eighteen) | 2^-112.0 | distance |
| Guessing an unopened leaf's salt | `q · 2^-242.4` | distance |
| Oracle collisions; the 64-byte absorb overlapping the node format | 2^-229.8; 2^-233.1; 2^-241.4 | distance |
| Challenge pre-query | `q · 2^-244.0` | distance |
| The generator | the named assumption; inside the model alternatively `6q · 2^-256` (labelled ASSUMED — it needs a stronger property of the hash) | assumption |
| Refusal on degenerate challenges | 2^-62.0 (four base-field determinants, `4/p`) | **liveness, not distance** |

## 5. Conditions — if any of these changes, this statement lapses for the changed code

1. One reserved mask pair per claim site, with weights of the exact shape
   `(cm, cm·U)`; the single deliberate exception is the helper commitment's
   shared zero-sum pair. **`audit_claims`' pair-exclusivity check is the whole
   defence against a shared pair** — the privacy tools' reduction cannot see
   one.
2. The pad count equals the number of opened columns, per row, always.
3. `d + 1` values published per sumcheck round; the exact-row-span assertions
   in the commitment code; the refusal on a zero mask challenge; the declared
   order of the mask functionals (machine-checked, 34 of 34).
4. One opening per commitment; a refusal is terminal (no retry with the same
   endpoints — enforced by the type system).
5. Every Merkle leaf is salted with 32 fresh bytes; no unsalted column digest
   is ever published, logged or captured.
6. Fresh operating-system randomness per proof; no seeded configuration on
   this profile's path.
7. The source pins of the Python gates: a change to any pinned Rust file
   suspends step 3 until it is re-read and re-pinned.

## 6. Out of scope by ruling (proposed D20, D21), and operating rules

- Timing, memory and power.
- A receipt the prover's own final check rejected is **never transmitted**.
- A retained capture bundle counts as **publishing**: nothing computed from a
  hidden input is ever added to one.
- A refusal reason is never shown to anyone not entitled to the input.

## 7. What must not be claimed, even when this is in force

That the fast line is private "at model scale"; that the 125M block is
private; that real weights or real data have been proved privately; that
sealing in advance is covered; that soundness was reviewed here (it was not:
one flagged ambiguity — Merkle node and salted-leaf inputs are both 64 untagged
bytes — is recorded for the integrator, unchecked); that this is a proof in the
mathematician's sense rather than an argument each of whose steps survived one
independent attack.

## 8. What would bring it into force

Victor's one-line answer on D19, D20 and D21
(`ZK60_RULINGS_FOR_VICTOR_PRIVACY.md`). On that day the status line above
changes, the register gains the acceptance as an entry of its own, and
`MVP_STATUS.md` gains one sentence — for this profile and no other.
