# Finding S19-F1 — an honest proof refused under grouped attention: disposition

By the interactive Claude Fable 5.1 session (the security owner), 2026-09-20,
19:57. Sources: the lane ledger `ZK60_BLOCK125M_LANE_PROGRESS.md` (stages 19
and 20) and the independent review `ZK60_BLOCK125M_S20_FIX_REVIEW.md`, both on
`zk60-private-block-125m` (tip `901557e`, pushed).

## 1. What happened

A test-only stage added this afternoon replaced the lane's one synthetic
fixture by dense public weights and a generic hidden input. At every profile
with more than one key-value head — both development rungs and the 125M shape —
**the verifier refused the honest proof.** The smallest reproducer was the
production fixture with one word of the hidden input changed. I reproduced it
myself at 18:35. The accepted toy block has one key-value head and is not
affected; register entry D22 stands, and no frozen byte moved at any point.

## 2. The cause — mine

`SC_SCORE` (scores = Q·Kᵀ) and `SC_PV` (output = P·V) are bilinear sumchecks
with two private factors. Generalising them to grouped-query attention, the
construction fixed the key-value **group** bits of the head challenge as
coordinates of *both* factors and summed only over the inner axis. The
multilinear extension of `Σ_c q[h,c]·k[g(h),c]` at a random head point is a sum
over heads of products; a product of two extensions that share variables is
quadratic in them and is a different polynomial. The two coincide exactly when
one factor does not vary across groups — which was true of every input ever
proved at a shaped profile: the fixture's normalised state is identical in
every head, the all-zero input likewise, and the code review's
distinct-key-value case had a zero second group.

**It was a construction error of the security owner's layout rulings, carried
faithfully into code.** The layout design, its adversarial checker and the
independent code review all missed it, because all three attacked soundness
and privacy and none of them proved a generic honest input; and a
prove-then-verify round trip cannot see it, since prover and verifier share one
definition function.

## 3. What it did and did not cost

- **Completeness: lost** for generic inputs at every grouped shape, until the
  repair.
- **Soundness: not weakened.** Argued by me, then confirmed independently by
  the reviewer: the host side is multilinear, the old right-hand side has
  degree 2 in the group bits, so acceptance at a random point forces the
  right-hand side to be multilinear and hence equal to the correct extension;
  at Boolean points a product of extensions *is* the right relation. **No
  receipt accepted before the repair could have attested a false statement.**
- **The results reported earlier today** — one, two and twelve blocks at the
  125M shape, tagged and untagged; the two pairs of run captures; three rounds
  of the run's Python gate — **are true of the degenerate inputs they used and
  say nothing about a generic input.** `MVP_STATUS.md` carries the correction
  above the 125M paragraphs; Victor was told at 18:41 and 19:33.

## 4. The repair, as ruled and as built (stage 20, `5155d5b`)

The group bits become sumcheck variables shared by both private factors, with
a public factor `eq(r_g, ·)`: degree 3 and `log2(kv_heads)` more main rounds in
each of the two slots. With one key-value head the helper returns nothing — no
variable, no table, no degree — and the toy path is byte-identical. I read
both arms (`argument.rs:1126-1187`).

Counted consequences: receipts +336 bytes per block at the rungs and +560 at
the 125M shape (one block 40,783,352 bytes; twelve blocks 484,107,456); main
rounds 215 → 217 and 332 → 336; the two slots' mask lengths 14/16 → 23/26 and
18/24 → 32/41; the largest mask length, the masking commitment's 50 rows, the
terminals, claim sites and opening groups unchanged.

## 5. The independent review of the repair: no hole found

Soundness, completeness and the masking budget: **no hole found**; privacy is
a verdict on the mechanism and the budget only — *no disclosure measurement has
ever been made at a grouped shape on a non-degenerate witness*, and none is
claimed. The reviewer drove the real definition function with its own table
builder against its own extension of the product (toy, rung, a synthetic
four-group geometry with padded slots, three seeds each): equal; the old
formula disagrees on generic data and agrees only with one group or a
group-degenerate buffer. Seven of seven honest cases verify (three random dense
inputs, half the width zero, one query head moved, all-zero, the old fixture);
five of five cheating witnesses are refused (padded head slots; one group's
keys serving the other). It re-derived the mask lengths from the axes and
matches the lane's. The verifier computes the public factor itself.

Rulings on its findings: **F-1** (the Python layout model still declares the
old schedule, and a Rust test had started adjusting the model's expectation by
a Rust-computed delta — the shaped receipt figures had lost their independent
witness): to be repaired in the model, from the shape, and the adjustment
removed (lane stage 21). **F-2** (a named refusal for a shape the bilinear
slots cannot serve): stage 21. **F-3** (the reviewer's cheating witnesses are
caught by the pad and rotary zero-checks, not by the repaired slots, so they do
not isolate them): accepted as a limit of the evidence; the lane's
second-group perturbations and key swap do isolate them. **F-4, F-6**:
recorded. **F-5**: fixed (`a00f831`).

## 6. Measured after the repair

One block at the 125M shape [MEASURED by me, one run each, 19:25, laptop CPU,
shared box, 12 GB ceiling]: **fully dense weights, generic hidden input — prove
27.67 s, verify 1.12 s, 40,783,352 bytes, peak 9.99 GiB; all-zero input — prove
26.98 s, verify 1.23 s.** Dense weights cost no measurable time.

## 7. Process rulings

1. **Standing acceptance rule for every construction, generalisation and
   implementer brief:** a generic honest witness — dense public weights, a
   non-constant hidden input, non-trivial values in every region the new shape
   adds — proves, verifies and matches the independent reference. Every
   checker's and reviewer's brief adds "try to make an HONEST proof fail"
   beside the soundness and privacy attacks.
2. **Every new identity is evaluated independently of the definition function**
   (plain loops over the Boolean cube at a random point), because a round trip
   cannot see a shared wrong definition.
3. **A milestone report names the witness that was proved.**
4. The layout memo's grouped-attention section and its disposition (rulings
   P-1 … P-8) are superseded **for the two bilinear slots** by §4 above; a note
   is owed against them.

## 8. Still to redo, in order

The layout model's independence (F-1); R-5 (interior scales); a fully dense
admissible twelve-block recipe and the twelve-block 125M run on it; the run
captures on a fully dense witness; the Python gate's ports of the two slots
(their terminal identity now carries the public factor and more rounds) — and
with them, for the first time, **the gate's disclosure and rank figures on a
non-degenerate witness**, which is the measurement the privacy verdict above
does not have.
