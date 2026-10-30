# ZKP efficiency progress

Cycle0172 complete — 20261030T204123Z-0f14d260.

**No measured proving improvement.** The new DeepProve gap study rules out
Merkle-path repetition as the main cause of our large receipts. Source
accounting puts all authentication paths at **13.66 MB, 1.61%** of the current
848.41 MB classifier receipt. Synthetic path sharing saves **0.74%** of the
whole receipt. Even deleting every path would shrink it only 1.016 times;
this is a size bound, not a wall-time speedup estimate.

The isolated codec restores every original path, ordered query occurrence,
column and salt in 50 synthetic cases; 12,800 independent synthetic root
checks and ten negative controls pass. A separately authored local audit
passes 7,291 checks. Main: 0.469 s /40,844 KiB; audit: 0.217 s /29,368 KiB.
SHA256 is a synthetic tree oracle, not native BLAKE3/PCS verification.

New independently verified full-stack proofs / complete-model passes /
proved positions: **0 / 0 / 0**. Actual model context: **none**; passes: **0**.
Device: Intel Core Ultra 9 185H, one low-priority CPU affinity, **no GPU**.
Witness, proof, serialization, verification, startup and initial-prefill
clocks, startup fraction, proof latency/bytes and both steady-state and
total-workload proved-token rates: **unmeasured**. No long-context prefill,
resident-model proof series or decode ran. The complete private 8B / >=50
proved-token/s RTX 5090 or named high-end-GPU target remains unachieved.
Larger workloads remain allowed; attention can grow quadratically. No mask,
pad or private-opening reuse or weaker privacy is proposed.

Ten LIVE primary-source records were added. DeepProve's backward chaining
without activation commitments is the more substantial architectural lead;
its private-IO transfer, exact arithmetic and native phase savings remain
unknown. Its paper PDF returned403. Attestable's alpha H100 claims are a
comparison, with no public implementation reproduced. The owner R18
one-load batch already saves about2.4%; that does not remove recurring proof
work or establish an8B GPU rate.

Closing update: the coordinator's gap study arrived and was read. Next is a
small streamed, masked-LogUp-GKR prerequisite against H helpers; retain all
old root-disclosure, binding and memory negatives. Its projected savings
remain models. D53's GPU-classifier lane belongs to Claude; no duplicate
job was launched. Main/Claude owns review and integration. No Rust patch.

[Experiment](experiments/deepprove-gap-ledger-20261030/README.md) ·
[Gap analysis](experiments/deepprove-gap-ledger-20261030/GAP_ANALYSIS.md) ·
[Handoff](handoffs/20261030-deepprove-gap-path-ceiling.md) ·
[Dated report](progress/20261030T204123Z-0f14d260.md).
Saved reports do not establish message delivery.
