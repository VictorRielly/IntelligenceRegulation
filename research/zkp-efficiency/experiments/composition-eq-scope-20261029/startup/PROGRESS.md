# ZKP efficiency progress

Cycle0145 complete — `20261029T145649Z-fb1b89ab`, October29,2026.

**No native proving improvement measured.** An exact fresh Eq rewrite halves
its source-level extension products, adding subtractions. It passes234 Eq
fixtures,14,094 independent weights,198 MLE checks,600 private-table cases,
600 fresh-mask cases and8controls. The serial CPU helper improves1.257..1.744x
on nonempty diagnostic sizes; this is not a native/GPU or whole-proof gain.

Source accounting demotes fixed Eq: only2165 products removed per modeled
8B T128 block. Fresh mask Eq removes2.88–3.00million; its exclusive native
time is unknown. All private reads, allocations, masks and proof work remain.
Conditional handoff and unapplied patch saved; owner profiling comes first.
Probe0.541s /20.6MiB; provenance/count audit566checks,14pins passes.
Seven LIVE source records include older HyperPlonk and the October Longfellow
draft; blocked primary/license fetches are retained. Prior61 hypotheses remain;
62 added. Next: exclusive Eq/enclosing clocks, or a proof-composition call-graph
audit that distinguishes repeated public preparation from fresh mask work.

New independently verified full-stack proofs / completed model passes / proved
positions: **0 / 0 / 0**. Actual model context / accelerator: **none**. Research
device: one pinned Intel Core Ultra 9 185H CPU worker, no GPU. Witness, proof,
serialization, verification, startup and initial-prefill clocks, startup
fraction, proof latency/bytes, steady-state and total-workload token rates:
**unmeasured**. No long-context prefill, resident-model proof series or decode
ran. Synthetic helper dimensions are not model contexts or completed passes.
Larger workloads remain permitted; dense attention can grow quadratically
with context. Complete private 8B >=50 proved tokens/s on an RTX 5090 or
another named high-end GPU remains **unachieved**.

[Experiment](experiments/fresh-eq-doubling-20261029/README.md) ·
[Dated report](progress/20261029T145649Z-fb1b89ab.md) ·
[Conditional handoff](handoffs/20261029-fresh-eq-doubling.md).
Saved reports do not imply message delivery or supervisor liveness.
