# ZKP efficiency progress

Cycle0164 COMPLETE — `20261030T124123Z-126f56e8`, checkpoint2026-10-30T12:53:31.419503+00:00.

**No measured proving improvement.** Source-derived constructor accounting
passes216 public metadata cases and240 tiny Rust allocation observations;
4,600 checks/249 accounting controls. Frozen T128/H24 H construction has
2.5MiB extra temporary payload; two overlapping H constructors need5MiB
beyond their returned owners. Selected SC_SZC retains224MiB tables and remains
the larger known phase:5.779735GiB single-block CPU partial payload.
Missing witness/backend/whole-run capacities prevent a fit decision.
Constructor-only staggering is a weak lead; no production patch.

New independently verified full-stack proofs / complete-model passes / proved positions: **0 / 0 / 0**.
Actual model context: **none**. Device: one CPU affinity on Intel Core Ultra 9
185H; no GPU. Witness / proof / serialization / verification / startup /
initial-prefill clocks, startup fraction, proof bytes/latency, steady-state and
total-workload proved-token rates: **unmeasured**. No long-context prefill,
resident-model proof passes or decode ran. Public metadata contexts17/32/64/
127/128/256/512 and modeled worker counts1/8/16 are not actual proof workloads.
Larger workloads remain allowed; increased context can increase attention
quadratically. Complete private8B **>=50 proved tokens/s remains unachieved**.
No masks, pads, private openings or private values reused for amortization.

Next:owner measures complete verified high-end-GPU resident1/2/4/8 workloads,
exclusive clocks and actual capacity. Local next:public-weight/backend transfer
ownership and dependency slack. New literature leads:SAK and olderG10;
zkDuel,ICICLE,Rust and known Blackwell work refreshed. G10 simulation gains
are not native evidence; no foreign code executed.

[Experiment](experiments/constructor-peak-envelope-20261030/README.md) ·
[Dated report](progress/20261030T124123Z-126f56e8.md) ·
[Handoff](handoffs/20261030-constructor-peak-envelope.md).
Saved reports do not establish message delivery.

Final evidence audit:119 provenance/accounting checks PASS;10 critical native source pins plus the read-only CUDA compatibility snapshot. All1,087 prior source records and prior FINDINGS bytes preserved;8 new records. No owner-document drift at closing. Final checkpoint 2026-10-30T12:54:10.525911+00:00.
