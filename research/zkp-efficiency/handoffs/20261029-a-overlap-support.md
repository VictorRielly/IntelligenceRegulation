# A source-support census and bounded packing — owner review only

Cycle0150, run `20261029T195649Z-795daf31`. **No native proving gain measured.**
Frozen R13 8B/T128 public descriptors were derived and differentially checked;
native `define`, native FS, CUDA and complete proofs were not run. R14 has
a different split-width layout and needs a separate pin/census.

At N16384, A's dense chunk4 visits45,770/44,550 (noDD/DD32) become
structural support9,654/9,328:78.9076%/79.0617% fewer logical matrix reads
with the prior zero-skip kernel. With prior H source support, combined A/H
reductions are68.7275%/69.1085%. A has508/509 data rows in more than one
evaluation group; do not assume H's disjointness. All masks/proximity remain.
Corner points can merge groups and change opportunity. No physical traffic
or 8B throughput follows from these counts.

Optional pair-swap packing finds5,658/5,794 A visits in7/10 swaps, not a
global optimum or a device-time optimum. Python planning17.9/27.3ms n1;
copying current slice-of-Vec rho API adds2,709,584/2,779,920B, or active
streamed clone payload292,928/285,120B. Inverse scatter is mandatory.

The baseline/candidate kernel seam is:
`fold_rows_multi_zk -> EncodedStore::fold_rows -> dev_fold_rows -> k_fold_rows`.
Prior unapplied patch:
`experiments/multi-rho-rowfold-20261029/native-public-rho-skip.patch`.
This cycle's metadata/algorithm interfaces are `schedule`/`supports` in
`experiments/a-overlap-support-20261029/harness.rs`, independent
`inventory`/`group_plan` in `census.py`, and retained `packing_plans.rs`.
No production patch or integration was made. Main/Claude owns integration.

Before considering a device test, record actual current public descriptors,
group/support/nonzero/chunk-union counts and exclusive rho H2D, allocation,
kernel, D2H, pad, opening and enclosing clocks. Prior adapter aggregate H2D
stats omit rho upload; `secs_fold` includes more than the kernel. No counter
may export private matrix values. Re-pin current accepted profile/source.

The zero-skip kernel retains every row scan and public rho load. Source
matrix+rho operand reductions are only9.3938%/8.9843%, before compiler,
cache and warp broadcast. Source accumulator+weight payload doubles64→128B
per thread; actual registers/spills/occupancy are unknown. Even a large
matrix/MAC reduction can fail to improve the enclosing proof.

Validation:14 Rust fixtures,27,540,288 independent full-cube coefficients,
5,172 restored synthetic message-plus-three-pad-column values,380 source-row
five-column base-field values using actual source plans,62 controls;
517 independent Python descriptor/offset/support/packing checks;64 artifact
and exact-helper checks. Small shapes are synthetic and unadmitted. Actual
native PCS pad generation, FS, receipt and privacy validation are not covered.
Seed202610290150; source hashes, bounded commands, hardware and failed runs
in the experiment README/manifests. One CPU affinity, all stages<3s and
<184MiB RSS,384MiB address-space caps; no GPU/native build.

Keep every current native audit/refusal, same-slot fresh masks, pads,
proximity, H sum/U, output/claim order, RNG/FS/PCS and complete coverage.
Do not use private sparsity or reuse masks, commitments or openings. Native
byte/golden/RNG/transcript/refusal/privacy and independently verified full
receipts remain prerequisites; use current shared build/heavy locks. Do not
launch from this research report or duplicate held owner pipelines.

Whole-workload ceiling `N/(T-C_removed_exclusive+A_added)`; exclusive f is
unknown, free deletion≤`1/(1-f)`. Promotion is falsified by any descriptor,
coefficient/value/limb/order/mask/pad/refusal/RNG/FS/PCS/privacy mismatch,
spills/copy/planning costs erasing gain, or no independently verified
whole-workload benefit.

Next local refinement: test a sorted public row-union index loop to remove
empty scans/rho loads. Original-order A index payload38,616/37,312B;
packed22,632/23,176B, including dense proximity. Add API/upload/indirection
and cache costs; no indexed kernel has been tested. Owner measurements
can change this priority.

No new verified full-stack proofs/passes/positions:0/0/0. Actual context
and accelerator:none; modeledT128, one pinned Intel Core Ultra9 185H worker.
All witness/proof/serialization/verification/startup clocks, startup fraction,
proof latency/bytes and both throughput rates are unmeasured. No prefill,
resident series or decode. Complete private8B>=50 proved tokens/s unachieved.
