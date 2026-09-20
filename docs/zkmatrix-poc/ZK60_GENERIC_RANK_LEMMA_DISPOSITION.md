# Disposition of the generic-rank lemma — security owner, 2026-09-20

Written by the interactive Claude Fable 5.1 session (the security owner) at
00:46 on 2026-09-20. It rules on two delegated documents:

| Short name | Document | What it is |
|---|---|---|
| G | `ZK60_GENERIC_RANK_LEMMA.md` | a draft lemma for the step the project calls U-3a: turning "nothing disclosed at four captured challenge vectors" into a statement about all challenges, for the toy private block and the toy private attention |
| G-check | `ZK60_GENERIC_RANK_LEMMA_CHECK.md` | an independent adversarial check (`results/zk60_generic_rank_lemma_check/`): 4 blocking items (B-1 … B-4), 12 corrections, 6 omitted conditions |

| Verdict | **The lemma's core is accepted for the two toy profiles: on the linear channels, the set of challenges at which anything would be disclosed lies inside the set the prover already refuses on. The draft is NOT accepted as written** and goes back for an errata pass. **This is not a privacy acceptance**: it covers the linear channels at two fixed layouts and nothing else, and it found a defect in the project's own gate (§2, G-1). |
|---|---|

## 1. What survived the attack

- **The factorisation, rebuilt from the real captured claim schedules** (the
  draft's own script used invented groupings): over 48 fresh uniform
  challenge vectors and 78 adversarial ones, **zero mismatches** between the
  determinant of the non-data block and `∏ Norm(λ·cm) · wedge(prox)`, no zero
  determinants, ranks 72 / 20 / 4 / 4 and 62 / 18 / 4 / 4, disclosed dimension
  0. The checker's grouping matches the Rust `group_zclaims` recorded in every
  capture, element by element.
- **No hidden bad set.** `U = (0, 1)` with `u² = 7`, fixed and public; the 2×2
  real block's determinant is `Norm(λ·cm)`; nothing vanishes unless `λ = 0` or
  `cm = 0`, and both are refused.
- **A claim's weights never reach a non-data row outside its pair** — exact for
  every part of every claim — but *because of* four assertions in the
  commitment code (`zkp-core/src/pcs.rs:759, 768, 775, 786`) the draft never
  cited. A straddle would panic, not leak.
- **The refusal replay uses the same challenges as the opening**, element by
  element, and the verifier re-runs it (`protocol.rs:458, 464, 471`). No Rust
  test pins this.
- **The pad budget is exactly sufficient, jointly, per commitment.** Opened
  columns are sampled *with* replacement (241–246 distinct at the captures);
  rank equals the number of distinct columns; the pad halves of the group and
  proximity vectors are determined by those columns, so nothing is counted
  twice. 257 distinct columns would break it and cannot occur at Q = 256.
  Zero slack: **the pad count and Q must move together, always.**
- **`H`'s two disclosed functionals are public**: the real and imaginary parts
  of the lookup identity whose declared value is zero.
- **The field correction is right.** The good event is a rank over the base
  field, not the extension (the check exhibits a two-row counterexample), so
  the fallback bound is about 2^-56, not the 2^-121 of the earlier sketch.
  Every challenge is an extension-field element; decision D15's soundness
  figures are untouched. The refusal probability is 2^-62.0 for both profiles.

## 2. Rulings

**G-1 (the project's gate has a stage that cannot fail — mine to fix, today).**
`scripts/zk60_native_joint_view.py` hard-codes `joint == sum` as true (line
245) and its stage-4 verdict with it (line 248). **Every statement that quoted
"joint disclosed dimension 4, equal to the sum of parts" as computed was
quoting four marginals and an assumption.** I wrote that tool's acceptance and
repeated the figure to Codex and in the privacy case; both are corrected with
this disposition. The tool gets a genuine joint computation across the
commitments of one receipt (shared coordinates identified), a negative control
that makes it fail (a blinding source shared across two commitments — the case
the form-E check measured at joint 8 with parts 0), and the certifying minor
printed per role. Until that lands, **the honest reading of stage 4 is "not
computed"**. The lemma's per-commitment result does not depend on it; the
joint statement does.

**G-2 (B-1, scope).** The lemma holds for the two toy layouts. At the
development rung and the 125M shape its `H` step is about a claim that cannot
even be formed until the lookup-summation repair (ruling P-3 of the layout
disposition); after it, the certificate is owed again from the start — 36
groups on `A`, 29-row endpoints with three data parts, a new refusal for the
pad-zero challenge. "Re-check" understates it; the errata pass says "re-prove".

**G-3 (B-2, B-3).** The four assertions in the commitment code and the
`d + 1` values per round (`zkp-core/src/sumcheck.rs:148-150`; with only `d`
the kernel is two-dimensional at slots 8 and 17) are load-bearing facts about
code the integrator owns. They are cited in the lemma and recorded here as
**invariants that must not be weakened**: a change to either is a privacy
change.

**G-4 (B-4).** The refusal on a zero mask challenge is *exactly necessary*,
not conservative: with one `cm = 0` the real schedule discloses 2, because
singleton groups are common. Nobody weakens that refusal.

**G-5 (labels).** With the errata applied, the privacy case's seven "computed
on captures" steps that concern the linear channels may be re-labelled
**PROVED-CONDITIONAL on this lemma, for the two toy layouts**, the conditions
being G-3's invariants, the refusal replay (owed a Rust test), and the
random-oracle reading of "refusals are independent of the hidden data". The
joint statement stays COMPUTED-NOT, per G-1.

**G-1 is fixed (01:32, 2026-09-20)** [MEASURED, `zk60-native-jointview` at
`14b7d20`]: stage 4 now builds one generator system per receipt across its
commitments with shared coordinates identified, and computes `joint`,
`sum_of_parts` and their equality. At the toy profiles the shared coordinates
are the two endpoint planes, which are `A`'s own planes; no blinding source is
shared, so joint = sum is a theorem of the block structure there, stated as
such and still computed: **joint 4, sum 4, equal, on all four captures.** A
blinding row shared across two commitments leaves every per-role figure
unchanged and moves the joint from 4 to 260, so the control fires; three more
controls fire; one blind spot (only singleton-group positions are visible to
that control) is recorded as a test. The certifying minor is printed per role
and its determinant recomputed independently: nonzero in 16 of 16. Tests
69 → 85. The earlier figure is therefore now a computed one for these four
captures; the lesson of G-1 stands.

## 3. What I reviewed myself, and what was delegated

I read the check's hand-back report and its table of blocking items. G-1 is my
own tool's defect and my own repeated figure; I did not find it, the lemma's
drafter did, and the check confirmed the line numbers. I did not re-run the
determinant comparison. Both documents were produced by delegated Opus agents,
the second instructed to assume the first was wrong. **Nothing here establishes
a privacy property.**

## 4. Next steps

1. Fix the gate (G-1), print the certifying minor, re-pin `mle.rs` at the
   integrator's row-fold commit, rerun on the four captures — one lane on
   `zk60-native-jointview`.
2. Errata pass on G.
3. A Rust test that pins the refusal replay order against the opening's
   challenge order (additive; on the 125M lane).
