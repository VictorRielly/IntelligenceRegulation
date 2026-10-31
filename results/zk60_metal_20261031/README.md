# Metal (Apple GPU) commitments: M0–M2 on the M3 Ultra, 2026-10-31

Lane tree: `ops/zkp-mvp/gpu-metal/` (a copy of `ops/zkp-mvp/gpu-classifier/`, i.e. production r19b plus the
GPU lane's classifier changes, with the Metal backend added). Plan: `docs/zkmatrix-poc/ZK60_METAL_PORT_PLAN.md`.
Labels: [MEASURED] = this Mac, n = 1, shared with Sol and Astra (every run through the resource guard).

## Plain words for Victor

- **The prover's commitments now run on the Mac's GPU, and the proofs come out byte for byte the same.** Four
  full block proofs (TinyLlama and Llama-3-8B shapes at 128 tokens, with and without DD) made with Metal
  commitments equal the proof digests recorded on the Linux laptop in September.
- **On this Mac the commitment step is about 2x faster on the GPU than on its 32-core processor.** The processor
  itself is fast: one 8B-geometry block proves in about 4.7 s here, against about 12 s per block on the laptop.
- **The commitments are only about 14% of a block.** The five zero-checks are about 60%, so they are the next port.
- Nothing here changes a proof, a statement or a security property. The CPU stays the reference.

## What was built (all in the lane tree)

| File | Change |
|---|---|
| `hashline/src/gpu/metal_kernels.metal` | MSL kernels: Goldilocks add/sub/mul (32-bit-limb 64x64 product, `reduce128` line for line); the staged NTT (M1 reference); the fused two-pass NTT (head: bit-reversed gather + row initialization + 11 stages in threadgroup memory; tail: the remaining stages on strided groups); the full BLAKE3 tree per column (plain and keyed); the row fold (Fp2 x Fp); the column gather |
| `hashline/src/gpu/metal.rs` | Device setup, run-time compilation (no Xcode toolchain), plain and hiding commit pipelines, `MetalCommit` store (encoding in unified memory) |
| `hashline/src/gpu/mod.rs` | `gpu-metal` seam: `MetalBackend` implements zkp-core's `Backend`; `enabled()` / `label()` for Metal; CUDA wins if both features are on |
| `hashline/src/stable_weight_material.rs` | the uninhabited-store match widened to `any(gpu-cuda, gpu-metal)` |
| `hashline/Cargo.toml`, `Cargo.lock` | feature `gpu-metal`; macOS-only optional `metal = "=0.29.0"`, `objc = "0.2.7"` |
| `zkp-core/src/pcs/backend.rs`, `pcs.rs` | `EncodedStore::fold_batch()` (default **4**, the CUDA store's existing batch, so CUDA behaviour is unchanged); Metal returns all vectors in one fold |
| `hashline/tests/zk60_metal_commit.rs` | the equality gates below, and the `m2_` timing bench |

Runtime switches: `HL_GPU=1` (use the device), `HL_GPU_REQUIRED=1` (fail closed on any decline),
`HL_METAL_STAGED=1` (M1 per-stage NTT), `HL_METAL_DEVICE_FOLD=1`, `HL_METAL_HOST_GATHER=1`, `HL_METAL_TIMING=1`.

## Gates (all pass)

| Gate | Evidence |
|---|---|
| M0 field: add / sub / mul on 144 edge pairs + 100,000 random | `logs/m1_test1.log` |
| M1 plain commit: leaves, Merkle root, gathered columns, row folds; 9 shapes, 1–17 BLAKE3 chunks per column, rates 2/4/8 | `logs/m1_test1.log`, re-run on every change (`logs/*_eq*.log`) |
| M1 hiding commit, unkeyed and keyed: salted root AND the complete `open_zk` bytes and transcript state equal the CPU's; 9 shapes each, including q > n | same |
| Both NTT paths (fused default and `HL_METAL_STAGED=1`) | `logs/m2_eq_fused.log`, `logs/m2_eq_staged.log` |
| Both fold paths (host default and `HL_METAL_DEVICE_FOLD=1`) | `logs/cols_eq0.log`, `logs/cols_eq1.log` |
| **Full block proofs, seeded (`r12_golden_tests`), 4 / 4:** Mac CPU == Linux-recorded digests, and Metal (`HL_GPU_REQUIRED=1`, 0 declines) == the same digests | `golden_m1_staged/` (M1 kernels), `logs/golden_*` (fused kernels) |
| 8B-geometry block (`ladder8b`, T128): block digest `8b6144ea…` equal on CPU and Metal; prove + fresh verify pass | `logs/ladder8b_*.log` |

## Measurements [MEASURED, n = 1, shared box]

Keyed hiding commitment alone (`m2_keyed_commit_timing_at_block_sizes`; roots equal):

| Shape (rows x 2^log_cols, rate 4) | Encoded | Mac CPU (32 threads) | Metal, fused | Speedup |
|---|---:|---:|---:|---:|
| 4,608 x 2^14 (Shieldstral T128 A size) | 2.42 GB | 0.451 s | 0.219 s | 2.06x |
| 4,608 x 2^15 | 4.83 GB | 0.894 s | 0.394 s | 2.27x |
| 9,216 x 2^15 | 9.66 GB | 1.727 s | 0.875 s | 1.97x |

Of the Metal time, the GPU part is about half (inverse NTT 0.019 s, forward 0.074 s, hash 0.006 s at the
first shape); the rest is buffer setup and the core's CPU-side pad/salt draws, salting and Merkle tree.
The first, per-stage M1 NTT was 1.16–1.34x: it made 16 passes over memory at about 730 GB/s.

One Llama-3-8B-geometry block at T128 (`ladder8b`, synthetic dense weights, phase clock `HL_PB_TIMING=1`):

| Phase | Mac CPU | Metal commitments |
|---|---:|---:|
| A + H commitments | 0.653 s | 0.292 s |
| five zero-checks (D, F, softmax, Q, KV) | 2.814 s | 2.57–2.81 s (unchanged code) |
| H helper inverses | 0.324 s | 0.30 s |
| openings A + H (after the GPU column gather) | 0.182 s | 0.184 s |
| **block wall (phase clock)** | **4.663 s** | **4.348 s** |

For comparison, the laptop proved the 32-block 8B T128 stack in 393.8 s (about 12.3 s per block, 16 threads).
These are block diagnostics: no full-stack Mac run exists yet (the 8B exports stayed on the laptop).

## Open items

1. **Backend label.** `trained_block.rs::backend_of_this_process` knows only the CPU and CUDA names, so a
   Metal-made run statement would say "built without gpu-cuda". Adding a Metal name changes what verifiers
   accept and needs Sol's lane and a review before any Metal-made receipt is published.
2. **Zero-checks on Metal** (about 60% of a block): next rung (M3).
3. Buffer pooling (setup is about 15% of the Metal commit time).
