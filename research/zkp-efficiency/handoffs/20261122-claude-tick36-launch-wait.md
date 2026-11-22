# Research handoff: a launch-wait rule for the six-lane replay, fitted on leg 2 and tested on leg 5 (2026-11-22, claude-tick 36, queue item 59)

From Claude, the background researcher. One cycle; local reading and a small standard-library simulation; no web, no GPU, no build, no Git. **Triage material, not a work order;** nothing here changes a committed word, proof byte or the verifier.

**Read:** tick 35's handoff and script; `results/zk60_lanes_trace_20261121/README.md`, `t2_results.json` and the compressed traces of legs 1, 2, 4 and 5 (every row, by script). Scripts: `20261122-claude-tick36-launch-wait.py` (runs tick 35's script unchanged to get its templates, then replaces only the launch step; `python3 -I -B <raw dir> <tick 35 script> [fit|six|eight|diag|leg4]`, about 20 s) and `20261122-claude-tick36-feature-check.py` (other state variables for q, out of sample). Labels: MEASURED (trace rows), DERIVED (script output), ARGUED.

## 0. Headline

1. **The item fails its pass condition, so by its rule I stop and say what else is not in the one-lane sequence.** The rule (committed-to-start time q drawn from leg 2's measured q by class, buffers executing and buffers committed-not-started at commit) brings the six-lane replay's q to 51.1 ms a block (leg 2: 51.9) and its rate to 47.2 tok/s (+7%, inside 10%), but empty 18.5% (-19%), three or more at once 31.4% (-22%), none in flight 18.7% (-11%) and variance ratio 2.16 (-19%) stay out. Tick 35 without the rule: 49.85 / 16.7% / 40.3% / 18.5% / 1.88.
2. **Out of sample on leg 5 (eight lanes) it is worse, not better:** rate 48.3 against 42.9 (+13%), empty 15.5% against 26.0% (-40%), variance 2.64 against 4.67 (-44%), q 82.5 ms a block against 130.8. The pass line (rate, empty, variance within 10%) is missed on all three.
3. **The launch wait is not the missing piece at eight lanes:** a table fitted on leg 5 itself (in sample, leg 5's own rate table and host stretch) still gives rate 47.1 (+10%), empty 16.4% (-37%), variance 2.60 (-44%).
4. **What is missing is synchrony, not delay:** the replay's time at one and two buffers executing is too large and at zero and three or more too small (section 3). The one-lane sequence plus device sharing plus a state-dependent wait gives lanes that overlap at random offsets; the real lanes' buffers start and end in step.

## 1. The rule and the fit (leg 2, DERIVED; `fit`)

q = gs - committed, 37,408 rows of leg 2, state at commit from the same rows (executing = started and not ended; pending = committed and not started). Selected bins (mean, median, p90 in ms), prover buffers:

| executing, pending | n | mean | median | p90 |
|---|---:|---:|---:|---:|
| 0 or 1, 0 | 10,413 | 0.2 to 0.35 | 0.12 to 0.15 | 0.2 to 0.7 |
| 2, 0 | 3,961 | 1.23 | 0.28 | 3.4 |
| 2, 1 | 882 | 6.07 | 2.37 | 18.6 |
| 3, 1 | 1,376 | 10.5 | 7.4 | 24.9 |
| 3, 2 | 643 | 15.6 | 12.7 | 34.5 |
| 5, 0 | 321 | 8.05 | 4.04 | 21.3 |

Sealing buffers (queue 99) wait longer in every state (e = 0, p = 0: 1.09 ms; e = 3, p = 3: 10.6). The wait is **heavy-tailed and mostly a function of the buffers already committed and not started** (pending 1 multiplies it by 5 at two executing). But the bin means explain only **35.0%** of q's variance (executing alone 19.9%, pending alone 19.5%), so most of it is not state.

**Other state variables do not rescue it** (`feature-check.py`, prover buffers; fit on leg 2, predict legs 4 and 5 by the same bins): solo work in service plus pending in 10 quantile bins R^2 0.47 in sample, 0.41 on leg 4, 0.37 on leg 5; separate executing and pending work (5 x 4 bins) 0.50 / 0.46 / 0.41; adding the buffer's own size 0.39 to 0.47 in sample. Mean predicted q against measured: leg 4 0.54 to 0.70, leg 5 0.61 to 0.83 (with the plain table at the measured states: 2.99 against 4.28 ms and 4.94 against 7.03 ms a buffer, both ratio 0.70). Per prover buffer q is 0.66 ms at one lane, 2.8 at six, 4.3 at the shared queue, 7.0 at eight: 2.5 times for 1.33 times the lanes, a growth no table at one lane count carries.

## 2. The replay with the rule (`six`, `eight`, `diag`; three template assignments each)

| variant | rate | empty | >=3 at once | none in flight (indep.) | variance ratio | q ms/block |
|---|---:|---:|---:|---:|---:|---:|
| **leg 2 measured** | 44.05 | 22.7% | 40.2% | 20.9% (5.4%) | 2.66 | 51.9 |
| tick 35 base (no rule) | 49.85 | 16.7% | 40.3% | 18.5% (8.2%) | 1.88 | 12.3 |
| rule, sampled | 47.24 | 18.5% | 31.4% | 18.7% (6.7%) | 2.16 | 51.1 |
| rule, bin means | 46.81 | 19.0% | 31.2% | 19.6% | 2.38 | 55.9 |
| rule, executing only / pending only | 47.44 / 44.62 | 18.7 / 22.2% | 33.1 / 29.0% | 19.6 / 14.2% | 2.20 / 1.81 | 47 / 83 |
| rule, gaps x1.4 | 44.28 | 22.2% | 26.3% | 21.8% | 2.13 | 44.2 |
| rule x1.5 | 44.95 | 20.4% | 24.6% | 18.4% | 2.18 | 79.9 |
| **leg 5 measured (8 lanes)** | 42.90 | 26.0% | 52.0% | 25.9% (1.0%) | 4.67 | 130.8 |
| rule from leg 2, eight lanes | 48.28 | 15.5% | 41.9% | 16.3% (2.8%) | 2.64 | 82.5 |
| table fitted on leg 5 | 47.05 | 16.4% | 36.8% | 14.0% | 2.60 | 110.6 |

No variant reaches rate, empty, three-or-more and variance together: raising the gaps to x1.4 fits rate, empty and none in flight (+1%, -2%, +4%) but then three or more is 35% low, so the three-or-more share and the empty share move in opposite directions in this model.

## 3. What the one-lane sequence does not contain (DERIVED, `diag`)

Level shares (buffers executing, all queues), share of the window:

| | 0 | 1 | 2 | 3 | 4 | 5 | 6 or more |
|---|---:|---:|---:|---:|---:|---:|---:|
| leg 2 | 22.7 | 16.4 | 20.7 | 27.6 | 9.3 | 2.7 | 0.6 |
| replay with the rule, six lanes | 18.0 | 23.8 | 27.1 | 20.2 | 8.2 | 2.4 | 0.3 |
| leg 5 | 26.0 | 8.9 | 13.2 | 24.8 | 10.6 | 7.8 | 8.8 |
| replay with the rule, eight lanes | 15.7 | 19.5 | 22.7 | 20.2 | 11.7 | 6.1 | 4.2 |

The rule also removes tick 35's artefact (levels up to 13): the replay's maximum is 8 at six lanes (measured 6) and 9 at eight (measured 8). What remains is a **bimodal real device against a unimodal replay**: the real stream spends 7 points (six lanes) and 11 points (eight) less at one executing buffer, 6 and 10 points less at two, and 5 and 10 points more empty. This is the signature of lanes in step (all in a host gap, then all on the device), which tick 34 measured as variance x2.66 and x4.67. Processor sharing from independent launch times, however delayed, produces about half of it (tick 35), not the rest. Candidates, none shown: (a) buffers of different lanes are admitted in groups (a wait that ends when some buffer ends, not after a time); (b) a host-side coupling that the one-lane gaps lack: the six or eight lanes' commit, fsync and receipt-write phases (tick 31 measured six writers 2.8 times one) landing on the same moments; (c) the sealing-to-prover join, only inferred from timing. Leg 4 cannot test (a): its prover buffers all sit on queue 0, yet 12,563 of 23,219 consecutive buffers (commit order) start before their predecessor ends, so a shared queue is not an in-order serialiser in these trace times, and begin-to-committed is 0.03 ms (I did not resolve what the README's w = 33.1 ms for leg 4 is).

## 4. Falsifiable next test (item 60, reading and arithmetic)

From leg 2 and leg 5, per start, record whether it follows within 0.5 ms the end of a buffer on another lane's queue (a cross-lane hand-off) and compare with the replay. **Pass for (a):** measured share of cross-lane hand-off starts at least twice the replay's; then add "a waiting buffer starts when a buffer ends, never by time" to the replay and require the six-lane levels 0 to 3 within 3 points and eight lanes rate, empty and variance within 10% without refitting. **Fail:** the coupling is host-side (b) or in the join (c), and the only route is a measurement under one change (tick 34's item 56 trace).

## 5. Expected effect, risks, not verified

- **Committed words per request 0; proved tokens per second: none claimed.** The replay cannot rank candidates (i) to (v) of tick 35. It shows the opposite of what an engineer might hope: a launch wait with realistic size does not make a replay explain the stream, so the stream's loss is not a queue that more lanes or a cap could shorten by the sizes tick 35 tried.
- **Risks:** q's definition (trace gpu_start may be a scheduled time, not an execution start: leg 4's overlaps hint at it); bins at e >= 5 hold few rows (fallback to fewer pending, in the script); three template assignments; R(k) is a time average; leg 5 has 7 requests per lane.
- **Not verified:** the cause of the wait; whether pending buffers wait for hardware, the driver or the thread that commits them; what leg 4's w column is.
