# ZKP efficiency progress

Cycle0163 COMPLETE — `20261030T114123Z-38ad9454`, checkpoint 2026-10-30T11:54:17.656204+00:00.

**No measured proving improvement.** A public capacity gate passes216 source
metadata cases,20 small Rust Vec probes,159 admission boundaries and55 controls.
Frozen R13 H24 T128 SC_SZC has28 tables /224MiB payload per proof. Counting
half-length tables as released capacity wrongly admits a second proof and
undercounts112MiB in the synthetic counterexample. Correct admission retains
capacity through every last-use event and keeps commitments until openings.

New independently verified full-stack proofs / complete-model passes / proved positions: **0 / 0 / 0**.
Actual model context: **none**. Device: one CPU affinity on Intel Core Ultra 9
185H, no GPU. Witness / proof / serialization / verification / startup /
initial-prefill clocks, startup fraction, proof latency/bytes, steady-state and
total-workload proved-token rates: **unmeasured**. No long-context prefill,
resident-model proof passes or decode ran. Metadata contexts17/32/64/127/128/
256/512 and synthetic cohort counts1/2/4 are not model runs or proved passes.
Larger workloads remain allowed; increased context can increase attention
quadratically. Complete private8B **>=50 proved tokens/s remains unachieved**.
No masks, pads, openings or private values reused for amortization.

Next: native owner measures complete verified fixed-context resident1/2/4/8
workloads, exclusive phase clocks and actual host/device capacity. Local next
screen reserves whole proof-construction peaks before admission; unknown
components currently prevent any actual-fit conclusion. Further toy batches
are parked. LIVE sources: zkDuel, STAlloc, MegaZK, CUDA/Rust docs and gnark.

[Experiment](experiments/public-cohort-admission-20261030/README.md) ·
[Dated report](progress/20261030T114123Z-38ad9454.md).
Saved reports do not establish user-message delivery.

Final evidence audit:183 checks PASS;10 unchanged native source pins. Final checkpoint 2026-10-30T11:56:44.181953+00:00.
