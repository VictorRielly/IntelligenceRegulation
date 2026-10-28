# ZKP efficiency progress

Cycle 0096 complete — `20261020T041854Z-f70297a5` — 2026-10-20T04:30:18.409484+00:00.

**No proving speed improvement measured.** A Python model using the native
Goldilocks Fp2 field definition and actual FZC polynomial passed 108 fixtures,
468 modeled rounds and 11 negative controls against a separate original-table
MLE/reference polynomial. Native Rust/CUDA, masking, transcripts and receipts
were not run. A lexical census indexes 107 selected sites in 21 functions.

New option: reconstruct the affine GL/PL tables in shared staging. At
illustrative T128/F2^21/support, requested storage falls from 736 MiB dense
to 464 MiB mixed, then 400 MiB with implicit GL/PL. In 72 partial allocation
schedules this saves **zero additional backing in all 24 resident cases**;
selected chunked cases save another 64 MiB. Actual VRAM, fit and time remain
unknown; extra arithmetic and barriers may outweigh saved traffic.

New independently verified full-stack proofs/passes/positions: **0/0/0**.
CPU-only synthetic work; actual model context and accelerator: none.
New witness/proof/serialization/verification clocks, steady-state and total
proved rates, and startup fraction: **unmeasured**. No long-context prefill,
complete resident-pass sweep or decode ran. The complete private 8B >=50
proved tokens/s target remains unachieved; privacy and fresh masking unchanged.

LIVE searches covered NTT-TensorCore, SP1's October release and zerocheck
simplification, ICICLE, zkLLMPoT v2, zkIE and older profiling work. Nine source
records were appended with dates, commit/license scope and fetch failures.

Next: coefficient-aware affine recomputation/fold/barrier accounting and
host-tail break-even. Owner telemetry must first show raw eligibility and
lower fresh backing at the actual peak before a native implementation.

[Experiment](experiments/native-fzc-arena-20261020/README.md),
[handoff](handoffs/20261020-implicit-affine-fzc.md).
Saved reports do not imply external message delivery.

[Dated report](progress/20261020T041854Z-f70297a5.md).
