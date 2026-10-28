# ZKP efficiency progress

Cycle 0117 complete — `20261021T011854Z-d7ab1017` — 2026-10-21 UTC.

**No proving speedup measured.** The fused fold/pack candidate passes 48 synthetic
FZC cases and an independent 55,423-check audit. At the default tail threshold, the
illustrative case removes one kernel launch and 24 KiB of logical traffic. The copy,
synchronization and device arena remain. Larger CPU tails add copy and host work;
no runtime crossover is established. The CUDA sketch is uncompiled and low priority.

New completed, independently verified full-stack proofs / passes / positions: **0 / 0 / 0**.
Actual model context and accelerator: **none**. Research ran on one Intel Core Ultra 9
185H CPU worker. Witness, proof, serialization and verification clocks: **unmeasured**.
Startup duration and fraction, steady-state rate and total-workload rate: **unmeasured**.
No long-context prefill, resident-model proof series or decode ran. Synthetic table
lengths 2–2,048 and modeled cube logs 1–26 are diagnostics, not model context lengths.
Larger workloads remain allowed; increasing context can raise attention work quadratically.
The complete private 8B target of >=50 proved tokens/s remains unachieved.

Next: audit recurring mapped/pinned scratch allocation with sequence/completion
controls. Complete GPU clocks and verified resident 1/2/4/8 workloads remain priorities.
Thirteen LIVE queries and ten source records are retained; 34 ranked hypotheses
preserve earlier negative results.

[Experiment](experiments/fzc-tail-boundary-20261021/README.md),
[dated report](progress/20261021T011854Z-d7ab1017.md),
[handoff](handoffs/20261021-fzc-tail-fold-pack.md). Saved files do not establish delivery.

Evidence integrity: 213 checks PASS; 54 artifact hashes and 11 source pins match. All 727 prior source records, the prior findings prefix and all 31 prior hypotheses are preserved. No concurrent source/document changes observed. Final audit UTC: 2026-10-21T01:35:13.986602+00:00.
