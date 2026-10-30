# Conditional H public-support handoff — 2026-10-29

Run `20261029T185649Z-81a2bde2`, cycle0149. **No native proving gain measured.**
Main/Claude reviews and integrates. This is complementary incidence evidence
for the existing unapplied [zero-rho skip patch](../experiments/multi-rho-rowfold-20261029/native-public-rho-skip.patch).
No new production patch or device job is queued.

The [self-contained experiment](../experiments/h-structural-support-20261029/README.md)
extracts unchanged frozen R13 HIds, H-domain inventory, H-offset loop,
`B::h`, `build_claim`, `logup_sum_claim`, audit and grouping/rho helpers.
It supplies public Shape methods and a source-read H plane-to-slot schedule;
the full native constructor/FS was not run. All source hashes, commands,
seed, failures and bounds are retained. R14 must be re-pinned separately.

At R13 8B/T128 with generic distinct slot-point keys, H evaluation groups
partition all data and terminal-mask rows. H's sum adds all data again;
proximity remains fully dense. With ordinary chunk4 ordering, support
upper bounds reduce logical H matrix reads from 1,726,218,240 to
1,150,550,016 B without DD (−33.35%), and 1,664,876,544 to
1,095,499,776 B with DD32 (−34.20%). These are per-core source-read bounds,
not physical DRAM or elapsed gains. Host folds already skip zero weights.

Exact three-batch structural planning can reduce the bounds further to
732,954,624 / 692,060,160 B (−57.54% / −58.43% vs dense H). An exhaustive
subset DP agrees with the constructive plan: sum+prox+largest D/F evaluation
groups together, remaining disjoint groups in two batches. Full batches go
first; only the last is partial. This result is specific to complete H
support. The prior mask-only packing counterexample is preserved and does
not authorize the same heuristic on A.

Proposed interface: a public-only planner accepts current `ZClaim` group
membership and structural row intervals (or actual public rho support),
returns `physical_order: Vec<usize>` and its inverse. It runs after normal
grouping/rho construction, before the device branch of `fold_rows_multi_zk`.
At `EncodedStore::fold_rows` → `dev_fold_rows` → `k_fold_rows`, use batches
of at most four; restore all message vectors to original logical order
before original-order pad concatenation or transcript absorption. Keep the
original rho list for the host pad fold and all checks.

Added costs must be charged. The existing `&[Vec<Fp2>]` API needs public-rho
clones for a simple reordering implementation: 702,400 B noDD or 745,184 B
DD total copied in these geometries (streaming batch4 could bound active
clone payload to 280,960 / 270,976 B). A reference/gather API would need a
separate interface review. Output vectors can move by header rather than
copying all elements, but extra allocation/permutation still counts. The
prior skip patch increases source accumulator+weights64→128B/thread;
compiled registers/spills/occupancy are unknown. Support scans/bitsets,
branches, uploads, downloads, pads and pipeline drain stay in clocks.

Validation:20 Rust fixtures,539,532 independent full-cube coefficients,
1,683 message+pad folds and1,683 inverse-scattered values;5 control
classes90 invocations.175 Python checks independently verify source
offsets, intervals, unions, legal chunking and DP/constructive equivalence.
All data/challenges synthetic. Source-sized matrices were not materialized.
No native receipt, GPU arithmetic/race/ABI or external security test ran.

Corner-point tests merge groups and can leave one dense-proximity batch
with no matrix-read saving. Never hardcode generic group counts or skip
based on private witness sparsity. Preserve H sum and U pair, every mask,
pad and output, refusals, RNG order, FS/PCS and proof bytes. No commitment,
opening, blinding, pad or result reuse is proposed.

Owner next: record current public H part/group/nonzero/chunk-union counts
and exclusive rho-H2D, allocation, kernel, D2H, pad-fold, open and enclosing
clocks (prior rho-H2D omission remains relevant). Compare with these source
bounds. If material, use current shared locks for CUDA compile, register/
spill and device checks, native golden/refusal/RNG/FS/PCS/privacy controls,
then independently verified complete-workload A/B. Current S4/R14 reviews
take precedence; the historical source shape does not register R14.

End-to-end ceiling is `N/(T−C_removed_exclusive+A_added)`. The exclusive
native H-fold fraction f is unknown; free deletion is bounded by
`1/(1−f)`. No numerical 8B GPU rate follows. Any descriptor/group/value/
order/refusal/privacy mismatch, capacity regression or absent enclosing
verified gain falsifies promotion. New complete proofs/passes/positions0;
the complete private8B >=50 proved tokens/s target remains unachieved.
