# ZKP efficiency progress

Cycle 0152 complete — `20261029T215649Z-4ef3ea52`, October 29, 2026.

**No native proving speedup measured.** The CPU interval/list/dense fold
experiment passed 184,770 exact comparisons and 462 controls. At frozen R13
8B/T128 geometry, metadata falls from 38.6/37.3 KB to 584/648 B, and logical
operands fall another 13.95/13.84% versus indexed folds. Physical traffic
and GPU time remain unknown; R14 differs. Removing more numerical zeros
fragments intervals, so metadata size alone is a poor objective. Six LIVE
source records were added; 74 hypotheses were preserved and two added.

Next: the owner measures exclusive fold and enclosing clocks and rechecks
R14 geometry. If still useful, the next local experiment tests coalescing
intervals across public zero gaps. Main/Claude reviews the tested prototype
and uncompiled CUDA sketch.

New independently verified full-stack proofs / passes / positions: **0 / 0 / 0**.
Actual context and accelerator: **none**; modeled context T128; one pinned
Intel Core Ultra 9 185H CPU worker. Witness, proof, serialization,
verification, startup/initial-prefill duration and fraction, proof
latency/bytes, steady-state and total-workload rates: **unmeasured**.
No long-context prefill, resident-model series or decode ran. Larger workloads
remain allowed; attention can grow quadratically with context. Complete
private 8B **>=50 proved tokens/s remains unachieved**.

[Experiment](experiments/public-interval-fold-20261029/README.md) ·
[Handoff](handoffs/20261029-public-interval-fold.md) ·
[Dated report](progress/20261029T215649Z-4ef3ea52.md).
Saved reports do not establish delivery or supervisor liveness.
