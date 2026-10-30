# ZKP efficiency progress

Cycle 0148 complete — `20261029T175649Z-b41890ba`, October 29, 2026.

**No native proving improvement measured.** The frozen R13 mask audit
establishes zero public weights at unrelated claim-mask rows. The prior
skip candidate could avoid at least 4.18% / 4.39% of logical A/H matrix
reads in the inspected 8B/T128 noDD / DD geometry. These are conservative
work bounds; actual GPU traffic and proving benefit remain unknown.

81 Rust differential fixtures and three H-sum fixtures passed. They checked
405,216 independent coefficients and 5,049 message-plus-pad values; seven
audit mutations refused. Mask-count-only packing was rejected: a synthetic
counterexample increased actual row visits by 19% despite a better bound.

Six LIVE source records were added. All 66 prior hypotheses were preserved
and two added. Next: exact public part-offset/domain support, then owner
support/union counters and exclusive phase clocks before GPU integration.

New independently verified full-stack proofs / passes / proved positions:
**0 / 0 / 0**. Actual context and accelerator: **none**. Device: one pinned
Intel Core Ultra 9 185H CPU worker. Witness, proof, serialization,
verification, startup/prefill duration and fraction, proof latency/bytes,
steady-state and total-workload rates: **unmeasured**. No prefill,
resident-model proof series or decode ran. Larger workloads remain allowed;
dense attention can grow quadratically. The complete private 8B
**>=50 proved tokens/s target remains unachieved**.

[Experiment](experiments/public-row-support-20261029/README.md) ·
[Handoff](handoffs/20261029-public-mask-row-bound.md) ·
[Dated report](progress/20261029T175649Z-b41890ba.md).
Saved reports do not establish message delivery or supervisor liveness.
