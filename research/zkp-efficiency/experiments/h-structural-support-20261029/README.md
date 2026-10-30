# Frozen R13 H public support — cycle 0149

Run `20261029T185649Z-81a2bde2`, October 29, 2026. **No native proving
improvement measured.** This experiment narrows the prior public-rho skip
candidate to exact H part offsets and structural support at the frozen
R13 8B/T128 geometry. Native `define`, native Fiat–Shamir, CUDA and complete
proofs were not executed. R14 split-width geometry is different.

The native H plane inventory, H offset loop, `B::h`, `build_claim`,
`logup_sum_claim`, claim audit and grouping/rho helpers were extracted
unchanged. Equality iterators are serial. A locally supplied public Shape
and Layout wrapper supplies geometry and the H plane-to-slot schedule read
from `argument.rs` / `argument_accuracy.rs`. The native HIds constructor
crosschecks its domain inventory. The independent Python interval model
checks every offset against that extracted route and the native census.
Thus the offsets are source-derived, rather than the prior arbitrary
synthetic placements. This is not an actual captured native invocation.

Every H plane appears in exactly one evaluation group, including the U
zero-sum pair, and again in the all-ones LogUp sum. The evaluated groups'
structural supports partition every data and terminal-mask row. The sum
covers data only; proximity remains a dense full-row vector. For the seeded
generic distinct public slot points, the source geometry gives:

| H, per core, N=16384 | noDD | DD32 |
|---|---:|---:|
| Rows / data / sites | 4390 / 4282 / 53 | 4234 / 4122 / 55 |
| Ordinary groups / rho vectors | 9 / 10 | 10 / 11 |
| Baseline chunk4 row visits | 13,170 | 12,702 |
| Existing-order support visits | 8,778 | 8,358 |
| Baseline logical matrix reads | 1,726,218,240 B | 1,664,876,544 B |
| Support upper bound with zero skip | 1,150,550,016 B | 1,095,499,776 B |
| Reduction in logical matrix reads | 33.3485% | 34.1993% |

With the prior conservative A bound, unchanged-order combined A/H logical
read reductions are 11.4455% / 11.7830%. No layer multiplier, physical
DRAM, elapsed-time or complete-model rate inference is applied. The host
already skips zero rho; the candidate device kernel does not yet run here.
All rho transfer, outputs, host pad folds, masks and PCS checks remain.

A further public-support planning experiment finds the best three legal
chunk4 batches by exhaustive subset dynamic programming (441 / 726 states),
independently checked against a constructive partition: batch sum and
proximity with the largest two evaluation supports, D and F. Remaining
evaluation supports are disjoint, so their packing does not change total
visits. Full batches precede the sole partial batch. The optimum is
5,592 / 5,280 visits, or 732,954,624 / 692,060,160 logical matrix bytes
(57.5399% / 58.4317% below the dense H baseline). This is an exact optimum
of the inspected **structural-support objective**, not a device-time
optimum. A planner, permutation/scatter, launch overhead, cache effects,
registers and spills can erase that advantage.

Corner challenges merge column-weight keys. The generic group counts and
percentage bounds must not be hardcoded for every opening. Small zero/one
point fixtures sometimes fit in one batch; its dense proximity leaves no
matrix-read skip opportunity. The original single-batch negative-control
assumption failed and is retained, then corrected. Cycle0148's mask-only
packing counterexample remains valid: this H result needs its complete
source support partition, not just mask counts.

20 Rust fixtures pass: two source-sized H metadata cases and 18 small
fixtures (column logs1/3/5, DD on/off, zero/one/random point tails).
Independent u128 schoolbook field arithmetic checks 539,532 full-cube
coefficients, 1,683 message-plus-pad folds and 1,683 physically packed then
inverse-scattered values. Five control classes run 90 times: proximity
overlap, sum reaching a terminal mask, wrong imaginary-plane mapping,
union-versus-batch accounting, and wrong inverse scatter. These are local
component controls, not receipt attacks or external security review.
The Python source-offset/interval/DP census passes 175 checks.

Seed202610290149. Final compile2.232s/185,528KiB RSS; probe0.0658s
parent (0.03983s internal)/9,324KiB; census0.0658s/17,428KiB. One CPU
affinity, nice19,40s CPU/45s alarm/50s parent limits,384MiB address-space
cap. Estimated memory300MiB compile/96MiB other stages. Intel Core Ultra9
185H, WSL2, Rust1.75, Python3.10.12. Rust auxiliary thread count unmeasured;
one CPU affinity and codegen unit bound CPU use. No GPU job or native build.
An initial Rust include-macro assembly failure and the corner-control
failure are retained with logs. Passing results before adding packed
scatter are retained too.

Reproduce each bounded stage separately:

```text
python3 experiments/h-structural-support-20261029/run_bounded.py prepare
python3 experiments/h-structural-support-20261029/run_bounded.py compile
python3 experiments/h-structural-support-20261029/run_bounded.py probe
python3 experiments/h-structural-support-20261029/run_bounded.py census
python3 experiments/h-structural-support-20261029/run_bounded.py audit
```

The integration seam remains `fold_rows_multi_zk` → `EncodedStore::fold_rows`
→ `dev_fold_rows` → `k_fold_rows`. The prior unapplied kernel patch is
`../multi-rho-rowfold-20261029/native-public-rho-skip.patch`. No production
patch was made. Public-only planning would run before device dispatch and
restore logical output order before pad folding, absorption or opening use.
Never reuse private openings, masks, pads, commitments or results. Keep all
refusals, RNG order, FS, PCS, H sum and proximity. Current accepted source,
native golden/refusal/privacy gates and independently verified full receipts
remain owner prerequisites before integration.

The whole-workload ceiling remains `N/(T−C_removed_exclusive+A_added)`.
The exclusive native H-rowfold fraction f is unknown; even free deletion is
bounded by `1/(1−f)`. The prior zero-skip source increases accumulator-plus-
weight temporary payload64→128B/thread; compiled occupancy/spills are unknown.
Logical-read reductions do not set a numerical end-to-end speedup.

LIVE primary searches refreshed [StateSync's October26v2](https://arxiv.org/abs/2610.14849),
[zkDuel](https://github.com/snarang181/zk-duel) and the
[NTT/sumcheck memory-budget comparison](https://arxiv.org/abs/2606.16146).
Newly assessed [2012 cache-locality work](https://arxiv.org/abs/1202.3856)
separates disjoint structure from locality; [2026 constrained hypergraph
partitioning](https://arxiv.org/abs/2605.20497) has a different objective.
Expander's searched October release label was historical: CUDA PR131 merged
October28,2024, not October2026. Its exact commit metadata/partial diff was
inspected; no kernel adoption or execution. Seven source records retain
dates, URLs, license/commit limits and Cachemiss blockers. Nine raw LIVE
batches saved. No author performance reproduced.

New independently verified full-stack proofs / model passes / proved
positions: **0/0/0**. Actual model context and accelerator: **none**.
Modeled context128; device one pinned CPU worker. Witness, proof,
serialization, verification, startup/prefill duration and fraction, proof
latency/bytes, steady-state and total-workload rates: **unmeasured**.
No long-context prefill, resident-model proof series or decode ran. Larger
workloads remain allowed; dense attention can grow quadratically. Complete
private8B >=50 proved tokens/s remains **unachieved**.

Next: owner actual public H part/group/union counters and exclusive
upload/allocation/kernel/download/pad/open/enclosing clocks at the current
profile; re-pin R14 separately if admitted. Next local complementary work:
derive A's source offsets and overlapping support, with this H partition as
a control, rather than applying the H disjointness assumption to A.
Main/Claude reviews and integrates; no heavy/GPU job was queued. Saved
reports do not establish user-message delivery or supervisor liveness.
