# Public-rho row-fold skipping — cycle0147

Run `20261029T165649Z-7b8b834a`, October29,2026. **No native proving gain
measured.** This bounded experiment checks a device-kernel candidate that
skips a matrix row when every public row weight in the current batch is zero,
and skips individual zero-weight products. It keeps batch4, the original
matrix/output indexing, every output vector and the original row order.

The actual seam is `pcs::fold_rows_multi_zk -> EncodedStore::fold_rows ->
dev_fold_rows -> k_fold_rows`. The host fold already skips zero row weights;
this patch affects only the device kernel. R13 and the inspected immutable
R14 core-build-2 checkpoint have identical host/wrapper/adapter/kernel bodies.
R14's new split-width layout is a different geometry; R13 count examples
below are not R14 counts. No production file changed.

The baseline kernel reads every row once per chunk of at most4 rho vectors,
then performs every group's Fp2-by-base-field multiply-add, including zeros.
The candidate reads the same current-call public weights into `rw[4]`, checks
their union, and then reads the matrix only for an active row. Both limbs
participate in every zero check. It never decides from a private matrix word.

The candidate adds zero tests, uniform control and a temporary row-weight
array. Source `acc+rw` payload is128B/thread versus64B for baseline `acc`;
compiled register allocation, load elimination, spills, occupancy, physical
traffic and enclosing time are all unknown. No persistent cache or mask,
challenge, pad, salt, opening or proof-result reuse is introduced. The
existing mask-site assertion runs before this kernel; verifier, FS, pad fold,
logical vector order, column queries and all proof work are unchanged by
the unapplied patch.

Differential evidence:

- 1,120 Rust fixtures: rows0/1/3/9/33, columns1/7/31/513,
  rho counts0/1/2/4/5/8/11, eight public support patterns. The unchanged
  extracted host fold (only Rayon iterator adapted serially), a direct
  independent u128 modular reference, and dense/sparse kernel emulations
  agree. 5,475,840 emulated output values,697,500 message-plus-pad values,
  systematic-stride checks,8 negative controls and4 paired emulator panics.
- 288 C++ fixtures compile the exact extracted baseline/patched kernel
  bodies with a CPU thread-index and modular-arithmetic shim. 19,680 scalar
  limb outputs agree with a row-first reference. Three additional controls
  cover pure-imaginary rho, a changed live private word, output bounds and
  overlaunch threads. Overlaunch is also exercised on every fixture.
- This is same-researcher independent-reference evidence, not external
  review. The C++ shim does not compile CUDA or test native GPU arithmetic,
  device ABI, registers, races or timing. The Rust batch8 arm is counterfactual;
  the actual adapter remains capped at4. Primitive all-zero/empty fixtures
  are algebra edges, not accepted masked openings or complete proofs.
- Audit:139 checks,13 native/owner pins plus2 prior public metadata pins,
  exact patch replay in memory, four R14 seam equality checks. The owner
  reports are mutable snapshots, not asserted unchanged forever.

The 257-row/17-column/37-rho support study illustrates the limits. With
batch4, dense weights retain43,690 matrix loads and161,653 MACs in both arms.
Disjoint supports plus one dense proximity vector change those source counts
to8,636 loads/MACs. A different quarter-density pattern still reads40,426
matrix words. These are deliberately synthetic distributions; actual native
support incidence has not been measured. A dense proximity vector forces
at least one full matrix scan for its batch. No synthetic saving is adopted
as a real profile result.

Source-derived R13 8B T128 A/H count examples, including one proximity rho
per commitment:

| Geometry | A/H rhos | Batch4 passes A+H | Batch4 logical matrix bytes | Rho H2D | Output D2H |
|---|---:|---:|---:|---:|---:|
| noDD |37/10|10+3|7,725,383,680|3,411,984|12,320,768|
| DD32 |39/11|10+3|7,504,134,144|3,525,104|13,107,200|

These are source logical loads, not measured DRAM. They exclude host pads,
matrix construction and all other proof phases. No layer multiplier applied.
Counterfactual batch8 makes5+2 passes and4,150,394,880/4,029,546,496 logical
matrix bytes, while retaining the same total rho upload, output download and
MAC count. Its largest per-call rho+output device allocation doubles; summed
A/H maxima are not simultaneous peak savings. Merely changing `chunks(4)`
to8 is invalid: `FR_MAX_K` and the adapter assertion also cap at4.

An additional source measurement issue: `dev_fold_rows` explicitly uploads
rho via `htod_sync_copy`, but its local aggregate stats update adds only
`bytes_d2h`, omitting this rho upload from `bytes_h2d`. Its `secs_fold`
encloses upload/alloc/launch/download/conversion; it is not kernel-only time.

Whole-workload ceiling: `N/(T-C_removed_exclusive+A_added)`. The exclusive
native rowfold fraction is unknown, so no numerical 8B token-rate forecast
is supported. Free deletion of a measured fraction f would be bounded by
`1/(1-f)`. Dense support, compiler elimination of zero work, register spills,
or no enclosing benefit would falsify a speed advantage. Any value, limb,
order, pad, refusal, RNG, transcript, PCS or privacy mismatch rejects it.

Commands, each separately run from the research directory:

```text
python3 experiments/multi-rho-rowfold-20261029/run_bounded.py prepare
python3 experiments/multi-rho-rowfold-20261029/run_bounded.py compile
python3 experiments/multi-rho-rowfold-20261029/run_bounded.py probe
python3 experiments/multi-rho-rowfold-20261029/run_bounded.py compile-cpp
python3 experiments/multi-rho-rowfold-20261029/run_bounded.py probe-cpp
python3 experiments/multi-rho-rowfold-20261029/run_bounded.py account
python3 experiments/multi-rho-rowfold-20261029/run_bounded.py audit
```

Seed202610290147. One CPU affinity, nice19,40s CPU/45s alarm/50s parent
timeout,384MiB address-space cap. Rust compile1.628s/160,724KiB RSS;
Rust probe0.469s parent/0.445561s internal,7,800KiB RSS. C++ compile0.524s/
72,104KiB; probe0.00929s/7,956KiB. Estimates320MiB Rust compile/96MiB other
stages. Rust1.75 opt1, g++11.4 opt1, Python3.10.12, one Intel Core Ultra9
185H worker on WSL2. Auxiliary compiler threads not measured; oneCPU
affinity and one Rust codegen unit. A harmless C++ indentation warning is
retained. No arithmetic/test/build failure occurred.

LIVE sources and exact dates/license/commit boundaries are in
[sources-cycle.jsonl](sources-cycle.jsonl), with raw web batches. The
[GPIR paper](https://arxiv.org/html/2604.04696v2) motivates measuring traffic
and occupancy together; its PIR performance is not proof performance. The
[older multiple-RHS work](https://arxiv.org/abs/1601.03184) motivates reuse,
but native already batches4. Inspected MAGMA wrappers select independent
batched matrices; their floating kernels are not native field replacements.
The October LP preprocessing and current Ethereum prover announcements
are architectural screens only. No foreign source was executed.

Global priorities remain:1 owner whole-prover high-endGPU and independently
verified resident1/2/4/8 workloads;2 admitted-context/DD/fidelity scaling;
3 exclusive phase/capacity clocks. All64 prior hypotheses are preserved;
65 adds this conditional candidate,66 asks about public-support dispatch.

Owner next: collect only public support density/union counts and exclusive
rowfold upload/allocation/kernel/download/pad/open clocks. If material,
compile unchanged-batch4 candidate under current shared build/heavy locks,
measure compiled registers/spills and run native golden/refusal/RNG/FS/PCS/
capture/privacy plus independently verified full-receipt A/B. Main/Claude
reviews and integrates; nothing is merged or queued here.

Next local experiment: source-derived public structural row-support census
at actual A/H claim layouts, retaining a dense proximity floor. Do not infer
support from witness values or transfer synthetic distributions. New native
measurements take precedence.

New independently verified full-stack proofs/model passes/proved positions:
**0/0/0**. Actual model context/accelerator:none. Witness, proof,
serialization, verification, startup/prefill duration/fraction, proof
latency/bytes, steady-state and total-workload rates: **unmeasured**.
No long-context prefill, resident-model pass series or decode ran. Larger
workloads remain allowed; attention may grow quadratically with context.
The complete private8B >=50 proved-token/s target remains **unachieved**.

Only research outside runtime was written; no production/Git/receipts/
calibration/instructions/safety/reviewer edits, GPU, native build,
installation, external write/message, purchase, escalation, Git operation
or merge. Saved reports do not imply user delivery or supervisor liveness.
