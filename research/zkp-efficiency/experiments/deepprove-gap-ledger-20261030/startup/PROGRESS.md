# ZKP efficiency progress

Cycle 0171 complete — 20261030T194123Z-776cb104.

**No measured proving improvement.** The current R14 DD algebra projection
passed 48 synthetic fixtures, including all three score limbs and six lookups.
Each evaluator matched 840 round values, 9,504 intermediate folded values and
864 ordered finals against an independent reference. All ten negative controls
fired. The first mask control missed a distinguishing case; that failure is
retained and corrected. The independent local audit passed 11,337 checks.

At public T128-sized dimensions, grouping removes 28.78% of counted expanded
field products, or 18.78% with all recovery disabled by zero factors. These are
arithmetic counts, not speed measurements. Small cases can regress. The saved
Rust diff is uncompiled and unapplied; native setup and enclosing costs remain
unknown. Main experiment: 5.461 s / 24,592 KiB; audit: 5.263 s / 20,364 KiB,
one low-priority CPU thread.

New independently verified full-stack proofs / model passes / proved positions:
**0 / 0 / 0**. Model context: **none**; passes: **0**. Device: Intel Core Ultra 9
185H, one CPU affinity; no GPU. Witness, proof, serialization, verification,
startup and initial-prefill clocks, startup fraction, proof latency/bytes and
both steady-state and total-workload token rates: **unmeasured**. No prefill,
resident-model proof series or decode ran. The private 8B / 50 proved-token/s
high-end GPU target remains unachieved. Larger workloads remain allowed;
attention can grow quadratically. No mask or private-opening reuse.

Eight LIVE primary-source records were added, including current sumcheck work,
recent October revisions and newly assessed older FFT planning. The native NTT
already uses two passes and fused gather; no extra pass deletion is established.
The queue retains verified GPU resident workloads, admitted context/fidelity
scaling and exclusive native clocks as its top three priorities.

Next local: test the source-derived CFS masking and extension wrapper on
synthetic data. Next owner: review the diff, run native masked-byte, randomness,
transcript, refusal and opening checks, then measure exclusive phase times under
the shared locks. Main/Claude owns integration.

[Experiment](experiments/accuracy-dd-groups-20261030/README.md) ·
[Handoff](handoffs/20261030-accuracy-dd-groups.md) ·
[Dated report](progress/20261030T194123Z-776cb104.md).
Saved reports do not establish message delivery.
