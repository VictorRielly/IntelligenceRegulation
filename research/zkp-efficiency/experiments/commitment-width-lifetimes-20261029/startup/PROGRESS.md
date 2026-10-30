# ZKP efficiency progress

Cycle 0139 complete — `20261029T085649Z-193029f7`, 2026-10-29 UTC.

**No native proving improvement measured.** The synthetic model shares storage
for exact repeated R13 lookup expressions while retaining every logical
occurrence, helper pair and fresh-mask schedule. For representative 8B T128
parameters, looked-column payload falls from 490.25 to 481.25 MiB without DD,
or 463.25 to 460.25 MiB with DD. These are logical per-block counts, not
measured peak memory, physical traffic or runtime savings.

Validation: 11,874 checks, 1,872 synthetic fixtures,
104 helper cases and 14 controls pass; 0.426626 s,
18,864 KiB RSS. The separate source/accounting audit passes
237 checks, including four mutations and 12 source pins. No native
Rust, proof or GPU job ran. Eight primary source records were appended. All
57 prior hypotheses remain; 25 and 35 were refined, and 58 was added.

The remaining questions are actual per-layer alias incidence and exclusive
preparation, histogram, helper and enclosing clocks. Container ownership and
indexed reads add costs. Commitments and proof data do not shrink in this
model; native refusal, RNG, transcript, PCS, receipt and privacy gates remain.

Next: measure the admitted catalog and exclusive clocks before deciding on a
native container A/B under shared locks. Complete-prover GPU measurements and
independently verified resident-model workloads remain the first priority.
The next local rotation checks R13 widths and lifetimes against the owner's
split-width design before proposing another memory experiment.

New independently verified full-stack proofs / passes / positions: **0 / 0 / 0**.
Actual model context and accelerator: none; research used one Core Ultra 9 CPU
thread. Witness, proof, serialization, verification, startup and initial-prefill
clocks, startup fraction, proof latency/bytes, steady-state and total-workload
rates: **unmeasured**. No long prefill, resident-model proof series or decode
ran. Larger workloads remain allowed; longer attention can grow quadratically.
The complete private 8B >=50 proved-token/s target remains unachieved.

[Experiment](experiments/lookup-public-incidence-20261029/README.md) ·
[Handoff](handoffs/20261029-r13-lookup-column-views.md) ·
[Dated report](progress/20261029T085649Z-193029f7.md). Checkpoint: 2026-10-29T09:12:05.812753+00:00.
Saved reports do not imply message delivery or supervisor liveness.
