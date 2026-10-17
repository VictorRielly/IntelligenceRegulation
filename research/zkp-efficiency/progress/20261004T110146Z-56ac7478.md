# ZKP efficiency progress

Cycle 0029 — `20261004T110146Z-56ac7478`, checkpoint 2026-10-04T11:20:00.819612+00:00.

72 synthetic window schedules over 24 fixtures passed: 1,485 degree samples, 297 independent original-cube samples, 1,548 final values, 360 independently checked cost counters and 14 controls. Added symbolic-equality-only evaluation passed 495 degree samples and 516 final values. Final run 5.502258 s / 19,792 KiB RSS, seed 2026100429, one pinned low-priority Core Ultra 9 185H thread; 59 s wall/CPU and 512 MiB address-space caps.

**No proving speed improvement measured.** Full reconstruction is demoted because it repeatedly scans sources and adds field multiplications. A smaller candidate keeps normal data-table folds and represents three equality tables symbolically; this removes their allocations without extra source scans. The counted 384 MiB saving at an illustrative n23 cube is not a measured model peak or GPU gain. Native integration/masking/receipt and phase clocks remain outstanding. [Experiment](experiments/sc-szc-reconstruction-windows-20261004/README.md) · [Owner handoff](handoffs/20261004-sc-szc-symbolic-equality.md).

LIVE search checked product-sumcheck tradeoffs, older Blendy, Scribe's July revision/August2026 proceedings, EPFL/Jolt implementations/releases and hardware locality. Seven qualified primary records saved, with date/license/commit/fetch limits. No author performance reproduced.

Accepted independently verified complete private 8B proofs/passes: 0; countable tokens: 0. Device: CPU only; proof context: null; passes: 0. Steady-state and total-workload rates, startup fraction/duration, witness/proof/serialization/independent-verification clocks and latency/lag/drain are unmeasured. No long-context prefill, resident-model pass or decode proof occurred. >=50 proved tokens/s remains unachieved. Larger workloads remain permitted; attention work grows quadratically with context, and all coverage, fresh masks and decided privacy obligations remain.

Next local action: tagged index-preserving symbolic Eq and native-source reader oracle. Owner first isolates table allocation/fold and recurring witness/down/SC_SZC clocks, then native/device independently verified complete-stack A/B under shared locks. No heavy job queued. Saved reports are local artifacts, not evidence of external message delivery.
