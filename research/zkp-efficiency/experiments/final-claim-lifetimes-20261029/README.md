# Final-claim lifetimes and SC_TAB mask-tail weights — cycle 0136

Run `20261029T055649Z-74b83633`, 2026-10-29 UTC. **No native proving
improvement measured.** One current-slot public equality table can replace six
identical constructions in SC_TAB while every private mask pair is evaluated
separately. The scope has a small retained enclosing-phase ceiling.

The initial hypothesis of repeated main-table final evaluation is rejected:
`run_slot` already receives `finals` from the masked round evaluator and uses
them for extensions. The verifier's public table evaluation is another path;
it cannot be priced as prover savings. Earlier lookup recursion, private
terminal masking, SC_TAB descriptor and masked-driver findings were read.

The tested baseline is `private_block/argument.rs::mask_eval`: build a fresh
`eq_table_msb` for the exact ordered column tail, then dot it against each of
the site's reserved base-field rows and combine them with `u`, where `u²=7`.
SC_TAB pushes three A multiplicities and three H helpers, all on Dom::Tab;
the shape enforces `log(Tab)=log_cols`, both commitment widths agree and
their coordinates are `rho(0..log)`. These six tails are identical at one
slot's fresh point. The six mask pairs remain distinct.

`candidate.py::TailWeights` keeps one public evaluated point and its equality
weights. A hit requires the entire ordered Fp2 tail, including its length, to
match. A miss releases the old vector before constructing its replacement.
No mask values, data, evaluations, pads or openings enter this cache. The
proposed Rust selection is SC_TAB only, inside one extension closure; every
other slot calls the original function. No cross-slot/proof caching is proposed.

| Six SC_TAB pairs | N=256 | N=8,192 | N=16,384 |
|---|---:|---:|---:|
| Baseline Eq builds | 6 | 6 | 6 |
| Candidate Eq builds | 1 | 1 | 1 |
| Baseline constructor Fp2 mul | 3,060 | 98,292 | 196,596 |
| Candidate constructor Fp2 mul | 510 | 16,382 | 32,766 |
| Unchanged mask-row base reads and `mul_base` | 3,072 | 98,304 | 196,608 |
| One logical Eq vector, bytes | 4,096 | 131,072 | 262,144 |

Counts follow the actual two-multiplication Eq constructor. They are API/word
counts, not machine instructions, DRAM traffic or time. Removed work is five
Eq/reversed-point allocations and `10(N−1)` Fp2 multiplications. Added work is
a public point key/copy, dispatch and exact comparisons (at most five times
the tail length for these hits). The point key at log14 has 224 logical bytes.
One Eq vector remains live during `extension()` after the row evaluations,
where the incumbent's temporary has died. Its true peak delta is unknown;
one-entry ownership does not prove an unchanged whole-prover peak.

At log14 the removed constructor count is 163,830 Fp2 multiplications per
block and 5,242,560 for 32 sequential block invocations, with no parallel
residency implication. There are still 196,608 mask-row reads/`mul_base` calls
per block and six final U products. Whole-pair dot cost is untouched. These
counts do not add to prior public SC_TAB descriptor savings automatically.

The independent reference in `reference.py` uses schoolbook tuple Fp2
arithmetic, original Boolean-cube sums for small cases, and separate MSB folds
for larger rows, combining original real/imaginary mask coefficients before
evaluation. It imports no candidate arithmetic, weight generator or reader.
Candidate arithmetic uses a different multiplication expansion. Both are
locally authored; neither executes an external prover.

The model passes **1,042 checks / 102 fixtures / 13 wrong-control families**.
Small cases span private logs 0..8, four width relations where distinct,
full-extension/Boolean/zero-first challenges, A/H/In/Out data, offsets,
flipped/fixed coordinates and two extension families. Large SC_TAB cases use
row logs 8/13/14 and six fresh reserved pairs. Raw mask values, ordered
extension terminals and synthetic terminal bytes agree. The test preserves
each later zero extension. Wrong controls cover stale private results,
length-only point keys, tail order, c0, row width, reserved-pair reuse,
flip/fixed coordinates, swapped/missing imaginary rows, term order, extension
family and missing later zero extension. These are local algebra controls,
not native refusal, transcript or privacy tests.

Model clock: 1.528105 s, 41,284 KiB RSS. Source/count/patch audit: 75 checks,
0.004654 s, 15,884 KiB RSS. Device: one nice19 pinned CPU0 worker on Intel
Core Ultra 9 185H; seed 202610290136. Leaf limits: 40 CPU seconds, 45-second
alarm, 256 MiB AS, 96 MiB estimated experiment memory; parent timeout50 s.
No native build, CUDA/GPU, dependency installation or actual model run.

The current R4 TinyLlama T128/L22 phase ledger, reread without rerunning or
reverifying receipts, bounds this selected scope: CPU SC_TAB extension
0.69 s / prove_run153.072 s; RTX4070 Laptop assisted 0.55 s /135.809 s.
Deleting the entire extension phase for free would give at most
1.004528x /1.004066x respectively, before added work. This candidate removes
only Eq preparation within it. Those are historical same-run diagnostic
ceilings, not 8B predictions. Extension timers include mask dots, extension
polynomials and CFS work; exclusive Eq time is unmeasured.

For the actual target, the only defensible ceiling is
`Npositions / (T − C_exclusive_removed + A_added)`, with both cost terms
unknown on a named high-end GPU. Falsify usefulness on any arithmetic,
point/order/offset/width/extension/site/refusal/RNG/transcript/PCS/receipt or
privacy mismatch, absent exclusive saving, peak failure or no enclosing gain.

Reproduce from the research root, sequentially:

```text
python3 experiments/final-claim-lifetimes-20261029/prepare_adapter.py
python3 experiments/final-claim-lifetimes-20261029/run_bounded.py probe.py
python3 experiments/final-claim-lifetimes-20261029/run_bounded.py audit.py
```

[Native pins](native-pins.json), [counts](counts.json), [fixture results](result.json),
[unapplied Rust patch](mask-tail-weights.unapplied.patch),
[ranked hypotheses](hypotheses.json), [sources](sources-cycle.json).
The patch is generated and applied **in memory only** by the audit; it is
uncompiled and unapplied to native source. Main/Claude reviews and integrates.

Primary LIVE search refreshed [StateSync-GKR's October revision](https://arxiv.org/abs/2610.14849)
and [October26 release](https://github.com/Oraclizer/statesync-gkr/releases/tag/v1.2.1),
then inspected [Akita's caller/terminal tracker](https://github.com/LayerZero-Labs/akita/issues/61).
The newly read [author thesis](https://escholarship.org/content/qt5qm6n0s0/qt5qm6n0s0.pdf)
adds detailed older subset-claim combining beyond the earlier Virgo++ abstract
screen; that protocol route remains parked. No author speed reproduced.
Dates, licenses, stale history, observed versus inspected commits and exact
fetch/rate-limit failures are recorded. No downloaded scripts executed.

New independently verified full-stack proofs / passes / positions: **0/0/0**.
Actual model context / accelerator: **none**. Witness/proof/serialization/
verification, startup/initial-prefill duration and fraction, latency/bytes,
steady-state and total-workload rates: **unmeasured**. No long-context prefill,
resident-model pass series or decode. Private8B ≥50 proved tokens/s remains
unachieved. Larger workloads are allowed; attention can grow quadratically.

Next owner action: exclusive Eq/row-dot/extension/enclosing clocks and actual
tail incidence before promotion. Whole-prover high-end GPU and independently
verified fixed-context resident1/2/4/8 remain higher priority. Next local:
lookup/softmax rotation, read earlier wide-Fp2/fused-MAC negatives, then assess
a three-product paired-mask dot only if that exact role is uncovered. Retain
fresh masks, source reads and all current gates; do not sum incompatible gains.
