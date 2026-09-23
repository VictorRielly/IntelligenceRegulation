# The shaped refusal census (gap GS-14, first item) — disposition

By the interactive Claude session acting as security owner (Opus 5.5,
continuing the Fable 5.1 lane), 2026-09-22, 23:22 PDT. It rules on the census
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

## 5. Built (lane stage 40, `c735d77`, 2026-09-23 00:11) and two further rulings

**Built, test-first** (lane ledger "Stage 40", census memo §9; 12 new tests;
lane filter 452/0/18; toy 2,816,472 B and every frame/digest pin unchanged;
`absorb_into` and `BlockPublic::digest` untouched):
- **CS-1:** `FeedForwardPublic::check_words` is the one check (lengths, P-2,
  table length, S38-F1(a)); `new_shaped` calls it and `check_for_shape`
  re-runs it at the builder, both prover entries, both verifier entries and
  bodies, `RunStatement::new`, the run prover and the run verifier — measured
  to fire with 0 bytes drawn, 0 squeezes, the transcript unmoved. The
  sibling the check never built (a `Wg` entry off support, P-2) was
  reproduced failing-first and is covered.
- **CS-2:** undersized `wrho_s` / `norm_wrho` overrides refused by name in
  `Shape::new` (norm with the 32768 bound).
- **CS-3:** a lookup miss is one named prover refusal after the histograms
  and before the first `A` mask draw, no absorb or draw added or moved. For
  a single block it precedes every commitment. **In a run it follows block
  k's own boundary commitment and earlier blocks' written segments** (moving
  it before the run's first commitment would need every witness up front);
  accepted under ruling M-9 — a refused run writes no `statement/`, is not
  a run and is never transmitted (D21). The soundness tests reach the
  verifier through a test-only guard `CheatingProver`; I checked that its
  state, its guard and its single use are all `#[cfg(test)]`
  (`protocol.rs:502-546`).
- **Note C-6:** `width ≠ q_heads·head_dim` never made an honest proof fail
  (dense proofs at five widths) — recorded, no refusal; **`f_e` above 31
  (the reference kernel's bound) refused by name** after honest proofs were
  shown to fail at 64, 65, 80, 200; 4 to 31 prove.

**CS-4 (finding S40-N2, same class as C-1).** The attention half of a block
statement has the same gap: a rung-G attention half inside a rung-K4 block
is admitted and the verifier refuses the honest proof. **Ruling: CS-1
extends to every part of a block or run statement** — each has one check
against a shape, called by its constructor and re-run wherever it meets the
shape it is proved at, before anything is absorbed, committed or drawn.

**CS-5 (finding S40-N1).** Above width 16,384 `Shape::new`'s own norm window
can be one bit short (the builder refuses first, so it narrows admissibility
rather than failing a proof). No target is that wide (the 8B width is
4,096). **Ruling, simplest first:** `Shape::new` refuses a width above
16,384 by name; re-deriving the norm window for wider shapes is the
alternative, worth doing only when a wider model is a target.

## 6. Built (lane stage 41, `17d10ac`, 2026-09-23 00:42) and two further rulings

**Built, test-first** (census memo §10, ledger "Stage 41"; 11 new tests; lane
filter 463/0/18; toy and every frame / receipt / schedule / slot-IR / 125M /
R-5 pin unchanged): CS-4 — `AttentionPublic::check_words`,
`IoSpec::check_for_shape` and `BlockPublic::check_for_shape` re-run at every
stage-40 site (`build_shaped`, `prove_inner_at`, `prove_core`,
`verify_bytes(_at)`, `verify_inner_at`, `verify_core`, `RunStatement::new`,
`prove_run`, `RunVerifier::start`), firing with 0 draws / 0 squeezes /
transcript unmoved. Five cross-shape parts were reproduced failing first: the
attention `Wq` (S40-N2), the attention gain, the rotary tables, **the exp
table's scale — refused before only by the builder's softmax-denominator
check, and in one direction on some inputs only, i.e. input-dependent; now
one statement refusal whatever the input** — and the endpoint policy (a
rung-G spec in a rung-K4 proof failed at `endpoint 0: Merkle path`). CS-5 —
widths 16,385 … 65,536 refused by name, 16,384 admitted.

**CS-6 (finding S41-N2 — statement binding, the most important item of the
night).** I read it in `run.rs`: the run absorbs the STATEMENT's
`block_digests[k]` (`:602`, `:752`) but proves and verifies against the
`BlockPublic` values it is HANDED (`prove_run(st, blocks, …)`,
`RunVerifier::start(st, blocks)`), and nothing compares
`blocks[k].digest()` with `st.block_digests[k]`. A statement naming block X,
proved with block Y, is accepted by a verifier handed Y: a caller who trusts
the statement's digests accepts a run about other weights. Today's callers
build the statement from the same blocks (`RunStatement::new`, `:207`), so no
recorded run is affected. **Ruling:** `prove_run`, `RunVerifier::start` and
every reader of a run statement from bytes refuse, by name and before
anything is absorbed, unless `blocks[k].digest() == st.block_digests[k]` for
every `k`. No byte moves.

**CS-7 (finding S41-N1).** `RunShape::new` accepts a registered run profile
over a block shape it was not registered for (rung-G's run profile over the
rung-K4 shape verifies). Nothing fails, but privacy statements and hash keys
(D19a) are per PROFILE, so a profile string must name exactly one shape.
**Ruling:** `RunShape::new` refuses, by name, a profile not registered for
the block shape it is given. Registered shapes unchanged.

## 7. Built (lane stage 42, `6b68561`, 2026-09-23 01:10); CS-8 and the end of this chain

**Built, test-first** (census memo §11, ledger "Stage 42"; 10 new tests; lane
filter 473/0/18; no absorb, draw or hash call added; every pin unchanged):
CS-6 — the digest comparison sits in `prove_run` (after the shape checks,
before `check_endpoints`, the OS entropy read, the transcript and any
absorb; measured 0 witnesses asked for, 0 boundary planes, 0 segments sunk)
and in `RunVerifier::start` (before the run transcript exists; refuses the
same way on 64 zero bytes, so no segment is read first), which
`verify_run` / `verify_run_from_dir` reach before reading any segment; the
statement-file reader's existing check carries CS-6's name. **S42-F1, fixed
by the same check:** stage 18's statement WRITER checked the recipe against
the blocks it was handed, not the statement's digests, and wrote a
5,476-byte statement file that does not reproduce its own digests. The
prover-side bypass for the forged-receipt test is the existing
`CheatingProver`; I read `protocol.rs:540-542` and `run.rs:634-640, 815-818`:
the accessor is `#[cfg(test)]` and the verifier never consults it. CS-7 —
the registry maps the seven registered run profiles to their whole shapes;
rung-K8's pair exists only under `#[cfg(test)]`.

**CS-8 (finding S42-N1) and a sweep.** `RunShape`'s fields can be written
anywhere in the crate, so a struct literal skips CS-7 and the run verifies.
Stages 38–42 have now found this class five times (the feed-forward half,
the attention half, the endpoint policy, the run's block digests, the run
shape): an invariant established by a constructor and assumed downstream.
**Ruling:** one sweep instead of one finding at a time — every type in
`private_block/` that a statement, shape or run is assembled from and whose
invariant a constructor establishes either has private fields (the
constructor is the only way in; preferred where a struct literal outside
the module is test-only), or is re-checked at every entry where it meets
what it is proved against (the CS-1 pattern). The sweep lists every such
type with its choice. After it, the lane's production delta since
`27398d0` gets an independent adversarial code review before a stable tip
is named for the integrator.

## 8. Stage 43 and the independent code review of stages 39–43 (2026-09-23 02:22)

**Stage 43 (`f45b842`) accepted:** the CS-8 sweep of 22 types (census memo
§12); five had an in-crate bypass that was ACCEPTED before (a `Shape` with a
written window, a `Layout` with two plane offsets swapped, a run shape by
struct literal or written field, an `IoSpec` with written scales — at the
toy's size); `RunShape` / the run statement's shape made private,
`Shape::check_constructed`, `Layout::check_is_for_shape` and the `IoSpec`
scale pin re-checked first at every entry, 0 draws when firing; filter
479/0/18. Plus my comment correction in `timing.rs` (`f486e6f`, ruling P-2 of
the D22 pre-read).

**Independent adversarial code review of `a9d6d4c..f486e6f`** (review branch
`dc12f44`, `docs/zkmatrix-poc/ZK60_LANE_S39_S43_CODE_REVIEW.md`): **no
soundness regression** (every verifier hunk adds or strictly widens a
refusal; the 41 removed lines are moves or supersets; no early `Ok`; the
verifier never reads the test switch), **no completeness regression**
(`check_constructed` exact for every registered shape and K8; the norm-window
derivation first falls short at width 16,385, which CS-5 refuses; CS-3 fired
on none of 29 honest inputs), **ordering holds** (the one exception is CS-3
inside a run, accepted under M-9), **test-only gating holds in a release
build** (no `cheating`, `with_run_shape` or `k8` symbol by `nm`), **only
CS-3 reads the witness**. D22: six pinned files move, every hunk off the toy
path or identical for every admitted toy input; the re-pin takes `shape.rs`
and `timing.rs` at the lane tip and lists CS-3 as a refusal site. Gate on the
merged branch 490/0/25.

Rulings on its findings:
- **K-1 (erratum):** CS-3's refusal text claims nothing of the block was
  drawn, absorbed or committed; inside a run the stage header and boundary
  `B_k` precede it (`run.rs:746-757`), and in a single block the header does.
  The text says exactly what precedes it. Text only.
- **K-2 (erratum):** the same message prints three counts computed from the
  hidden witness. **Dropped**: the message names the class of miss only.
  (The same D21 point was made to the integrator for R1d, R-9.)
- **K-3 (note):** the stage-43 declaration pin misses a second constructor
  that skips CS-7 and a test-only `with_run_shape` losing its `#[cfg(test)]`;
  the review's stronger guard moves into the lane.
- **K-4 → ruling CS-9.** A BLOCK profile string is bound to no geometry: the
  toy's profile string at rung-G's geometry passes every check and carries no
  pad rule and the legacy hash; the honest proof is then refused at slot 2. A
  privacy statement is per profile (D22 names a profile string), so a profile
  string must name exactly one geometry. **Ruling:** a block-profile registry,
  as CS-7 is for runs — `Shape::new` (or the one place a profile string meets
  a geometry) refuses a registered profile string with any geometry other
  than its own, and an unregistered string outside `#[cfg(test)]`. The toy's
  shape and bytes are unchanged.
