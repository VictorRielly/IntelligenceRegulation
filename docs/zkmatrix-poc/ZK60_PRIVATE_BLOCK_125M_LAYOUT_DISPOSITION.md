# Disposition of the 125M private-block layout — security owner, 2026-09-19

Written by the interactive Claude Fable 5.1 session (the security owner) at
23:29 on 2026-09-19. It rules on two delegated documents:

| Short name | Document | What it is |
|---|---|---|
| L | `ZK60_PRIVATE_BLOCK_125M_LAYOUT.md` | a paper layout for growing the one complete private block from its toy shape (32 tokens, width 16) to the 125M-class shape: 12 layers, 512 tokens, width 768, hidden 2048, 12 query heads of 64 over 4 key-value heads |
| L-check | `ZK60_PRIVATE_BLOCK_125M_LAYOUT_CHECK.md` | an independent adversarial check of L with exact recomputation (`results/zk60_private_block_125m_check/`, predictions written before the arithmetic): 4 blocking items (B-1 … B-4), 15 corrections, 6 omitted conditions |

| Verdict | **Accepted as the plan for the next build, subject to the four blocking items and the rulings of §2; the draft is returned for an errata pass before anyone implements from it.** The working ruling of `ZK60_MVP_COMPLETION_PLAN.md` §5.2a — grow the built single-commitment form first, measure, then decide on the two-prover form E — **stands and is strengthened.** Nothing here is a privacy acceptance, and nothing has been run. |
|---|---|

## 1. What survived the attack

- **The shape is the repository's own record**, not an assumption, including
  grouped-query attention (12 query heads over 4 key-value heads).
- **The totals reproduce**: `A` 5,681 rows, a receipt of 40,747,256 bytes per
  block (the draft said 40.6 MB), about 489 MB for twelve; `H` corrected to
  7,120 (the draft dropped two of four redundant lookups); 36 opening groups
  on `A`, not 35. **Soundness per opening 2^-105.61 at 2^14 columns and rate
  1/4**; by the accounting of decision D15 one block is about 2^-101 and
  twelve about 2^-97.5, the lookup argument dominating.
- **Both integer-window findings are exact.** The norm's window must grow from
  2^29 to 2^32 and lands 0.2076 bits under the construction's ceiling; the
  softmax window grows from 2^14 to 2^18. Nothing else wraps.
- **Ten of the eleven "design decisions in disguise" are confirmed**, and the
  check found six more pins the draft missed. The output-binding site
  (`argument.rs:626`) is **a panic, not a soundness hole**: the fold asserts
  its length (`zkp-core/src/mle.rs:118`) for every width that is not a power
  of two. Loud, not silent — but it means no proof at width 768 until fixed.
- **Form E would save 10–17% at this shape**, lower than the draft's 17.8%,
  because the GPU feed-forward prover proves neither the second norm nor the
  second residual. The attention half is about 80% of the block.

## 2. Rulings

**P-1 (B-1, B-4): padding is governed by one proved invariant, not by
case-by-case exemptions.** At the toy every domain is a power of two, so no
relation was ever evaluated on padding. At width 768 (padded to 1,024) the
sum of squares inside the norm reads 256 padded columns of the hidden input,
and **neither fix the draft discusses forces them to zero**: a prover could
put junk there, obtain any divisor it likes (the check moved it from 2,300 to
524,357 on the real checkpoint's figures), and produce a "correct" output that
is not the block applied to the committed input. The draft's public support
indicator, used alone, *removes* constraints on the pad; that is the wrong
direction. **Ruling: every hidden plane on a padded domain is PROVED to be
zero off its support**, by an explicit pad-zero term `(1 − supp)·plane = 0`,
batched per padded domain over *every* committed plane on it, not only the two
the hole was found in. A plane may be exempted only by name, with a stated
reason (a looked-up pair whose table entry at input 0 is not 0, for example),
and an exempted plane is then excluded from every summation by the support
indicator. The errata pass produces that table plane by plane. The support
indicator is not a prefix mask: the padded head slots are `{3, 7, 11, 15}`,
one per key-value group. **Acceptance tests that can fail:** a lone nonzero
value written into a pad is rejected by the verifier; and the check's sharper
test — nonzero pad values *with* the divisor, remainders and outputs adjusted
consistently — is rejected too.

**P-2 (B-2): public weights are zero off their support, as a stated
obligation** of the construction and of model registration (the approved root
commits to the zero-padded matrix), with a construction-time check that each
folded weight vector vanishes off the support. With P-1 this is belt and
braces on the input axis and necessary on the output axis.

**P-3 (B-3): the lookup-summation claim is repaired before the row geometry
moves.** At 2^14 columns the helper planes' domains straddle the row width, the
single summation claim then has parts under three different column-weight
keys, the module's own audit refuses it and the commitment code asserts: **no
proof would be produced at all.** Accepted fix: lift the lookup and table
domains to the row width (no extra rows), with the padded table positions
repeating an existing entry so that the proved set is still exactly the 256
byte values. It is sequenced **before** the step that changes the column
count.

**P-4: geometry.** 2^14 columns at rate 1/4 is the working geometry for this
profile, with the soundness figures of §1 quoted in every status line that
mentions it. Whether a whole-proof figure near 2^-97 to 2^-101 is acceptable
is a question I will put to Victor with decision D15's, not decide here.

**P-5 (the norm pin).** Pinning the norm's inputs below 2^12 is accepted in
principle: the real checkpoint's recorded inputs are at most 83 in magnitude,
49 times inside the pin, and the pin turns 0.21 bits of margin into about 5.
Two conditions: the draft's arithmetic is corrected (`wrho` 29, not 27; three
limbs for `D`, not two), and **the first-residual stream's range, which was
never measured, is measured on the real checkpoint before any proof about the
real model** — until then the pin is a property of the synthetic fixture only.
This is decision D16's precondition at this width, and it needs the
norm-range lane (`zk60-private-norm-range`), which is pushed and **not yet in
the integration branch**.

**P-6 (memory and the box).** Peak 11.0 GiB modelled (9.6 after the buffer
frees of step S2) on a machine with about 14 GiB available, a record of
out-of-memory failures, and another agent's builds running. **The 125M block
is a heavy run**: detached, under the heavy lock, with a memory ceiling that
kills the process rather than the machine, after S2, and with peak resident
memory recorded as an acceptance figure beside the wall-clock. It is not run
while a GPU job or a release build is active.

**P-7 (the rung).** Development targets a small non-power-of-two rung first —
the check and the draft agree on the idea; I fix its requirements: a width
that pads (48 → 64), grouped-query attention with group 3 so that the padded
head slots interleave as they do at 125M, a token count that pads, a column
count chosen so that the helper domains straddle the row width as they do at
125M (so P-3's failure is reproduced and then fixed at a size that runs in
seconds), and both endpoints wider than one block so that decision D17's
multi-block seam is exercised. **Every hole found tonight must be reproducible
as a failing test at the rung before it is fixed.** The 125M run is then a
measurement, not a debugging session.

**P-8 (scope).** One private block of the 125M shape on synthetic weights is
the deliverable. Twelve blocks under one transcript, the real checkpoint, and
form E are all later and separately ruled. The toy profile stays byte-frozen
at 2,816,472 bytes through every step (D17); the first steps touch shared
constants, so receipt identity is asserted at every commit, not at the end.

## 3. What I reviewed myself, and what was delegated

I read the check's hand-back report, its verdict and its table of blocking
items, and the draft's hand-back report and outline. Ruling P-1's choice
between the check's two offered fixes is mine: a proved invariant covers
relations nobody has written yet, where per-relation indicators are exactly
the kind of rule that was forgotten here. I did not re-run the recomputation
or re-read the module. Both documents were produced by delegated Opus agents,
the second instructed to assume the first was wrong. **Nothing here
establishes a privacy property**; a grown layout owes the joint-view gate
again from the start.

## 3a. After the errata pass: an independent recount (00:36, 2026-09-20)

A pure-Python, shape-driven layout model
(`scripts/zk60_private_block_layout_model.py` on lane
`zk60-private-block-125m`, commit `b22fe74`, 25 tests) was written from the
rules and from `layout.rs`, and was required to reproduce the toy **exactly**
before anything else counted. It does: all 23 numbers the Rust asserts (455 /
384 / 50 rows, the group and site counts, 61,440 lookups, 2,816,472 bytes),
and the slot table and site arrays element for element. Then [COUNTED by the
model, nothing run]:

- **125M shape: zero differences** from the revised memo, receipt rebuilt part
  by part to 40,750,024 bytes.
- **The rung: one difference, 4,173,208 bytes against the memo's 4,173,032.**
  The whole 176 bytes is the support indicator of one slot (`SC_KVZC`): the
  memo's text gives the key-value domain an indicator and its receipt
  arithmetic leaves it out. The model's figure stands; the memo's §9a figure
  is to be read as 4,173,208.
- **The pad table is complete**: 100 planes = 64 ruled ZERO + 35 EXEMPT by
  name + 1 with no pad after the lookup repair (`H_U`). The editor's summary
  figures (62 / 61 / 35) counted three different populations and cannot be
  added; the table itself has no unclassified plane.
- The refusal of blocking item B-3 (three column-weight keys at the new row
  width) was reproduced independently, and the model notes that the lookup
  domain already pads at the toy.

The model is now the oracle for the change list's shape-driven layout step.

## 4. Next steps

1. Errata pass on L: B-1 … B-4 as ruled, the 15 corrections, the 6 conditions,
   the per-plane pad table of P-1, the rung of P-7, the change list re-ordered
   (P-3's repair before the geometry step).
2. Settle with Codex who implements, and get the norm-range lane integrated.
3. The rung, test-first; then one 125M block as a heavy run under P-6.
