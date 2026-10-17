# GPU zero-check lane (speed plan task 2) — report

Saved by the coordinating session from the lane's final report of
2026-10-17 23:06 UTC (the lane could not write this file itself). Ledger with
every step: `PROGRESS.md`. Labels: [MEASURED] = shared box, n = 1 unless
stated; [COUNTED]; [MODEL].

## In plain words

- **What moved.** Slot 18 (the feed-forward zero-check; 21 tables over 2^20
  entries at TinyLlama T128) runs its sumcheck body on the laptop RTX 4070
  behind `HL_GPU_ZEROCHECK=1`: tables built on the device from the resident
  A/H rows, every round's sums and every fold on the device. The transcript,
  CFS masking, all challenges and randomness, the R1d recovery and the
  extension round stay on the host.
- **Byte identity holds everywhere it was asked for:** rounds, challenges and
  finals equal the CPU's at rung-TC, TinyLlama T32/T128 and the R4-2 8B T32
  generic block, on dense random and honest-witness data; seeded proof bytes
  identical at all four shapes in three separate runs; 0 declines under
  `HL_GPU_REQUIRED=1`; the 22-block TinyLlama T128 stack with slot 18 on the
  device verifies in a fresh process with the CPU run's statement identity
  `53a5667d…`.
- **VRAM:** at most 3,457 MiB after one violation (7,123 MiB), found and fixed.
- **Speed:** the best variant ("lean") does the 2^20 slot in about **42 ms
  including the table build**, against about 0.72 s on 16 CPU threads: on the
  plan's figure **30 GB/s = 11.7% of 256 GB/s** [MEASURED]. The older variants
  (v2, the code default; v1) reach about 8%. Inside the CLI stack the same
  body took **182 ms (2.7%)**: the laptop GPU's clock ramp after idle (integer
  arithmetic 5–8x slower for the first ~100–200 ms after the 2 s of CPU-only
  slots before slot 18). With a 300 ms warm-up the in-stack body is 42 ms again.
- **Verdict: 10–25% band — kernel-design work before porting more slots.**
- **Main kernel finding:** every round kernel uses all 255 registers and still
  spills, so only 8 of 48 warps per SM run: latency-bound, not
  bandwidth-bound. The folds alone stream at 57–67% of 256 GB/s.

## 1. What moved, what stayed

`DevFzcRounds` (`gpu/cuda.rs`) is a `SumcheckRounds` evaluator driven by the
unchanged `zk::masked_prove_rounds`; it only returns unmasked sums. Kernels in
`gpu/fzc_kernels.cu`, compiled lazily by NVRTC, one variant per module (v1, v2
fused = default, lean `HL_GZC_LEAN=1`, lean unfused). Description and dispatch
in `gpu/fzc.rs` and `private_block/argument.rs::device_fzc`. A decline goes
through `gpu::declined` (panic under `HL_GPU_REQUIRED=1`); `HL_GZC_CHECK=1`
runs both bodies and asserts equality. This session's changes: the seeded gate
starts from `tagged_transcript` plus the block's public words; VRAM fixes
(`drain_device_pool` between shapes and arms; `GZC_SHAPES` filter; the table
buffer via `Pooled::take_min`, so slot 18 adds 0 MiB to the stack's VRAM);
diagnostics off by default (`HL_GZC_ROUNDS=1`, `PB-GZC-MEM`,
`HL_GZC_WARM_MS`). Patch against frozen review-r3: `gzc-vs-review-r3.patch`
(12 files); hashes `lane_sources_after.sha256`; binaries `bin/`
(`binaries.sha256`).

## 2. Byte-identity evidence

- Descriptor equals the slot's closure (80 random points) at 8 small shapes
  plus rung-TC, TinyLlama T32 (n 18), T128 (n 20), 8B T32 (n 19)
  (`logs/t3-release-small.log`).
- Device body = CPU body (masked rounds, challenges, finals, transcript state,
  next challenge): 360 synthetic bodies (n 1–10, D 4/5, gate and pad on/off,
  claim none / correct / wrong, all four variants); real slot 18 at 8 small
  shapes; trained shapes with dense random and honest data, resident rows and
  host words, lean 0/1, claim none/given — 36 equalities per run, run twice
  (`logs/t4-release-trained.log`, `logs/t10-trained-all-r2.log`).
- Seeded proof-byte gate (`prove_core` twice from one seeded generator, slot
  18 CPU vs device), byte-identical: rung-TC 7,591,336 B; TinyLlama T32
  11,627,208 B; T128 23,049,192 B; 8B T32 14,856,216 B (runs t6, t9, t10,
  under `HL_GPU_REQUIRED=1`).
- Fail closed (t6): a refused layout panics "fail closed", is counted, and
  leaves the transcript untouched.
- CLI stacks (22 TinyLlama T128 trained blocks, slot 18 on the device):
  s1-lean, s4-diag, s5-warm each 22 device sumchecks, 0 declines, each
  verified in a fresh process by the frozen review-r3 CPU binary (sha256
  `3a106486…`) expecting `53a5667decccbe4d…`.
- 8B: the R4-2 generic 8B T32 block fits (slot 18 = 2^19, 168 MiB of tables;
  t10 peaked at 3,125 MiB).

## 3. Seconds and bandwidth (TinyLlama T128, cube 2^20, k 21, D 5)

Plan figure: 72 B × 2^20 × 17 = 1.2835 GB per body.

| variant | body incl. build | rate | % of 256 GB/s |
|---|---|---|---|
| lean fused | 42.7 ms | 30.1 GB/s | 11.7% |
| lean unfused | ~43 ms | ~30 GB/s | ~11.6% |
| v2 fused (default) | 62.4 ms | 20.6 GB/s | 8.0% |
| v1 | ~64 ms | ~20 GB/s | ~7.9% |

Kernels only, lean: 29.8–33.1 ms (15–17%). On the code's own counted device
bytes (1,848 B/entry incl. build) lean is ~46 GB/s = 18%.

In the stack (s4, lean, median of blocks 1–21): 182 ms = build 34.4 + round 0
49.2 + fused rounds 92.8 + reduce/D2H/host 4.7 ms (2.7%). After a 300 ms
warm-up (s5): ~42 ms (build 8.6, round 0 12.1, fused 18.8, reduce 2.7).

End-to-end, 22-block stack, GPU arm, same session:

| quantity | slot 18 on CPU (s0) | slot 18 on device (s4) |
|---|---|---|
| slot-18 phase | 17.54 s | 8.11 s (2.16x; ~5.8 s steady excl. 2.3 s NVRTC compile) |
| sum of block walls | 134.42 s | 122.64 s (−8.8%) |
| prove_run | 135.27 s | 123.44 s |
| total CLI | 173.05 s | 158.54 s |

Per block steady: device body 182 ms + host extension round 80 ms. At warm
speed the host extension round would be ~63% of slot 18.

## 4. Why the bandwidth is low (isolated lean)

| part | launches | counted bytes | time | rate |
|---|---|---|---|---|
| table build | 20 + 16 MB pageable H2D | 528 MB + 16.8 MB | 8.6–12.9 ms | H2D and launches dominate |
| round 0 | 1 | 352 MB | 11.6 ms | 30 GB/s |
| fused rounds 1–5 | 5 | 1,024 MB | 13.3 ms | 77 GB/s |
| tail rounds 6–19 | 14 | ~33 MB | 3.2–3.5 ms | ~220–250 µs floor per launch |
| reduce + D2H + host | 20 rounds | ~2 KB | 2.7–3.3 ms | ~140–165 µs per round |

About 82 launches and 21 host syncs per sumcheck (launch overhead 1–2 ms, not
the problem). Folds run at 145–171 GB/s. Every round kernel: 255 registers per
thread, spills (v2 2.6/3.8 KB, lean 1.05/1.1 KB per thread), 2 blocks of 128
threads per SM = 8 of 48 warps. Arithmetic ~5.4e8 Goldilocks multiplications
per sumcheck (2–3 ms compute floor [MODEL]) against a 7.6 ms memory floor. The
card never left P4 (SM <= 1.2 GHz, memory 6,000 MHz); telemetry also showed P5
(300/810 MHz) at up to 73% utilization. The in-stack slowdown is not
transfers, launches, paging (4,076 MiB free) or CPU contention; it is DVFS
(the spin probe falls from 6.2–9.9 ms to 1.22 ms per launch within
100–200 ms of continuous work).

## 5. Verdict (plan §6 decision rule)

Achieved bandwidth = **11.7% of 256 GB/s** (lean, plan figure, table build
included; isolated and in-stack warm agree) [MEASURED]; default v2 8.0%.
**10–25% band: continue with kernel-design work before porting more slots.**
The cold 2.7% in the stack is power management: a slot-by-slot port on the
laptop delivers a fraction of the kernel speed until the GPU is busy
continuously (a GPU-resident prover) or its clocks are pinned. Recommendation:
make lean the default variant.

## 6. Resource record (peak VRAM, MiB)

t2 441, t3 441, t4 1,653, t5 125, **t6 7,123 (violation)**, t7 1,457, t9
3,393, t10 3,125, t11 481, t12 481, s0 3,105, s1 3,457, s4 3,105, s5 3,105.
t6 cause: the device buffer pool keeps up to 64 exact-length buffers with no
byte cap and the private-block path never drained it; fixed by drains in the
tests and `take_min` in the prover. Host peak RSS <= 2.41 GiB everywhere; t5
failed (transcript refusal) and proved nothing.

## 7. Next step (proposed)

One lane round on slot 18 only, existing gates as acceptance (t3 synthetic,
t10 trained equality + seeded gate, a stack + fresh verify; isolated ladder
and one stack with `HL_GZC_WARM_MS`):
1. **K1 term-group split kernel:** the 9 term groups each multiply by E0 or S
   and sum independently into the block reduction, one thread per (pair,
   group): ~40–64 registers, no spills, 4–6x more warps, ~9x shorter serial
   latency.
2. **K2 support table:** resident per process or generated on the device
   (removes the 16 MB pageable H2D per block).
3. **K3 reduction:** cross-block reduction folded into the round kernel, the
   96-byte result through pinned memory (one launch and one sync per round).
4. **K4 tail:** below 2^10 entries finish the rounds in one kernel or on the
   host.
Estimate [MODEL]: ~12–15 ms per body = 85–107 GB/s = 33–42%, i.e. the >= 25%
band; then schedule L3 (slots 14–17 plus the extension rounds) on the same
template. 5090 measurements should keep the GPU busy or pin clocks (Linux
persistence mode / application clocks; needs admin).
