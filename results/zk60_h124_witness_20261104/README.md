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
