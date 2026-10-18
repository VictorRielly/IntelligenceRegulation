# ZKP efficiency progress

Cycle 0070 — `20261017T232105Z-d713e393`, 2026-10-17 UTC.

**No proving speedup found.** A Rust evaluator avoids expanded public equality,
selector and position arrays in the row-first lookup probe. It passes 84
synthetic fixtures, 22 controls, 1,788 round values and 252 terminals; independent
audit 4,768 checks, challenge-causality 1,699 +1. Main 3.151 s including compile/
references; one CPU thread, no native proof/GPU. Quadratic base row rounds still
require cubic masked messages; complete private lookup construction remains open.

Counted prototype payload 625.625 -> 178.784 MiB across four groups, before
original sources, masks, commitments, GKR and other live buffers;**not peak memory
or a speed gain**. Added equality generation and V rereads need costing.
[Unapplied handoff](handoffs/20261017-factorized-public-equality.md).
Next: known-previous-challenge fold plus next weighted round.

Current carried R5b 8B T32 CPU baseline: one cold 32-block pass, freshly verified;
191.755 s app/191.975 s process, diagnostic 0.1669 positions/s total. Sealing
37.214 s = 19.407% includes overlapping witness 32.584/load 35.798 s. Inclusive
proving 154.427 s includes reload 19.052; serialization unisolated. Fresh check
32.248 s + load 14.507. Steady slope/full startup/prefill/drain unknown; trained-
shape privacy acceptance open. Free deletion of direct H phases 21.568 s
bounds only those phases to 1.127x before added costs.

Owner whole-prover kernel design and resident workload slopes stay first.
Six LIVE primary records added, including SP1 ordering, EPFL/Jolt factoring,
sumcheck references and newly assessed Orion's corrected composition boundary.
[Dated report: clocks, sources, rankings, limits](progress/20261017T232105Z-d713e393.md).
New target proofs/passes/positions **0/0/0**. No resident repeats, long prefill or
decode. ≥50/s private 8B on a named high-end GPU unchanged/unachieved.
Production/runtime/Git untouched. Saved reports do not establish delivery.
