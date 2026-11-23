# Research handoff: what a lane's host time per block consists of at six lanes, and what grows from one lane to six (2026-11-23 UTC, claude-tick 47, queue item 77)

From Claude, the background researcher. One bounded cycle; local reading and arithmetic only (no web, no run, no build, no Git). **Triage material, not a work order.** Everything here is host-side timing; no committed word or proof byte is touched. Any change to what the prover draws or commits needs the owner's ruling, a new profile version and re-proving in Lean.

**Question (item 77).** The bundle test's traced pair puts a lane's block at six lanes at 521.5 ms: 218.5 ms device execution, 58.7 wait, 241.6 host. Split the host time by the gaps between a lane's consecutive buffers, at one lane and six; say which gaps grow and by how much; check arm A against tick 40's six-lane device table; count cores.

**Read, and how.** In full: `results/zk60_bundle_app_20261123/README.md`; the traces `bn_trace_leg1` (arm A, base binary, fused RS + sparse fold; six lanes x 5) and `leg2` (arm C, bundle); `results/zk60_lane_threads_20261122` `lt_trace` legs 1 and 3 (same switches as arm A; six lanes and one lane); `results/zk60_lanes_trace_20261121` `tr_leg1` and `tr_main` leg 2 (an OLDER binary: no fused RS, no sparse fold, host store fold; one lane and six); ticks 24, 37, 38, 40 and 42 (tables). Script `20261123-claude-tick47-host-time-six-lanes.py` (standard library, `-I -B`, argument: repo root) prints every number; its output is `...six-lanes.out.txt` beside it. Labels: MEASURED (a trace), DERIVED (script arithmetic), ARGUED. 0 of 12 searches used; none needed.

## 0. Headline

1. **(a) passes.** Arm A's device execution per kind is within 2.8% of tick 40's six-lane column for each of the ten named kinds (0.984 to 1.028), +8.4% on "all others", sum 219.70 against 217.88 ms (+0.8%). Tick 40's column stands. The script's re-implementation reproduces tick 38's periods exactly (504.96 and 302.31 ms).
2. **The README's 241.6 ms host is 230.5 ms of loop host plus about 10 ms of head and last block.** Encode + gap over the 25 block periods: 230.5 (A) and 226.5 (C); the README divides the whole prove call (13.559 s, 13.163 s) by 26 blocks: 240.5 (A) and 236.3 (C) by my window (README 241.6 and 237.7; e differs by 1.2 ms), the difference being the head and last block per 26 (10.0 and 9.8 ms, tick 37's accounting).
3. **Host time grows 37.5 ms from one lane to six** (187.3 to 224.8, x1.20, same-switch pair); 55.6 ms in the older-binary pair (221.7 to 277.3, x1.25, of which 8.4 is the old host fold). The added block period is 202.7 ms (execution +119.4, queue +46.5, host +37.5), so **host growth is 18% of the lane's slowdown**. It is a uniform stretch of about x1.2, not one gap.
4. **Six gaps grow by at least 1.0 ms in both pairs and hold 82% and 70% of the growth.** All keys are in the table of section 2. **The bundle's whole host saving is in the opening tail:** A to C host -4.0 ms, of which the opening tail plus gather (G1 + G2, merged in C because the device gather is gone) 54.4 to 50.5; G3, G4, G5, G6 are unchanged within 0.3 ms.
5. **Cores: 32 logical = 24 performance + 8 efficiency** (`sysctl hw.perflevel0.logicalcpu 24`, `perflevel1 8`; physical equals logical). Mean lanes in host code 3.1; the thread demand cannot be shown to exceed the cores; **no coupling between lanes' host states is established except possibly in G2** (section 4).

## 1. (a) Device table, arm A against tick 40 (MEASURED; ms per block, request threads)

| kind | tick 40 six lanes | arm A | ratio | arm C |
|---|---:|---:|---:|---:|
| slot 18 | 52.71 | 51.95 | 0.986 | 52.14 |
| slot 14 | 33.07 | 33.14 | 1.002 | 33.74 |
| slot 17 | 25.19 | 24.78 | 0.984 | 22.01 |
| commit H (2606) | 17.34 | 17.42 | 1.004 | 17.69 |
| commit A (2504) | 16.64 | 17.01 | 1.022 | 16.18 |
| slot 15 | 14.08 | 14.47 | 1.028 | 15.94 |
| slot 19 | 10.73 | 10.79 | 1.006 | 9.96 |
| slot 0 | 8.46 | 8.38 | 0.991 | 9.07 |
| slot 16 | 8.43 | 8.46 | 1.004 | 8.56 |
| spfold 2504 | 6.07 | 6.02 | 0.993 | 0 (kernel replaced) |
| all others | 25.16 | 27.26 | 1.084 | |
| sum | 217.883 | 219.699 | 1.008 | 211.2 |

## 2. (b) Host time by gap, one lane against six (MEASURED; ms per block, request thread; host = encode + gap, the encode being 0.3 to 0.5 ms)

By group (tick 38's groups; each buffer is charged to the transition after it, so the groups sum to the period):

| group | lt 1 lane | lt 6 lanes | growth | x | old 1 | old 6 | growth |
|---|---:|---:|---:|---:|---:|---:|---:|
| G1 openings tail | 16.8 | 19.4 | +2.6 | 1.15 | 50.6 | 59.0 | +8.4 |
| G2 gather 38 to boundary commit | 26.5 | 34.5 | +8.0 | 1.30 | 27.1 | 35.0 | +7.9 |
| G3 boundary commit to A commit | 31.7 | 37.2 | +5.4 | 1.17 | 34.8 | 44.0 | +9.3 |
| G4 A commit to H commit | 42.4 | 52.2 | +9.8 | 1.23 | 41.3 | 55.1 | +13.8 |
| G5 slots 5-13 to slot 14 | 42.0 | 45.4 | +3.4 | 1.08 | 40.3 | 44.4 | +4.0 |
| G6 other slot gaps | 28.0 | 36.2 | +8.2 | 1.29 | 27.7 | 39.8 | +12.1 |
| all | 187.3 | 224.8 | +37.5 | 1.20 | 221.7 | 277.3 | +55.6 |

Keys that grow by at least 1.0 ms in both pairs (lt, old): A to H commit +9.84, +13.78; gather 38 to boundary commit +7.98, +7.94; boundary commit to A commit +5.42, +9.25; slot 4 to slot 14 +3.31, +3.57; slot 17 to slot 18 +2.85, +3.40 (x1.57, x1.69: the largest stretch of any key; "table build and claimed sum of slot 18"); commit H to slot 0 +1.17, +1.20. Sum 30.6 and 39.1 ms. The other keys over 0.3 ms are slot-setup gaps of 0.3 to 0.9 ms and the opening-tail keys (0.6 to 1.0 ms at one lane only). Arm A at six lanes: 54.0 (A to H), 34.9, 38.5, 43.2 (slot 4 to 14), 7.9, 6.3 ms, equal to the lt column within 2.5 ms; arm C changes none of them.

**Beside tick 24 and tick 42.** Tick 24's classes are union wall times of an 8B prove call (six forks, code before the block loop) and are not per block of one lane; I map by code phase only (C2 opening host work to G1, C8 A to H commit to G4, C6 to G5) and draw no number from the match (C8's 52 ms for 2 gaps and G4's 52.2 for one gap per block agree by accident of units). Against tick 42: the same buffers' device execution stretches x1.4 to x4.4 from one lane to six (slot 18 x2.46, slot 14 x2.03, slot 17 x3.30, commits x1.36), the host gaps x1.08 to x1.30. Host is the smaller and steadier stretch.

## 3. (c) Cores and thread counts (MEASURED where stated, else DERIVED or ARGUED)

32 logical CPUs (24 P + 8 E). Six lanes x 5 pool threads = 30 prover pool threads, six request threads and 30 sealing-queue threads in the trace. Time share with k lanes in host code (encode or gap), lt six lanes: k = 0 9.3%, 1 14.0%, 2 18.0%, 3 17.0%, 4 14.9%, 5 14.3%, 6 12.6%; mean 3.08 (arm A 3.13; old 3.42). **If every lane in host code used its whole 5-thread pool** (an upper bound: G1, G2, G6 and half of G4 are serial) the demand averages 16.3 and exceeds 24 for 28% of the time and 32 for 5%; with one thread per lane it averages 4.0. The sealing pool's host work is invisible (its buffers are few; my proxy gives 0.8 to 0.9 active threads and is not a measure). Tick 30's retained cores figure (14.1 of 32 on average, 8B) points the same way. So 30 threads can exceed the performance cores only during the bunched stretches of the thread-scaled groups (G5, G4, G3; tick 38's thread part about 85 of 225 ms), about a quarter of the time at most; it is not shown to.

## 4. Does a lane's gap lengthen when other lanes are in host code? (pre-registered line, then two controls)

Pre-registered (c): within a group, mean gap with at least 3 other lanes in host code at the gap's midpoint over mean with none, at least 1.25 in two of three six-lane traces. Result (lt6, arm A, old6): G5 1.17, 1.26, 1.33 (met, but the zero bin holds 10, 22 and 32 gaps); G2 1.21, 1.24, 1.29 (one of three); G4 1.11, 1.14, 1.10; G3 1.03, 1.00, 1.00; G1 0.58, 0.54, 1.52; G6 0.80, 0.97, 1.16. Met for G5 only.

**Supplement d (not pre-registered; line fixed before it ran):** the same ratio with at most 1 and at least 4 other lanes, taken also at the midpoint shifted by +-0.1 to 0.3 s. G5: d = 0 gives 1.070, 1.170, 1.217; the shifted values reach 1.065, 1.074, 1.223. By the line (d = 0 above every shifted value by 0.10 in two of three) **G5 is common-mode, not contention**: slow stretches of the run, not the lanes' simultaneous state. G2: 1.154, 1.168, 1.285 against shifted maxima 1.144, 1.065, 1.004: the d = 0 value exceeds them by 0.01, 0.10, 0.28.
**Supplement e (line fixed before it ran): G2 against other lanes in G2 at the same moment.** Mean G2 gap with none, one, two or more others in G2: lt6 29.6, 32.5, 37.8 (+8.1); arm A 29.7, 33.1, 38.5 (+8.9); old6 29.4, 33.9, 43.1 (+13.8). The control at +-0.2 and +-0.3 s gives differences between -5.5 and +5.4 ms. **By the written line (control within 2 ms) this is NOT met**; by magnitude the d = 0 difference is 1.5 to 2.5 times the largest control swing in every trace, so it is suggestive, not shown. G2 holds the disk sink (SHA-256, write, fsync, rename; ticks 31, 32).

## 5. Two candidates, each with its lines written first (measurements for the coordinator; not scheduled; no code change)

**K-4L: is the one-to-six stretch a core-count threshold or a smooth shared-resource effect?** One traced leg, base binary B0 with `frs1 sf1`, **4 lanes x 5 threads** (20 pool threads, under 24 performance cores), host per block over 25 block periods by this script. One lane 187.3, six lanes 224.8 (230.5 in arm A). Linear in lanes predicts 187.3 + 0.6 x 37.5 = 209.8. **Pass for "stretch needs more threads than P-cores": 197 ms or less. Pass for "smooth shared resource" (memory bandwidth, device crowding): 203 to 217. Between, or above 217: undecided.** Noise of a leg mean about 3 ms (tick 37). Four lanes also crowd the device less, so a result near linear cannot name the resource.
**K-G2: is G2's +8 ms the sink?** Two traced legs, one lane and six lanes, with the run files written to a memory-backed volume (not checked that one can be made here; the bytes written are unchanged). **Pass: G2 at six lanes minus G2 at one lane under +2 ms (from +8.0); fail: still +6 or more.** A fail sends the growth to the statement check and `boundary::prepare` (tick 38 T2).

## 6. Honest expected effect

Committed words: 0. Proved tokens/s: nothing from this tick. Removing the entire one-to-six host stretch (37.5 ms) is 7.4% of the six-lane block period at full pass-through and about 2.5% at tick 37's one-third pass-through; G2's share (8 ms) is 1.6% and 0.5%. Under the 5% rule at the ceiling; neither candidate is a gain, both are attributions.

## 7. Risks and what was not verified

Two traced pairs, one run each, with the trace's own overhead; the lt pair and arm A are the same configuration on different days (host 224.8 against 230.5). The older pair has a different binary. "Lanes in host code" counts a lane's gaps and encodes; it is not CPU time, and a gap can contain waiting (rayon join, fsync). The midpoint bins are not independent of the run's common-mode stretches (section 4 shows this). Sealing threads' host work is not in the trace. I did not read the code of the gaps again (tick 38's phase-to-code assignment stands, ARGUED). Core counts are the machine's, from `sysctl`; the scheduler's use of the E cores was not observed.
