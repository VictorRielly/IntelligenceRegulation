# 2026-11-03: Claude researcher cycle, rtx5090-projection-20261103

**Run.** Claude (standing researcher, D50), on the M3 Ultra Mac. Read-only analysis and arithmetic.
- No native build, proof or GPU run; no Git write.
- The heavy lock was held by the privacy-gate queue and was not touched.
- **One micro-benchmark:** a single-thread 218 MB byte scan (libc memchr, 3.6 ms median of 7, shared Mac).
- **Written only:** `experiments/rtx5090-projection-20261103/` (README, `model.py`, `model.out.txt`,
  `projection.json`), `handoffs/20261103-rtx5090-projection.md`, STATE.md, PROGRESS.md and this file.

## What completed

1. **An RTX 5090 projection for W16R2 (Q = 280) + D55**, one request, 8B T128, built from the measured Mac profile.
   - **Inputs:**
     - per-kind GPU attribution (`HL_METAL_TIMING`, attribution only);
     - the D55 N = 6 phase split;
     - Metal allocation per fork;
     - spec-sheet bandwidth, lanes and clocks;
     - the laptop's measured 4070 MAC probe.
   - **Proof only** [MODEL on ESTIMATE ranges]:
     - p10–p90 54–82 tok/s with today's serial head;
     - 69–117 with H122/H123;
     - a pessimistic corner of about 40.
     - Limiter: the per-fork host path, with VRAM capping the forks near 8.
2. **The witness found absent from the profile.**
   - **What was found.** In five A/B logs the test's total wall minus every timed part is 8.48–8.71 s per call. That is
     the 32-witness rebuild, about 0.27 s per 8B block [INFERRED].
   - **Why it adds.** D55's phase 1 needs every boundary plane before any fork.
   - **Under the target's clock:**
     - the Mac is about 9 tok/s;
     - a 5090 with today's witness code is 6–11;
     - with an exact GPU int8 forward it is 48–76 [MODEL].
3. **The open levers re-ranked**, with Mac and 5090 gains, byte status, ruling status and effort:
   - #2, #3, #4 and #5 from the 20261101 GPU-work table;
   - coefficient-form rows;
   - H112, H113 and H114.

   **Coefficient-form rows** pass the hiding argument in form: the pad block is independent of the message encoding,
   and the encoder is a bijection. They meet the δ/2 lemma's §7 condition. They change bytes, so they must join W16R2
   before registration or become a later profile.
4. **Hypotheses.**
   - H117–H121 adopted from the 20261101 handoff.
   - New: H122–H126.
   - H112 retired (subsumed by D55); H113 merged into H121.
   - 126 in total.

## What the evidence measures

- **[MEASURED]** inputs only:
  - Mac per-slot and commit attribution, and the D55 phases;
  - Metal allocation peaks;
  - the TinyLlama witness time on the laptop;
  - the byte scan.
- **The 5090 figures are [MODEL]** on [ESTIMATE] ranges. No 5090 exists in the project yet, and no CUDA port of
  W16/W16R2/D55 exists.
- **The witness cost is [INFERRED]** from walls, not a witness clock.

## Still unknown or blocked

- **The 5090 box:** its CPU, RAM and PCIe are undocumented.
- **NVIDIA's throughput table:** the cc 12.0 table could not be fetched, so the multiply factor rests on SM×GHz and the
  laptop probe.
- **Unmeasured on the Mac:** GPU-busy time under N = 6 (H121), host CPU-seconds per block, a direct witness clock and
  the preflight split.

## Next action

After the queue releases the heavy lock, the native owner should take four small, guarded measurements:
1. a direct `witness::build_accuracy` clock on one W16 8B T128 block, split into matmul and the rest;
2. a preflight sub-step timer;
3. getrusage CPU-s over a D55 forks phase;
4. per-fork MTLCommandBuffer timestamps.

Then the byte-identical H122 and H123 fixes, and a SIMD-int8 witness matmul with a witness-digest equality gate.

## Implication for ≥ 50 proved tokens/s (complete private 8B)

- The Mac tops out near 26–37 tok/s proof-only on every lever found, and about 9 under the target's clock today.
- A 5090 can plausibly reach 50 on the target's clock, but only with all of:
  - an exact fast witness forward;
  - the per-fork host work moved onto the device or kept under about 0.2 s;
  - per-fork streams.
- **Unachieved.** New full-stack proofs, passes and proved positions: **0 / 0 / 0**.
