# Research handoff: the empty device at full lanes, and what the lanes are doing while it is empty (2026-11-21, claude-tick 34, queue item 56)

From Claude, the background researcher. One cycle; local reading and arithmetic only (no web, no GPU run, no build, no Git). **Triage material, not a work order;** nothing here changes a committed word, proof byte or the verifier.

**Read:** `results/zk60_lanes_trace_20261121/README.md` and the five compressed traces `raw/traces/*.tsv.xz` (every row, by script), `trace_check.py` (for the window and union rules), `t2_results.json` per leg. Script: `20261121-claude-tick34-empty-device.py` (standard library, `python3 -I -B <raw dir>`, about 40 s). Its leg 2 numbers reproduce the co-coordinator's table (empty 22.7%, one 16.4, two 20.7, three or more 40.2). Labels: MEASURED (trace rows), DERIVED (script arithmetic), ARGUED (my reading, untested).

## 0. Headline

1. **At six lanes the empty device is many short stretches, none over 50 ms:** 9,421 stretches in a 139.5 s window, median 1.6 ms, 62% of the empty time in stretches over 5 ms, 19% over 20 ms. Eight lanes make longer ones (7.8% of empty time over 50 ms).
2. **All the lanes are on the host together.** At a stretch's midpoint 3.6 of 6 lanes (6.1 of 8) are in the same inter-buffer host gap. The count of lanes with a prover buffer in flight has variance 2.66 times (six lanes) and 4.67 times (eight) what independent lanes would give; none in flight is 20.9% of the time against 5.4% (six) and 25.9% against 1.0% (eight) if independent. So about 17 of the 22.7 points at six lanes are correlation, not load.
3. **The device is not saturating at high overlap:** its work rate keeps rising with the number of buffers executing (0.95, 1.33, 1.37, 1.63 solo-seconds per second at one, two, three, four or more). Two at once is already 1.33.

## 1. (a) Empty stretches (window = completion 6 to completion 54; union of all buffers' execution intervals)

| leg | stretches | median / p90 / p99 / max, ms | over 5 ms: share of empty time (of window) | over 20 ms | over 50 ms |
|---|---:|---|---|---|---|
| 2: 6 lanes, thread queues | 9,421 | 1.6 / 7.8 / 27.1 / 50.0 | 62.4% (14.2%) | 19.0% (4.3%) | 0 |
| 5: 8 lanes | 8,485 | 1.5 / 9.0 / 48.0 / 63.8 | 72.7% (18.9%) | 46.7% (12.1%) | 7.8% (2.0%) |
| 4: 6 lanes, shared queue | 11,089 | 1.5 / 8.5 / 31.8 / 51.0 | 67.8% (17.9%) | 28.1% (7.4%) | 0.1% |
| 3: 6 lanes, A36 on | 9,786 | 1.8 / 13.1 / 44.2 / 77.5 | 75.0% (23.0%) | 44.7% (13.7%) | 5.0% (1.5%) |

(Empty shares of the window: 22.7, 26.0, 26.4, 30.7%.) A36's extra empty time is in the longer stretches (over 20 ms: 4.3% to 13.7% of the window); the shared queue sits between.

## 2. (b) Where each lane is when the device is empty (leg 2; a lane = one of the six prover queues)

The lane's block is a cycle of 18 prover buffers; leg 1's host gap between consecutive buffers (median ms, solo) is: slot 22 > gather H 24.5; gather H > gather A 23.3; gather A > gather M 1.5; gather M > commit M 27.0; commit M > commit H 34.6; commit H > commit A 41.1; commit A > slot 0 4.9; slots 0 to 4 about 9; **slot 4 > slot 14 40.2**; slots 14 to 22 about 13. The names are the buffer labels; I have not mapped them to code or to S1's phase rows (S1 section 11 has the one-lane rows, 1 ms resolution).

- **The 218 stretches over 20 ms:** per-lane pairs (last buffer before the stretch > next after): slot04>slot14 213, slot22>gather2504 191, gather2504>gather2606 190, gather38>commit38 177, commit38>commit2504 147, commit2504>commit2606 110, gather38>commit6 106 (the sealing pass, a 2.3 s gap at one lane): 1,134 of about 1,300 lane-stretch pairs. The stretch's globally last buffer is gather2504 53, slot22 40, gather38 37, slot04 35, commit38 23, a sealing product (`wprod`) 21 times; the first after is gather2504 50, gather2606 39, slot14 35, commit38 31, commit2504 28, wprod 15. No lane has its next buffer already encoded when the stretch begins (mean 0.00 of 6); a lane's last buffer ended a median 6.7 ms before.
- **Stretches of 5 to 20 ms are largely sealing:** over 5 ms, a sealing buffer is the last before in 37% (678 of 1,829) and first after in 36%; over 20 ms only 10% and 7%.
- **Lane-time in each state, empty time against the whole window (ratio; a lane is in a gap 62% of the time, so 1.6 is "uniform"):** slot22>gather2504 2.16, sealing or request-boundary gap 1.84 (27.8% of lane-time in empty stretches), gather38>commit38 1.77, gather2504>gather2606 1.77, slot04>slot14 1.75, commit38>commit2504 1.46, **commit2504>commit2606 1.03, commit2606>slot00 1.02.** At eight lanes the same host gaps reach 2.1 to 2.9 and commit2504>commit2606 falls to 0.38.
- **The host gaps stretch with load** (sum of the 18 gaps of a block: 219 ms at one lane, 266 at six, 351 at eight), so at six lanes the lane's block wall (547 ms) is 49% host gaps.

## 3. (c) Work rate against buffers executing (unit: leg 1's median execution of each buffer key; each buffer progresses at its solo time over its duration)

| leg | level | none | one | two | three | four or more |
|---|---|---:|---:|---:|---:|---:|
| 2 (6 lanes) | time share | 22.7% | 16.4% | 20.7% | 27.6% | 12.6% |
| | rate, all buffers | | 0.95 | 1.33 | 1.37 | 1.63 |
| | rate, prover only | | 0.69 | 0.96 | 1.25 | 1.58 |
| | prover buffer duration / solo | | 1.03 | 1.61 | 2.33 | 2.81 |
| 5 (8 lanes) | time share | 26.0% | 8.9% | 13.2% | 24.8% | 27.2% |
| | rate, all buffers | | 1.09 | 1.32 | 1.21 | 1.51 |
| | prover buffer duration / solo | | 1.03 | 1.72 | 2.62 | 3.40 |
| 4 (shared) | time share | 26.4% | 16.4% | 24.3% | 32.5% | 0.5% |
| | rate, all buffers | | 0.97 | 1.30 | 1.40 | (noise) |
| | prover buffer duration / solo | | 1.02 | 1.62 | 2.30 | |

Whole-window work: 1.01 (leg 2), 0.98 (leg 5), 0.94 (leg 4) solo-seconds per second; per busy second 1.31, 1.33, 1.28. Two at once already runs at 1.3; **no fall at four or more** (rate rises). Leg 4's shared queue never shows four at once.
**Caveat:** sealing buffers run faster at six lanes than the one-lane unit (the heaviest key, `t=128 k=4096 n=16384`, is 2.66 ms at six lanes against 5.00 at one; mean 0.6 to 0.9 of solo), so the all-buffers rate is soft by that and the prover-only rows are the clean ones. Cause not examined (a lighter-load clock state is one possibility; prover buffers show none: 1.03 at level one).

## 4. What would have to change for the empty share to fall (no code proposed)

- **The correlation, not the load:** independent lanes with leg 2's in-flight fraction (0.37 to 0.40 each; sealing not counted) leave 5.4% empty (about 2% by the co-coordinator's 47%); measured 22.7%. Adding lanes raises the load but raises the bunching faster (variance ratio 2.66 to 4.67), so eight lanes keep the empty share at 26%.
- **What couples them is not shown.** ARGUED, untested: the lanes' buffers at level three or more take 2.3 to 2.8 times solo and finish nearly together, so they leave for their host gaps together and arrive together; the 300 ms start stagger exists only at the start. The host gaps over-represented (slot 22 to the next gathers; slots 5 to 13; sealing) are the places where the lanes meet. Neither "device-paced" nor "host-paced" describes it: it is a loop in which each side waits for the other.
- **Bound (DERIVED, ceiling):** if the empty share fell from 22.7% to 5% and busy time kept the measured 1.31 per busy second, the rate would be x1.23; at level one (0.95) it is x0.89. So the range is below 1 to 1.23, and any gain needs a change in how lanes are phased, not in the proof.

## 5. Falsifiable test (item 57's replay, in this project's terms)

Replay leg 1's per-buffer sequence for six lanes with the level rates above. **Pass:** it reproduces leg 2's empty share (22.7%), none-in-flight share (20.9%) and in-flight variance ratio (2.66) to within 10%. If it does with held lane phases only, the correlation is dynamic (device coupling); if it needs the start stagger removed, the coupling is the stagger's decay. If it gives about 5%, something that is not in leg 1's sequence couples the lanes.

## 6. Expected effect, risks, not verified

- **Committed words per request: 0. Proved tokens per second:** none claimed; the x1.23 above is an arithmetic ceiling, not a prediction, and is a lane-scheduling question rather than a kernel or protocol one, so the kernel 5% rule does not apply to it. A lane-phasing change leaves proof bytes unchanged.
- **Risks:** a lane is a prover queue (leg 4's shared queue gives one, so no lane attribution there; leg 3's 12 queues are not lanes); sealing buffers (queue 99) are not attributed to lanes; the host gap names are buffer labels, not code phases; the window is cut by begin time, as in `trace_check.py`; single runs, one traced leg each.
- **Not verified:** the cause of coupling; whether the stagger decays within a block; the sealing unit's cause; the mapping of the seven gaps to S1's phase rows.
