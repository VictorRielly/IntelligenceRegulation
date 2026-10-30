# Conditional handoff: public-rho row-fold skipping

Cycle0147, `20261029T165649Z-7b8b834a`. No native proving gain measured.

Interface: existing `dev_fold_rows(dc,rhos)` and `k_fold_rows(data,rhos,out,
rows,n,k)`, max4 unchanged. Patch only the kernel to load public row weights,
skip a row if all active weights are zero, and skip individual zero-weight
MACs. Both limbs participate; no branch on private matrix values. Physical
output/row order, masks, pads, FS, verifier and all native pre-fold mask-site
assertions remain. No persistent cache or randomness/opening reuse.

Unapplied patch:
`experiments/multi-rho-rowfold-20261029/native-public-rho-skip.patch`.
Baseline pins, exact source bodies, CPU C++ shim, Rust independent reference,
commands and resource logs are in that directory. The inspected immutable
R14 core-build-2 checkpoint has the same four seam bodies as frozen R13;
R14 geometry is distinct from R13 count examples.

Validation:1,120 Rust fixtures/5,475,840 emulated output values/697,500
message+pad values/8controls/4paired emulator panics;288 exact-body C++ shim
fixtures/19,680limb outputs/3controls;139check patch/pin audit. Same researcher,
not external review. No CUDA compile/device arithmetic/ABI/register/race,
native proof, actual FS or independent native receipt verification.

First owner step is measurement, not integration: public rho nonzero/union
counts per batch, exclusive rho upload/allocation/kernel/download/host pad/
absorb/open/enclosing clocks. `dev_fold_rows` uploads rho but its local
stats adds only output `bytes_d2h`; account rho H2D explicitly. `secs_fold`
includes adapter work, not just kernel. The host fold already skips zeros.

No observed real support distribution or exclusive phase magnitude exists
here. Dense weights eliminate no loads/MACs; the dense proximity batch keeps
a full scan. Source live array payload increases64->128B/thread at4; compiled
registers/spills/occupancy and physical traffic unknown. All rho/output
transfer bytes remain. Batch8 counts are counterfactual: changing only
`chunks(4)` breaks the adaptermax4 contract. Do not apply that change.

If material, owner uses current reviewed shared build/heavy locks for CUDA
compile and controlled current-profile A/B. Require device field/output
oracle, golden/refusal/RNG/transcript/PCS/capture/privacy gates, independently
verified complete receipts and enclosing workload gain. Reject any mismatch,
compiler already eliminating zero work, missing real support, spill/peak
regression or no enclosing benefit. Global whole-proverGPU/resident evidence
still ranks above this candidate. Main/Claude reviews and integrates;
this handoff does not merge, activate a profile or authorize a heavy run.
