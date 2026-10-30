# ZKP efficiency progress

Cycle0146 complete — `20261029T155649Z-9750c59b`, October29,2026.

**No native proving improvement measured.** A small PCS candidate avoids
constructing dense column weights that the prover never reads. The verifier
retains its columns. All row weights, fresh masks/pads/salts and proof work stay.

162 differential fixtures,662,256independent coefficients and4current-sized
synthetic cases pass;8malformed cases fail in both arms. At modeled8BT128,
A/H saves133–142allocation calls and19.6–20.9MiB cumulative requests per block.
Summed column payload11.25–12MiB is not simultaneous peak memory saving.
Serial grouping+rhos+drop improves1.51–2.20x; matrix folds, witness, FS,
commitments and serialization are outside those clocks. Whole-proof gain unknown.

Probe0.342s/37.5MiB RSS; audit160checks/13pins passes. A fixture compile hit
the memory cap; compact descriptors passed under the same cap. Failures retained.
7LIVE primary records include newly assessed FlexProofs and detailed older
Hyrax source, September Plonky3 PR/October release and ITC batch evaluation.
No author performance reproduced. All62prior hypotheses preserved;63/64added.

Conditional handoff/unapplied patch saved. Next owner: exclusive preparation/
rowfold/open/enclosing clocks, then native correctness/privacy/receipt gates
if material. Next local: actual multi-rho row-fold scans and device chunk4costs.
Native full-stack/GPU evidence remains the blocker to a throughput conclusion.

New independently verified full-stack proofs / completed model passes / proved
positions: **0 / 0 / 0**. Actual model context / accelerator: **none**. Research
device: one pinned Intel Core Ultra9 185H CPU worker; no GPU. Witness, proof,
serialization, verification, startup/initial-prefill duration and fraction,
proof latency/bytes, steady-state and total-workload token rates: **unmeasured**.
No long-context prefill, resident-model proof series or decode ran. Larger
workloads remain allowed; dense attention may grow quadratically with context.
Complete private8B >=50 proved tokens/s on RTX5090 or another named high-endGPU
remains **unachieved**.

[Experiment](experiments/composition-eq-scope-20261029/README.md) ·
[Handoff](handoffs/20261029-prover-column-preparation.md) ·
[Dated report](progress/20261029T155649Z-9750c59b.md).
Saved files do not imply message delivery or supervisor liveness.
