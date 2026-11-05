# H124: where one block's witness time goes (W16R2 8B T128), 2026-11-04

**Test:** `witness_speed_tests::h124_witness_time_per_block_at_w16r2_8b_t128` (ignored, release).
- The block is the D55 A/B fixture's: public synthetic data at the true Llama-3-8B geometry (`range16_tests::case`),
  with M10's admissible input.
- Each figure is the best of 3.
- The run was guarded (class cpu) and alone among guarded jobs. The Mac is shared, so read the numbers as an
  estimate. Log: `h124.log`.

**Result** [MEASURED, M3 Ultra, 32 rayon threads]:

| One block | 32 threads | 1 thread (CPU s) |
|---|---:|---:|
| `witness::build_accuracy`, the whole witness | 0.438 s | 5.940 s |
| the seven weight products alone (q, k, v, o, gate, up, down; 27.92 G MACs) | 0.361 s | 5.617 s |
| everything else (norms, RoPE, attention, lookups, limbs) | 0.077 s | about 0.32 s |

**What it means:**
- **The weight products are 82% of the witness wall time and 95% of its CPU time.** They run as scalar i32 code at
  about 5.0 G MACs/s on one core and 77 G MACs/s on 32. That is far below the M3 Ultra's vector units or its GPU.
- **At this rate a 32-block request is 14.0 s of witness** if blocks are built one after another on all threads, or
  190 CPU s in all.
  - The D55 A/B log implied about 8.6 s per request with 8 builder threads [INFERRED, MVP_STATUS 2026-11-03].
    Building several blocks at once uses the cores better than one block at a time.
  - Against 5.6 s of proving, that is why the target's clock reads about 9 tok/s, not 22.9.
- **The lever (H124) is to make these products fast without changing one byte.** Every product is an exact integer
  sum, so a faster kernel must give the same integers. Candidates, roughly in order of effort:
  1. NEON integer SIMD on the CPU (widening int16×int8 multiply-accumulate into int32, as the narrow path already
     allows; or two int8 limbs per activation with SDOT / i8mm).
  2. The products on the GPU (Metal now, CUDA on the RTX 5090), in exact integer arithmetic. 27.9 G MACs per block
     is small for either GPU.
  3. Building the witness inside each D55 fork, so it overlaps the proving.
- **Acceptance:** byte-identical witnesses. The existing equality test (`the_parallel_products_equal_the_sequential_ones_*`)
  and the goldens hold the planes fixed.

## Step 1 landed: an exact i16 fast path (2026-11-04)

**What changed:** `witness::matmul` and `matmul_in_out` gain a third path. When every input word fits an i16
(|x| < 2^15), products are summed exactly in i32 over blocks of 256 and widened to i64 between blocks: each product is
at most 2^22, so each block sum is at most 2^30. The i32 path (|x| < 2^23) and the i64 path are unchanged.

**Checks** [MEASURED, `check_i16.sh`, one guarded job; `check.progress`]:
- **Exact:**
  - parallel = sequential at the trained-rung and TinyLlama dimensions, for five input classes (int8; i16 at its edge
    ±32767; i16 with −32768, which takes the i32 path; ±(2^23 − 1); ±2^40);
  - a new worst-case test (`the_i16_products_are_exact_at_their_extremes`): every product at its largest size, one
    sign throughout, over widths that span several blocks.
- **Byte-identical:**
  - the W16R2 rung golden (CPU = Metal) passes;
  - the trained digests 2b0d04bb, 678953f6, 01a6d51d, c5e0bdac, 4e189ccc and a9a19ee5 (R13, W16 and W16R2, 8B and
    Shieldstral) all reappear unchanged.
- **Time, one W16R2 8B T128 block** [MEASURED, best of 3, shared box]:

  | | before | after |
  |---|---:|---:|
  | whole witness, 32 threads | 0.438 s | 0.379 s |
  | whole witness, 1 thread | 5.94 CPU s | 4.97 CPU s |
  | the seven weight products, 32 threads | 0.361 s | 0.237 s |
  | the seven weight products, 1 thread | 5.62 s | 4.08 s (about 6.8 G MACs/s) |

  About 1.5× on the products and 1.16× on the whole witness. The compiler vectorized the loops only partly.

## Next (H124b): exact products on the matrix hardware

**The exactness argument:**
- Every product `x w` and every partial sum here is an integer: |x| < 2^23, |w| ≤ 128, and at most 14,336 terms,
  so every partial sum is below 2^44.
- Every integer below 2^53 is exact in f64, so an f64 matrix product returns EXACTLY the same integers, in any
  summation order, with or without fused multiply-add.

**Where that leads:**
- **On the Mac:** Apple's Accelerate `cblas_dgemm` runs on the matrix coprocessor. A block is 55.8 G f64 operations,
  plus converting about 218 M int8 weights to f64. Cache the converted weights per model where memory allows.
- **On the GPU:** integer kernels (Metal now, CUDA on the RTX 5090) with i32 block sums as above. 27.9 G MACs per block
  is small for either.
- **Overlap:** building each fork's witness inside the fork overlaps it with proving.
- **Acceptance stays the same:** parallel = sequential, the goldens, and the pinned digests.

## Step 2 landed: the i16 products tiled by output columns (2026-11-04)

**Why:** both product loops re-read the whole weight matrix once per token (128 times per block, about 59 MB per
matrix each time), so they were memory-bound. Vectorizing alone (step 1) therefore gained little.

**What changed:** `witness::tiled16` gives each rayon task a block of output columns for every token.
- Each weight row is read once and reused across all tokens.
- Partial sums are i32 over blocks of 256 input indices (each at most 2^30), widened to i64 between blocks.
- The i32 and i64 paths are unchanged.

**Checks** (`check_tiled.sh`, one guarded job, `tiled.progress`):
- exact: the equality tests over five input classes at the rung and TinyLlama dimensions, and the worst-case test;
- byte-identical: the W16R2 rung golden, and all six pinned trained digests (2b0d04bb, 678953f6, 01a6d51d, c5e0bdac,
  4e189ccc, a9a19ee5);
- no new compiler warnings.

**Time, one W16R2 8B T128 block** [MEASURED, best of 3, shared box]:

| | original | step 1 | step 2 (tiled) |
|---|---:|---:|---:|
| the seven weight products, 32 threads | 0.361 s | 0.237 s | **0.085 s** |
| the seven weight products, 1 thread | 5.62 s | 4.08 s | **1.39 s** (about 20 G MACs/s) |
| whole witness, 32 threads | 0.438 s | 0.379 s | **0.249 s** |
| whole witness, 1 thread | 5.94 CPU s | 4.97 | **1.38 CPU s** |

- **The products are now about 4.2× faster, and a block costs 4.3× less CPU.**
- On 32 threads the rest of the builder (norms, RoPE, attention, lookups, limbs) is now most of the wall time: about
  0.16 s of 0.25 s, because it scales poorly across threads.
- The products-alone figure uses dense random words. The real block's inputs skip zeros, so on one thread its
  products cost slightly less than this figure.
- **Next:** parallelize the rest of the builder, and build several blocks' witnesses at once. The forward chain of
  one request is serial, but its products are now cheap enough to compute the chain first and build the 32 witnesses
  in parallel.

## One request end to end after step 2 (D55 A/B harness, 2026-11-04)

**Command:** `d55_ab_one_request_serial_against_forks`, guarded (class gpu), `HL_D55_PROFILE=W16R2_8B_T128_H24`,
`HL_D55_L=32`, `HL_D55_WORKERS=6`, `HL_D55_PASSES=2`. The tree now includes Q = 280. Log: `d55_ab_tiled.log`.

| | 2026-11-01 (`m_d55_r2b.log`) | 2026-11-04 (tiled witness, Q = 280) |
|---|---:|---:|
| D55 fork run at N = 6, best wall | 5.579 s = 22.94 tok/s | **5.278 s = 24.25 tok/s** |
| D12a serial, best wall | 11.061 s | 11.119 s |
| setup | 15.1 s | 9.1 s |
| total | 110.9 s | 77.1 s |
| witness per call [INFERRED: total − setup − timed calls − verifications, over 5 calls] | 8.64 s | **3.09 s** |
| **one request on the target's clock** (proof + witness) | about 14.2 s = **9.0 tok/s** | about 8.4 s = **15.3 tok/s** |
| receipt | 790,844,032 B | 818,728,672 B (+3.5%, as Q = 280 predicted) |

Both figures are inferred by the same subtraction; the box is shared.

## H124c: the witness ON the clock, measured (2026-11-04, night)

**Correction to the row above.** "One request on the target's clock … 15.3 tok/s" adds the parallel build of the 32
witnesses from KNOWN block inputs. A real request does not know them: block `k + 1`'s input is block `k`'s output, so
the forward chain (the sealing pass) is serial, and it was outside every clock so far. Measured here, it is the
largest single cost.

**What was added (test code only, no byte moves).** The harness `d55_ab_one_request_serial_against_forks` now:
- times the sealing pass (the 32 serial full witness builds of its setup);
- takes `HL_D55_JIT=builders:ahead,...`, one extra fork arm per pair. In that arm every witness is built ON the
  clock, just in time: builder threads run at most `ahead` blocks beyond the fork prover's feeder (`Jit`,
  `jit_builder` in `run_fork_tests.rs`). The fork prover already pulls witnesses one by one (`run_fork.rs`, phase 2),
  so building overlaps proving with no prover change.

**Command:** guarded (class gpu), `HL_GPU=1 HL_PB_ORACLE=0 HL_METAL_TIMING=0 HL_D55_PROFILE=W16R2_8B_T128_H24
HL_D55_L=32 HL_D55_WORKERS=6 HL_D55_PASSES=2 HL_D55_JIT=2:4,4:6,8:8` (`check_jit.sh`, log `d55_ab_jit.log`). Every arm's
receipt verified (D55 verifier, 6 threads, about 2.6 s).

**One W16R2 8B T128 request, 32 blocks** [MEASURED, best of 2 warm passes, shared box]:

| | wall | proved tok/s |
|---|---:|---:|
| D12a serial, witnesses prebuilt | 11.084 s | 11.55 |
| D55 forks N = 6, witnesses prebuilt (proof only) | 5.629 s | 22.74 |
| D55 forks N = 6, every witness built on the clock, 2 builders, 4 ahead | 7.345 s | 17.43 |
| same, 4 builders, 6 ahead | 7.508 s | 17.05 |
| same, 8 builders, 8 ahead | 7.889 s | 16.22 |
| **the sealing pass: the forward chain, 32 serial full builds** | **8.223 s** | — |
| **one request end to end: sealing pass + the best on-the-clock fork run** | **15.568 s** | **8.22** |
| one request end to end, if the sealing pass KEEPS its 32 witnesses (9.6 GB) and the forks use them [INFERRED: 8.223 + 5.629] | 13.85 s | 9.24 |

**What it says.**
- Building on the clock costs the forks about 1.7 s (5.0 to 6.4 s for the forks phase). The builders and the fork
  provers share the CPU, and more builders make it worse, so the Mac's fork run is not purely GPU-bound.
- **The serial forward chain is the critical path: 0.257 s per block.** The weight products are 0.085 s of that;
  the rest of the builder (norms, RoPE, attention, lookups, limbs) scales poorly across threads.
- **Keeping the sealing pass's witnesses beats rebuilding them** for one request (9.24 against 8.22 tok/s). Memory
  is not a constraint here (0.30 GB per witness).
- For a stream of requests (D64 allows batching), the next request's sealing pass can run while this one's forks
  prove. The rate is then bounded by the larger of the two stages and by the CPU they share: about 7.3 to 8.2 s per
  request, roughly 16 to 17 tok/s on the Mac [INFERRED, not measured].

**Next, in order.**
1. Parallelize the builder's remainder. This shortens the critical path directly: at 0.12 s per block the chain is
   about 3.8 s, so one request is about 9.4 s, about 13.6 tok/s [INFERRED].
2. A production D55 source that keeps the sealing pass's witnesses (the CLI's `StackSource` serves D12a only; it
   builds every witness twice).
3. A multi-request pipelined harness, to measure the batched rate D64 is stated in.
4. GPU products (H124b) on the 5090. The Mac's CPU is shared by builders and provers, so moving the products off it
   helps both.
