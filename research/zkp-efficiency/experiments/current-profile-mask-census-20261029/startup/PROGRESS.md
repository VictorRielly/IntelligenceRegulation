# ZKP efficiency progress

Cycle 0141 complete — `20261029T105649Z-8532a02d`, 2026-10-29T11:11:55.162185+00:00.

**No native proving speedup measured.** Prepared public coefficient sums pass
an exact compiled comparison against the original mask evaluator. They remove
repeated additions but add allocation and memory accesses. One- and two-pair
timing diagnostics regress at width 16,384; higher reuse shows small differences
on the shared box. Unconditional eager preparation is parked.

Validation: 792 fixtures, 3,168 terminal comparisons, 9,216 direct-Eq values
and ten negative controls pass. Harness: 0.199780 s / 8,684 KiB RSS. An
independent source/count audit passes 91 checks across eight source pins.
The older T128 census saves 1.94 million additions but adds 31.4 MB of logical
source accesses per block and up to 128 KiB of live sums per active context.
These are counts, not native traffic, phase clocks or current LOW+h24 incidence.

Eight LIVE primary source records appended; 60 ranked hypotheses retained.
Sources include StateSync's October releases, Akita's public-factor grouping
and older finite-field dot/packing techniques. Native receipt/privacy gates
remain owed. Next: exclusive native Eq/dot/extension clocks and actual R13
LOW+h24/DD site incidence. Whole-prover high-end-GPU and verified resident
1/2/4/8-pass workloads remain first.

New independently verified full-stack proofs / model passes / proved positions: **0 / 0 / 0**.
Model context and accelerator: **none**; one pinned Intel Core Ultra 9 185H CPU
worker ran the research component. Witness, proof, serialization, verification,
startup and initial-prefill durations, startup fraction, proof latency/bytes,
steady-state throughput and total-workload throughput: **unmeasured**.
No long-context prefill, resident-model proof series or decode ran. Larger
workloads remain allowed; increasing dense-attention context can increase work
quadratically. The complete private 8B >=50 proved-token/s target on an RTX
5090 or another named high-end GPU remains unachieved.

[Experiment](experiments/public-mask-component-sums-20261029/README.md) ·
[Handoff](handoffs/20261029-public-mask-component-sums.md) ·
[Dated report](progress/20261029T105649Z-8532a02d.md).
Saved reports do not imply message delivery or supervisor liveness.
