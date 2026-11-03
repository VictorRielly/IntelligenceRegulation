# Research handoff: an RTX 5090 projection for W16R2 + D55, and what limits it (2026-11-03)

From Claude, the standing researcher (D50).

**Scope.**
- **Read and arithmetic only.** No build, proof, GPU run or Git write. One 0.03 s single-thread byte scan.
- **Experiment:** `experiments/rtx5090-projection-20261103/`. The README holds the tables, `model.py` every input and
  range, and `model.out.txt` the output.
- **Builds on:** `20261101-gpu-work-per-block.md` (its table #1–#15), `20261101-logup-gkr-w16.md` (H111–H116) and
  `20261101-delta-half-lemma-check.md` (the bijection condition).

Labels: [MEASURED], [INFERRED] (derived from measured walls, not a clock of the thing), [MODEL], [ESTIMATE].

## 1. The projection: one request, 8B T128, W16R2 at Q = 280 + D55, one RTX 5090

**Proof-only clock**, the same clock as the Mac's 22.9: witnesses are built before the timer.

| | tok/s | Limiter |
|---|---|---|
| Pessimistic straight port (Metal-like single queue, host-built tables, slow desktop host, N = 6) | **~40** [MODEL] | GPU kernels, 74 ms/block |
| Monte Carlo over every range, per-fork streams, today's serial head | p10–p90 **54–82** (p50 68) [MODEL on ESTIMATE ranges] | the per-fork host path in 75% of draws |
| Central (8 forks, tables built on device) | **76** | per-fork host path |
| The same with the serial head fixed (H122, H123: byte-identical) | p10–p90 **69–117**; central **108** | per-fork host path |

**Target clock** (witness work included, as `ZK60_THROUGHPUT_TARGET.md` requires):

| Witness | tok/s | Limiter |
|---|---|---|
| Today's CPU witness code | **6–11** [MODEL on INFERRED] | the witness forward chain |
| Exact SIMD-int8 CPU forward | 32–47 | |
| Exact GPU forward (int8 tensor-core products on two int8 limbs of each int16 activation) | **48–76**, P(≥ 50) ≈ 0.86 | |

**The Mac under the same clock:** about **9 tok/s** for one request [INFERRED]: 8.6 s of witness plus the 5.54 s
proof.

**Why the witness counts.** The D55 A/B harness rebuilds the 32 witnesses on 8 threads before every timed call.
- The test's total wall minus every timed part is 8.48–8.71 s per call, in all five logs read [INFERRED], which is
  0.27 s per 8B block.
- The laptop's MEASURED TinyLlama T128 witness was 0.607 s per block on 16 threads, and TinyLlama has about a fifth of
  the 8B block's multiply-adds.
- `witness.rs:455-480` does scalar i32 products widened to i64 per term.
- D55's phase 1 asks for every boundary plane before any fork (`run_fork.rs:1092-1112`), so the forward chain is a
  serial prefix of one request. Overlap cannot hide it.

**Assumptions.**
1. The CUDA port reaches the Metal kernels' fraction of each roof.
2. Goldilocks multiply ×4–8. The Mac does 149 G/s; the 4070 Laptop's 64×64→128 probe did 156.5 G/s; SM×GHz is
   ×5.7–7.6.
3. DRAM ×1.9–2.2.
4. VRAM caps the fork count near 8. The Mac peaked at 3.3–3.5 GB per fork.
5. Each fork's host path is about 0.21 s of mostly one-thread work per block, at Mac speed (diagonal test weights; dense
   adds about 15 ms).
6. The 5090 box's CPU, RAM and PCIe are **undocumented**. They enter only as ranges: 0.7–1.1× per core, 12–28 cores,
   60–300 GB/s.

**Falsifiers on the real box.**
1. The M18 multiply harness, ported, gives under 0.6 T Goldilocks mul/s.
2. Slot 18 at the W16R2 shape takes more than 8 ms of device time.
3. Proof only at N = 8, all device phases ported with per-fork streams: under 40 tok/s.
4. The GPU is busy over 70% of the forks phase while tok/s stays under 80. That refutes "host path limits".
5. A per-fork host path above 0.3 s per block, which means host-bound below about 60.

## 2. The levers re-ranked

×-figures are [MODEL]:
- **Mac:** one request, GPU-bound, N = 6, from 23.1.
- **5090 C:** the central case, proof only, with the head fixed, or with today's head where that is the column that
  matters.

| Rank | Lever | Bytes | Ruling | Effort | Mac | 5090 |
|---:|---|---|---|---:|---:|---:|
| 1 | H124 witness: exact SIMD/GPU forward chain, expansion inside the forks | preserved | no | 3–12 d | target clock ×2 (9 → 18–19) | target clock 6–11 → 48–76 |
| 2 | H122 preflight once per resident model or in parallel | preserved | no | 0.5–1 d | ×1.06 | ×1.22 |
| 3 | H125 host path on the device (tables, store and weight folds, Merkle, planes) | preserved | no | in the port, 15–30 d | ×1.00 | ×1.05–1.19 |
| 4 | H121 per-fork queues / streams + GPU timestamps (absorbs H113's remainder) | preserved | no | 1–3 d | ×1.0–1.25 | built into the "streams" regime |
| 5 | H123 boundary commits in parallel | preserved | no | 1–2 d | ×1.03 | ×1.10 |
| 6 | Coefficient-form rows | **changes** | **yes** | 4–7 d + gates | **×1.09** | ×1.01 |
| 7 | #2 zero-check kernels (shared per-point loads first) | preserved | no | 5–10 d | ×1.02–1.11 | ×1.00–1.01 |
| 8 | #3 equal-size zero-check batching | changes | yes | 10–20 d | ×1.03–1.08 | ×1.02–1.03, and −28% core bytes |
| 9 | #4 non-power-of-two F | changes | yes | 10–15 d | ×1.04 | ×1.01 |
| 10 | H114 helper inverses by gather | preserved | no | 2–3 d | ×1.00 | ×1.01–1.02 |
| 11 | #5 pruned coset NTT (−0.7 ms at rate 1/2) | preserved | no | 1–2 d | ×1.01 | ×1.00, drop |
| — | H112 | — | — | — | **subsumed by D55** (N = 6 > (H + G)/G ≈ 2.9) | becomes H125 / H126 |
| — | H113 | — | — | — | M6 took 0.21 → 0.025 ms per round; the remaining latency share (about 33 of 109 ms) is hidden only by overlapping submissions (H121) | |

**The two-device reading.**
- On the Mac the GPU limits, so the GPU-kernel and commitment levers are what move it. Proof-only, the byte-preserving
  levers (#2, H122, H123) bring it to about 26–28 tok/s, or up to about 35 if H121 recovers the whole queue gap.
  Adding the byte-changing levers (coefficient form, #3, #4) gives about 31–37 [MODEL]. The Mac does not reach 50.
- On a 5090 the central case is host-path-limited. The kernel levers then fall to 0–3%, and moving host work onto the
  device is what pays.
- **M5a's "no gain" for device plane gather was measured on unified memory and does not transfer to the 5090.**

**Coefficient-form rows.**
- **Hiding is allowed in form.** The pad term Z_n(η)g(η) is a nonzero diagonal times a Vandermonde block, onto F^s,
  independent of the message encoding. The clear vector's message half is still ρᵀD. The encoder is still a bijection
  onto degree < n + Q.
- **Soundness.** It is the δ/2 lemma's §7 condition, and that condition holds.
- **It changes every root and receipt byte.** It must either join W16R2 before registration, sharing the Q = 280
  branch's gate cycle, or wait for a W16R3 string and a second full D54 and privacy-gate cycle.
- **Time-sensitive.** The Q = 280 branch is open now. This is for Victor, not for the researcher to decide.

## 3. New hypotheses

- **H122.** The serial per-request preflight is 0.377 s. It scans 7 GB of i8 weights with `contains`
  (`private_block.rs:859-861`), one block after another.
- **H123.** The serial D55 commit phase is 0.226 s for 31 boundaries.
- **H124.** The witness forward chain is a serial prefix outside every clock (§1).
- **H125.** The 5090's per-fork host path against VRAM-capped forks: N ≥ (H + G)/G ≈ 7–12.5 is needed, and VRAM allows
  about 8.
- **H126.** On the 5090, one request prefers T128: T256 models at 65.6 against 107.9 tok/s, because VRAM halves the
  forks. Many requests are bounded by the GPU and the host cores, and today's witness code caps the aggregate at 7–30
  tok/s.

Each hypothesis's falsifier is in the README §6.

## 4. Implementation seams and obligations

- **H124**
  - **Seam:** `witness.rs::matmul` / `matmul_in_out` (SIMD int8 dot products on two limbs; exact, since
    |x_lo·w| summed over K ≤ 14,336 is < 2^31) and a new exact forward that returns only the layer outputs, which feed
    `RunWitnessSource::boundary_plane`. `Witness` expansion then runs per fork in `ForkCtx::prove_one`.
  - **Gate:** witness digests equal `build_accuracy`'s at every W16, W16R2 and R13 shape, plus CS-3's refusals.
- **H122**
  - **Seam:** `run_fork.rs::preflight` and `run.rs`'s D12a twin, plus `BlockPublic::check_accuracy_for_shape`.
  - **Change:** chunked parallel scans (M8's pattern), or a check-once flag on an immutable resident block set whose
    digest the statement already binds.
  - **Gate:** the same refusals, and the D60 preflight controls (F1).
- **H123**
  - **Seam:** `prove_forks_inner`'s phase 1: draw `rng0`'s pads in today's order, then run `boundary::prepare`
    concurrently.
  - **Gate:** byte identity under the seeded tests, and the D55 18/18.
- **H121**
  - **Seam:** `gpu/metal.rs` `Ctx::queue` becomes one queue per fork thread, and GPU timestamps are read per command
    buffer.
  - **Gate:** byte identity. No ruling.
- **Coefficient form.** Needs a ruling. Before any receipt:
  - the encoder flag in `encode_row_zk`, `encode_buffer` and the Metal head;
  - PG-R2, the Python rank lemma and the run-level joint rank re-run;
  - the D59 controls.
- **Proof and privacy obligations.** None is added by H121–H126, which move no transcript byte. A faster witness must be
  bit-exact, and the privacy gates are unaffected.

## 5. Next concrete experiments (Mac, after the heavy lock frees; each small, guarded)

1. A direct witness clock: one W16 8B T128 `build_accuracy`, warm, n ≥ 3, split into matmul and the rest. This decides
   H124's size.
2. A preflight sub-step timer (H122).
3. getrusage CPU-seconds over a D55 N = 6 forks phase (H125's input).
4. MTLCommandBuffer GPU timestamps per fork at N = 6 (H121).
5. Then the 0.5-day H122 fix and the 1–2-day H123 fix, which are byte-identical: Mac about 23 → 25.5 tok/s proof-only
   [MODEL].

## Status

- New full-stack proofs, passes and proved positions: **0 / 0 / 0**.
- The complete private 8B at ≥ 50 proved tokens/s remains **unachieved**.
- On this model, a 5090 reaches it only with a fast exact witness forward **and** the CUDA port's host work moved onto
  the device or kept under about 0.2 s per fork-block.
