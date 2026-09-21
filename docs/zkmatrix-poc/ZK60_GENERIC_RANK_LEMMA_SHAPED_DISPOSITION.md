# The generic-rank lemma at the shaped layouts — disposition

By the interactive Claude Fable 5.1 session (the security owner), 2026-09-20,
23:27. It rules on `ZK60_GENERIC_RANK_LEMMA_SHAPED.md` (a delegated agent's
draft of this evening) after `ZK60_GENERIC_RANK_LEMMA_SHAPED_CHECK.md` (an
independent agent told to assume the draft wrong, with its own field library
and four scripts). Both read the lane `zk60-private-block-125m` at `e6b612f`.

**Not a privacy acceptance of anything.** Register entry D22 (the toy block)
is untouched. This page narrows one gap (G-R1) of the run's composition
argument; it does not close the path.

## 1. What survived the attack

- **The lemma holds, with changes**, in the checker's first line: at the
  generalised rung and at the 125M shape, per commitment and per stage of a
  run, on every run the prover does not discard, the blinding generators have
  full row rank on the non-data rows, so the linear view discloses nothing
  about the activations, the endpoints or the boundaries, and exactly the
  public lookup identity about the helper commitment. **Every numerical
  verdict of the draft was reproduced independently at both shaped layouts**,
  with the checker's own field arithmetic.
- **The repaired attention slots are harmless to this argument, and no
  structural key collision exists** at any shape in scope. Positions of the
  two claims' column keys that would have to coincide by accident: 6 of 10 and
  10 of 10 at the generalised rung, 8 of 14 and 14 of 14 at the 125M shape,
  7 of 10 and 10 of 10 at the new four-group rung — probabilities of 2^-768
  and below; zero numeric collisions over eight seeds of generic field
  elements at all four shapes. The pre-repair schedule also scores 0: **the
  defect S19-F1 was privacy-neutral in the linear view.**
- **The refusal refinement is right**, recounted from the code: the inverted
  lookup denominators fall in three families of at most 256 arguments (byte
  values, exponent-table rows, activation-table rows; the three table helpers
  are subsets of them), so at most **768 distinct arguments per block at every
  shape**.
- **Why the helper commitment discloses 2, now said and computed**: the
  zero-sum construction makes the all-ones functional on a zero-sum row
  publicly zero, so the sum claim gets no blinding; the disclosed
  2-dimensional space was computed **span-equal to the public identity** at
  the shaped layouts.
- **At a boundary, "bad set inside refusal set" is an identity, not a
  probability**: its whole 6 × 6 determinant equals
  `Norm(λ₁·cm₁) · Norm(λ₂·cm₂) · wedge(prox)` exactly. The draft's weak
  backstop (2^-52.2 for a twelve-block run) is therefore not needed there.

## 2. Rulings

**S-1 (the check's B-2) — "Fact 1" is restated, and one shape condition
becomes an invariant.** The draft said a claim's evaluation point never
reaches a commitment's non-data rows. **False on the helper commitment**: the
claim of slot `SC_ZS` on `H_U` and the pairless sum claim both put data parts
on the two zero-sum rows, which the draft itself counts as non-data, and the
claim audit does not forbid it. It is harmless today for one reason only: the
lookup-table domain sits at **exactly the row width** (the P-3 lift makes
`log(Dom::Tab) == log_cols`), so the row part of that eq-tensor is trivial.
**Ruling: `log(Dom::Tab) == log_cols` joins the invariants that must not be
weakened (ruling G-3's list), and becomes a named, tested shape refusal on the
lane.** Fact 1 is restated with that hypothesis; without it the draft's
headline about the bilinear slots is not a theorem.

**S-2 (B-1) — the draft's finding N-2 and gap GS-10 are struck.** The
opening-group-count check is **not** a privacy check. `check_opening` runs the
claim audit first, and on a two-site boundary the audit forces exactly two
claims, so the many-group case N-2 priced is unreachable; the only deviation
the count check can catch is a key merge, which the draft's own §3.1 calls a
liveness event, and which computes to disclosure 0. **Nobody builds a test for
N-2.** What a boundary's hiding rests on: the audit's pair exclusivity, the two
zero-mask refusals and the proximity-determinant refusal (finding N-1, which
stands: with 6 generators on 6 non-data rows a boundary has zero slack, and
the external endpoint's spare row is what gives it slack 1).

**S-3 (B-3) — a latent liveness trap gets a named refusal.** If a shape had
`head_dim ≥ row width`, `SC_SCORE`'s two private factors would be claimed at
the same shared tail and their column keys would collide on **every** run —
every proof refused. The shape validation guards only the opposite direction.
No shape in scope is near it (head dimension 8 to 64 against row widths 2^10
to 2^14). **Ruling: a named `Shape::new` refusal, with a test.**

**S-4 (B-5, B-6) — the input-dependent refusal inside the argument is
2^-118.4 per block and 2^-114.8 for a twelve-block 125M run**
(`768 / p²` and `12 · 768 / p²`) [COUNTED twice, independently]. It supersedes
the raw figures of ruling R-6 (2^-101.4 and 2^-97.8), which stay correct as
upper bounds. The conditioning is **"any witness the constructors admit"**, not
"an honest witness": the byte ranges are refusals of the witness builder. The
worry that this term sat next to a run's soundness level is withdrawn. The
toy's statement keeps its conservative 2^-112.

**S-5 (errata, B-4, B-7, B-8, B-9, B-10, B-12).** The shared-coordinate
inventory gains `SC_GMM` / `SC_UMM` (same plane, shared fixed row point; no
collision). Gap GS-15 is closed: the activation commitment's real opening
groups are derivable — largest group 35, 17 singletons. Two measured figures
re-cited to the gate section they come from. The "why 2" of the helper
commitment and the boundary's determinant identity are written in. The layout
model's frozen-seam rung still carries a stale endpoint (14 rows against the
code's 21) behind a named correction term: fixed in the model, on the lane.
Definitional note kept for anyone re-running: disclosure is
`rank(all) − rank(non-data)`, not `generators − rank(non-data)`; they differ
exactly on refused draws.

**S-6 (added 2026-09-21 14:19; source: lane stages 31 and 32).**
`Shape::a_groups` — the function that fixes `A`'s opening-group count, which
this lemma's counts rest on — has an arm `natural_log(Dom::T) >= log_cols`
(token count at or above the row width) that NO registered shape reaches, the
125M shape included. An arm no shape reaches is code nobody has tested, in the
one place the group structure comes from. **Ruling: such a shape is refused at
shape validation by name, in the form of S-1 and S-3, and the Python layout
model refuses the same family by the same name; the arm stays only as an
unreachable defensive return.** Lifting the refusal later requires a shape of
that family in the ordinary test filter and the lemma's counts redone for it.
No registered shape is affected and no figure on this page moves. Being
implemented as lane stage 33, failing test first.
**IMPLEMENTED 2026-09-21 15:25 (lane `226f3b2`, pushed; filter 394 passed /
0 failed; I checked the diff's scope).** The failing-first log shows the gap
was real: the toy's axes at 256 tokens (and at 129) passed validation and read
`a_groups() = 28` out of the unreached arm. The refusal is named
`private block shape: ruling S-6 …`; the Python layout model refuses the same
family with the same sentence; the arm is kept as a panic-free defensive
return because the two arms provably agree on the refused family (`t_pad` a
power of two at or above the row width makes every offset zero), so it is a
shortcut and not a second behaviour. One older test's probe geometry sat
inside the refused family and was moved (its measured mask lengths are
unchanged).

## 3. Where gap G-R1 stands

| Shape | State after this page |
|---|---|
| Generalised rung (one group bit) | Lemma accepted with S-1's hypothesis. Left: a Rust test pinning the refusal replay order against the opening's challenge order (GS-2); the reduction not re-derived at pad count ≠ column count, though brute force there scores 0 (GS-5); the computed gate sees two challenge vectors per shape. |
| Four-group rung (two group bits) | Covered by the checker's collision count and generic computation; real bytes exist since 23:03 (`run-i-dense-k4`) and are with the gate now. |
| 125M | The argument and every count carry over; **nothing has been measured there** (GS-1), and nothing can be with the present tools — a 125M capture is out of the Python gate's reach. A privacy statement at this shape would rest on the argument, the counts, and measurements at the two development shapes that share its head geometry. That is a limit to state, not to hide. |

Still open on the whole path: the joint law across commitments and its
machine-asserted draw accounting (G-R4), the slot closures as a reading
(G-R2), the sequential lift for a run (G-R5), the non-linear channel (GS-13).

## 4. What I checked myself, and what was delegated

Myself, tonight: the repaired slots' coordinate lists in `argument.rs`; the
run header's absorbs; the hunk positions of the integrator's `zk.rs` change.
Delegated and not re-derived by me: the lemma's proof, the rank computations
(two independent implementations agree), the recounts, the determinant
identity. The draft and the check disagree on no number; they disagree on one
finding (N-2), and the check is right.
