# ZKP efficiency progress

Cycle0170 COMPLETE — `20261030T184123Z-46af51dd`, checkpoint 2026-10-30T18:57:03.474015+00:00.

**No measured proving improvement.** The useful finding is a compatibility gap:
current R14 LOW/LOW+h24 DD profiles select `argument_accuracy.rs::szc_dd` before
the legacy DD arm. They use three score-remainder limbs and score=base+12;
the prior15-table/4lookup/2helper/shift1..8 projection does not validate that
relation. Current source counts18tables/14private terminals,6lookups/3helpers.
Matching legacy branch text was insufficient to establish actual incidence.

Completed scalar-scaffold census: both inverse methods replay160 synthetic
legacy fixtures; all8controls fire, standalone11422-check audit passes. At
synthetic n7/span4, grouping adds7.65% counted base products. At n19/span12,
legacy counts remove26.62% (16.66% all-zero fallback), **not current LOW+h24
costs or timing**. Tiny norm batching saves just4410 products against381million
legacy baseline products; parked. Main0.519s/24056KiB; finalaudit1.174s/21624KiB,
one low-priority CPU,256MiB AS cap; no GPU/native proof/build.

New independently verified full-stack proofs / complete-model passes / proved positions: **0 / 0 / 0**.
Actual model context: **none**; passes: **0**. Device: **one CPU affinity on Intel
Core Ultra9 185H; no GPU**. Witness, proof, serialization, verification, startup,
initial-prefill clocks, startup fraction, proof latency/bytes, steady-state and
total-workload proved-token rates: **unmeasured**. No long-context prefill,
resident-model proof series or decode ran. Larger workloads remain allowed;
attention can grow quadratically. Complete private8B **>=50 proved tokens/s on
RTX5090 or another named high-endGPU remains unachieved**. No mask/pad/private-
opening reuse or weaker privacy.

Eight LIVE source records append1142->1150: new older author-hosted Montgomery
chapter (online2017-10-25), recent zkDuel(Oct26), extended sumcheck, Efficient
Sumcheck and GPU arithmetic release/field boundaries. Dates/unknowns, license
labels, commit429 and PDF403 are retained; no author gain reproduced.

Next local: source-pin `argument_accuracy.rs::szc_dd` plus accuracy layout and
precision; model all18tables/14private terminals, three Rs limbs, six ordered
lookups/three helpers and score=base+12. Differential full rounds/folds/finals
against original-cube equations with multi-limb/shift/helper negative controls.
Count its own scaffold before any native port. Next owner: selected-path DD
incidence and exclusive scan/scaffold/inverse/slot/enclosing clocks; native
masked/RNG/transcript/extension/PCS/refusal/privacy and independently verified
full-stack resident workloads under current shared build/heavy locks. Do not
duplicate owned R14 freeze/review jobs.

[Experiment](experiments/dd-group-scaffold-cost-20261030/README.md) ·
[Handoff](handoffs/20261030-dd-scaffold-current-profile-gap.md).
Saved reports are not user-message delivery or supervisor-liveness evidence.
