# Public indexed rowfold — owner review only

Cycle 0151, run `20261029T205649Z-c620e79d`. **No native proving gain measured.**
FrozenR13 A structural supports and fresh synthetic public rhos support an
indexed rowfold model. R14 split geometry needs separate counters/pins.

At 8B/T128/N16384, original-order noDD / DD unions visit 9,654/9,328 rows
instead of 45,770/44,550 dense chunk4 rows per column. A packed
`u32 = row << 4 | membership` skips unsupported per-group rho loads too:
9,804/9,561 logical rho reads per column. Source matrix+rho+index accounting
falls50.393/51.385 GB → 4.468/4.340 GB. These are logical operands before
compiler/cache/broadcast, **not physical traffic, time or whole-proof rates**.

Charge38,616 / 37,312 B plan allocation/upload and632.685/611.320 MB logical
per-column index reads. All2.710/2.780 MB rho uploads, outputs/D2H, pads,
fresh masks/proximity, encodings/commitments and other proof phases remain.
Original-order plan construction/validation each0.28 ms n=1, shared CPU; no
device result. Reordering is optional and adds planning/clone/scatter costs.
Negative control: reversing noDD order decreases union visits but increases
plain-union logical operands 40.93%; matrix-only packing is not that loop's
correct cost objective. Membership rho reads are order-independent.

Actual source seam:
`fold_rows_multi_zk → EncodedStore:: fold_rows → dev_fold_rows → k_fold_rows`.
Current `dev_fold_rows` already has the public opening rhos, max4.
`build_public_rho_plan` in
`experiments/public-indexed-fold-20261029/indexed.rs` scans both limbs and
can avoid a PCS trait change. The public provenance must be reviewed; never
pass a private witness vector. `candidate-kernel.cuh` is an uncompiled CUDA
sketch, not a tested production patch. `seam-pins.json` pins current files.
Main/Claude owns integration; no production changes were made.

Owner integration requirements: register the kernel name, upload sorted
unique packed row/flags per current call, preserve rho/output layouts and
plan-buffer lifetime through synchronized D2H. Require rows<2^28 and valid
flags; retain a dense fallback. Preserve native length/audit/mask-site
checks, refusals, output order, same-slot fresh masks, proximity, H sum/U,
RNG/FS/PCS and pads. No private sparsity, cached changed-key plans or reuse
of masks/commitments/openings. No privacy acceptance is implied.

Validation: 14 Rust fixtures, 109,512 independent schoolbook modular comparisons
including3synthetic pad columns, 16,416 source-row/narrow8 values; 376 controls;
1,206 independent Python set checks. Original/reversed/prior packed orders,
zero/one/random points, imaginary-only public rho and numeric cancellations
pass. Missing/duplicate/out-of-range/unsorted row entries, wrong/zero flags,
missing masks/proximity/batches and wrong/stale order are rejected. Small
shapes and zero-coefficient fixtures are not admitted native proofs. Native
define, FS, actual PCS pads, CUDA and complete receipts were not executed.

Seed 202610290151. One pinned Intel Core Ultra9 185H CPU worker, 384 MiB
address-space cap, 40 s CPU / 45 s alarm / 50 s parent per stage; compile2.7368 s,
probe 0.9227 s. Compiler auxiliary threads unmeasured, one codegen unit/affinity.
Logs, hashes, earlier failure/pass and commands are in the experiment README.

First obtain current public support/group counters and exclusive rho H2D,
allocation, kernel, D2H, pad/open/enclosing clocks. `secs_fold` combines work;
existing aggregateH2D misses rho upload. Re-pinR14 separately; do not touch
or duplicate its held pipelines. If material, owner uses current shared
build/heavy locks for actual CUDA/register/spill/cache checks and native
golden/refusal/RNG/FS/PCS/privacy, independently verified full-receipt and
resident 1/2/4/8-workload A/B. No GPU job launched here.

Ceiling `N/(T-C_removed_exclusive+A_added)`, unknown exclusive fraction f;
free deletion≤`1/(1-f)`. Promotion fails on any native support/value/order/
limb/refusal/mask/RNG/FS/PCS/privacy mismatch, overhead erasing gain, or no
verified whole-workload benefit. No numerical high-endGPU8B forecast.

Next local: public consecutive-row/membership run census and exact interval
fold versus list/dense, with truncated/overlapping/missing/bounds controls.
Owner measured bottlenecks can supersede this queue.

New independently verified full-stack proofs/passes/positions0/0/0.
Actual context/accelerator: none; modeledT128, one CPU. Witness/proof/
serialization/verification/startup/prefill clocks, fraction, latency/bytes,
steady-state and total-workload rates unmeasured. No prefill, resident series
or decode. Larger workloads allowed; attention can grow quadratically.
Private8B>=50provedtokens/s remains unachieved.
