# U-PERF3 — batched opening layer over the committed digits (design memo, no code)

Status: SKELETON — sections are filled in commit by commit; a section
headed "(pending)" has not been written yet.

Scope: route 1 of the 2026-08-18 decision memo in `PROGRESS_UPERF2.md`
(the lattice-line protocol change after the kernel curve flattened at
21.0 s for the 12x512 slice). Every number below carries one of
[MEASURED] / [COUNTED] / [MODEL] / [ASSUMED]; every claim about the
built protocol cites the report/section it comes from.

## 0. Recommendation

Build a **batched digit-opening layer** that replaces the ten per-table
masked descents with (a) the range/narrowing facts proved as base-field
booleanity + recomposition zero-checks on the committed digits, folded
into the existing claim layer, and (b) the SiLU lookup proved as a
LogUp-as-one-sumcheck with a committed helper `h`, so the whole
range/lookup family reduces — like the eight arithmetic instances
already do — to MLE-evaluation claims served by the SAME two per-group
lattice eval proofs (one opening per group, E-O2-BB preserved). Two
levers compose on top: (T11 b) batch the aggregate's terminal claims to
ONE evaluation point per group so the planner's `r` cap can drop the
level-0 h-garbage rows, and (T11 a/a') feed the level-0 claim functional
from the rank-structured `Phi_0` (never materialized) and — the one
genuinely new piece — let the prover supply `Psi_0` with a small
checkable sumcheck so the verifier's level-0 work goes from
O(n_value_rings) to O(log n_0).

Expected factor, staged and labelled honestly. **Stage A** (range ->
booleanity, SiLU -> LogUp-sumcheck, keep the LaBRADOR opening): the
descents (6.5 s of the 21.0 s, and 71.8% of the 1.51 MB artifact) drop
to ~1.0-1.5 s and the artifact to ~0.5 MB; prover 15.5 s -> ~10.5 s,
wall 21.0 -> ~15.5 s = **~1.35x prover, measurable, low risk**
[MODEL, from the measured phase shares]. **Stage B** (the R-row +
rank-structured `Phi_0` + one-point batching cut the eval proof's
level-0 h-garbage, and the supplied-`Psi_0` sumcheck makes the verifier
sublinear): wall ~11-12 s, and the verifier reaches the <= 2 s / 1T
line — **~1.8-2.5x prover combined** [MODEL, unmeasured; the eval-proof
term dropping is the biggest assumption]. The decision memo's "3-10x on
the prover" is the optimistic top of this range and it requires the
eval-proof opening itself to move (toward the Greyhound-class O(sqrt N)
serving of family (c), AGGREGATION_LITERATURE.md Section 3) — a larger
re-architecture than Stage A/B and out of scope for the first tranche.
None of this reaches the contract's 25-100x on its own; combined with a
<= 450 W desktop board (4-6x [MODEL]) it lands the 8B FFN shape in the
~15-160 s class the decision memo names, not the 5-15 s headline. The
lattice commitment (MLWE/MSIS, post-quantum) and the exact-integer
soundness (range facts failing by design) are preserved throughout.

Biggest [ASSUMED] items, carried into Section 5: (1) the range facts'
K-field descent arithmetic collapses to a much cheaper base-field
booleanity zero-check (the spike measures the K-mult/base-field ratio);
(2) the eval-proof level-0 h-garbage actually drops under the R-row +
one-point batching (device-bound today, may not move); (3) the
supplied-`Psi_0` verifier sumcheck is sound and cheap (new crypto, owes
a proof); (4) the aggregate sumcheck's base-field soundness closes to
the R5 knowledge-error line with challenges in a small extension.

## 1. The built protocol's cost anatomy, counted (pending)

## 2. The design (pending)

## 3. Counts after, side by side (pending)

## 4. Transcript / freeze consequences (pending)

## 5. Honest risks and unknowns (pending)

## 6. Staged plan (pending)
