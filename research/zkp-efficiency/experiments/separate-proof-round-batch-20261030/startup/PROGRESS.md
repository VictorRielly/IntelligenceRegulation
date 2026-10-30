# ZKP efficiency progress

Cycle 0161 COMPLETE — `20261030T094123Z-ce04cf1a`, checkpoint 2026-10-30T09:55:42.646672+00:00.

**No measured proving improvement.** The bounded slot census passes:
401 metadata geometries, 802 Rust/reference rows, 72,800 numeric comparisons and
48 controls. At R13 8B/T128 all 24 equal-shape slot pairs remain transcript-ordered.
Simple same-proof merging is parked; separate-proof batching remains a
different hypothesis requiring distinct transcripts/masks and actual clocks.

New independently verified full-stack proofs / passes / proved positions: **0 / 0 / 0**.
Actual model context: **none**. Device: one affinity-pinned Intel Core Ultra 9
185H CPU worker; **no GPU**. Witness / proof / serialization / verification /
startup / initial-prefill clocks, startup fraction, proof latency/bytes,
steady-state and total-workload proved-token rates: **unmeasured**.
No long-context prefill, resident-model proof passes or decode ran. Metadata
contexts 17/32/64/127/128/256/512 are synthetic/public geometry, not model runs.
Larger workloads remain allowed; increased context can raise dense-attention
work quadratically. The complete private 8B **>=50 proved tokens/s target
remains unachieved**.

Owner priority: complete independently verified high-end GPU workloads at
fixed context with resident 1/2/4/8 passes, startup/drain, exclusive phases,
actual capacity and all failure/exclusion accounting. Local next experiment,
if those clocks remain unavailable: two/four independent synthetic Fp2 round
evaluators with separate transcript/challenge/site ownership, differential
scalar reference and swapped-proof/early-reuse controls. Existing
`cuda.rs::dev_zerocheck_blocks` takes one transcript; `nb` is no multi-proof
API. No GPU/native build is proposed without owner locks and materiality.

[Experiment](experiments/slot-batching-census-20261030/README.md) · [Integration boundary](experiments/slot-batching-census-20261030/INTEGRATION.md) · [Dated report](progress/20261030T094123Z-ce04cf1a.md).

Saved reports do not establish delivery or job liveness.
