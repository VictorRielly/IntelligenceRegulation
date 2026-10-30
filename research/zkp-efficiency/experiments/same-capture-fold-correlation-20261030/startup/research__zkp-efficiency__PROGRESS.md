# ZKP efficiency progress

Cycle 0159 complete — `20261030T074123Z-71d2f333`, October 30, 2026 UTC.
Checkpoint 2026-10-30T07:55:01.314464+00:00.

**No measured proving improvement.** The exact native fold function was tested
with synthetic Rust device/clock bindings: 326 cases pass, including 216 injected
errors/panics. Independent Python references check 2,934 clock/payload fields and
2,154 bigint output limbs; 8 corruption controls reject. Six explicit Rust fixtures
show a 32 tick simulated packing reduction saving either 0 or 32 ticks depending on
prior queued work. Arbitrary ticks are not physical latency or proof gains.

The fold counter starts after initialization/mutex/clone and samples before
conversion/drop; errors skip aggregation. It includes STATS wait and copy
wrapper stream waits. No native measurement magnitude is known. A measurement
handoff targets `hashline/src/gpu/cuda.rs::dev_fold_rows`; no production patch.

Six LIVE primary records cover CUDA/Nsight, a newly assessed attribution paper,
cudarc, StateSync 1.2.1 and ICICLE. Dates, licenses and commit/fetch limits saved.
All 88 prior hypotheses preserved; 89 tests 88 and 90 adds correlation controls.

New independently verified full-stack proofs / passes / positions: **0 / 0 / 0**.
Actual model context: **none**; synthetic row-fold shapes use rows 0/1/3/7,
n 1/2/4/8 and k 1..4, plus malformed k 0/5. These are not model contexts.
Device: one affinity-pinned Intel Core Ultra 9 185H CPU worker; no GPU.
Witness / proof / serialization / verification / startup / initial-prefill
clocks, startup fraction, proof latency/bytes, steady-state and total-workload
proved-token rates: **unmeasured**. No long-context prefill, resident-model
proof passes or decode ran. Larger workloads remain allowed; context growth
can raise dense attention work quadratically. Complete private 8B **>=50
proved tokens/s remains unachieved**.

Next: owner measures complete verified high-end GPU workloads and fixed-context
resident 1/2/4/8 passes, with current admitted profile, exclusive phases, actual
capacity and startup/drain. For this seam, measure GPU initialization, mutex wait/hold,
packing, allocation, H2D, kernel, D2H, STATS wait, conversion, drop submission and
actual retirement. Reconcile with an enclosing independently verified workload;
do not insert synchronizations just to separate timers. If owner traces are
absent next cycle, test a values-free same-capture correlation adapter with
equal-count shuffled-role and missing/duplicate-ID controls (hypothesis 90).
No more packing/staging variants without measured materiality.

[Experiment](experiments/fold-timer-attribution-20261030/README.md) ·
[Handoff](handoffs/20261030-fold-timer-attribution.md) ·
[Dated report](progress/20261030T074123Z-71d2f333.md).
Saved reports do not establish user delivery or supervisor liveness.
