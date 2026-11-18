# Hardware GPU Sub-Phase Breakdown of Zero-Check Sumcheck Slots `18` & `14` + `HL_METAL_BATCH_TAIL_US=250` Stream A/B (`2026-11-17`)

Author: Antigravity (co-coordinator)  
Binary: unmodified `ops/zkp-mvp/gpu-metal/hashline/target/release/deps/hashline-a90b6cf7715dc2a7` (pre-A33 `a6eee4b0`; A33 modifies only CPU `seal_chain` and leaves Metal block proving untouched)  
Guard ledger: [`GUARD_RUNS.md`](./GUARD_RUNS.md) (`15` guarded runs, all `exit=0`, `ds4-bench: none / none`)  
Machine-readable artifacts: [`manifest.json`](./manifest.json), [`summary.json`](./summary.json), [`knob_probe.json`](./knob_probe.json), [`ab_serve4_tail250.json`](./ab_serve4_tail250.json)  
Externalized raw GPU trace archive: `/Users/victorrielly/zk60-artifacts/slot18_14_traces_20261117/*.tsv.gz`

---

## 1. Executive Summary (`[MEASURED]` + `[CODE-READ]`)

1. **Exact solo-block hardware GPU (`gpuEndTime - gpuStartTime`) budget (`[MEASURED]`, median of 5 warm passes):**
   - **`W16R2_8B_T128_H24` (`117.285 ms`/block GPU × 32 layers = `3.753 s`/req; digest `90003b76...` identical across all 6 runs):**
     - `all_slots_gpu_ms` (`12` device sumcheck slots, `M6` batched): **`63.302 ms`** (`54.0%`, `2.026 s`/req)
     - `commit_A + commit_H`: `13.987 + 13.900 =` **`27.887 ms`** (`23.8%`, `0.892 s`/req)
     - `other_diag_ms` (`store fold with pads` PCS opening fold of `A` & `H`): **`25.660 ms`** (`21.9%`, `0.821 s`/req)
     - `other_gather_ms`: **`0.185 ms`** (`0.2%`)
   - **`R13_SHIELD_T128_H24` (`248.899 ms`/block GPU × 26 layers = `6.471 s`/req; digest `5a6193d3...` identical across all 3 arms):**
     - `all_slots_gpu_ms`: **`97.784 ms`** (`39.3%`, `2.542 s`/req)
     - `commit_A + commit_H`: `39.481 + 36.718 =` **`76.199 ms`** (`30.6%`, `1.981 s`/req)
     - `other_diag_ms`: **`74.631 ms`** (`30.0%`, `1.940 s`/req)
2. **Exact sub-phase split inside Zero-Check Slots `18` (`14 F`) and `14` (`03 D`) (`[MEASURED]`, Arm A `HL_METAL_BATCH=1` vs Arm B `HL_METAL_BATCH=0, HL_METAL_DEVICE_TABLES=sync, HL_A27_LIN=1` vs Arm C `HL_A27_LIN=0`):**
   - **Slot 18 on `W16R2_8B` (`2^21` cube, `19` tables [`11` base], `m=3` materialized `xtabs`, `deg=5, de=4`):**
     - `Arm A` (`nd=17`): **`21.339 ms`** (`[21.335, 21.347]`, `0.683 s`/req = `33.7%` of all slot GPU).
     - `Arm B` (`nd=14`): **`18.557 ms`** useful GPU work = `TabBuild 1.701 ms` (`8.0%`, ~335 GB/s) + `Round 0 (k_sc_mat + k_sc_round0) 6.377 ms` (`29.9%`) + `Rounds 1..4 (k_sc_round + fold_tab) 9.020 ms` (`4.730 + 2.421 + 1.250 + 0.619 ms`, `42.3%`) + `Rounds 5..13 1.479 ms` (`6.9%`, hitting a `~135 µs`/round dispatch floor) + **M6 intra-batch gap `21.339 - 18.557 = +2.782 ms` (`13.0%`)**.
   - **Slot 14 on `W16R2_8B` (`2^19` cube, `36` tables [`23` base], `m=3`, `deg=4, de=4`):**
     - `Arm A` (`nd=15`): **`14.007 ms`** (`[13.925, 14.027]`, `0.448 s`/req = `22.1%` of all slot GPU).
     - `Arm B` (`nd=12`): **`11.517 ms`** useful GPU work = `TabBuild 0.995 ms` (`7.1%`) + `Round 0 3.546 ms` (`25.3%`) + `Rounds 1..4 5.345 ms` (`2.753 + 1.451 + 0.742 + 0.399 ms`, `38.2%`) + `Rounds 5..11 1.677 ms` (`12.0%`, `~240 µs`/round floor) + **M6 intra-batch gap `+2.490 ms` (`17.8%`)**.
   - **Across all 12 device slots on `W16R2_8B`:** `Arm B` sum = **`44.887 ms`** vs `Arm A` batched = **`63.302 ms`** -> **`+18.415 ms`/block (`29.1%` of slot GPU = `0.589 s`/32 blocks)** is M6 intra-batch serial barrier (`k_sc_part_reduce` + 1-TG `k_sc_fs_step` at `MTLSize(1,1,1)`) + trailing-round (`nd` extended by `+3` rounds to `half=16`) low-occupancy overhead!
   - **`HL_A27_LIN` (`Arm C - Arm B`) contribution (`[MEASURED]`):** saves **`3.988 ms`/block** on `W16R2_8B` Slot 18 (`22.545 -> 18.557 ms`) and **`1.602 ms`/block** on `W16R2_8B` Slot 14 (`13.119 -> 11.517 ms`); on `R13_SHIELD`, saves **`14.536 ms`/block** on Slot 18 (`46.216 -> 31.680 ms`) and **`27.267 ms`/block** on Slot 14 (`51.869 -> 24.602 ms`, `-52.6%`!).
3. **Critical systems discovery from pairing solo knob probe (`knob_probe.json`) with 2-lane `serve4` A/B (`ab_serve4_tail250.json`) (`[MEASURED]`):**
   - On a **solo block**, setting `HL_METAL_BATCH_TAIL_US=250` (vs default `25 µs`) cuts `nd` by 3 trailing rounds per slot (`17 -> 14` on Slot 18, `15 -> 12` on Slot 14), reducing `all_slots_gpu_ms` from **`63.302 -> 56.183 ms` (`-7.119 ms`/block = `-11.2%`)** and solo `prove_core` wall from **`0.327 -> 0.299 s` (`-8.6%`)** with identical digest `90003b76...`.
   - On **2-lane `serve4` (`ab_serve4_tail250.json`, 4 interleaved `A B A B` runs, 12 warm passes/arm, 20 receipts verified across the 4 leaves)**, `HL_METAL_BATCH_TAIL_US=250` cuts 2-lane GPU `forks` from `[3.542, 3.581] s` to `[3.490, 3.500] s` (`-52..-82 ms`) and `prove_call` by `-49..-51 ms` (`[3.829, 3.877] -> [3.780, 3.826] s`), **but increases overlapped CPU `seal_ov` from `[3.433, 3.565] s` to `[3.611, 3.613] s` (`+47..+180 ms`)**, leaving net `serve4` steady cadence flat (`Arm A` 12-pass median **`3.7455 s`** / `34.17 tok/s` vs `Arm B` **`3.7576 s`** / `34.06 tok/s`).
   - **Why (`[MEASURED]` + `[CODE-READ]`):**
     1. *2-lane GPU backfilling:* In `prove_two_lanes`, when Lane 0 enters a 1-threadgroup `k_sc_fs_step` or tiny trailing round (leaving 32–39 of the 40 Apple GPU cores idle), the hardware command processor schedules Lane 1's full-occupancy `commit_A/H`, `store fold`, or `j=0..3` sumcheck kernels onto those idle cores — already hiding ~70% of the solo M6 occupancy bubble (`-228 ms` solo GPU -> `-52..-82 ms` 2-lane `forks`).
     2. *CPU contention:* Offloading `~1,150` trailing rounds/request from GPU to CPU steals Rayon worker cycles from the concurrent `seal_chain` pass (`seal_ov` `+47..+180 ms`).
   - **Strategic takeaway for `D80` sumcheck work:**
     - **Do NOT change default `BATCH_TAIL_BUDGET_S` to `250 µs` for `serve4` streaming** (keep CPU offload at `25 µs`; if trailing rounds are optimized, fuse them **on the GPU** into a single persistent 1-TG kernel `H135b` so CPU cost stays `0`).
     - **Target `j=0..3` (`H133` + `H134`) where all 40 GPU cores are 100% saturated on DRAM bandwidth (`23.67 ms`/block in Slots 18+14 alone, `~36 ms`/block = `1.15 s`/req across all zero-check slots)!** Two-lane pipelining *cannot* hide DRAM bandwidth saturation — every byte of DRAM traffic saved in `j=0..3` translates **1-for-1** into `serve4` cadence reduction!

---

## 2. Solo-Block Category & Top-Slot Breakdown (`[MEASURED]`)

### 2.1 Category Split (`Arm A`, `HL_METAL_BATCH=1`, median of 5 warm passes)

| Category | `W16R2_8B_T128_H24` (ms/blk) | `%` | `× 32` blks (s/req) | `R13_SHIELD_T128_H24` (ms/blk) | `%` | `× 26` blks (s/req) |
|---|---:|---:|---:|---:|---:|---:|
| `all_slots_gpu_ms` (`12` device slots) | `63.302` | `54.0%` | `2.026` | `97.784` | `39.3%` | `2.542` |
| `commit_A_ms` | `13.987` | `11.9%` | `0.448` | `39.481` | `15.9%` | `1.027` |
| `commit_H_ms` | `13.900` | `11.9%` | `0.445` | `36.718` | `14.8%` | `0.955` |
| `other_diag_ms` (`store fold with pads`) | `25.660` | `21.9%` | `0.821` | `74.631` | `30.0%` | `1.940` |
| `other_gather_ms` | `0.185` | `0.2%` | `0.006` | `0.252` | `0.1%` | `0.007` |
| **`total_prove_gpu_ms`** | **`117.285`** | **`100%`** | **`3.753`** | **`248.899`** | **`100%`** | **`6.471`** |

### 2.2 Per-Slot Sub-Phase Breakdown on `W16R2_8B_T128_H24` (`[MEASURED]`, ms/block)

| Slot | Cube / `k` (`base`) / `m` / `deg(de)` | Arm A Batched (`nd`) | Arm B Unbatched Total (`nd`) | TabBuild (`sync`) | Round `j=0` (`mat+k0`) | Rounds `j=1..4` (`round+fold`) | Rounds `j=5..` (`round+fold`) | M6 Gap (`A - B`) | Arm C (`LIN=0`) |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| **Slot 18 (`14 F`)** | `2^21` / `19 (11)` / `3` / `5(4)` | **`21.339`** (`17`) | **`18.557`** (`14`) | `1.701` | `6.377` | `9.020` (`4.730+2.421+1.250+0.619`) | `1.479` (`9` rds) | **`+2.782`** | `22.545` |
| **Slot 14 (`03 D`)** | `2^19` / `36 (23)` / `3` / `4(4)` | **`14.007`** (`15`) | **`11.517`** (`12`) | `0.995` | `3.546` | `5.345` (`2.753+1.451+0.742+0.399`) | `1.677` (`7` rds) | **`+2.490`** | `13.119` |
| **Slot 17 (`06 smx`)** | `2^19` / `19 (11)` / `1` / `4(4)` | **`7.510`** (`14`) | **`5.523`** (`11`) | `0.485` | `1.468` | `2.708` (`1.415+0.692+0.371+0.230`) | `0.894` (`6` rds) | **`+1.987`** | `5.723` |
| **Slot 15 (`04 Q`)** | `2^19` / `15 (9)` / `0` / `4(4)` | **`5.535`** (`14`) | **`3.539`** (`11`) | `0.395` | `0.983` | `1.570` (`0.792+0.412+0.243+0.123`) | `0.619` (`6` rds) | **`+1.996`** | `3.756` |
| **Slot 19 (`TAB`)** | `2^14` / `58 (25)` / `18` / `3(3)` | **`3.900`** (`9`) | **`2.063`** (`6`) | `0.050` | `0.383` | `1.288` (`0.373+0.300+0.295+0.320`) | `0.325` (`1` rd) | **`+1.837`** | `2.398` |
| **Slot 16 (`05 KV`)** | `2^17` / `15 (9)` / `0` / `4(4)` | **`2.979`** (`12`) | **`1.285`** (`8`) | `0.098` | `0.302` | `0.581` (`0.249+0.122+0.110+0.100`) | `0.299` (`3` rds) | **`+1.694`** | `1.342` |
| *Other 6 device slots (`4,1,0,3,21,22`)* | — | `8.159` | `2.403` | `0.207` | `0.531` | — | — | **`+5.756`** | `2.554` |
| **All 12 Device Slots** | — | **`63.302`** | **`44.887`** | **`3.931`** | **`13.590`** | — | — | **`+18.415`** | **`51.437`** |

### 2.3 Per-Slot Sub-Phase Breakdown on `R13_SHIELD_T128_H24` (`[MEASURED]`, ms/block)

| Slot | Cube / `k` (`base`) / `m` / `deg(de)` | Arm A Batched (`nd`) | Arm B Unbatched Total (`nd`) | TabBuild (`sync`) | Round `j=0` (`mat+k0`) | Rounds `j=1..4` (`round+fold`) | Rounds `j=5..` (`round+fold`) | M6 Gap (`A - B`) | Arm C (`LIN=0`) |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| **Slot 18 (`14 F`)** | `2^21` / `29 (18)` / `4` / `5(4)` | **`34.754`** (`17`) | **`31.680`** (`14`) | `2.590` | `11.564` | `15.302` (`8.086+4.084+2.061+1.071`) | `2.300` (`9` rds) | `+3.074` | `46.216` |
| **Slot 14 (`03 D`)** | `2^19` / `64 (44)` / `4` / `5(4)` | **`27.950`** (`16`) | **`24.602`** (`13`) | `1.656` | `9.010` | `10.785` (`5.451+2.907+1.558+0.869`) | `3.175` (`8` rds) | `+3.348` | `51.869` |
| **Slot 17 (`06 smx`)** | `2^19` / `28 (16)` / `3` / `4(4)` | **`12.225`** (`15`) | **`10.049`** (`12`) | `0.706` | `2.823` | `5.024` (`2.597+1.351+0.712+0.364`) | `1.464` (`7` rds) | `+2.176` | `10.595` |
| **Slot 15 (`04 Q`)** | `2^19` / `27 (17)` / `1` / `4(4)` | **`9.334`** (`14`) | **`7.153`** (`11`) | `0.708` | `2.209` | `3.187` (`1.656+0.851+0.437+0.243`) | `1.042` (`6` rds) | `+2.181` | `8.138` |
| **Slot 16 (`05 KV`)** | `2^17` / `27 (17)` / `1` / `4(4)` | **`4.393`** (`12`) | **`2.570`** (`9`) | `0.167` | `0.631` | `1.078` (`0.464+0.255+0.186+0.173`) | `0.690` (`4` rds) | `+1.823` | `2.830` |

---

## 3. Runtime Knob Probe (`knob_probe.json`) & Interleaved `serve4` A/B (`ab_serve4_tail250.json`) (`[MEASURED]`)

### 3.1 Solo-Block Knob Probe on `W16R2_8B_T128_H24` (`5` warm passes, all digest `90003b76...`)

| Configuration | `metal_core` (s) | `dev_sc` (s) | `all_slots_gpu_ms` | `total_prove_gpu_ms` | Slot 18 (ms, `nd`) | Slot 14 (ms, `nd`) |
|---|---:|---:|---:|---:|---:|---:|
| Baseline (`BATCH_TAIL=25us`, `TG=128`, `TH=16`) | `0.327` | `0.072` | `63.302` | `117.285` | `21.339` (`17`) | `14.007` (`15`) |
| **`HL_METAL_BATCH_TAIL_US=250`** | **`0.299`** (`-8.6%`) | **`0.064`** (`-11.1%`) | **`56.183`** (`-11.2%`) | **`111.041`** (`-5.3%`) | `20.536` (`14`) | `12.968` (`12`) |
| `HL_METAL_BATCH_TAIL_US=500` | `0.312` | `0.065` | `54.914` | `110.014` | `20.443` (`13`) | `12.881` (`11`) |
| `HL_A27_ROUND_TG=256, HL_A27_MULTI_THRESH=18` | `0.322` | `0.071` | `63.279` | `117.133` | `20.968` (`17`) | `13.881` (`15`) |

### 3.2 Interleaved `A B A B` 2-Lane `serve4` Stream Test (`W16R2_8B_T128_H24`, `6` warm passes/run = `12` warm passes/arm)

| Leaf | Arm | Guard Run | Steady Cadence Median (s) | Steady `tok/s` Median | `prove_call` Median (s) | `forks` Median (s) | `seal_ov` Median (s) | `prover_wait` Median (s) | Verified Receipts (`818,728,672 B`) |
|---|---|---|---|---:|---:|---:|---:|---:|---:|
| `1A` | Default (`25 µs`) | `1e88204d23b8` | `3.7413` | `34.22` | `3.8290` | `3.5415` | `3.4330` | `0.1290` | `5` (`1` cold + `4` pass 0) |
| `2B` | `TAIL_US=250` | `5d310ce2a734` | `3.7455` | `34.17` | `3.7800` | `3.4900` | `3.6130` | `0.0680` | `5` (`1` cold + `4` pass 0) |
| `3A` | Default (`25 µs`) | `be70535655fa` | `3.8378` | `33.38` | `3.8765` | `3.5810` | `3.5645` | `0.1385` | `5` (`1` cold + `4` pass 0) |
| `4B` | `TAIL_US=250` | `abf5459bac88` | `3.7840` | `33.83` | `3.8260` | `3.4995` | `3.6110` | `0.0925` | `5` (`1` cold + `4` pass 0) |
| **Pooled `A` (`n=12`)** | Default (`25 µs`) | — | **`3.7455`** (IQR `3.7213–3.8217`) | **`34.17`** | — | — | — | — | `10` |
| **Pooled `B` (`n=12`)** | `TAIL_US=250` | — | **`3.7576`** (IQR `3.7330–3.8313`) | **`34.06`** | — | — | — | — | `10` |

---

## 4. Three Concrete Transcript-Preserving GPU Kernel Optimizations (`[CODE-READ]` + `[MODEL]`)

Because `ops/zkp-mvp/gpu-metal/**` is now confirmed unpinned on `perf` by both Astra and Sol, these three transcript-preserving kernel designs are ready to prioritize and prototype on top of `a6eee4b0`:

1. **`H133` — Shared-SRAM Single-Fetch Multi-Point `k_sc_round0` / `k_sc_round` + Fused `fold_tab` (`metal_slot.rs:447-466`, `metal.rs:4030-4055`):**
   - **Bottleneck (`[MEASURED]` + `[CODE-READ]`):** Rounds `j=0..3` consume **`14.778 ms`/block** in Slot 18 (`6.377 + 4.730 + 2.421 + 1.250`) and **`8.492 ms`/block** in Slot 14 (`3.546 + 2.753 + 1.451 + 0.742`) = **`23.270 ms`/block (`0.745 s`/req)** on `W16R2_8B` (`33.368 + 18.926 = 52.294 ms`/block = `1.360 s`/req on `R13_SHIELD`!), at 100% 40-core DRAM saturation. `[M4g]` (`HL_A27_MULTI=1`, `np = 5` at `j=0`, `np = 4` at `j>=1`) assigns separate SIMD groups to each evaluation point `d ∈ {0, 2, ..., de}` for the same pair `i`, causing the `608 MB` (`j=0` Slot 18) / `352 MB` (`j=1`) / `184 MB` (`j=0` Slot 14) table working set (exceeding Apple Silicon SLC!) to be fetched from DRAM **`4×–5×` per round**, plus another read+write pass in `fold_tab`.
   - **Design:** Have one 32-lane SIMD group cooperatively load `(lo_t, hi_t)` for all active tables into `threadgroup` SRAM once (`22 tables × 32 × 32 B = 22.5 KB < 32 KB` threadgroup limit; two table tiles for Slot 14's 36 tables) and loop `d` over SRAM without register pressure; for `j >= 1`, write the folded table out directly when `r_{j-1}` is applied on load (`fused fold-then-eval`, saving an additional `369 MB` write+read at `j=1` and `185 MB` at `j=2`!).
   - **Expected `serve4` impact (`[MODEL]`):** Because `j=0..3` is DRAM-bandwidth-saturated across all 40 cores (cannot be hidden by Lane 1), cutting `50–70%` of DRAM traffic in `j=0..3` across Slots `18, 14, 17, 15` projects **`-0.25 to -0.40 s`/req** directly off `serve4` steady cadence (`3.74 s -> ~3.35–3.50 s`).

2. **`H134` — Dead-Table `fold_tab` Elimination After `k_sc_mat` + Closed-Form `Tab::Eq` Terminal Eval (`metal_slot.rs:151-152`, `metal.rs:4041`):**
   - **Bottleneck (`[CODE-READ]`):** Base/ext tables consumed *exclusively* inside `Mat::Node` materialized `xtabs` are never read by `k_sc_round` in `j = 1..nd`, yet `fold_tab` still folds all `k` original tables every round solely to return `final_tables()` at the end of sumcheck!
   - **Design:** Partition tables into `live_in_body` vs `dead_after_mat`. Skip `fold_tab` on all `dead_after_mat` tables during `j = 1..nd`; at slot end, evaluate `Tab::Eq` dead tables in `O(n)` closed form on CPU (`0` DRAM bytes!) and remaining dead tables in a single read-only `dot(tab[0..2^nd], eq(r[0..nd]))` kernel (`0` intermediate DRAM writes!).
   - **Expected `serve4` impact (`[MODEL]`):** Pure DRAM read+write reduction in Slots `18, 14, 17, 19` -> **`-0.06 to -0.12 s`/req** directly on `serve4`.

3. **`H135b` — On-GPU Persistent Single-Threadgroup Tail Kernel `k_sc_tail_fused` (`half <= 512`, `0` CPU Offload):**
   - **Bottleneck (`[MEASURED]`):** Each slot's last `8–9` GPU rounds (`half = 512 -> 16`) execute `4` serial dispatches/round (`k_sc_round`, `k_sc_part_reduce`, `k_sc_fs_step`, `fold_indirect`) = `~32–36` kernel launches/slot (`~13,000` launches/req), paying `130–250 µs`/round in command-processor barrier overhead. Moving them to CPU (`TAIL_US=250`) hurts `seal_ov` (`+47..+180 ms`).
   - **Design:** Once `half <= 512` (where `22 tables × 1024 × 16 B ≈ 352 KB` fits entirely inside SLC, or `half <= 64` fits inside `32 KB` threadgroup SRAM!), run the remaining rounds inside **one** persistent single-threadgroup Metal kernel (`threadgroup_barrier` replaces `4 × 8 = 32` host encoder dispatches, `0` CPU threads touched!).
   - **Expected impact (`[MODEL]`):** **`-0.20 to -0.30 s`/req** on solo `serve1` latency and **`-0.05 to -0.10 s`/req** on 2-lane `serve4` (`0` `seal_ov` penalty!).
