# Opus 5 delivery, 2026-09-08 — O1–O4 and the re-scoped core item

Victor's Fable usage ran out mid-round, so Codex reassigned the pending reviews
to Opus 5 in [the Opus queue](ZK60_OPUS_QUEUE.md). This is the delivery record
for that dispatch: O1, O2, O3, O4 and the re-scoped CL20 item. Codex owns
integration and the final cryptographic judgement; nothing here is merged by
this side.

Fable's completed analyses (FA1–FA9, CL21, the PCS and typed-core extraction)
keep their Fable attribution. Two tasks were interrupted by the usage limit:
the FA6 follow-up and the full CL20 step-2c extraction. Both are resolved
below, the second by parking rather than finishing, because the queue re-scoped
it.

## Lanes and tips

| Lane | Commits this round |
|---|---|
| `zk60-fable-review` (`wt-zk60-fa`) | O3 `6ce0f6a`, the gates sentinel `dc1e9bb` (superseded, see below), O4 `e42718e`, O1+O2 `369c916`, merge of Codex `29d3436` = `ec554df`, rebind `fc92078`, this record |
| `zk60-cl20-core` (`wt-zk60-cl20`) | park `95d6b62`, helper move `2dec4a9` |
| `zk60-fable-fa9` (`wt-zk60-fa9`) | FA9's round-15 review `3810406` (delivered before the limit) |

Implementation under review: Codex's `b41d036`, the first executable FFN
privacy repair. The review lane is merged through Codex's `29d3436`.

## O1 — the four captures are what they claim to be

Two private-input proofs and two private-weight proofs. Every hash, byte
length, proof digest, privacy mode and layout digest matches the published
record, and each file is named by its own proof digest. The layout description
was reproduced independently in Python and came out **byte-identical**, so the
digest agreement is a real reproduction rather than a hash comparison. Row
counts, one role per row, exactly two proximity rows per role, the group
member counts, the vector widths and a symbolic coefficient tag on every claim
part all match the recomputed layout. 167 checks, none failed.

This is an integrity check, not a privacy verdict.

## O2 — the repair works, in the model that caught the original defect

The adapter is **separate** from Fable's archived legacy parser, which keeps
its meaning and its digests, and it recomputes the expected layout from the
source rules instead of trusting what the capture declares. Its refusals were
written and run before any analysis.

Analysing all group message coordinates and terminal values together, with row
aliases, proximity coordinates and the helper commitment's zero-sum constraint:

| Commitment | Legacy (Fable, FA7) | Repaired |
|---|---:|---:|
| Inputs and activations (A) | 516 base dimensions | **0** |
| Private weights (W, P3) | 514 | **0** |
| Helpers (H) | 2 | **2**, and 0 without the zero-sum row |

The helper residual is exactly the public LogUp identity, identified as such.
Nothing is recovered from any plane. The legacy attack is preserved as a
positive control in the same result file and still recovers the whole tiny
weight plane, and the adapter refuses all twelve legacy captures, including a
forged one carrying a genuine layout description.

No new mathematical assumption was needed, so this item leaves nothing
unresolved. What the model still excludes, and therefore what this does **not**
cover, is pad and column leakage, the masking-channel messages and repeated
proofs. It is a linear-model result on four proof-of-concept captures: not
whole-protocol zero knowledge, not the registered or seamed profile, not
function two, not stable weights.

## O3 — the implemented mask schedule, audited

Seven site classes traced through allocation, randomness fill, prover use,
verifier use and regression, with file and line citations. The three properties
the queue asked about hold: the repaired entry points take no seed, generator
or reusable commitment and draw fresh operating-system randomness before any
proof work; private state does not escape; degenerate draws abort with no
resampling anywhere. An independent recomputation of the row counts matches the
implementation, and the difference from the legacy layout is exactly the pair
repair.

Two things are not clean. One table check aborts **late**, after two values it
depends on are already in the transcript and the proof object, which breaks the
"abort before any dependent field" rule the other sites keep. And coverage is
uneven: the masking challenges are well covered, while the helper and proximity
pairs have no pair-level assertion or negative control at all. Twelve gaps and
ten differences from the reviewed design are listed for Codex.

This is the bounded implementation portion of FA8. A passing test and a correct
mask-site count are not a privacy verdict.

## O4 — the attention inventory

Every attention sumcheck slot, terminal, mask site, proximity mask and seam
endpoint, from source, with citations and an implemented-or-design marker.
Attention is a public argument today and carries no masks at all, so the
inventory is design input for a future private profile.

Three obstacles matter for whoever builds that profile:

1. **Six sumchecks have a private claimed sum** reconstructed from earlier
   claim values. Once those inputs are masked the reconstruction no longer
   closes on honest data. The feed-forward proof sends its claimed sum as its
   own field; attention has six such sums and no field to send them in.
2. **Two matmuls multiply two private factors** with no vanishing public
   factor, and at this profile the suggested substitute degenerates to the
   constant one. They need the feed-forward proof's two-extension treatment
   already in the public mode.
3. **Nineteen helper-sum claims** against the feed-forward proof's one, over
   five domains in a single opening group, have no row in the existing model
   and no rule in the repair design.

Good news on the mechanics: the derived slot table passes the masking-channel
criterion in every slot, and the largest slot fits the mask commitment's
layout with room to spare, so nothing there has to change. Both seam rows are
aliased, and nothing marks an attention seam consumed exactly once. Sixteen
numbered requirements and nine open items are handed to Codex.

## The re-scoped core item

The interrupted full extraction was assessed rather than continued. It was
larger than expected and **did not compile**: the module list was never
updated, so six new modules were not part of the crate, while a consumer had
already been switched to import symbols that live only in them. It is parked as
a patch that applies cleanly to its base, with recovery verified and its
reusable parts identified as design proposals carrying no parity evidence.

In its place, one genuinely pure helper was moved with the byte check the queue
asked for, chosen because the ledger names it as a blocker and it is the only
pure function in that list. Both proof paths use it, so two frozen artifacts
act as live gates and two act as controls, and the old side was measured on a
restored clean tree rather than inherited. Core tests pass in release and
debug, the hashline suite passes in both feature configurations, the
graphics-feature compile check is clean, and all four frozen proofs are exact
with the verifier accepting each.

## Two things owed to Codex

- **Gate counts.** The core lane sits below `b41d036`, so its baseline is the
  earlier suite. On top of `b41d036`, a new suite needs the core test count at
  36 and the storage-enabled count at 220.
- **A record field.** The published round-16 record's source commit is the
  validation head, not the captures' implementation pin, which is carried
  separately. A consumer reading the first as the pin would be wrong. The
  adapter binds to the implementation pin and reports the head beside it.

A third item resolved itself: the round-16 validation run failed one test of
660, the gates sentinel asserting that an unused suite version is rejected,
because that round created the version the sentinel named. This lane fixed it
by bumping the sentinel; Codex fixed it independently and better, deriving the
next version from the table, so Codex's version was taken whole on merge and
this lane's was dropped.

## Rounds 17 and 18 — O5, O6 and O7

Codex integrated O1–O4 through `2fb7e0a`, rerunning all 69 Opus tests and the
57 legacy ones with no skips, and accepted them within their stated scope. It
then gave the repaired proof a byte format (round 17) and bound its input and
output to external endpoints (round 18), which produced three more items.

**O5, the wire format** (`e793fef`). Three independent models of the encoded
length — the closed form, the payload writer field by field, and the decoder's
cursor, each with the row counts re-derived rather than copied — agree on all
781,250 shape and mode combinations, and both stated maximum frame sizes
reproduce to the byte. Mode and expected root are caller-supplied, parse and
verify are properly separated, and the verify command has no path into proving.
Eight findings, the most notable being that a parsed proof exposes accessors
before anything is verified and never compares the file's weight root to the
caller's; it fails closed, so it is an interface hazard rather than a hole.
Sixteen missing adversarial cases named as concrete inputs.

**O6, the seam inventory** (`d130de6`). Written before the binding existed, it
predicted from source what the binding would require. Codex verified all 32
recorded source hashes and worked through its fifteen unresolved items. Its
central point changed the implementation: the masking slots for the two
equality proofs had to be reserved in **one** commitment before the challenges,
and the draft's separate second commitment created a composition nobody had
analysed. Codex agreed in as many words — the per-commitment analysis "does not
by itself establish the privacy of the combined adaptive transcript" — and
replaced the draft unpublished.

**O7, the replacement reviewed** (`4695503`). All six checklist items pass on
profile `/2`: the expected policy is absorbed before every commitment and
challenge; the four new rows alias nothing and bind the real committed slices,
confirmed by recomputing the allocation as a disjoint complete trace; both
equality slots sit in the eight-slot commitment before the challenges, with
every opening deferred until after both equalities; the wrong-plane tests fail
for the right reason; and the table guard now precedes every value that depends
on it. An independent frame model reproduces both profiles' sizes and shows the
149,536-byte difference between them is exactly the removed second commitment
minus the four extra rows — the two differ by the schedule change and nothing
else. All thirteen of the inventory's predictions now hold. Three of the five
wire findings are closed as proposed, using the concrete input from the first
as its regression test.

What remains after these three: no capture or joint analysis exists for the new
profile, so the linear result does not cover its seven groups, its wider mask
commitment or the endpoints. That is the blocker Codex carries forward, along
with five of the audit's twelve gaps and four of the inventory's fifteen items.

## What none of this establishes

No repaired registered profile, no seams, no attention privacy, no function
two, no stable private weights, no private block or two-block composition, no
authenticated approval or rollback resistance, no throughput or full-model
claim. The repaired proof is an experimental profile at one tiny shape.
