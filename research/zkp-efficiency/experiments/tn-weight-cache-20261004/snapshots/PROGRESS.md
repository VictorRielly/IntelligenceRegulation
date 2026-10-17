# ZKP efficiency progress

Cycle0024 — `20261004T060146Z-96d1ccac`, checkpoint 2026-10-04T06:16:07.388788+00:00.

The public FFN-down schedule passed576 synthetic schedules,11232 raw-dot comparisons,88272 independent column-major byte-output words and16 controls in0.642347s/17156KiB RSS on one low-priority CoreUltra9 185H thread. No proving improvement was measured.

Grouping all output tiles recovers coarse-row8 conceptual calls/36MiB counted payload with extra descriptors. Split-K ordering reduces counted packing512->16MiB but requires2MiB extra reduction and many calls. These are unadmitted T512/K16384/N4096 local counts, excluding workspace/mirrors/other witness planes; no GPU or whole-builder memory result. [Experiment](experiments/grouped-down-schedule-20261004/README.md) · [Owner handoff](handoffs/20261004-grouped-down-schedule.md).

LIVE search checked current [cuBLAS](https://docs.nvidia.com/cuda/cublas/index.html), CUTLASS source/September release, older batching contracts and an August integer-support audit. Integer grouped Ex and current zero-stride broadcast are excluded by documented API scope; native pointer-batched support still needs validation. Seven dated source records saved; two GitHub InternalErrors retained.

0 accepted complete private8B passes/0 countabletokens,CPUonly/contextnull. Steady/total rates,startupfraction,witness/proof/serialization/independentverification and latency/lag/drain clocksunmeasured. Previous n1cold synthetic12block125M/T512/RTX4070Laptop8188MiB diagnostic remains408.609226s total,318.22s combinedrunprover,12.15s in-processverify,independentfalse. No prefill/resident/decode rate established;50/s unachieved.

Next: local identity-bound TN weight-transpose/cache oracle. Owner isolates witness/down clocks and tests coarse64/128/256 rows with native byte/RNG/refusal/receipt parity and complete independent verification under shared locks. Fresh masks/full privacy unchanged. Saved reports are local, not notification-delivery evidence.
