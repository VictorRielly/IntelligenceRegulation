# The shaped refusal census (gap GS-14, first item) — disposition

By the interactive Claude session acting as security owner (Opus 5.5,
continuing the Fable 5.1 lane), 2026-09-22, 23:55 PDT. It rules on the census
of lane stages 38–39 (branch `zk60-private-block-125m`, tip `27398d0`: memo
`docs/zkmatrix-poc/ZK60_SHAPED_REFUSAL_CENSUS.md`, tests
`hashline/src/private_block/census_shaped_tests.rs`) after its independent
adversarial check (branch `zk60-private-block-125m-review`, `cda7d05`:
`docs/zkmatrix-poc/ZK60_SHAPED_REFUSAL_CENSUS_CHECK.md`, attack tests
`census_check_tests.rs`, exact-arithmetic bounds `results/zk60_census_check/`).
Context: ruling NL-8 of `ZK60_NONLINEAR_CHANNEL_SHAPED_DISPOSITION.md` named a
shaped builder-versus-kernel census as GS-14's first concrete item.

**Not a privacy acceptance of anything.** D22 (the toy) is untouched: the
toy's `Dom::F` does not pad and it uses no window override.

## 1. What survived the attack

- **The site list is complete for the shapes as built:** the checker's own
  enumeration from the code gives 34 of 34 data-dependent sites, 25 distinct
  builder code sites mapped exactly onto the census's builder rows plus the
  six prover-side rows. No data-dependent refusal site is missing.
- **Every reachable site is refused by the witness builder first, with the
  same or a tighter bound** — confirmed independently. `AO` is reachable
  exactly above width 258 (±127·width), covered at `witness.rs:594`.
- **Every bound agrees in exact arithmetic** (norm output exactly [−64, 64];
  125M norm margin 0.2075 bits; largest multiplicity 61,440 at the toy to
  98,598,912 at 125M; largest kernel intermediate 1.72e10 to 8.25e11).
- **Challenge-only refusals** c_s 23, e 25, ν 12, ζ 5 per 125M block —
  confirmed; add the opening-group count check (`protocol.rs:323`, C-4).
- **The S38-F1(a) condition `pads(Dom::F)` is exact** on 392 admitted shapes.

## 2. What the attack found, and rulings

**C-1 (latent; ruling CS-1).** The S38-F1(a) refusal and ruling P-2's
padded-weight check run against the shape PASSED TO the constructor; the
statement does not remember it (`private_block.rs:550-556`) and nothing
downstream checks again. A feed-forward half built at rung-P2 with
`act[128] = 1` placed in a rung-K4 block passes constructor, builder, kernel
and `RunStatement::new`, and the verifier refuses the honest proof. No
production path reaches it today (all shaped entry points are `pub(crate)`),
but a named check that can be sidestepped is not a check. **Ruling:** one
function checks a feed-forward statement against a shape (S38-F1(a) and
P-2), called by the constructor AND at every point where a statement meets
the shape it is proved at — the block builder, the prover's and verifier's
entry, and `RunStatement::new` — refusing by name before anything is
absorbed, committed or drawn. No absorbed byte changes.

**C-2 (latent, input-dependent; ruling CS-2).** `Shape::new` accepts a
`wrho_s` override smaller than the derived window `clog2(tokens) + f_e`
(`shape.rs:230`), and likewise `norm_wrho` below its derivation; the builder
and kernel check only `sigma_s`, so on some inputs lookup words fall outside
the byte table and the verifier refuses — **whether the honest proof fails
depends on the hidden input**, the class of failure that leaks. No registered
shape uses an override. **Ruling:** `Shape::new` refuses, by name, any
override smaller than the window it would derive (for `norm_wrho` with the
input bound 32768, as the check proposes); overrides at or above the
derivation are kept. Every registered shape's bytes are unchanged.

**Defence in depth (ruling CS-3).** The prover's three silent paths that file
a lookup miss into bucket 0 (the mechanism by which S38-F1, C-1 and C-2 each
became a verifier refusal) become ONE named prover refusal before the first
commitment, computed from values the prover already holds, with no absorb or
draw added or moved. For every witness and statement the builder admits this
refusal is unreachable (§1); its role is to turn any future admissibility gap
into a refusal at the prover, before any byte leaves it (D21), instead of a
receipt that fails verification. If it cannot be placed before the first
commitment without moving an absorbed or drawn byte, it is NOT built and the
stage reports why.

**C-3 (erratum).** Seven census rows cannot fail (their reach is typed in or
defined equal to their range); the checker verified each premise by hand. The
census memo labels them as premises checked by reading, not tests.

**C-4, C-5, C-6 (notes).** The opening-group count check joins the
challenge-only list; the zero LogUp denominator refuses for the same
challenges whatever the input (only WHEN it refuses depends on data — the
D22 §9 item 10 sentence, same shape); the multiplicity comment at
`layout.rs:671` is corrected to 98,598,912. `Shape::new` checks neither
`width = q_heads · head_dim` nor an upper bound on `f_e`: the lane stage
tests whether either admits a shape whose honest proofs fail, and refuses by
name if so; otherwise it records the fact.

## 3. What GS-14 is now

**Narrowed, not closed.** For the ten shapes as built with their own
statements, every data-dependent refusal site is covered by the witness
builder (census + check). Open: CS-1 and CS-2 until built (lane stage 40);
the 23 slot relations for every admissible witness are shown by the 37 edge
proofs and the dense generic runs, not re-derived symbolically; the soundness
premise (no field wrap, `layout.rs:639-648`) is out of this census's scope.

## 4. What I checked myself

`shape.rs:215-235` (the two window defaults and the unchecked overrides) and
`private_block.rs:545-587` (the statement struct without its shape; the
S38-F1(a) refusal inside `new_shaped` only) — both findings are what the code
says. Delegated and not re-derived: the site enumeration, the bounds, the two
reproducers (run by the checker; exit 101 as expected).
