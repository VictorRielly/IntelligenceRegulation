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
