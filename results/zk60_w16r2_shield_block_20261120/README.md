# The installed Shieldstral block on its own (W16R2_SHIELD_T128_H24), 2026-11-20

By the Claude co-coordinator. No source file changed. One block proved alone on the Metal GPU, production settings,
with the two profiles of the 2026-11-17 slot breakdown as controls.

**In one line: the installed Shieldstral block costs what the 8B block costs, about 94 ms of GPU, not the 174 ms that
several documents quoted for "Shieldstral".** The 174.25 ms belongs to the older R13 Shieldstral block.

## Why

`results/zk60_slot18_14_breakdown_20261117/` measured `W16R2_8B_T128_H24` and `R13_SHIELD_T128_H24`. Research ticks
11, 21, 22 and 26 then quoted the R13 block's figures as "Shieldstral", while the installed app has been W16R2 since
2026-11-13. Research tick 27 found the mismatch
(`research/zkp-efficiency/handoffs/20261120-claude-tick27-shieldstral-padding-stream.md`) and stated the two tests
run here, B1 and S1.

## Rule, posted in `ops/zkp-mvp/RECOVERY_COORDINATION.md` at 15:52:20Z before the run

- **Controls:** the 8B arm within 5% of 91.46 ms block GPU and the R13 Shieldstral arm within 5% of 174.25 ms;
  otherwise the session is not comparable.
- **B1:** commit A + commit H at W16R2 Shieldstral, median of the warm passes. At or below 31.9 ms: tick 27's bracket
  holds. Above 42 ms: the padding ceiling is above 5% of the stream cadence. In between: report and recompute.
- **S1:** table counts of slots 14 and 18 against 64 and 29 (R13 Shieldstral) and 36 and 19 (W16R2 8B). Close to the
  8B counts: the padded-pair figures of ticks 11 and 22 do not carry over to the app's profile.

**One deviation from the posted plan:** the two census leaves were not run. The census test takes its profile from
`registered_shapes()`, which lists `ACCURACY_PROFILES` only and does not accept a W16R2 name. The table counts are
read from the slot labels in the GPU trace instead, which the block test writes.

## Setup [MEASURED unless marked]

- Binary: the breakdown's reference `hashline-a90b6cf7715dc2a7`, SHA-256
  `aaaab7e6fd38af59d406f201f94cfdb0325a3fe6adb3a04332873580f3acad11` (checked before every leaf).
- Test `private_block::slot_ir::accuracy::tests::m4_trained_accuracy_block_cpu_and_metal_digests_and_times`, arm A of
  the breakdown: `HL_METAL_BATCH=1 HL_METAL_DEVICE_TABLES=1 HL_A27_LIN=1 HL_GPU_REQUIRED=1 HL_M4_WARM_PASSES=5
  HL_METAL_TIMING=1 HL_PB_TIMING=1`, GPU trace on. One cold and five warm passes per leaf; the CPU digest equals the
  Metal digest in every leaf.
- Four guarded leaves (class gpu, all exit 0, 6 to 9 s each), in this order: `4e4ca56fa6dc` (W16R2 Shieldstral),
  `6a08ef04f943` (8B control), `074ce2c3044b` (R13 Shieldstral control), `bd09e045f897` (W16R2 Shieldstral again).
  No `ds4-bench` before or after any leaf. Load average 2.3 before the first leaf, rising to 7.6 before the fourth
  (each leaf starts with a CPU proof and the gaps were 13 s).
- `analyze_block.py` computes per-pass sums from the traces. Applied to the two retained traces of 2026-11-17 it
  gives 91.462 and 174.249 ms, the reference totals, so today's figures are computed the same way. "Block GPU" is
  the pass total without the diagnostic records, as in the reference.
- Runner `run_block.py`; logs in `raw/`; traces outside the repository in
  `/Users/victorrielly/zk60-artifacts/w16r2_shield_block_20261120/`.

## Result (medians over five warm passes, ms)

| arm | block GPU | commit A | commit H | A + H | all slots | slot 18 | slot 14 |
|---|---|---|---|---|---|---|---|
| W16R2 Shieldstral, first | 94.06 | 14.44 | 13.61 | 28.72 | 65.67 | 21.28 | 15.52 |
| W16R2 Shieldstral, second | 98.98 | 18.98 | 13.60 | 32.60 | 65.91 | 21.28 | 15.53 |
| W16R2 8B, control today | 94.29 | 16.87 | 13.62 | 30.50 | 63.40 | 21.34 | 13.96 |
| W16R2 8B, 2026-11-17 | 91.46 | 13.99 | 13.90 | 28.18 | 63.30 | 21.34 | 14.01 |
| R13 Shieldstral, control today | 178.23 | 44.12 | 36.70 | 80.83 | 97.82 | 34.57 | 27.98 |
| R13 Shieldstral, 2026-11-17 | 174.25 | 39.48 | 36.72 | 76.21 | 97.78 | 34.75 | 27.95 |

- **Controls pass:** 8B +3.1%, R13 Shieldstral +2.3%. The slot sums and commit H agree with 2026-11-17 to within
  0.3 ms. All of today's excess is in commit A, which today sits near 13 ms in some passes and near 19 ms in others,
  in every arm including the controls (per-pass A + H: 26.7 to 33.0 ms at both W16R2 profiles).
- **B1: the bracket holds.** Commit A + H at W16R2 Shieldstral: 28.72 and 32.60 ms by arm, 28.95 ms over the ten
  passes pooled, against 30.50 ms for the 8B control in the same session. The second arm is 0.7 ms above the
  bracket's upper end, with the control showing the same slow commit A passes. The commit time at W16R2 Shieldstral
  is the 8B block's within today's noise (lowest passes 26.8 against 26.7 ms).
- **Padding ceiling recomputed [DERIVED]:** 26.96% of 28.95 ms is 7.8 ms per block, 0.203 s over 26 blocks, 4.6% of
  the Shieldstral stream cadence of 4.381 s per request (range over today's passes 4.3 to 5.3%). At the 5% line,
  as tick 27 estimated; and only if every padded row left the commitment.
- **Block GPU at W16R2 Shieldstral: 94 to 99 ms** (pooled median 94.7), inside tick 27's estimate of 88 to 95 ms at
  the lower arm. With commit A at its 2026-11-17 level it would be about 93.8 ms [DERIVED: 91.46 plus the slot
  difference].
- **S1: the app's block has the 8B block's slots, not the R13 block's.** Slot 14: 37 tables (24 base), 47 nodes,
  against 36 (23 base), 45 nodes at 8B and 64 (44 base), 83 nodes at R13 Shieldstral. Slot 18: 19 tables (11 base),
  23 nodes at both W16R2 profiles, 29 (18 base), 37 nodes at R13 Shieldstral. So the Shieldstral shares that ticks 11
  and 22 derived from the R13 slots (27.95 and 34.75 ms) do not carry over; the app's slots take 15.52 and 21.28 ms.
- **The one difference between the two W16R2 blocks is slot 14:** one more table, two more nodes and 1.56 ms more
  (15.52 against 13.96 ms). The D domain pads at Shieldstral (width 3,072 in 4,096 columns) and not at 8B, and tick
  26 counted one pad group there. That the 1.56 ms is the pad term is an inference from that count, not a
  measurement of the term.

## What this changes

- "Shieldstral block GPU 174.25 ms" and every share derived from it describe the R13 block. For the installed
  profile use about 94 ms, commit about 28 to 29 ms, slots about 65.7 ms.
- 26 blocks at 94 ms are 2.45 s of GPU per request, 56% of the measured stream cadence of 4.381 s (64% of the 3.839
  s with the checks deferred). The 8B harness stream is at 78%. The Shieldstral figure is from the 2026-11-13
  benchmark (`results/zk60_astra_20261026/a30a31_benchmark_review_20261113/REVIEW.json`), an older binary run through
  the app, so the two are not like for like; but it says the app's stream has more time outside the GPU per request
  than the harness stream, and it has not been measured again since A33.

## Not shown

- A Shieldstral stream on the current binary (the 4.381 s is from 2026-11-13).
- Trained weights: this is the block test's own fixture at the profile's shape.
- Why commit A has a slow mode; it is in the controls as well. See the addendum below: located, not explained.
- The unbatched arms B and C of the breakdown at this profile.

## Addendum, 2026-11-20 17:36 UTC: where commit A's slow mode sits [RECOMPUTED from the traces, no new run]

From the trace's five timestamps per record (begin, committed, GPU start, GPU end, done), over the eight batched
traces at hand (today's four and four of 2026-11-17: the two arm A traces and the knob traces tail250 and
tg256_th18), five warm passes each:

- **It is GPU execution time of commit A, and only of commit A.** Encode, queue wait and tail are the same in slow
  and fast passes (0.03, 0.1 to 0.9 and 0.15 ms). Script: `commit_a_mode.py` (reads the traces, runs nothing). Commit A's GPU interval is at least 15% above the fastest pass of
  its trace in 11 of 40 warm passes (17 to 67% above; at W16R2 about 13.2 ms fast and 15.5 to 21.8 ms slow). Commit H,
  the same kernel on about the same number of rows, is never slow: 0 of 40, largest ratio 1.08.
- **It is not new today.** The 2026-11-17 knob traces have it (13.1 to 21.8 ms); the 2026-11-17 arm A trace that
  gave the reference total happened to have five fast passes (13.1 to 14.7 ms), which is why today's controls read
  2 to 3% above it.
- **The GPU idle gap before the record does not decide it.** Commit A follows the longest gap of a pass (57 to
  88 ms at W16R2, the host building the witness). Over the 30 W16R2 passes the slow ones have somewhat longer gaps
  at the median (78 against 68 ms), but the ranges overlap completely: there are slow passes after 57 and 58 ms and
  fast ones after 85 and 87 ms. Commit H stays fast after gaps of 75 and 76 ms at R13. At most a weak factor.
- **Cause not determined.** What differs for commit A is that it is the first GPU work of a pass, on buffers the
  host has just written. Candidates, none tested: first use of freshly written or freshly allocated buffers, or
  host threads still running beside it.
- **Size [DERIVED]:** the mean excess of commit A over the fastest pass of its trace is 2.2 ms per block over the
  30 W16R2 passes, 2.3% of a 94 ms block. Whether the stream has it at all is not shown (there commit A overlaps
  other buffers and its span is dominated by sharing). Under the 5% line; not scheduled.
- **For measurement:** a block GPU total moves by up to 6 ms with the share of slow commit A passes. Compare the
  slot sums and commit H across sessions (they agree to 0.3 ms); read commit A as a range.
