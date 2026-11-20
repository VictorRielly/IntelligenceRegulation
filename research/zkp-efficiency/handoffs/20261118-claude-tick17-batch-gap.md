# Research handoff: where the fixed ~0.8 ms per batched slot sits, a real cost or a difference between the two arms (2026-11-18 UTC, claude-tick 17, queue item 34)

From Claude, the standing researcher. Triage material, not a work order.

**Question.** Arm A (production, batched) minus Arm B (one command buffer per round) is 0.7 to 1.2 ms at slots whose rounds cost 0.02 ms, about 9 to 10 ms per block over 12 slots (tick 16). What does each arm's GPU interval contain, so the gap is a real batching cost or a measurement difference; what could remove it?

**What was read and how.** Local only, no web, nothing run. Full: `results/zk60_slot18_14_breakdown_20261117/` `summary.json`, `knob_probe.json`, `README.md`, `analyze_slot_breakdown.py` (how each arm's total is summed), `run_slot_breakdown.py` (the arm environments). Code: `ops/zkp-mvp/gpu-metal/hashline/src/gpu/metal.rs` lines 725-746, 886-933 (`run_tagged`, `gpu_times`, `tl_record`), 3190-3258 (`TabBuild::encode`, `run_tagged_pre`), 3517-3647 (the unbatched `round` and `fold`), 3673-3683, 3864-4129 (`batched_rounds`, `batched_round_count`); `metal_kernels.metal` 944-1131 (`k_sc_fs_step`, `k_fold_tables_dev`, `k_sc_part_reduce`). Script: `20261118-claude-tick17-batch-gap.py` (standard library; prints the tables below). Labels: MEASURED (record), COUNTED (file:line), DERIVED (arithmetic), ASSUMED.

## 1. What each arm's GPU interval contains (COUNTED)

Both arms report `GPUEndTime - GPUStartTime` of each completed command buffer (`gpu_times` 886-894; the analysis sums those intervals, `analyze_slot_breakdown.py` 108-113). Host time between command buffers is in neither total.

- **Arm A, one `batch` command buffer per slot** (`run_tagged_pre` 3235-3257, `batched_rounds` 4029-4085): a concurrent table-build encoder when the slot has a deferred build, then one serial encoder holding the whole sumcheck. Per round: fold of the previous round by the DEVICE's challenge (`k_fold_tables_dev3`, plus `encode_xfold` when m > 0), the round kernel, `k_sc_part_reduce` when nthreads > 4,096 (4065-4070), and **`k_sc_fs_step`**, one threadgroup of up to 256 threads (4081). That kernel reduces the partials point by point (d1 sequential passes, each a strided load plus an 8-level tree with barriers, 986-1003), then thread 0 alone does the CFS mask arithmetic, two keyed BLAKE3 hashes through byte arrays (`fs_absorb_round`, `fs_challenge`), the extension of the round message and the claim interpolation (1004-1069).
- **Arm B, one command buffer per round** (`HL_METAL_BATCH=0`, tables `sync`): a separate `tables` command buffer; then per round one `round` command buffer holding the previous fold, the round kernel only (3537-3565); the final fold in its own `fold` command buffer (3630). The partials are read back and summed on the HOST (3576-3597) and the Fiat-Shamir step runs on the host. **None of that is in B's GPU interval**: no transcript step, no reduce kernel, no inter-buffer gap.
- **Other differences:** B's unbatched budget is 250 microseconds (3676) against A's 25, so A runs 2 to 4 more device rounds per slot (my count from the per-round entries against `nd`: 3 at 8 of 12 slots, 2 at two, 4 at two). Each B command buffer's start-to-end interval counts any per-buffer ramp once per round, A once per slot, which biases the gap the other way.

So the gap is not a pure measurement artefact and not a pure batching cost: it is device work (transcript step, reduction) that A puts inside the interval and B does outside it, plus A's extra rounds.

## 2. Splitting the gap (MEASURED sums by me, DERIVED where marked)

- **W16R2_8B, 12 slots:** gap 18.54 ms (sum of per-slot medians; 18.42 on the README's all-slot medians). **7.12 ms is the extra rounds** (36 rounds, knob 250: all-slot GPU 63.302 to 56.183, same digest) [MEASURED]. **The other 11.30 ms is the gap at equal round count** (56.183 against B's 44.887) [DERIVED]; equal `nd` is verified for slots 18 and 14 only (14 and 12 in both arms), assumed elsewhere. That 11.30 ms is 9.6% of the 117.285 ms block GPU, 0.94 ms per slot.
- **Shieldstral:** gap 18.71 ms (7.5% of 248.899); the knob probe was not run there, so the split is EXTRAPOLATED: about 6.3 ms extra rounds (tick 16's 0.198 ms per round x 32), about 12.4 ms (5.0%) at equal rounds.
- **It is not a constant per batch.** Remove the extra rounds at B's own tail-round time (last three B medians): the residual is 0.6 to 2.35 ms across the 12 slots (8B) and 0.64 to 2.46 ms (Shieldstral), growing with slot size. Per A round the residual is 0.100 to 0.121 ms at the degree-3 and degree-4 slots (nine slots), 0.061 to 0.073 at the two degree-2 slots (21, 22), 0.138 (8B) and 0.145 (Shield) at the one degree-5 slot (18) [DERIVED; the table is the script's output]. Through the origin the rate is 0.106 ms per A round (8B), 0.111 (Shield). The order follows d1, which is what the transcript step's per-point loop predicts. A line with an intercept gives -0.79 + 0.174 x nd (rmse 0.15 ms): a negative intercept, so no positive fixed cost per batch is supported, and the big slots cost more per round than the small ones, as expected if `k_sc_fs_step` reads up to 4,096 partials per point serially in its 256 threads (16 loads each, count is PART_RED_WIDTH or nthreads, 4065-4073) [DERIVED from the code; no timing of the kernel exists].
- **Corroboration that this is relocated work, not waste** [MEASURED, summary.json]: the harness's "device sumcheck rounds" wall per block is 72 ms in A against 89 ms in B (8B), 105 against 121 (Shield), and the prove core 0.327 against 0.360 s (8B), although A's GPU interval is 18 ms longer and A carries 36 more device rounds. B spends at least 89 - 44.9 = 44 ms outside its GPU intervals, A 72 - 63.3 = 8.7 ms (DERIVED; assumes that counter covers device rounds only, not read to the end). So batching wins wall time over B and the interval gap is mostly the price of doing the transcript on the device.

## 3. Findings that do not fit (reported, not smoothed)

- Slots 21 and 22 have the same shape (3 tables, degree 2, pre=3); A is 1.136 ms at nd = 10 and 1.123 ms at nd = 9. One round of difference shows 0.013 ms, against the 0.06 to 0.07 per round the per-round reading predicts, and their B table builds differ by 0.05 ms. This pair favours a larger fixed part; one pair, single run, medians of 5 warm passes.
- The knob probe is inconsistent with a flat per-round cost: slot 18 saves 0.80 ms for rounds 14 to 16 (0.27 each) but only 0.093 ms for round 13; slot 14 saves 1.04 ms (0.35 each) then 0.087 ms (single runs per setting, slot spread about 0.03 ms). A flat round cost cannot be both, and I cannot say why from the records (candidates: the extra rounds' time includes something at the end of the command buffer, or clock/latency effects of very small dependent dispatches).
- So the split between "per round" and "per batch" is **not settled**. The sign of the evidence is per round (degree order, negative intercept, the big slots), with one contrary pair.

## 4. What could remove it (protocol-neutral; same transcript bytes; a prover change for the owner)

- **R1, a faster transcript step.** Run the d1 point reductions concurrently (one simdgroup per point, `simd_sum`-style, no threadgroup tree: about 10 barriers instead of about 50 at d1 = 5), and let the round kernel reduce within its threadgroups so the step reads far fewer than 4,096 partials; this also drops the `k_sc_part_reduce` dispatch in the early rounds. The serial hash and extension part of thread 0 stays.
- **R2, the extra rounds** are the knob (7.1 ms solo): already priced as flat in the stream (tick 16).
- Neither changes committed words, the transcript, the verifier or Lean (the host replay at 4156-4171 stays).

## 5. Falsifiable tests (the coordinator schedules; I run nothing)

- **K9, the micro-benchmark that settles per round against per batch.** One command buffer repeating `k_sc_fs_step` 1,000 times on a captured partials buffer, at count 4,096, 512 and 32 and d1 = 3, 4 and 5; and the same for `k_sc_part_reduce` at nthreads 32,768. Pass for "per round, kernel project worthwhile": `k_sc_fs_step` at count 4,096 and d1 = 5 costs >= 0.06 ms; fail: <= 0.02 ms, and the equal-nd 11.3 ms is a fixed batch cost (encoder transition, table-build prelude) to chase with timestamps instead. About 5 seconds of GPU.
- **T1 (tick 16) extended:** sweep `HL_METAL_BATCH_TAIL_US` over {25, 250, 1000, 5000, 20000} so nd falls to 2 or 3 at the small slots, and fit A(nd) = a + f nd per slot from the trace. Pass for per-round: intercept <= 0.3 ms at slots 0, 1, 21 and 22 and f >= 0.06 for d1 >= 4. Fail: intercept >= 0.7 ms.

## 6. Honest expected effect

- **Committed words per request:** none. **Proved tokens per second:** the equal-round part is 11.3 ms solo per block (9.6% of block GPU at 8B, about 5% at Shieldstral, extrapolated), 0.36 s per request at 32 blocks. If the stream hides it like the tail (64 to 77%; ASSUMED, the step is a one-threadgroup low-occupancy kernel like the tail rounds), at most 83 to 130 ms per request (2.2 to 3.5% of the 3.7455 s cadence) if the cost vanished, and a halving about 1 to 1.7%. Realistic **x1.01 to x1.02 on cadence**, ceiling x1.03 to x1.04; it adds to tick 16's tail estimate only partly, because both are one-threadgroup latency chains the other lane fills.
- **Corrections:** tick 16's "about 0.8 ms per batch of fixed cost" should read "about 0.94 ms per slot at equal rounds, mostly per round (about 0.1 ms, scaling with degree), device work that the unbatched arm does on the host". The README's "+18.4 ms M6 gap" is 39% extra rounds (7.1 ms) and 61% (11.3 ms) this.

## 7. Risks and what was not verified

- No kernel timing exists for `k_sc_fs_step` or `k_sc_part_reduce`; every "per round" figure is a regression on medians, 12 slots, one run per arm. The slot 21 and 22 pair and the knob probe's 3-against-1 round discrepancy contradict a flat per-round model.
- I did not read the ISA or check what `GPUStartTime` includes at command-buffer launch.
- Equal `nd` between A at 250 and B is checked for two slots only.
- That the harness's "device sumcheck rounds" counter covers only the device rounds was inferred from `SC_ROUND_NS` additions (3607, 3642, 4099), not traced through the host-tail path.
- The Shieldstral split, the stream hiding ratio for this item, and R1's gain are extrapolations or untested. Any kernel change moves no byte of the proof but is a prover change; the coordinator decides.
