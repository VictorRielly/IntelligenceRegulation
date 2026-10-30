# ZKP efficiency progress

Cycle 0149 complete — `20261029T185649Z-81a2bde2`, October 29, 2026.

**No native proving improvement measured.** Frozen R13 8B/T128 H source
support permits 33–34% fewer logical matrix reads with the prior zero-skip
candidate. A conditional packing optimum increases that bound to 57–58%.
GPU traffic, device time and whole-proof gains remain unknown. Corner
challenges can merge groups and remove the read-saving opportunity.

20 Rust fixtures passed: 539,532 independent coefficients, 1,683
message-plus-pad folds and 1,683 restored-order values. Five control
classes ran 90 times; 175 independent offset/union/packing checks passed.
Failures and prior negative findings are retained. Seven LIVE source
records were added; 68 prior hypotheses were preserved and two added.

Next: owner current public-support counters and exclusive phase clocks;
local derivation of A's overlapping support. Main/Claude reviews integration.

New independently verified full-stack proofs / passes / positions:
**0 / 0 / 0**. Actual context and accelerator: none; modeled T128.
Device: one pinned Intel Core Ultra 9 185H CPU worker. Witness, proof,
serialization, verification, startup/prefill duration and fraction,
proof latency/bytes, steady-state and total-workload rates: **unmeasured**.
No prefill, resident-model series or decode ran. Larger workloads remain
allowed; dense attention can grow quadratically. Complete private8B
**>=50 proved tokens/s remains unachieved**.

[Experiment](experiments/h-structural-support-20261029/README.md) ·
[Handoff](handoffs/20261029-h-structural-support.md) ·
[Dated report](progress/20261029T185649Z-81a2bde2.md).
Saved reports do not establish delivery or supervisor liveness.
