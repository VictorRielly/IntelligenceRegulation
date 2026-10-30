# ZKP efficiency progress

Cycle 0150 complete — `20261029T195649Z-795daf31`, October 29, 2026.

**No native proving improvement measured.** Frozen R13 8B/T128 A support
permits about 79% fewer logical matrix reads with the prior zero-skip
candidate; combined A/H about 69%. Including unchanged rho operands reduces
A's source-level read saving to about 9%, before cache/broadcast effects.
GPU time and whole-proof gains remain unknown. A's supports overlap; H's
partition assumption fails. Optional public packing is a local optimum only.

14 Rust cases passed 27.5 million independent coefficient comparisons,
5,172 synthetic message-plus-pad values, 380 source-row packed values and
62 controls. The independent census passed 517 checks; the helper audit
passed 64. Five LIVE source records were added; 70 prior hypotheses were
preserved and two added. Final checkpoint audit: 145 checks passed.

Next: owner current support counters and exclusive fold/enclosing clocks;
local sorted public row-index differential. Main/Claude reviews integration.

New verified full-stack proofs / passes / positions: **0 / 0 / 0**.
Actual context and accelerator: none; modeled T128. Device: one pinned Intel
Core Ultra 9 185H CPU worker. Witness, proof, serialization, verification,
startup/prefill duration and fraction, proof latency/bytes, steady-state and
total-workload rates: **unmeasured**. No prefill, resident series or decode
ran. Larger workloads remain allowed; attention can grow quadratically.
Complete private 8B **>=50 proved tokens/s remains unachieved**.

[Experiment](experiments/a-overlap-support-20261029/README.md) ·
[Handoff](handoffs/20261029-a-overlap-support.md) ·
[Dated report](progress/20261029T195649Z-795daf31.md).
Saved reports do not establish delivery or supervisor liveness.
