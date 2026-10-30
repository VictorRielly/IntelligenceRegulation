# ZKP efficiency progress

Cycle 0147 complete — `20261029T165649Z-7b8b834a`, October 29, 2026.

**No native proving improvement measured.** A kernel candidate skips rows
whose public opening weights are all zero. It passed 1,120 Rust differential
fixtures and 288 CPU C++ fixtures using the exact patched kernel body.
Eleven negative controls, four paired emulator panics and 139 audit checks
passed. No CUDA compilation, GPU run, native proof or external review occurred.

Dense weights remove no work, and a dense proximity vector retains a full
scan. Actual native support, register spills and whole-proof benefit remain
unknown. A separate measurement finding: the device row-fold adapter uploads
weights without recording those bytes in its local H2D counter. Larger
batches retain total upload and download volume; the current limit stays four.

Nine LIVE source records were appended; all 64 prior hypothesis objects
were preserved and two added. The conditional patch and handoff are saved.
Next: measure actual public row support and exclusive phase clocks, then
consider a guarded native A/B only if the cost is material.

New independently verified full-stack proofs / model passes / proved
positions: **0 / 0 / 0**. Model context and accelerator: **none**. Device:
one pinned Intel Core Ultra 9 185H CPU worker. Witness, proof, serialization,
verification, startup/prefill duration and fraction, proof latency/bytes,
steady-state rate and total-workload rate: **unmeasured**. No prefill,
resident-model proof series or decode ran. Larger workloads remain allowed;
dense attention can grow quadratically with context. The complete private
8B **>=50 proved tokens/s target remains unachieved**.

[Experiment](experiments/multi-rho-rowfold-20261029/README.md) ·
[Handoff](handoffs/20261029-public-rho-rowfold.md) ·
[Dated report](progress/20261029T165649Z-7b8b834a.md).
Saved files do not imply message delivery or supervisor liveness.
