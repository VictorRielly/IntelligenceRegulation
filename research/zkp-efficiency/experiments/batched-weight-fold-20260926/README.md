# Batched public-weight column folds — cycle 0006

Run `20260926T215233Z-c6bf3a4b`, 2026-09-26. **Arithmetic passes; demote this
optimization because the measured native phase is too small. No model speed
improvement was measured.** All matrices and challenges are synthetic.

The proposed numerical interface is
`fold_cols_i8_batch(m: &[i8], rows: usize, cols: usize, c: &[&[Fp2]]) -> Vec<Vec<Fp2>>`.
Output `b,i` is `sum_j m[i,j] * c[b,j]`; each `c[b]` is independently supplied,
usually `eq_table_msb(r_j)` from that proof's own transcript. This is a tiled
matrix-times-many-vectors operation, not proof aggregation. Production seam:
`/tmp/zk60-groups-20260926/zkp-core/src/mle.rs:141`, called by
`hashline/src/private_block/argument.rs:1432` for slots 11, 12 and 13.
Source pins and exact caller/schedule excerpts are retained locally. No Rust
patch was applied or compiled; `experiment.py::batch_fold` is the prototype.

Run from the research directory:

```sh
python3 experiments/batched-weight-fold-20260926/experiment.py > experiments/batched-weight-fold-20260926/run.log 2>&1
python3 experiments/batched-weight-fold-20260926/validate.py > experiments/batched-weight-fold-20260926/validation.log 2>&1
```

One CPU affinity, one thread, 59-second alarm, 55-second CPU limit and 512 MiB
address-space limit. Estimated experiment memory 32 MiB. The executed run used
**3.2093 seconds and 16,300 KiB RSS**, Intel Core Ultra 9 185H, Python 3.10.12,
Linux/WSL2, seed **2026092606**. No dependency, compiler or GPU was invoked.

**385 cases, 29,290 compared field outputs, 13,260 independently expanded
equality entries, 360 full matrix-MLE checks, eight negative controls and
six malformed fixture refusals pass.** Shapes: 1x1, 3x4, 8x8, 13x16, 32x64,
65x128; batches 1/2/4/8; row tiles 1/3/8/32; dense, sparse, zero and padded
matrices. Tests include -128/127, full-extension and near-p coefficients,
zero/one challenge coordinates and partial final tiles. Non-power-of-two rows
are zero-extended for the independent matrix-MLE oracle.

The first reference mirrors the native per-term modular arithmetic. The
independent reference accumulates signed integer dots then reduces each limb;
direct cube products independently check equality ordering and the two-axis
matrix contraction. Mutations detect unsigned byte interpretation, stale
challenge reuse, dropped extension limbs, dropped tails, wrong matrix reuse,
dirty padding, swapped proof order and a changed matrix digest. Shape/range
refusals belong only to this research interface; no native refusal claim follows.

For a **modeled**, unallocated 1024x4096 dense matrix and B=8:

| Row tile | Separate / batch weight bytes | Coefficient bytes (both) | Output bytes (both) | Ideal input/output reduction |
|---|---:|---:|---:|---:|
| 1 | 33,554,432 / 4,194,304 | 536,870,912 | 131,072 | 5.15% |
| 8 | 33,554,432 / 4,194,304 | 67,108,864 | 131,072 | 29.13% |
| 32 | 33,554,432 / 4,194,304 | 16,777,216 | 131,072 | 58.18% |

The fair independent baseline uses the **same row tile**; coefficient reuse
across rows is not credited to batching. Arithmetic stays 33,554,432 nonzero
multiply-add terms. Each path additionally initializes 131,072 accumulator
bytes and performs 1,073,741,824 logical accumulator read/write bytes and
536,870,912 local coefficient-read bytes. These may be registers/cache or
spills. Tile 32 needs 4,096 live accumulator bytes plus 128 coefficient bytes
for the batch, compared with 512+16 for one independent proof tile. Source
counts exclude allocator/zero-initialization of returned vectors, cache lines,
write allocation, packing, equality-table construction and scheduler traffic.
They are neither measured DRAM bytes nor a runtime model. Strided row-major
access and register pressure can erase the apparent saving. B=1 saves no
weight traffic, and zero matrices perform no arithmetic in either path.

The previous cycle's queued grouped A/B **has completed**: `comparison.json`
says passed and `run.done` is zero, despite a stale queued README. The two
new-arm native logs record:

| Clock (seconds) | 03-new | 04-new |
|---|---:|---:|
| Proving | 34.861 | 33.315 |
| Witness build | 5.43 | 5.76 |
| Serialization | 0.031 | 0.020 |
| Known readiness sum | 40.322 | 39.095 |
| Verify internal | 0.900 | 0.810 |
| Verify from bytes | 0.91 | 0.82 |
| All three FFN matmul slots | 0.035 | 0.032 |

Deleting all three slots would save only **0.087% / 0.082%** of those known
readiness sums, based on rounded phase clocks. The fold is a subset of each
slot: `define` and `run_slot` both precede `ph.slot`. This is a conservative
phase ceiling, not the candidate's saving. Conditions: dense synthetic 125M
block, two Rayon threads, shared CPU. No fold-only timing, enclosing request
clock, trained-model/GPU/8B estimate or quiesced performance claim is inferred.
The old-arm proving clocks are 37.630/36.836 seconds; the complete softmax slot
is 10.050/10.085 old versus 8.601/7.832 new. These observations are another
owner's evidence, not an experiment run by this lane.

The same logs show **8,548/8,591 MiB process RSS** at the FFN slots. This is
not an incremental per-proof memory measurement, but already motivates a
residency gate before batching. Native `argument` runs each definition and
slot synchronously; later challenges cannot be prefetched across earlier
transcript messages. Gate/up/down use different matrices, so they cannot
share this matrix read. Across independent proofs, same-matrix/model/profile/
calibration/shape identity, fresh masks/transcripts, preserved result order,
queueing latency and live commitments require explicit handling. No concurrency
scheduler, native proof-byte test, mask/RNG parity, verifier test or privacy
extension was implemented. P3/private weights need a separate design.

Sources and their precise date/license/commit limitations are in
`source-records.json`; search errors are in `search-log.json`. Recent sampled
proofs and older KZG preprocessing ideas do not establish an improvement here.
Next: inspect and test exact Karatsuba/specialized-square arithmetic at
`zkp-core/src/field.rs::Fp2::{mul,square}`, used by larger sumcheck phases;
do not spend the next cycle implementing a concurrency scheduler for this fold.
