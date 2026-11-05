# A4: the witness weight products on the Metal GPU, exactly (2026-11-05)

This is plan item A4 (`docs/zkmatrix-poc/ZK60_EFFICIENCY_PLAN_20261105.md`). It is byte-preserving. Every product is
an exact integer sum, so the device must return the CPU's words. No protocol, transcript, profile or receipt code
changed.

Labels:
- [MEASURED]: on the shared Mac, one run unless stated. Other lanes' guarded jobs ran between ours, never beside them.
- [INFERRED]: a difference or quotient of measured figures.

## 1. Result

| W16R2 8B T128, forks N = 6 | CPU products (`HL_GPU_WITNESS=0`) | device products (default) |
|---|---:|---:|
| one block's whole witness, 32 threads (A4 timer, best of 5) | 0.162 s | **0.103 s** |
| the seven products alone (dense words, best of 5) | 0.085 s | **0.014 s** |
| sealing pass, 32 serial builds (harness setup, uncontended) | 5.450 s | **3.615 s** |
| sealing pass on the SEALED clock (two passes) | 5.891 / 5.913 s | **4.172 / 4.231 s** |
| **one request from its input (SEALED), best** | 10.919 s = 11.72 tok/s | **9.237 s = 13.86 tok/s** |
| one request (SEALED), mean of 2 | 10.978 s = 11.66 tok/s | 9.370 s = 13.66 tok/s |
| **4-request stream, steady** | 15.98 tok/s | **20.73 tok/s** |
| 4-request stream, amortized | 14.15 tok/s | 18.20 tok/s |
| stream completions | 12.15, 20.64, 28.78, 36.18 s | 9.60, 15.74, 22.05, 28.13 s |
| stream per-request latency | 12.15, 14.73, 14.51, 13.51 s | 9.60, 11.63, 11.65, 11.29 s |
| forks, witnesses prebuilt (proof only), best | 5.337 s = 23.98 tok/s | 5.165 s = 24.78 tok/s (within noise) |
| receipt | 818,728,672 B | 818,728,672 B |

All figures are [MEASURED]. Sources:
- the harness rows: one build, run twice, back to back (`s3_d55_cpu.log`, `s4_d55_gpu.log`);
- the per-block rows: `s1c_timer.log`.

Every receipt verified in both runs: D12a, the D55 forks, both SEALED passes, and all 4 stream receipts.

**Before this change.** A2's record (`results/zk60_effplan_20261105/README.md`) gives:
- sealing 5.56–6.13 s;
- sealed 10.81 s = 11.84 tok/s;
- stream 15.95 tok/s steady.

The CPU-products run on this build agrees with it.

**Concurrency.** In the stream, the device products share the GPU with the fork provers. The stream still got faster:
- 15.98 → 20.73 tok/s steady (×1.30);
- 37 → 28 s for 4 requests.

The CPU the builders no longer spend on products outweighs the added GPU work. At 9–14 ms per block, that work is
about 0.3–0.45 s of GPU per request, against about 5 s for the fork run [INFERRED]. So no gating is needed: the device
path stays on for the sealing pass and the stream alike. `HL_GPU_WITNESS=0` turns it off.

## 2. What changed

**`hashline/src/gpu/metal.rs`**: a new section `[A4]` at the end, the only new device code.
- `WPROD_SRC` is a separate Metal library, compiled at first use with fast math OFF. It holds:
  - the float kernel `k_wprod_sg<FM, FN>`, instantiated as `k_wprod_sg_4x2` and `k_wprod_sg_2x4`;
  - the integer kernel `k_wprod_int`;
  - their shared weight-tile loader `wp_weights`.
- `wctx` compiles the library, checks the pipelines (256 threads, SIMD width 32) and runs the exactness self-check
  once. It keeps any failure, so every later call declines.
- `wprod_self_check`.
- `witness_product` and `witness_product_with`: the shape bounds are checked before any device work. They return
  `Ok(None)` when the CPU must take the product, and `Err` on a device failure.
- `wprod_run`: pack, present the weights, run on the witness queue (with the GPU's own clock), write back.
- The no-copy views: `page_size`, `pages_view`, `page_view`, `weight_buffer`, `result_plane`.
- Test-only statistics and switches.

The products have their own command queue. The existing code is untouched.

**`hashline/src/gpu/mod.rs`**: re-exports, and a `witness_product` stub that returns `Ok(None)` (the CPU path) in every
build without the Metal backend.

**`hashline/src/private_block/witness.rs`**: the dispatch only.
- `matmul` and `matmul_in_out` first ask `on_device`. On `None`, the unchanged CPU code runs.
- `on_device` uses the device only when all of these hold:
  - `crate::gpu::enabled()`, that is a gpu-metal build with `HL_GPU=1`;
  - `HL_GPU_WITNESS` is not `0`;
  - the product has at least `HL_GPU_WITNESS_MIN_MACS` multiply-adds. The default is 2^28: every 8B product is
    above it, and the rung's products are below it.
- A device error is a decline (`gpu::declined`): the CPU path, or a panic under `HL_GPU_REQUIRED=1`.
- Test-only: a per-thread force switch, and a per-thread count of device products.

**Tests and harness**:
- the tests in `witness_speed_tests.rs`;
- the D55 harness's A4 evidence line in `run_fork_tests.rs`;
- this directory's scripts and logs.

**What the transfers do.**
- The activations are checked to fit i16 and packed into a pooled int16 buffer. Eight rows go to each rayon task.
- With `HL_GPU_WITNESS_VIEW` unset (the default), the weights reach the device as a read-only no-copy view of the
  pages that hold them.
- In the same mode, the kernel writes the int64 result plane at the caller's row stride, in place, straight into the
  result `Vec`. It does so through a no-copy view of that `Vec`'s own pages: its allocation is calloc'd with its
  capacity rounded up to whole pages, and the view is used only when the allocation starts on a page.
- Otherwise, or with `HL_GPU_WITNESS_VIEW=0`, the weights are copied into a pooled buffer, and the outputs are
  written there and then scattered.
- In the D55 run, 2,707 of 2,719 device products wrote in place. The 12 others are small self-check planes.

**No new production file**, so there is no new source pin and no scan list change.

## 3. The routes, and why (b) at the 2 × 4 layout

Each figure is one W16R2 8B T128 block, the seven products, on the GPU's own clock [MEASURED, `s1c_timer.log`]. The
figure in brackets is the previous run, `s1b_timer.log`.

| Route | weights and outputs mapped | weights and outputs copied |
|---|---:|---:|
| (b) float, `simd2x4` (each simdgroup 16 tokens × 32 outputs) | **9.9 ms** | 8.4 ms |
| (b) float, `simd4x2` (32 × 16) | 12.1 ms (10.7) | 14.0 ms |
| (a) int32 multiply-adds, `int` | 19.5 ms (20.7) | 14.3 ms |

- **(b) is about twice as fast as (a).** At 9.9 ms the float route does about 5.6 T exact fp32 multiply-adds a
  second, counting both byte halves. That is about 39% of the M3 Ultra's fp32 peak [INFERRED].
- **Why 2 × 4.** It is the lowest GPU time in both transfer modes, and the GPU time is what competes with the fork
  provers. On the whole witness, the three routes are within noise of each other: 0.099–0.103 s mapped.
- `HL_GPU_WITNESS_ROUTE` selects another route: `int`, `simd4x2` or `simd2x4`.

**End to end, per block of seven, on the default route** (mapped; means over 6 rounds; `s1c_timer.log`):

| Phase | ms |
|---|---:|
| pack activations | 2.56 |
| weights view | 0.10 |
| output plane and encode | 0.31 |
| command buffer | 14.16 |
| of which on the GPU | 9.89 |
| scatter | 0 |

The products-alone best is 14.1 ms, against the CPU's 85 ms.

**What the views bought.**
- Mapping the weights instead of copying them saves about 4.7 ms per block.
- Writing in place saves the 5.8–6.1 ms scatter (`s1b_timer.log` against `s1c_timer.log`).
- The rest of the command-buffer time (about 0.5–0.6 ms per product beyond the GPU's own) is per-command-buffer
  latency. Batching Q, K and V into one command buffer would need a builder change, so it is not done here.

## 4. Exactness (the slab bounds)

**Route (b), float.** For x in [−32768, 32767] and w in [−128, 127]:
- **The split.** x = 256·hi + lo, with lo = x & 255 in [0, 255] and hi = (x − lo)/256 in [−128, 127]; the division is
  exact. Every operand is an integer of magnitude at most 255, so it is a binary32 value.
- **The products.** |lo·w| ≤ 255·128 = 32,640, and |hi·w| ≤ 128·128 = 16,384.
- **The slab.** A slab is 512 consecutive terms (16 tiles of 32). In whatever order or fusion the matrix hardware
  sums, every value it forms inside a slab is a sum of a subset of the slab's products. So its magnitude is at most
  512·32,640 = 16,711,680 < 2^24 = 16,777,216.
- **Why that is exact.** Every integer of magnitude at most 2^24 is a binary32 value. An operation whose exact result
  is representable returns it unchanged, under correct or faithful rounding. So every slab sum is the exact integer.
- **The totals.** Each slab sum is converted to int32, exactly, through the simdgroup's own threadgroup scratch, and
  added to an int32 total. The bound is |Σ lo·w| ≤ K·32,640 < 2^31 for K ≤ 65,536 (`WP_MAX_K`, checked before any
  device work); the same holds for hi.
- **The output** is 256·hi_total + lo_total in int64, which is Σ x·w.
- **Belt and braces.** Fast math is off for this library. A start-up self-check runs every route, both weight layouts
  and both transfer modes at 65 × 1,100 × 70: three slabs with the last one partial, and partial tiles in every
  dimension. It uses two public patterns:
  - every product at the slab bound: x = 32,767 (low byte 255, high byte 127) times w = −128;
  - mixed extremes.

  Any difference from the host's i64 sums turns the device path off for the process.

**Route (a), int.** |x·w| ≤ 32,768·128 = 2^22, so an int32 partial over 256 terms is at most 2^30 < 2^31. The
partials are widened to int64 between them.

## 5. Byte identity: the tests

All of these are in `witness_speed_tests.rs`. All pass in the full suite (`s2_full.log`) and in `s1c_tests.log`.

**`a4_the_device_products_equal_the_cpu_ones_on_every_input_class`.** Every route, in both modes, against the
sequential reference.
- Input classes:
  - int8;
  - i16 at ±32,767;
  - the full i16 range with −32,768, with and without a sprinkling of zeros;
  - −32,768 throughout;
  - all zeros.
- Random int8 weights in [−128, 127], in both layouts.
- Sizes from 1 × 1 × 1 up to 128 × 2,049, with partial tiles in every dimension and several slabs.
- Row strides wider than the rows, and weights at an odd offset inside a longer buffer, which tests the page view's
  offset.
- Then every product the builder makes at the two rung shapes, through the CPU path too.

**`a4_the_device_products_are_exact_at_their_extremes`.**
- Pairs: x ∈ {32,767, −1, 255, −32,768, −32,767} with w ∈ {−128, −127, 127}, at 8 sign pairs.
- One sign throughout, so each slab sits at its bound.
- Totals reach −8.6·10^9, far beyond int32.

**`a4_activations_outside_i16_stay_on_the_cpu`.**
- One word of 32,768, −32,769 or 2^40 makes the device return `None` on every route, before any device work.
- The builder's product, though forced onto the device, then equals the sequential sums.
- No device product is counted for it.

**`a4_the_device_builder_equals_the_cpu_one_on_every_plane`.** It covers the six H124c profiles:
- R13 TINY T128 LOW;
- R13 8B T128 H24 DD;
- R13 RUNG H24;
- **W16R2 RUNG H24**;
- W16 SHIELD T256 H24;
- **W16R2 8B T128 H24**.

Every route is used, with all seven products of every build forced onto the device and counted (7 of 7). Results:
- every plane and the output plane are equal for each admissible input;
- the DD profile refuses all four inputs with the CPU builder's own error.

**`a4_forcing_the_device_never_changes_a_product`.** This test runs in every build. Without the Metal backend, the
forced request falls back to the CPU.

**End to end, the six trained digests.** The Metal arm of `m4_trained_accuracy_block_cpu_and_metal_digests_and_times`
builds its witness under `HL_GPU=1`, and the CPU arm with `HL_GPU` unset. All six digests equal the pinned values, with
`HL_GPU_REQUIRED=1`.

At these 8B and Shieldstral shapes every product has at least 2^28 multiply-adds. So by the dispatch rule, the Metal
arm's products ran on the device [INFERRED]. That test does not count them. The device path at W16R2 8B T128 is counted
directly in the D55 run: 2,719 products, every receipt verified.

## 6. Acceptance

**Full lib suite** (`s2_full.log`): 918 passed, 3 failed, 95 ignored. The three failures are exactly the known ones:
- `review_tests::a_toy_receipt_made_before_f12_is_refused`;
- `trained_block::accuracy::profile_tests::accuracy_v2_dense_witness_matches_all_nineteen_independent_integer_traces`;
- `trained_stack_tests::review_n_r6_b_a_stale_statement_writing_dir_is_removed_or_refused_by_name`.

Before this change the count was 913 / 3 / 94. The difference is the five new tests and one new ignored timer.

**The goldens and digests:**
- the W16R2 rung golden with `HL_GPU_REQUIRED=1` passes (`s2_r2rung.log`);
- the six trained digests with `HL_GPU_REQUIRED=1` are all present and unchanged (`s2_trained.log`): 5a6193d3,
  f590b01f, 79f987ef, a8258241, 0e88d84f, 90003b76;
- no decline was logged anywhere.

**The D55 harness:** the command from the brief, run twice on one build, `HL_GPU_WITNESS=0` against the default
(`s3.sh`, `s4.sh`). Every receipt verified.

**Build:**
- No new warnings from the A4 code (29 warning lines, as in the H124 build). `objc`'s `msg_send!` raised a check-cfg
  warning, so `send_message` is called directly instead.
- The lib tests also check clean without `gpu-metal` (`cargo check --tests`, `s5_check_nometal.log`): the gate chain's
  CPU-only configuration.

**How the jobs ran:**
- every build, test and GPU run went through the guard, as class gpu, `--need-gib 48 --cap-gib 120`;
- each stage was one guarded job, run one at a time and detached (`run_stage.py`);
- the D55 stage's peak RSS was 29.1 GiB, and its peak GPU memory 21.2 GB.

## 7. What the privacy gate (D60, the real-content flip) will need to read

No new file is pinned. The three files below were already pinned, and their digests changed. The gate reads a moved
pin only at a full digest, so these need a re-read: `src/gpu/metal.rs`, `src/gpu/mod.rs`,
`src/private_block/witness.rs`.

**What a reader must cover:**

1. **The new device code, `metal.rs` section `[A4]`.** This is the MSL in `WPROD_SRC` and its host:
   - `witness_options`, `wctx`, `wprod_self_check`;
   - `witness_product`, `witness_product_with`, `wprod_run`;
   - `page_size`, `pages_view`, `page_view`, `weight_buffer`, `result_plane`.

   **The device code handles private values:**
   - the activations x;
   - the int64 products, which become the builder's private Q / K / V / AO / gate / up / down accumulators.

   They never leave the machine. Nothing prints, hashes or serializes them. Errors name a shape or a device state.
   The self-check uses public synthetic data.
2. **Residue.** The packed activations sit in a pooled shared buffer that keeps its stale contents after return. That
   is the same class as the existing pooled A, H and table buffers: never read before being written.

   In the fallback mode only, the outputs also pass through a pooled buffer. In the default mode they are written
   straight into the caller's `Vec`.
3. **The no-copy views.**
   - The weight view maps the whole pages holding the public weights, read-only for the kernel. Its first and last
     page may include neighbouring heap bytes; the kernel never reads them.
   - The result view maps exactly the result `Vec`'s own pages, and is writable. It is used only when the allocation
     starts on a page and spans whole pages of its own. The kernels write only inside the first `out_len` words.
   - Both views are dropped after the command buffer completes.
4. **The dispatch, `witness.rs`: `DEVICE_MIN_MACS`, `device_wanted`, `on_device`, and the two call sites.**
   - With `HL_GPU` unset, `crate::gpu::enabled()` is false, and no device entry runs. This is the same property the
     round-26 CPU-path reading recorded.
   - Whether a product goes to the device depends on whether the activations fit i16, which is a private-data-dependent
     branch. It is of the same kind as the existing CPU branch between the i16, i32 and i64 paths. The kernels'
     work is data-independent.
5. **The environment switches.**
   - The switches are `HL_GPU_WITNESS`, `HL_GPU_WITNESS_MIN_MACS`, `HL_GPU_WITNESS_ROUTE` and
     `HL_GPU_WITNESS_VIEW`.
   - They change where and how the products are computed, never the values.
6. **The capture manifest's `proved_on_gpu`.**
   - Under `HL_GPU=1`, the witness's weight products are now device-made too.
   - The existing rule already covers it: GPU-made bundles stay refused until the Metal device paths are fully read.
   - W-1 and W-2 apply unchanged.

`run_fork::D55_REAL_CONTENT_PRIVACY_GATE_PASSED` was not touched.

## 8. Not done

- **Kernel tuning beyond the two layouts.** The float route runs at about 39% of the fp32 peak. Options left:
  - double-buffered tiles;
  - a larger K tile;
  - fewer threadgroup loads per MMA.

  The likely gain is 3–5 ms per block, about 0.1–0.15 s per request [ESTIMATE].
- **Per-command-buffer latency**, about 0.5 ms per product. Batching Q, K and V, or all seven products, into one
  command buffer would need the builder to hand over several products at once. That is outside the dispatch-only
  scope.
- **The repeat measurement.** Each D55 figure above is one run of each arm, on a shared box. The before arm agrees with
  A2's record.
- **No CUDA path.** On a gpu-cuda build, `witness_product` is the CPU stub.
- **The parent README.** `results/zk60_effplan_20261105/README.md` and `MVP_STATUS.md` are not updated here. They are
  the coordinator's files.

## Files here

- **Scripts:** `run_stage.py`, a detached runner that runs each stage as one guarded job. The stages are:
  - `s1.sh`, `s1b.sh`, `s1c.sh`: tests and the timer, three iterations;
  - `s2.sh`: the suite, the golden and the digests;
  - `s3.sh`: D55 with CPU products;
  - `s4.sh`: D55 with device products;
  - `s5_check_nometal.log`: the check without `gpu-metal`, guarded as class build.
- **Per stage:** `*.progress`, `*_*.log`, `*.guard.log`, `*.guard.json` and `*.done`.
