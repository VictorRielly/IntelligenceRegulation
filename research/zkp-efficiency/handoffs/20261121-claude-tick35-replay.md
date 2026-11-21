# Research handoff: a replay of the six-lane stream from the one-lane trace (2026-11-21, claude-tick 35, queue item 57)

From Claude, the background researcher. One cycle; local reading and a small standard-library simulation (arithmetic by the queue's rule); no web, no GPU, no build, no Git. **Triage material, not a work order;** nothing here changes a committed word, proof byte or the verifier.

**Read:** `results/zk60_lanes_trace_20261121/README.md`, `trace_check.py`, the five compressed traces and `t2_results.json` per leg (every row, by script); tick 34's handoff. Script: `20261121-claude-tick35-replay.py` (`python3 -I -B <raw dir> [tmpl|base|sens|diag|cand]`, about 45 s for all sections). Labels: MEASURED (trace rows), DERIVED (script output), ARGUED.

## 0. Headline

1. **The replay does not reproduce leg 2, so by the item's rule I stop and report no candidate effect.** Fed with leg 1's per-buffer sequence, tick 34's work rate per level (R = 1.00, 1.33, 1.37, 1.63) and the measured host stretch (gaps x1.215, the 266/219 ms of tick 34), six lanes give 49.9 tok/s, empty 16.7%, three or more at once 40.3%, none in flight 18.5%, in-flight variance ratio 1.88. Leg 2 is 44.05, 22.7%, 40.2%, 20.9%, 2.66. Passes (within 10%): three or more at once. Fails: rate +13%, empty -26%, variance ratio -29%; none in flight is -11.5% (borderline). Eight lanes fail more (rate +20%, empty 13.1% against 26.0%, variance 2.17 against 4.67).
2. **The part that does reproduce: bunching from the device alone.** The replay's lanes start from a 0.3 s stagger only and have no coupling except sharing the device, yet reach variance ratio 1.9 and none-in-flight 18.5% against 8.2% for independent lanes at the replay's own in-flight fractions: roughly half to two thirds of the measured excess over independent lanes (variance 0.88 of 1.66; none-in-flight 10.3 of 15.5 points). So "what couples the lanes" (tick 34 section 4) is mostly the loop "buffers finish together, leave for the host together, come back together", as ARGUED there, not something outside leg 1's sequence.
3. **What is missing is a device-side delay that is not in the sequence.** Leg 2's committed-to-start time is 51.9 ms a block (mean 2.79 ms a prover buffer, median 0.20, long tail) against 12.2 ms at one lane; the replay gives 12.3. Adding 4 ms to every launch brings rate (44.0) and empty (23.5%) to leg 2, but then three or more at once falls to 29.1% (measured 40.2) and the variance ratio stays 1.85. No single input I tried reaches all four numbers (section 2).

## 1. The replay (what it is)

- **Requests** are leg 1's requests 2 to 7 (between completions k-1 and k): about 481 prover buffers and 208 sealing (`wprod`) buffers each. For every buffer the script takes an *enabler* (the same-class, same-thread predecessor if its done time is within 3 ms of the latest done time before this buffer's begin; else the latest-done buffer; the first buffers wait for the previous completion) and a *gap* = begin minus the enabler's done time; launch latency (gpu_start - committed, median 0.64 ms), done latency (0.16 ms) and the request's tail after its last buffer (25 to 29 ms) as measured. Per template: prover device work 2.47 to 2.57 s, sealing 0.39 to 0.49 s, prover gaps 6.1 s, sealing gaps 3.7 to 4.0 s, 26 block starts, one cross-class enabler (COUNTED by the script, `tmpl`). Encode time (begin to committed) is 0.02 ms and ignored.
- **Device:** processor sharing; with k buffers executing (all queues, sealing included) the device does R(k) solo-seconds of work a second, shared equally, so a prover buffer at level 2, 3 and 4 or more takes about 1.5, 2.2 and 2.8 times solo (measured 1.61, 2.33, 2.81). R from tick 34 section 3; leg 5's R for eight lanes. Sealing work is scaled by 0.75 (variant; 1.00 gives 49.2 tok/s) because tick 34 found sealing buffers 0.6 to 0.9 of the one-lane unit at six lanes.
- **Lanes:** back to back requests, start stagger 0.3 s per lane, templates assigned by seed (three assignments; the rate varies by under 1%). Window: completion 6 to 54 for six lanes (48 requests), 8 to 56 for eight.
- **Not in it:** any CPU contention beyond the fixed stretch; the launch queue; any hardware limit on concurrent buffers; the join between a sealing result and the prover (only inferred from timing).

## 2. Replay against leg 2 (`base`, `sens`, `diag`; DERIVED)

| variant (six lanes) | rate | empty | >=3 at once | none in flight (indep.) | variance ratio |
|---|---:|---:|---:|---:|---:|
| **leg 2 measured** | 44.05 | 22.7% | 40.2% | 20.9% (5.4%) | 2.66 |
| base: gaps x1.215, sealing x0.75 | 49.85 | 16.7% | 40.3% | 18.5% (8.2%) | 1.88 |
| no host stretch | 54.30 | 12.1% | 50.2% | 13.4% | 1.89 |
| gaps x1.6 | 42.90 | 25.0% | 26.9% | 25.0% | 1.78 |
| +4 ms per launch | 44.02 | 23.5% | 29.1% | 15.8% | 1.85 |
| no stagger | 49.41 | 18.0% | 41.6% | 22.4% | 2.13 |
| cap of 4 buffers executing | 49.18 | 18.6% | 41.1% | 21.2% | 2.25 |
| sealing on one queue, one at a time | 49.58 | 14.5% | 35.6% | 18.4% | 1.87 |

- **The host stretch alone is not it.** Gap length against the number of other lanes in a host gap (MEASURED, leg 2, transitions with a solo gap of 5 ms or more): median 1.11 with none, 1.14, 1.18, 1.18, 1.20, 1.24 with five others (mean 1.17 to 1.31). Leg 5: 1.34 with none to 1.64 with seven others. So a load-dependent stretch is real but small at six lanes (+0.13 across the range) and a fixed 1.215 already contains most of it; a stretch of 1.6, which fits rate and empty, is the eight-lane value and contradicts the measured gaps.
- **Levels:** leg 2 never has more than six buffers executing (0.6% at six); the replay reaches 13 (sealing buffers of 30 threads run at once on one queue number). Serialising the sealing queue lowers the three-or-more share to 35.6% and does not move the rate. A limit near four to five executing is the one change that raises the variance ratio (2.25 and 2.03) but it leaves the rate at 49 to 49.5.
- **Not found:** a mechanism that makes buffers wait for the device after commit by 2.1 ms on average with a long tail (leg 2 q 51.9 ms a block). The replay has no admission limit that produces it (cap 4 gives 24.6 ms, cap 5 14.0). Where that wait comes from (the GPU's queue arbitration, the driver, or the host thread that completes the commit) is not shown by the traces: they record committed and gpu_start only.

## 3. Items (i) to (v): not answered

Because the replay fails its gate, none of the five candidate effects is a prediction and I do not state one. For the record, the exploratory runs (`cand`; the model overstates the rate by 13%) gave: held phase grid x0.87 to x1.00 (it only delays lanes), caps of 2, 3, 4 buffers x0.83, x0.89, x0.98, 10% less prover host time x1.04, 10% less prover device work x1.04, all sealing products on the host free x1.04 and at 4 times their device time x0.97. They show only that none of the five is large in a model that already has too little empty time; they are not evidence about the real stream and should not be quoted.

## 4. Falsifiable test (a replay with the missing delay, no GPU)

Item 59 (below): from leg 2's rows, fit committed-to-start time as a function of the number of buffers executing and queued at commit (and of the buffer's queue), add that rule to the replay, and test the result **out of sample on leg 5** (8 lanes, not used in the fit) and on leg 4 (shared queue). **Pass:** the eight-lane replay reproduces rate, empty share and variance ratio (26.0%, 4.67) to within 10%, and the six-lane replay reproduces all five leg-2 numbers. Fail again: then something outside the one-lane sequence (the sealing-to-prover join, the host's thread scheduling) is missing, and item 57's candidates are not answerable by replay at all; a measurement (item 56's trace under one change) is the only route.

## 5. Expected effect, risks, not verified

- **Committed words per request 0; proved tokens per second: none claimed.** The replay's internal sensitivity says 10% less host time per block is worth about x1.04 and 10% less device work about x1.04 in a model that is too fast; that agrees in size with tick 34's own bounds and is not new evidence.
- **Risks:** the enabler is inferred from timing, so cross-chain joins (sealing to prover, the 2.3 s sealing gap) are approximated; templates are leg 1's, six requests, one clock state; R(k) is a time-average, not a function of which kernels overlap; gap noise (sigma 0.3) changes the rate by under 1%.
- **Not verified:** the cause of the launch wait; whether leg 1's sealing buffers (5.0 ms for the heaviest key) are slower than at six lanes (2.66 ms) because of a clock state; any queue-99 ordering rule.
