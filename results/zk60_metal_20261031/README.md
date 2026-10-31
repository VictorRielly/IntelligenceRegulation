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
| Legacy golden gate (`run_golden.py`, 4 shapes x CPU/Metal, recorded digests) on the M4 binary | 8 / 8, Metal arms with device evidence | `golden_m4/` (with its binary hash); the run before the single-compile change is in `golden_m4a_two_compiles/` (8 / 8) |

Measured [n = 1, shared box, synthetic public weights (`grow_tests::tame_case`), 3 activation groups, seeded
`prove_core` wall clock]:

| Accuracy block, T128 | Mac CPU | Metal cold (first kernel compile in this process) | Metal warm (cached kernels) |
|---|---:|---:|---:|
| `R13_8B_T128_H24` (8B geometry) | 5.595 s | 2.926 s (OS shader cache already warm) | 2.795 s |
| `R13_SHIELD_T128_H24` (Shieldstral, the MVP classifier) | 5.644 s | 4.151 s (1.155 s of kernel compile) | **2.860 s** |

A multi-layer run compiles each shape's slot kernels once per process (all layers share a shape), and macOS
also caches compiled shaders across processes, so the warm column is the per-layer figure. One slot per block
(19, the table helpers) has no IR and stays on the CPU.

### M4b: the extension rounds' mask reads, shared and parallel (CPU code, both paths)

After M4 a phase breakdown of the Metal Shieldstral block showed the CPU "extension rounds" at 0.49 s, as much
as the device rounds. Almost all of it was `mask_eval`: each private table's reserved mask pair read at its claim
point's tail, one table after another, each rebuilding the same 2^14-entry eq table (2.5 ms a table; 64 tables in
slot 14). `argument.rs` now builds ONE eq table per distinct tail and evaluates the tables in parallel with an
indexed collect. Each value is the same fold in the same order, so no byte moves. The digests are unchanged at
all four development shapes, both trained shapes and the legacy golden gate (`golden_m4b/`, 8 / 8).

| Accuracy block, T128 [n = 1, shared box] | Mac CPU | Metal warm |
|---|---:|---:|
| `R13_8B_T128_H24` | 5.595 -> 5.118 s | 2.795 -> **2.217 s** |
| `R13_SHIELD_T128_H24` | 5.644 -> 5.245 s | 2.860 -> **2.263 s** |

Phase breakdown, Shieldstral, Metal warm: witness planes + commit A 0.378 s, LogUp helpers + commit H 0.483 s,
23 masked sumchecks 1.028 s (device rounds 0.541 s), remainder (openings, IO) about 0.37 s.
Evidence: `logs/m4b_bytes.log`, `logs/m4b_trained.log`.

### M4c: LogUp helper columns written straight into `H` (CPU code, both paths)

Each helper column was built in parallel into a column-sized temporary (up to 2^21 `Fp2` words) and then copied
into `H`'s real and imaginary rows on one thread. `protocol.rs::write_helper_u8` now writes each word straight
into its two places in parallel (same words, same places, same refusal string). A unit test pins it against the
reference functions (both row orders, below and above the parallel threshold, a zero denominator). The digests
are unchanged at all six accuracy shapes and the legacy golden gate (`logs/golden.done`, 8 / 8). The R13
classifier run proves and verifies.

| Accuracy block, T128 [n = 1, shared box] | Mac CPU | Metal warm |
|---|---:|---:|
| `R13_8B_T128_H24` | 4.826 s | 2.217 -> **2.017 s** |
| `R13_SHIELD_T128_H24` | 5.120 s | 2.263 -> **2.098 s** |

Evidence: `logs/m4c_unit.log`, `logs/m4c_bytes.log`, `logs/m4c_trained.log`, `logs/m4c_r13.log`.

### M4d: the prover's fresh randomness and the LogUp helpers in parallel (CPU code, both paths)

Three findings from a phase probe on the quiet box (`HL_PB_TIMING=1`):

- **The mask rows drew their randomness one word at a time** (`ZkRng::fp()`: a u128 remainder per word over a
  serial blake3 stream), 25 ns per word: A's mask and proximity rows 0.119 s, H's 0.045 s. The stream is
  counter mode (block `c` is `blake3(key || c)`, drawn in order), so word `t` from any state is a pure function
  of the state. `zkp-core/src/rng.rs::fill_fp` rebuilds the blocks in parallel chunks and leaves the generator
  in exactly the state the `fp()` loop leaves it in; `fp_vec` (the commitments' pads) uses it too. Test
  `fill_fp_equals_the_draw_loop_and_leaves_the_same_state`: equal draws, equal `(counter, pos, buf)` and equal
  later draws of every kind, from seven buffer alignments (including an odd word, so draws straddle blocks) and
  eleven lengths around the chunk and block edges. A mask rows 0.119 -> 0.007 s, H 0.045 -> 0.004 s.
- **A rayon region costs about half a millisecond to start on this Mac.** The 47 LogUp helper columns each
  opened one (and paid a per-word `try_for_each`), 0.13 s in all, slower than one thread (a standalone bench:
  17 columns of 2^19, one thread 0.015 s, per-column regions 0.043-0.068 s, one region 0.0023 s).
  `protocol.rs::write_helpers_u8` writes every column's chunks in ONE region; it takes that path only when all
  jobs are well formed and their target ranges disjoint, so the only error left is the zero denominator the
  job-by-job loop also returns, and anything else runs that loop itself. Test
  `m4d_batched_helper_write_equals_the_job_by_job_loop`. Page faults on the fresh 575 MB `H` buffer were ruled
  out: touching every page in parallel takes 2-6 ms.
- **The Metal upload of a commitment's data was one `memcpy`** (600 MB for A); now parallel above 2^20 words.

`HL_METAL_TIMING=1` now also splits each device sumcheck into round 0, later rounds and folds (diagnostic;
note that the same switch re-runs every commitment's GPU parts on scratch buffers, so never time with it).

Gates: zkp-core rng tests 4 / 4; unit `m4c_ m4d_ s28 slot_ir` 30 / 30; CPU vs Metal seeded bytes at the four
development shapes; the trained digests unchanged (`2b0d04bb...` Shieldstral, `678953f6...` 8B, CPU and Metal);
R13 classifier run proves and verifies; legacy golden gate 8 / 8 with device evidence (`golden_m4d/`, binary
`golden_binary_m4d.sha256`).

| Accuracy block, T128 [n = 1, quiet box; the test's own clock] | Mac CPU | Metal cold | Metal warm |
|---|---:|---:|---:|
| `R13_8B_T128_H24` | 4.739 s | 1.859 s | 2.017 -> **1.766 s** |
| `R13_SHIELD_T128_H24` | 4.834 s | 1.939 s | 2.098 -> **1.832 s** |

Shieldstral warm phases: witness planes + commit A 0.264 s (was 0.379), LogUp helpers + commit H 0.237 s (was
0.516), 23 masked sumchecks 0.994 s. The zero-checks are now more than half the block. Their split
(`logs/m4d_trained.log`): slot 14 (64 tables, degree 5) round 0 0.033 s, rounds 1.. 0.165 s; slot 18 (29 tables
x 2^21) 0.036 / 0.084 s; the small slots pay about 0.5 ms per round in fixed costs (two command buffers, a
fresh partials buffer, a rayon reduction). The Goldilocks multiply itself is not the limit: a standalone bench
does 96 G `gl_mul`/s on this GPU, and neither a 32-bit `mulhi` form nor 64-bit `mulhi` is faster (equal outputs).
Evidence: `logs/m4d_core_rng.log`, `logs/m4d_unit.log`, `logs/m4d_bytes.log`, `logs/m4d_trained.log`,
`logs/m4d_timing.log`, `logs/m4d_r13.log`.

### M4e: the device sumcheck's later rounds, one thread per evaluation point (byte-identical)

The M4d split showed the zero-checks' later rounds (every table extension-valued after the first fold)
costing 2-5x round 0, and the small slots paying about 0.5 ms per round in fixed costs. Three changes:

- **Host (`gpu/metal.rs::MetalRounds`).** A fold is encoded in the NEXT round's command buffer, ahead of
  that round (the encoder runs its dispatches in order, as the NTT stages rely on); only the last fold runs
  at once, since the final tables are read after it. One partials buffer per sumcheck instead of one per
  round; small partial sums on one thread.
- **Karatsuba `f2_mul`** (SC_PRELUDE): three base products and 7 bd by doublings, the same field elements.
- **The generated kernels (`private_block/metal_slot.rs`) run one thread per (pair stride, evaluation
  point)**, grid `nthreads * (D + 1)`, each table's value at `d` formed directly (`lo`, `hi`,
  `lo + d (hi - lo)`: the element the CPU reaches by adding the step `d` times); one pair per thread up to
  2^17 strides, threadgroups of 64 (`HL_METAL_SC_THREADS` / `_PER` / `_TG` override). Partial `(gid, d)`
  lands where the M3 kernel put it.

The kernel shape was chosen in a standalone harness on Shieldstral slot 14's dumped library
(`kbench/`, all variants' sums equal), later rounds only, best of three:

| Slot 14 later rounds, 64 tables, degree 5 [n = 3, min] | seconds |
|---|---:|
| M3 kernel, 4 pairs per thread, <= 2^15 threads, groups of 256 (the M4d setting) | 0.170 |
| M3 kernel, 1 pair per thread, groups of 64 | 0.081 |
| point outer / lazy loads / unrolled (B, C, D; single runs) | 0.24-0.27 |
| **one thread per (pair, point), values loaded up front (E)** | **0.059** |

Negative results kept for the record: a "v2" kernel (point loop outermost, SIMD-group partials) was built
into the prover first and was SLOWER (Shieldstral device rounds 0.55 s against 0.47 s for the M3 kernel with
the host changes, `logs/m4e_trained_v2.log` / `_v1.log`) with 2-7 s more cold compile, so it was removed;
lazy loads were slower in the harness too, so register liveness was not the limit, the per-thread serial
work of the small late rounds was. In those two logs and in `m4e_unit.log`, `m4e_bytes.log` and
`m4e_split.log`, the FIRST run is the M4d binary (the first M4e build failed to compile and its queued
gates ran on); the second is the M4e candidate named.

| Accuracy block, T128 [n = 2, quiet box; the test's own clock] | Metal warm, M4d | Metal warm, M4e |
|---|---:|---:|
| `R13_8B_T128_H24` | 1.766 / 1.780 s | **1.562 / 1.563 s** |
| `R13_SHIELD_T128_H24` | 1.832 / 1.862 s | **1.615 / 1.610 s** |

Shieldstral device rounds 0.52 -> 0.33 s; slot 14 0.21 -> 0.12 s (round 0 0.024 s, later rounds 0.094 s),
slot 18 0.13 -> 0.12 s, slots 15-17 0.040 / 0.029 / 0.049 -> 0.021 / 0.012 / 0.023 s (`logs/m4e_split3.log`).
A new library's first compile is longer (up to 6 s at the 8B shape, once per machine; macOS caches it).

Gates: unit `m4c_ m4d_ s28 slot_ir metal` 30 / 30; CPU vs Metal seeded bytes at the four development
shapes; trained digests unchanged (`2b0d04bb...`, `678953f6...`) in every run; R13 classifier run proves and
verifies; legacy golden gate 8 / 8 with device evidence (`golden_m4e/`, binary `golden_binary_m4e.sha256`).
Evidence: `logs/m4e_build3.log`, `logs/m4e_unit3.log`, `logs/m4e_bytes3.log`, `logs/m4e_trained_e1.log`,
`logs/m4e_trained_e2.log`, `logs/m4e_split3.log`, `logs/m4e_r13.log`; the Karatsuba-only intermediate in
`logs/m4e_*2.log` and `logs/m4e_trained_k*.log` (Shieldstral warm 1.783 / 1.745 s).

### M4f: a pool for the shared Metal buffers (byte-identical)

The first touch of a FRESH shared Metal buffer is slow on this Mac, unlike ordinary memory (575 MB of
`malloc`ed pages fault in, in parallel, in 2-6 ms). A standalone bench (`kbench/`-style, numbers below,
n = 2): writing a new buffer the first time against the second time, in parallel:

| Fresh shared buffer | new_buffer | first write | second write |
|---|---:|---:|---:|
| 537 MB | 0.0001 s | 0.042-0.059 s | 0.003 s |
| 973 MB (slot 18's tables) | 0.0000 s | 0.074-0.078 s | 0.005 s |
| 2.4 GB (A's encoded matrix) | 0.0001 s | 0.170-0.196 s | 0.011 s |

A block allocates about 46 such buffers (the commitments' data, row and encoded matrices, leaves; the
zero-checks' tables and partials), and the next block asks for the same sizes. `gpu/metal.rs::PBuf` hands a
dropped buffer back to a process-wide pool, and `shared_buffer` takes the smallest free one between the
requested size and 1.25x it. A reused buffer keeps its old contents, which is safe because every user
writes everything it later reads (the upload copies every word; the NTT head writes every element, the
padding as explicit zeros; the hash, gather and fold kernels write every output; the tables are written
whole; each round writes the partial of every thread the host reads). `HL_METAL_POOL=0` turns it off,
`HL_METAL_POOL_GIB` caps what it keeps (default 48). The trained test now prints the pool's reuse.

| Accuracy block, T128 [n = 2, quiet box; the test's own clock] | Metal warm, pool off | Metal warm, pool on |
|---|---:|---:|
| `R13_8B_T128_H24` | 1.572 s | **1.136 / 1.134 s** |
| `R13_SHIELD_T128_H24` | 1.594 s | **1.130 / 1.098 s** |

A warm block reuses all 46 buffers; the first Metal block of a process (after the CPU run) finds 21 of 48,
so in a 26-layer run only the first layer pays. Shieldstral warm phases: witness planes + commit A 0.157 s
(was 0.25), LogUp helpers + commit H 0.141 s (was 0.235), 23 masked sumchecks 0.538 s (was 0.79). The cost is
memory: the test's peak RSS 10.8 GB against 8.4 GB without the pool.

Gates: unit 30 / 30; CPU vs Metal seeded bytes at the four development shapes; trained digests unchanged
with the pool on and off; R13 classifier run proves and verifies; legacy golden gate 8 / 8 with device evidence (`golden_m4f/`,
binary `golden_binary_m4f.sha256`). Evidence: `logs/m4f_build.log`, `logs/m4f_unit.log`, `logs/m4f_bytes.log`,
`logs/m4f_trained_1.log`, `logs/m4f_trained_2.log`, `logs/m4f_trained_nopool.log`, `logs/m4f_r13.log`;
the bench is `kbench/alloc_bench_main.rs` with `kbench/alloc_bench_run.log`.

### M4g: one evaluation point per SIMD group, point 1 not launched when the claim gives it (byte-identical)

Every later round of a closure slot recovers s(1) from the claim (`eval_one == 0`), and the M4e kernel
(point `tid % (D + 1)`) still launched point 1's threads, idle inside every SIMD group, with the line-value
branches divergent across the group. The `kbench` harness on slot 14's library now takes `eval_one`
(`kbench/gen2.py`, `kbench/sweep_m4g.log`, later rounds, best of three, sums equal):

| Slot 14 later rounds, 64 tables, degree 5 [n = 3, min] | eval_one = 1 | eval_one = 0 (what the prover runs) |
|---|---:|---:|
| M4e form E (point `tid % (D + 1)`) | 0.059 s | **0.087 s** |
| **G: 32 lanes share a point, point 1 not launched** | 0.059 s | **0.050 s** |
| G with the step times `d` as a small-integer product (H) | 0.059 s | 0.049-0.050 s |
| floor: E's or G's loads and line values, body replaced by a sum (L, LG) | 0.010 s | 0.009-0.011 s |

So the M4e kernel ran at its WORST in the prover (the M4e split's 0.094 s for slot 14's later rounds
matches the 0.087 s column, not the 0.059 s one it was chosen on), and the body's arithmetic, not the
loads, is what is left (the floor is a fifth of G). `private_block/metal_slot.rs` now generates G:
`grp = tid >> 5`, `np = D + 1` or `D`, `d` = the group's point skipping 1, `gid = (grp / np) * 32 + lane`;
`gpu/metal.rs` launches `ceil(nthreads / 32) * 32 * np` threads and its host sum skips point 1's partial
when the claim sets s(1) (the pooled buffer's word there is not written). H did not pay and was not taken.

| Shieldstral, prover split (`HL_METAL_TIMING`, `logs/m4g_split.log`) | M4e/M4f | M4g |
|---|---:|---:|
| slot 14 (64 tables, degree 5): round 0 + later rounds | 0.024 + 0.094 s | **0.022 + 0.056 s** |
| slot 18 (29 tables, degree 5, 2^21) | 0.12 s | **0.028 + 0.045 s** |
| slots 15 / 16 / 17 | 0.021 / 0.012 / 0.023 s | 0.018 / 0.010 / 0.020 s |

| Accuracy block, T128, Metal warm [the test's own clock, quiet box] | M4f (n = 2) | M4g (n = 4) |
|---|---:|---:|
| `R13_SHIELD_T128_H24` device sumcheck rounds | 0.318-0.332 s | **0.242-0.245 s** |
| `R13_SHIELD_T128_H24` block | 1.098 / 1.130 s | **1.046-1.168 s, median 1.07** |
| `R13_8B_T128_H24` device sumcheck rounds | 0.256-0.259 s | **0.199-0.200 s** |
| `R13_8B_T128_H24` block | 1.134 / 1.136 s | **1.090-1.180 s, median 1.10** |

The block gains less than its device rounds (0.04 s at the medians against 0.06-0.08 s), inside this box's
run-to-run spread; unrelated phases (witness + commit A) moved by as much between runs. A new library compiles
once per machine (6.3 s at the 8B shape, 1.0 s Shieldstral, then macOS caches it).

Gates: unit `m4c_ m4d_ s28 slot_ir metal` 30 / 30; CPU vs Metal seeded bytes at the four development shapes;
trained digests unchanged (`2b0d04bb...`, `678953f6...`) in all four runs; R13 classifier run proves and
verifies; legacy golden gate 8 / 8 with device evidence (`golden_m4g/`, binary `golden_binary_m4g.sha256`).
Evidence: `logs/m4g_build.log`, `logs/m4g_unit.log`, `logs/m4g_bytes.log`, `logs/m4g_trained_{1,2,3,4}.log`,
`logs/m4g_split.log`, `logs/m4g_r13.log`.

### M4h: the exp and activation helper inverses in parallel (byte-identical, CPU side)

`H`'s exp and activation helper columns (2,621,440 extension elements at the T128 rungs) were built and
batch-inverted on ONE thread (0.057-0.059 s of a warm block). `private_block/protocol.rs`: `inverses` now
inverts a long column in rayon chunks of 2^14, one batch inversion (one field inversion) per chunk; an inverse
is the unique field element, so the words are the same, and a zero anywhere refuses with the same string (each
chunk checks before it inverts; a refused vector is dropped). The denominators are formed on indexed rayon
iterators (same elements, same order; `zip` stops at the shorter side as before) and `write_h` writes a long
column's re and im rows in parallel when they are disjoint and in bounds (always; anything else takes the old
loop). The DD dictionary's helper columns use the same `inverses`. `slot_ir_accuracy.rs`:
`m4h_parallel_inverses_and_h_writes_equal_the_sequential_forms` (word-for-word inverses against the
single-region batch inversion, the zero refusal in both forms, `write_h` with the real row before and after the
imaginary one). The phase: **0.057-0.059 s -> 0.024-0.025 s** (`logs/m4h_trained_phases.log`; the remainder is
`accuracy_act::query_values`, a file of the accuracy lane, left as it is).

| Accuracy block, T128, Metal warm [the test's own clock, quiet box] | M4g (n = 4) | M4h (n = 4) |
|---|---:|---:|
| `R13_SHIELD_T128_H24` | 1.046-1.168 s, median 1.07 | **0.980-1.023 s, median 1.005** |
| `R13_8B_T128_H24` | 1.090-1.180 s, median 1.10 | **1.016-1.182 s, median 1.03** |

The CPU path shares the change (Shieldstral CPU 4.2-4.8 s, one run 3.1 s; not a quiesced CPU ladder). The
CPU-vs-Metal bytes test at the four development shapes went from 31-36 s to 7.4-7.7 s with the same four digests.

Gates: unit `m4c_ m4d_ m4h_ s28 slot_ir metal` 31 / 31 (the first run of the new test failed on the TEST's own
slice length, `logs/m4h_first_binary/`; fixed, rebuilt, every gate below re-run on the final binary except the
three timing runs, whose prover code is the same); CPU vs Metal seeded bytes at the four development shapes;
trained digests unchanged in all runs; R13 classifier run proves and verifies; legacy golden gate 8 / 8 with
device evidence (`golden_m4h/`, binary `golden_binary_m4h.sha256`). Evidence: `logs/m4h_*`.

### M4i: device tables built in place, witness planes in parallel, and a prove-core clock (byte-identical)

A `sample` profile of six warm Shieldstral blocks (`kbench/`-free: macOS `sample` on the running test, 3252
samples per thread) put the largest prover-side CPU cost in `argument::priv_table`, and 60% of THAT in
`__bzero`: every slot table was a fresh `vec![Fp2::ZERO; 2^n]`, whose recycled pages macOS zeroes before the
builder overwrites them, and the device path then copied every table into a shared buffer (0.045 s per block
over the five device zero-checks). Two more single-threaded loops showed up: `A`'s witness planes were
converted into their rows on one thread (0.075 s), and the test's own digest formats the whole proof as text.

- **Tables in place** (`gpu/metal.rs::MetalTables`, `metal_rounds_owned`; `private_block/argument.rs`). A device
  slot (host or standalone kind, so its claimed sum reads no table; above `2^18` terms, strictly above the test
  oracle's size; census off) builds its tables straight into ONE pooled shared buffer viewed as `[Fp2]` (the
  constructor checks `Fp2` is the two words `c0, c1`, else the old path runs), one rayon task per table.
  `priv_table_into` / `eq_cube_into` write the words `priv_table` / `eq_cube` return: a plain-store private
  table writes every element (its index map is a bijection onto the subsets of `used`, and the broadcast fills
  the rest), an accumulating one is zeroed first, an eq cube is filled and doubled, a public table copied. The
  base-typing check the copy made now reads the tables in place (0.003 s for slot 18). A device decline hands
  the tables back (`to_vecs`) for the CPU evaluator. The stage-28 equality gates (`priv_table` against the
  walked builder, `eq_cube` against the gathered one) still pass through the shared fill code.
- **Witness planes** (`private_block/protocol.rs::write_planes`): the planes' ranges are checked in bounds and
  disjoint, carved in address order and converted in one rayon region; anything else runs the old loop.
- **Clock** (`slot_ir_accuracy.rs`): the trained test now prints `prove core`, the `prove_core` call alone. Its
  older `metal-warm` figure also holds the test's NTT tables, endpoint rows and the digest's text (about
  0.16 s): the M4-M4h rows above are that figure, and remain comparable with one another. `HL_M4_WARM_PASSES=n`
  runs n warm passes per process.

| Accuracy block, T128, Metal warm [quiet box; 9 warm passes in 3 processes] | M4h test clock (n = 4) | M4i test clock | **M4i prove core** |
|---|---:|---:|---:|
| `R13_SHIELD_T128_H24` | median 1.005 s | 0.889-1.095 s, median 0.917 | **0.727-0.927 s, median 0.753** |
| `R13_8B_T128_H24` | median 1.03 s | 0.868-0.956 s, median 0.921 | **0.705-0.794 s, median 0.759** |

Phase clock, Shieldstral warm (`HL_PB_TIMING`, `logs/m4h_trained_phases.log` -> `logs/m4i_trained_phases.log`,
n = 1 each): the call 0.974 -> **0.801 s**; slot 18 0.131 -> 0.097 s, slot 14 0.124 -> 0.091 s, slots 15-17
0.032 / 0.024 / 0.034 -> 0.028 / 0.019 / 0.030 s, `A: allocate + witness planes` 0.075 -> 0.027 s. The CPU
path shares the plane write (Shieldstral CPU prove core 2.9 s in these runs; not a quiesced ladder).

Gates: unit `m4c_ m4d_ m4h_ m4i_ s28 s29 slot_ir metal` 32 / 32 (including the stage-28 table equality gates
and `m4i_in_place_tables_and_plane_writes_equal_the_host_forms`, which writes into a buffer of stale words);
`cargo check` without the `gpu-metal` feature; CPU vs Metal seeded bytes at the four development shapes (the
same four digests); trained digests unchanged in all 18 warm passes; R13 classifier run proves and verifies;
legacy golden gate 8 / 8 with device evidence (`golden_m4i/`, binary `golden_binary_m4i.sha256`). Evidence:
`logs/m4i_*`; the profiler run and its reader are `kbench/profile_warm.py` and `kbench/sample_tree.py`, the
flat self-time summary `kbench/m4i_profile_flat.txt` (the 27 MB sample text stayed in the session scratchpad).

### M4j + M4k: table builders parallel over their output; the last, tiny rounds on the host (byte-identical)

Gated together (one binary, `logs/m4k_*`, `golden_m4k/`); M4j alone was measured first on its own binary
(`logs/m4j_*`, no golden of its own).

- **M4j** (`private_block/argument.rs`). A slot's tables were built in parallel ACROSS tables only, so a slot
  of three 2^19 tables used three threads. A plain-store private table's map `idx -> x` is a bit permutation
  (one coordinate per bit, flipped for `Flip`), so its inverse is the same bit table read the other way, and
  every cube entry is `value(inverse(x & used))`: the loop's store for x within `used` and the broadcast's
  copy for every other x. Tables of `2^16` entries or more are now filled in parallel over the OUTPUT that
  way; an eq cube likewise (`out[x] = e[(x >> shift) & (|e| - 1)]`, its own definition). Accumulating
  tables (fixed coordinates, a repeated index) keep the loop. `priv_table_at`, `eq_cube_at` and the in-place
  `_into_at` forms take the threshold as an argument; `m4j_parallel_table_builders_equal_the_sequential_ones`
  forces both forms at 2^3, 2^8, 2^13 and 2^17 on seven descriptors (including an interleaved, flipped,
  short one) and every eq cube shape. The builds were smaller than the profile suggested (0.076 -> 0.079 s
  summed over a block's slots, within noise), so M4j's gain is small.
- **M4k** (`gpu/metal.rs::TailedRounds`, `MetalRounds::with_host_tail`). A device round costs about
  0.35-0.4 ms whatever its size (command buffer, wait, partial sum), so the last rounds of every device
  sumcheck, and most rounds of the small ones, were pure latency. The device evaluator now hands over to the
  host at the first round whose host cost (pairs x points evaluated x one evaluation of the slot's closure,
  timed on eight points at construction) is under 0.25 ms: any deferred fold runs, the tables (by then a few
  thousand entries) are read from shared memory, and the remaining rounds are `ClosureRounds`' rounds over
  the slot's own polynomial (the closure the IR was checked against): the same unmasked values, the same s(1)
  recovery, the same folds, so where the switch lands moves no byte. `HL_METAL_HOST_TAIL=0` keeps every round
  on the device. The masked sumchecks' slot steps summed 0.294 -> 0.261 s; the "device sumcheck rounds"
  statistic now counts only the rounds that stayed on the device (Shieldstral 0.24 -> 0.20 s, 8B 0.20 ->
  0.16 s), and the per-sumcheck `HL_METAL_TIMING` split no longer prints for a sumcheck that finished on the
  host.

| Prove core, T128, Metal warm [9 warm passes in 3 processes, quiet box] | M4i | M4j | **M4k** |
|---|---:|---:|---:|
| `R13_SHIELD_T128_H24` median (min-max) | 0.753 s | 0.740 (0.725-0.757) s | **0.711 (0.698-0.801) s** |
| `R13_8B_T128_H24` median (min-max) | 0.759 s | 0.719 (0.698-0.935) s | **0.686 (0.663-0.866) s** |

Phase-clock call (Shieldstral, n = 1): 0.801 (M4i) -> 0.795 (M4j) -> 0.776 s (M4k).

Gates (on the M4k binary): unit `m4c_ m4d_ m4h_ m4i_ m4j_ s28 s29 slot_ir metal` 33 / 33; `cargo check` without
`gpu-metal`; CPU vs Metal seeded bytes at the four development shapes (same digests); trained digests unchanged
in all 18 warm passes; R13 classifier run proves and verifies; legacy golden gate 8 / 8 with device evidence
(`golden_m4k/`, binary `golden_binary_m4k.sha256`).

### M4l: eq tables' doubling steps on one thread below 2^15 (byte-identical)

`zkp-core/src/mle.rs::eq_table` doubles its table once per variable and ran a step on rayon from length 4096
(UPERF3-XX had already moved the smaller steps to one thread for the same reason). A rayon region costs about
0.3 ms on this Mac and a step of length 2^14 about 0.15 ms on one thread, so the cutoff is now
`EQ_TABLE_PAR_LEN = 2^15`. Eq tables are built all through a block (every opening group's 2^14 column weights,
the extension rounds' mask tails, slot definitions, fixed coordinates), so the saving is spread wide. Same
values: each entry is the same two products. New `zkp-core` test
`eq_table_across_the_parallel_cutoff_matches_point` (2^14 and 2^17 tables against the product definition).

| Prove core, T128, Metal warm [9 warm passes in 3 processes, quiet box] | M4k | **M4l** |
|---|---:|---:|
| `R13_SHIELD_T128_H24` median (min-max) | 0.711 (0.698-0.801) s | **0.656 (0.647-0.677) s** |
| `R13_8B_T128_H24` median (min-max) | 0.686 (0.663-0.866) s | **0.622 (0.608-0.730) s** |

The single instrumented run (`HL_PB_TIMING`) read 0.807 s against M4k's 0.776 s; single instrumented runs have
varied by about 0.1 s all along, so the medians above are the figure. Gates: unit 33 / 33; `zkp-core` lib
76 / 76; `cargo check` without `gpu-metal`; CPU vs Metal seeded bytes at the four development shapes; trained
digests unchanged in all 18 warm passes; R13 classifier run proves and verifies; legacy golden gate 8 / 8 with
device evidence (`golden_m4l/`, binary `golden_binary_m4l.sha256`). Evidence: `logs/m4l_*`.

### Token scaling on Metal after M4i: T256 against T128 (a measurement, no code change)

The registered `R13_SHIELD_T256_H24` profile (same geometry, 256 tokens, `log_cols` 15) in the same process as
T128, three warm passes each (`logs/m4i_t256.log`; digests CPU = Metal at both, T256 `68edf250...`):

| Shieldstral, Metal warm [n = 3, quiet box] | T128 | T256 | ratio |
|---|---:|---:|---:|
| prove core | 0.745-0.813 s (median 0.752) | 1.499-1.639 s (median 1.585) | 2.1x |
| device sumcheck rounds | 0.24 s | 0.42 s | 1.75x |
| witness planes + commit A (phase clock of the test) | 0.109-0.140 s | 0.308-0.320 s | 2.5-2.9x |
| LogUp helpers + commit H | 0.099-0.120 s | 0.290-0.313 s | 2.6-2.9x |
| 23 masked sumchecks (host side included) | 0.43-0.45 s | 0.74-0.81 s | 1.75x |

Proof time is about LINEAR in the tokens of a block here (2.1x for 2x): the device rounds scale sublinearly,
the commitments (2^15-column rows, a larger NTT) superlinearly, and every buffer was reused (pool 46 / 46).
Longer blocks alone do not raise proved tokens per second on this design and this machine; at T128 the proof
core is 0.75 s per Shieldstral block, about 19.6 s for 26 layers, about 6.5 proved tokens/s against the target of
50 (7.7x short). Closing that needs the protocol-level levers (fewer commitments and openings per token, e.g.
across layers) or a faster device, not more phase tuning.

## Open items

1. **Backend label.** `trained_block.rs::backend_of_this_process` knows only the CPU and CUDA names, so a
   Metal-made run statement would say "built without gpu-cuda". Adding a Metal name changes what verifiers
   accept and needs Sol's lane and a review before any Metal-made receipt is published.
2. **Next on the GPU (after M4k, a 0.71 s Shieldstral block):** slots 18 and 14 (~0.09-0.10 s each, their
   later-round bodies still arithmetic-bound: an affine-extraction pass that turns each slot's affine
   subexpressions into folded derived tables would cut the body's multiplications about 3-4x, est. 0.04-0.05 s),
   the two commitments (~0.15 s: NTT and hash on the device, near this GPU's throughput, plus a 0.6 GB upload
   copy each), the openings (~0.09 s), the 18 small slots (~0.15 s, mostly fixed per-slot costs), the CPU-only
   TAB slot (0.02 s). Byte-identical tuning of all of it is worth perhaps another 15-25%.
3. ~~Buffer pooling~~ done in M4f.
4. **DD slot 17, the dictionary slot and the R13 table-helper slot (19)** need IR coverage before every slot of
   every profile runs on the device (legacy and accuracy alike).
5. **A structural lever for a ruling, not taken here (it changes the proof):** at the Shieldstral T128 shape
   the byte lookups read 64.3 M words of `A`'s byte-sized planes (`A` is 75.0 M words; a plane under an int8 or
   scaled bound is read twice, so the planes themselves are fewer words), and their LogUp helpers are 64.3 M of
   `H`'s 71.9 M words (`logs/m4i_trained_phases.log`, the phase sizes). Most of what is committed is therefore
   range-check limbs and their helpers. Wider limbs (16-bit, a 2^16-entry table) where a value is decomposed
   into bytes would shrink both commitments, the openings and the helper writes roughly in proportion: a rough
   estimate is 0.1-0.2 s of a 0.71 s block, to be counted from the layout before anyone relies on it. It is a
   new layout, verifier and receipt format, so it needs Victor's ruling and Sol's lane; even with it, 50 proved
   tokens/s needs more (cross-layer batching of commitments and openings, or a faster device), because proof
   time is about linear in tokens (T256 above).
