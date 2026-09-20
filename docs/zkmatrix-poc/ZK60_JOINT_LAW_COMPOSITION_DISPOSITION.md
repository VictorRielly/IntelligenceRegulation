# Disposition of the joint-law composition — security owner, 2026-09-20

Written by the interactive Claude Fable 5.1 session (the security owner) at
02:50 on 2026-09-20. It rules on two delegated documents:

| Short name | Document | What it is |
|---|---|---|
| J | `ZK60_JOINT_LAW_COMPOSITION.md` | a draft argument for the step the project calls U-3b, with the nonlinear link: for fixed challenges, the *joint* law of every field value a toy-block receipt publishes does not depend on the hidden input |
| J-check | `ZK60_JOINT_LAW_COMPOSITION_CHECK.md` | an independent adversarial check (`results/zk60_joint_law_composition_check/`): 4 blocking items (B-1 … B-4), 14 corrections, 7 conditions, a corrected tally |

| Verdict | **The theorem's core is accepted for the toy block, in this exact form: at fixed challenges the prover does not refuse on, and in the idealisation where the prover's blinding is uniform, the joint law of the published field values is the same for every admissible hidden input.** The checker, instructed to assume it wrong, could not break it and found it stronger than drafted. **The draft is NOT accepted as written** and goes back for an errata pass. **This is not a privacy acceptance**: the hash layer and every other shape are outside it, and the real prover is not the idealised one. |
|---|---|

## 1. What survived the attack

- **No circularity.** The hypothesis about the four commitments reads like the
  conclusion but concerns a strict sub-view, and the section that discharges
  it uses nothing from the section it supports. The graph is acyclic.
- **The inventory of what the masked sumcheck publishes is complete.** The
  verifier's routine is at `hashline/src/zk.rs:552-590`; its five checks are
  exactly the draft's list.
- **The degrees-of-freedom count is an identity, and is now proved for every
  challenge**, not only recomputed (276 shape-and-regime pairs from a
  brute-force matrix agree): the mask map restricted to a zero top coefficient
  is injective, its image lies in the consistency set, and that set has the
  matching dimension. Zero slack. **The code comment at
  `zkp-core/src/sumcheck.rs:163-183` is wrong about what the extra coefficient
  is for** (the mask's total and its evaluation are determined by the mask's
  rounds); it is harmless — the kernel is one-dimensional and no coefficient
  is special — and nothing in the code changes because of it.
- **The completeness premise is settled by reading all 23 terminal
  closures**: 21 vanish through a public factor, and the two softmax slots
  through different extension rounds. Structural; no port needed.
- **Block diagonality is settled family by family by reading, and turns out
  not to be needed**: independent per-role blinding gives the product law
  directly, which also disposes of the fact that the endpoint planes are `A`'s
  own planes.
- **The shared hash domain cannot make a challenge depend on a leaf or node
  digest.** Challenges are 47-byte queries, a length nothing else in the
  system uses; the single 64-byte transcript absorb overlaps the node domain
  only at a fixed suffix, about 2^-243. **This narrows the deviation I had
  planned to put to Victor.**
- **The exact enumeration over a five-element field tests the protocol's
  structure**, and the checker's own added controls found a new instance of
  the marginal-versus-joint trap: **two terminals sharing one reserved pair —
  identical marginals, different joint law.** That is the rule "one reserved
  pair per claim site", now with a counterexample on file.

## 2. Rulings

**J-1 (B-1).** The printed sampler batches the mask functionals in the wrong
order: the declared order is interleaved per slot with the six host terms
last (`private_block/argument.rs:361-376, 924-925`). The errata pass rewrites
the step, and **the functional order is recorded as part of the public data
the sampler needs** — and as something a future layout change must not
reorder silently.

**J-2 (B-2): a step supplied by the check enters the argument with its
provenance stated.** The 173 individual terminals are published and are not
among the accepted lemma's generators, so the sampler's second step was
unjustified in both documents. The check supplies a per-group surjection with
three non-vanishing conditions (`λ ≠ 0`, `cm ≠ 0`, `cw ≠ 0`), each given by a
refusal, and verifies it by script. It goes into the memo **labelled "supplied
by the independent check; verified by its script; not independently
reviewed"**, and the lemma's own reduction is named as the thing leaned on.
It is the first item for whoever reviews this argument next.

**J-3 (B-3).** "Perfect" is never written without "in the uniform-blinding
idealisation". The real-prover statement is given once: the idealised law,
within the sampler residual decision D9 accepted (2^-77.7 for one toy proof)
and the advantage against the named generator.

**J-4 (B-4): there is no restart.** `prove` is called once, the endpoints are
consumed, the prepared plane cannot be cloned, and the endpoint roots are in
the public statement: **a refusal is terminal for that statement and those
endpoints, and "opened twice" is prevented by the type system.** The
single-attempt reading replaces the draft's conditioning-on-restart, and the
same correction goes into the generic-rank lemma (its condition O-5). A
consequence for operations, recorded for the rulings page: a service that
retries after a refusal does so with **fresh endpoints**, so the refusal event
(probability about 2^-62, challenge-only) is visible as a changed root and
carries no information about the input.

**J-5 (labels).** The check's tally stands: of 35 rows, 6 proved
unconditionally, 5 verified in the code, 6 proved on named rows, 6 mixed, 4
relying on cited facts, **2 gaps — every other shape, and the hash layer** —
and 6 illustrations. Three demotions applied.

## 3. Where the privacy path now stands

1. The all-zero input proves and verifies — **done** (measured).
2. The generic-rank lemma — **core accepted**, revised.
3. The block-scope gate — **built, partial** (10 channels open; the masking
   commitment's own opening needs a layout port).
4. The joint-law composition — **core accepted here**, errata pass owed. What
   remains under it: the hash-layer statement (H6) written as one
   random-oracle lemma with its query budget, and the sequential lift over
   Fiat–Shamir composed with it into a single argument.
5. **Victor's rulings** — now the item on the critical path. I will put them
   to him as one page: the random-oracle model for the hash in Fiat–Shamir and
   in the Merkle layer (with the narrowed note on the shared domain); timing,
   memory and power out of scope for the first MVP; rejected receipts never
   transmitted and retained captures treated as publishing.

After 3, 4 and 5 I can write, for the toy profile only, "privacy accepted in
the stated model, with these named residuals". The development rung and the
125M profile owe all of it again.

## 4. What I reviewed myself, and what was delegated

I read the check's hand-back report and its table of blocking items. I did not
re-derive the identity, re-read the 23 closures or re-run the enumeration.
Ruling J-2's labelling is mine: a step that first appears in a check has been
checked by nobody. Both documents were produced by delegated Opus agents, the
second instructed to assume the first was wrong. **Nothing here establishes a
privacy property.**
