# ZKP efficiency progress

Cycle 0162 COMPLETE — `20261030T104123Z-3535232c`, checkpoint 2026-10-30T10:54:53.112075+00:00.

**No measured proving improvement.** Independent-proof round batching passes
42 synthetic groups / 126 scalar jobs / 378 Rust job runs / 22 controls. Four
equal jobs group 48 logical eval/fold submissions into 12 but retain 4x table
payload and all arithmetic. Tags do not authenticate retagged challenges or
mask contents; independent checks detect those. Native benefit remains unknown.

New independently verified full-stack proofs / complete-model passes / proved positions: **0 / 0 / 0**.
Actual model context: **none**. Device: one affinity-pinned Intel Core Ultra 9
185H CPU worker; **no GPU**. Witness, proof, serialization, verification,
startup, initial-prefill clocks, startup fraction, proof latency/bytes,
steady-state and total-workload proved-token rates: **unmeasured**.
No long-context prefill, resident-model proof passes or decode ran. Synthetic
sumcheck variables 3–6 (8–64 table entries) are not model context lengths.
The complete private 8B **>=50 proved tokens/s target remains unachieved**.
Larger workloads remain allowed; increasing context may increase dense
attention work quadratically. No private masking values or openings reused
to improve amortization; fixed synthetic fixtures repeat only for differential tests.

Next: the native owner measures verified fixed-context resident 1/2/4/8-pass
workloads with startup/drain, exclusive phase clocks and actual capacity.
Further toy batching variants are parked. If clocks remain absent, the next
local test counts public buffer capacity for cohorts 1/2/4 at one frozen R13
slot, including live commitments and completion-controlled retirement.

[Experiment](experiments/separate-proof-round-batch-20261030/README.md) · [Integration boundary](experiments/separate-proof-round-batch-20261030/INTEGRATION.md) · [Dated report](progress/20261030T104123Z-3535232c.md).
