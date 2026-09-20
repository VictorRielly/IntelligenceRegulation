# Disposition of the form-E draft — security owner, 2026-09-19

Written by the interactive Claude Fable 5.1 session (the security owner) at
22:17 on 2026-09-19. It rules on two delegated documents:

| Short name | Document | What it is |
|---|---|---|
| F | `ZK60_PRIVATE_BLOCK_FORM_E.md` | a draft of the complete private block at model width that keeps the block-decomposed GPU feed-forward prover ("form E"): two provers under one transcript, two seams, and how blocks chain |
| F-check | `ZK60_PRIVATE_BLOCK_FORM_E_CHECK.md` | an independent adversarial check of F, with a small-model experiment of a seam between two commitments (17 cases, `results/zk60_form_e_check/`): 5 blocking errata (E-1 … E-5), 15 corrections (E-6 … E-20), 11 omitted conditions (C-1 … C-11) |

| Verdict | **The construction's core is accepted; the draft is NOT yet a design to build.** It is returned for revision against the check's table and the rulings of §2. **Nothing here is a privacy acceptance**, and at model width the numbers that would justify building it are 60% estimate. |
|---|---|

## 1. What survived the attack

- **Nothing is opened twice.** Confirmed commitment by commitment: nine
  commitments per block, each opened once; a seam claim rides its side's
  single batched opening, which works because the feed-forward's
  `PendingV3` keeps its claim list open until `finish`, as the private-IO
  path already relies on. No intermediate plane gets a caller-fixed root;
  only `x_in` and `xres2` are external. D12 holds.
- **A seam between two commitments discloses nothing in the small model.**
  The same hidden plane on two commitments under independent masks, related
  by a public equality: predicted 0 before the run, **measured joint 0 with
  parts 0 + 0**, also batched over three blocks and with both seams present.
  The reason, which the draft never states and the check supplies (C-3): on an
  honest witness the two tables are pointwise equal, so the seam polynomial
  `v0·(v1 − v2)` vanishes identically, every masked round is exactly
  `c·g_j(X)`, and only the two masked terminals carry data — each under its
  own reserved pair on its own commitment.
- **The pair discipline is the right one, and is now quantified:** a
  counterparty seam claim with no reserved pair of its own discloses 8 Fp;
  two seams sharing one pair disclose 8; a pair shared with another claim 8;
  opened twice 10; one pad short 6.
- The slot arithmetic, the two seam slots on the feed-forward's masking
  commitment (16 → 20 base rows), every soundness figure, and the row count
  of 26,676 for the attention half all reproduce. The tiling finding is true.
  About 22 of the draft's 30 "this already exists in the code" claims are
  confirmed.

## 2. Rulings

**R-1 (the ruling the check asked for, E-5): two lookup-challenge triples; the
frozen prover function is not split.** The draft wanted both sides' `A` and
`M` roots absorbed before one shared `(β, γ, α)`. `prepare_layer_zk_v3_inner`
absorbs `W → A → M`, draws its triple and commits `H` in one contiguous body
(`zk.rs:2542–2556`); there is no insertion point. Under D17 accepted paths stay
frozen and new things are additive, so the order is
`A-attn, M-attn │ [W, A-ffn, M-ffn, (βγα)_ffn, H-ffn] │ (βγα)_attn, H-attn`,
then both sides' arguments, then the seams, then the openings in a reachable
order (E-9). Each side's triple is still drawn only after that side's own `A`
and `M` are absorbed, which is what LogUp needs; the seam coefficients are
drawn after every root. This **reverses the draft's decision 4.**

**R-2: the acceptance experiment is rewritten** (E-1, E-2, E-16). Three of the
draft's controls cannot fire for an *equality* seam at an honest witness, so
"a control that stops firing is a stop" would have halted a correct design.
The expected-zero and expected-positive cases are as the check lists them; the
three reclassified cases are soundness and simulator conditions and are run in
their non-aliased form, where they do fire. **The gate computes a genuine
cross-commitment joint rank with the shared plane's coordinates identified,
and asserts `joint == sum of parts` as well as `joint == 0`**: the one new
failure mode a seam introduces — a blinding source shared across the two
commitments — measured **joint 8 with every per-role figure 0**, so a per-role
gate is blind to it. The two-masking-commitments question cannot be decided
by a linear model; it is replaced by the per-slot derived-mask-evaluation
identity asserted for both masking commitments on a real receipt.

**R-3: the tiling rule is restated** (E-3, E-13, E-14). Where the block count
is a power of two (one block at width 4096; two at 8192; four at 16384), a
public index map binds the attention side's flat plane to the feed-forward's
blocks with **no re-tiling and no extra draws**. Where it is not (768, 5120,
6144, 12288 …), the **whole** `Dom::D` family re-tiles together — 35 `A`
planes, 19 helpers, the public `gamma` vectors (so the public-statement digest
moves) and the zero-check, batched over the blocks — at about +70 claim sites
and +140 rows at three blocks. "Costs nothing" is withdrawn.

**R-4: the module lives inside `hashline::zk`** (C-4). `PendingV3`,
`prepare_layer_zk_v3_inner` and `verify_layer_zk_v3_with_seams` are private to
that module; making them `pub` would widen a frozen prover's interface and is
refused. Every seam claim stays on `A`, because the existing verifier hook
exposes `ac` and not `hc` (C-5). The two `mask_open` calls draw two separate
`θ`; their functional lists must never be mixed, and that gets a check (C-6).

**R-5: the counterparty's seam claim carries its own reserved pair, and
`audit_claims` is ported to the feed-forward's claim path before any external
claim is pushed onto its `A`** (C-1). This is a build precondition, the same
one D17 set for the private-IO path.

**R-6 (added 22:41, after the revision; found by the errata editor while
applying R-1).** R-1's order has a consequence the draft's step list missed:
the feed-forward's own statement absorb (`absorb_statement_v3`, `zk.rs:2364`)
is the first act of the frozen function, so it happens *after* the attention
side's `A` and `M` roots are absorbed, not before. That is sound provided
**the wrapper's public-statement digest, absorbed before any root, covers the
exact `StatementV3` bytes the frozen function will absorb** — then the
attention commitments are bound to the feed-forward statement before they are
made, and every challenge on either side still follows both absorbs. It is a
build requirement with a verifier-side test: a block statement whose digest
and whose feed-forward statement disagree must reject.

## 3. Chaining, after today's other ruling

The draft recommended runs of `g` blocks under one transcript, starting at two.
The shape is right; two things change it.

1. **The boundary between two runs is a forbidden root.** The D8/D11
   restatement's check established it independently
   (`ZK60_D8_D11_RESTATEMENT_DISPOSITION.md` §2.5): the upstream receipt
   already contains a full opening of its output commitment, so a downstream
   proof consuming the same root is a second opening, is also prior history,
   and is unimplementable today. **A private run is one transcript end to
   end.** Joining runs needs the sealed handle of D18's option B, which Victor
   has recorded as a todo and expects to be the end state. D12's item 2 is
   generalised, not contradicted, by a multi-block proof; the amendment must
   also say that a run's internal boundary planes are hidden intermediates
   under item 3 (C-8).
2. **The memory claim was five times too low** (E-4). From the draft's own
   rows, at Mistral width and the model-scale encoding rate: **one form-E
   block is about 28.9 GB resident (5.8 GB systematic + 23.1 GB encoded); two
   blocks about 57.9 GB; thirty-two about 926 GB.** A two-block run does not
   fit a 32 GB card, and one block is at its limit. Of those bytes about 60%
   belong to an attention layout at model width that does not exist — it is a
   plane-count scaling of the tiny layout's hard-coded constants — and against
   the feed-forward's *private* commitments alone the attention half is about
   **80%** of the private material (C-10), with no device path.

**What follows, plainly.** A multi-block private run at 8B does not fit one
consumer GPU under this construction; whether it can run with the encoded
matrices in host memory is a measurement nobody has. **The first feasible
target for complete private blocks in one transcript is the 125M-class
shape**, where every figure is small, the feed-forward half's private cost is
already measured, and the project's own convergence plan points. Form E's
value at 8B today is as the design that keeps the feed-forward half fast *if*
the attention half is ever given a device path; it is necessary for speed
there and nowhere near sufficient.

## 4. What I reviewed myself, and what was delegated

I read the check's hand-back report, its memory section and its complete table
of errata and conditions, and the draft's hand-back report. I made the ruling
of R-1 myself, from the absorb order the check cites and the LogUp requirement
that each side's challenges follow that side's commitments. I did not re-run
the small model or re-derive the row counts. Both documents were produced by
delegated Opus agents, the second instructed to assume the first was wrong; it
wrote its predictions before its runs. **Nothing here establishes a privacy
property**; the small model is a linear model, and D8 and D11 are untouched.

## 5. Next steps

1. Revise F against E-1 … E-20, C-1 … C-11 and R-1 … R-5, with §F rewritten on
   the corrected memory and on "a private run is one transcript end to end".
2. Before any Rust: the corrected small-model experiment, as a committed gate
   with the joint rank of R-2.
3. The first build target, when it comes, is a two-block run at the 125M
   shape, additive, inside `hashline::zk`.
4. A model-width attention layout, even on paper, before any further memory or
   speed claim about complete private blocks at 8B.
