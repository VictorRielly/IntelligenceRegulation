# ZK60 — security owner's disposition of the slot expression IR design and its independent check

**Written 2026-09-21 16:34 PDT by the security owner (interactive Claude
Fable 5.1).** Inputs: the design memo `ZK60_SLOT_EXPRESSION_IR_DESIGN.md`
(drafter, commits `b94f3b3`..`7c09272`, evidence `results/zk60_slot_ir/`) and
the independent adversarial check `ZK60_SLOT_EXPRESSION_IR_DESIGN_CHECK.md`
(checker, `8bf00a0`..`0e38380`, evidence `results/zk60_slot_ir_check/`), both
on this branch. What I verified myself is marked [READ]. Labels: [COUNTED]
from code by a script; [MEASURED] from a committed log; [MODEL] an estimate,
never a prediction.

## 0. In plain words

The prover's 23 sub-arguments are today Rust closures the shared sumcheck
loop calls once per cube point per evaluation point. The memo proposes writing
each sub-argument's polynomial down as DATA, so that a specialised CPU
evaluator, a GPU kernel and a description the independent Python gate can
read are all derived from one source. The checker re-derived every count by a
different method (transliterating all 23 closures into exact polynomial
arithmetic) and **confirmed the baseline to the digit** (16,478,006,793
base-multiplication units per 125M proof; 746,012,745 at rung-W14), confirmed
the combined saving (59.9% against the memo's 58.2%, with additions priced at
zero), and found one classification error that would have produced a WRONG
PROOF if built as written. **My reading of the two documents together: the
case for the IR is the GPU and the gate's independence, not the CPU
percentages** — the checker's own ceiling for the CPU prove with every lever
taken is 13.4 s [MODEL], and after that the two commitments are 60% of what
is left. The 5-second target is not reached by anything on this page.

## 1. Rulings

**I-1 — the counts stand as counts.** Baseline and levers are accepted as
[COUNTED] figures with the checker's corrections: lever (b) 14.2% of the
baseline (memo: 10.9%), lever (a) 14.4% (memo: 20.8% — see I-2), lever (c)
31.2% with its finite-difference additions priced at zero, and combined 59.9%
at zero addition cost, **52.4% / 44.9% / 29.9% if an extension addition is
priced at 0.25 / 0.5 / 1.0 of a base multiplication** [COUNTED, the check §3].
The memo's three percentages are shares of the previous row, not of the
baseline, and are to be rewritten as shares of the baseline. **No count on
this page is a time**: the checker showed the count model does not reproduce
the measured per-slot seconds (implied throughput spans 6.7× across the six
big slots; slots 17 and 14 are 3.92 : 1 counted against 1.86 : 1 measured),
so a count is a lower bound on work, not a model of time.

**I-2 — the base-field classification must be DERIVED and TESTED, never
declared (finding IR-C1, the one that matters).** Twelve of the memo's 143
"wholly base-field" tables are extension-valued: eleven `A` planes read at a
fixed claim point, where `priv_table` weights them by an `eq` tensor of
CHALLENGES, and the byte-table column that carries `g_u8`. The correct count
is 131 of 229. A `FieldKind::Base` written into the IR for one of those
twelve would make a stage-5 evaluator drop imaginary parts silently, and no
test on the proving path today checks proof CONTENT at the small shapes — the
honest proof would simply fail to verify, or worse, verify by accident at a
degenerate fixture (the S19-F1 pattern). Ruling: (i) `FieldKind` is computed
from provenance — a table is base-field only if no challenge and no
extension-valued input enters its construction — and the rule is written in
the memo; (ii) a filter test asserts, at every registered shape and both pad
branches, that every table the IR calls `Base` has zero imaginary part on the
honest generic witness, and that a deliberately mislabelled table makes the
test fail; (iii) lever (a) buys the seven matmul slots and the two bilinear
slots nothing, and the memo says so.

**I-3 — the checker's extra lever (IR-C19) is the cheapest shared-file change
on the table and goes to the integrator as request R1d.** `sumcheck::prove`
evaluates every round polynomial at `degree + 1` points (`sumcheck.rs:83-89`
[READ]) although the prover knows the running claim and `s(1) = claim − s(0)`:
one evaluation per pair index is redundant, **15.8% of the baseline**
[COUNTED]. What is sent is unchanged (the same field values). What is lost is
a mid-proof self-consistency the verifier's `s(0) + s(1) == claim` check
provided against a prover bug; the terminal check `final claim ==
poly(terminals)` still catches any such bug one round later, so nothing
false can be accepted. Condition: a debug assertion of `s(0) + s(1) == claim`
in test builds, and the oracle tests compare against the full evaluation.
This applies inside the masked sumcheck only if the claim the prover tracks
is the unmasked one at that point — the implementer reads `zk::masked_prove`
and says which.

**I-4 — what the lane can do alone, and what needs the integrator.** One
correction to the check's sharpest sentence: "hand-specialising slots 17 and
14 with no shared-file change" is not available. The loop over evaluation
points and the fold live in `sumcheck::prove` (`:76-90` [READ]); a closure
can only change what happens INSIDE one evaluation. So lever (b) — shared
sub-expressions, the support gate hoisted, base constants — is lane-only
(14.2% [COUNTED]); levers (a), (c) and R1d all need the shared loop to hand
the evaluator a range of pair indices or the whole round. **Order: (1) lane
stage — IR stage 1 (below) and lever (b) inside the closures of slots 17 and
14, which are 82% of the counted baseline and 71% of the measured
masked-sumcheck seconds [COUNTED / MEASURED, check §11]; (2) integrator — R1d
and the interface of I-5; (3) lane — levers (c) then (a) through that
interface, slots 17 and 14 first.**

**I-5 — the interface (Option A), accepted in principle as an OFFER to the
integrator, with the check's three corrections.** A `SumcheckRounds` trait
(`round(j)`, `fold(r)`, `finals()`) beside the closure path, `prove` becoming
a wrapper over a `ClosureRounds` that is today's code verbatim, and an
additive `masked_prove_rounds` in `zk.rs`; the legacy functions untouched
(`masked_prove` has 18 call sites, the frozen `private_seam.rs` among them —
additive or nothing). Corrections: drop the `Sync` supertrait (the device
handle is `Send`, not `Sync`, and the trait's own purpose is the device);
write the preservation list into the trait's documentation — transcript
absorb order, where the CFS mask enters, the extension rounds, the refusal
points (`e ∈ {0, 1}`, zero challenges), rayon chunking with exact field
addition so reduction order cannot matter; the frozen byte gates on main
that must stay green named in the request. **Precondition I verified myself
[READ, run at 16:20]: `tests/test_zk60_mvp_security_probe.py` is ALREADY RED
on main** — `hashline/src/zk.rs` no longer matches the round-22 capture
manifest since the integrator's `4751b93` (2026-09-20 20:52); one failure,
one error from the same cause. That pin is the integrator's and must be
re-read and re-pinned BEFORE any further change to `zk.rs`, or two changes
become indistinguishable in it. (The toy statement's D22 pins are a separate
set and were re-read at `4751b93` on 2026-09-20 22:06; D22 is unaffected.)

**I-6 — memory on a device: the round loop fits an 8 GB card, the prover
does not.** The memo's table sizes reproduce exactly [COUNTED, check §10]:
3.44 GiB slot-at-a-time, 4.83 GiB for all slots with `A` and `H` as raw
data — and the raw-data row is the error: at 125M the two commitments' encode
and Merkle passes grow the prover's resident set by about 6.4 GiB
[MEASURED, `q28-m125-final-dense.log`], and the whole prove peaks at
10,156 MiB. Under the standing rule that exhausting VRAM freezes the whole
WSL machine, **the sentence "fits an 8 GB card" may be said of the round
loop alone, with the `Fp → Fp2` fold peak written as an implementation
condition (free each base table's buffer before folding the next, or the
peak returns to the all-extension figure), and may not be said of the whole
block.** The whole block is a 32 GB-card design (the 5090), and the
commitments need their own memory design regardless of the IR.

**I-7 — the degree finding: recorded, excluded, and marked for the next
profile change.** Two slots (14 and 15 — not four; the checker verified slot
by slot at the two shapes the memo is about) declare a round degree one
higher than any product attains: 640 B of receipt and 3.4% of the count
[COUNTED]. Lowering a declared degree moves bytes and needs a new profile; it
also needs the soundness reading that the declared degree bounds the true
degree at EVERY shape and both pad branches. No mask-budget (C-4) or
soundness figure in the project depends on the declared degrees. Excluded
from this work; on the list for the next profile change.

**I-8 — IR stage 1 is accepted as lane-only work now.** Types, a builder
beside each arm of `define` producing the IR for that slot, and the oracle
test: the IR evaluated against the closure on random tables at every
registered shape (toy, the rungs, rung-P2, rung-C6, rung-W14, rung-E32),
through both branches of every threshold, under 1, 2 and 8 threads — plus
I-2's `FieldKind` oracle. **No execution path changes; no byte moves;** the
closures stay the oracle. Stage 1b, also lane-only and test-only: a JSON
export of the IR per shape, pinned by digest in a capture bundle, which the
Python gate reads as a CROSS-CHECK of its hand port first — the hand port is
not replaced until the gate has predicted, from the shape alone, the draw
counts and degrees the export declares, and one hand-ported family stays as
an independent check forever (the independence the memo's §6 says is lost is
kept that way).

**I-9 — the honest headline.** The checker's Amdahl ceiling [MODEL]: all
three levers at 59.9% → 13.4 s for the 125M block on this laptop; the round
loop at zero cost → 10.8 s, of which the two commitments are 60%. **The IR is
worth building for the GPU path and the gate, and it is not the road to 5 s
by itself**; the commitments are the larger half of that road, and they are
the integrator's and the device's.

**I-8 DONE — 2026-09-21 17:46 (lane stage 34, `89e393f`, pushed; I checked
that the two new modules are `#[cfg(test)]`, that `argument.rs` and
`protocol.rs` do not appear in the diff, and the filter result: 403 passed /
0 failed / 17 ignored).** The IR of all 23 slots is built beside `define`
without touching an arm (a script counts 0 removed and 0 added lines in
`argument.rs`); the IR evaluated against the closure at 9 shapes × 23 slots ×
8 random points — **1,656 evaluations, every one equal**, 125M included
(its IR needs no witness), both pad branches of every pad-hosting slot. The
field kind derived from provenance gives **131 of 229 `Base` at rung-C6,
rung-W14, rung-E32 and 125M** — the check's corrected count, the memo's 143
wrong by twelve at every shape — and the oracle catches exactly those twelve
when a control mislabels them (S34-F2: the test harness had to give every
definition-time challenge an imaginary part, as production does, or one of
the twelve hides; S34-F3: a few base tables are identically zero on the
honest fixture, so the oracle also runs a dense nonzero pass). Declared
degrees bound the interpolated true degrees at all 207 pairs with **22
one-degree gaps, exactly the LogUp hosts whose own domain pads** — the I-7
fact, asserted, unchanged. `s(0) + s(1) == claim` holds at all 379 rounds of
46 (shape, slot) pairs on the honest prover's round loop — the lane's half of
R1d. Nine canonical JSON exports (99–110 KB each) pinned by digest and length,
no challenge value in them. One fact worth carrying: the IR encodes the
memo's hoisted support gate, so the equality oracle already shows the first
part of lever (b) value-preserving at every registered shape (slot 14: 22
multiplications per evaluation → 12; slot 17: 10 → 6). S34-F1 corrects the
memo's §2.3(ii): `per_row` is the hosted claim's coefficient, not a factor of
slot 17's polynomial. **Stage 2 (lever (b) inside the closures of slots 17
and 14, lane-only, the IR's equality oracle as the gate) may proceed.**

**Stage 2 (lever (b) in slots 17 and 14) DONE — 2026-09-21 18:42 (lane stage
35, `fee1a8d`, pushed; I checked the diff's scope — `argument.rs`, one test
file, two module lines — and read the 125M log's result lines).** Three
changes, one commit each, every one a pure algebraic identity in an exact
field or the implementation identity `x.mul(c) == x.mul_base(c.c0)` for a
constant with zero imaginary part (tested on all 13 constants over 6,656
arguments): the support gate hoisted, two of slot 14's sub-products formed
once, public constants through `mul_base`. Counted per evaluation: slot 17
175 → 119 of 405 units (13.8% of its closure), slot 14 320 → 165 of 828
(18.7%) [COUNTED]. Old closure (verbatim from `89e393f`) = new closure = the
stage-34 IR at 576 points and 72 comparisons per registry walk, both pad
branches; table list, order, rounds and declared degree pinned unchanged;
receipt 40,783,352 B identical. **What it measured [MEASURED, one run each,
shared box, NOT quiesced]:** at rung-W14 nothing distinguishable from spread
(three runs each, every range overlapping — its cubes are 2^16); at 125M slot
17's masked sumcheck **3.05 / 3.11 → 2.66 s** (about −13%, close to the
count, and against a baseline spread of 0.05 s while the untouched
neighbours ran slower in the after-run), slot 14 **1.64 / 1.87 → 1.74 s**
(nothing — IR-C9 again: the larger counted saving shows no clock), the whole
prove **18.40 s against 17.40 / 19.36** — inside the band. **Honest headline:
one measured 0.4 s on one slot; the 125M block stays at 17.4–19.4 s.** This
is what lever (b) alone is worth on this CPU, and it says that the remaining
levers need the shared loop (I-4, I-5) and that the commitments, not the
rounds, are where the CPU time is. Finding S35-F1 for the integrator:
`argument.rs::limbs` is now dead code (its only callers were these two arms;
the arms-only rule kept it) — delete or keep behind `cfg(test)` as an oracle.
Filter 408 passed / 0 failed / 17 ignored.

## 2. What this is not

Not an implementation (nothing compiled or run by either agent; the IR-versus-
closure equality is stage 1's first test). Not a speed result: every
percentage on this page is a count of multiplications, and the one thing the
counts were tested against — the measured per-slot seconds — they do not
reproduce. Not a change to any privacy or soundness statement.
