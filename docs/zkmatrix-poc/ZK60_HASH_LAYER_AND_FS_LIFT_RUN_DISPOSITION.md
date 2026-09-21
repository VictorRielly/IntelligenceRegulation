# The hash layer and the Fiat–Shamir lift for a run — disposition

By the interactive Claude Fable 5.1 session (the security owner), 2026-09-21,
01:12. It rules on `ZK60_HASH_LAYER_AND_FS_LIFT_RUN.md` (a delegated agent's
draft of tonight) after `ZK60_HASH_LAYER_AND_FS_LIFT_RUN_CHECK.md` (an
independent agent told to assume the draft wrong). Both read the lane
`zk60-private-block-125m` at `8c5922b`.

**Not a privacy acceptance of anything.** Register entry D22 (the toy block)
is untouched: it rests on the untagged profile and on D19 as Victor accepted
it, and nothing here changes either.

## 1. What survived the attack

- **The draft's conditional statement holds, with changes.** Given the run's
  fixed-challenge theorem (itself conditional), in the model below and under
  the named generator assumption, an *accepted* run directory's view is within
  the blinding sampler's bias of one that does not depend on the hidden data:
  2^-75.0 and 2^-74.9 for three-block runs at the two development shapes,
  **2^-69.3 for twelve blocks at the 125M shape**, linear in the number of
  runs (about 2^-49.4 at a million). **Every hash-layer term is at least 37
  bits below that.** The checker reproduced every count by a different route.
- **The segment position tags are clean.** A tag is two squeezes off a
  discarded clone that copies only the state, the counter and the public key;
  nothing of the prover's enters; the verifier re-derives it. A tag query
  never coincides with a live challenge query.
- **The generator question is settled, and two of my own documents were wrong
  about it** (ruling H-3).

## 2. Rulings

**H-1 (the check's B-1) — "the run's hidden input is fixed before the first
message" is a fact of the code, not an operating condition.** The draft, and
my own ruling R-2 of last night, treated it as something a caller must
promise, because a run asks for block k's witness inside stage k. The checker
read what the draft had itself transcribed: **the run header absorbs the
expected-IO bytes, which carry both external endpoint commitment roots, before
any challenge exists**, and the endpoint check refuses unless the prover's own
owners produce exactly those roots. So the input plane — and the *final
output* plane — are committed before the header. Two consequences:
1. For the lift, the hypothesis holds computationally, by the binding of the
   endpoint commitments and the proved chain. **A run is longer than a block,
   not harder.**
2. **The prover has already run the whole forward pass before the header**
   (there is no other way to seal the output). My ruling R-1.3 priced an
   admissibility pre-pass at "up to 15% of a run"; that costing is withdrawn.
   **New rule for any production caller of a run: the pass that seals the
   endpoints is the witness builder's own, with its refusals — so an
   inadmissible chain is refused before the header and no partial directory
   can arise from that cause.** Rule M-9 stays, as the second line.
What remains is an interface item: the witness-source trait still *permits* an
adaptive source. It is tightened when the production caller is written.

**H-2 (B-2) — rule M-9 has no production code behind it yet.** The statement
writer that publishes only after the whole run verifies is test-only, and
`prove_run` has **no production caller at all** at this commit. The draft's
"the code side of M-9 is built and pinned" is corrected. The run wrapper is
the integrator's; until it exists, M-9 is a rule, a tested writer and nothing
more.

**H-3 (B-3) — the generator.** `rng.rs:47` uses keyed BLAKE3 for the **key
derivation only**. The stream itself (`rng.rs:53-61`) is **plain unkeyed
BLAKE3 over `key ‖ counter`, 40 bytes, read as an extendable output**. The tag
scoping memo was right about a different line; my tag disposition §2a and
register entry D19a ("the generator's keyed function under its secret key"),
and the doc comment at `zkp-core/src/hashtag.rs:22-33`, are wrong and are
corrected (the source comment at integration — it is a comment in the
integrator's crate). Consequences: a tagged run uses **five** BLAKE3
functions, not six; the 40-byte input class is still load-bearing in the
unkeyed function; the toy statement's generator assumption, which is about the
output stream, is unaffected.

**H-4 (B-4) — the model behind the tag goes to the project owner.** Register
entry D19a says the random oracle of D19 is read as "a family of independent
random functions indexed by BLAKE3's mode and key", and my disposition called
that "BLAKE3's own design claim for its modes". **The form is what the
argument uses; the justification was wrong.** BLAKE3's design claim separates
its three *modes*. The leaf and node functions are the *same* mode under
*different, published* keys; nothing in that claim covers it, and keyed BLAKE3
as a random-function family is a statement about *secret* keys. The honest
model is: **BLAKE3's compression function is ideal, also when the adversary
knows and chooses the chaining value it starts from.** That is the assumption
under which BLAKE3 is shown to behave as a random function in the first place,
but it is stronger than D19 *as it was put to Victor*, and it was not put to
him. Nothing accepted rests on it — no tagged profile has a privacy statement
— and nothing measurable changes: the tag removes two terms of about 2^-241
and 2^-485 and adds the probability that two derived keys collide, about
2^-251 for the keys that exist (**zero today, by a test that pins them
distinct; that test is extended to every tagged profile**). **Proposed D19b,
recommendation: accept; on Victor's page, not urgent.** The alternative, a
one-byte prefix per domain under the single unkeyed function, stays inside D19
exactly, costs about half a percent of hashing, and would mean redoing the tag
stage; it is recorded, not recommended.

**H-5 (B-5) — the trailer of a segment equals the header tag of the next**
(measured on all ten bundles). Not a leak, and not a splicing weakness: the
run binding and each segment's own position compare stop a foreign segment.
The 32·(L−1) bytes buy nothing; the wire format is settled and stays. **What
is pinned is the property** — no transcript operation between a segment's end
tag and the next segment's start tag — not the coincidence.

**H-6 (B-8, the draft's F-3) — figures after the attention repair.** Per block
687,028 / 750,540 / **9,029,804** draws (generalised rung / four-group rung /
125M); per run 2,093,340 / 2,283,876 / **109,728,784**; the residual **2^-69.3
unmoved**. Last night's 109,728,040 was the pre-repair count. A third pinned
receipt total moved with the repair besides the two I listed: the frozen-seam
rung, 4,218,264 → 4,218,600.

**H-7 (B-6, B-7, B-9 … B-12) — errata.** "Impossible: 0" for a tag/challenge
coincidence is overstated — the non-local case is a state collision and folds
into the collision row; the last stage has no next start tag; a
constructor-versus-absorb row is added at `(A + q)·2^-256 = 2^-128`; a million
is not 2^20 (2^-49.36, not 2^-49.29); the draft's "validated by nothing" about
its absorb count is retracted — the checker reproduced 1,129 / 1,138 / 5,932;
the accelerator path that builds unkeyed leaves is feature-gated and declined
by tagged commitments (ruling T-8 verified); there are two run profiles, not
three shapes.

**H-8 — the draft's finding F-2 (a 46-byte run constructor beside the 47-byte
squeeze class).** Inside the transcript's keyed function a constructor input
can equal a squeeze input only if its bytes spell the word `squeeze` at a
fixed offset after a 32-byte hash state; no profile string does, and none of
the seven constructor lengths is 47. **Ruling: a one-line test that no
registered profile's constructor input has the squeeze length**, so the margin
is watched rather than argued.

## 3. The gap that remains: O-4, the sequential composition

Unchanged in kind from the toy: the draft's hybrid composes the fixed-challenge
theorem with the hash-layer lemma inside the model, which is the toy's
standing; what is **not** done, for the toy or for a run, is the sequential
composition over arbitrary challenge functions ("Route B"). The lemma that
closes it is known in shape — causality; the witness fixed before the first
message (now a code fact, H-1); the challenge family independent of what the
prover's messages depend on; for every non-refused challenge vector the joint
law of all messages witness-free — and **exists only for field messages, on an
older branch. Extending it to (field, hash) message pairs is the next paper
task**, and it closes the toy's O-4 at the same time.

## 4. What I checked myself, and what was delegated

Myself: the run header's absorbs and `ExpectedIo::to_bytes` (read last night;
they are what H-1 rests on). Delegated: every count, the generator reading,
the tag's query analysis, the model analysis of H-4 — which I have reasoned
through and agree with, and which is Victor's to accept or not.
