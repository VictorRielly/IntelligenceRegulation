# The non-linear channel at the shaped layouts (gap GS-13) — disposition

By the interactive Claude session acting as security owner (Opus 5.5,
continuing the Fable 5.1 lane), 2026-09-22, 20:45 PDT. It rules on
`ZK60_NONLINEAR_CHANNEL_SHAPED.md` (a delegated agent's draft, 19:41–20:10)
after `ZK60_NONLINEAR_CHANNEL_SHAPED_CHECK.md` (an independent agent told to
break it: its own field library, its own parser of `define`, every slot
polynomial expanded into monomials rather than sampled). Both read the lane
`zk60-private-block-125m` at `a8e4939`–`4373fb6`; nothing either pinned moved
(check N-10).

**Not a privacy acceptance of anything.** Register entry D22 (the toy block)
is untouched. This page narrows one gap of the shaped block's privacy path
(GS-13, defined at `ZK60_GENERIC_RANK_LEMMA_SHAPED.md:1379`); it does not
close the path.

## 1. What I did myself

- Re-ran both machine checks from a clean shell: the draft's
  `results/zk60_nonlinear_channel_shaped/nl_check.py` (exit 0, 28.7 s:
  premise 23/23 at all nine exports, public factor in every monomial 23/23 at
  every shaped export and 21/23 at the toy, degree 23/23, Fact 2.1 210/210,
  controls 12/12, `Σ L_s / dim C` 859/836 rung-G, 871/848 rung-K4,
  1,239/1,216 125M, 583/560 toy) and the check's
  `results/zk60_nonlinear_channel_shaped_check/nlc_check.py` (exit 0, 24.3 s:
  host coupling 18/18, the D9 control that means something 18/18, the
  inadmissible-world control fires, the M pad block rank 256 at L = 50 / 117 /
  256 with the 255-pad control at 255, 72 of 72 figures equal to the draft's,
  40 of 40 citations found). Both reproduce what the reports said.
- Read `hashline/src/private_block/argument.rs:600-625` on the lane: a
  `Private` slot pushes only the evaluation functional, a `Standalone` slot
  pushes its Γ with the scalar, a `Host` pushes the host functional with its
  hosted slots' terms. That is dependency D9 as the check states it.
- Delegated and not re-derived by me: the monomial expansion, Fact 2.1's
  hand proof, the extension-round parse.

## 2. Rulings

**NL-1 — core ACCEPTED as an algebraic reading.** At rung-G, rung-K4 and the
125M shape (and the five further development exports), every one of the 23
slots satisfies every dependency of the toy's non-linear argument that can be
read from the slot polynomials: a public table in every monomial (184/184
slot-shape pairs, confirmed by monomial expansion, so for every coefficient
value, not only sampled ones), product degree within the declared degree
(207/207), the mask exactly covers each slot (Fact 2.1, 210/210 at full size,
proved by hand in the check for every challenge vector), extension rounds as
the IR labels them (18/18). The argument lifts with its proof unchanged. The
reading rests on the slot IR equalling the closures, which is the lane's
oracle test of stage 34, re-run green in stage 37 (filter 429/0/18). **GS-13
is closed on its algebraic half.**

**NL-2 — the three changes GS-13 named are harmless to this channel.** Degree
5 costs mask length, not privacy (worst 117 of 256 at 125M, slot 17 alone;
72 at rung-G as a tie of slots 17 and 18, N-4). The public `eq(r_g,·)` of
slots 08/09 gives them a public factor in every monomial, so the toy's
second mechanism (factors masked in different extension rounds) is now a
backup there, not the reason. Every support indicator sits beside another
public table.

**NL-3 — "public factor" means a public TABLE (draft R-b), adopted as an
invariant for every new slot or profile.** An affine term with a constant
(`1 − supp`) is not a public factor; the check confirmed no monomial at any
shape has such a term as its only public factor. A future slot that breaks
this needs its own argument before it may carry a privacy statement.

**NL-4 — errata N-1..N-5 accepted; the draft carries them in a dated block at
its top.** The fibre test is evidence only for its 108 Private-slot rows; for
Standalone and Host slots the evidence is the check's re-run with the real
slot kinds (22 runs, all pass, both controls fire) and the four full-size
125M runs of slots 08/09 including challenges 0 and 1. The draft's D9 control
could not fail and is replaced by the check's. The "69/69" terminal rank and
controls C7/C8 are illustrations and leave the headline figures.

**NL-5 — the run memo's stale totals corrected in all four places** (N-3):
`ZK60_JOINT_LAW_COMPOSITION_RUN.md` §2.1's table carries a dated correction
(post-repair 859/836 and 1,239/1,216), with pointers at the theorem
statement, the simulator `O1_run` and the B-8 reconciliation (exact for the
pre-repair schedule; +62 draws per 125M block after it; residual 2^-69.3
unmoved at that precision).

**NL-6 — the refusal inventory gains the host arms' ν draws** (N-6): twelve
`nonzero(…)` draws per block (`argument.rs:1142, 1405, 1552, 1605, 1663`),
challenge-only, so liveness, not distance. Owed as a line in whichever
refusal census GS-14 produces (NL-8).

**NL-7 — design constraint for P3 (hidden weights), recorded, not ruled.**
With the weights private the seven matmul slots (05–07, 10–13) lose their
only public factor (draft control C9, confirmed). The non-linear argument of
this page does NOT carry to P3; P3 needs a new argument for those slots
before any design is costed. This is a fact about the construction, not a
product ruling; `ZK60_PRIVACY_REQUIREMENTS.md` already requires P3 to hide
weights.

**NL-8 — what stays open (not narrowed here).**
- **GN-1 / GS-14, completeness for every admissible witness** at the shaped
  layouts: if a legal input made an honest proof fail, the failure would
  leak. The evidence is test runs (dense generic 125M, 12 blocks; and since
  tonight rung-K8 at lkv = 3), not an argument. **The check found that the
  toy's refusal-site census does not transfer** (N-9): at 125M the `AO` sum
  has 768 terms, `|aoacc| ≤ 12,484,608`, `requant(·, 7)` reaches ±97,536,
  outside int16 — the site is reachable, and the witness builder refuses
  there too (`witness.rs:594`), so it is an admissibility boundary, not a
  hole; but no shaped census exists. GS-14 must include a shaped
  builder-versus-kernel census.
- The linear half at the shaped layouts beyond the generic-rank lemma (G-R1,
  narrowed 2026-09-20), the joint law across commitments (G-R4, draw count
  machine-asserted since stage 36, the LAW still owed), the hash layer and
  the sequential lift for runs (G-R5).
- N-11 (norm gains' provenance label) matters only for P3; leave it with
  NL-7.

## 3. What this changes day to day

Nothing in the code. The shaped privacy path's open list shrinks by GS-13's
algebraic half; GS-14 now names its first concrete item (the shaped refusal
census). No statement for any shaped profile is in force or proposed.
