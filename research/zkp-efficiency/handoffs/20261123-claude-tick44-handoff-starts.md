# Research handoff: cross-lane hand-off starts in the six- and eight-lane traces, against tick 36's replay (2026-11-23, claude-tick 44, queue item 60)

From Claude, the background researcher. One cycle; local reading and a standard-library script; no web, no GPU, no build, no Git. **Triage material, not a work order;** nothing here changes a committed word, proof byte or the verifier.

**Read:** tick 36's handoff and script (executed unchanged except two text patches that record each buffer's end and, in stage 2 only, release waiting buffers at ends), tick 35's script it builds on, `results/zk60_lanes_trace_20261121/README.md`, and every row of the compressed traces of legs 1, 2 and 5. Script: `20261123-claude-tick44-handoff-starts.py` (`python3 -I -B <script> <raw dir> <tick 36 script> <tick 35 script> [meas|replay|wait|adm]`, about 20 s in all). Labels: MEASURED (trace rows), DERIVED (script output), ARGUED.

## 0. Headline

1. **Item 60's first pass rule is met as written, and its reading needs a control.** The share of prover starts that fall 0 to 0.5 ms after the end of a buffer on another lane's queue is 21.1% (leg 2, six lanes) and 32.6% (leg 5, eight lanes) against 9.4% and 10.0% in tick 36's replay: x2.24 and x3.27 (pass: at least x2). But the mirror control (an end 0 to 0.5 ms AFTER the start, which cannot have caused it) is 13.6% and 22.7% measured against 6.5% and 6.9% in the replay, so most of the raw gap is end density (bunching), not hand-off.
2. **The specific excess is real and absent from the replay.** Against the flat level at lags 0.5 to 3 ms the 0 to 0.5 ms bin is x1.75 (six lanes) and x1.94 (eight) measured, x1.00 and x0.99 in the replay. About 10% (six) and 19% (eight) of prover starts are hand-offs beyond background (DERIVED, section 2). Leg 1, one lane: 0.0% (no other lane, as it must be).
3. **It belongs to buffers that waited.** Among prover buffers with a committed-to-start wait over 5 ms, 37.6% (six lanes) and 35.2% (eight) start in the 0.5 ms after another lane's prover end beyond background (39.9% and 37.0% counting sealing ends too); at a wait of 0.5 to 5 ms 15.5% and 18.3%; at a wait up to 0.5 ms none at six lanes (0.0%) and 4.8% at eight. So "a waiting buffer starts when a buffer ends" is a description of a minority of the waiting buffers (about 60% of the long waiters do not start at an end of any buffer on another queue), not a rule that covers them.
4. **Stage 2 fails: the mechanism does not bring the replay's levels or eight-lane statistics inside the lines, so the replay line stops** (item 60's own rule). Best variant (release one waiting buffer per end, no timeout, no refit): six-lane levels 0 to 3 off by -2.4, +2.3, +8.0, -2.4 points (line: within 3, so level 2 fails); eight lanes rate +7%, empty -32%, variance -22% (line: 10%). Every other variant is worse on one of the lines (section 3).
5. **What this leaves, in the item's words:** the coupling is not shown to be a start-at-an-end admission. The remaining routes are host-side (all lanes landing in their commit, fsync and receipt phases together) or the sealing-to-prover join; only a measurement under one change decides, as tick 34 and tick 36 said.

## 1. How the starts were counted (DERIVED; `meas`)

Lane = prover queue: legs 2 and 5 have one prover queue per lane (6 and 8 queues, each on one thread); all sealing buffers sit on queue 99 and have no lane in the trace, so the clean lane-identity count is prover start after prover end on a different queue. Window rows are cut by host begin time as in tick 36 (23,239 and 23,211 prover starts). A hand-off is an end (gpu_end) on another queue in (s - 0.5 ms, s] for a start at s; the mirror is an end in (s, s + 0.5 ms]. Replay: three seeds pooled (69,216 starts), a sealing buffer given queue 99 for like-for-like counts.

| prover starts after prover ends of other lanes | hand-off 0 to 0.5 ms | mirror | lags +0.5 to +3 ms (five bins, mean) | peak over flat | hand-off beyond background |
|---|---:|---:|---:|---:|---:|
| leg 2, six lanes | 21.1% | 13.6% | 12.0% | x1.75 | 10.3% of starts |
| replay, six lanes | 9.4% | 6.5% | 9.4% | x1.00 | 0.0% |
| leg 5, eight lanes | 32.6% | 22.7% | 16.8% | x1.94 | 18.9% |
| replay, eight lanes | 10.0% | 6.9% | 10.1% | x0.99 | 0.0% |

"Beyond background" is (h - b) / (1 - b) with b the flat mean, which assumes the background is independent of the hand-off. Two further variants (any end on another queue; sealing starts after prover ends; all starts) give the same picture: x2.3 to x2.9 (six), x2.4 to x3.3 (eight) raw, with measured mirror ratios of the same size.

Two things in the lag bins that I did not resolve. (i) The bin just before zero (a start 0 to 0.5 ms BEFORE another lane's end) is also raised in the measured legs (13.6% against about 9.5% for the other negative bins at six lanes; 22.7% against about 17.7% at eight), while the replay has no such rise: the trace's start and end stamps may overlap by under 0.5 ms (leg 4's overlapping starts hint at the same), so a hand-off may be wider than the 0.5 ms used; that would only make the measured excess larger. (ii) The replay's flat level (9 to 10%) is the density of ends it produces; the measured flat level is 12 to 17%: the real ends are clustered in time, the signature tick 34 found in the in-flight variance.

## 2. Which starts hand off (DERIVED; `wait`)

Prover starts by committed-to-start wait q (gs minus committed), hand-off fraction beyond the flat background of lags 0.5 to 3 ms:

| | q at most 0.5 ms | 0.5 to 5 ms | over 5 ms |
|---|---:|---:|---:|
| leg 2, six lanes: share of starts | 59.8% | 25.2% | 15.0% |
| leg 2: hand-off beyond background, prover ends / all ends | 0.0% / 0.1% | 15.5% / 21.4% | 37.6% / 39.9% |
| leg 5, eight lanes: share of starts | 44.3% | 24.8% | 30.8% |
| leg 5: hand-off beyond background, prover ends / all ends | 4.8% / 5.0% | 18.3% / 23.4% | 35.2% / 37.0% |

Reading (ARGUED): the device admits some waiting buffers when another buffer finishes, which is candidate (a) of tick 36 in its true size: a minority of the waiters, a larger share at eight lanes (30.8% of starts wait over 5 ms) than at six (15.0%). It does not say why the other 60% of long waits end, and it says nothing about the buffers that do not wait.

## 3. Stage 2: the rule added to the replay, no refit (DERIVED; `adm`, three seeds)

Tick 36's replay, with a buffer whose drawn wait exceeds 0.5 ms held in a list and released at the next buffer end instead of at its drawn time (all waiting buffers at each end, or one per end in first-in-first-out order; with or without the drawn time as a timeout). Measured level shares 0 to 3 buffers executing: six lanes 22.7 / 16.4 / 20.7 / 27.6; eight lanes 26.0 / 8.9 / 13.2 / 24.8.

| six lanes (rate 44.05, empty 22.7%, variance 2.66) | rate | empty | variance | levels 0..3, points off |
|---|---:|---:|---:|---|
| tick 36 rule, timed | 47.2 (+7%) | 18.5% | 2.16 | -4.2, +6.9, +6.1, -7.4 |
| release all at an end | 48.2 (+9%) | 18.3% | 2.28 | -4.4, +3.5, +5.5, -6.1 |
| **release one per end** | 46.3 (+5%) | 20.3% | 2.76 | **-2.4, +2.3, +8.0, -2.4** |
| release all, or drawn time | 49.6 (+13%) | 16.8% | 2.03 | -5.9, +3.4, +3.0, -5.2 |
| release one, or drawn time | 49.2 (+12%) | 17.5% | 2.15 | -5.2, +3.7, +2.1, -5.6 |

Eight lanes (rate 42.90, empty 26.0%, variance 4.67): timed rule 48.3 / 15.5% / 2.64; release one per end 46.1 (+7%) / 17.8% (-32%) / 3.63 (-22%), levels 0..3 off by -8.2, +6.0, +9.7, +8.5; the other three variants rate +17% to +19%, empty -46% to -50%, variance -44% to -49%. Pass lines (levels within 3 points at six lanes; rate, empty, variance within 10% at eight): none met. Release-one without a timeout comes closest at six lanes (variance +4%, three of four levels within 2.4 points) and overshoots queueing at eight (q 125 ms a block against 130.8 measured, but three or more at once 44% against 52%).

## 4. What is not in the replay yet (ARGUED, not shown)

The replay still has no source of synchrony: starting lanes with a 0.3 s stagger, host gaps from one lane's sequence scaled by a constant, and a device that admits at ends cannot produce all lanes sitting in a host gap together (none in flight 20.9% against 5.4% independent, tick 34). The hand-off peak in section 1 is the device-side half of that picture; the missing half is on the host side or in the join. **Falsifiable next test (one measurement, not scheduled):** tick 34's item 56 trace under one change that removes cross-lane host coupling but not device sharing (for example `HL_A28_STAGGER_MS` raised to a larger spacing, or lane commit phases skewed), and read whether the none-in-flight share falls toward the independent share while the hand-off fraction of section 2 stays. If the share stays, the coupling is on the device; if it falls with the hand-off fraction unchanged, the host is the coupling.

## 5. Expected effect, risks, not verified

- **Committed words per request: 0. Proved tokens per second: none claimed.** This is a diagnostic of what the replay lacks; it ranks no candidate and the replay line stops here.
- **Risks:** gpu_start and gpu_end may be scheduled rather than executed times (overlap at the 0.5 ms scale); the lag bins are of 0.5 ms and the background is a five-bin mean; "beyond background" assumes independence of the flat level; a start's wait q is by the trace's committed stamp; leg 5 has seven requests per lane; three seeds; the sealing buffers' lane is unknown so the lane count of the all-ends variants treats queue 99 as one lane.
- **Not verified:** the cause of the hand-off (hardware scheduler, driver, or the thread that commits); whether the 60% of long waits that do not end at a buffer end end at a driver timer or a commit by another thread; whether the hand-off fraction depends on the buffer's size or kind (not split).
