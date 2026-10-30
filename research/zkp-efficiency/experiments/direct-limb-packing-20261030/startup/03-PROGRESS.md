# ZKP efficiency progress

Cycle 0157 complete — `20261030T054123Z-a698c842`, October 30, 2026 UTC.

**No measured proving improvement.** A public-budget hybrid stages all
supplied row-weight vectors once while retaining max-four output scratch.
It passed 388 synthetic Rust fixtures, 1,567 budget checks/controls and all
25 injected synchronous failure points. Python bigint references matched
1,764 Rust planner cases and 3,648 output limbs in 16 exported fixtures.

For a conditional historical T128 A opening with 57 vectors, H2D submissions
fall from 15 to 1 and device scratch allocation requests from 30 to 2.
Hybrid requested scratch is 4,256,080 B versus 1,273,664 B for serial reuse
and 18,149,712 B for full staging. D2H calls, launches, matrix scans,
arithmetic and transfer payload bytes are unchanged. These are synthetic
capacity/API counts, not native elapsed savings.

Next: owner measurements of exclusive host packing, allocation, H2D,
kernel, D2H, conversion, synchronization and mutex-wait costs, with actual
current groups and enclosing independently verified workload time. If those
removable costs are negligible, park staging variants. A bounded local
follow-up can test safe direct c0/c1 packing into u64 staging to remove
per-rho temporary Vec allocations; it must not use raw Fp2 bytes.

New independently verified full-stack proofs / passes / positions: **0 / 0 / 0**.
Actual model context: none; cost accounting uses historical T128 standalone
R14 f_e9 groups. Device: one affinity-pinned Intel Core Ultra 9 185H CPU
worker, no accelerator. Witness, proof, serialization, verification,
startup and initial-prefill clocks, startup fraction, proof latency/bytes,
steady-state and total-workload proved-token rates: **unmeasured**.
No long-context prefill, resident-model pass series or decode ran. Larger
workloads remain allowed; longer attention can grow quadratically.
Complete private 8B **>=50 proved tokens/s remains unachieved**.

Seven LIVE primary-source records saved; all 84 prior hypotheses preserved.
New records 85/86 retain the tested hybrid and safe-packing follow-up.

[Experiment](experiments/hybrid-opening-budget-20261030/README.md) · [Handoff](handoffs/20261030-hybrid-opening-budget.md) · [Dated report](progress/20261030T054123Z-a698c842.md).
Saved reports do not establish message delivery or supervisor liveness.
