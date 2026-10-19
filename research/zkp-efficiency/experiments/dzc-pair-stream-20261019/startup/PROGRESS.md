# ZKP efficiency progress

Cycle 0076 — `20261018T052105Z-217b5106`, 2026-10-18 UTC.

**Promising arithmetic counts; no measured proving speedup.** Direct D row
coefficients match the captured complete Rust expression on 30 synthetic
fixtures: 2,145 grid and 390 off-grid values, 90 round messages, 1,845 original
finals and 30 final relations. Eleven controls and a 237-check audit pass.

At counted 8B T128 D geometry, with all 59 original tables retained, scalar
products fall **16.69%**, including preparation, conversion and folds. No
full aggregate table is added. Later rounds use more extension products;
register costs, allocation and actual enclosing time remain unmeasured.
These are source counts, not GPU or proof performance. The main test took
1.901 seconds on one CPU thread.
[Experiment](experiments/dzc-row-coefficients-20261018/README.md) and
[unapplied handoff](handoffs/20261018-dzc-row-coefficients.md).

Seam: `SC_DZC` / `SumcheckRounds`, retaining original samples, finals and
masking stages. Next: stream helper coefficients to reduce logical temporary
retention, followed by owner native byte, refusal, RNG, privacy and timing
gates. Even deleting all D in the carried 1.1B diagnostic gives only 1.181×.

Seven LIVE source records cover EPFL, the older Spartan implementation,
monomial benchmark methods, the September 30 Pico 3 report, Plonky3 releases
and commitment/batching references. Dates, license scope, commit inspection
and fetch blockers are recorded. No external performance claim was reproduced.

Carried 8B CPU diagnostic: T128, 32 blocks, one cold pass, 16 threads, GPU off;
606.598 seconds app total, or 0.211 diagnostic positions/s. Prove takes
501.126 seconds including 122.694 seconds rebuilding witnesses. Seal takes
105.287 seconds and overlaps witness/loading. Serialization, startup and
steady slope remain unisolated. Fresh verify: 14.126 seconds loading plus
43.902 seconds checking. Privacy acceptance remains pending.

New target proofs/passes/positions: **0/0/0**; device none. Target steady and
total rates, startup fraction, and witness/proof/serialization/verification
clocks remain unmeasured. No prefill, resident series or decode ran; longer
attention context can grow quadratically. Complete private 8B ≥50/s remains
unachieved. Fresh-mask requirements remain. Only research files changed.

[Dated report](progress/20261018T052105Z-217b5106.md). Saved reports do not establish delivery.
