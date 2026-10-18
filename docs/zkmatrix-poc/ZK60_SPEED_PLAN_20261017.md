# Costed speed plan: private Llama-3-8B stack at 50 proved positions/s (2026-10-17)

Written 2026-10-17 13:35 UTC by a Claude planning agent. This was read-only analysis: no build, no proof and no git.
The arithmetic is in `results/zk60_speed_plan_20261017/`:

- `layout.py` is a replica of the Rust counted layouts. It matches the Rust ladder exactly on every rung it was checked against.
- `cost_model.py` is the phase model and its validation.
- `projection.py` and `projection_output.txt` hold the 8B projections and the lever ladder.

Every Python run was one thread and took under 1 s.

## Task results (dated)

- **2026-10-17 23:08 UTC — task 2 (GPU F-slot zero-check) DONE: 11.7% of the
  4070 Laptop's 256 GB/s** (lean variant, table build included, isolated and
  in-stack warm agree) [MEASURED]; byte-identical rounds and seeded proof
  bytes at rung-TC, TinyLlama T32/T128 and 8B T32; 0 declines; a 22-block
  TinyLlama T128 stack with slot 18 on the device verifies fresh. **Decision
  rule: 10–25% band — kernel-design work before porting more slots.** Cause:
  every round kernel uses 255 registers and spills (8 of 48 warps per SM;
  latency-bound; the folds alone run at 57–67%). Next round K1–K4 (term-group
  split kernel, resident support table, fused reduction, tail kernel),
  estimated 33–42% [MODEL]. The laptop's in-stack 2.7% is its clock ramp after
  idle, which a GPU-resident prover avoids. Report:
  `results/zk60_gpu_zerocheck_20261017/REPORT.md`.
- **2026-10-18 02:26 UTC — task 2, kernel round 3 (exact arithmetic cuts +
  cross-process module cache):** slot-18 body 28.3–29.8 ms isolated (29.0 ms in
  the stack, warm) = **16.8–17.7% of 256 GB/s** [MEASURED], still byte-identical
  (1,080 synthetic bodies, 54 trained equalities, seeded proof bytes at four
  shapes, two fresh-verified 22-block stacks). In the stack, cold, the slot-18
  phase is 5.49 s vs 17.54 s on the CPU; the module cache removes a 3.6 s
  compile per process. Every number was taken with the laptop GPU capped at
  ~1.1 GHz (reason 0x20). At ~2.1 GHz sustained the compute-bound rounds would
  roughly halve: ~18 ms, ~28% [MODEL]. One more lever round (direct build from
  resident rows, flag polling, host tail) is estimated at ~22% at today's
  clock [MODEL]; then the lane pauses for the clock cap or the 5090.
- **2026-10-18 00:42 UTC — task 2, kernel round 2 (K1–K4):** the term-group
  split kernel removes every register spill (80 registers, 24 warps/SM) and
  stays byte-identical at all four shapes; slot-18 body 42.7 -> **34.7 ms =
  14.4% of 256 GB/s** isolated (13.8–14.2% in the stack, warm) [MEASURED].
  Still the 10–25% band. The large rounds are now integer-arithmetic-bound at
  the clock this laptop allows: the RTX 4070 Laptop is held at P4 (SM
  1,065 MHz of 3,105) with clock-limit reason "SW thermal slowdown" at
  60–65 °C and 37 W. Next: lift the laptop's power/thermal profile (Victor),
  exact arithmetic cuts (25–35% fewer instructions [MODEL]), a cross-process
  module cache. A 5090 desktop measurement must record its clock state.
- **2026-10-17 — task 1 (run hygiene) DONE:** 8B T32 stack 171.6 s total
  (targets met: digest 15.3 s, loads 16.0 s, total <= 180 s); identity and
  segment lengths unchanged (`results/zk60_1b_native_20261017/r5/`).
- **2026-10-17 — task 3 (8B T64/T128 phase ladder) DONE:** per block the model
  over-predicted by 22–23% on a quiet box (T128 8.15 s vs 10.60 s predicted;
  zero-checks −34%, commit +5%); T64 → T128 block wall x1.91 measured vs x1.94
  modelled; the softmax slot grows x1.74 vs x2.42 modelled — **the score
  domain grows slower than counted**, not faster (§7's worry). A refit
  calibrated on a full 8B T128 stack is owed before §5 is re-run
  (`results/zk60_1b_native_20261017/r5/refit/`). A first private 32-block
  Llama-3-8B stack at T128 proved in 487 s and verified fresh (T128 profile
  pending independent review).
- **Soundness target (D27):** about 95 bits whole-run at the 8B T512 workload
  is the MVP target; throughput is not traded for bits.

## In plain words (10 lines)

1. **Today.** The private 8B stack proves 32 positions in 384.5 s on the laptop, which is 0.083 positions/s. The block proofs alone take 110 s (0.29/s).
2. **The cost model.** A phase model fitted on today's TinyLlama T128 run reproduces the 8B T32 stack to within 3%. It reproduces every ladder rung to within 8% on CPU and 15% on the GPU arm.
3. **Today's code on a 5090.** It would give about 0.55 positions/s at T=512. Attention scores grow as T², so the cost per token doubles by about T≈930, and T≥2048 does not fit any of the three machines.
4. **The big lever.** Only moving the *whole* prover onto the GPU is worth more than 2×. At the GPU efficiency this project has actually measured, that reaches about 7–9 positions/s, and 10–11 with the layout reductions. That is not 50.
5. **When 50 is possible.** 50 is reachable on paper only if every GPU kernel runs at ≥ about 35% of the 5090's memory bandwidth, or ≥ about 23% with the causal-triangle and zkAttn layout changes. Today's measured GPU commitment kernel runs at about 13% of the laptop GPU's bandwidth.
6. **The decisive next measurement is cheap.** Port one zero-check (the FFN slot) to the laptop GPU and read its achieved bandwidth.
7. **Commitments.** The commitments alone cap a 5090 at 19–33 positions/s unless their kernel gets about 3× better. The LogUp helper commitment H is 55% of all committed data.
8. **If kernels stall below ~25%.** The design changes still left are:
   - zkAttn softmax (needs a ruling);
   - causal-triangle scores (needs a review);
   - LogUp-GKR in place of a committed H (needs a privacy design and a ruling);
   - a lower code rate (needs a security ruling).
9. **Startup.** Today each run spends about 160 s loading and hashing weights, plus 93 s on an in-process verify. That must fall to tens of seconds. Otherwise a total-workload rate of 50/s needs about 50,000 positions.
10. **First three tasks.** Run hygiene with byte counters; a GPU FFN-slot sumcheck with a bandwidth readout; an 8B T64/T128 phase table.

Labels:

- **[MEASURED]** means a run on the laptop: Core Ultra 9 185H, RAYON_NUM_THREADS=16, RTX 4070 Laptop 8 GB. The box is shared and every run is n=1.
- **[COUNTED]** means exact arithmetic on the layout or on measured numbers.
- **[MODEL]** means fitted, extrapolated or assumed; the basis is always stated.

Path shorthand: `N/` = `results/zk60_1b_native_20261017/`, `SP/` = `results/zk60_speed_plan_20261017/`.

---

## 1. What was measured (the anchors)

| Anchor | Number | Label, source |
|---|---|---|
| TinyLlama-1.1B, 22 blocks, proofs only per block (CPU / GPU arm) | T32 1.83 / 1.85 s; T64 2.95 / 2.89 s; T128 6.19 / 4.87 s | [MEASURED] `N/r3/LADDER.md` |
| TinyLlama, whole-run positions/s (CPU / GPU) | T32 0.57 / 0.53; T64 0.75 / 0.72; T128 0.76 / 0.90 | [MEASURED] `N/r3/LADDER.md` |
| TinyLlama witness per block | 0.122 / 0.231 / 0.583 s at T32 / 64 / 128 | [MEASURED] `N/r3/LADDER.md` |
| TinyLlama one-block peak RSS | 0.85 / 1.64 / 3.39 GiB at T32 / 64 / 128 | [MEASURED] `N/PROGRESS.md` R3-2 |
| T128 phase sums over 22 blocks, CPU, block walls 152.2 s | five zero-checks 69.0 s (D 27.5, F 17.6, S 11.5, Q 8.0, Kv 4.4); commits A + H 34.7 s; "A: allocate + witness planes" 17.7 s; LogUp U8 inverses 6.9 s; exp/act 1.4 s; openings 8.8 s | [MEASURED] `N/r4/PHASES_T128.md` |
| The same, GPU arm, block walls 134.8 s | zero-checks 68.5 s; commits 7.6 s; A-alloc 21.2 s; inverses 8.8 + 1.8 s; openings 12.2 s | [MEASURED] `N/r4/PHASES_T128.md` |
| Llama-3-8B, one generic block at T32 | prove 4.68 s; verify 1.34 s; 14,856,296 B; 1.95 GiB | [MEASURED] `N/PROGRESS.md` R4-2 |
| **Llama-3-8B, 32-block trained stack, T32, CPU** | total 384.5 s = digest pass 83.0 + witness 18.6 + block loads 79.2 + proofs 110.2 + in-process verify 93.4; receipt 465,815,776 B; fresh verify 96.1 s, of which 13.3 s is cryptography; peak 1.9 GiB | [MEASURED] `N/r4/TABLE.md`, `N/r4/stack-llama3_8b_pg_rot1_T32-ho00-cpu/` |
| The same stack, GPU arm | total 391.3 s; proofs 117.7 s; fresh verify 90.9 s; VRAM 2,369 MiB | [MEASURED] `N/r4/TABLE.md` |

**Correction to the phase reading.** The 12–16% phase "A: allocate + witness planes → committed rows" is mostly the witness:

- In `run.rs:710` the phase clock starts **before** the block's witness is built (`src.witness(k)`, `run.rs:733`). The first mark is at `protocol.rs:828`, so this phase also contains the witness and the boundary commit.
- Subtracting the measured witness (13.2 s CPU / 15.9 s GPU) leaves **0.20 s per block (2.9%) CPU and 0.24 s (3.9%) GPU** for the real conversion [COUNTED].
- The U8 inverses are already batched through a 256-entry inverse table and parallel (`protocol.rs:909-930`, stage 28).

So neither of those two levers is worth more than a few percent on the CPU (§4).

## 2. The per-token cost model

### 2.1 Work measures (exact, from the layout)

Every phase cost is driven by the sizes of the block's domains (`shape.rs:1564-1606`). Write t = T, d = 4096, f = 16384 (14336 padded), h = 32 query heads, hd = 128, kv = 8:

| Domain | Size | Committed planes per element (A + 2×H; Fp2 helpers count twice) | U8 lookups per element | Zero-check terms |
|---|---|---|---|---|
| D (t·d) | 4096 t | 35 + 34 = 69 | 34 | 54 (slot 14) |
| Q (t·h·hd) | 4096 t | 7 + 14 = 21 | 13 | 15 (slot 15) |
| Kv (t·kv·hd) | 1024 t | 6 + 12 = 18 | 12 | 13 (slot 16) |
| **S (h·t²), the attention scores** | **32 t²** | **13 + 18 = 31** at t ≥ 256 (3 softmax limbs) | **15** | **24** (slot 17) |
| F (t·f) | 16384 t | 11 + 12 = 23 | 9 | 17 (slot 18) |

Per token, per block [COUNTED]:

- committed elements ≈ 763,904 + 992·T;
- U8 lookups ≈ 352,256 + 480·T;
- zero-check element-terms ≈ 574,464 + 768·T.

These T-terms are the attention T². At T=512 the score domain is 40% of committed elements, and 57% at T1024.

`SP/layout.py` reproduces these exactly:

- the Rust counted ladder (`N/r3-ladder-count.log`): A/H rows, receipt bytes and U8 lookups for TinyLlama T32–T512;
- the five 8B counted receipts in `N/PROGRESS.md` R4-1.

### 2.2 The cost law

Per block, laptop, 16 threads [MODEL]. The calibration is per-block averages of the R4-4 T128 CPU phase run (`SP/cost_model.py`):

| Phase | Law | Coefficient |
|---|---|---|
| Commit A + H (encode + Merkle) | × committed elements | CPU 23.05 ns; keyed GPU commit on the 4070 Laptop 5.06 ns |
| Zero-check slot X (masked sumcheck body) | × size(X) × terms(X), plus a fixed 0.08 s per slot | D 63.8, Q 52.5, Kv 130, S 31.7, F 35.6 ns per element-term |
| Extension rounds | × terms × row width n | 299 ns per term-column (consistent to ±5% across the five slots) |
| LogUp inverses | × U8 lookups; × exp+act pairs | 10.8 ns; 40.2 ns |
| Openings A + H | × committed elements | 5.81 ns |
| Conversion (witness subtracted) | × A elements | 6.17 ns |
| Rest (row sums, matmul slots, IO, table, mask rows) | split by its own driver | 0.63 s at T128, of which weight folds are 0.41 s at 8B (constant in T) |
| Witness (CPU) | 17.7 ms·T + 15.5 µs·T² per 8B block | Fitted on TinyLlama, scaled by weights and by h·hd; reproduces 8B T32 at 0.581 vs 0.582 s measured |
| Fresh verify, cryptography | 1.46 ns × padded weights + 0.74 µs × score entries + 0.03 s | Fitted on TinyLlama T32/T128 and 8B T32; predicts T64 at −4% |
| GPU arm | CPU law with the commit at 5.06 ns, plus a fixed 0.305 s per block | 0.305 s is the mean residual over the four GPU points |

The resulting per-token law at 8B, laptop CPU:

- proof ≈ **58 ms + 62 µs·T per block-token**, plus 0.8 s per block of fixed work (slot overheads and weight folds);
- witness 17.7 ms + 15.5 µs·T.

Heads enter through S = h·T². Layers multiply everything by L = 32.

The T-linear part equals the constant part at T ≈ 930. Beyond that, dense attention makes each extra token dearer.

### 2.3 Fit error (proofs only, per block)

| Shape | CPU model / measured | Error | GPU-arm model / measured | Error |
|---|---|---|---|---|
| TinyLlama T32 | 1.79 / 1.83 s | −2.0% | 1.84 / 1.86 s | −1.0% |
| TinyLlama T64 | 3.18 / 2.95 s | +7.8% | 2.93 / 2.89 s | +1.5% |
| TinyLlama T128 (calibration rung) | 6.32 / 6.19 s | +2.0% | 5.39 / 4.87 s | +10.7% |
| **Llama-3-8B T32** (not used in the fit) | **3.34 / 3.44 s** | **−3.1%** | 3.13 / 3.68 s | −14.8% |

Further checks:

- The 8B T32 cold run, excluding the in-process verify, is modelled at 285 s against 291 s measured (−2%).
- The GPU-arm errors are within the measured run-to-run spread. The T128 GPU phase run and the ladder's T128 GPU run differ by 13% on the same binary.
- Memory model: one-block peak ≈ 53 B per committed element plus the base. It gives 0.81 / 1.62 / 3.48 GiB for TinyLlama against 0.85 / 1.64 / 3.39 measured, and 1.90 GiB for 8B T32 against 1.91–1.95 measured.

### 2.4 Fixed costs per run, today (8B)

| Cost | Seconds | Label |
|---|---|---|
| Digest pass: load and SHA-256 every padded layer | 83.0 | [MEASURED] |
| Proving-pass block reloads (2.5 s per layer) | 79.2 | [MEASURED] |
| In-process verify, mostly a third reload | 93.4 | [MEASURED] |
| Fresh verify | 96.1, of which 13.3 is cryptography | [MEASURED] |
| Sealing, run header | 0.02 | [MEASURED] |
| Per block, inside the proof: five slot fixed costs + weight folds | ≈ 0.4 + 0.41 | [MODEL] |

## 3. Llama-3-8B at T = 512 … 4096 with today's code

Assumptions:

- **Row width** n is the receipt-minimising admissible one (2^15 at T512, 2^16 at T1024, 2^17 at T2048, 2^18 at T4096) [COUNTED].
- **Profiles.** No 8B profile above T32 is registered. Every row below needs a profile, a calibration export and a fidelity check of F_P = 9 at large T, which the readiness note `ZK60_TRAINED_STACK_READINESS_20261017.md` §4 flags as a calibration cliff.
- **Mac (M3 Ultra).** CPU only, with no Metal backend and no Mac build established. Assumed 2.5× (range 2.0–3.5) the laptop's 16-thread throughput, on the basis of its 24P + 8E cores and 819 GB/s against the laptop's ~120 GB/s [MODEL].
- **5090, today's code.** Only the commit runs on the GPU. The commit is at the measured 4070-Laptop rate divided by a board factor of 5 (range 4–7): the bandwidth ratio is 7.0× and SMs × clock is ~5–6×. Every other phase and the witness run on the 5090 PC's host CPU, assumed 2× the laptop (range 1.5–2.5); that CPU is unknown. Weight loading is per run [MODEL].

| T | Committed elements per block | Laptop CPU / GPU arm (pos/s, fit?) | Mac CPU (pos/s, central; fit? at 256 GB) | 5090, today's code (pos/s, low / central / high; VRAM; host RAM) | Receipt per pass | Verify crypto per pass |
|---|---|---|---|---|---|---|
| 32 | 0.028 G | 0.112 / 0.115, fits (measured 0.110) | 0.20, fits | 0.18 / 0.19 / 0.21 | 0.48 GB | 13 s |
| 128 | 0.118 G | 0.22 / 0.25, fits (6.3 GiB) | 0.47, fits | 0.38 / 0.45 / 0.52 | 0.94 GB | 25 s |
| 256 | 0.273 G | CPU no (14 GiB); GPU arm marginal (10.7 GiB host) | 0.54, fits | 0.43 / 0.54 / 0.64 | 1.44 GB | 62 s |
| **512** | 0.663 G | no fit (33 GiB CPU path) | **0.55**, fits (33 GiB) | **0.43 / 0.55 / 0.67**; VRAM 5.1 GiB; host ≈ 25 GiB | 2.23 GB | 210 s |
| 1024 | 1.85 G | no | 0.44, fits (92 GiB) | 0.34 / 0.45 / 0.56; VRAM 14 GiB; host ≈ 69 GiB | 3.60 GB | 804 s |
| 2048 | 5.77 G | no | no (286 GiB) | no (VRAM 43 GiB) | 6.36 GB | 3,178 s |
| 4096 | 19.9 G | no | no (981 GiB) | no (VRAM 148 GiB) | 11.9 GB | 12,674 s |

All rates in this table are [MODEL] cold single passes, with weight loading included and the in-process verify excluded.

- **The laptop cannot reach T512** at 8B.
- **The Mac is the memory machine.** It holds up to T1024 in the CPU path, and T2048 only with a streamed CPU commitment that drops the 32 B/element encoded matrix (~115 GiB) [MODEL]. It is not a throughput machine.
- **At T512 on today's 5090 code the time splits as follows** (central, per block, 25.7 s):
  - host-CPU proof phases 18.3 s;
  - CPU witness 6.5 s;
  - GPU commits 0.8 s.

  This agrees with the earlier `MVP_STATUS.md` projection of 0.62–1.23 positions/s.
- **Verification grows as h·T².** The verifier evaluates the dense public tables (the causal mask and others) over the score domain. At T512 that is 6.6 s per block [MODEL].

## 4. The levers

The phase shares quoted here are for 8B at T512 on the laptop-CPU law, where the proof is 52.0 s and the witness 13.1 s per block:

- commit 15.3 s (29%);
- zero-checks 22.8 s (44%: D 7.8, S 6.7, F 5.3, Q 1.9, Kv 1.1);
- inverses 4.0 s (8%);
- openings 3.9 s (7%);
- conversion 1.9 s (4%);
- rest 4.2 s (8%).

Engineering costs are [MODEL] judgements in lane-days, calibrated on this week's native rounds (one round ≈ one lane-day of agent work).

| # | Lever | What it changes / phase attacked | Expected factor and evidence | Cost (lane-days) | Risk, rulings | Depends on |
|---|---|---|---|---|---|---|
| L1 | **Run hygiene and startup**: hash weights once, in parallel; keep `LayerRecord`s; resident model; skip the in-process verify in production | Removes the per-run reloads (79 + 83 s) and the 93 s verify; digest once at startup | 8B T32 laptop cold 384.5 → ~150–170 s (2.3–2.5×) [MODEL]. With a resident model on the 5090 PC, steady-state loads are 0. Researcher: digest cache "CLI cold 2P->P" (`research/zkp-efficiency/handoffs/20261004-full-public-digest-cache.md`); TN cache negative (`…/20261004-tn-weight-cache.md`) | 2–3 | No ruling. The statement must still bind every block digest, computed once and pinned. Resident 8B needs ≥ ~8–16 GB host RAM (not the laptop) | — |
| L2 | **Witness on the GPU** (exact int8 GEMMs, requant, RoPE, softmax chain) | Witness: 17.7 ms·T + 15.5 µs·T² per block on CPU, i.e. 13.1 s at T512 and 332 s at T4096 | → ~0.03 s per block at T512 on a 5090 (112 G int8 MAC plus the A-plane writes) [MODEL]. A CPU alternative for the Mac: tiled int8→int32 microbench 4.8–7.7× (`…/20261017-exact-witness-projections.md`) | 5–8 | Per-layer bit-exact parity is already mandatory (R3-1), so acceptance is clear. VRAM freeze rule on the laptop | — |
| L3 | **The five zero-check sumchecks on the GPU** (slots 14–18 plus extension rounds), with device-built tables, a base-field first round, and host Fiat–Shamir and masking | 44% of the CPU proof | Anchored band on the 5090 vs 16 laptop threads: **10 / 25 / 60×** [MODEL]. Basis: the measured hashline FFN activation side was 285 s CPU (8 threads) vs 38.6 s on the 4070 Laptop (7.4×, `START_HERE.md` §2), ≈5× vs 16 threads, × board 4–7. Roofline: 72 B per element-term, i.e. 0.1 ns at 40% of 1.79 TB/s, **~300–650× the CPU coefficients** (Kv ~1300×) [COUNTED]. Researcher: device-round design, ≥7 sequential exchanges survive (`…/20260927-sc-szc-device-round.md`); grouped Eq measured −14–22% on a synthetic softmax slot (`…/20260924-sc-szc-groups.md`, already the `GroupedEqRounds` path). Literature: binary-field GPU sumcheck 1.6–4× (SumCATS, NVIDIA; not our field) | 12–20 | No ruling: byte-identical rounds (the R1d oracle at `argument.rs:545-567`). Fp2 on device. Laptop VRAM freeze: test at ≤ 4 GiB | A/H raw rows on the device (exist in the keyed chunked route) |
| L4 | **The rest of the prover on the GPU**: inverses, openings (all groups in one pass), conversion (the witness kernel writes A rows), row sums, matmul-slot weight folds, mask rows | 27% of the CPU proof | Same bands as L3. Roofline per block at T512: inverses 0.024, openings 0.015, rest ~0.005 s [COUNTED] | 10–15 | No ruling; byte-identity gates | L2, L3 |
| L5 | **Commit kernel to roofline**: fused LDE/NTT, device BLAKE3 and Merkle top, no host round-trip | Commit: 29% CPU, and the dominant GPU phase once L3–L4 land | The 4070 commit is measured at 5.06 ns per element. At ~170 B of counted traffic per element that is **≈13% of its 256 GB/s** [COUNTED]. 40% would make it 3× [MODEL]. Researcher: inverse-store pad fusion 663,552 → 401,408 B per row (`…/20260927-inverse-store-pad.md`); shift twiddles 35% of the NTT at 2^20 (`…/20261013-native-shift-twiddles.md`). **Without L5 the commit alone caps a 5090 at 19 / 24 / 33 positions/s at T512** [MODEL] | 5–10 | No ruling. The existing CPU/GPU proof-byte gates apply. A device decline must fail closed (readiness note §2a) | — |
| L6 | **Larger T, multi-pass and batching** | Amortizes startup and per-block fixed costs; dense attention penalizes T | The per-token CPU cost is lowest at T≈128 (83 ms per block-token) and rises to 102 ms at T512, 136 ms at T1024 and 346 ms at T4096 [MODEL]. On a GPU-resident prover the per-block fixed cost is ~0.03 s, so T512 is the operating point. A total-workload rate of 50 at steady rate r needs N ≥ 50·startup / (1 − 50/r). At r = 57 that is 15.7 k positions with a 40 s startup and 63 k with today's 160 s [COUNTED]. Batching B sequences into one block proof (new profile) only helps at small T or for decode. Researcher: batched weight fold 0.087% (`…/20260926-batched-weight-fold.md`); amortized-throughput note (`…/20260926-amortized-throughput.md`) | Multi-pass server 3–5; batch-axis profile 8–12 | Fresh masks every pass; no blinding reuse (`ZK60_THROUGHPUT_TARGET.md`). Multi-pass is aggregate throughput, not one long context | L1 |
| L7 | **Causal-triangle score domain**: pack the lower triangle | S domain halves | Committed elements −20% at T512 and −28% at T1024 [COUNTED]. Anchored 6.9 → 8.2; roofline 57 → 70 positions/s at T512 [MODEL] | 10–15 | **New profile plus soundness review.** Today's integer relation includes the masked upper entries, and the researcher showed the full 2,048-site relation differs from the lower triangle (`…/20260926-kv-proof-state.md`). Fidelity check needed | 8B profile at T512 |
| L8 | **zkAttn-style softmax normalization**: committed LSE offset plus a per-row sum band | Score-domain A planes 13 → 3, lookups 15 → 4, zero-check terms 24 → 8 per entry [COUNTED on a sketch, not a spec] | After L7, committed elements −17% at T512 and −28% at T1024. Anchored 8.2 → 9.4; roofline 70 → 83 positions/s at T512 [MODEL]. Literature: zkLLM zkAttn (`results/zk60_lit_zkllmpot_20261017/ASSESSMENT.md` §5 B) | 15–25 | **RULING needed.** It turns an exact relation into one with bounded prover slack, a small adversarial bias on attention. Needs a privacy re-check and a fidelity check | L7 is optional |
| L9 | **Verifier: public-table descriptors** (succinct causal mask, RoPE, Eq) | Verify goes from O(h·T²) to O(weights) | Verify crypto at T512 6.6 → ~0.39 s per block (210 → 12 s per pass) [MODEL]. Researcher: causal mask "8,388,607 dense interpolations vs 1,022", "128MiB … vs 24KiB" (`…/20261012-causal-mask-descriptor.md`) | 5–8 | Verifier change, so a soundness review. No product ruling | — |
| L10 | **Proof size** | 69.6 MB per block at T512, 2.23 GB per 512-token pass [COUNTED]; 220 MB/s of receipts at 50/s | Not part of the rate. Options are fewer column checks via a lower code rate (security ruling) or recursion (not planned) | — | Security ruling (D-register) | — |
| L11 | **CPU micro-levers** (researcher, tested in isolation only): Fp2 four-reduction −18.8% of reduction calls; compiled denominators −5.9% of base multiplications; unpadded round0 −7.0% of API ops; row coefficients −14.9% of base products; direct U8 H writer ceiling 2.9–3.0%; pair-inverse cache 0.5% | CPU sumcheck and inverses | ≤ ~1.2–1.4× on the CPU sumcheck combined [MODEL]. They matter for the Mac route and as kernel-design input. Falsified: fold/next-round fusion (1.66% slower), and others (`research/zkp-efficiency/FINDINGS.md`) | 1–2 each | None | — |
| L12 | **Parallel plane-to-row conversion and parallel exp/act inverses** (the levers named in R4-4) | Conversion is 2.9% and exp/act inverses 0.9% at T128 (§1 correction) | Saves ≤ ~3–4% on the CPU [MODEL]. They vanish on a GPU-resident prover | 1–2 | None; deterministic and byte-identical | — |
| D1 | **Design change: LogUp-GKR in place of the committed H** | H is 55% of committed elements at T512 [COUNTED] | Commit and opening volume −55%. Roughly 1.3× on the roofline block time once L5 is done [MODEL]. Researcher: fraction tree (`…/20260926-logup-fraction-tree.md`); **privacy counterexample**: a lookup "recovered exactly from D/C" | 20–30 | **Privacy design plus ruling** | L3–L5 |
| D2 | **Design change: code rate 1/4 → 1/2** | Encode and hash traffic about halves | ~1.3× on the roofline block [MODEL]; more column checks and bigger proofs | 5–10 | **Security ruling** (column-check count, bits) | L5 |

Out of scope for the 50/s target:

- **KV reuse and decode.** The researcher finds no saving against a single prefill, and cross-window state is open under D8/D11 (`…/20260926-kv-proof-state.md`).
- **Multi-GPU.** `ZK60_THROUGHPUT_TARGET.md` says no purchase or multi-GPU deployment follows from this benchmark.

## 5. The ranked, integrated plan

One RTX 5090, Llama-3-8B, **T = 512 per pass**, 32 blocks, resident model, steady state. Each row includes every row above it.

- The *anchored* columns use the measured-GPU-ratio band from §4 (L3 basis).
- The *roofline* columns assume every GPU kernel moves the counted bytes at 25% or 40% of 1.79 TB/s, plus 0.025 s per block of host Fiat–Shamir and Merkle-top work.

All rates are [MODEL] positions/s (`SP/projection_output.txt`).

| Step | What lands | Anchored low / central / high | Roofline 25% / 40% | Cost (lane-days) | Ruling? |
|---|---|---|---|---|---|
| 0 | Today's code on a 5090, cold single pass with loads | 0.43 / 0.55 / 0.67 | — | — | — |
| 1 | L1 run hygiene, resident model (steady state) | 0.47 / 0.62 / 0.78 | — | 2–3 | no |
| 2 | L2 witness on the GPU | 0.63 / 0.83 / 1.04 | — | 5–8 | no |
| 3 | L3 the five zero-checks on the GPU | 1.27 / 1.84 / 2.44 | — (host-bound) | 12–20 | no |
| 4 | L4 the rest of the prover on the GPU | 3.4 / 6.9 / 12.8 | **37 / 57** | 10–15 | no |
| 5 | L5 commit kernel 3× (13% → ~40% of bandwidth) | 3.8 / 8.5 / 17.1 | 37 / 57 (already assumed) | 5–10 | no |
| 6 | L7 causal-triangle scores | 4.5 / 10.1 / 19.9 | **46 / 70** | 10–15 | profile + soundness review |
| 7 | L8 zkAttn normalization | 5.1 / 11.3 / 22.3 | **54 / 83** | 15–25 | **ruling** + privacy re-check |

Lanes running in parallel from day 1, which gate steps 4–7 on the 5090:

- the 8B T512 profile, calibration export and F_P fidelity check (5–8 lane-days);
- 5090 Linux bring-up and the chunked-commit fail-closed fix (Victor plus 2–3 lane-days);
- L9 verifier descriptors (5–8 lane-days).

The path to step 5 is about 35–55 lane-days; to step 7 about 60–95.

**Verdict.**

- **With the GPU efficiency this project has measured, no recorded combination reaches 50.** The best is 11 (central) to 22 (high) positions/s at step 7.
- **50 is reachable only in the roofline regime**, with the whole prover GPU-resident and every kernel moving its counted bytes at a sufficient fraction of the 5090's bandwidth:
  - **≥ 34% from step 4/5 on** (57 positions/s at 40%);
  - **≥ 28% after step 6**;
  - **≥ 23% after step 7**.
- Equivalently, the ported CPU phases must run **≥ 340×** faster than the laptop's 16 threads (≥ 170× after step 7), with the commit at ≤ ~0.25 ns per element.
- Neither the laptop nor the Mac can get there.

| Roofline at 40%, today's layout, T512, per block | Seconds |
|---|---|
| commit | 0.157 |
| zero-checks | 0.050 |
| inverses | 0.024 |
| openings | 0.015 |
| witness | 0.003 |
| host sequential | 0.025 |
| **total** | **0.279** |

The **budget is 0.32 s per block** (512 positions / 50 / 32 blocks). The commitment is the item that decides it.

**For the total-workload rate** (`ZK60_THROUGHPUT_TARGET.md`), startup must also shrink. At a steady 57 positions/s, total-workload ≥ 50 needs 63 k positions with today's ~160 s of loading, 15.7 k with 40 s, and 3.9 k with 10 s [COUNTED].

**If the kernels stall below ~25%.** Measure this with the step-2 task below and then on the 5090. In order of cost per gain, the remaining design changes are:

1. D1, LogUp-GKR helpers in place of a committed H: −55% committed elements; needs a privacy design and a ruling.
2. D2, code rate 1/2: ~1.3×; needs a security ruling.
3. Wider range tables, 16-bit instead of byte limbs, to cut limb planes. This reopens the P-3 `log(Tab) == log_cols` privacy invariant (`layout.rs:139-169`), so the privacy argument must be re-derived; not counted here.

Even all three on top of step 7 at anchored efficiency give only about 13–16 positions/s central and ~25–30 high [MODEL], so **efficient GPU kernels are the necessary condition, and rulings are not a substitute**.

## 6. The first three engineering tasks

Each is one agent round. Guard every heavy command (`scripts/zk60_resource_guard.py run --class {build,cpu,gpu}`). On the laptop, keep VRAM ≤ 4 GiB.

**Task 1: run hygiene, startup and byte counters.** CLI/run code only; no transcript or layout change.

- Do:
  - (a) a production switch that skips the in-process verify (the fresh-process verify remains the check);
  - (b) the digest pass keeps each `LayerRecord`, and the proving-pass reload compares against it instead of re-hashing the padded words;
  - (c) parallel SHA-256 over arrays (same bytes, same digests);
  - (d) `HL_PB_TIMING` prints counted work per phase (committed elements, element-terms per slot, lookups) next to seconds, so every phase reports ns per unit and GB/s.
- Accept when:
  - the 8B T32 ho00 statement identity is still `259dad7c…`;
  - all 32 segment lengths equal `N/r4/stack-llama3_8b_pg_rot1_T32-ho00-cpu/run/statement/segments.json`;
  - the fresh-process verify accepts and the 11 run-level controls refuse;
  - the TinyLlama T32 identity is still `9b71dfb0…`;
  - the byte counters sum to the counted totals (A = 32,653,312 words at TinyLlama T128);
  - measured on the laptop CPU: digest pass ≤ 20 s (from 83.0), proving-pass loads ≤ 30 s (from 79.2), total 8B T32 wall ≤ 180 s (from 384.5) [targets, MODEL].

**Task 2: the GPU F-slot zero-check (slot 18) on the 4070. This is the go/no-go measurement.**

- Do:
  - put the masked-sumcheck body of slot 18 on the device, with its tables built on the device from the A/H rows (the keyed chunked store already keeps raw rows on the device);
  - keep the transcript, CFS masking and extension rounds on the host.
- Accept when:
  - for the same transcript state, round messages, challenges and finals equal the CPU's (the R1d oracle pattern, `argument.rs:545-567`) on rung-TC, TinyLlama T32/T128 and the R4-2 8B generic block;
  - the seeded CPU/GPU proof-byte gates are byte-identical;
  - the run shows `HL_GPU_REQUIRED=1` and 0 declines;
  - VRAM peak ≤ 4 GiB.
- Measure: slot-18 seconds against the CPU (17.6 s summed over 22 blocks at TinyLlama T128) and the **achieved bandwidth** = 72 B × size(F) × 17 terms / time.
- Decision rule:
  - ≥ 25% of 256 GB/s: schedule L3–L5 against the roofline column;
  - 10–25%: continue with kernel-design work before porting more;
  - < 10%: report that 50 is out of reach on the current design and bring D1/D2 to Victor as rulings.

**Task 3: the 8B phase ladder at T64/T128** (generic dense Llama-3-8B block, test-only constructor like `tinyllama_trained_ladder`; CPU and GPU arm; `HL_PB_TIMING`).

- Predictions, written before the run [MODEL, `SP/cost_model.py`]:

  | T | CPU proof per block | GPU arm | Witness | Host peak | Verify | Receipt |
  |---|---|---|---|---|---|---|
  | 64 | 5.47 s | 4.78 s | 1.19 s | 3.2 GiB | 0.48 s | 21.7 MB |
  | 128 | 10.60 s (commit 2.72, zero-checks 5.05, inverses 0.67, openings 0.69, conversion 0.34, rest 1.14) | 8.78 s | 2.51 s | 6.3 GiB | 0.77 s | 29.3 MB |

- Accept when:
  - the block proves and verifies in a fresh process, and every control refuses (the generic-honest-witness rule);
  - the measured phase table is recorded;
  - the model error is ≤ ±15% per phase group, or else the model is refitted and §5 is re-run (`python3 -B results/zk60_speed_plan_20261017/projection.py`).

  This validates the T-scaling at 8B geometry that every row of §3 and §5 depends on.

Next after these:

- a 22-block TinyLlama T128 stack on the laptop GPU with slots 14–18 ported (L3 complete);
- the witness kernel (L2);
- the 5090 bring-up.

## 7. What would change this plan

- **Task 2's achieved bandwidth.** This is the single number that decides whether 50 is reachable.
- **Task 3's T-scaling** at 8B: if S-domain costs grow faster than counted, the operating point moves below T512.
- **5090 PC host specification and RAM.** Today's code at T512 needs ~25 GiB of host RAM in the GPU-commit path, and T1024 needs ~69 GiB.
- **The F_P = 9 fidelity at T512** (calibration lane). More softmax precision may add limb planes on the score domain.
- **A ruling on L8 (zkAttn) or D1/D2.** Each moves the required kernel efficiency down by 5–10 percentage points.
