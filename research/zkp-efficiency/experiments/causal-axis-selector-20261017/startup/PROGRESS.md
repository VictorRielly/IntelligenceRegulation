# ZKP efficiency progress

Cycle0057 — `20261017T072624Z-c38c878c`, completed2026-10-17 UTC.

**No native speed improvement established.** An immutable captured-index adapter now feeds the fixed round0 softmax helper directly in Python. It passes120 synthetic layouts,2,304 helper sample checks,1,440 independent scalar group checks and480 full-polynomial comparisons. The source/index audit passes13,047 checks. Final experiment: 4.94s,27,108KiB RSS,one nice19 CPU thread. Rust remains uncompiled; actual native captures/transcripts/proofs were not tested.

Two mistaken negative-control expectations are retained and corrected: omitting a referenced limb causes a metadata refusal, while swapping denominators inside one LogUp pair preserves the symmetric relation. There is no new field-operation saving; native speed remains unknown.

The seam is SC_SZC in argument.rs and the grouped cur/dif/sample loop. Next local check derives the constant-mask selector from native public axes and extension metadata. Owner next: real-capture differential fixtures and guarded literal/unscheduled/scheduled profiling, then complete resident workloads with both witnesses and all clocks. See [experiment](experiments/native-capture-adapter-20261017/README.md) and [handoff](handoffs/20261017-native-capture-adapter.md).

Four LIVE records appended,292 total: updated zkLLMPoT/zkTransformer scope and older updatable-lookup/composition leads. Fetch/date/license/commit gaps are recorded; no external performance reproduced.

Accepted independently verified complete private 8B proofs/passes/tokens: **0/0/0**. Device: Intel Core Ultra 9 185H CPU only, one thread, nice19, CPU0. Proof context length, steady-state and total-workload rates, startup duration/fraction, witness/proof/serialization/independent-verification clocks and proof latency/lag/drain are **all unmeasured**. No long-context prefill, resident-model pass or decode proof ran. Fixtures use one two-cell affine row, not token contexts. T512 figures below are historical diagnostics or allocation-free accounting. Dense-attention score work grows roughly fourfold when context doubles. Larger workloads remain permitted with fresh masks and complete coverage; the private8B >=50 proved-token/s target remains unachieved.

Production, runtime, Git, calibration, safety gates, instructions and reviewer files were not modified. No GPU job, build, dependency installation, downloaded script execution, external write/message, merge or heavy queue action occurred. Saved reports are not evidence of notification delivery or supervisor liveness. D24 remains proposed; no new privacy/profile ruling is accepted.
