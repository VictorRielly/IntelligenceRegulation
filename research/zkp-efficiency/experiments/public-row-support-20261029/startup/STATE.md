# ZKP efficiency explorer — durable state

Cycle 0147 COMPLETE: `20261029T165649Z-7b8b834a`.
Started 2026-10-29 16:56:49 UTC; checkpoint 2026-10-29T17:14:12.890691+00:00.
Deadline 17:16:49 UTC. Next cycle no earlier than 17:56:49 UTC.
Read AGENDA.md every cycle. Prior state and complete histories are preserved
in experiments/multi-rho-rowfold-20261029/startup/.

No native proving improvement measured. A conditional kernel candidate skips
rows/products at zero public opening weights, including both field limbs.
Batch4, all output values/order, masks, pads, FS and verifier remain. No
persistent cache, private-value sparsity or mask/opening reuse. The host
already skips zeros. Frozen R13 and the inspected immutable R14 core-build-2
checkpoint have identical four seam bodies; their layout geometries differ.

1,120 Rust fixtures passed the extracted host fold and independent modular
reference: 5,475,840 emulated values, 697,500 message-plus-pad values, eight
controls and four paired emulator panics. Another 288 exact-body C++ CPU
shim fixtures compared 19,680 limb outputs with three controls. No CUDA
compile/device arithmetic/ABI/race/timing test or external review. Audit:
139 checks, 13 native/owner pins, two prior public metadata pins and exact
patch replay. Rust probe 0.469 s/7,800 KiB RSS; compile 1.628 s/160,724 KiB.
C++ probe 0.0093 s/7,956 KiB; compile 0.524 s/72,104 KiB. One CPU affinity,
nice19, 40 s CPU/45 s alarm/50 s parent, 384 MiB address-space cap.
Seed 202610290147. No arithmetic/test/build failure; warning retained.

Dense support eliminates no work. A dense proximity vector forces a scan.
Actual native support and exclusive cost are unknown. Source accumulator
plus temporary-weight payload grows 64 to 128 B/thread; compiled registers,
spills, occupancy and physical traffic are unmeasured. Source-derived R13
8B T128 A/H baseline: 37/10 rho without DD, 39/11 with DD; batch4 scans
10+3. Logical matrix bytes are 7,725,383,680 / 7,504,134,144 per core block.
Batch8 is counterfactual: 5+2 scans but unchanged total rho/output transfer
and MACs, doubled per-call rho/output allocation. Current adaptermax4 and
FR_MAX_K4 remain. No physical traffic, layer multiplier or token forecast.

Measurement finding: dev_fold_rows uploads rho but omits its bytes from the
local H2D counter update. Its fold timer encloses upload, allocation, kernel,
download and conversion. Owner next: public nonzero/union counts and
exclusive phase/pad/open/enclosing clocks, with transfer accounting fixed.
Only if material, use current shared locks for CUDA/register/spill checks,
native golden/refusal/RNG/FS/PCS/capture/privacy and independently verified
complete-receipt A/B. Main/Claude reviews and integrates; no heavy job queued.

All 64 prior hypothesis objects preserved. Global priorities remain:
1 whole-prover high-end GPU plus verified resident1/2/4/8 workloads;
2 admitted-context/DD/fidelity scaling; 3 exclusive phase/capacity clocks.
65 adds the conditional kernel; 66 asks about public-support dispatch and
physical grouping with original output order restored. Next local experiment:
actual source-derived structural A/H row-support census, retaining the dense
proximity floor. Do not adopt synthetic support distributions or private-value
sparsity. New measured owner bottlenecks take precedence.

Nine LIVE records appended, ledger 987. GPIR traffic/occupancy, June matched
memory-budget study, newly assessed 2016 multiple-RHS work, MAGMA batch
wrappers, October LP preprocessing and current Ethereum prover announcements.
MAGMA release diff commit 752e63cfb102e5de7e31cb9f2e35db7ed0842be4 inspected;
February19,2026 commit date verified. Master-file date/pin unknown; release
02Mar label has no year. BSD3 license body inspected. Airbender October13
announcement verified; release19Dec label lacks year/Prime association,
b93c285 observed only, MIT body inspected. Specific fetch failures retained.
No author performance reproduced or foreign source executed.

Latest owner R14 comparison explicitly covers a public sparse synthetic
2-block T128 diagnostic, shared host, n=1. Native review/privacy/security
remain owed; no trained 26-block or 8B high-end GPU acceptance. Current
D44/D45/R17 updates do not amend this research target. R13 8B T512 is still
unregistered at 94.48/94.80 bits. Six mandate/owner documents unchanged at
closing recheck.

New independently verified full-stack proofs / model passes / proved
positions: **0 / 0 / 0**. Actual model context / accelerator: **none**.
Device: one pinned Intel Core Ultra 9 185H CPU worker. Witness, proof,
serialization, verification, startup/prefill duration and fraction, proof
latency/bytes, steady-state and total-workload rates: **unmeasured**.
No prefill, resident-model proof series or decode ran. Larger workloads
remain allowed; dense attention can grow quadratically with context.
Complete private 8B >=50 proved tokens/s remains **unachieved**.

Carried older-profile CPU 8B baseline, not rerun/reverified/newly counted:
T128/L32, one16-thread pass, GPU off. Total478.737s=0.267370positions/s;
prove_run393.785s includes witness98.348s/load17.595s. Sealing84.824s precedes
it; its load27.151s/witness80.897s overlap. Receipt922,711,264B;
verify42.709s plus load13.681s. Isolated serialization/startup fraction and
steady slope unknown. No high-end GPU conclusion follows.

Experiment: experiments/multi-rho-rowfold-20261029/README.md.
Patch: experiments/multi-rho-rowfold-20261029/native-public-rho-skip.patch.
Handoff: handoffs/20261029-public-rho-rowfold.md.
Report: progress/20261029T165649Z-7b8b834a.md.
Only research outside runtime written; production/Git/receipts/calibration/
instructions/safety/reviewer files untouched. No GPU/native build/install/
foreign execution/external write/message/purchase/escalation/Git operation/
merge. Saved reports do not imply delivery or supervisor liveness.

Closing audit 2026-10-29T17:14:13.033785+00:00: 127 checks PASS; 116 experiment files hashed. Prior history/source records/hypotheses preserved; zero new model work.
