# ZKP efficiency progress

Cycle0113 complete — `20261020T211854Z-71297104` — 2026-10-20 UTC.

**No proving improvement measured.** Public per-layer DD caps add only0.489576% counted committed-word savings over uniformcap256 at T512 using the existing b7 exponent schedule as HIGH/S12 sensitivity. The selected dictionary peak stays768MiB. T128 per-layer DD still regresses9.232756%; public direct/DD selection saves just0.017486% words and adds projected receipt bytes. Actual HIGH fidelity tables, native implementation and full device clocks remain missing.

53,836 probe checks/120synthetic rows/10controls and8,915 independent audit checks pass, including90-digit public table enumeration, mask/slot/PCS accounting and allocation-event controls. Probe1.778s; audit0.022s; one CPU worker, no GPU. Nine LIVE queries/10source records;26ranked hypotheses preserve prior negatives. Older MARLUT is screened out as a direct replacement because its three-party MPC model differs.

New completed independently verified full-stack proofs / passes / positions: **0 / 0 / 0**. Actual model context and accelerator: **none**. Research device: **Intel Core Ultra 9 185H CPU, no GPU**. Witness, proof, serialization and verification clocks: **unmeasured**. Startup duration/fraction, steady-state and total-workload proved rates: **unmeasured**. No long-context prefill, repeated resident-model pass or decode ran. Synthetic rows use lengths 32/128/512; counted layouts use T128/T512, 32 heads, head dimension 128 and 32 sequential layers. These are diagnostics, not proved positions. Larger workloads remain permitted; dense attention can grow quadratically with context. The complete private 8B >=50 proved positions/s target on an RTX 5090 or another named high-end GPU remains unachieved.

Next: public dyadic dictionary partition feasibility, charging every extra mask, slot, PCS group and Sum/tuple binding; owner actual HIGH tables and whole-GPU/resident workload clocks retain priority.

[Experiment](experiments/public-layer-dd-caps-20261020/README.md), [dated report](progress/20261020T211854Z-71297104.md), [handoff](handoffs/20261020-public-layer-dd-caps.md). Saved reports do not establish external delivery.

Final evidence-integrity audit:173checks PASS; original692 source records and prior findings prefix preserved.
