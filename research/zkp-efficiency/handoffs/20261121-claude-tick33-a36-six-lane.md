# Research handoff: why A36 helped at one lane and slowed the lanes-full stream (2026-11-21, claude-tick 33, queue item 54)

From Claude, the background researcher. One bounded cycle; local reading and arithmetic only (no web, no run, no build, no Git). **Triage material, not a work order;** nothing here changes a committed word, proof byte or the verifier.

**Read:** the A36 README (`results/zk60_a36_core_ahead_20261121/README.md`, sections 1 to 13, in full); `raw/t1/t1_results.json`, `raw/t2_setA` and `raw/t2_setB/t2_results.json` (per-request `prove_s`, `served_s`, completion times, per-leg mean ioreg utilisation), `t2_driver.py`, `metal.rs:750-850`; ticks 30 to 32; Astra's `REVIEW.md`. Script `20261121-claude-tick33-a36-six-lane.py` (standard library, `-I`) prints every DERIVED number. Labels: MEASURED, CODE-READ, DERIVED, MODEL, ASSUMED.

## 0. Headline

1. **The retained records cannot say whether the extra time sits in device waits or host phases:** no buffer trace or `HL_PB_TIMING` exists for any six-lane leg, and S1 is one lane with the switch off. They do show a **cross-lane** effect: the sealing pass, which A36 does not touch, is about 7% slower with A36 on in both sets.
2. **The ioreg utilisation cannot decide "device-paced":** it reads about 65% while one lane proves (solo block GPU is 22% of that period) and is pinned at 85 to 90% in all eight legs at six and eight lanes.
3. **From solo GPU time alone, the off stream runs at 83% (six lanes) and 87% (eight) of the rate the device would allow with no overlap** (section 1): near a device bound, not shown saturated.
4. **A36's six-lane loss is 80 ms a block for about 60 ms of work moved;** one lane saved 16.7 ms. That excess (139 ms beyond perfect overlap) is more than a short concurrent window can explain alone.
5. **One added measurement decides it:** the Metal buffer trace on one off and one on six-lane leg under T2's own environment (section 2). Not scheduled.

## 1. (a) Is the six-lane stream paced by the device?

MEASURED (means of each arm's two legs; seconds). "Outside" is `served_s - prove_s`.

| fixture | A36 | prove call | outside | lane period | rate tok/s |
|---|---|---:|---:|---:|---:|
| 1 lane | off / on | 8.921 / 8.487 | 2.303 / 2.336 | | |
| 6 x 5 | off / on | 14.470 / 16.545 | 3.024 / 3.234 | 17.68 / 19.99 | 43.43 / 38.43 |
| 8 x 4 | off / on | 18.657 / 19.523 | 3.763 / 4.021 | 22.65 / 23.76 | 45.25 / 43.10 |

The period exceeds the served time by only 0.19 to 0.21 s per lane at six lanes (never idle between requests), so time cut from a lane's serial path is one-for-one in the period if the stretch does not change.

**The meter.** One lane: 64 to 65% (off), 70 to 71% (on), samples at or above 40%. Six and eight lanes: 85.4 to 90.3% in all legs. Mean times leg wall gives 2.55 (off) to 3.06 (on) busy-seconds a request, but the on legs are only longer legs (wall x1.157, meter x1.029), so I do **not** infer extra device-busy time from A36.

**A bound that avoids the meter** (DERIVED): solo block GPU 94.679 ms (pooled median, `zk60_w16r2_shield_block_20261120`) x 26 = 2.462 s a request (3.0 s with tick 30's sealing products, an upper figure). With no overlap between lanes the six-lane period is at least 6D = 14.8 s (18.0 s with products) against 17.68 s measured: 83% (proving only). Rate form: 128 / D = 52.0 tok/s against 43.4 (six lanes), 45.3 (eight), 38.4 (A36 on, 74%). With tick 30's shared-queue union-to-sum ratio 0.79 (ASSUMED to carry) the device is 66 to 80% busy. **Device-paced is neither shown nor excluded;** the overlap factor at T2 is unmeasured.

## 2. (b) Which resource the extra task contends for

**Cross-lane evidence.** Outside-prove time with A36 on: one lane x1.01, six lanes **x1.069** (6.8 and 7.0% in the two pairs), eight lanes **x1.069** (6.3 and 7.4%). The seal-ahead switch is off in this fixture, so a lane's sealing never overlaps its own proving: the slowdown of unchanged code comes from other lanes. The lane's 5-thread pool therefore cannot be the whole explanation. The off path already stretches from one lane to six by x1.31 outside and x1.62 inside the prove call.

**Size.** One lane saves 16.7 ms a block; six lanes lose 79.8 ms (prove call +14.3%, period +13.0%, rate x0.885); eight lanes lose 33 ms (rate x0.952). Moved work is about 59.5 ms (S1 medians: A host 28, A commit 21.5, M 4, B commit 6; tick 30 says 59). Perfect overlap would give 497 ms at six lanes; measured 636 ms. At one lane only 28% of the moved work was hidden. A 60 ms task, even stretched threefold, overlaps a second half for at most 180 ms and cannot add 139 ms alone; a cost spanning the second half is needed.

**Candidates** (none tested):
- *Lane pool.* Plausible inside the prove call (the job takes a worker the second half's parallel sections want); cannot produce the sealing effect. Cores average 14.1 of 32 (tick 30, other batch), so core exhaustion is not indicated.
- *Per-thread Metal queues* (`metal.rs:753-761`): with `thread`, the job thread has its own queue and the GPU "may run side by side" buffers of different queues. A36 puts a commit's NTT and Merkle buffers beside the second half's zero-check buffers in every lane at once, and the six lanes are aligned (Astra: 302 of 333 near-simultaneous A commits began within 10 ms). The one mechanism both new and shared between lanes.
- *Memory bandwidth.* The first half writes about 0.31 GB (words) plus 0.63 GB (encoded) a block (README section 5); at five passes (ASSUMED) six lanes use about 40 GB/s, 5% of the roof. Unlikely alone.

**The single added measurement.** Two six-lane legs on the T2 fixture (`HL_METAL_QUEUES=thread`, same binary), `HL_A27_GPU_TRACE=<prefix>` with `HL_GPU_REQUIRED=1` as Astra's `capture_stream.py` does, switch off then on, read with tick 30's partition. (i) Sum of buffer execution intervals per block **at least 10% above off (about 9 ms): device stretch;** then the cheap follow-up is an on leg with `HL_METAL_QUEUES=shared`. (ii) Host-only time per request thread per block **up 50 ms or more with execution flat: host contention.** (iii) One on leg with `HL_PB_TIMING=1` gives the `prove-ahead` line against the block wall: whether the job outlasts the second half. Tick 30's trace is shared-queue, so it cannot stand in for this.

## 3. (c) What this predicts for the other host-only candidates

Rule from A36: a one-lane gain does not transfer (+4.9% at one lane, rate -11.5% at six).
- **Work removed, no new concurrency** (tick 32's repeated check): 0.223 to 0.358 s solo, x1.31 stretch at six lanes, so 0.29 to 0.47 s, **1.7 to 2.7% of the period** at one-for-one pass-through (less if device-paced). A36's failure does not apply.
- **Work moved to another thread:** the segment writer (tick 31). The sink is 21 ms a block (S1), digest about 10.9 ms (tick 31's bench ratio), write, F_FULLFSYNC and rename about 10.1 ms of waiting. Handing off only the waiting part adds no CPU or device load: **0.26 s a request, 1.5% of the period, the six-lane ceiling.** Moving the digest too resembles A36 and has no six-lane evidence. Seal-ahead (tick 30, x1.039 prior, ceiling x1.178) adds a second active pool and buffers per lane: **its first test must be a six-lane stream under the 3% rule, never a one-lane leg.**
- **MODEL** (closed queue, six lanes, device one first-come server, calibrated on the 557 ms off block): D = 74.8 ms (0.79 x solo) gives think 376 ms, device 81%; cutting the host gap 17 ms is x1.021, 60 ms x1.075; **adding 80 ms of host gap gives x0.904 against A36's measured x0.885.** The model has no overlap term. With D = 94.7 ms (no overlap) think time is 0, the model's own baseline is 568 ms and host cuts pass nothing (a degenerate calibration). The two differ on device cuts only in size, not sign.

## 4. (d) What can still raise the lanes-full rate

Ranked by pass-through (MODEL, both calibrations):
1. **Device time per block:** 1 ms is x1.007 to x1.011 (0.7 to 1.1%, each against its own baseline; the upper end is the no-overlap calibration, where 6 ms of block time falls per ms); 5 ms x1.036 to x1.056; 10 ms x1.073 to x1.118. **About 3 to 4.5 ms (3 to 5% of 94.7 ms) buys the 3% line.** Device-heavy rows of S1: slot 18 (28 ms), slot 14 (20), both commits (21.5, 22.5), slots 15 to 17 and 19 (30); kernel ideas on them are already bounded by ticks 12 to 16 and 28.
2. **Fewer committed words:** the only change that cuts device and host together (commits 28.95 of 94.7 ms, 31%; A and H host phases about 59 of 335 ms). A 10% cut is about 3 ms device (x1.02) plus about 6 ms host (0 to x1.01) (ASSUMED proportional); needs rulings and re-proving.
3. **Fewer command buffers:** counts only for fixed cost inside the 94.7 ms; the 303 ms host-only gap passes only its host share (0 to 0.125% a ms, MODEL).
4. **Host-only cuts** (tick 31, 32): 1.5 to 2.7% each at best, six-lane pass-through not shown.
5. **Concurrency added inside a lane** (A36, seal-ahead, before-part ahead): negative at six lanes until the trace says why.

## Expected effect

Committed words per request: 0. Proved tokens/s: A36 is -11.5% (six lanes) and -4.7% (eight) already measured; for the rest, section 4; nothing is scheduled by this tick.

## Risks and not verified

Each on/off comparison is two legs with off-leg noise of 2 to 5%; the 7% sealing effect repeats in all four on legs but is one measurement each. No trace or phase table exists for any six-lane A36 leg. Solo block GPU is the fixture's, not the stream's; the 0.79 ratio is a shared-queue figure; moved work uses one-lane diagnostic medians (1 ms resolution). The model's single exponential server is crude. I read `classify_run.rs` only through the README's description of the scope and join. Section 4's pass-through values are model values, not measurements.
