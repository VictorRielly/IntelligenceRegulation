# The slot closures at the shaped layouts — disposition

By the interactive Claude Fable 5.1 session (the security owner), 2026-09-21,
01:22. It rules on `ZK60_SLOT_CLOSURES_SHAPED.md` (a delegated agent's draft of
tonight) after `ZK60_SLOT_CLOSURES_SHAPED_CHECK.md` (an independent agent told
to assume the draft wrong, with its own ports and seven scripts). Both read the
lane `zk60-private-block-125m` at `8c5922b`.

**Not a privacy acceptance of anything.** This page narrows gap G-R2 — the
hypothesis (H4) of the run's composition theorem — and no more.

## 1. What survived the attack

- **The closure property holds, with changes**: all seven clauses, four of
  them with a named defect that is bookkeeping or enforcement, none a break of
  (H4).
- **The clause the theorem needs in its strong form holds more strongly than
  the draft said.** At every shaped layout every monomial of all 23 slot
  definitions carries a public factor, so the closure polynomial evaluated on
  an extension-round-supported vector is the **zero polynomial** in the
  prover's values — not merely zero at each honest value. The second mechanism
  (the other private factor vanishing) is needed only at the toy, where there
  is no group factor. Computed on 92 of 92 slot-shape pairs; the negative
  control (the pad-zero term moved outside its `eq` bracket) breaks it in 21
  of 21.
- **The masking of every slot is exactly tight, with no bad challenge set.**
  Slot 09 at the 125M parameters: mask length 41, dimension 40, rank 40,
  kernel 1 — at fourteen challenge vectors including repeated, all-equal,
  all-zero coordinates and unrefused round challenges 0 and 1. Over 23 slots,
  four shapes and twelve to fourteen vectors: **1,120 checks, none not
  tight**; a mask one degree short covers only 27 of 40.
- **What a slot publishes is what the count says**: on the real four-group
  bundle, 23 of 23 slots match `1 + N(d+1) + terminals` — 1,269 words per
  stage — and the chain and terminal identity re-run from the published fields
  alone.
- **No verifier-side panic is reachable from a malformed receipt.** The wire
  decoder, the sumcheck verifier, the public-length refusal, both opening
  verifiers return errors; the three panics the draft listed are reached only
  while a *shape* is being defined.
- Slots 21 and 22 have no ordering problem in a run: the boundary's root is
  absorbed at the second step of stage k, before any slot challenge.
- A zero batching coefficient `mu` or `mu_pad` (neither is refused) is a
  soundness matter at 2^-128 only: it enters the polynomial and never a
  terminal, a claim point or a pair coefficient.

## 2. Rulings

**C-1 (the check's B-1) — four slots declare more degree than they use, and
stay as they are.** Slots 14, 15, 16 and 18 declare degree 5; where their
domain pads, the closure's degree is 4, because the lookup arm that sets the
declared degree never carries the pad gate. Over-declaring is safe for (H4) —
no slot under-declares, which would not be. It wastes 816 / 816 / 640 bytes
per block (7,680 bytes in a twelve-block 125M run of 484 MB). **Not changed:**
it would move every shaped profile's bytes for a saving below two thousandths
of a percent; recorded as slack to take if the schedule is ever reopened.

**C-2 (B-2) — clause C1 reworded, and a second thing ruling S-3 protects.**
"Every private plane raises exactly one claim" is false for slots 15 and 16:
the rotary partner makes the *same* plane raise two claims at points differing
in one flipped coordinate. The checker built the miniature the draft had not:
all properties hold. Their column keys separate only because the head
dimension is below the row width — which last night's refusal S-3 enforces for
slot 08's sake, with 6 to 8 bits of margin at the shapes in scope. **The
refusal's documentation and its test are extended to say it protects slots 15
and 16 too.**

**C-3 (B-3) — host discipline is checked by nothing at the shaped layouts.**
No test and no production check compares the hosted lists written literally in
the slot definitions with the host table; the existing assertions are
test-only and against the toy's constants. A mismatch would be a **soundness**
defect, not a privacy one — a hosted claim consumed twice or never. **A test,
generic over every shape, on the lane; the integrator is told.**

**C-4 (B-4) — the mask budget becomes a named shape refusal.** Today it
is a prover-side assertion inside the masking commitment; shape validation has
ten refusals and none is `L + 256 ≤ 512`. Every shape in scope passes with
room (the worst is 117 + 256). **Named refusal and test on the lane.** The
draft's word "panic" is qualified with the finding above, so that nobody reads
it as a denial of service on the verifier.

**C-5 (B-5) — errata.** *(Labels corrected 2026-09-21 01:39: I had numbered
two findings from the checker's summary instead of its file; in the file the
joint-law sentence is B-5 and B-6 is its three confirmations. The errata
editor caught it.)* The joint-law sentence is wrong as written for the six
*host* slots (their scalar carries other slots' mask totals); it is still
uniform marginally, by the toy's Lemma 2.2, which is cited explicitly. The
draft's degree-rise cost rows are corrected with C-1's split.

**C-6 — ruling R-7's ζ count.** Already un-made at 00:43 in the run's
composition disposition; this check is the third independent count: **8 ζ and
8 `mu_pad` draws at both development shapes, 5 at the 125M shape.**

**C-7 — the draft's gap S-C1 is taken up**: a Rust test that evaluates each
slot's closure polynomial on extension-round-supported vectors, at every
shape, on the lane. With the stronger form above it should be able to assert
identity to zero for arbitrary values, not only honest ones.

## 3. Where gap G-R2 stands

At the two development shapes (H4) is read, computed and — for the terminal
identity and the published-word count — measured on fully dense bundles; what
is left there is enforcement (C-3, C-4, C-7). **At the 125M shape every figure
is a count or a computation at that shape's parameters; nothing has been
evaluated on a 125M receipt, and the present tools cannot.** Same limit, same
wording, as for the per-commitment lemma.
*[2026-09-23: false since 2026-09-21 — the run gate evaluates the 23-slot
terminal identity on 125M receipts, **46 of 46** on two two-block captures
(round 9, `ad16a77`; repeated in round 9c's full pass), after repairing a port
defect only that shape could show (finding M-F1: three power-of-two domains
draw no pad-zero challenge). The enforcement left at the development shapes
is built too: C-3, C-4 and C-7 are lane stage 24 items 6–8 (`68e8769`). The
per-commitment lemma's identical sentence was corrected on 2026-09-22 14:47 —
evidence: `ZK60_PRIVATE_RUN_MULTI_BLOCK_DISPOSITION.md` §2b round 9; gate
ledger `ZK60_NATIVE_RUN_GATE_PROGRESS.md` R9g.4 on `zk60-native-jointview`;
lane ledger stage 24.]*

## 4. What I checked myself, and what was delegated

Myself: nothing new tonight beyond the two repaired arms read yesterday.
Delegated: the reading of 23 arms (two independent readers agree), every
computation (two independent implementations agree, and one tested the other's
port for a bit-order defect and found none). The draft and the check disagree
on no number and on one clause's wording.
