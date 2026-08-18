# U-PERF2 lane K — THE GPU RUNG, step 1 (CONTINUATION Phase 3: CUDA on the reference box)

Branch `uperf2-k` (worktree /home/victor/wt-uperf2-k), opened at bd5e0dd on
2026-08-17. Ledger: PROGRESS_UPERF2.md "Round 6 ... Lane K" + "Agent K
status". This is the Phase-3 GPU rung report of CONTINUATION.md Section 4:
hardware named, watts stated, every number flagged [MEASURED] / [ASSUMED] /
[MODEL], what is bit-identical, what is left.

**Hardware (this box) [MEASURED, nvidia-smi 2026-08-17]:** NVIDIA GeForce RTX
4070 Laptop GPU, 8,188 MiB VRAM, sm_89 (Ada, 36 SMs), reached from WSL2
(driver 566.14, CUDA 12.7 driver API). Power: default limit 55.00 W, current
limit 68.82 W, max 105 W (a 50-70 W-class MOBILE part — the TARGET_CONTRACT
board is a <= 450 W desktop card; nothing here is a claim about that board).
Host: Intel Core Ultra 9 185H (6P + 8E + 2 LP-E, 22 threads), 15 GB.
Toolchain: NO CUDA toolkit; `cudarc 0.13.9` (driver + nvrtc, dynamic
linking) against the WSL libcuda and the pip-wheel NVRTC 12.x runtime
(`/home/victor/cuda-root`); kernels are CUDA C strings compiled at first use
by NVRTC (`src/ring/gpu/kernels.cu`).

## 0. One paragraph

(filled at the end)

## 1. What landed (files)

- `zkmatrix-rs/Cargo.toml`: feature `gpu-cuda` (default OFF) + optional
  `cudarc` dependency (`driver`, `nvrtc`, `cuda-12040`, `dynamic-linking`,
  `std`). The default build has no cudarc in its graph.
- `zkmatrix-rs/src/ring/gpu/mod.rs`: the module — feature-gated re-exports
  of the CUDA implementation, or a stub whose `enabled()` is a constant
  `false` (default build).
- `zkmatrix-rs/src/ring/gpu/cuda.rs`: device / NVRTC-compile-once
  singleton (`OnceLock<Option<Mutex<Gpu>>>`), `enabled()` = feature AND
  `ZK_GPU=1` AND a device initialized AND not bypassed, the mulmod probe,
  `ntt_batch` (battery transforms), `ntt_gemm_modq_small` (the port), the
  harness knobs (`set_bypass`, `set_block_mb`), stats.
- `zkmatrix-rs/src/ring/gpu/kernels.cu`: Goldilocks primitives, the length-128
  psi-twisted negacyclic forward / inverse NTTs (batched, shared-memory,
  transposed store), the D = 128 batched split-K GEMM with split-halves
  128-bit accumulation, the window flush (reduce -> inverse -> center -> mod
  q -> add).
- `zkmatrix-rs/src/ring/mod.rs`: `pub mod gpu;`.
- `zkmatrix-rs/src/ring/eval_proof.rs`: ONE hook at the top of
  `ntt_gemm_modq_small_gen` (`if gpu::enabled() { if let Some(o) =
  gpu::ntt_gemm_modq_small(..) { return o } }`). Nothing else.
- `zkmatrix-rs/src/bin/ring_matmul.rs`: `// [UPERF2-K]` section, `uperf-k
  probe | battery | bench`, registered in `main`.
- This report + "Agent K status" in PROGRESS_UPERF2.md.

## 2. Method (why the values are identical)

(filled with the port: the exact-integer window argument, the canonical
Goldilocks arithmetic, the split-halves 128-bit sums, the identical window
boundaries `ntt_window_terms(q, s_max)`.)

## 3. Differential evidence

(filled: `uperf-k battery` at ZK_THREADS 1/2/7, `uperf-pc diff-battery`
under ZK_GPU=1, the REAL rigs' digests.)

## 4. Measurements

(filled: probe; `uperf-k bench`; `uperf-pc kernel-bench 64 8192 noref` CPU
8T vs ZK_GPU=1; the REAL 3x16 / 12x128 / 12x512 rigs.)

## 5. What is left / honest state

(filled at the end.)
