# ZKP efficiency progress

Cycle 0095 complete — `20261020T031854Z-e03e28dc` — 2026-10-20T03:33:04.456870+00:00.

**No proving speed improvement measured.** A mixed storage layout passed 30 toy
fold/address fixtures and 121 negative controls. At illustrative 8B T128,
the slot-18 table request falls from 736 to 464 MiB. A partial allocation
projection saves 272 MiB of backing with chunked commitments and **zero** with
resident commitments, where suitable pooled capacity already exists. Actual
GPU peak memory, fit and elapsed benefit remain unknown.

The allocation study covers 72 partial schedules and a separate interval
oracle. The fold fixtures use two residue lanes modulo 101 and base challenges;
they do not validate native extension arithmetic, masked rounds or receipts.
No native patch, build or GPU job ran.

New independently verified full-stack proofs/passes/positions: **0/0/0**.
No actual model context or accelerator was used. New witness, proof,
serialization and verification clocks; steady-state and total-workload rates;
and startup fraction are **unmeasured**. No long-context prefill, complete
resident-pass series or decode ran. The complete private 8B / >=50 proved
tokens/s target remains unchanged and unachieved. No masking or privacy change.

LIVE primary searches covered StateSync-GKR's October papers/release, SP1's
GKR PR/release, the older SP1-zorch memory finding, INT4 FFN, Sumcheck 201,
Bits Under ZK-LLM and efficient-sumcheck. Ten records were appended; publication
and license limits and failed commit fetches are retained.

Next: extend the layout oracle to native Goldilocks Fp2 and the actual FZC
polynomial, then enumerate every reader/writer. The owner must measure actual
raw-path eligibility and fresh/reused capacity before a native implementation.
The seam is DevFzcRounds::new and the FZC kernels, including later folds,
finals and host-tail packing.

[Experiment](experiments/private-transient-capacity-20261020/README.md),
[handoff](handoffs/20261020-mixed-fzc-arena.md),
[dated report](progress/20261020T031854Z-e03e28dc.md). Saved reports do not imply message delivery.
