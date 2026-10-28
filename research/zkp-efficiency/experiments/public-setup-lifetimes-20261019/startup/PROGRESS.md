# ZKP efficiency progress

Cycle 0083 — `20261019T151854Z-4f2eec2a`, 2026-10-19 UTC.

**No speed improvement found.** A single shifted raw pointer is incorrect in
all nine repeated non-reference D helpers. The two helper families need at
least two and three raw pointer groups. This shortcut is rejected.

A narrower parameter/base translation passes 2,888 address checks and 33
synthetic fixtures. It could remove 198 logical index bytes per row, adding
18 pointer shifts; no lowered kernel, DRAM or runtime gain was measured.
A separate 187-check audit and 36-fixture native-field scalar comparison
(180 coefficients) pass. Main/audit: 0.254/0.098 s, peak 20,532 KiB RSS,
one nice-19 Core Ultra 9 185H CPU core. No build or GPU work.

Seven LIVE primary-source records append 448→455: MLIR/Polygeist address
legality, BatchZK scheduling, and refreshed sumcheck/zkLLMPoT sources. Dates,
license/commit scope and fetch failures are retained; no external gain was
reproduced. [Experiment](experiments/dzc-affine-address-census-20261019/README.md),
[handoff](handoffs/20261019-dzc-affine-address-census.md),
[dated report](progress/20261019T151854Z-4f2eec2a.md).

Seam: `SC_DZC` / `SumcheckRounds`; partial address plan only, no production
patch. Helper tuning is demoted. Next local action: classify immutable public
setup lifetimes across R8 sealing/restart with complete per-layer cache keys.
Owner whole-prover GPU and verified resident 1/2/4/8 passes remain first.

Carried CPU 8B diagnostic: T128, 32 blocks, one 16-thread pass, GPU off;
471.580 s total; proof region 370.137 s includes witness 94.021 s and loading
17.408 s; sealing 101.279 s; D 44.833 s. Fresh verification 34.587+load
11.599 s. Serialization, startup fraction and steady slope unisolated.
Delete-all-D ceiling only 1.105058× on that diagnostic; no receipt reverified
here.

New target proofs / passes / positions **0 / 0 / 0**, device none. Target
context, steady/total rates, startup fraction and witness/proof/serialization/
verification clocks unmeasured. No prefill, resident series or decode ran.
Larger workloads remain allowed; attention may grow quadratically. The
complete private 8B / ≥50 proved positions/s GPU target is unchanged and
unachieved. Saved reports do not establish message delivery.
