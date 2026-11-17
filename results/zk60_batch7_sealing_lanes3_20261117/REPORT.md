# Batch 7 Report — 32-Block Witness Sealing Phase Profile, Overlap Slowdown Decomposition, & 3-Lane Server Stream (`W16R2_8B_T128_H24`)

**Date:** `2026-11-17` (Updated post-review per `results/zk60_claude_review_20261116/BATCH7_REVIEW.md`, `H1..H15`)
**Branch / Git HEAD:** `perf/zk-batch-optimizations` at `4716c6b5` (`0 B` diff in `ops/zkp-mvp/gpu-metal/**`; binary built at `2df5f72d`)
**Hardware:** Apple M3 Ultra (`32` CPU cores, `256 GiB` unified RAM), `zk60_resource_guard.py` quiet GPU (`waited=0.0–0.1 s` on all 3 leaves; `ds4-bench` pre/post `pgrep` check recorded in JSON for `serve4` and `serve6+lanes3` [`4` checks], while `serve1` reused the immediately preceding guarded leaf `061723c7aeb6`)
**HEAD Test Binary:** `hashline-a90b6cf7715dc2a7` (`22,951,056 B`, `sha256 aaaab7e6fd38af59d406f201f94cfdb0325a3fe6adb3a04332873580f3acad11`)

---

## 0. Batch 7 Scope, Fixture Conditions, & Source-Pin Audit

Per `ops/zkp-mvp/RECOVERY_COORDINATION.md:3196-3200` and `BATCH7_REVIEW.md`:

1. **Batch 5 & Batch 6 Corrections:** Committed at **`4716c6b5`** (`20` explicit named files in `results/zk60_h132_batched_forward_20261116/`, zero 0-byte logs, no push).
2. **Per-Phase Sealing Pass Profile (`n = 6` warm passes, Solo vs Overlapped):** Measured across `serve1` (`6` warm solo requests), `serve4` (`6` warm unoverlapped `req 0`s + `18` warm overlapped `reqs 1..3`), and `serve6+lanes3` (`6` warm unoverlapped `req 0`s + `30` warm overlapped `reqs 1..5`; pooled solo `n = 18` median `2.1740 s`).
   - **Zero prover source files touched (`0 B` diff):** Sol's `results/zk60_sol_20261105_w16r3/INPUTS.json` pins 11 Rust files (`metal.rs`, `pcs.rs`, `run_fork.rs`, `run_fork_tests.rs`, etc.), and Astra's `results/zk60_astra_20261026/a2_real_length_review_20261117/SOURCE_BASE.json` pins `trained_block.rs`, `witness.rs`, and `witness_accuracy.rs`.
   - **Fixture & run-order scope (`H12`, `H15`):** `a22_stream_ab` serves the harness's **synthetic 32-block stack (`A22Synth`, honest chain)** — not a trained export — with `HL_A27_GPU_TRACE` enabled in all three arms, executed in fixed order (`serve1`, `serve4`, `serve6+lanes3`, passes not interleaved). Uniformly across metrics, this batch ran **`1.0–2.0%` slower than Batch 6** (`serve4` steady cadence `3.668 s` vs Batch 6's `3.606 s` [`+1.7%`]; `serve1` solo sealing `2.215 s` vs `2.172 s` [`+2.0%`]; `serve1` pass wall `6.188 s` vs `6.093 s` [`+1.6%`]).
3. **3-Lane Server Stream (`serve6+lanes3`, `n = 6` warm passes):** Measured at `lanes = 3` (`--need-gib 48 --cap-gib 64`) alongside `serve4` (`lanes = 2`, `--need-gib 40 --cap-gib 52`) and `serve1` (`--need-gib 36 --cap-gib 48`), all at `HL_METAL_TIMING=0`, `HL_PB_ORACLE=0`, `HL_D55_WORKERS=6`, `HL_A19_BUDGET_GIB=32`.
   - **Budget & verification scope (`H9`):** `HL_A19_BUDGET_GIB=32` sets `cfg.budget` (`budget_bytes` passed to each request's `seal_chain` — a **per-request** witness/part retention budget, identical at `32 GiB` in all three arms; lane count is set by the arm label `lanes=2` vs `lanes=3`, and `48/64 GiB` are `zk60_resource_guard.py` limits). In each arm, `a22_stream_ab` verifies all receipts from their run directories twice (**the cold request and warm pass `0` only**); warm passes `1..5` print the receipt size (`818,728,672 B` each) without re-verifying or logging proof digests.
4. **Permanent Trace Archive Outside Repository:** All 3 raw `HL_A27_GPU_TRACE` TSVs are gzip-compressed and retained at `/Users/victorrielly/zk60-artifacts/batch7_traces_20261117/` (`1.45 MB` total compressed; `0` uncompressed `.tsv` leftovers):

| Arm | Guard `run_id` | Retained `.tsv.gz` Path | `.tsv.gz` Bytes | `.tsv.gz` SHA-256 | Raw TSV Bytes | Parsed CB Rows |
| :--- | :--- | :--- | :---: | :--- | :---: | :---: |
| `serve1` (`6` warm) | `061723c7aeb6` | `/Users/victorrielly/zk60-artifacts/batch7_traces_20261117/serve1_6warm.15048.tsv.gz` | `153,149` | `aeb584645bf21dc4bf045fea2db82303a03b1f38bdcbcf20fe1e2c581895b4ba` | `1,161,441` | `5,887` |
| `serve4` (`lanes=2`, `6` warm) | `48fd544d9472` | `/Users/victorrielly/zk60-artifacts/batch7_traces_20261117/serve4_lanes2_6warm.15818.tsv.gz` | `524,430` | `fc8133ebbab5d082d388dde6587ab6797afa9ddeccd9fe25d0d401a2a0ce67bf` | `4,084,448` | `20,413` |
| `serve6+lanes3` (`lanes=3`, `6` warm) | `604ae9fa4f37` | `/Users/victorrielly/zk60-artifacts/batch7_traces_20261117/serve6_lanes3_6warm.16734.tsv.gz` | `771,461` | `258c66a8ced808fe3a32349a75e9f405d1a9ae843044451357dcb7ec7de1332c` | `6,031,379` | `30,091` |

---

## 1. Per-Phase Profile of the 32-Block Witness Sealing Pass (`n = 6` Warm Passes)

### 1A. Phase Boundaries (`[MEASURED]`) vs Gap Contents (`[CODE-READ / ASSUMED]`) (`H2`, `H5`, `H6`)

- **`[MEASURED]` Phase Boundaries:** In `a22_stream_ab` (`window = 0`, `HL_A23_SHARE = 1`), `Turn` serializes sealing passes (`1` active sealing pass at a time), and each 32-block request emits **32 sequential blocks × 7 `wprod` command buffers = 224 `wprod` CBs** on witness `queue 99` (`Q, K, V, Wo, Wg, Wu, Wd`) with 5 recorded timestamps (`begin, committed, gpu_start, gpu_end, done`). All 4 per-block data-dependency barriers (`max_done(Q,K,V) <= begin(Wo)`, `done(Wo) <= min_begin(Wg,Wu)`, `max_done(Wg,Wu) <= begin(Wd)`, `done(Wd_k) <= min_begin(Q,K,V)_{k+1}`) hold across every warm block (`2,112` warm blocks = `14,784` `wprod` CBs) with zero violations.
  - **`P1` (`Q, K, V` `wprod` group wall):** `[min_begin(Q,K,V), max_done(Q,K,V)]` (`3` CBs).
  - **`P2` (Intra-block host gap 1):** `[max_done(Q,K,V), begin(Wo)]` (`0` `wprod` CBs in flight).
  - **`P3` (`Wo` `wprod` wall):** `[begin(Wo), done(Wo)]` (`1` CB, `4096 -> 4096`).
  - **`P4` (Intra-block host gap 2):** `[done(Wo), min_begin(Wg,Wu)]` (`0` `wprod` CBs in flight).
  - **`P5` (`Wg, Wu` `wprod` group wall):** `[min_begin(Wg,Wu), max_done(Wg,Wu)]` (`2` CBs, `4096 -> 16384` each).
  - **`P6` (Intra-block host gap 3):** `[max_done(Wg,Wu), begin(Wd)]` (`0` `wprod` CBs in flight).
  - **`P7` (`Wd` `wprod` wall):** `[begin(Wd), done(Wd)]` (`1` CB, `16384 -> 4096`).
  - **`P8` (Between-block & bookend host time with `0` `wprod` CBs in flight):** `P8a + P8b`, where **`P8a` (`[MEASURED]`)** is the sum of the `31` inter-block gaps `[done(Wd_k), min_begin(Q,K,V)_{k+1}]` and **`P8b` (`[RESIDUAL]`)** is `seal_pass_s` (`1 ms`-resolution log timer) minus `[first_begin(Q,K,V)_0, done(Wd)_{31}]` (`0.033–0.037 s` across requests; `sum(P1..P8) = seal_pass_s` by construction).
  - **`P9` (Post-pass sealing-side tail):** `seal_side_total_s - seal_pass_s` (`seal_done - seal_turn - seal_pass_s`, from log).

- **`[CODE-READ / ASSUMED]` What Runs Inside `P2, P4, P6, P8` (No Sub-Timers Inside Gaps in Batch 7):**
  - **Boundary-crossing preludes & tails (`metal.rs:4797-4839`, `witness_accuracy.rs:672`):** `begin = host_time_s()` is stamped **after** each `wprod`'s host prelude: the `i16` activation pack (`~2.56 ms/blk ≈ 0.08 s/req` measured in A4), `weight_buffer` (no-copy page view of weights), and `result_plane` (freshly zeroed `Vec<i64>` output plane + page view). Copy-back/drop runs after `done`. Thus `Q/K/V` preludes land in **`P8`**, `Wo` prelude in **`P2`**, `Wg/Wu` preludes in **`P4`**, and `Wd` prelude in **`P6`**; additionally, requantisation and RoPE of the last-finishing `Q/K/V` branch inside `rayon::join` sit in **`P2`**.
  - **Intra-block compute (`SealPool(8)`):** `P2` runs attention scores (`Q·K^T`), softmax, and `P·V` (+ `QKV` tail & `Wo` prelude); `P4` runs `AO` requant, residual 1, and `norm_m` (+ `Wg/Wu` preludes); `P6` runs SwiGLU gate lookup, `G ⊙ U`, and `H` limb decomposition (+ `Wd` prelude).
  - **Between-block serial chain in `P8` (`trained_block.rs:3020-3088`):** Between `done(Wd_k)` and `min_begin(Q,K,V)_{k+1}` run, in order: the builder tail (`Z`, residual 2), `assign_with` (allocating/zeroing/scattering `Vec<i64>` witness planes — `D, Q, S` `4 MiB`, `Kv` `1 MiB`, `F` `16 MiB` at `t_pad = 128, f_pad = 16,384`; note `H` is built in the prover, not in sealing), `check_lookup_misses` (CS-3), `padded_plane`, `true_words`, `seq` comparison, `hand.block`/`hand.witness`, next block's `build_for_block` (`check_accuracy_for_shape` including the `-128` scan of 9 weight arrays), `norm_a` + requantisation, and `Q/K/V` preludes. **How much of the `~36 ms/gap` (`1.20 s` total) each item takes is NOT measured in Batch 7.** Prior A16 sampler profiling (`results/zk60_effplan_20261105/a16/README.md`, 2026-11-06 revision, `1.63–1.67 s` harness pass) put fresh-plane zeroing/first-touch at **`0.05–0.10 s/pass`** (`~529k` minor faults ≈ `8.1 GiB` at `16 KiB` pages; peak footprint step in Batch 7 is `5.35 GiB / 32 = 169 MiB/blk`), limb scatter at `0.29 s`, quantisation fills at `0.20 s`, and device wait at `0.36 s`.

- **`[MEASURED]` Disjoint Partition of Each `wprod` Group `[min_begin, max_done]` (`H5`):**
  1. **`wprod` GPU busy (`gpu_busy_union`):** `t ∈ ⋃ [gs_i, ge_i]` (at least one `wprod` CB of the group executing on GPU).
  2. **`wprod` commit-to-`GPUStartTime` wait (`ext_gpu_queue_wait`):** `t ∉ ⋃ [gs_i, ge_i]` and `t ∈ ⋃ [committed_i, gs_i]` (at least one CB committed and waiting before `GPUStartTime`, while zero CBs of the group execute on GPU). Solo (`0.249 s/req`), its cause is **not separated** across submit-path overhead, GPU wake, and `newBufferWithBytesNoCopy` page-view residency (`0.92–1.07 ms` median on `Q/K/V/Wo` vs `1.5–2.2 ms` on `67 MB` `Wg/Wu/Wd`). Beside a proof (`0.704 s/req`), **`87–97%`** of this wait occurs while prover CBs on shared `queue 0` are actively executing on the GPU.
  3. **`wprod` encode + completion wake (`host_inside_wall`):** `wall - gpu_busy - ext_gpu_queue_wait` (`0.016 s/req`: `begin -> committed` encode `~0.0025 s` + `gpu_end -> done` completion wake + overlapped `QR/KR` RoPE inside `P1`; does **not** include the `i16` pack, which runs before `begin`).

### 1B. Solo vs Overlapped Per-Phase Breakdown (Medians & IQRs, `L = 32` Blocks)

| Phase / Metric (32-block request) | `serve1` Solo (`n = 6`) Med (IQR) | Solo Share (`%` of `2.215s`) | `serve4 req 0` Solo (`n = 6`) Med (IQR) | `serve4 reqs 1..3` Overlapped (`n = 18`) Med (IQR) | `serve6+lanes3 reqs 1..5` Overlapped (`n = 30`) Med (IQR) | Ratio (`serve4` Ov / `serve1` Solo) |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: |
| **`seal_pass_s` (32-block witness pass)** | **`2.2150 s`** (`0.070`) | **`100.0%`** | **`2.1520 s`** (`0.066`) | **`3.3535 s`** (`0.176`) | **`3.2305 s`** (`0.175`) | **`1.514x`** (`1.558x` in-proc; `1.543x` vs pooled `2.174s`) |
| `seal_side_total_s` (`seal_done - seal_turn`) | `2.2280 s` (`0.070`) | — | `2.1660 s` (`0.066`) | `3.3665 s` (`0.183`) | `3.2960 s` (`0.201`) | `1.511x` |
| `P1`: `Q, K, V` `wprod` wall (`96` CBs) | `0.1013 s` (`0.029`) | `4.6%` | `0.0954 s` (`0.025`) | `0.2504 s` (`0.029`) | `0.2444 s` (`0.046`) | **`2.472x`** (`2.625x` in-proc) |
| `P2`: Intra-block host gap 1 (attn + `QKV` tail + `Wo` pre) | `0.1765 s` (`0.001`) | `8.0%` | `0.1765 s` (`0.002`) | `0.2549 s` (`0.026`) | `0.2515 s` (`0.024`) | `1.444x` |
| `P3`: `Wo` `wprod` wall (`32` CBs) | `0.0737 s` (`0.030`) | `3.3%` | `0.0634 s` (`0.004`) | `0.2110 s` (`0.069`) | `0.1944 s` (`0.048`) | **`2.863x`** (`3.328x` in-proc) |
| `P4`: Intra-block host gap 2 (`AO`/`res1`/`norm_m` + `GU` pre) | `0.0631 s` (`0.003`) | `2.8%` | `0.0620 s` (`0.001`) | `0.0884 s` (`0.009`) | `0.0891 s` (`0.012`) | `1.401x` |
| `P5`: `Wg, Wu` `wprod` wall (`64` CBs) | `0.2363 s` (`0.029`) | `10.7%` | `0.2201 s` (`0.034`) | `0.3630 s` (`0.055`) | `0.3483 s` (`0.054`) | `1.536x` |
| `P6`: Intra-block host gap 3 (SwiGLU/limbs + `Wd` pre) | `0.1643 s` (`0.001`) | `7.4%` | `0.1659 s` (`0.003`) | `0.1875 s` (`0.018`) | `0.1957 s` (`0.025`) | `1.141x` |
| `P7`: `Wd` `wprod` wall (`32` CBs) | `0.1959 s` (`0.015`) | `8.8%` | `0.1874 s` (`0.024`) | `0.3152 s` (`0.029`) | `0.2615 s` (`0.037`) | `1.609x` |
| **`P8`: Between-block & bookend host time (`0` CBs in flight)** | **`1.2020 s`** (`0.061`) | **`54.3%`** | **`1.1563 s`** (`0.045`) | **`1.6463 s`** (`0.106`) | **`1.6404 s`** (`0.055`) | **`1.370x`** (`1.424x` in-proc) |
| ↳ `P8a`: 31 inter-block gaps (`[MEASURED]`, flat `~36 ms/gap`) | `1.1665 s` (`0.066`) | `52.7%` | `1.1181 s` (`0.049`) | `1.5989 s` (`0.102`) | `1.5909 s` (`0.061`) | `1.371x` |
| ↳ `P8b`: blk-0 / blk-31 bookends (`[RESIDUAL]`) | `0.0358 s` (`0.002`) | `1.6%` | `0.0371 s` (`0.003`) | `0.0469 s` (`0.004`) | `0.0495 s` (`0.015`) | `1.310x` |
| `P9`: Post-pass sealing-side tail (`seal_done - pass`) | `0.0130 s` (`0.001`) | — | `0.0130 s` (`0.002`) | `0.0300 s` (`0.021`) | `0.0415 s` (`0.053`) | `2.308x` |
| **Host vs GPU Summary Inside `seal_pass_s`:** | | | | | | |
| `wprod` 4-group wall (`P1 + P3 + P5 + P7`) | `0.6309 s` (`0.045`) | `28.5%` | `0.5909 s` (`0.078`) | `1.1683 s` (`0.088`) | `1.0369 s` (`0.144`) | `1.852x` |
| ↳ **`wprod` GPU hardware busy (`gpu_start..end` union)** | **`0.3698 s`** (`0.005`) | **`16.7%`** | **`0.3662 s`** (`0.039`) | **`0.4378 s`** (`0.030`) | **`0.4008 s`** (`0.037`) | **`1.184x`** |
| ↳ **`wprod` commit-to-`GPUStartTime` wait (`c..gs` ex-busy)** | **`0.2489 s`** (`0.050`) | **`11.2%`** | **`0.2101 s`** (`0.038`) | **`0.7044 s`** (`0.097`) | **`0.6058 s`** (`0.136`) | **`2.830x`** (`3.353x` in-proc) |
| ↳ `wprod` encode + completion wake (+ overlapped RoPE) | `0.0164 s` (`0.001`) | `0.7%` | `0.0157 s` (`0.001`) | `0.0176 s` (`0.001`) | `0.0180 s` (`0.003`) | `1.073x` |
| **Intra-block host gaps (`P2 + P4 + P6`, `0` CBs)** | **`0.4024 s`** (`0.004`) | **`18.2%`** | **`0.4052 s`** (`0.002`) | **`0.5273 s`** (`0.038`) | **`0.5441 s`** (`0.026`) | **`1.310x`** |
| **Total time ex GPU busy & commit-to-start (`71–75%`)** | **`1.6171 s`** (`0.071`) | **`73.0%`** | **`1.5750 s`** (`0.045`) | **`2.2165 s`** (`0.158`) | **`2.2070 s`** (`0.052`) | **`1.371x`** |
| Concurrent prover GPU busy during `seal_pass` | `0.0000 s` (`0.0%`) | — | `0.0000 s` (`0.0%`) | `2.5883 s` (`78.7%`) | `2.1572 s` (`67.3%`) | — |

### 1C. Summary of the Solo `~2.15–2.22 s` (`2.174 s` Pooled, `n = 18`) Witness Pass (`H1`, `H2`, `H5`)

1. **`71–75%` (`1.617 s` median on `serve1`) has zero witness command buffers in flight:**
   - **`54.3%` (`1.202 s` on `serve1`, `1.156 s` on `serve4 req 0`; `31` flat inter-block gaps of `~36 ms` = `1.167 s` + `0.036 s` bookends)** is **`P8`** (the serial between-block chain: builder tail, `assign_with`, CS-3 lookup-miss scan, `padded_plane`, `hand`, next-block shape/weight checks, `norm_a`, and `QKV` preludes). Its internal split is **not measured** in Batch 7; pre-allocating/reusing witness planes is one hypothesis among several (alongside limb scatter `0.29 s` and quantisation fills `0.20 s` in A16, where zeroing was `0.05–0.10 s/pass`). *(Note on `sys` CPU [`H1`]: the stream log's `~13.0–13.7 s/req` `sys` CPU is process-wide `getrusage(RUSAGE_SELF)` across the entire `6.2 s` request including prover forks and receipt writers, flat across `serve1` [`13.0 s`], `serve4` [`13.2 s`], and `serve6` [`13.7 s`]; A16 measured `~4.0 s` `sys` CPU for a solo sealing pass alone.)*
   - **`18.2%` (`0.402 s`, `12.6 ms/block`)** is **`P2 + P4 + P6`** intra-block host gaps (`P2` `176.5 ms`, `P6` `164.3 ms`, `P4` `63.1 ms`, including `QKV` tail and `Wo/Wg/Wu/Wd` preludes).
2. **`28.5%` (`0.631 s`) is inside the `128` `wprod` groups (`4` per block × `32` blocks):** **`16.7%` (`0.370 s`)** actual GPU kernel execution (`0.504 s` summed spans compressed to `0.370 s` union busy) + **`11.2%` (`0.249 s`)** commit-to-`GPUStartTime` latency (cause not separated across submit path, GPU wake, and page-view residency) + **`0.7%` (`0.016 s`)** encode and completion wake.

---

## 2. Overlap Slowdown Decomposition (`2.215 s -> 3.354 s` vs `serve1` [`1.514x`]; `2.152 s -> 3.354 s` In-Proc [`1.558x`]; `2.174 s` Pooled [`1.543x`]) (`H3`, `H4`, `H10`)

Across all 18 overlapped `serve4` passes (`reqs 1..3`), a concurrent proof runs for `100%` of the sealing span (with the prover GPU busy `70–81%` of each span; by position, `req 1` median is `3.465 s`, `req 2` `3.353 s`, `req 3` `3.265 s`). On **means**, the `+1.1338 s` (`serve4` Ov vs `serve1` Solo) slowdown sums to **`100.0%`** (`40.5% / 41.5% / 11.6% / 6.2% / 0.2%`; against pooled solo `n = 18` [`2.177 s` mean], shares are `41.4% / 41.4% / 10.6% / 6.4% / 0.2%`); on **medians**, the five component deltas sum to **`96.1%`** (`+1.0939 s` of `+1.1385 s` due to non-additivity of medians):

| Component (`serve4 reqs 1..3`, `n = 18`, vs `serve1` Solo, `n = 6`) | Solo Med (`s`) | Ov Med (`s`) | `Δ` Med (`%` of `+1.1385s`) | `Δ` Mean (`%` of `+1.1338s`) | Supported Observation (`[MEASURED]` / `[CODE-READ]`) |
| :--- | :---: | :---: | :---: | :---: | :--- |
| **1. Commit-to-`GPUStartTime` Wait (`queue 99`)** | `0.2489` | `0.7044` | **`+0.4555 s` (`40.0%`)** | **`+0.4595 s` (`40.5%`)** | `224` witness CBs on `queue 99` waiting beside `6` prover fork threads submitting to shared `queue 0`; **`87–97%`** of overlapped wait occurs while prover CBs execute on GPU |
| **2. Between-Block & Bookend Host (`P8`)** | `1.2020` | `1.6463` | **`+0.4443 s` (`39.0%`)** | **`+0.4705 s` (`41.5%`)** | Host contention (`cause not separated`, `1.37x`); gaps are **longer when prover GPU is idle** (`62 ms` at `<50%` busy vs `47 ms` at `>50%`, `r = -0.59` `serve4`, `-0.36` `serve6`), coinciding with prover host phases (commit/Merkle, folds, host rounds) |
| **3. Intra-Block Host Gaps (`P2 + P4 + P6`)** | `0.4024` | `0.5273` | **`+0.1249 s` (`11.0%`)** | **`+0.1316 s` (`11.6%`)** | Host contention (`1.31x`, similar factor to `P8`): `SealPool(8)` competing with `6` fork threads + global Rayon pool on `32` M3 Ultra cores |
| **4. `wprod` GPU Kernel Busy (`gs..ge` union)** | `0.3698` | `0.4378` | **`+0.0680 s` (`6.0%`)** | **`+0.0698 s` (`6.2%`)** | GPU SM / memory sharing while `wprod` kernels co-execute with prover GPU kernels (`1.18x`) |
| **5. `wprod` Encode + Wakeup (+ RoPE in `P1`)** | `0.0164` | `0.0176` | **`+0.0012 s` (`0.1%`)** | **`+0.0024 s` (`0.2%`)** | `begin -> committed` encode + `gpu_end -> done` wakeup |
| **Sum of Components** | — | — | **`+1.0939 s` (`96.1%`)** | **`+1.1338 s` (`100.0%`)** | Host parts (`#2 + #3`) = `+0.569 s` med (`50%`); GPU parts (`#1 + #4`) = `+0.524 s` med (`46%`) |

**Upper-Bound Reading for Research Queue Item 5 (`H3`):**
- Moving intra-block forward gaps (`P2 + P4 + P6 = 0.402 s` solo / `0.527 s` overlapped) onto the GPU touches **at most `16–18%`** of sealing.
- As a theoretical **upper bound** (NOT an achievable target), if both `P8` and `queue 99` commit-to-start wait vanished completely, solo sealing would drop by `54%` (`1.20 s`) and the overlap slowdown by `79–82%` (`+0.90–0.98 s`). In practice, **`87–97%` of the overlapped `queue 99` wait is spent behind actively executing prover GPU work**, the `4` per-block barriers are true data dependencies (though merging e.g. `Q, K, V` into fewer CBs could trim part of the `0.25 s` solo submit latency), and `P8` contains real witness/check work whose internal breakdown requires direct sub-phase profiling (Claude's Batch 8: solo `sample` call-graph split + `HL_GPU_WITNESS_VIEW=0`).

---

## 3. Three-Lane Server Stream (`serve6+lanes3` vs `serve4` `lanes=2`, `n = 6` Warm Passes) (`H7`, `H8`, `H14`)

| Stream Metric (`n = 6` warm passes, `L = 32`, `HL_A19_BUDGET_GIB=32` per req) | `serve1` (`1` req, `lanes=2`) Med (IQR) | `serve4` (`4` reqs, `lanes=2`) Med (IQR) | `serve6+lanes3` (`6` reqs, `lanes=3`) Med (IQR) | `lanes=3` vs `lanes=2` (Like-for-Like) |
| :--- | :---: | :---: | :---: | :---: |
| Pass wall (`s`) | `6.1880 s` (`0.035`) | `17.4465 s` (`0.181`) | `25.2055 s` (`0.187`) | — |
| Amortized per-request wall (`s/req`) | `6.1880 s` (`0.035`) | `4.3616 s` (`0.045`) | `4.2009 s` (`0.031`) | `1.038x` (longer stream amortizes `req 0`) |
| **Steady cadence `reqs 1..R-1` (`s/req`)** | — | **`3.6678 s`** (`0.061`, `3.632..3.724`) | **`3.7394 s`** (`0.038`, `3.708..3.782`) | **`0.981x`** (`+0.072 s` [`+1.9%`], overlapping ranges) |
| **Steady throughput `reqs 1..R-1` (`tok/s`)** | `20.69` amort | **`34.90 tok/s`** (`0.57`) | **`34.23 tok/s`** (`0.34`) | **`0.981x`** |
| **Post-lane-fill cadence `q >= lanes` (`s/req` / `tok/s`)** | — | **`3.6170 s` / `35.39 tok/s`** (`0.028`) | **`3.6760 s` / `34.82 tok/s`** (`0.035`) | **`0.984x`** (`+0.059 s` [`+1.6%`], like-for-like) |
| **Lane admission wait `seal_turn(q) - seal_done(q-1)` (`q >= lanes`)** | — | **`0.5960 s`** (`0.336`, `n=12`) | **`0.0000 s`** (`0.000`, `n=18`) | **Eliminated (`0.596 s -> 0.000 s`)** |
| **Prover slack `prover_start - seal_done` (`q >= 1`)** | — | **`0.1790 s`** (`0.327`) | **`1.6500 s`** (`1.316`) | By pos: `0.53, 1.11, 1.65, 2.35, 2.69 s` |
| Prover stall waiting for seal (`q >= 1`) | — | `0.0000 s` (`0.000`) | `0.0000 s` (`0.000`) | `0.000 s` in both |
| Contended mid-stream `forks` wall (`s`) | `3.384 s` (solo) | `3.4535 s` (`0.101`) | `3.5205 s` (`0.199`) | `+0.067 s` under back-to-back sealing |
| Uncontended final-request `forks` wall (`s`) | `3.384 s` (solo) | `3.2105 s` (`0.069`) | `3.2300 s` (`0.079`) | Comparable when no next req seals |
| Steady GPU busy union (`s/req` / `%` of wall) | — | `2.6494 s` (`71.96%`) | `2.6823 s` (`71.22%`) | Comparable GPU work/req |
| **macOS peak `phys_footprint` (`GiB`)** | `42.40 GiB` (`0.35`) | **`45.35 GiB`** (`0.25`) | **`50.70 GiB`** (`0.45`) | **`+5.35 GiB` at peak** (`+2.95 GiB` from `1 -> 2` lanes) |
| Guard `peak_rss` (`GiB`) / `peak_vram` (`MiB`) | `29.34 GiB` / `22,965` | `32.39 GiB` / `23,151` | `38.16 GiB` / `22,508` | **`+5.77 GiB` RSS** / no VRAM growth |

### Supported Findings on Three Lanes (`[MEASURED]` vs `[MODEL]`)

1. **`[MEASURED]` A third lane gives no gain today (`0.981x` steady, `0.984x` like-for-like post-fill — about `2%` slower, at the `±2%` A/B noise floor):**
   - Per-pass steady cadences overlap (`lanes=2`: `3.632..3.724 s`; `lanes=3`: `3.708..3.782 s`), and note that `serve4` (`3` intervals: `1` uncontended at `req 3`) and `serve6+lanes3` (`5` intervals: `2` uncontended at `reqs 4..5` after sealing finishes early) average different mixes of contended and uncontended prove calls (`mid-stream` intervals are `3.88, 3.84, 3.93 s` on `lanes=3` vs `3.77, 3.70 s` contended + `3.54 s` uncontended on `lanes=2`).
   - With `2` lanes, `P_ov` (`~3.70 s`) and `(S_ov + W + P_ov) / 2` (`~3.64 s`) are nearly balanced (`prover stall = 0.000 s`, `slack = 0.179 s`), so eliminating the `0.596 s` lane-admission pause on `lanes=3` simply queues up to `2` sealed requests (`2.69 s` slack) while keeping sealing overlapped continuously during `reqs 1..3`.
   - **Memory finding (`[MEASURED]` + `[CODE-READ]`):** Peak footprint rises by **`+2.95 GiB`** (`42.40 -> 45.35 GiB`) for the 2nd lane and **`+5.35 GiB`** (`45.35 -> 50.70 GiB`, `+5.77 GiB` RSS, no VRAM increase) at peak with the 3rd lane, because queued lanes hold witness planes / A-side parts rather than the `43.2 GB` NTT codewords built inside the single active `prove_call`. Thus Candidate A's codeword halving (`43.2 -> 21.5 GB`) does not buy a 3rd lane (`lanes=3` already fits in `50.7 GiB` on `256 GiB` RAM, and buys no throughput today).
2. **`[MODEL]` Pipeline Ceiling Under a Faster Future Prover (`H8`):**
   - Under the simplified pipeline model `cadence ≈ max(P', (S + W + P') / L_lanes)`, once `P'` drops below `S + W` (`~3.52–3.59 s`), `lanes = 3` keeps `(S + W + P') / 3` below `S`, so the `Turn`-serialized sealing side `S` (`seal_side_total_s = 3.296 s` median on `serve6+lanes3`, `3.367 s` on `serve4`) becomes the binding term instead of the 2-lane `(S + W + P') / 2` half-slope.
   - However, **`S` is not a fixed constant (`G2`, `H8`)**: as `P'` shortens, the prover overlaps a smaller fraction of each sealing turn, so `S` will fall from `~3.30–3.37 s` toward the solo `~2.17–2.23 s` floor. At constant `S = 3.296 s`, a faster prover alone could gain at most `3.668 / 3.296 = 1.113x` (`1.135x` if compared against `3.231 s`), whereas reaching `50 tok/s` (`2.56 s/req`) requires accelerating **both** the proof and the sealing side.

---

## 4. Per-Slot GPU Kernel Spans from Retained `serve1` Trace (`192` Solo Blocks, Summed Over 6 Forks) (`H13`)

From `serve1_6warm.15048.tsv.gz` (`6` warm passes × `32` solo blocks = `192` blocks, `HL_METAL_TIMING=0`), table below reports the per-slot GPU execution spans (`gpu_end - gpu_start`, in `ms/block`) **summed across the 6 concurrent fork threads** on shared `queue 0` (note: because up to 6 forks submit concurrently, `sum / union` reaches up to `~2.3x` on the large slots, so these figures measure **per-slot GPU work distribution**, not wall-clock duration; slots `13` and `20` appear in `5/6` and `3/6` passes respectively):

| Slot Index & Label (`W16R2_8B_T128_H24`) | Vars / Tables | Median (`ms/blk` summed) | IQR (`ms/blk`) | Mean (`ms/blk` summed) |
| :--- | :---: | :---: | :---: | :---: |
| `slot 18`: `14 F zero-check (hosts 13G, 13U)` | `21`v / `19`t (`11` base) | **`44.535`** | `3.367` | `45.523` |
| `slot 14`: `03 D zero-check (hosts 12, 13D)` | `19`v / `36`t (`23` base) | **`30.324`** | `2.321` | `30.286` |
| `slot 17`: `06 softmax zero-check (hosts 07, 10)` | `19`v / `19`t (`11` base) | **`18.333`** | `1.335` | `18.173` |
| `slot 15`: `04 Q zero-check (hosts 09Q, 11)` | `19`v / `15`t (`9` base) | **`10.288`** | `0.300` | `10.588` |
| `slot 19`: `TAB table helper zero-check` | `14`v / `58`t (`25` base) | **`6.975`** | `1.061` | `6.781` |
| `slot 0`: `01 SS row sums norm_a` | `19`v / `2`t (`1` base) | **`6.910`** | `1.162` | `6.767` |
| `slot 16`: `05 KV zero-check (hosts 09K, 09V)` | `17`v / `15`t (`9` base) | **`5.614`** | `0.904` | `5.818` |
| `slot 1`: `01m SS row sums norm_m` | `19`v / `2`t (`1` base) | **`4.066`** | `1.197` | `4.190` |
| `slot 4`: `07 masked row sums + selector` | `19`v / `4`t (`3` base) | **`2.435`** | `0.663` | `2.717` |
| `slot 3`: `08 limb zero-check` | `14`v / `5`t (`3` base) | **`2.029`** | `0.737` | `2.137` |
| `slot 21`: `IO-in endpoint equality` | `19`v / `3`t (`2` base) | **`1.796`** | `0.230` | `1.715` |
| `slot 22`: `IO-out endpoint equality` | `19`v / `3`t (`2` base) | **`1.247`** | `0.114` | `1.330` |
| `slot 13`: `13D down matmul (private)` (`5/6` passes) | `14`v / `2`t (`0` base) | **`0.077`** | `0.134` | `0.100` |
| `slot 20`: `ZS zero-sum row` (`3/6` passes) | `14`v / `2`t (`1` base) | **`0.017`** | `0.008` | `0.018` |
| **Sum of all 14 GPU-active slots (summed over 6 forks)** | — | **`134.646`** | — | **`136.143`** |

---

## 5. Reproduction & Artifact Manifest (`9` Repository Files + `3` External `.tsv.gz` Traces)

- Runner & analyzer: `results/zk60_batch7_sealing_lanes3_20261117/run_batch7_guarded.py`
- Structured JSON metrics: `results/zk60_batch7_sealing_lanes3_20261117/BATCH7_SEALING_AND_LANES3_METRICS.json`
- Guard receipts: `agy-batch7-serve1-6warm.guard.json` (`061723c7aeb6`), `agy-batch7-serve4-lanes2-6warm.guard.json` (`48fd544d9472`), `agy-batch7-serve6-lanes3-6warm.guard.json` (`604ae9fa4f37`)
- Raw stdout logs: `batch7_serve1_6warm.log`, `batch7_serve4_lanes2_6warm.log`, `batch7_serve6_lanes3_6warm.log`
- External compressed GPU traces: `/Users/victorrielly/zk60-artifacts/batch7_traces_20261117/{serve1_6warm.15048.tsv.gz, serve4_lanes2_6warm.15818.tsv.gz, serve6_lanes3_6warm.16734.tsv.gz}`
