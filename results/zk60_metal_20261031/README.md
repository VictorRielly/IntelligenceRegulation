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

## M3: the zero-checks on the Apple GPU (2026-10-31, later the same day)

- **What:** each slot's polynomial is generated as Metal source from the slot expression IR
  (`private_block/slot_ir.rs`, now also compiled under `gpu-metal`; codegen in `private_block/metal_slot.rs`).
  The IR is built per slot on a CLONE of the transcript taken just before `define`, so it reads the challenge
  values `define` draws and the real transcript is untouched. A generic device sumcheck (`gpu::MetalRounds`)
  keeps the tables in GPU memory, runs each round with the generated kernel and folds on the device; it
  implements zkp-core's `SumcheckRounds` with the CPU evaluator's exact s(1) rule.
- **Runtime guard:** before a slot may run on the GPU, the IR is evaluated against THIS definition's closure
  at eight pseudo-random points of the whole space (local generator, no proof randomness). A slot that fails,
  or has no IR, stays on the CPU. On the DD profiles slot 17 (DD redefines it) stays on the CPU: the guard
  caught exactly that on the first DD run.
- **Fail-closed fix:** with `HL_GPU=1 HL_GPU_REQUIRED=1` a Metal device that fails to initialise now panics.
  Before the fix, a kernel-library compile error made one "metal" golden round run silently on the CPU
  (kept, marked invalid, in `golden_m3_cpu_fallback_invalid/`). The golden runner now also refuses a Metal
  arm whose log lacks device evidence.
- **Gates:** the four golden digests on Metal with commitments AND zero-checks on the device (device evidence
  checked per arm): `logs/golden_*`. Equality tests unchanged and passing.

8B-geometry block at T128 (`ladder8b`, block digest `8b6144ea…` on every arm) [MEASURED, n = 1]:

| Configuration | Block wall (phase clock) |
|---|---:|
| Mac CPU, 32 threads | 4.663 s |
| Metal commitments | 4.348 s |
| Metal commitments + zero-checks (M3) | 2.621 s |
| **+ round 0 typed by field (M3b)** | **2.195 s** |
| laptop, 16 threads (historical, per block of the 32-block stack) | ~12.3 s |

Slot 14 (D) 0.93 -> 0.24 s, 18 (F) 0.60 -> 0.24, 17 (softmax) 0.37 -> 0.09, 15 (Q) 0.31 -> 0.07, 16 (KV)
0.17 -> 0.03 (masked sumcheck sub-step). What remains on the CPU: the H helper inverses (~0.3 s), the
extension rounds (~0.33 s), witness planes and mask rows, the openings.

### M3b: round 0 typed by field

The round-0 kernel keeps every base-field table (by IR provenance, checked `c1 = 0` on upload) as one word
and types each expression, so a product with a base operand costs 2 or 1 field multiplications instead of 5.
Rounds 1.. use an all-extension kernel: **the first fold makes every table extension-valued.** A first
version typed every round and moved the golden digests (caught by the gate, never committed). Slot 18
0.164 -> 0.077 s, slot 14 0.194 -> 0.147 s (device rounds). Golden gate 4 / 4 with device evidence.

## M4: the R13 accuracy stack (the real classifier's zero-checks) on the Apple GPU

Until M4 the device path was offered only to the legacy stack: the R13 accuracy stack (`argument_accuracy.rs`,
which the MVP Shieldstral classifier runs) redefines slots 14-19 and DD slot 17, and the IR modelled only the
legacy arms, so those five heavy zero-checks always stayed on the CPU.

- `hashline/src/private_block/slot_ir_accuracy.rs` (new, child module of `slot_ir`): IR builders for the
  accuracy `dzc` (slot 14), `qzc` (15, 16), `szc` non-DD (17) and `fzc` (18), each mirroring one function of
  `argument_accuracy.rs` (same challenge draws and counts on the twin transcript, same table push order, same
  polynomial). DD `szc`, the dictionary slot and the R13 table-helper slot (19) return an error and stay on the
  CPU. `build_slot_ir` takes the accuracy arm first for a non-legacy stack.
- `argument.rs`: the device path is offered to every profile; the per-slot runtime guard (IR == closure at eight
  points) still decides each slot.
- `metal.rs`: a slot's two kernels (round 0 typed, later rounds untyped) now come from ONE library compile, not
  two. The doubled compile of the 64-table D kernel was why a first trained run was slower on Metal (8.10 s
  against 5.59 s on the CPU).

| Gate | Result | Evidence |
|---|---|---|
| Accuracy IR oracle: every development accuracy shape (LOW, H24, both DD), 1-4 activation groups, every slot, 12 random points each, degree bound, and transcribed arms draw exactly `define`'s challenge count | 72 transcribed + 272 legacy slot IRs equal their closures; 8 DD softmax slots refuse (CPU) | `logs/m4_oracle2.log` |
| Existing IR tests (legacy shapes, pinned export digests) | 10 / 10 | same |
| R13 classifier run (`r16_an_r13_classifier_run_with_two_gate_denominators_proves_and_verifies`, `HL_GPU_REQUIRED=1`) | slots 14-18 pass the runtime guard and run on the device; proves and verifies | `logs/m4_r13.log` |
| Seeded accuracy block, CPU vs Metal, 4 development shapes | byte-identical digests, device rounds > 0 | `logs/m4_bytes.log` |
| Seeded accuracy block at trained T128 geometry, CPU vs Metal cold vs Metal warm | byte-identical digests | `logs/m4_trained2.log` |
| Legacy golden gate (`run_golden.py`, 4 shapes x CPU/Metal, recorded digests) on the final binary | 8 / 8, Metal arms with device evidence | `logs/golden_*`, `golden_binary_m4.sha256`; the run before the single-compile change is in `golden_m4a_two_compiles/` (8 / 8) |

Measured [n = 1, shared box, synthetic public weights (`grow_tests::tame_case`), 3 activation groups, seeded
`prove_core` wall clock]:

| Accuracy block, T128 | Mac CPU | Metal cold (first kernel compile in this process) | Metal warm (cached kernels) |
|---|---:|---:|---:|
| `R13_8B_T128_H24` (8B geometry) | 5.595 s | 2.926 s (OS shader cache already warm) | 2.795 s |
| `R13_SHIELD_T128_H24` (Shieldstral, the MVP classifier) | 5.644 s | 4.151 s (1.155 s of kernel compile) | **2.860 s** |

A multi-layer run compiles each shape's slot kernels once per process (all layers share a shape), and macOS
also caches compiled shaders across processes, so the warm column is the per-layer figure. One slot per block
(19, the table helpers) has no IR and stays on the CPU.

## Open items

1. **Backend label.** `trained_block.rs::backend_of_this_process` knows only the CPU and CUDA names, so a
   Metal-made run statement would say "built without gpu-cuda". Adding a Metal name changes what verifiers
   accept and needs Sol's lane and a review before any Metal-made receipt is published.
2. **Next on the GPU:** the H helper inverses (batch inversion), the extension rounds, and fewer host round trips in the device sumcheck.
4. **DD slot 17, the dictionary slot and the R13 table-helper slot (19)** need IR coverage before every slot of every profile runs on the device (legacy and accuracy alike).
3. Buffer pooling (setup is about 15% of the Metal commit time).
