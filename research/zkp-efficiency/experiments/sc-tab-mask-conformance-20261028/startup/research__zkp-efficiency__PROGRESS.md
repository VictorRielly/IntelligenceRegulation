# ZKP efficiency progress

Cycle 0128 complete — `20261028T215649Z-43c1f18d` — 2026-10-28 UTC.

**No proving speedup measured.** A public-table descriptor passed 50,042
synthetic checks while keeping only the 256 distinct freshly encoded rows in
each U8/exp/act table. The test covers six complete SC_TAB polynomial fixtures,
54 rounds, full Fp2 terminals, zero leading challenges, extension selectors,
malformed adapters and pad-zero controls. A separate source/count audit passed
64 checks; all nine tested native source pins are unchanged.

At current R12 T128, the three public factors would retain 12,288 B instead of
786,432 B and perform 765 instead of 49,149 public fold interpolations. These
are logical source counts. All private factors, the full round cube and
generic polynomial work remain. Dispatch and adapter costs are unknown.
The Rust sketch is uncompiled and unapplied; native masks/transcript/PCS,
refusal/privacy/receipt gates and exclusive enclosing clocks are owed.

Checking clocks: model 3.977046 s / 16,400 KiB RSS; source audit 0.011229 s /
15,840 KiB RSS, one nice-19 Intel Core Ultra 9 185H worker. Caps: 45-second
CPU/alarm, 50-second parent, 256 MiB address space; 96 MiB memory estimate.
No GPU or native build ran.

Nine primary-source records (830 total) cover contemporary sumcheck/SP1,
Efficient Sumcheck and older CMT/public preprocessing, among others. Eleven
native LIVE batches are retained. Exact dates, license/commit limits and
429/cache/404 blockers are recorded; no author benchmark was reproduced.
All 41 prior hypotheses remain; rank 41 is tested/refined and rank 42 added.

New independently verified full-stack proofs / passes / positions: **0 / 0 / 0**.
Model context / accelerator: **none**. Witness, proof, serialization,
verification, startup/prefill clocks, startup fraction, proof latency/bytes,
steady-state and total-workload rates: **unmeasured**. No long prefill,
resident proof series or decode ran. Larger workloads remain allowed;
attention can grow quadratically. Private 8B / >=50 proved tokens/s is unachieved.

Next owner action: measure exclusive public construction/folding, SC_TAB and
enclosing verified workloads under shared locks before integration. Next
local test: source-derived CFS extension/terminal/refusal conformance at this
slot, after checking previous masked-driver coverage. Whole-prover GPU,
DD-context/fidelity scaling and complete phase/capacity clocks stay top ranked.

[Experiment](experiments/periodic-sc-tab-20261028/README.md),
[handoff](handoffs/20261028-periodic-sc-tab.md),
[dated report](progress/20261028T215649Z-43c1f18d.md).
Only research outside runtime written; saved reports do not establish delivery
or supervisor liveness. Checkpoint UTC: 2026-10-28T22:09:24.949626+00:00.

Final evidence audit: 334 checks PASS; 63 immutable artifacts and nine native pins match. All prior sources/findings and 41 hypotheses preserved. Final checkpoint UTC: 2026-10-28T22:10:28.423971+00:00.
