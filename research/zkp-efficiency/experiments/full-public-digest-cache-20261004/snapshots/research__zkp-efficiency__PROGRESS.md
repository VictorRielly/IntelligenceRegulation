# ZKP efficiency progress

Cycle0026 — `20261004T080146Z-55b15f9d`, checkpoint 2026-10-04T08:18:12.165349+00:00.

Canonical transposed-weight readers pass324 synthetic cases,3888 fresh folds,10206 raw witness dots,1157652 canonical FFN bytes and26 controls in0.460062s/17392KiB RSS on one CPU thread. **No proving improvement was measured.** [Experiment](experiments/tn-canonical-readers-20261004/README.md) · [Owner handoff](handoffs/20261004-tn-canonical-readers.md).

Conditional32layer down-cache duplication could shrink by2GiB if every original weight consumer migrates. A64row digest stream needs256KiB modeledRust scratch instead of64MiB per-tensor cast storage. Current native code has no duplicated TN adapter yet; these are capacity counts, not native peak or GPU speed. Source-line counts assume cache reset and do not establish64x traffic savings. Native BLAKE3/full-statement/RNG/receipt checks, ownership and isolated phase/peak measurements remain pending.

LIVE search inspected [cuda-zkp-ntt releases](https://github.com/Artemarius/cuda-zkp-ntt/releases), older small-characteristic sumcheck and [August batch-polynomial evaluation](https://drops.dagstuhl.de/entities/document/10.4230/LIPIcs.ITC.2026.3), plus implementation/scope filters. Five qualified records saved, including fetch failures. No author result reproduced.

Accepted complete private8B passes0/countabletokens0,CPUonly/contextnull/passes0. Steady/total-workload rates,startupfraction,witness/proof/serialization/independentverification and latency/lag/drain clocks unmeasured. No prefill,resident or decode proof;50/s remains unachieved. Larger workloads allowed, attentionT² and fresh masks/privacy unchanged.

Next local: full public digest preimage and immutable-cache ownership/repeated-call audit. Owner first isolates both witness/down/preprocess/digest clocks and actual peaks, then guarded native/device exactness and independently verified complete-stack A/B. GPU SC_SZC/witness recurrence remains the highest impact priority. Reports are local artifacts, not evidence of notification delivery.
