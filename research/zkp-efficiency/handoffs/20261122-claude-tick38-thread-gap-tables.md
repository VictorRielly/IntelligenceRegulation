# Research handoff: which host phases shrink with a fifth thread, and the one-lane gap table (2026-11-22 UTC, claude-tick 38, queue item 64)

From Claude, the background researcher. One bounded cycle; local reading and arithmetic only (no web, no run, no build, no Git). **Triage material, not a work order.** Everything below is host-side timing; no committed word or proof byte is touched. Any code change that alters what the prover draws or commits needs the owner's ruling, a new profile version and re-proving in Lean.

**Read, and how.** In full: `results/zk60_lane_threads_20261122/README.md`; the three traces `raw/traces/lt_trace_leg1` (6 lanes x 5 threads), `leg2` (6 x 4), `leg3` (1 lane x 5 threads, 8 timed requests), all with both switches on (`.tsv.xz`, read by the script); `raw/lt_trace/t2_results.json`; tick 37's handoff and script. Code read (lines): `classify_run.rs:269-308`, `protocol.rs:2347-2420, 2500-2515, 2550-2890`, `argument.rs:1192-1293`, `boundary.rs:337-352`. Script `20261122-claude-tick38-thread-gap-tables.py` (standard library, `-I -B`, takes the `raw` directory) prints every number. Labels: MEASURED (a trace), COUNTED (code line), DERIVED (my arithmetic), ARGUED.

## 0. Headline

1. **Item 64's pass check holds exactly.** Each buffer is assigned to the phase of the transition that follows it (its encode, queue, execution and wait, plus the gap), so the phases sum to the block period: 504.96 / 528.95 / 302.31 ms, difference 0.0000 ms in all three legs (1,200, 1,200 and 200 blocks).
2. **The loss at four threads is all host gap.** Block period 6x5 504.96 to 6x4 528.95 ms (+24.0, +4.75%); gap +24.5 (224.3 to 248.8), execution +0.4, queue -0.9, wait -0.1. The traced rate fell 46.94 to 44.54 tok/s (-5.1%); the untraced pairs were -3.3% and -6.1%. **The gap tables account for the loss.** Three phases carry 21 of the 24.5 ms: slots 5-13 (+9.5), A to H commit (+6.6), boundary commit to A commit (+5.2).
3. **About half the host gap is serial and does not change with threads.** A two-point fit per phase, gap = s + p/T from T = 4 and 5, gives p/5 = 98 ms thread-scaled and s = 126 ms serial of the 224 ms (DERIVED; two points, one pair of runs). The three flattest phases are the opening tail (ratio 1.000), gather 38 to boundary commit (1.045) and the other slot gaps (1.045); they hold 75.5 ms of serial residual, 15% of the block period.
4. **One lane to six lanes: the block period is x1.670 (302.3 to 505.0 ms) and only 37 ms of the 203 ms is host gap.** Execution +119 ms, queue +47 ms, gap +37 ms. The host gaps stretch only x1.10 to x1.30 per phase, so tick 37's six-lane stand-ins (x2.2 for A to H, x1.7 for slots 4 to 14) were mostly profile (8B figures against this profile), not lane stretch.

## 1. (a) The gap table by code phase (MEASURED; ms per block, request thread)

Phases as tick 37 (G1 opening tail slot 22 to gather 38 including the spfold buffers; G2 gather 38 to boundary commit; G3 boundary commit to A commit; G4 A commit to H commit; G5 slots 5-13 to slot 14; G6 every other slot-to-slot gap and H commit to slot 0). Total = encode + queue + execution + wait + gap of the phase's buffers.

| phase | 6x5 gap | 6x5 total | 6x4 gap | 6x4 total | 1x5 gap | 1x5 total |
|---|---:|---:|---:|---:|---:|---:|
| G1 openings tail | 19.3 | 38.7 | 19.3 | 38.2 | 16.7 | 28.1 |
| G2 gather 38 to boundary commit | 34.4 | 35.4 | 36.0 | 36.8 | 26.5 | 27.1 |
| G3 boundary commit to A commit | 37.1 | 44.8 | 42.3 | 45.8 | 31.7 | 32.9 |
| G4 A commit to H commit | 52.2 | 75.7 | 58.8 | 83.4 | 42.3 | 55.8 |
| G5 slots 5-13 to slot 14 | 46.6 | 54.2 | 56.1 | 63.4 | 42.2 | 44.7 |
| G6 other slot gaps | 34.6 | 256.1 | 36.2 | 261.3 | 27.5 | 113.8 |
| all | 224.3 | 505.0 | 248.8 | 529.0 | 187.0 | 302.3 |

Queue, execution and wait per block, all phases: 6x5 59.7 / 217.9 / 2.6; 6x4 58.8 / 218.3 / 2.5; 1x5 13.2 / 98.5 / 3.3 (the script prints them per phase). Block-to-block sd of the period 39.5 (6x5), 46.0 (6x4), 5.8 ms (1x5). Noise floor of a difference of means about 1 to 3 ms (tick 37 compared a smoke leg with a traced leg of one arm and found up to 2.7 ms per group).

## 2. (b) Which phases scale with the fifth thread

Ratio 6x4 over 6x5 of the gap (a phase that used all its threads perfectly would show 1.25). **A ratio near 1.0 means serial host code, or a wait on something else.**

| phase | gap 5 | gap 4 | ratio | serial residual s (fit) | thread part p/5 |
|---|---:|---:|---:|---:|---:|
| G5 slots 5-13 | 46.6 | 56.1 | 1.204 | 8.6 | 38.0 |
| G4 A to H commit | 52.2 | 58.8 | 1.127 | 25.8 | 26.4 |
| G3 boundary to A commit | 37.1 | 42.3 | 1.140 | 16.3 | 20.8 |
| G2 gather 38 to boundary | 34.4 | 36.0 | 1.045 | 28.0 | 6.4 |
| G6 other slot gaps | 34.6 | 36.2 | 1.045 | 28.2 | 6.4 |
| G1 openings tail | 19.3 | 19.3 | 1.000 | 19.3 | 0 |

**The three largest phases that do not scale (by residual s), with code locations:**

1. **G6, other slot gaps, 28 ms serial (35 ms gap, 1.045).** The per-slot host setup between device slots, each 1.4 to 8 ms: slot 17 to 18 7.9 ms (ratio 1.03), H commit to slot 0 6.1, slot 3 to 4 5.1, slot 0 to 1 4.7, slot 14 to 15 3.2, tick 37's "table build and claimed sum of slot 18". COUNTED: `argument.rs:1213` (tables build), `1282` (claimed sum `total`, `tr.absorb_fp2`), `1289` (the shared masked sumcheck); `argument_with` at `argument.rs:2986`. The loop is per slot and the transcript is one sequential object, so it is serial by construction.
2. **G2, gather 38 to boundary commit, 28 ms serial (34 ms, 1.045).** The previous boundary's opening tail, `wire::encode_segment` (`classify_run.rs:303`), the disk sink (`sink(k + 1, bytes)`, `classify_run.rs:308`; ticks 31, 32: SHA-256, write, F_FULLFSYNC, rename, 21 to 25 ms), the next block's load and statement check (`classify_run.rs:269-272`, `stage_block_kept`) and the `Fp::from_i64` map over the plane (`classify_run.rs:280`, a single-threaded iterator), then `boundary::prepare` (`boundary.rs:337-352`, whose NTT and Merkle run in `pcs::commit_zk_owned_tagged`). The fsync and hash are not helped by rayon.
3. **G4, A to H commit, 26 ms serial of 52 (ratio 1.127, a scaling part as well).** `zk::mask_commit_tagged` (`protocol.rs:2509`), the root absorbs, `u8_denominator_inverses` (`protocol.rs:1142, 2591`), the single-stream `rng.fill_fp` of the H mask rows (`protocol.rs:2824`) and the zero-sum rows' serial fold after it. The parallel parts are the helper inverses (`inverses`, `protocol.rs:1010`, rayon chunks of 2^14) and `write_helpers_*`.

**G1, 19.3 ms, exactly flat (1.000, per key: slot 22 to spfold 7.06 / 7.06, spfold to gather 6.10 / 6.14, gather to spfold 3.14 / 3.14).** `zk::mask_open`, the two `check_opening` schedule audits and the host part of `pcs::open_zk` (`protocol.rs:2863-2877`). It is the fourth non-scaling phase, and it is the only one that is exactly flat, so it is entirely serial.

**Next three in order of size are the scaling ones:** G5 (38 ms thread part of 46.6; the nine matmul claims, no buffers; scales almost the full 1.25, at 1.204) and G4, G3.

## 3. (c) One lane against six lanes at this profile

Stretch from one lane (1x5) to six (6x5), per phase: total x1.21 (G5), x1.31 (G2), x1.36 (G3), x1.36 (G4), x1.38 (G1), x2.25 (G6, whose device slots stretch 77 to 181 ms of execution). Gap alone: G2 x1.30, G6 x1.26, G4 x1.23, G3 x1.17, G1 x1.16, G5 x1.10. The sum of the six lanes' increase over one lane's period (+202.7 ms): execution +119.4, queue +46.5, gap +37.3, wait -0.7, encode +0.2.

**This replaces tick 37's stand-ins and answers its G5 test.** Tick 37 compared the 8B solo log (A to H 25 ms, slots 5-13 26 ms, boundary to A 28 ms) with the app's six-lane gaps and read the ratios (x2.2, x1.7, x1.4) as six-lane stretch. The one-lane app gaps are A to H 42.3 ms, slots 5-13 42.2 ms, boundary to A 31.7 ms: the profile accounts for most of the difference (x1.7 and x1.6 for the first two before any other lane runs), the lane stretch is x1.23, x1.10 and x1.17. Tick 37's G5 test ("near 45 ms: the solo log's 26 is not this phase") reads **42 ms: the 26 ms (PB-TIMING, 1 ms resolution) is not this phase at this profile**; item 44's reconciliation should start from 42 ms.

## 4. (d) Do the tables account for the setting results?

- **Removing the fifth thread:** yes, as in headline 2 (gap +24.5 of period +24.0 ms; traced -5.1%, untraced -3.3% and -6.1%).
- **Adding threads beyond five:** the fit predicts a period cut from the gap of 16.3 ms at six threads (-3.2%), 36.8 ms at eight (-7.3%), 57.2 ms at twelve (-11.3%), against measured gains of +2.2% (6x6), +3.3% (6x8) and -0.4% (6x12). **The fit holds to six and overpredicts beyond:** at eight it is x2.2 too high, at twelve it gains where the machine lost. DERIVED, from two points a phase; the extra threads crowd 32 cores (48 and 72 threads in six pools) and presumably the device (execution rose x2.2 from one lane to six), which the gap model does not carry. The phases that would gain from more threads are G5 (thread part 38 ms), G4 (26), G3 (21), in that order; G1, G2 and G6 would not (their thread part is 6 ms or none).
- **A bound for any host-code work:** the host gap is 44% of the period (224 of 505 ms) and about 56% of that gap is serial (126 ms, 25% of the period); only code that shortens G1, G2, G6 or G4's serial part (75 + 26 = 101 ms, 20%) changes the thread-independent floor. At the pass-through tick 37 measured (a third), a full 25 ms cut of a serial phase is about 8 ms of period (1.6%).

## 5. Falsifiable tests (not scheduled)

- **T1 (one more traced leg, 6 x 8 on the same binary):** the fit predicts G5 gap 32 ms, G4 42, G3 29, G1/G2/G6 unchanged (19, 32, 32). Pass: the three scaling phases fall by at least 6 ms each and the serial three move by under 2 ms; kill: G5 stays above 42 ms. A different result locates the 6x8 gain in execution or queue rather than the host.
- **T2 (reading, CPU):** whether the `Fp::from_i64` map and `boundary::prepare`'s data fill (`classify_run.rs:280`, `boundary.rs:343-349`) are under 2 ms of G2 on one thread (a bounded CPU timing); if so G2's serial part is the sink and statement check (ticks 31, 32).

## 6. Honest expected effect

Committed words: 0. Proved tokens/s: no change from this reading. It sizes where the host time sits: 126 ms of a 505 ms block is serial host code that more threads cannot touch, and 98 ms is thread-scaled and nearly exhausted at six to eight threads. A 10 ms cut in one serial phase is about 3.3 ms of period at a third pass-through (0.7%).

## 7. Risks and what was not verified

One traced run of each leg, with the trace's own overhead; traced rates are not compared with untraced ones except in direction. Only two thread counts feed the s + p/T fit (no 6 or 8 trace), so the split into serial and thread parts is model-dependent; per-phase differences of 1 to 2 ms (G2, G6, G1) are inside the noise. The 6 x 8 prediction uses the 6 x 4 and 6 x 5 gaps only. The one-lane leg has 8 requests (200 blocks) and its own device conditions (no crowding), so the stretch figures include both lanes' contention and the A36 job's pool buffers, which this table does not count (request thread only, as tick 37). I read the code phases from `classify_run.rs` and `protocol.rs` and did not instrument them; the assignment of a gap to a source line is ARGUED except where a trace key names the transition.
