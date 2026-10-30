# ZKP efficiency progress

Cycle0140 complete — `20261029T095649Z-50135f2e`, 2026-10-29T10:10:51.585056+00:00.

**No native proving speedup measured.** A compiled local CPU encoder candidate
uses its final output prefix for coefficient scratch. It removes one allocation
per row while preserving all encoded values. At width16,384 this avoids128KiB
of live coefficient payload per active worker, or2MiB for16 workers. The encoded
matrix and NTT work remain. The accepted CUDA route has zero direct incidence.

Validation:168fixtures /606rows /360,882encoded values agree;29,106values
have an independent direct-DFT reference. Five serial matrices, ten refusals
and ten negative controls pass. Harness0.104446s /8,352KiB RSS. A74-check
source/patch/cost audit passes. Full native Rayon, safety, RNG/transcript/PCS,
receipt and privacy gates remain owed. One CPU; no GPU or large build.

Eight primary source records appended;59hypotheses retained. Owner next:
exclusive CPU allocator/encoding and enclosing clocks before deciding whether
native integration is useful. Whole-prover high-end GPU and verified resident
workloads remain first. Next local: fresh public component sums for mask dots.

New independently verified full-stack proofs / model passes / proved positions: **0 / 0 / 0**.
Actual model context and accelerator: **none**; research used one pinned
Intel Core Ultra 9 185H CPU worker. Witness, proof, serialization, verification,
startup and initial-prefill clocks, startup fraction, proof latency/bytes,
steady-state and total-workload rates: **unmeasured**. No long-context prefill,
resident-model proof series or decode ran. Larger workloads remain allowed;
longer dense attention may grow quadratically. The complete private 8B
>=50 proved-token/s target on an RTX 5090 or another named high-end GPU remains
unachieved.

[Experiment](experiments/commitment-width-lifetimes-20261029/README.md) ·
[Handoff](handoffs/20261029-cpu-encode-prefix-scratch.md) ·
[Dated report](progress/20261029T095649Z-50135f2e.md).
Saved reports do not imply message delivery or supervisor liveness.
