# RTX 5090 projection for W16R2 (Q = 280) + D55, and the levers re-ranked (2026-11-03)

Claude, standing researcher (D50). **Arithmetic and reading only.** No build, proof, GPU run or Git write. One
single-thread micro-benchmark (a 218 MB byte scan, about 0.03 s). Files: `model.py` (every input and range, with its
source), `model.out.txt` (its output), `projection.json`.

Labels: **[MEASURED]** a Mac log or README figure, source given; **[INFERRED]** derived from measured wall clocks
but not itself a clock of that thing; **[MODEL]** arithmetic on measured parts or spec sheets; **[ESTIMATE]**
judgement.

## 1. Plain summary

- **Proof only** (the same clock as the Mac's 22.9 tok/s: witnesses built before the timer), one request of W16R2 +
  D55 on an RTX 5090 projects to **about 54–82 proved tok/s (p10–p90) with today's serial head, 69–117 with two small
  byte-identical fixes to it, and about 40 in a pessimistic straight port** [MODEL on ESTIMATE ranges].
- **In the central case the GPU is not the limiter.** The per-fork host path (about 0.21 s of host work per block,
  mostly on one thread) times a fork count capped near 8 by 32 GB of VRAM is. GPU-kernel levers then move one request
  by 0–3%; moving host work onto the device moves it by 5–19%.
- **The witness is outside every clock so far, and it is the largest cost.** The D55 A/B harness spends 8.5–8.7 s per
  call building the 32 witnesses outside the timer, in every one of five logs [INFERRED]: about 0.27 s per 8B block,
  against 0.17 s per block of proving.
  - D55's commit phase needs every boundary plane before any fork starts, so the forward chain is a serial prefix of
    one request.
  - Under the throughput target's clock (which includes witness work), the Mac's one request is therefore about
    **9 tok/s, not 23** [INFERRED].
  - On the 5090 box, today's witness code caps one request at **about 6–11 tok/s whatever the GPU does**.
  - A GPU-exact forward (int8 tensor-core products on two limbs of each int16 activation) brings the projection back to
    **48–76 tok/s (p10–p90), P(≥ 50) ≈ 0.86** [MODEL].
- **The Mac's remaining levers** are worth ×1.0–1.1 each on its 23 tok/s ceiling. The largest are coefficient-form
  rows (×1.09; changes bytes), the zero-check kernels (×1.02–1.11), H121 per-fork queues (×1.0–1.25, unmeasured)
  and H122 preflight (×1.06).
  - **Byte-preserving levers together** (#2, H122, H123): about **26–28 tok/s** proof-only, or up to about 35 if H121
    recovers the whole queue gap.
  - **With the byte-changing ones too** (coefficient form, #3, #4): about **31–37** [MODEL].
  - The Mac does not reach 50 on any of these.

## 2. The Mac profile the projection starts from

W16R2_8B_T128_H24, Metal, warm. GPU attribution comes from `HL_METAL_TIMING=1`, which is attribution only and never a
timing; the one-request figures are from untimed-attribution runs.

| Part | Mac ms / block | Source | Bound by (split used) |
|---|---:|---|---|
| inverse NTT, A + H (2^14) | 10–13 | M21; `w16r2 logs/ab/m_ab_gpu.log` | 0.4 multiply, 0.2 DRAM, 0.4 latency |
| forward NTT, A + H (2^14 → 2^15) | 18–25 | M21 (9 + 9); A/B log (12 + 13) | 0.5 multiply, 0.5 DRAM (M11; counted: 615 M products = 4.1 ms, 2.6 GB = 3.7 ms) |
| column leaf hash, A + H | 4 | same | 32-bit ALU |
| heavy zero-checks, slots 14–18 | 59.7 | same; batch + replay clocks 15.6 / 6.1 / 3.8 / 8.1 / 26.1 | 0.47 multiply, 0.08 DRAM, 0.20 cache (redundant per-point loads), 0.25 latency |
| TAB (slot 19) + six small slots | 5.1 + 12.5 | same | 0.8 latency |
| **summed GPU attribution** | **109–116** | | |
| store folds A + H (host CPU) | 16.4 | same | host |
| **D55 N = 6 forks phase / 32** | **152** | `logs/ab/m_d55_r2a.log` pass 1 | [MEASURED] |
| serial head and tail of one request | 0.680 s | preflight 0.377, commit 0.226, join 0.077 | host, mostly |
| one request, wall | 5.542 s = 23.1 tok/s | same | GPU-bound |

**Two counts behind the splits** [MODEL]:
- **Slot 18.** 2^21 entries × 5 points × 58 multiplies is about 445 M Fp2-equivalents, which is 12.8 ms at the
  measured 34.7 G Fp2/s (M18). That is 49% of the 26.1 ms. Its DRAM traffic is about 1.4 GB, or 2.1 ms. The rest is the
  per-point table loads and the per-round fixed cost, which matches M13's negative ("loads and latency weigh as much as
  the multiplies").
- **The Mac's concurrency overhead.** The forks phase runs 152 ms per block against 109–116 ms of summed attribution,
  so η = 1.27–1.39. One process-wide `MTLCommandQueue` serves every fork (`metal.rs:57, :82`). Whether this is queue
  serialisation is H121's question, and it is unmeasured.

**The per-fork host path, about 215 ms** [MODEL]: the W16 phase report (`logs/m15g/phases.log`) minus GPU
attribution, recut at rate 1/2.

| Host phase | ms |
|---|---:|
| planes, lookups, indices, mask rows | 39 |
| helpers and inverses | 26 |
| commit CPU parts (salts, Merkle) | 15 |
| M commit | 5 |
| public weight folds (slots 05–13) | 31 |
| zero-check table builds and setup | 34 |
| small slots' host share | 24 |
| openings | 41 |

Diagonal test weights; dense real weights add about +15 ms (M8).

## 3. The 5090 factors [ESTIMATE]

| Kind | 5090 / M3 Ultra | Basis |
|---|---:|---|
| Goldilocks multiply | ×4–8 | Mac 149 G/s [MEASURED, M18]. The RTX 4070 Laptop's 64×64→128 MAC probe ran at 156.5 G/s [MEASURED on the lost laptop, `U_PERF2_CLAIM2_REPORT.md` §2.3], about the Mac's figure. 5090 / 4070L SM×GHz is 410 / 54–72 = 5.7–7.6, since both issue 64 int32 multiplies per SM per clock (`U_PERF3_THROUGHPUT_MODEL.md` §3.2). Widened for port efficiency. I could not fetch NVIDIA's cc 12.0 throughput table. |
| DRAM | ×1.9–2.2 | 1792 / 819 GB/s |
| cache-served loads | ×2–4 | no like-for-like Mac figure |
| 32-bit ALU (BLAKE3) | ×3–3.7 | 21,760 lanes × 2.41 GHz against 10,240 × ~1.4 GHz |
| per-round latency | ×1.5–4 | Metal batched round 0.025 ms [MEASURED, M6 probe]; CUDA graph nodes take a few µs; clock ×1.7 |

**The 5090 box itself** (`ZK60_5090_LINUX_BRINGUP.md`: CPU, RAM and PCIe "not yet known"):
- host per-core speed ×0.7–1.1 of an M3 Ultra P-core;
- 12–28 usable cores;
- host DRAM 60–300 GB/s (a desktop on dual-channel DDR5, up to a workstation);
- PCIe 5 x16 at about 50 GB/s.

**Fork count** is capped near **8** (6–10) by 32 GB of VRAM. The W16R2 N = 6 run peaked at 19.8–21.0 GB of Metal
allocation (`history.jsonl`: `w16r2-d55-r2a`/`-r2b`), which is 3.3–3.5 GB per fork.

**Two port regimes**:
- **serial-queue:** Metal-like, so latency is never hidden, and η is the Mac's 1.27–1.39;
- **streams:** one CUDA stream per fork with a CUDA graph per slot, so 60–90% of the latency share overlaps other forks'
  kernels, and η is 1.0–1.2.

## 4. The projection: one request, 8B T128, W16R2 (Q 280) + D55

**Q = 280 against 260:** +20 opened columns. That is +0.82 MB of column bytes per block (+3.5%) and under 1 ms of
gather [MODEL]. The Mac's 22.9 should not move measurably [ESTIMATE]. It is not measured at 280.

### 4a. Proof only (the same clock as the Mac's 22.9)

| Scenario | N | GPU ms/block (throughput) | Host path ms/block | Head + tail s | Forks s | tok/s | Limiter |
|---|---:|---:|---:|---:|---:|---:|---|
| P: straight port (serial queue, host-built tables, slow desktop host) | 6 | 74.0 | 343 | 0.85 | 2.37 | **39.8** | GPU kernels |
| P2: streams, host-built tables | 8 | 26.5 | 244 | 0.65 | 1.27 | 66.7 | host DRAM bandwidth |
| **C: streams, tables built on the device** | 8 | 26.5 | 211 | 0.65 | 1.04 | **75.9** | per-fork host path |
| C + H122/H123 (serial head fixed) | 8 | 26.5 | 211 | 0.15 | 1.04 | **107.9** | per-fork host path |
| O: compact uploads, fast host, 10 forks | 10 | 18.8 | 182 | 0.10 | 0.71 | 157.1 | per-fork host path |

**Monte Carlo** (uniform over every range, 20,000 draws, seed 20261103), p10 / p50 / p90:

| Regime | p10 / p50 / p90 tok/s | P(≥ 50) | Main limiter |
|---|---|---:|---|
| serial-queue, host-built tables | 50.6 / 57.8 / 66.2 | 0.92 | GPU kernels in 80% of draws |
| streams, host-built tables | 53.6 / 66.4 / 80.8 | 0.97 | host path 68% |
| streams, device tables | 54.1 / 67.6 / 82.2 | 0.97 | host path 75% |
| streams, device tables, head fixed | 69.1 / 92.5 / 117.3 | 1.00 | host path 75% |

**Many requests** (aggregate, proof only): the ceiling is min(GPU, link, host DRAM, cores), about **107–213 tok/s**
[MODEL].

### 4b. The target's clock (witness work included)

**The witness.** Before every timed call the D55 A/B harness rebuilds 32 witnesses on 8 builder threads
(`run_fork_tests.rs:1930-1954`). The test's total wall minus every timed part (setup, proofs, verifications) is
8.60 / 8.64 / 8.71 / 8.69 s per call in `m_d55_r2a`, `-r2b`, `-w16a` and `-w16b`, and 8.48 s over 16 calls in the
original D55 A/B [INFERRED]. That is about **0.27 s of whole-Mac wall per W16 8B T128 block**.

Two things back that figure:
- The laptop measured TinyLlama T128 at **0.607 s per block on 16 threads** [MEASURED, `witness_speed_tests`].
  TinyLlama has about a fifth of the 8B block's 2.79e10 multiply-adds.
- The witness matmuls (`witness.rs:455-480`) are scalar i32 products widened to i64 per term.

**The serial prefix.** D55's phase 1 asks the source for every boundary plane before any fork (`run_fork.rs:1092-1112`),
so the 32-layer forward chain is a **serial prefix** of one request.

| Witness implementation | Forward chain per layer (5090 box) | One request, tok/s p10 / p50 / p90 | P(≥ 50) |
|---|---:|---|---:|
| Mac today | 0.27 s [INFERRED] | **9.0** (8.6 s + the measured 5.54 s) | — |
| 5090, today's CPU code | 0.30–0.60 s | 6.5 / 8.1 / 10.7 | 0.00 |
| 5090, SIMD int8 CPU products (int16 split into two int8 limbs; exact in i32 for K ≤ 14,336) | 0.04–0.08 s | 32.2 / 38.2 / 46.9 | 0.04 |
| 5090, exact forward on the GPU (int8 tensor-core products, two limbs) | 0.01–0.035 s | **48.4 / 60.0 / 76.4** | 0.86 |

**Overlap does not rescue today's code.** Even perfectly overlapped, today's witness code needs 2.15–8.6 CPU-seconds
per block [INFERRED], which caps 16 host cores at **7–30 tok/s** aggregate.

### 4c. Assumptions (all carried in `model.py`)

1. The CUDA port reaches the same fraction of each roof as the Metal kernels do on the Mac (kernel efficiency carried
   over).
2. Tables are built on the device in every central case; the P/P2 rows show what happens otherwise.
3. Each fork's host path stays about 0.21 s at Mac speed.
4. 8 forks fit.
5. The witness expansion beyond the forward (limbs, histograms) runs inside the forks and is cheap. It is not cheap
   today.
6. Head and tail are 0.45–0.85 s today, 0.10–0.20 s with H122 and H123.

### 4d. What would falsify it on the real box

1. **Multiply roof.** The M18 harness ported to CUDA (`x = x·y + x` over 2^20 threads) gives under **0.6 T Goldilocks
   mul/s** (×4). That kills the GPU half of every row above.
2. **First heavy kernel.** Slot 18 at the W16R2 shape takes more than **8 ms** of device time (Mac 26.1 ms; model
   2.5–5 ms).
3. **Integrated.** Proof only, every device phase ported, per-fork streams, N = 8: below **40 tok/s** falsifies the
   range. Nsight showing the GPU busy over 70% of the forks phase while tok/s stays under 80 falsifies "host path is the
   limiter".
4. **Host.** A per-fork host path above 0.3 s per block on the box's CPU means N ≥ 12.5 is needed, which is past the
   VRAM cap. The 5090 is then host-bound below about 60 tok/s until host work moves to the device.

## 5. The levers re-ranked (from `model.out.txt`; Mac = one request, GPU-bound, N = 6)

"5090 C" columns are proof-only, head fixed / today's head.

| Rank | Lever | Bytes | Ruling | Effort (lane-days) | Mac ×, on 23.1 | 5090 C × |
|---:|---|---|---|---:|---:|---:|
| 1 | **H124 witness: exact SIMD/GPU forward chain + parallel expansion** | preserved (bit-exact witness gate) | no | 3–6 (SIMD CPU); 6–12 (GPU) | target clock 9 → 17.6–19.3 tok/s; proof only ×1.00 | target clock 6–11 → 48–76 |
| 2 | **H122 preflight once per resident model, or in parallel** (the CS-1/4/6 scans: 7 GB of i8 scanned with `contains`, `private_block.rs:859-861`, 32 blocks one after another) | preserved | no (reviewer note on CS-6 caching) | 0.5–1 | ×1.06 | ×1.22 (today's head) |
| 3 | **H125 host path on the device** (table builds, store and weight folds, Merkle, planes/helpers) | preserved | no | part of the CUDA port, 15–30 | ×1.00 (M5a negative on unified memory) | ×1.05–1.19 |
| 4 | **H121 per-fork queues / streams + GPU-busy timestamps** (absorbs H113's remainder) | preserved | no | 1–3 | ×1.0–1.25 (if the 152 vs 109–116 ms gap is queue serialisation) | the streams regime: p50 57.8 → 66.4 |
| 5 | **H123 31 boundary commits in parallel** (pads drawn in order first), overlapped with preflight | preserved | no | 1–2 | ×1.03 | ×1.10 |
| 6 | **Coefficient-form rows** (drop the inverse NTT) | **changes bytes** | **yes** | 4–7 + gates | **×1.09** | ×1.01 |
| 7 | #2 zero-check kernels (shared per-point loads first; the infinity point and affine extraction second) | preserved | no | 5–10 | ×1.02–1.11 | ×1.00–1.01 |
| 8 | #3 batch equal-size zero-checks | changes bytes | yes | 10–20 | ×1.03–1.08 | ×1.02–1.03; **−6.7 MB per block (−28% core bytes), verifier PCS about −50%** |
| 9 | #4 non-power-of-two F domain | changes bytes | yes | 10–15 | ×1.04 | ×1.01 |
| 10 | H114 helper inverses by gather (M15 already took 18 → 8 ms) | preserved | no | 2–3 | ×1.00 | ×1.01–1.02 |
| 11 | #5 pruned coset NTT | preserved | no | 1–2 | ×1.01 | ×1.00 |
| — | H112 cross-block pipelining | — | — | — | **subsumed by D55** | replaced by H125 |

Notes on the ranking:
- **#5 at rate 1/2.** Only the first stage prunes. Since n + Q = 16,664 exceeds N/2 = 16,384, only the n − Q of n
  first-stage pairs have a zero partner. That is about −0.7 ms, not −2.2. Drop it.
- **H112 on the Mac.** D55's forks already overlap one block's host phases with another's GPU work, and N = 6 exceeds
  (H + G)/G ≈ 2.9.
- **H112 on the 5090.** N must reach (H + G)/G ≈ 7–12.5 (§4a), so the lever becomes "shorten H" (H125) or "fit more
  forks" (H126).
- **H113.** M6 took the per-round cost from 0.21 to 0.025 ms. What remains is the latency share, about 33 of the 109 ms.
  Concurrency can hide it only if submissions overlap, which is H121. A standalone CUDA-graph round driver matters
  only in the serial-queue regime.

### Coefficient-form rows: does the hiding encoding allow it, and when must it land?

**The change.** Today's row polynomial is f_r = d_r + Z_n·g_r, where d_r interpolates the n data values on G_n
(`PRIVACY_RECHECK_20261102.md` §2.1). Coefficient form reads the n values as d̃_r's coefficients instead:
f_r = Σ_i d_{r,i} X^i + Z_n·g_r.

**Hiding carries over in form.**
- The opened entry of row r at η_j is d̃_r(η_j) + Z_n(η_j)·g_r(η_j). The pad term is a nonzero diagonal times an
  s × Q Vandermonde block, which is onto F^s for s ≤ Q (H1, H2). That block does not depend on how the message is
  encoded, so the opened columns are uniform whatever D is.
- The message half of each clear vector is still ρᵀD.
- The message-to-codeword map is still a linear bijection onto polynomials of degree < n + Q. Its coefficients are
  triangular: msg_i − pad_i, msg_i, pad_i.
- So conditioning on the opened columns leaves the message half as free as before (H3, H4).

**Soundness.** The δ/2 lemma covers any Fp-linear bijective verifier encoder onto RS[D, n + q_pad]
(`handoffs/20261101-delta-half-lemma-check.md` §7), and this is one.

**What it still needs:**
- the privacy gate's exact-rank parts (PG-R2, the Python rank lemma, the joint rank over A_k, B_k and A_{k+1}) re-run
  with the new encoder;
- a byte-identity gate, CPU = Metal;
- the encoder flag in `encode_row_zk`, `encode_buffer` and the Metal head (which then reads the row directly).

**It changes every codeword, every root and every receipt byte**, so it must land as part of a profile:
- **(a) Inside W16R2 before registration.** The Q = 280 branch already moves every W16R2 byte and re-runs its goldens,
  controls and privacy re-check, so one gate cycle covers both.
- **(b) As a later W16R3 string,** with a second full D54 and privacy-gate cycle.

**Recommendation.** Ask Victor before the Q = 280 branch closes. (a) saves a full gate cycle and buys ×1.09 on the Mac,
but adds an encoder change to a branch whose job is a parameter change.

## 6. New and refined hypotheses (STATE continues from H121)

- **H122. The preflight scan is per request and serial.**
  - **Lever.** Check once per resident model, or in parallel over blocks and chunks, as M8 did for the fold.
  - **Falsifier.** A sub-step timer shows the weight scans under 0.1 s of the 0.377 s.
  - **Supporting measurement.** libc memchr scans one 8B layer's 218 MB in 3.6 ms here [MEASURED, single thread,
    shared Mac], which is 0.12 s for 32 layers. Rust's core `contains` on i8 is slower, which is consistent with
    0.38 s [ESTIMATE].
- **H123. The D55 commit phase is serial.**
  - **Lever.** Draw every boundary's pads in order, encode the 31 boundaries concurrently, and start the commit phase
    alongside the preflight.
  - **Falsifier.** The commit phase is under 0.05 s after the change, or the boundary encodes are already concurrent.
- **H124. The witness forward chain.**
  - **Mechanism.** It is a serial prefix of every D55 request and is outside every clock so far. It is the largest
    single cost under the target's clock (§4b).
  - **Lever.** An exact SIMD-int8 or GPU int8 forward that returns the layer outputs, with the per-block expansion
    inside the forks. It is byte-preserving if the witness digests are equal.
  - **Falsifier.** A direct `witness::build_accuracy` clock on one W16 8B T128 block under 0.05 s. The INFERRED 0.27 s
    would then be something else in the harness.
- **H125. On the 5090 the per-fork host path, not the kernels, limits one request.**
  - **Mechanism.** N ≥ (H + G)/G is needed, about 7–12.5, and VRAM caps N near 8.
  - **Lever.** Move host work onto the device. M5a's "device plane gather: no gain" was measured on unified memory and
    does not transfer to a discrete card.
  - **Falsifier.** On the box, GPU-busy over 70% of the forks phase.
- **H126. Longer windows on the 5090 hurt one request.**
  - **Mechanism.** T256 doubles per-fork VRAM (N about 4) and the host path, so the model gives 65.6 against
    107.9 tok/s at T128 (central, head fixed). On the Mac T256 is the better one-request context (13.0 against 10.7,
    M14), because there the GPU, not the fork count, limits.
  - **Many requests.** The serial head, the tail and the next request's witness chain overlap other requests' forks. The
    aggregate is then set by the GPU and the host cores (§4a), and today's witness code alone caps it at 7–30 tok/s.
  - **Falsifier.** A T256 one-request run on the box at or above T128's tok/s.

## 7. Measurements to take on the Mac once the heavy lock frees (each small; none is a timing from `HL_METAL_TIMING`)

1. A direct witness clock: `witness::build_accuracy` on one W16 8B T128 block, warm, n ≥ 3. Split it into matmul and
   the rest (H124).
2. A preflight sub-step timer (H122).
3. getrusage CPU-seconds per block over a D55 N = 6 forks phase, which gives the host path in CPU-s (H125's input).
4. MTLCommandBuffer GPU start and end timestamps per fork under N = 6, to settle whether the 152 against 109–116 ms gap
   is queue serialisation (H121).
