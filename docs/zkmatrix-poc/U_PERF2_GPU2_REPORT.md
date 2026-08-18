# U-PERF2 lane L — THE GPU RUNG, step 2: the K-field lane kernels on the device (fused descent round, ixf round + fold, tree step)

Branch `uperf2-l` (worktree /home/victor/wt-uperf2-l), opened at f821485 on
2026-08-17. Ledger: PROGRESS_UPERF2.md "Round 7 ... Lane L" + "Agent L
status". This continues lane K's Phase-3 GPU rung (U_PERF2_GPU_REPORT.md:
the plumbing, the one-hook discipline, the honest-framing rules): hardware
named, watts stated, every number flagged [MEASURED] / [ASSUMED] / [MODEL].

**Hardware (this box) [MEASURED, nvidia-smi 2026-08-17]:** NVIDIA GeForce RTX
4070 Laptop GPU, 8,188 MiB VRAM, sm_89 (36 SMs), reached from WSL2 (driver
566.14, CUDA 12.7 driver API); power limits 55 W default / 68.82 W current /
105 W max (a 55-70 W-class MOBILE part — nothing here is a claim about the
TARGET_CONTRACT's <= 450 W desktop board). Host: Intel Core Ultra 9 185H (22
threads), 15 GB. Toolchain as lane K's: no CUDA toolkit; `cudarc 0.13.9`
(driver + NVRTC), the kernels are CUDA C strings compiled at first use.

Every wall-clock number below is `[WSL-BOX NT NOISY-SHARED]` unless marked —
lane M builds and runs concurrently the whole session; the CPU/GPU pairs
are taken back-to-back in ONE binary (`ZK_GPU` unset vs `ZK_GPU=1`, or the
in-process bypass), so the ratios are what to read.

## 0. One paragraph

(filled at close)

## 1. Plan (skeleton commit)

Files: `zkmatrix-rs/src/ring/gpu/{mod.rs, cuda.rs}` (extend lane K's
plumbing: the singleton, `enabled()`, knobs), NEW `gpu/k9.rs` (the host side
of the K-field lane kernels: device-resident chains, pipelined uploads,
the handover protocol) + NEW `gpu/kernels_k9.cu` (the device code: the K =
Z_q[Y]/(Y^16 - s) lane arithmetic on u32 coefficients — the 16x16
schoolbook with lane J's burst accumulation and canonical reductions, the
fused fold / extract / extract-fold rounds, the ixf round, the fold, the
tree step, the compact-leaf expansion), ONE additive hook line at the top
of `kfield::k9_fused_round_par`, `kfield::k9_ixf_round_par`,
`KField::kt_fold_par`, `kfield::k9_tree_climb_par` (nothing else in
kfield.rs), a `// [UPERF2-L]` bin section with `uperf-l {battery, bench}`,
this report, "Agent L status".

Order: (1) the fused masked-descent round (FUSE_FOLD / FUSE_EXTRACT /
FUSE_EXTRACT_FOLD) with the layer's tables device-resident for the pair's
layer (the tree layer or the compact leaves uploaded once per layer, read
by rounds 0 and 1 on the device; the state-1 tables produced on the device
and folded there round after round; only the round outputs come back; the
host tables written at the handover), (2) the ixf sumcheck round + fold
(the claim layer's tables resident across the round/fold chain), (3) the
tree step (the climb from the checkpoint / compact leaves). Each: one hook,
`oracle_mode()` and `ZK_GPU=0` keep the CPU path; batteries `uperf-a` 18/18,
`uperf-g` 22/22, `uperf-h` 24x8, `uperf-d` 30/30, `uperf-j` under `ZK_GPU=1`
+ `uperf-l battery` cell-by-cell at the kernel level; the descent-bench
digest; the rigs with `ZK_GPU=1`.

## 2. Method (why the values are identical)

(filled as the items land)

## 3. Differential evidence

(filled as the items land)

## 4. Measurements

(filled as the items land)

## 5. What is left / honest state

(filled at close)
