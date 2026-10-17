# Public-weight batching: exact oracle, low-priority disposition

Cycle 0006, `20260926T215233Z-c6bf3a4b`. **Do not prioritize integration on
the current measurements.** Three FFN matmul slots expose less than 0.1% of
accounted readiness in the newly completed grouped CPU A/B. No measured
improvement toward complete private 8B >=50 proved tokens/s follows.

The [experiment](../experiments/batched-weight-fold-20260926/README.md) retains
385 passing cases, two arithmetic references, 360 direct matrix-MLE checks,
eight negative controls, source/log hashes and honest traffic accounting.
The script ran in 3.2093 seconds, 16,300 KiB RSS, one CPU; all data synthetic.

Potential interface:

```rust
fn fold_cols_i8_batch(
    m: &[i8], rows: usize, cols: usize, coefficients: &[&[Fp2]],
) -> Vec<Vec<Fp2>>; // result[proof][row]
```

Implementation prototype: `experiments/batched-weight-fold-20260926/experiment.py`,
function `batch_fold`. **No native patch exists, is applied or compiled.**
The inspected numerical seam is `/tmp/zk60-groups-20260926/zkp-core/src/mle.rs:141`;
its FFN call is `hashline/src/private_block/argument.rs:1432`. Each output
preserves its independent challenge vector. The source's synchronous slot
driver at line 1921 would need a new rendezvous boundary for separate proofs.
Gate/up/down have distinct matrices and cannot be batched as one common matrix.

The model reduces weight reads B-fold but preserves B-fold arithmetic and
output. B=8 at 1024x4096 saves only 5.15% of ideal input/output traffic for
row tile 1; tile 32 models 58.18%, assuming local accumulator residency and
the same tiled independent baseline. Coefficient reads, local accumulator
updates and footprint are itemized. No timing or hardware bandwidth inference.

Newly available owner evidence: grouped `dense-ab-1/comparison.json` is passed,
terminal marker zero. Proving 34.861/33.315 s; witness 5.43/5.76 s; serialization
.031/.020 s; known readiness 40.322/39.095 s. Verification from bytes .91/.82 s,
internal .900/.810 s. Three complete FFN matmul slots .035/.032 s, so the fold's
maximum useful impact is smaller. RSS there is 8,548/8,591 MiB for one process;
do not multiply that by B and call it an actual concurrency memory measurement.
Source/log hash validation is retained in the experiment. Shared two-thread,
synthetic 125M CPU evidence; no 8B/GPU/private-model speed acceptance.

If larger-shape evidence later reverses this priority, owner gates are: isolate
fold time and native cache/memory behavior; make all challenges available only
after their original transcript prefixes; bind identical public matrices and
model/profile/calibration/shape; keep independent masks and RNG streams; test
all B=1/native proof-byte/refusal paths; measure peak live memory, startup,
queue delay, readiness and verifier cost. This arithmetic oracle grants no P3
reuse, endpoint chaining or changed privacy contract. Main/Claude owns review
and any integration; no heavy/build/GPU work was launched or queued here.
