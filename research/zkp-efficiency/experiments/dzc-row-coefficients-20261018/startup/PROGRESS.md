# ZKP efficiency progress

Cycle 0075 — `20261018T042105Z-c9fe8fca`, 2026-10-18 UTC.

**No native proving improvement found.** The D affine aggregate passes 2,028
synthetic comparisons with the captured full Rust expression, 468 round sums
and 24 full-expression table permutations. It does not reduce input streams:
helpers and hosts keep 58 of 59 tables online, then the aggregate adds one.
The generic driver retains all 59 originals and adds the aggregate, its
construction and folds. At 8B T128, the added table is 8 MiB. These are counts,
not GPU, bus-traffic or peak-memory measurements.

The one-thread CPU experiment took 1.182 seconds; an independent 83-check
catalog/source/count audit passed. A harness norm-window error was corrected
using the native signed-int16 derivation and retained as a negative control.
Both trained windows are 32 bits. All production code and data remain untouched.
[Experiment](experiments/dzc-affine-read-catalog-20261018/README.md) and
[unapplied handoff](handoffs/20261018-dzc-affine-read-catalog.md).

The integration seam is `SC_DZC` / `SumcheckRounds`. Its arithmetic benefit
remains unknown; even deleting every D in the retained 1.1B diagnostic gives
only 1.181×. Next: test round coefficients from the original table endpoints,
including helpers and hosts, without adding a full aggregate table. Native
byte, refusal, RNG, privacy and enclosing timing gates remain owner work.

Five LIVE records cover extended sumcheck/Sage, TensorZKP, MSCProof,
Airbender and the recent Ziren design report. External performance and
security claims were not reproduced. Exact dates, license scope and fetch
blockers are recorded in `sources.jsonl`.

Carried 8B CPU diagnostic: T128, 32 blocks, one cold pass, 16 threads, GPU off;
606.598 seconds app total, or 0.211 diagnostic positions/s. Prove takes 501.126
seconds including 122.694 seconds of rebuilt witnesses. Seal takes 105.287
seconds and overlaps loading/witness work; its 17.357% is a phase share, not
startup. Startup, serialization and the steady slope remain unisolated.
Fresh verifier: 14.126 seconds load + 43.902 seconds check. Privacy acceptance
remains pending; this is not target credit.

New target proofs/passes/positions: **0/0/0**. Target device none; steady and
total-workload rates, startup fraction, and witness/proof/serialization/
verification clocks remain unmeasured. No long-context prefill, resident-pass
series or decode ran. The complete private 8B ≥50 proved-token/s target
remains unachieved; fresh-mask requirements are unchanged.

[Dated report](progress/20261018T042105Z-c9fe8fca.md). Saved reports do not establish delivery.
