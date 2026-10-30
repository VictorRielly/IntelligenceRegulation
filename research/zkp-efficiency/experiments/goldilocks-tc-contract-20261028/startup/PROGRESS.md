# ZKP efficiency progress

Cycle 0129 complete — `20261028T225649Z-6db80b72`, 2026-10-28 UTC.

**No proving speedup measured.** The periodic public-table candidate passed
817 synthetic checks across six SC_TAB fixtures, 60 rounds and 36 private
claims. Its 57 negative-control instances detect altered messages, inconsistent
witnesses and shortened masks. A separate source audit passed 83 checks;
all nine native source pins are unchanged.

The useful negative result: repeating public rows does not allow a smaller
full-slot CFS mask. At R12 T128 the candidate still needs all 47 mask
coefficients, six private claims and the full cube. Its earlier public-only
payload and fold reductions remain source counts, with no measured native
speed or peak-memory saving.

Checking took 6.527 seconds and 21,588 KiB peak RSS on one Intel Core Ultra 9
185H CPU worker. No GPU or native build ran. The domain, prelude, keys and
mask-row geometry are synthetic; native RNG, committed openings, receipts,
refusal and privacy gates remain outstanding.

Primary-source searches covered CFS/Libra, current Plonky3, GPU-NTT/ICICLE,
Tensor Core NTT and quantization. Ten qualified records were appended
(840 total). The new NTT lead's friendly path caps moduli at 62 bits; its
general 64-bit path still needs review. Fetch blockers are recorded.
All 42 prior hypotheses remain; one was refined and two were added.

New independently verified full-stack proofs / passes / positions: **0 / 0 / 0**.
Model context and accelerator: **none**. Steady-state and total-workload
rates, startup fraction, witness/proof/serialization/verification clocks,
initial prefill, proof latency and proof bytes: **unmeasured**. No long-context
prefill, resident proof series or decode ran. Larger workloads remain allowed;
attention can grow quadratically. The private 8B / >=50 proved-token/s target
remains unachieved.

Next local action: inspect the NTT lead's general 64-bit contract, then test
Goldilocks carry/reduction behavior against Python big integers. Next owner
action: measure exclusive public construction/folding and enclosing proofs
before considering integration. No heavy job was queued.

[Experiment](experiments/sc-tab-mask-conformance-20261028/README.md) ·
[Handoff](handoffs/20261028-sc-tab-mask-conformance.md) ·
[Dated report](progress/20261028T225649Z-6db80b72.md).
Only research outside runtime was written. Saved reports do not establish
message delivery or supervisor liveness.

Checkpoint UTC: 2026-10-28T23:10:19.857648+00:00.

Final evidence audit: 742 checks PASS, 69 immutable artifacts, nine native pins unchanged; all 830 prior sources and 42 hypotheses preserved. Supplemental final read checks also confirm the five required project documents and all nine prior-cycle native pins unchanged. Final checkpoint UTC: 2026-10-28T23:11:59.118540+00:00.
