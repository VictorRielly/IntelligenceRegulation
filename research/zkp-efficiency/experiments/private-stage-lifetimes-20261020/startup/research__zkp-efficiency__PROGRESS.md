# ZKP efficiency progress

Cycle0093 complete — `20261020T011854Z-224b9b69` —2026-10-20 UTC.

**No proving speed improvement measured.** The tested staging reuse saves
**zero work when A/H are already device-resident**, which is the source path
after successful GPU commitments. A fallback-only capacity option is preserved.

144 synthetic fixtures pass an independent table-byte/lifetime audit:
27301 checks,292 negative controls,
1299 corruptions rejected. A host-backed-only
prototype reduces symbolic staging184->16MiB at2^20 entries,with unchanged
H2D and existing copy synchronizations. This is no measured VRAM/time gain.
Source census covers298 selected allocation sites and exposes raw/cache costs
outside the prior partial pool model. Legacy drains are not direct production
calls in the inspected trained private path. Review-only patch remains unbuilt.

New independently verified complete proofs/passes/positions **0/0/0**;
GPU device/token context none; CPU-only synthetic experiment,0 proof passes.
New witness/proof/serialization/verification clocks, steady-state and
total-workload proved rates and startup fraction **unmeasured**. No long-context
prefill,resident complete-proof series or decode ran. Larger workloads remain
allowed; attention may grow quadratically. Complete private8B >=50 proved
tokens/s on RTX5090/another named high-end GPU remains unchanged and unachieved.
No mask/opening reuse or privacy weakening.

Carried owner CPU8B T128 one16-thread pass,GPUoff,total478.737s;
fresh verify42.709s+13.681s load;not reverified here. Startup/steady/isolated
serialization unknown. Newer next-token CPU timing is a separate owner report.

LIVE sources:quantization study,EfficientSumcheck,October gnark release/batching,
pinned cudarc copy semantics,NVIDIA2015 streams,SumCATS. Seven records saved.
Next: derive private-stage commitment/opening lifetimes and an actual peak
phase; owner whole-proverGPU and verified resident workloads remain first.

[Experiment](experiments/device-allocation-coverage-20261020/README.md),
[handoff](handoffs/20261020-host-backed-fzc-staging.md),
[dated report](progress/20261020T011854Z-224b9b69.md). Only research changed; no delivery implied.
Checkpoint 2026-10-20T01:31:06.037153+00:00.
