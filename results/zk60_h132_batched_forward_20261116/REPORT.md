# Batch 5 & Batch 6 (`HEAD` `n >= 5` Profile, Corrected per `BATCH5_REVIEW.md` & `BATCH6_REVIEW.md`): `D80a`, `H127`, `H128`, `H132`, Candidate A Gross vs Net Ceiling, Candidate B W-Plane Census, and Candidate E

- **Date:** `2026-11-17`
- **Device:** Apple M3 Ultra (`80` GPU cores, `256 GiB` unified memory; `pgrep ds4-bench` quiet verified pre/post on all GPU timing leaves)
- **Repository State:**
  - **Batch 5 (`M1`, `H132`, `Cand. B`):** `perf/zk-batch-optimizations` @ `4a24243c` (`ops/zkp-mvp/gpu-metal/hashline/` untouched; standalone `metal_batched_llama8b.mm`; build command: `clang++ -O3 -fno-fast-math -std=c++17 -fobjc-arc -shared metal_batched_llama8b.mm -framework Foundation -framework Metal -framework MetalPerformanceShaders -o libmetal_batched_llama8b.dylib`; `.dylib` and `__pycache__` excluded from git).
  - **Batch 6 (`HEAD` 1-block `n = 7` + 6-fork stream `n = 6` + `HL_A27_GPU_TRACE`):** `perf/zk-batch-optimizations` @ `2df5f72d`, freshly compiled `hashline` lib test binary (`size = 22,951,056 B`, `sha256 = aaaab7e6fd38af59d406f201f94cfdb0325a3fe6adb3a04332873580f3acad11`, `HL_METAL_TIMING=0`).
  - **Note on `337 ms -> 268 ms` (`BATCH6_REVIEW.md` `G3`):** Batch 6 supersedes the single-pass Batch 5 M2 profile (`337 ms` `prove_core`, `414.1 ms` composite). Any attribution of the `69 ms` difference (`54 ms` of which sat in `A` and `H` commitments) to `A27/A28/A30` is **withdrawn**: Batch 5 M2 ran with diagnostic `HL_METAL_TIMING=1` (`run_batch5_guarded.py:296`), which re-runs commitment GPU phases on freshly allocated scratch buffers (`metal.rs:2147-2155`), `A30` touches no timed code, and cargo reused the test binary filename so no A/B against the `2026-11-06` binary is possible.
- **Guarded Runs (Default `5.0 s` guard poll, `12 s` polite inter-leaf gap, `0` watchdog kills):**
  - Batch 5: `fabdef37e4bd` (`build`, `1s`), `a09f5097e4af` (`gpu`, `309.05s`, `peak_rss=18.31 GiB`), `20c1f225b1b9` (`gpu`, `38.77s`, `peak_rss=3.74 GiB`).
  - Batch 6: `75ef1a77331c` (`agy-batch6-head-build`, `build`, `170.84s`, `peak_rss=4.46 GiB`), `2667991f6da8` (`agy-batch6-head-1block`, `gpu`, `39.95s`, `peak_rss=3.82 GiB`), `ba52f58399f4` (`agy-batch6-head-stream`, `gpu`, `178.96s`, `peak_rss=31.92 GiB`).
- **Machine-Readable Metrics Receipts:** `H132_H128_H127_METRICS.json` (Batch 5) and `BATCH6_HEAD_PROFILE_METRICS.json` (Batch 6 `HEAD`). *(Caveat `G8`: `run_batch6_guarded.py` cleaned its temporary `.tsv` traces after computing the interval unions; Batch 7 retains compressed trace TSVs outside the repository.)*

---

## 1. Executive Verdicts (Corrected per `BATCH5_REVIEW.md` + `BATCH6_REVIEW.md`)

| Item | Gate / Question | `[MEASURED]` Result & `[ESTIMATE]` Ranges | Verdict |
|---|---|---|---|
| **`D80a (M1)` + `H128`** | Exact integer witness weight-product GEMMs (`7` projs, `T=128`) vs verbatim production `[A4]` `k_wprod_sg_2x4` (`n=32` alternating-order repeats, word-exact vs CPU `int64`) | **1. Requested Stage 2 kernel (`metal_int_gemm.mm` `32x64`) is SLOWER than `[A4]`:** `15.738 ms` vs `8.807 ms` GPU (`0.560x`), `20.233 ms` vs `13.475 ms` E2E (`0.666x`).<br>**2. New `64x64` (`k_wprod_fast_i8_2x4` + `k_wprod_fast_i16_2x4`, `FAST_WS=65`) like-for-like (`7` cmdbufs both sides, same NEON pack, `W16R2` `f_pad=16,384`):** **`1.400x` E2E** (`13.475 -> 9.625 ms`, `sk4`; `1.307x` `sk1`) and **`1.834x` GPU** (`8.807 -> 4.802 ms`; `1.835x` at `1`-cb both sides). On `BASE` (`f=14,336`): **`1.372x` E2E** (`12.315 -> 8.976 ms`).<br>**3. Full-range `int16` inputs (no `int8` route):** **`1.027x` E2E / `1.065x` GPU** (`sk1` `7`-cb, `13.494 -> 13.145 ms` E2E, `8.818 -> 8.282 ms` GPU) / **`1.275x` GPU** (`sk4` `1`-cb).<br>**4. Whole-block Amdahl worth:** **`1.011x–1.02x`** (`3.85 ms` saved out of `~343 ms` `HEAD` witness+prove). | **Stage 2 `32x64` FAILS (`0.56x–0.67x`); new `64x64` is `1.40x` like-for-like E2E on `7` projs (`1.011x–1.02x` on a block). `H128` original gate (RTX 5090 `<=9 ms`, `build_accuracy` digests, host witness remainder) NOT tested; `D80a` NOT unblocked.** |
| **Candidate E (Fold Half)** | `ZK60_NEXT_PROTOCOL_CANDIDATES.md` §6: exact-integer 64-bit limb fold vs production fold | **No exact-integer 64-bit limb fold kernel exists in the repository** (`microbench_metal_gpu.mm` `T1` was an inexact 24-bit FP32 mock already withdrawn, and `metal_int_gemm.mm` / `metal_batched_llama8b.mm` implement exact GEMMs only). Note (`G4`): by default (`HL_METAL_DEVICE_FOLD` unset) the production opening fold runs **on the host** at **`~11.2 ms/block`** (`5.3 ms` `A` + `5.9 ms` `H`, `~4%` of `prove_core`); the `0.094 + 0.081 = 0.175 ms` GPU figure in `open A / open H` is the `gather` buffers only. | **Candidate E's fold half is DROPPED for lack of an exact-integer fold kernel (experiment not run; host fold target is `~11 ms/block`).** |
| **Batch 6 (`HEAD` Profile & Cand. A)** | `HEAD` (`2df5f72d`) test binary, `n = 7` warm 1-block passes & `n = 6` warm 6-fork stream passes (`HL_A27_GPU_TRACE`), Candidate A **gross vs net** (`G1, G2, G5, G6, G7`) | • **1-Block `[MEASURED]` (`n=7` medians, `W16R2_8B_T128_H24`):** `prove_core` = **`268.0 ms`** (`IQR 11.0`; last 5 settled passes median `266.0 ms`, `IQR 2.0`); CB **`GPU busy` = `93.48 ms` (`35.12%` median of ratios; `34.88%` ratio of medians)**; Host between CBs = **`172.97 ms`**.<br>• **Cand. A 1-Block Gross Removal (Variant `G3`, before A's own cost):** `[MEASURED]` non-slot `H` phases = **`52.0 ms` (`19.4%` -> `1.24x` gross; variant `G1` is `~36 ms`, `1.15x`)**. Adding `[ESTIMATE]` helper-relation share inside domain zero-check slots `14..18` (`8–16.5 ms` by table count / round floor) and `TAB` slot `19` (`0–8 ms`) gives **`1.29x–1.41x` gross 1-block ceiling** (`1.25x` middle on `342.8 ms` witness+prove).<br>• **6-Fork Stream `[MEASURED]` (`serve4`, `2` lanes, `n=6` medians):** Steady cadence = **`3.606 s/req` (`35.50 tok/s`)**; steady CB **`GPU busy` = `2.663 s/req` (`73.68%`)**; solo `sealing pass` = **`2.172 s` (`35.6%`)**, **overlapped** `sealing pass` (`reqs 1..3`, `n=18`) = **`3.321 s` (`1.53x` slower beside prover; `3.054 s` was 4-req mean incl. unoverlapped `req 0` `2.143 s`)**; pipeline slack median = **`0.137 s`**.<br>• **Cand. A Stream Gross Ceiling (`2` lanes, `max(P, (S+W+P)/2)`, `13%–22%` forks conversion):** **`1.09x–1.19x` (`1.12x` overlap model)** on measured `52 ms` `G3` list; **`1.13x–1.27x` (`1.18x` overlap model)** with estimated helper-slot share.<br>• **Cand. A Added Cost (`[ESTIMATE]`, `2026-11-01` projection):** Metal GKR tree rounds **`40–105 ms/block`**, leaf-claim terms **`~9 ms`**, `+48..+144` `M` rows — **same size as the `52–77.5 ms` removed (`~0.8x–1.1x` net 1-block)**. | **Gross 1-block (`G3`): `1.24x` measured (`1.29x–1.41x` w/ slot `[ESTIMATE]`); Gross 2-lane stream (`G3`): `1.09x–1.19x` (`1.13x–1.27x` w/ slot `[ESTIMATE]`). Net of A's own GKR cost (`40–105 ms` + `9 ms`), gain is inside uncertainty (`~0.8x–1.1x`); Cand. A prototype NOT ordered on speed grounds.** |
| **`H132`** | Batched `K=1,2,4,8` 32-layer forward; kill gate `K=4 / K=1 <= 0.80x` | On the deployable `K=1` baseline (`fast_64x64_sk4`, `155.70 ms` last-tok / `163.12 ms` full-head): **`K=4` is `138.12 / 155.70 = 0.887x` (`sk4` `0.888x > 0.80x`)** and **`K=8` is `0.832x`** (full-head: `0.903x` at `K=4`, `0.854x` at `K=8`). *(Only handicapped `sk1/sk1` was `0.770x` because `sk1` under-occupies 80 cores at `K=1`.)* | **`H132` FAILS (`0.887x–0.888x > 0.80x` against deployable `sk4` `K=1`).** |
| **`H127`** | Request-independent challenge-dependent Bucket `(b)` share (`< 10%` cycle-2 gate) | Strict (`3` table helpers `1 ms` + `9` weight/table slots `8 ms`) = **`9.0 ms`** (`2.67%` of `337 ms` Batch 5 / **`3.36%` of `268 ms` `HEAD`**); all-23-slots `tables: build` = `24.0 ms` (`7.12%`). Reconciling with cycle-2's `~10%` figure: adding witness-dependent LogUp/exp/act helper inverses (`16–22 ms`) lifts the share to `~9.3%–12.8%` (`1 ms` timer resolution). | **Closed / small on request-independent buckets (`2.7%–7.1%`; `~9%–13%` only if witness-dependent inverses are included — not robust to bucket choice).** |
| **`D80` Cand. B W-Census** | Stage 2 `Llama-3-8B` per-plane `RMS` & `max |v|` across `19` model planes (`256` tokens, **2 synthetic fallback prompts**) | `6` of `8` `int16` planes exceed `RMS <= 450` (`u_up 1875.7`, `act_silu 1051.6`, `z_down 646.1`, `x2_out 640.9`, `x1_res 574.4`, `x_in 552.1`; `384 > 150` W-rows over cap); `ao_proj` (`RMS 132.1`, `max 705`) and `h_swiglu` (`RMS 39.7`, `max 7,778`) fit RMS statistically and split by range (`max |v| > 255`). | **Triggers `H151b` W-split (`384 > 150` rows); does NOT settle Candidate B** (fallback prompts; remainder/limb classes `C` & `M` not measured). |

---

## 2. Exactness Gates & Verification Scope Caveats

1. **56 Adversarial Checks (`[M, K, N] = [65, 2200, 70]`):** `4` boundary/random patterns (`int8` `-128 x -128` hitting the `2^23` per-512-term slab sum; `int16` `+32767`, `-32768`, random mix) x `2` `in_out` layouts x `7` routes = `56` checks, all `np.array_equal` (`max_abs_diff == 0`) against independent CPU `numpy` `int64` 256-column chunked matmul.
2. **Block Word Equality (`W16R2` `6,029,312` words & `BASE` `5,505,024` words):** Checked once pre-timing against float64-BLAS 1,024-column chunked CPU reference (`< 2^32 << 2^53`, exact) across routes `0..6` in 1-cb resident mode and Scope B E2E routes `(2,1), (0,1), (5,1), (6,1), (6,0)`. *(Caveat: Scope B E2E route `1` `fast_64x64_sk1` and 7-cb resident mode use the same verified kernel shader text but were not separately asserted in the pre-timing E2E list.)*
3. **32-Layer Forward Gates (`H132` harness):** Gate 1 checked prompt 0 (`128 x 4096` final `x` and `16,416,768` full-head logits) for modes `0, 1, 5` against Stage 2's Python `run_forward` (not `hashline`'s `build_accuracy`). Gate 2 checked `K=2,4,8` full-head outputs against `K` standalone `sk4` GPU runs. *(Caveat: the timed `last_token_only_head = True` gather-last + `M = K` head path was not separately asserted against CPU.)*
4. **Prover Byte-Identity (`Batch 6` `HEAD`):** All `8` Metal passes (`1` cold + `7` warm) of `W16R2_8B_T128_H24` matched CPU proof digest `90003b760eb7ad80a5b85136cc69510fc42d95cfa1997947e4a8d0c871dbdebe`, and pass `0` of both `serve1` and `serve4` verified every 818,728,672-byte receipt from disk via `verify_run_with_forks`.

---

## 3. `D80a (M1)` & `H128` Kernel Comparison (`n = 32` Alternating-Order Medians)

### Equal-Condition Reading (`BATCH5_REVIEW.md` §4 & `BATCH6_REVIEW.md` §8)
- **Production shader identity:** `k_wprod_sg_2x4`, `k_wprod_sg_4x2`, and `k_wprod_int` in `metal_batched_llama8b.mm` are character-identical to `WPROD_SRC` in `ops/zkp-mvp/gpu-metal/hashline/src/gpu/metal.rs:4258-4475`.
- **Structural differences between `[A4]` and `fast_64x64_sk4` (no unmeasured compiler/hardware mechanism claims):** Under like-for-like `7`-cb dispatch, `fast_64x64_sk4` (`1.400x` E2E, `1.834x` GPU) differs in three code choices: (a) routing `int8`-range activations (`6` of `7` Stage 2 projections; note the prover's layout types `Y, YM` as `int16`) to a single-limb `int8` kernel instead of checking `hi != 0` inside a 2-limb loop, (b) `SPLIT_K = 4` (`M = 128` gives only `2` M-tiles of `64` on an 80-core GPU), and (c) `FAST_WS = 65` shared-memory stride with `4`-tile (`128`-step) slab flushes. On **arbitrary full-range `int16` inputs** at equal `7`-cb `sk1` structure, the gain is **`1.027x` E2E (`1.065x` GPU)**.
- **Harness vs Rust `[A4]` gap (`F7`):** At the `BASE` `hidden = 14,336` shape, the standalone C++ harness's `7`-cb `[A4]` GPU median is **`7.914 ms`** (`12.315 ms` E2E), whereas Rust `witness_speed_tests.rs`'s `wprod_run` GPU mean across 30 blocks is **`10.27 ms`** (`+30%` on `BASE`, or `+17%` vs `W16R2`'s `8.807 ms`): Rust's `wprod_run` executes inside `build_accuracy` / `products` with per-call `shared_buffer` pool checkout, `par_chunks_mut` Rayon range-check/pack, and synchronous `wait_done` per projection, whereas the standalone C++ benchmark pre-allocates persistent Metal buffers in a tight C++ loop.
- **Mixed-condition ratios not quoted as headline speedups:** `1`-cmdbuf Scope B rows (`8.339 ms`, `7.681 ms` on `W16R2`; `7.515 ms`, `7.070 ms` on `BASE`) bundle a `7 -> 1` command-buffer dispatch change that `[A4]` could also adopt (`[A4]` 1-cb vs 7-cb saves `1.52 ms` in Scope A).

### Table 3A — `W16R2` `8B` Padded Block (`T = 128`, `f_pad = 16,384`, `7` Projections, `n = 32` Medians)

| Kernel / Route | CmdBufs | Scope A Pure GPU (`ms`, IQR) | Scope A CmdBuf Wall (`ms`, IQR) | Scope B Host-`i64` E2E (`ms`, IQR) | Scope B Pack / Encode (`ms`) | Equal-Condition Ratio vs `[A4]` |
|---|---:|---:|---:|---:|---:|---:|
| **Prod `[A4]` `k_wprod_sg_2x4` (`7`-cb baseline)** | `7` | `8.807` (`0.012`) | `10.579` (`0.211`) | `13.475` (`0.128`) | `0.728 / 0.103` | **`1.000x` (7-cb baseline)** |
| Prod `[A4]` `k_wprod_sg_2x4` (`1`-cb) | `1` | `8.781` (`0.020`) | `9.057` (`0.032`) | — | — | **`1.000x` (1-cb Scope A baseline)** |
| Prod `[A4]` `k_wprod_sg_4x2` (`1`-cb) | `1` | `8.942` (`0.026`) | `9.231` (`0.065`) | — | — | `0.982x` GPU / `0.981x` wall (vs 1-cb) |
| Prod `[A4]` `k_wprod_int` (`1`-cb) | `1` | `13.564` (`0.013`) | `13.839` (`0.048`) | — | — | `0.647x` GPU / `0.654x` wall (vs 1-cb) |
| **Stage 2 `exact_int_gemm_simd_32x64` (`7`-cb)** | `7` | `15.738` (`0.121`) | `17.588` (`0.255`) | `20.233` (`0.351`) | `0.751 / 0.103` | **`0.560x` GPU / `0.666x` E2E (SLOWER)** |
| **`fast_64x64_sk1` (`SPLIT_K=1`, `7`-cb, like-for-like)** | `7` | **`5.672`** (`0.009`) | **`7.347`** (`0.153`) | **`10.312`** (`0.413`) | `0.680 / 0.115` | **`1.553x` GPU / `1.307x` E2E** |
| **`fast_64x64_sk4` (`SPLIT_K=4`, `7`-cb, like-for-like)** | `7` | **`4.802`** (`0.010`) | **`6.519`** (`0.229`) | **`9.625`** (`0.299`) | `0.680 / 0.111` | **`1.834x` GPU / `1.400x` E2E** |
| `fast_64x64_sk1` (`SPLIT_K=1`, `1`-cb) | `1` | `5.659` (`0.015`) | `5.942` (`0.042`) | `8.339` (`0.151`) | `0.609 / 0.074` | `1.552x` GPU / `1.524x` wall (vs 1-cb `[A4]`); *Scope B mixes 1 vs 7 cb* |
| `fast_64x64_sk4` (`SPLIT_K=4`, `1`-cb) | `1` | `4.785` (`0.012`) | `5.062` (`0.070`) | `7.681` (`0.449`) | `0.613 / 0.070` | `1.835x` GPU / `1.789x` wall (vs 1-cb `[A4]`); *Scope B mixes 1 vs 7 cb* |
| `fast_64x64_sk1` (arbitrary `int16`, `7`-cb, like-for-like) | `7` | `8.282` (`0.145`) | — | `13.145` (`0.345`) | — | **`1.065x` GPU / `1.027x` E2E** (vs `int16` `[A4]` `8.818 ms` GPU / `13.494 ms` E2E) |
| `fast_64x64_sk4` (arbitrary `int16`, `1`-cb) | `1` | `6.885` (`0.022`) | `7.169` (`0.059`) | `10.060` (`0.126`) | — | **`1.275x` GPU** (vs 1-cb `[A4]`); *Scope B mixes 1 vs 7 cb* |

### Table 3B — `BASE` `8B` Unpadded Block (`T = 128`, `f = 14,336`, `n = 32` Medians)

| Kernel / Route | CmdBufs | Scope A Pure GPU (`ms`, IQR) | Scope A CmdBuf Wall (`ms`, IQR) | Scope B Host-`i64` E2E (`ms`, IQR) | Equal-Condition Ratio vs `[A4]` (`7`-cb) |
|---|---:|---:|---:|---:|---:|
| **Prod `[A4]` `k_wprod_sg_2x4` (`7`-cb baseline)** | `7` | `7.914` (`0.014`) | `9.685` (`0.277`) | `12.315` (`0.242`) | **`1.000x`** |
| Stage 2 `exact_int_gemm_simd_32x64` (`7`-cb) | `7` | `13.766` (`0.109`) | `15.592` (`0.613`) | `17.860` (`0.357`) | `0.575x` GPU / `0.690x` E2E |
| **`fast_64x64_sk1` (`7`-cb, like-for-like)** | `7` | **`5.088`** (`0.039`) | **`8.774`** (`0.253`) | **`9.540`** (`0.251`) | **`1.556x` GPU / `1.291x` E2E** |
| **`fast_64x64_sk4` (`7`-cb, like-for-like)** | `7` | **`4.324`** (`0.009`) | **`6.006`** (`0.479`) | **`8.976`** (`0.512`) | **`1.830x` GPU / `1.372x` E2E** |
| `fast_64x64_sk1` (`1`-cb) | `1` | `5.059` (`0.017`) | `5.320` (`0.080`) | `7.515` (`0.181`) | `1.561x` GPU (vs 1-cb `7.886 ms`); *Scope B mixes 1 vs 7 cb* |
| `fast_64x64_sk4` (`1`-cb) | `1` | `4.307` (`0.012`) | `4.587` (`0.047`) | `7.070` (`0.503`) | `1.831x` GPU (vs 1-cb `7.886 ms`); *Scope B mixes 1 vs 7 cb* |

*Rust `witness_speed_tests.rs` reference at the `BASE` `hidden = 14,336` shape (`batch6_1block_a4_30reps.log` on `HEAD` `2df5f72d`, `Simd2x4` mapped, random full-range `int16 x int8`):* whole witness best-of-30 = **`74.8 ms`**, seven products alone **best-of-30 = `14.3 ms`**; separate **mean** components across all calls = `pack 2.53 ms + weights 0.09 ms + encode 0.31 ms + cmdbuf 14.38 ms` (of which GPU mean = `10.27 ms`), summing to `17.31 ms` (do not mix best-of-30 `14.3 ms` with component means).

---

## 4. `H132` 32-Layer Resident Batched Forward (`FAIL` vs Deployable `sk4` `K = 1`)

Measured on Stage 2's 32-layer `Llama-3-8B` integer forward (`f = 14,336`, `T = 128`, `n = 8..16` per mode in sequential mode blocks; "tok/s" = forward-pass tokens/s, not proved tok/s; `float16` arm is an incomplete MPS GEMM-heavy lower bound omitting RoPE/softmax/mask/embedding gather and reusing 6 placeholder weight layers):

| Batch `K` (`M = 128K`) | Deployable `fast_64x64_sk4` Wall (`ms/req`) | `fast_64x64_sk1` Wall (`ms/req`) | Incomplete `MPS` `float16` Lower Bound (`ms/req`) | `sk4` over `float16` Ratio | **`K` over Deployable `K=1` (`sk4`) Ratio (`<= 0.80` gate)** | `sk1 / sk1` Ratio *(under-occupied `K=1`)* |
|---:|---:|---:|---:|---:|---:|---:|
| **`K = 1` (last-tok head)** | **`155.70`** (`154.64` GPU) | `179.35` (`178.69` GPU) | `109.59` (`103.47` GPU) | `1.421x` | `1.000x` | `1.000x` |
| **`K = 2` (last-tok head)** | **`144.83`** (`144.11` GPU) | `160.54` (`160.21` GPU) | `96.72` (`93.96` GPU) | `1.497x` | `0.930x` | `0.895x` |
| **`K = 4` (last-tok head)** | `138.29` (`137.96` GPU) | **`138.12`** (`137.88` GPU) | `85.21` (`83.72` GPU) | `1.623x` | **`0.887x` (`sk4` `0.888x` — FAIL)** | `0.770x` |
| **`K = 8` (last-tok head)** | `129.66` (`129.47` GPU) | **`129.51`** (`129.26` GPU) | `77.90` (`76.87` GPU) | `1.665x` | **`0.832x` (`sk4` `0.833x` — FAIL)** | `0.722x` |
| **`K = 1` (full 128-tok head)** | **`163.12`** (`158.54` GPU) | `185.30` (`182.69` GPU) | `117.73` (`112.08` GPU) | `1.386x` | `1.000x` | `1.000x` |
| **`K = 4` (full 128-tok head)** | `150.66` (`144.64` GPU) | **`147.24`** (`144.48` GPU) | `91.40` (`89.91` GPU) | `1.648x` | **`0.903x` (`sk4` `0.924x` — FAIL)** | `0.795x` |
| **`K = 8` (full 128-tok head)** | **`139.35`** (`136.31` GPU) | `139.76` (`136.21` GPU) | `83.89` (`82.47` GPU) | `1.661x` | **`0.854x` — FAIL** | `0.754x` |

**Verdict:** Because `SPLIT_K = 4` already occupies the 80-core M3 Ultra GPU at `K = 1` (`155.70 ms`), batching to `K = 4` saves only `11.3%` (`0.887x > 0.80x`) -> **`H132` FAILS**.

---

## 5. Batch 6 (`HEAD` `2df5f72d`): `n >= 5` Warm Per-Phase Profiles, Command-Buffer GPU Busy, Candidate A Gross vs Net Analysis, and Stream Witness Share

*Baseline note (`G3`): Batch 6 (`HL_METAL_TIMING=0`, `n = 7` warm 1-block passes, `n = 6` warm stream passes) supersedes Batch 5's `HL_METAL_TIMING=1` M2 log (`337 ms` `prove_core`; note also that in `m4_trained`, `477 - 337 = 140 ms` was `verify` + digest inside `seeded_accuracy_digest`, while `wit()` ran prior to `Instant::now()`). All GPU busy figures below are exact interval unions of Metal command-buffer `[GPUStartTime, GPUEndTime]` timestamps from `HL_A27_GPU_TRACE`. Note (`G9, G10`): 1-block `prove_core` warm passes were `[296, 285, 268, 267, 270, 259, 266] ms` (first two settling -> `IQR 11.0 ms`; last five median `266.0 ms`, `IQR 2.0 ms`); medians of separate series do not sum (`93.482 + 172.974 = 266.456 ms` vs `268.0 ms`), and `35.12%` is the median of per-pass GPU ratios (`93.482 / 268.0 = 34.88%`).*

### 5A. One Warm `W16R2_8B_T128_H24` Block on `HEAD` (`n = 7` Warm Passes, Medians & IQRs)

| Phase (`W16R2_8B_T128_H24`, `n = 7` Warm Passes) | Wall Median (`ms`, IQR) | CB GPU Busy (`ms`, IQR) | Host CPU (`ms`, IQR) | Candidate A Role (`G1, G5, G7`) |
|---|---:|---:|---:|---|
| `A`: row alloc + planes + lookup/exp/act histograms + masks | `28.0` (`1.5`) | `0.000` | `28.000` (`1.500`) | Kept (`A` keeps multiplicities) |
| `A`: `pcs::commit_zk_owned` (`2504 x 2^14 -> 2^15`) | `22.0` (`1.0`) | `13.376` (`0.341`) | `8.624` (`1.364`) | Kept |
| `M`: `zk::mask_commit` (`50` rows) | `5.0` (`1.0`) | `0.000` | `5.000` (`1.000`) | Kept *(grows by `+48..+144` rows in Cand. A)* |
| **`H`: LogUp helper inverses (`6` lookup domains)** | **`7.0` (`0.0`)** | **`0.000`** | **`7.000` (`0.000`)** | **Removed (`G1, G2, G3`)** |
| **`H`: `exp` + `act` helper inverses** | **`9.0` (`1.0`)** | **`0.000`** | **`9.000` (`1.000`)** | **Removed in `G2 / G3`** *(kept in `G1`)* |
| **`H`: the `3` table helpers** | **`1.0` (`0.0`)** | **`0.000`** | **`1.000` (`0.000`)** | **Removed (`G1, G2, G3`)** |
| **`H`: mask rows + zero-sum rows** | **`2.0` (`0.0`)** | **`0.000`** | **`2.000` (`0.000`)** | **Mask rows (`82`) removed in `G3`** *(zero-sum pair stays in `G2/G3`)* |
| `H`: release `4` witness buffers (`S2` drops) | `2.0` (`1.0`) | `0.000` | `2.000` (`1.000`) | Kept *(deallocation stays)* |
| **`H`: `pcs::commit_zk_owned` (`2606 x 2^14 -> 2^15`)** | **`23.0` (`3.0`)** | **`14.001` (`0.186`)** | **`9.147` (`2.767`)** | **Removed in `G3`** *(`~84%` = `2,192 / 2,606` rows in `G1`)* |
| `23` Masked Sumcheck Slots (`slots 00..22`) | `139.0` (`5.5`) | `65.900` (`0.765`) | `75.139` (`4.236`) | **Partly reduced (`[ESTIMATE]` `8–16.5 ms` in slots `14..18` [`74 ms` total] + `0–8 ms` in `TAB` slot `19` [`8 ms`]); A adds `40–105 ms` GKR + `~9 ms` leaf claims** |
| `open M` (`zk::mask_open`) | `3.0` (`0.0`) | `0.000` | `3.000` (`0.000`) | Kept |
| `open A` (`schedule audit + host fold + gather + Merkle`) | `15.0` (`0.0`) | `0.094` (`0.003`)* | `14.906` (`0.008`) | Kept *(\*GPU CB is `gather`; fold is host `~5.3 ms` by default)* |
| **`open H` (`schedule audit + host fold + gather + Merkle`)** | **`10.0` (`1.0`)** | **`0.081` (`0.006`)* ** | **`9.922` (`1.000`)** | **Removed in `G3`** *(\*GPU CB is `gather`; fold is host `~5.9 ms` by default)* |
| **Total `prove_core` (`LAST_CORE_NS` exact)** | **`268.0` (`11.0`)** | **`93.482` (`1.260`) [`35.12%`]** | **`172.974` (`12.210`) [`64.88%`]** | **Non-slot `G3` `[MEASURED]` = `52.0 ms` (`19.4%` -> `1.24x` gross); w/ slot `[ESTIMATE]` = `60–77.5 ms` (`1.29x–1.41x` gross)** |

#### Candidate A 1-Block Gross vs Net Summary (`BATCH6_REVIEW.md` §1)
1. **Gross Removal Readings (before Candidate A's own proving cost):**
   - **Variant `G3` non-slot `[MEASURED]`:** **`52.0 ms` (`IQR 3.5`, `19.4%` of `268.0 ms`)** -> **`1.24x` gross** on `prove_core` (`1.18x` on `342.8 ms` composite with `HEAD` `[A4]` witness `74.8 ms`). *(Variant `G1`, retiring range & table helpers only: `~36 ms` = `13%` -> **`1.15x` gross** before slot share.)*
   - **Plus Helper-Relation Share Inside Slots `14..19` (`[ESTIMATE]`):** Domain zero-check slots `14..18` (`D 18 ms, Q 9 ms, KV 5 ms, S 11 ms, F 32 ms` = `74 ms` total, `IQR 1.5`) carry `(10/37, 3/15, 3/15, 4/19, 4/19)` helper columns, giving **`8–10 ms` (after subtracting `~28–32 ms` round-latency floor)** to **`16.5 ms` (raw table-count proportion)**, plus **`0–8 ms`** for the table-helper part of `TAB` slot `19` (`8 ms` whole slot). Including these estimates raises `G3`'s **gross** 1-block ceiling to **`60–77.5 ms` (`22.4%–28.9%` -> `1.29x–1.41x` gross on `prove_core`, `1.25x` middle on `342.8 ms` witness+prove)**.
2. **Candidate A's Own Added Costs (`[ESTIMATE]`, `2026-11-01` Metal projection):**
   - **`~300` masked GKR rounds** over a `2^25`-leaf tree: **`40–105 ms/block`** on Metal (no GPU GKR kernel exists yet), plus **`~9 ms/block`** for leaf-claim terms in the five domain zero-checks and **`+48..+144` `M` mask rows**. Because **`49–114+ ms` added** is the **same size as the `52–77.5 ms` removed**, net 1-block change lands around **`~0.8x–1.1x`** (inside estimation uncertainty).

### 5B. Six-Fork Stream Request on `HEAD` (`W16R2_8B_T128_H24`, `L = 32`, `N = 6`, `n = 6` Warm Passes)

| Stream Metric (`n = 6` Warm Passes, Medians & IQRs) | Solo Request (`serve1`, `1` req/pass) | Pipelined Stream (`serve4`, `4` reqs/pass, `2` lanes) |
|---|---:|---:|
| **Steady-State Cadence per Request (`(done[3]-done[0])/3`)** | — | **`3.606 s` (`0.076`) = `35.50 tok/s` (`0.75`)** |
| Amortized Wall per Request (`pass_wall / R`) | **`6.093 s` (`0.101`) = `21.01 tok/s`** | `4.309 s` (`0.046`) = `29.71 tok/s` |
| Host `sealing pass` — **unoverlapped** (`serve1` / `serve4 req 0`) | **`2.172 s` (`0.030`) [`35.6%` of wall]** | `2.143 s` (`req 0` only, unoverlapped) |
| Host `sealing pass` — **overlapped** (`serve4 reqs 1..3`, `n = 18`) | — | **`3.321 s` (`0.145`) [`1.53x` slower beside prover; 4-req mean `3.054 s`]** |
| Pipeline slack (`prover_start - sealing_done`, `reqs 1..3`, `n = 18`) | — | **`0.137 s` median** (`0.055–0.182 s` on `reqs 2..3`; `0.000 s` prover stall on `18/18`) |
| Host `prove call` (`preflight + bnd commit + forks + join`) | **`3.628 s` (`0.052`)** | **`3.697 s` (`0.040`)** *(steady `reqs 1..3`: `3.626 s`)* |
| &nbsp;&nbsp;• `boundary commit` (`33` commitments) | `0.194 s` (`0.006`) | `0.230 s` (`0.005`) |
| &nbsp;&nbsp;• `forks` (`32` blocks across `6` workers) | `3.347 s` (`0.041`) | `3.386 s` (`0.039`) *(req 1–2 contended `3.409 s` vs req 3 uncontended `3.207 s`)* |
| &nbsp;&nbsp;• `join` (`33` boundary openings) | `0.079 s` (`0.001`) | `0.081 s` (`0.005`) |
| Host `receipt write` (`818.7 MB`, `16` writers) | `0.221 s` (`0.009`) | `0.226 s` (`0.007`) |
| **Command-Buffer `GPU busy` Union per Request** *(code-verified; trace TSVs not retained in Batch 6)* | **`2.885 s` (`0.026`) [`47.09%` of wall]** | **`2.663 s` (`0.005`) [`73.68%` of steady wall]** *(amortized: `2.776 s`, `64.36%`)* |
| Summed GPU Spans per Request (`mean ~2.45` concurrent CBs) | `7.026 s` (`0.162`) | `6.804 s` (`0.162`) |
| &nbsp;&nbsp;• `slots_sumcheck` (`batch/round/fold/tables`) | `4.295 s` (`61.1%` of spans) | `4.381 s` (`64.4%` of spans) |
| &nbsp;&nbsp;• `commit_A` (`32` blocks, `rows=2504`) | `1.289 s` (`18.3%`) | `1.079 s` (`15.9%`) |
| &nbsp;&nbsp;• **`commit_H` (`32` blocks, `rows=2606` — Cand. A removes)** | **`0.897 s` (`12.8%`)** | **`0.833 s` (`12.2%`)** |
| &nbsp;&nbsp;• `wprod_witness` (`224` CBs in sealing pass) | `0.493 s` (`7.0%`) | `0.489 s` (`7.2%`) |
| &nbsp;&nbsp;• `commit_boundary` (`33` CBs) | `0.016 s` (`0.2%`) | `0.016 s` (`0.2%`) |
| &nbsp;&nbsp;• `open_A` (`32` blocks, `gather` CBs; fold is on host) | `0.004 s` (`0.1%`) | `0.010 s` (`0.2%`) |
| &nbsp;&nbsp;• **`open_H` (`32` blocks, `gather` CBs; fold is on host — Cand. A removes)** | **`0.006 s` (`0.1%`)** | **`0.009 s` (`0.1%`)** |

#### Corrected 2-Lane Stream Cadence Analysis (`BATCH6_REVIEW.md` §5, `G2, G6, G7`)
1. **Two-lane admission chain (`max(P, (S + W + P) / 2)`):** With `lanes = 2`, request `q` enters sealing when request `q - 2` finishes writing its receipt (`12/12` checked pairs agree within `2 ms`), so steady cadence is governed by **`max(P, (S + W + P) / 2)`** (`S = 3.321 s` overlapped sealing, `W = 0.225 s` receipt write, `P = 3.626 s` steady prove call -> `max(3.626, 3.586) ≈ 3.606 s`, pipeline slack median **`0.137 s`**).
2. **Overlap coupling of `S`:** Overlapped sealing (`3.321 s`) runs **`1.53x` slower** than solo sealing (`2.172 s` in `serve1`, `2.143 s` on `serve4 req 0`), so shortening `P` also shortens the overlapped portion of `S`.
3. **Supported Gross Stream Ceiling on `2` Lanes (Variant `G3`, BEFORE Candidate A's own cost):**
   - Converting block share to `forks` wall (`13.3%` GPU-span share to `21.9%` solo host share; `19.3%` solo block wall share):
     - On the **measured `52 ms` `G3` list**: **`1.09x` (`S` unchanged) to `1.19x` (no sealing chain limit), `1.12x` under the `1.53x` overlap model**.
     - Including the **`[ESTIMATE]` helper-slot share (`25.6%–28.9%`)**: **`1.13x–1.27x` (`1.18x` overlap model; up to `1.33x` if whole `TAB` slot & no sealing chain limit)**.
   - *(Second channel to price in Batch 7: Candidate A cuts codewords per request from `43.2 GB` to `21.5 GB`, which could fund a 3rd admission lane `(S + W + P) / 3` inside a memory budget.)*

---

## 6. `D80` Candidate B — Stage 2 W-Plane `RMS` & `max |v|` Census (with Caveats)

*Caveats (`BATCH5_REVIEW.md` §7): `wiki.test.tokens` was absent on disk, so `bench_batch5_d80a.py` executed its **2 synthetic fallback prompts** (`256` tokens of hand-written paragraphs + reversed-character text); RMS is pooled per layer (not worst-token row) against a flat `450` (F-domain `k = 7,168` after splitting has cap `342`); and this measures Stage 2's `19` model intermediates (class `W`), NOT the prover's committed remainder/limb classes `C` (`480` rows) or `M` (`272` rows), nor `H153`/`H154`.*

| Plane | Model Type | Words Sampled | Global `RMS` | Worst-Layer `RMS` | `max |v|` | Exceeds Statistical `RMS` Cap (`450` / `342` on F)? | Needs `2`-Byte `(lo, hi)` Split? |
|---|---|---:|---:|---:|---:|---|---|
| `x_in` | `int16` | `33,554,432` | `395.97` | **`552.11`** | `8,871` | **Yes (`> 453`)** | **Yes (RMS + range)** |
| `y_a` | `int8` *(prover `Y`: `int16`)* | `33,554,432` | `5.63` | `6.32` | `33` | No | No *(by value)* |
| `q_pre_rope` | `int8` | `33,554,432` | `5.25` | `7.98` | `77` | No | No |
| `k_pre_rope` | `int8` | `8,388,608` | `6.39` | `10.02` | `70` | No | No |
| `qr` | `int8` | `33,554,432` | `5.26` | `7.99` | `77` | No | No |
| `kr` | `int8` | `8,388,608` | `6.39` | `10.02` | `70` | No | No |
| `v` | `int8` | `8,388,608` | `9.42` | `10.58` | `82` | No | No |
| `s_score` | `int8` | `33,554,432` | `14.45` | `24.43` | `105` | No | No |
| `p_prob` | `u12` (`[0,4096]`) | `33,554,432` | `32.96` | `40.85` | `512` | No (`max 512 > 255`) | *(2-byte range; already split in tick 6)* |
| `o_attn` | `int8` | `33,554,432` | `2.39` | `3.92` | `57` | No | No |
| `ao_proj` | `int16` | `33,554,432` | `37.88` | `132.07` | `705` | **No (`132.1 <= 453`)** | **Yes by range (`max 705 > 255`)** |
| `x1_res` | `int16` | `33,554,432` | `400.08` | **`574.42`** | `8,787` | **Yes (`> 453`)** | **Yes (RMS + range)** |
| `y_m` | `int8` *(prover `YM`: `int16`)* | `33,554,432` | `3.40` | `4.51` | `23` | No | No *(by value)* |
| `g_gate` | `int8` | `117,440,512` | `4.24` | `6.73` | `87` | No | No |
| `u_up` | `int16` | `117,440,512` | `1,041.36` | **`1,875.73`** | `23,576` | **Yes (`>> 342`)** | **Yes (RMS + range)** |
| `act_silu` | `int16` | `117,440,512` | `521.76` | **`1,051.57`** | `32,767` | **Yes (`>> 342`)** | **Yes (RMS + range)** |
| `h_swiglu` | `int16` | `117,440,512` | `23.86` | `39.66` | `7,778` | **No (`39.7 <= 342`)** | **Yes by range (`max 7,778 > 255`)** |
| `z_down` | `int16` | `33,554,432` | `144.56` | **`646.10`** | `11,165` | **Yes (`> 453`)** | **Yes (RMS + range)** |
| `x2_out` | `int16` | `33,554,432` | `411.86` | **`640.92`** | `8,871` | **Yes (`> 453`)** | **Yes (RMS + range)** |
