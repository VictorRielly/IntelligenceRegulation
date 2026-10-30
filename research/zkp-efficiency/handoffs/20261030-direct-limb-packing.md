# Review handoff: direct Fp2 limb packing

Run `20261030T064123Z-6637fd3d`; checkpoint 2026-10-30T06:52:49.356272+00:00. No measured proving improvement.

Replace the per-rho temporary `as_u64s_f2` Vec in
`hashline/src/gpu/cuda.rs::dev_fold_rows` with explicit c0.0/c1.0 writes into
the existing reserved flat destination. Interface, assertion placement,
call-local lifetime and upload bytes are unchanged. Fp2 lacks repr(C);
never upload/cast raw Fp2 bytes. No production source was edited or merged.

Patch: `../experiments/direct-limb-packing-20261030/direct-pack-review-only.patch`.
Prototype and evidence: `native_pack.rs`, `packing.rs`, `source-pins.json`,
`result.json` in that experiment. 168Rust packing fixtures/458160limbs,
120native scalar-fold cases,40Python references/1600bigint output limbs,
11Rust and5Python negative-control families,49checked length cases.
Nonempty k=4 allocation requests5→1;rows3517 requested peak281360→225088B.
Instrumented optimized1.75CPU helper only; custom allocator makes calls
observable. The current production compiler and GPU were not evaluated.

Removed: temporary allocations and logical temporary writes/reads/copies.
Added: direct stores and existing push checks. No payload,launch,fold,
arithmetic,synchronization,proof-byte or fresh randomness saving. Conditional
historical A57 opening:72→15 host pack allocations,not a full8B result.
Ceiling N/(T-C_pack_exclusive+A_added),exclusive fractionunknown. Falsify on
negligible packing,compiler elision,net regression or any byte/order/refusal/
receipt/privacy mismatch. Do not promote solely from allocation counts.

Required owner validation: source-matched native CPU/GPU/forced-chunked
receipt-byte gates,extension/order/pad/proximity/fresh-call controls,
initialization/poison/shape/error/refusal ordering,actual current group/host
capacity census and exclusive packing/allocation/init/mutex-wait/hold/H2D/
kernel/D2H/conversion clocks in a complete independently verified workload.
secs_fold begins after gpu initialization and mutex acquisition; do not
interpret it as full call latency. No outside-mutex move is proposed without
measured contention and capacity/refusal review. Use shared heavy/build locks
and current guard for any owner native/GPU work; none launched here.

New independently verified full-stack proofs / passes / positions: **0 / 0 / 0**.
Actual model context: none; only conditional historical cost accounting uses T128.
Device: one affinity-pinned Intel Core Ultra 9 185H CPU worker; no accelerator.
Witness, proof, serialization, verification, startup and initial-prefill clocks,
startup fraction, proof latency/bytes, steady-state and total-workload
proved-token rates: **unmeasured**. No long-context prefill, resident-model pass
series or decode ran. Larger workloads remain allowed; longer dense attention
can grow quadratically. Complete private 8B **>=50 proved tokens/s remains
unachieved**.

Main/Claude owns review/integration. Further packing/staging variants stay
parked until native costs warrant them. Full report:
`../progress/20261030T064123Z-6637fd3d.md`.
