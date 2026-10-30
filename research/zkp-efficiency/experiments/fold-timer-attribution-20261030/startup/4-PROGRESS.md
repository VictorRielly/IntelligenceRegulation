# ZKP efficiency progress

Cycle 0158 complete — `20261030T064123Z-6637fd3d`, October 30, 2026 UTC.
Checkpoint 2026-10-30T06:52:49.356272+00:00.

**No measured proving improvement.** Direct explicit-limb packing passed
168 optimized Rust fixtures and 40 independently authored Python references.
In a nonempty four-vector helper, instrumented allocation requests fall from
five to one. At 3,517 rows, requested packing peak falls from 281,360 to
225,088 bytes; cumulative requested bytes fall from 450,176 to 225,088.
These measure a synthetic CPU host helper, not native GPU or proof performance.

The single-hunk review patch targets
`hashline/src/gpu/cuda.rs::dev_fold_rows`, replacing each temporary Vec with
ordered c0/c1 writes. Transfer payload, kernels, folds, masks and transcript
work are unchanged. Production source was not modified.

Next: owner measurements of exclusive packing, allocation, GPU initialization,
mutex wait/hold, H2D, kernel, D2H, conversion and synchronization, reconciled
with an enclosing independently verified workload. `secs_fold` starts after
GPU initialization and mutex acquisition, so that phase alone misses waits.
Keep actual current groups and capacity in the profile. Park further packing
or staging variants if removable costs are negligible. No lock move is proposed
without contention, capacity and failure-order evidence.

New independently verified full-stack proofs / passes / positions: **0 / 0 / 0**.
Actual model context: none; only conditional historical cost accounting uses T128.
Device: one affinity-pinned Intel Core Ultra 9 185H CPU worker; no accelerator.
Witness, proof, serialization, verification, startup and initial-prefill clocks,
startup fraction, proof latency/bytes, steady-state and total-workload
proved-token rates: **unmeasured**. No long-context prefill, resident-model pass
series or decode ran. Larger workloads remain allowed; longer dense attention
can grow quadratically. Complete private 8B **>=50 proved tokens/s remains
unachieved**.

Four LIVE primary-source records saved (Rust Vec, ICICLE, StateSync-GKR and
zkLLMPoT); source fetch limits recorded. All 86 prior hypothesis records are
preserved; 87 is tested, 88 refines the mutex/timer measurement question.

[Experiment](experiments/direct-limb-packing-20261030/README.md) ·
[Handoff](handoffs/20261030-direct-limb-packing.md) ·
[Dated report](progress/20261030T064123Z-6637fd3d.md).
Saved reports do not establish user delivery or supervisor liveness.
