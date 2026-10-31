# Metal (Apple GPU) port plan for the hash-line prover

Written 2026-10-31 by Claude on the M3 Ultra Mac Studio, after the move off the WSL laptop.
Status: **PLAN ONLY. No Metal code exists yet; nothing below is measured on the Apple GPU.**
Labels follow the GPU lane: [MEASURED], [COUNTED] (read from source), [MODEL] (estimate).

## Plain words for Victor

- The prover's GPU code is written for NVIDIA (CUDA). The Mac's GPU cannot run it as it is.
- The CUDA code is a contained piece: about 50 small GPU programs (kernels) plus the Rust code that
  launches them, all behind one switch in the prover. Every GPU result must equal the CPU's
  byte for byte, so the CPU prover stays the referee.
- Porting it to Apple's GPU language (Metal) is a translation, not a redesign. The field arithmetic
  is 64-bit (Goldilocks) and the hash is BLAKE3. Both run on Apple GPUs.
- The Mac has two real advantages. Its GPU shares the 256 GB of memory with the processor, so the
  31 GB of uploads per proof that the laptop measured disappear. By the published specifications its
  memory bandwidth is about 3x the laptop GPU's (819 against 256 GB/s; not measured here).
- Its weakness is 64-bit multiplication, which Apple GPUs do in several 32-bit steps. How much that
  costs is the first thing to measure.
- Suggested order: the commitments first (they already work on CUDA and gave 1.37x), then the
  zero-checks. A first measured Metal number is the milestone, not a speed promise.

## 1. What has to be ported [COUNTED, ops/zkp-mvp/gpu-classifier and gpu-zerocheck trees]

| Piece | Size | Notes |
|---|---|---|
| `hashline/src/gpu/kernels.cu` (classifier tree) | 1,643 lines, 40 kernels | NTT passes, DIT pad kernels, column gather/fold, BLAKE3 column hashing (plain, keyed, streamed), sumcheck round/fold kernels, table builders, helpers |
| `hashline/src/gpu/fzc_kernels.cu` (zero-check tree) | 979 lines, 10 kernels | the paused fused zero-check lane |
| `hashline/src/gpu/cuda.rs` | 3,967 / 5,040 lines | cudarc driver + NVRTC runtime compilation, buffer pools, the declined-to-host fallbacks |
| `hashline/src/gpu/mod.rs` | ~780 lines | backend selection; `HL_GPU`, `HL_GPU_REQUIRED`, decline counting |

The seam already exists. `zkp_core::pcs::backend::Backend` (`try_commit`, `try_commit_zk`,
`try_commit_zk_keyed`, ...) has a CPU implementation and `CudaBackend`. A `MetalBackend` behind a new
`gpu-metal` cargo feature implements the same trait, so no proof logic changes.

CUDA features the kernels use [COUNTED in kernels.cu]: `__shared__` (27), `__syncthreads` (34),
`__umul64hi` (2), `__popc` (3). No warp shuffles, no atomics, no cooperative groups, no inline
assembly. All have direct Metal equivalents: threadgroup memory, `threadgroup_barrier`, `mulhi` on
`ulong`, `popcount`.

## 2. Approach

- **Kernel source.** Translate each `.cu` kernel to MSL (Metal Shading Language) by hand. Keep the
  same names and launch geometry so the two can be diffed. Compile at run time from source with
  `newLibraryWithSource` (the NVRTC analogue), so the build needs no Xcode `metal` toolchain.
  Command-line tools alone are installed here.
- **Rust binding.** `objc2-metal` (or `metal-rs`) behind `gpu-metal`. Default builds stay CPU-only.
- **Memory.** `MTLStorageModeShared` buffers wrap host data with no copy where alignment allows.
  This removes the upload phase the CUDA path pays.
- **Field arithmetic.** One MSL header for Goldilocks add, sub, mul and reduce, plus Fp2. It is
  unit-tested against `zkp_core::field` on random and edge values (0, p-1, 2^32, epsilon) before
  any kernel uses it.
- **Gates, unchanged from the GPU lane (`results/zk60_gpu_classifier_20261030/GPU_PORT_PLAN.md` §1):**
  1. device == CPU unit equality per kernel;
  2. rung single prove under fixed entropy, every file equal;
  3. real-scale job-0 prove, all 30 files equal to the recorded digests;
  4. fresh verify of the Metal-made receipt by the frozen CPU binary;
  5. `HL_GPU_REQUIRED=1` with 0 declines, peak GPU memory recorded via the guard's Apple GPU telemetry.

  Gates 2 and 3 need the fixtures that stayed on the WSL box (see the bring-up record). Until they
  are recovered or regenerated, gate 2 can use a freshly generated fixed-entropy rung whose CPU
  digests are recorded on this Mac first.

## 3. Phases [MODEL effort, agent-days]

| Phase | Content | Effort |
|---|---|---|
| M0 | `gpu-metal` feature, device probe, run-time compile, Goldilocks header + unit equality, one trivial kernel round trip | 1-2 |
| M1 | Commitment path: NTT p1/p2 variants, DIT pad kernels, gather/fold, BLAKE3 column hashing; `try_commit*` on Metal; gates 1-5 | 5-8 |
| M2 | Measure M1 against the Mac CPU path; profile 64-bit multiply cost; decide whether a 32-bit-limb Montgomery variant is needed | 1-2 |
| M3 | Zero-check round/fold kernels and table builders (the GPU lane's item 2), behind the same IR-driven generator the lane planned, emitting MSL as well as CUDA | 6-10 |
| M4 | Witness kernels (item 1), only after Sol's witness-builder seam (R15) lands | 5-8 |

## 4. What this does not change

- The CPU prover remains the reference; byte identity is the only acceptance.
- The RTX 5090 remains the throughput target machine for the >=50 proved tokens/s goal. A Metal
  backend is a second device path, not a substitute for that target.
- Privacy statements carry over only through byte-identical receipts (D53 reading), as on CUDA.

## 5. Open questions for Victor

1. Start M0-M1 now on the Mac, or keep GPU effort on CUDA until the 5090 is up?
2. Who owns the Metal lane: a Sol lane, or Claude as the GPU lane's continuation?
