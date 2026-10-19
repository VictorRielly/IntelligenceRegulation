# ZKP efficiency progress

Cycle 0077 — `20261019T091854Z-7d13829d`, 2026-10-19 UTC.

**Useful negative; no measured proving improvement.** Streaming D helper
pairs preserves all tested messages and original finals, with identical
arithmetic. Derived scratch falls from 79 to 18 field words, but the complete
logical peak, releasing endpoint pairs and derived buffers after last use,
falls only **130→129 words (0.77%)** at current unpadded T128 catalogs.
The earlier 202→141 count retains the entire endpoint bank throughout;
it describes a different scope. These are logical buffers, not GPU registers,
VRAM or proof clocks.

Thirty synthetic fixtures pass against the captured full Rust expression:
2,145 grid and 390 off-grid values, 90 messages, 1,845 original finals and
seven controls. All 246 independent audit checks pass. Main test: 6.348 s
on one CPU thread. [Experiment](experiments/dzc-pair-stream-20261019/README.md)
and [unapplied handoff](handoffs/20261019-dzc-pair-stream.md).

Seam: `SC_DZC` / `SumcheckRounds`. Pair streaming alone is deprioritized.
Next: construct endpoint pairs on first public use, charging every read,
difference, temporary and original fold. Native byte, RNG, refusal, privacy
and timing gates remain owner work. Seven LIVE source records cover older
Super-sumcheck/NVIDIA guidance, current releases and hardware papers; exact
dates, licenses, inspected commits and access limits are retained.

Carried 8B CPU diagnostic: T128, 32 blocks, one cold pass, 16 threads, GPU off;
606.598 s app total, 0.211 diagnostic positions/s. Prove: 501.126 s, including
122.694 s witness rebuilding. Seal: 105.287 s, overlapping witness 103.349 s
and loading. Fresh verification: 14.126 s load + 43.902 s check. Serialization,
startup fraction and steady slope remain unisolated; privacy/5090 acceptance
remains pending.

New target proofs/passes/positions: **0/0/0**, device none. Target steady and
total rates, startup fraction, witness/proof/serialization/verification clocks
remain unmeasured. No prefill, resident series or decode ran; context can
increase attention quadratically. Complete private 8B ≥50/s remains unachieved.
Only research files changed; no mask/opening reuse.

[Dated report](progress/20261019T091854Z-7d13829d.md). Saved reports do not establish delivery.
