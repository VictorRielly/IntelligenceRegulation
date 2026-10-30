# ZKP efficiency explorer — durable state

Cycle 0151 COMPLETE: `20261029T205649Z-c620e79d`.
Started 2026-10-29T20:56:49Z; checkpoint 2026-10-29T21:08:10.387234+00:00; deadline 21:16:49Z.
Next cycle no earlier than 21:56:49 UTC. Read AGENDA.md every cycle.
Startup memory and hashes:experiments/public-indexed-fold-20261029/startup/
and memory-index.json. Prior findings and source ledger are preserved.

**No native proving improvement measured.** A sorted public row-index
loop and packed membership refinement match an independent dense arithmetic
reference. At frozen R13 8B/T128 A geometry, original-order noDD / DD plans
visit 9,654/9,328 rows instead of 45,770/44,550 per output column. Membership
reduces logical rho reads to 9,804/9,561 per column. Source matrix+rho+index
operands fall 50.393/51.385 GB → 4.468/4.340 GB, or 91.13%/91.55%, before
compiler/cache/broadcast effects. These counts are not physical traffic,
GPU timing or a complete-proof rate. Held R14 split geometry differs.

Useful negative result: reversing noDD groups reduces matrix union
visits 9,654→9,553 while raising plain-union logical operands 40.93%
(8.422→11.869 GB), because proximity shares a fuller batch. Matrix-only
packing is the wrong objective for that loop. Membership rho reads are
order-independent. Previous public packing passes, but remains a local
optimum with extra planning/copy/scatter costs.

Added costs: 38,616 / 37,312 B original-order plan upload, with 632.685/
611.320 MB source logical index reads across N16384 columns. Rho upload
2.710/2.780 MB, allocations, outputs/D2H, pads, commitments and all other
proof phases remain. Original-order Rust construction 0.286/0.276 ms and
validation 0.285/0.289 ms, n=1 on the shared CPU. Cache/broadcast, registers/spills and
occupancy are unknown. No numerical 8B GPU forecast is justified.

Validation: 14 Rust fixtures; 109,512 exact independent schoolbook modular
fold comparisons (16,416 source-row/narrow8), including three synthetic
pad columns; 376 controls; 1,206 independent Python set checks; 120 source/
artifact audit checks. Original/reversed/prior packed orders, imaginary-only
rho and numerical cancellations pass. Missing/duplicate/out-of-range/
unsorted indices, wrong/zero membership, missing masks/proximity/batches,
wrong scatter and stale order are rejected. Native define, FS, actual PCS
pad generation, CUDA, receipts and privacy acceptance were not tested.
The references are independent code by this researcher, not external review.

Ranked priorities: 1 owner complete high-end GPU proofs and verified
resident 1/2/4/8 workloads; 2 admitted context/DD/fidelity scaling; 3 exclusive
native phase/capacity clocks. The highest useful permitted local continuation
of prior #72 was tested. All 72 prior hypothesis objects remain unchanged;
#73 records packed membership; #74 asks about public consecutive-row/flag
intervals and density fallback. New owner bottleneck measurements take
precedence. Rotating categories are retained in rotation.json.

Next bounded local experiment: independent public run-length census
and exact interval/list/dense fold differential, with missing, overlapping,
truncated and out-of-range span controls, imaginary rho and reserved masks/
proximity. Charge interval construction, upload, nested-loop and register
costs; do not hardcode cached keys across changed calls.

Owner next: actual current public descriptor/group/support counters and
exclusive rho H2D/allocation/kernel/D2H/pad/open/enclosing clocks. R14 differs;
re-pin separately. dev_fold_rows can scan current public rho (both limbs)
for sorted packed row/membership words, no trait change. Source provenance
must be reviewed. candidate-kernel.cuh is uncompiled; native golden/refusal/
RNG/FS/PCS/privacy and full verified receipt/workload A/B remain owed under
owner current shared locks. Keep every fresh mask, pad, proximity, H sum/U,
output order and refusal. No private sparsity, mask/opening reuse or weaker
privacy. Main/Claude reviews/integrates; no production patch.
Ceiling N/(T-C_removed_exclusive+A_added), unknown exclusive f; free deletion
<=1/(1-f). Any native mismatch or no verified enclosing gain falsifies it.

Seed 202610290151. Compile 2.7368 s/187,744 KiB RSS; probe 0.9227 s/29,116 KiB;
census 0.0654 s/18,564 KiB; cost 0.0172 s/10,472 KiB; audit 0.0660 s/24,092 KiB.
One CPU affinity, nice 19, 40 s CPU / 45 s alarm / 50 s parent, 384 MiB address-space cap
per stage. Serial workers; compiler auxiliary thread count unmeasured,
one codegen unit/affinity. Estimated memory 300 MiB compile/96 MiB otherwise.
Initial borrow-check failure and prior passing results remain retained.
Source/hardware/command/hash manifests are in the experiment directory.

Five LIVE source records 1005→1010; eight raw captures. Newly assessed
October 2026 SpMV, August 2026 vector masks, older 2024 JIT/API and a GPU repository;
DeepProve release/license refreshed. Exact URLs, dates/nulls, license limits
and full text/Cachemiss blockers retained. No foreign execution/adoption or
external commit inspection. Six owner/mandate documents unchanged in audit.
Owner R14 state remains 19:14:14held pipelines, not liveness. Its two-block
public-sparse n=1 on the shared CPU result excludes setup/later verification; reviews/privacy
owed. D44/D45/S4 do not amend target. R13 8B/T512 unregistered 94.48/94.80 bits.

New independently verified full-stack proofs / passes / positions: **0 / 0 / 0**.
Actual context and accelerator: **none**; modeled context T128; one pinned
Intel Core Ultra 9 185H CPU worker. Witness, proof, serialization,
verification, startup/initial-prefill duration and fraction, proof
latency/bytes, steady-state and total-workload rates: **unmeasured**.
No prefill, resident-model series or decode ran. Larger workloads remain
allowed; attention can grow quadratically with context. Complete private
8B **>=50 proved tokens/s remains unachieved**.

Carried older CPU 8B baseline, not rerun/reverified/newly counted:
T128/L32, one 16-thread pass, GPU off. Total 478.737 s = 0.267370 positions/s;
prove_run 393.785 s includes witness 98.348 s/load 17.595 s. Sealing 84.824 s
precedes it, with overlapping load 27.151 s/witness 80.897 s.
Receipt 922,711,264 B; verify 42.709 s plus load 13.681 s. Isolated serialization,
startup fraction and steady slope remain unknown. No GPU conclusion.

Experiment:experiments/public-indexed-fold-20261029/README.md.
Handoff:handoffs/20261029-public-indexed-fold.md.
Report:progress/20261029T205649Z-c620e79d.md.

Only research outside runtime was written. Production, Git, receipts,
calibration, instructions, safety gates and reviewer files were untouched.
No GPU/native build, dependency install, foreign execution, external
write/message, purchase, privilege escalation, Git operation or merge.
Saved reports do not imply user-message delivery or supervisor liveness.
