# ZKP efficiency progress

Cycle 0130 complete — `20261028T235649Z-d1bc0725`, 2026-10-28/29 UTC.

**No proving speedup measured.** The stock Tensor Core NTT driver selects a
<=62-bit reducer, so it cannot replace the native Goldilocks NTT. A general
multiplier helper works in isolation; replacing it alone still fails the
unsupported lazy butterfly. Canonical dot16 inputs need 132 bits, so dropping
top carries also fails. These are porting negatives, not upstream defects.

A new carry-aware reducer contract and matrix scaling/order bridge pass
**39,179 synthetic checks**, including 12,441 products, 18 radix2
fixtures, 35 dot16 fixtures, four matrix16 fixtures and 54 controls. Checking
took 0.093988 s / 15,608 KiB RSS on one Core Ultra 9
185H CPU thread. The CUDA sketch is uncompiled/unapplied. No GPU or native
proof ran. Separate source/provenance audit: 774 checks, seven native
pins unchanged. No native transcript, PCS, receipt or privacy acceptance.

Nine primary-source records appended (849 total); all 44 prior hypotheses
retained, two refined and two added. Current releases, the new Tensor NTT
source and older Montgomery arithmetic were screened; fetch limits retained.

New independently verified full-stack proofs / passes / positions: **0 / 0 / 0**.
Actual model context / accelerator: **none**. Witness, proof, serialization,
verification, startup/initial-prefill clocks, startup fraction, proof latency
and bytes, steady-state and total-workload rates: **unmeasured**. No long
prefill, resident-model proof series or decode ran. Larger workloads remain
allowed; attention can grow quadratically. Private 8B at >=50 proved tokens/s
on RTX 5090 or a named high-end GPU remains unachieved.

Next owner action: exclusive NTT/enclosing clocks before a native adapter and
its full gates, then verified resident workloads. Next local action: inspect
R12b's recurring public checkpoint/table validation and test an immutable,
fully parameter-bound public derivation against mutation controls. Owner's
17–18 s/load note is Shieldstral3B; it is not an 8B timing. No heavy job queued.

[Experiment](experiments/goldilocks-tc-contract-20261028/README.md) ·
[Handoff](handoffs/20261028-goldilocks-tc-contract.md) ·
[Dated report](progress/20261028T235649Z-d1bc0725.md).
Research outside runtime only; main/Claude reviews/integrates, no merge.
Saved reports do not establish delivery or supervisor liveness.

Checkpoint UTC: 2026-10-29T00:13:21.141827+00:00.

Final evidence audit: 272 checks PASS; 66 immutable artifacts, seven native pins and six required project documents unchanged. All840 prior sources,44 prior hypotheses and prior findings retained. Final checkpoint UTC: 2026-10-29T00:14:29.651392+00:00.
