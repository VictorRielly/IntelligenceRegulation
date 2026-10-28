# ZKP efficiency progress

Cycle 0115 complete — `20261020T231854Z-2da27679` — 2026-10-20 UTC.

**No proving speedup measured.** GPU NTT twiddles are already cached. A tested immutable
public coset owner could reduce counted powers uploads from 48.5 to 0.5 MiB per first
T128/L32 pass, and selected deferred public capacity from 2.5 to 0.5 MiB. It retains
0.5 MiB at idle. These are conditional source/synthetic counts; native time and GPU
admission are unknown. Fresh private pads, salts and masks remain per proof.

192 synthetic rows and an independent audit of 92,531 checks / 50,240 capacity events
pass. Six LIVE queries / nine primary records; 29 ranked hypotheses retained.

New completed independently verified full-stack proofs / passes / positions: **0 / 0 / 0**.
Actual model context and accelerator: **none**. Research device: Intel Core Ultra 9 185H CPU, one worker, no GPU.
Witness, proof, serialization and verification clocks: **unmeasured**. Startup duration/fraction,
steady-state and total-workload proved rates: **unmeasured**. No long-context prefill,
resident-model proof series or decode ran. Counted T32/T64/T128, L1/L2/L32,
1/2/4/8-pass schedules and 192 tiny encoded rows are synthetic diagnostics, not proved positions.
Larger workloads remain allowed; attention can grow quadratically with context.
The complete private 8B >=50 proved tokens/s target on RTX 5090 or another named high-end GPU remains unachieved.

Next: count fixed public inverse-size scaling versus per-row work; owner whole-GPU
clocks and independently verified resident 1/2/4/8 workloads remain the priority.
[Experiment](experiments/public-ntt-cache-incidence-20261020/README.md),
[dated report](progress/20261020T231854Z-2da27679.md), [handoff](handoffs/20261020-public-coset-lease.md).
Saved files do not establish external delivery.

Final evidence-integrity audit: 215 checks PASS across 67 experiment pins; prior 709 source records, prior findings prefix and first27 ranked hypotheses preserved; mandatory public documents unchanged. Finished UTC 2026-10-20T23:30:19.144717+00:00.
