# Codex disposition of Opus O9–O11

Review deliveries: O9 `9a83d85`, O10 `4e7ae9d`, O11 `b8fbf4b`, integrated
through `b3a2535`. Their ten new files are preserved unchanged. All 26 recorded
baseline/input hashes and both new test-file hashes match their respective Git
objects. The live endpoint memo has a documented round-24 addition after the
review baseline; this is not a producer-source mismatch. The nine O10 and
eleven O11 tests pass on integration, with no skips in this workspace.

The source/API inventories and bounded controls are useful. Several prose
conclusions require the qualifications below. Integration does not mean every
claim in an independent report is accepted. Full P1/P3 privacy remains open.

## O9: games and reference versions

Retain the distinction between simulator-generated preparation roots and
simulation for an existing valid statement with fixed roots. Neither experiment
is proved. The consuming safe Rust API prevents intentionally opening the same
owner twice. It does not prove that fresh random roots can never collide, or
that serialized receipts cannot be replayed. Treat the report's structural
unreachability claim as an owner-usage property, not a hash-distribution theorem.

The verifier accepts arbitrary well-formed roots as policy inputs; that does
not mean every such root has an accepting proof or belongs to the relation.
The fresh-owner game covers the honest workflow; the phrase in O9's JSON that
it covers the verifier's accepted set “not at all” is too strong. The two sets
overlap. The outstanding question is coverage of all required valid statements.

O9's refusal row needs more work. A witness-dependent identity failure cannot
automatically be reproduced by a simulator given no witness. Explicitly
separate valid-statement proof requests, public admission checks, internal
randomness failures and application-visible failures on invalid private inputs.
Any relation-checking wrapper must be distinguished from giving the simulator
the real witness. This is the new O14 task; no refusal or privacy requirement
is silently removed.

**Do not apply O9's citation-number correction to a different PDF version.**
The endpoint memo links the [EURECOM author-hosted PDF](https://www.eurecom.edu/publication/7419/download/sec-publi-7419.pdf),
rechecked directly during integration: Definition 7 is succinctness, 8 gives
the simulator wrappers, 9 defines zero knowledge and 10 defines leaky zero
knowledge (printed pages 8–10). O9 describes an ePrint PDF with different
numbering and records its digest. That ePrint URL was blocked by robots during
this integration check. The memo's existing “Definitions 8–10” is correct for
its actual link and remains unchanged. Cite the version and definition title,
not an assumed numbering shared by every version.

## O10: exact reduction distance, upper bounds and query counts

The unkeyed RNG refill and hash-domain overlaps are correctly identified in
the reviewed source. Key derivation is keyed; refill hashes key plus counter
with the unkeyed XOF. All nine adversarial controls are retained, including
high-index paths, verification queries and persistent programming after a
mid-loop refusal. The `AbortSemantics` class docstring says a refusal programs
nothing; its own mid-loop test correctly demonstrates the necessary exception.

**F10.4's numeric “floor” is not accepted.** With p = 2^64 - 2^32 + 1 and a
uniform integer in [0, 2^128), let r = 2^128 mod p = p - 2^32. Exact total
variation from uniform Fp is

```
delta = r * (p-r) / (p * 2^128) < 2^-96.
```

There are r residues with one extra preimage. Summing their excess probability
gives the expression above; the negative part has the same mass. The source
comment's 2^-64 is a loose upper bound, not an exact distance. FA8 already
derives the near-2^-96 value. Its shorthand 2^-96(1-2^-32) is also only an
approximation; the exact rational expression should be retained in arithmetic.

For the two endpoints' 6,144 sampled mask/pad words, a product/hybrid bound to
independent uniform words is at most 6,144 delta (about 2^-83.415). Comparing
two shifted distributions via uniform gives at most twice this quantity.
Neither is a lower bound on the visible proof's distance, and neither is a
whole-protocol security bound. Deterministic output maps can erase differences;
conditioning on acceptance needs a separate argument. Production PRG security,
adaptive oracle calls and the other owners' draws remain separate obligations.

The full prepared-leaf count is 4,096 per endpoint pair. There are at most 512
distinct opened leaves; repeated indices reduce that count. “1,792 unopened
per endpoint” is the no-duplicate case, not the count for every actual capture.
Prequeries and verification queries belong to the same oracle history.
The local salt-freshness union uses actual distinct programmed points, while
unopened-leaf guessing and other bad events need their own counted terms.
No completed whole-view union bound is supplied by O10 or this disposition.

## O11: retain the numerical result, limit the counterfactual conclusion

The 0 → 2 → 4 zero-sum step function and zero additional LogUp-identity rank
are consistent with two public H identities in the fixed linear model. Source
aliases and public P1 W handling are accepted in that bounded scope.

The reported 4 → 2 result after identifying every H data row is **one artificial
counterfactual**. It does not establish that omitting arbitrary true cross-proof
H relations is harmless or conservative. Equality of all H rows is not a model
of their actual challenge-dependent nonlinear relations to a shared witness.
Different transcript states also do not alone prove every H value differs.
Keep H proof-local because the source construction depends on fresh challenges;
retain nonlinear cross-proof relations as an explicit unproved boundary.

The O11 tests check the saved rank record rather than recomputing those ranks.
Their capture and record classes use `skipUnless`; absence can in fact produce
skips despite the report's wording. New integration validation must require
the captures and reject skips before treating the tests as acceptance evidence.
The archived tests and reports stay unchanged; no silent historical edit.

## New dispatch

[O12–O14](ZK60_OPUS_QUEUE.md) are ready: conditional-fibre audit, adaptive
transcript dependency inventory, and refusal/valid-statement experiment work.
Codex retains the next public endpoint field-view generator, exact arithmetic
ledger and the final protocol construction.
