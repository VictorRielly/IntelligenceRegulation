# ZKP efficiency progress

Cycle0114 complete — `20261020T221854Z-d390b45f` — 2026-10-20 UTC.

**No proving speedup measured.** A synthetic public dictionary union using128+32 slots counts4.553058% fewer committed words than cap256 at T512 after fresh masks, and8.337578% fewer than direct HIGH division. Exact156 slots require four shards and cost more. T128 sharding still regresses4.928441% versus direct. Native implementation, actual HIGH fidelity tables and binding/privacy review remain missing.

53,680probe checks/60synthetic rows/16controls and8,128 independent audit checks pass. Probe0.146128s; audit0.035228s; one CPU worker. Initial audit failure retained: a moved count between identical zero entries was not a valid mutation. Eleven LIVE queries/seven primary records;28ranked hypotheses retain prior negatives.

New completed independently verified full-stack proofs / passes / positions: **0 / 0 / 0**. Actual model context and accelerator: **none**. Research device: **Intel Core Ultra9 185H CPU, no GPU**. Witness, proof, serialization and verification clocks: **unmeasured**. Startup duration/fraction, steady-state and total-workload proved rates: **unmeasured**. No long-context prefill, repeated resident-model pass or decode ran. Synthetic row lengths32/128/512 and counted T128/T512,32heads,head_dim128,32-layer layouts are diagnostics, not proved positions. Larger workloads remain permitted; dense attention can grow quadratically with context. The complete private8B >=50 proved positions/s target on RTX5090 or another named high-end GPU remains unachieved.

Next: public PCS/NTT preprocessing incidence/capacity audit. Owner priorities remain complete high-end GPU exclusive/enclosing phase and capacity clocks, independently verified fixed-context resident1/2/4/8 workloads, actual HIGH/D32 fidelity tables and DD context scaling, and the all-eleven FZC compiler A/B under shared build/heavy locks. No such job was launched here.

[Experiment](experiments/dyadic-dd-shards-20261020/README.md), [dated report](progress/20261020T221854Z-d390b45f.md), [handoff](handoffs/20261020-dyadic-dd-shards.md). Saved reports do not establish external delivery.

Final evidence-integrity audit:443checks PASS; original702 source records and prior findings prefix preserved; agenda/project pins unchanged and sensitivity counts independently reaggregated. Finished UTC 2026-10-20T22:30:00.866956+00:00.
