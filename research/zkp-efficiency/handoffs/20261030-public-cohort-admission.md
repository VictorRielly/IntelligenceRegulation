# Public cohort admission prerequisite — cycle0163

No measured proving improvement or actual fit. The tested gate prevents
112MiB of undercount in a two-proof synthetic case using R13 H24 T128 metadata;
224MiB table capacity does not halve when logical table length halves.
Commitment owners outlive individual slots and completed idle tables still
consume capacity. This strengthens a scheduler safety prerequisite only.

[Interface and obligations](../experiments/public-cohort-admission-20261030/INTEGRATION.md) ·
[Evidence](../experiments/public-cohort-admission-20261030/result.json) ·
[Report](../progress/20261030T114123Z-38ad9454.md).

Prototype: `admission.py::Arena`,source probe `probe.rs/metadata.rs`.
Native owner reviews at SumcheckRounds/build_tables_at and prove_core/backend
lifetimes. All completion handles,reserves and downstream owner certificates
are trusted-model inputs; current source is not instrumented and no patch is
merged. GPU placement,whole-model capacity,exclusive timings,byte/refusal/
transcript equivalence and privacy/soundness remain unresolved. No fresh masks
or openings reused. Next local hypothesis96 counts whole lifecycle construction
peaks; owner complete verified high-end-GPU resident workloads take priority.
