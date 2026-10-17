# ZKP efficiency progress

Cycle0030 — `20261004T120146Z-d7433b90`, checkpoint 2026-10-04T12:19:53.569647+00:00.

40 mixed-table fixtures and 41 exhaustive equality-span fixtures passed: 1,128 source-map words, 1,128 independent original-cube degree samples (528 mixed + 600 spans), 363 direct-MLE final values, 240 synthetic extension samples, 120 count checks and 19 controls. Final run 7.695833 s / 17,212 KiB RSS, seed 2026100430, one pinned low-priority Core Ultra 9 185H thread; 59 s wall/CPU and 512 MiB address-space caps.

**No proving speed improvement measured.** Tagged symbolic equality storage preserves original indices/finals and passes the expanded independent oracle. It could remove three dense equality allocations; the illustrative n23 count is384MiB, with native peak/time still unknown. The full data tables and original source owners stay. A separate four-sample negative confirms naive product-table collapse changes a cubic round; this filters tensor-core transfers and makes no claim of a paper defect. [Experiment](experiments/sc-szc-tagged-equality-20261004/README.md) · [Owner handoff](handoffs/20261004-sc-szc-tagged-equality.md).

Six LIVE primary records cover original/2026 sumcheck literature, Jolt source/old PR/release/licenses and August2026 TensorZKP proceedings. Remote history/diff fetches failed; source remains without an inspected remote commit pin. Local experiments were unblocked.

Accepted independently verified complete private 8B proofs/passes: 0; countable tokens: 0. Device: CPU only; proof context: null; passes: 0. Steady-state and total-workload rates, startup fraction/duration, witness/proof/serialization/independent-verification clocks and proof latency/lag/drain are unmeasured. No long-context prefill, resident-model pass or decode proof occurred. >=50 proved tokens/s remains unachieved. Larger workloads are permitted; attention grows quadratically with context and fresh masks/full coverage/privacy remain mandatory.

Next: owner measures Eq/data build/fold/capacity plus recurring witness/down/SC_SZC, then native masked/frozen receipt/independent verifier/device A/B under shared locks. Next local check tests two-layer Eq weighting with exact operations and scratch accounting. No heavy job queued. These are local reports, not external notification-delivery records.
