# Research handoff: the split of commit_A + commit_H into NTT encode, hashing and gather, and a denominator error in the slot breakdown (2026-11-19 UTC, claude-tick 21, queue item 37)

From Claude, the standing researcher. Triage material, not a work order.

**Question.** Tick 19 bounded the dense-GEMM Reed-Solomon track (G3) by 1/(1 - f), f being the NTT-encode share of commit_A + commit_H, but the slot breakdown gives only the sum (23.8% of block GPU at W16R2_8B, 30.6% at the Shieldstral profile). What is f, and what does it bound?

**What was read and how.** Local only, no web. Full: the relevant parts of `gpu/metal.rs` (`commit_impl`, `encode_fused`, `encode_hash`, the `HL_METAL_TIMING` branch, lines 210 to 332 and 2056 to 2196), `analyze_slot_breakdown.py` (lines 100 to 190), `run_slot_breakdown.py` (the environment block), `ab_serve4_tail250.py` (line 79), the slot-breakdown `README.md` sections 1 to 2, `DEFERRED.md` entry 1; the six raw GPU trace files of the breakdown (`/Users/victorrielly/zk60-artifacts/slot18_14_traces_20261117/*.tsv.gz`, per command buffer: tag, detail, GPU start and end). Script: `20261119-claude-tick21-commit-split.py` (standard library; every DERIVED number comes from it). Labels: COUNTED (file), MEASURED (record), DERIVED (script or arithmetic shown).

## 0. Headline

1. **The split exists in the records, and f is about 0.86 to 0.87.** With `HL_METAL_TIMING=1` the commit code re-runs its three parts one by one on scratch buffers (`metal.rs:2148-2179`: inverse transform, forward transform, hash) and tags the command buffers `diag`. Warm-pass medians (5 passes, DERIVED from MEASURED): at W16R2_8B, inverse 4.11 + 4.19 ms (A, H), forward 6.90 + 7.13, hash 1.66 + 1.73; NTT share of the three parts **f = 0.868**. At Shieldstral: inverse 7.43 + 7.12, forward 25.14 + 24.11, hash 5.54 + 5.31; **f = 0.855**. Arms B and C agree to 0.01 (0.867 and 0.874 at 8B; 0.855 at Shieldstral).
2. **The breakdown's block total is inflated by those diagnostic re-runs.** The analyzer files every `diag` record under `other_diag_ms`, which the README calls "store fold with pads" (README 2.1: 25.660 ms, 21.9%; 74.631 ms, 30.0% at Shieldstral). It is not a fold: the trace has exactly three `diag` records after each commit (36 records for 12 commits; 8B Arm A) and their sum is 0.91 to 1.00 of the commit's own time. The diagnostic branch runs only when `HL_METAL_TIMING=1` (`metal.rs:2064`); the breakdown sets it (`run_slot_breakdown.py:215`) and the stream A/B sets it to 0 (`ab_serve4_tail250.py:79`). So the production block GPU is **91.46 ms at W16R2_8B (not 117.285) and 174.25 ms at Shieldstral (not 248.899)**; the README's 54.0% and 39.3% for the 12 sumcheck slots become 69.2% and 56.1% (DERIVED: 63.302 / 91.462, 97.784 / 174.249).
3. **Commit_A + commit_H is then 30.5% (8B) and 43.7% (Shieldstral) of block GPU, and the NTT in it is 26.5% and 37.4%.** The ceilings if the NTT cost nothing are x1.36 (8B) and x1.60 (Shieldstral) on block GPU, to be discounted by how GPU-bound the stream is (see section 3). Tick 19's x1.31 and x1.44 used the inflated denominator and the commit sum rather than its NTT part; they were bounds of the wrong size in both directions.

## 1. The numbers (MEASURED medians of warm passes; ms per block; script output)

| | 8B A | 8B H | Shield A | Shield H |
|---|---:|---:|---:|---:|
| Commit as one command buffer | 13.987 | 13.900 | 39.481 | 36.718 |
| Diag: inverse transform (rows x 2^14, scaled) | 4.110 | 4.187 | 7.427 | 7.117 |
| Diag: forward transform (2^14 to 2^15 or 2^16) | 6.897 | 7.132 | 25.138 | 24.114 |
| Diag: hash (old one-thread-per-column `k_hash_cols`) | 1.660 | 1.727 | 5.535 | 5.311 |
| Diag sum over commit | 0.91 | 0.94 | 0.97 | 1.00 |

Rows: 2,504 (A) and 2,606 (H) at 8B with `log_n = 14, log_nn = 15`; 4,577 and 4,390 at Shieldstral with `log_nn = 16` (trace `detail` field). The gather is 0.18 ms (8B) and 0.25 ms (Shieldstral) per block, 0.2% and 0.1% (README 2.1): negligible.

Block GPU without the diag records (DERIVED): Arm A 91.462 and 174.249 ms; the diag records are 25.660 and 74.631 ms (21.9% and 30.0%; Arm B 25.8% and 32.3%, Arm C 26.2% and 27.3%).

## 2. How close the NTT kernels are to a traffic floor (DERIVED; a model, not a measurement)

Counting bytes of the two-pass fused design (`encode_fused`: head reads rows x 2^14 words at most and writes the tile, tail reads and writes once; `TILE_LOG = 11`, so 2^14 and 2^15 or 2^16 both need head and tail) and dividing by the 700 GB/s copy roofline of K0: 8B A inverse 1.88 ms, forward 3.28 ms, hash read 0.94 ms; Shieldstral A (4,577 rows) 3.43, 11.14, 3.43 ms. Measured over that floor: inverse 2.2x, forward 2.1x (8B) and 2.3x (Shieldstral); the old diag hash form 1.8x and 1.6x. Whole NTT of A and H: 22.3 ms measured against 10.5 ms floor at 8B (2.12x), 63.8 against 28.5 ms at Shieldstral (2.24x).

Reading: the A27 radix-4 and A28 pruned head and two-pass hash are in and the design is already a two-sweep one, so the 2x above the floor is arithmetic (a field multiply per butterfly at about 0.9 us per base multiplication in the sumcheck census of tick 15, though NTT twiddles are base-field) plus occupancy, not a third pass over memory. A kernel that reached the floor would save 11.8 ms (12.9% of 91.46, x1.15) at 8B and 35.3 ms (20.2% of 174.25, x1.25) at Shieldstral. Those are limits, not estimates: nothing in this reading says a kernel can get there.

## 3. What this means for the tracks, and the honest effect

- **H117b (coefficient-form rows, deferred 2026-11-03)** drops exactly the inverse transform: 8.30 ms per block at 8B (9.1% of 91.46, x1.10) and 14.54 ms at Shieldstral (8.3%, x1.09), DERIVED. The deferral note's "about 5 ms of 25 ms" and "x1.09" stand within a few percent of this on block GPU; the x1.10 is a block-GPU figure and the stream is not wholly GPU-bound (tick 16: the two-lane stream hides part of what it saves), so on cadence expect less. It changes every commitment root and receipt byte (DEFERRED.md), so nothing here reopens the ruling; the number is more precise material.
- **G3 (dense GEMM encoder).** The forward transform is 14.03 ms (8B) and 49.25 ms (Shieldstral) per block, 15.3% and 28.3% of production block GPU. A dense RS encode multiplies by an NxN-ish Vandermonde block, `>100x` the MACs of an NTT as the track states; on the 8B shape a forward row has 2^14 inputs to 2^15 outputs, so the dense MACs per row are 2^29 against 2^15 / 2 x 15 = 2.5e5 butterflies: about 2,000x the arithmetic. Tick 19's finding that Apple GPUs here have no integer matrix type (half or float accumulators give N <= 258) stands. A 2,000x increase on a kernel already 2.1x over its traffic floor cannot pay on this hardware by arithmetic alone; a matrix-NTT split (sqrt N by sqrt N) would be the only form to test and it is not a commitment change, but it also has no measured basis here. G3 stays unscheduled.
- **Hash.** 1.7 ms per commit at 8B and 5.4 ms at Shieldstral in the diag (old form). Production uses the two-pass hash (A28: 5.47 to 4.23 ms at the classifier A shape [A28 bench record cited in `metal.rs:241`]); the hash is 7 to 13% of a commit and not a lever.
- **Effect on committed words per request:** 0 (no protocol change is proposed). **On proved tokens per second:** none proposed; the corrected denominator raises every earlier tick's block-GPU share by the factor 1.28 (8B) or 1.43 (Shieldstral) (see 4).

## 4. Consequences for earlier ticks (DERIVED; stated, not redone)

Shares of block GPU quoted in ticks 11, 12, 14, 15, 16, 17, 20 and the K0/K1 note used 117.285 and 248.899 as denominators. Production denominators are 91.462 and 174.249: multiply a share by 1.282 (8B) or 1.428 (Shieldstral). Examples: tick 20's plain two-table share 1.93% batched becomes 2.47% at 8B (still under the 5% rule; the G1 decision stands); tick 11's padded-pair skip "4 to 7% of Shieldstral block GPU" becomes 5.7 to 10.0%; tick 16's tail 4.7 to 20.5% solo at 8B becomes 6.0 to 26.3%. Millisecond figures and ratios between slots are unaffected. Rules that were decided at a threshold (G1 under 5%; the "no kernel idea above a few percent" statement) need a recheck against the corrected shares: item 38 in the queue.

## 5. A falsifiable test (local, cheap)

**T1 (CPU-free, reading only).** In the production stream (`HL_METAL_TIMING=0`) the commit command buffer's `gpuEndTime - gpuStartTime` should match this table's "Commit as one command buffer" row. The 8B and Shieldstral traces for the A/B stream (`ab_serve4_tail250`) were not externalized as GPU traces, so this cannot be checked from the records; if a 4-pass trace with `HL_A27_GPU_TRACE` and `HL_METAL_TIMING=0` exists or is made, pass is the commit row within 5% and no `diag` records. Fail would mean timing mode changes the commit itself.

## 6. Risks and what was not verified

- The diag parts differ from the production commit: forward is `MODE_PLAIN` (production is the keyed coset `MODE_ZK` with 280 or 256 pad columns), hash is the old `k_hash_cols` form, and the three parts are separate command buffers; so their sum is 0.91 to 1.00 of the commit and f is a ratio of re-run parts, not of the production kernels' own time. If the production hash is faster by the A28 ratio (about 0.77), f rises to about 0.88; if ZK mode adds forward work, f is similar or higher.
- The production total of 91.46 and 174.25 ms assumes diag records are the only addition of timing mode. Nothing else in `metal.rs` is gated on `HL_METAL_TIMING` that I found by grep, but I did not read every branch; the commit's own time is the same one-buffer measurement in both modes by construction, which T1 would confirm.
- Traffic floors use the 700 GB/s copy roofline of K0 (one clean run) and my byte count of the two passes; the head read of the pruned forward is counted as 2^14 words, the tail as one read and one write.
- No web research this tick (the item is a local count); the dense-GEMM arithmetic uses tick 19's reading of TensorZKP and is not independently checked.
- Any change here (H117b, an encoder change) alters commitment roots and needs the owner's ruling, a new profile version and re-proving in Lean. The 2026-11-09 shelving of size work stands.
