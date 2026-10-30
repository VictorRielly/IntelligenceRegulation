# R14 public fold geometry: source-bound metadata differential

Run `20261029T235649Z-a82f1ea9`, cycle0154. No native speedup measured.

`prepare.py` pins only public source/docs/census files, extracts unchanged
SplitLayout constructor/audit and13Shape method bodies. `harness.rs` executes
those methods in a minimal public fixture; no crate build, model/witness or
native proof. `audit.py` independently builds domain count blocks/prefix sums,
slot reservations and endpoint bands, comparing every descriptor and saved
native inventory. It partitions all rows and rejects overlapping/missing
data, reused masks, omitted endpoints/proximity and stale8B counts.

Reproduction (one stage at a time, same limits):

```sh
python3 experiments/r14-fold-geometry-20261029/run_bounded.py prepare
python3 experiments/r14-fold-geometry-20261029/run_bounded.py compile
python3 experiments/r14-fold-geometry-20261029/run_bounded.py probe
python3 experiments/r14-fold-geometry-20261029/run_bounded.py audit
```

Do not rerun finish_reports.py: it appends the one-cycle ledger/report.
Source changes cause pin/manifest checks to fail; preserve this experiment
and start a separately named one instead of silently accepting drift.

Result:12fixtures,11251assertions,132extracted-native controls and120Python
controls. Current R14 row metadata matches old inventory, but four census
producer files differ. Generic-point group counts are historical/conditional.
PCS appends fresh proximity before chunks4:56groups→57rhos→15batches,
12groups→13rhos→4batches. No current native define/claim/group execution,
actual support, Goldilocks arithmetic, FS, full PCS pads, CUDA or receipts.
Counter sums are logical operands only. Full-stack proofs/passes/tokens0.

The current profile door is Shieldstral3072/9216 atT128/T256; do not label
this8B geometry. Exact per-plane/slot bands, provenance differences,
historical conditional grouping and conservative internal endpoint bounds
are in result.json. target-accounting.json records all unknown phase clocks.

Native seam: fold_rows_multi_zk→EncodedStore::fold_rows→dev_fold_rows→
k_fold_rows. The next research question is a5vector lastbatch for4+1tails,
preserving every mask/proximity/output and charging register costs.
No production patch or GPU candidate was prepared this cycle.

The source-history correction and initial drafts are preserved in
source-history-correction.json and initial-before-source-history-correction-*;
Power circuits is a refresh. Sisu is the newly assessed older source.
