# Research handoff: the tail between one request's last run buffer and the next request's first sealing buffer (2026-11-22 UTC, claude-tick 39, queue item 63)

From Claude, the background researcher. One bounded cycle; local reading and arithmetic only (no web, no run, no build, no Git). **Triage material, not a work order.** Nothing here changes what the prover commits.

**Read, and how.** The three full traced arms of one run, `results/zk60_composed_app_20261122/raw/traces/cm_trace3_leg1..3` (A, B, C; 48 timed requests each, `raw/cm_trace3/t2_results.json`), read by script; tick 37's traced pair (`cm_trace_leg1/2`) as a control; the README addendum; code: `classify_serve.rs:231-392, 463-562` (lane loop, stagger), `classify_cli.rs:680-835` (`prove_with_public`), `classify_run.rs:185-330` (`prove_classify_run_with`). Scripts beside this file (standard library, `-I -B`, argument `raw`): `20261122-claude-tick39-after-run-tail.py` (tables 1 to 8; second argument `cm_trace` runs the control), `-stagger-check.py`, `-startup-share.py`, `-head-buffers.py`. Labels: MEASURED (trace), COUNTED (code line), DERIVED (arithmetic), ARGUED (reasoning, untested).

## 0. Headline

1. **The after-run tail is not where the A-to-C gain is.** Directly measured per request and thread (37 kept requests an arm): tail mean 189 ms (A), 218 (B), 190 (C); median 128, 140, 129. **A minus C: -0.001 s, 95% bootstrap interval [-0.049, +0.051]** (MEASURED, DERIVED). The tail is 1.1% of the lane period.
2. **Tick 37's "remainder" of 0.305 s was a sample-set artifact.** Its lane period came from 39 consecutive-request pairs and its sealing, hand-over and run from 45 requests. On one set (the 39 requests that have a successor) the same traced pair gives tail 0.218 (A) and 0.171 (C): difference +0.047 [-0.001, +0.097]; the run difference is -0.708, not -0.448. The cut A to C of 0.865 s splits as run 0.708 (82%), sealing window 0.106 (12%), tail 0.047 (5%, interval holds 0), hand-over 0.005.
3. **The tail is a fixed floor of about 125 ms plus the A28 start stagger.** All 56 tails above 0.2 s (17, 24, 15 in arms A, B, C; every request with a predecessor, not only the 37 kept) sit where the request's first sealing buffer comes 0.29 to 0.32 s after another lane's. Neither always-on change (stride-4 `mask_open`, `w16_histograms_cols`) is in the tail (section 4).

## 1. Method and the pass check

Request thread = thread with over 1,000 buffers (six); start-up `wprod` rows with `t=65` dropped. A request = the run of consecutive `wprod` rows (sealing products) plus all later rows of that thread up to the next such run. For request k with a successor on the same thread: seal = last `wprod` done - first `wprod` begin; hand-over = first run row begin - last `wprod` done; run = latest done among run rows - first run row begin; **tail = next request's first `wprod` begin - latest done among k's run rows**; lane = next first `wprod` begin - this one. Kept when the first `wprod` begins inside [completion 6, completion 54] (README rule).

| arm | n | seal | hand-over | run | tail | lane period | head (in run) | rate measured | rate from 6 x 128 / lane |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| A | 37 | 2.739 | 0.049 | 14.261 | 0.189 | 17.238 | 0.387 | 44.33 | 44.55 |
| B | 37 | 2.698 | 0.046 | 14.771 | 0.218 | 17.733 | 0.397 | 43.92 | 43.31 |
| C | 37 | 2.582 | 0.043 | 13.303 | 0.190 | 16.118 | 0.384 | 47.47 | 47.65 |

(seconds a request; MEASURED, one traced leg an arm.) **Pass check, stated honestly:** seal + hand-over + run + tail equals the lane period exactly (0.000% in every arm) because the four pieces are cut at shared boundaries; that is an identity, not a test. The independent check is the rate: the lane period predicts the measured rate within 0.5% (A), 1.4% (B), 0.4% (C). The run itself telescopes into head + 25 block periods + last block (A 0.387 + 13.381 + 0.493), also exact.

## 2. The tail, per request and per thread (MEASURED)

| arm | min | p25 | median | p75 | p95 | max | sd (ms) |
|---|---:|---:|---:|---:|---:|---:|---:|
| A | 122.7 | 125.5 | 127.8 | 204.4 | 384.5 | 696.5 | 122.6 |
| B | 120.5 | 125.2 | 140.3 | 298.3 | 408.3 | 458.9 | 106.8 |
| C | 121.3 | 124.0 | 128.8 | 233.2 | 400.9 | 446.1 | 96.9 |

Per thread (means of 6 to 7 requests): A 127 to 339 ms, B 124 to 292, C 124 to 313; a cluster at 121 to 129 ms and a long right tail carried by two or three threads an arm.

The last buffer to finish in the run is the 38-row boundary `gather` on all 111 requests, so the run's own device work ends first and the tail is host work only. Rows of other threads begin inside the tails (about 16 a tail); I cannot attribute them to a lane.

## 3. The right-hand part is the A28 stagger (MEASURED, COUNTED)

`HL_A28_STAGGER_MS=300` is set in the test fixture (README); `serve_lines_with` makes each request wait until the last start plus 300 ms (`classify_serve.rs:350-367`). Check (`-stagger-check.py`): the gap between consecutive request starts (first `wprod` begin as proxy) has a hard floor (min 0.276 s, 5th percentile 0.293 to 0.298 s) in all three arms. Tail when the previous start of any lane was under 0.36 s earlier: mean 291 / 283 / 270 ms (n = 23, 30, 21); otherwise 128 / 126 / 126 ms (n = 25, 18, 27). Every tail above 0.2 s (17, 24, 15 of them, all requests with a predecessor) has a gap to the previous start of 0.293 to 0.321 s (A 0.293 to 0.321, B 0.294 to 0.314, C 0.298 to 0.313). So the tail is a floor of about 126 ms plus a stagger wait with a mean of 62 (A), 92 (B), 64 ms (C) a request: **0.36 / 0.52 / 0.40% of the lane period.** The stagger is deliberate (A28: keep lanes out of lockstep); do not read this as lost time without an arm where the lanes bunch.

## 4. What the floor holds, and whether the always-on changes are in it

- **Start side, about 100 ms (MEASURED, first wave).** For the six first-wave requests of each arm, first sealing buffer minus start (driver send time plus the server's own `queued_s`) is 0.106 / 0.105 / 0.104 s mean (median 0.099 to 0.101; `-startup-share.py`). By code order (`prove_with_public`): directories, policy and tied-table check, content slice, honest IN-C inputs, the `x_in` file load, first block's witness set-up, then the first product. Cold first-wave effects are in it (the six agree within 3 ms, except the first request at 0.133).
- **End side, about 25 ms (DERIVED: floor 125 minus 100).** After the last gather: OUT-C's host proof, the last segment `sink`, `input.dec`, statement render, directory rename, event line, `write_log`. Dropping the kept sealing-pass witnesses at the end of the request (26 blocks x 296 MB = 7.17 GiB, `WITNESS_CACHE.json`) would have to fit in this 25 ms, so it is cheap or not on the request thread; unverified.
- **The always-on changes are not in the tail:** `mask_open` is inside the blocks. `w16_histograms_cols` runs in the sealing pass (the first `wprod` window) and in the run's own sealing pass (`prove_classify_run_with`, the first gap of the head, below), never after the last buffer. The measured A-minus-C tail difference is 0 (section 0).
- **The head (0.384 s at C, 2.4% of the lane period).** Equal in all arms (A-C +0.003 [-0.006, +0.011]). In arm C its buffers are 25 ms; the other 359 ms is host gaps (`-head-buffers.py`): **176 ms before the first IN-C commit** (by code order the run's own sealing pass: `lookup_misses`, endpoint check, 26 x `stage_block_kept` + `seal_check`, OUT-C seal check), 98 ms after the 41-row commit, 50 ms before the first A commit, 19 and 12 ms between. This is new material for item 62's H1.

## 5. The lane-period cut, split into the always-on part and the switches

| step | lane | seal | hand-over | run | tail |
|---|---:|---:|---:|---:|---:|
| A to B (always-on part) | -0.495 | +0.041 | +0.002 | -0.510 | -0.028 |
| B to C (the two switches) | +1.615 | +0.116 | +0.003 | +1.468 | +0.028 |
| A to C (both) | +1.120 | +0.157 | +0.006 | +0.958 | -0.001 |

(positive = shorter; seconds a request; MEASURED.) **This triple does not locate the always-on gain, because it does not show one:** arm B's lane period is 0.495 s longer than A's (interval [0.249, 0.733], almost all in the run), against the untraced B over A of +4.2% and +5.1% (about 0.7 to 0.9 s expected). The traced A is 2% to 4% above the untraced A legs (42.5 to 44.3). My intervals count only requests inside a leg; the between-leg spread is as large as the effect, so they understate the uncertainty. Only repeated traced triples would split the always-on part. Not scheduled.

## 6. Test and honest effect

- **Falsifiable (CPU-free, no new run):** the stagger explanation predicts that in any other six-lane trace with `HL_A28_STAGGER_MS=300` all tails above 0.2 s sit 0.29 to 0.32 s after another start, and with the stagger at 0 the tails fall to the floor. A failure of the first (a tail over 0.2 s with no start within 0.32 s before) kills it. Checked here only on this run.
- **Committed words: 0.** Proved tokens/s: the tail as a whole is 1.1% of the lane period at the mean; the stagger excess 0.4% (A, C); the floor 0.73% (start side about 0.58%, the end side 0.15%); under the 5% rule at their ceilings, nothing scheduled.

## 7. Risks and what was not verified

One traced leg an arm; the trace overhead is not zero. The start-side figure comes from cold first-wave requests. The split of the 125 ms floor into code steps is by order, not by marks. A request's start is proxied by its first sealing buffer. The last request of each thread is excluded (no successor).
