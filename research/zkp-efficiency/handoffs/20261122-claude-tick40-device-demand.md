# Research handoff: the device demand table at the app profile, one lane against six, and what a ms of it is worth (2026-11-22 UTC, claude-tick 40, queue item 65)

From Claude, the background researcher. One bounded cycle; local reading and arithmetic only (no web, no run, no build, no Git). **Triage material, not a work order.** Every cut named below keeps the committed words; any change to what the prover commits or draws needs the owner's ruling, a new profile version and re-proving in Lean.

**Read, and how.** In full: the READMEs of `results/zk60_lane_threads_20261122/`, `zk60_composed_app_20261122/`, `zk60_fused_rs_app_20261121/`; the first 60 lines of `zk60_fused_rs_20261120/README.md`; tick 38's handoff and script; tick 17's sections 1 to 5; tick 14's sections 1 to 2; the traces `raw/traces/lt_trace_leg1` (6 lanes x 5 threads) and `leg3` (1 lane x 5 threads), by script. Code (lines): `metal.rs:1702-1710` (gather), `1919-1960` (spfold), `2600-2640` (commit), `4425-4440` (`HL_METAL_BATCH_TAIL_US`), `metal_kernels.metal:925-1010` (`k_fold_sparse_partial`, `k_fold_sparse_reduce`). Script `20261122-claude-tick40-device-demand.py` (standard library, `-I -B`, takes the `raw` directory) prints every number. Labels: MEASURED (a trace or record), COUNTED (code line), DERIVED (my arithmetic, in the script), ASSUMED.

## 1. (a) Execution per block by buffer kind (MEASURED; ms per block, request thread only, both switches on)

Definitions are tick 38's (1,200 blocks at six lanes, 200 at one). A kind is the trace tag plus the slot number or row count; execution is the buffer's `gpu_end - gpu_start`.

**Pass: the kinds sum to 98.541 ms (one lane) and 217.883 ms (six lanes), against 98.5 and 217.9: differences +0.04% and -0.01%.** Stretch of the sum x2.211, +119.3 ms.

| kind | per block | one lane | six lanes | stretch | added | what it is |
|---|---:|---:|---:|---:|---:|---|
| slot 18, F zero-check | 1 | 21.42 | 52.71 | 2.46 | 31.29 | 19+3 tables, n_vars 21, degree 5, 17 device rounds |
| slot 14, D zero-check | 1 | 16.31 | 33.07 | 2.03 | 16.76 | 37+4 tables, n_vars 19, degree 5, 16 rounds |
| commit rows=2606 (H) | 1 | 12.68 | 17.34 | 1.37 | 4.66 | RS encode + Merkle hash |
| commit rows=2504 (A) | 1 | 12.21 | 16.64 | 1.36 | 4.44 | same |
| slot 17, softmax zero-check | 1 | 7.63 | 25.19 | 3.30 | 17.56 | 19+1 tables, n_vars 19, 15 rounds |
| slot 15, Q zero-check | 1 | 5.68 | 14.08 | 2.48 | 8.40 | 15 tables, n_vars 19, 14 rounds |
| spfold rows=2504 | 1 | 4.18 | 6.07 | 1.45 | 1.88 | sparse opening fold, A rows |
| slot 19, table-helper zero-check | 1 | 4.03 | 10.73 | 2.66 | 6.70 | 58+18 tables, n_vars 14, 9 rounds |
| slot 16, KV zero-check | 1 | 3.05 | 8.43 | 2.76 | 5.38 | 15 tables, n_vars 17, 12 rounds |
| slot 0, row sums (norm_a) | 1 | 1.91 | 8.46 | 4.43 | 6.55 | 3 tables, n_vars 19, 11 rounds |
| all others (slots 1, 3, 4, 21, 22, spfold 2606 and 38, commit 38, gathers, three rare slots) | | 9.44 | 25.16 | | 15.7 | |

The top ten are 90.4% (one lane) and 88.4% (six lanes) of the demand. Grouped: slots 14 to 18 are 54.1 of 98.5 ms at one lane and 133.5 of 217.9 at six, **67% of the 119.3 ms added** (79.4 ms); commits (six per block) x1.44, +11.0 (9%); spfold x1.51, +3.1 (3%); slots 0 to 4 x3.32, +15.4 (13%); slots 19 to 23 x2.53, +9.8 (8%). Small-table slots (0, 1, 3, 4, 16, 19, 21, 22) stretch x2.89, big-table slots (14, 15, 17, 18) x2.45, commits x1.37. Per block there are 141 device rounds in the 12 main slots (the trace's `nd`), so about 420 to 560 dispatches.

**Limits.** `wprod` is absent: the sealing products run outside the block loop (17.3 ms a block-equivalent at one lane, tick 33's table; the request's device work is 2.968 s, the block loop 2.56 s of it). The A36 job's buffers on the pool's own queues are not counted. Execution at six lanes includes sharing with the other lanes' buffers; a kind's "stretch" is wall time under contention, not extra work.

## 2. (b) The ten largest kinds: what they compute, over how many elements

Table elements are 16 B (tick 14). Slot kernels: `batched_rounds` (`metal.rs` about 4029-4085 per tick 17), fold `k_fold_tables_dev3`, the A27 round kernel `k_v13`, transcript step `k_sc_fs_step` (`metal_kernels.metal` 944-1131); the batch buffer is made at `metal.rs:4590`.

1. **Slot 18** (F zero-check): 22 tables x 2^21 = 46.1 M elements (738 MB), 17 rounds. Covered by tick 10 (line values and delayed reduction: dead or about zero after A27), tick 11 (padded pairs, 1.2 to 2.1 ms at 8B), ticks 12 to 16 (K1 load share 0.19; split H162 0.91 to 0.97 of v13 at 8B), tick 17 (transcript step, 0.138 to 0.145 ms per round at degree 5).
2. **Slot 14** (D): 41 x 2^19 = 21.5 M (344 MB), 16 rounds. Same coverage; tick 11 found no gate here at 8B.
3. **Commit 2606** (H): 2,606 rows, 2^14 data + 280 pad, coded to 2^15: 85.4 M words (683 MB) written, then hashed (`metal.rs:2631`, fused RS encoder on, `frs=1` in the trace). Covered by ticks 21 and 23 (NTT 0.87 of a commit; traffic-floor kernel at most 2.7 to 3.2% of block GPU) and the fused encoder.
4. **Commit 2504** (A): 82.0 M words (656 MB). Same.
5. **Slot 17** (softmax): 20 x 2^19 = 10.5 M, 15 rounds, no recover. Tick 17 only (transcript step); tick 11 says no gate.
6. **Slot 15** (Q): 15 x 2^19 = 7.9 M, 14 rounds. Ticks 10 to 17.
7. **spfold 2504**: reads 2,504 x 16,664 = 41.7 M words (334 MB), writes and re-reads 13 x 37 x 16,664 x 16 B = 128 MB of partials; 5,658 (row, vector) terms, so 189 M `gl_mul` (`metal.rs:1919-1960`, `metal_kernels.metal:938-1010`). **Not covered by ticks 10, 17 or 24** (tick 24 priced the host opening work this kernel replaced).
8. **Slot 19** (table helpers): 76 x 2^14 = 1.2 M, 9 rounds: dispatch-bound. Tick 17.
9. **Slot 16** (KV): 15 x 2^17 = 2.0 M, 12 rounds. Tick 17.
10. **Slot 0** (row sums): 3 x 2^19 = 1.6 M (25 MB), 11 rounds, 1.9 ms alone and 8.5 ms at six lanes. A 25 MB slot cannot take 8.5 ms by bytes: this is the time to run 11 dependent rounds while other lanes' large kernels occupy the cores. Tick 17 only.

Tick 24 covers the host side around these slots (277 ms of opening host work, 63 ms slots-to-14), none of the device time.

## 3. (c) The exchange rate R: ms of block period per ms of one-lane device demand, at six lanes

Definitions: block period 504.96 ms (tick 38, six lanes), one-lane demand D1 = 98.54 ms. A request is 128 tokens; request time at rate r is 6 x 128 / r. The fused-encoder traced pair shows 82% of the rate-implied time gain in block wall (-26.8 against -32.7 ms), so block-wall gains are 0.82 of the rate-implied gain per block.

- **Structural bounds (DERIVED).** Six blocks of one-lane demand are 591 ms per 505 ms of period: overlap factor c = 1.171. If the device were the only constraint R = 6/c = **5.12**; if the host were, R = 0.
- **E1, the fused RS encoder, app profile (MEASURED rates, ASSUMED demand cut).** Untraced pairs +4.43, +2.87, +3.06, +1.43% (mean +2.95%) give block wall -23.7, -16.0 (mean), -7.9 ms. One-lane demand cut: **4.1 ms** (installed-block solo A+H commit 28.95 ms, switch off, `zk60_w16r2_shield_block_20261120`, minus this one-lane trace's 24.89 ms, switch on; different harnesses) or **7.9 ms** (the traced pair's six-lane execution cut of 17.0 ms is 8.0% of 212.2; the same 8.0% of 98.5). **R = 3.9 to 2.0 at the mean gain** (1.0 to 5.8 across the four pairs).
- **E2, from the host pass-through (DERIVED, a closed two-phase model).** Tick 37 measured that a cut of 53.4 ms of host gap passed a third (execution +21.1 and queue +14.6 came back). If the host cut passes 1 - w, a device ms passes w x 6/c: **R = 3.4** at one third (3.1 to 3.8 at a quarter to two fifths). Not independent of the shape of the model, but independent of E1's data.
- **E3, tick 33's calibration (not a measurement):** 0.7 to 1.1% of rate per block-ms = **3.5 to 5.6 ms**.
- **Do E1, E2, E3 agree within a factor of two? Yes in their central values** (2.0 to 3.9, 3.4, 3.5 to 5.6; extreme ratio 2.8 across the full ranges, 1.7 between the nearest). In rate terms **one ms of one-lane device demand is about 0.3 to 0.9% of the tok/s rate** (R x 26 ms / 16.4 s request period = 0.16% per unit of R). That is about half a percent of rate per percent of one-lane demand (1 ms is 1.0% of 98.5 ms), which agrees with item 58's corrected "about half in percent" and not with "one for one".
- **Limit: R is not a constant.** In the composed bundle (traced A against C, one pair) one-lane demand changed by about -1.8 to +2.0 ms (fused -4.1 to -7.9, spfold +6.1), yet six-lane execution rose 20.5 ms and queue 14.8 ms, because the host cut (-53.2 ms) put more lanes on the device at once. The stretch depends on the number of lanes on the device, so a device cut is worth more when lanes are bunched than when they are staggered. The three estimates are at the present operating point only. Whether a *host* ms or a *device* ms is the cheaper way to buy rate is then settled by R against pass-through: at E2's central values a device ms is worth about 3.4 ms of period, a net host ms 0.33 (tick 37).

## 4. (d) Three cuts of device demand that keep the committed words (not scheduled; each with a test)

Ranked by expected rate change at 0.3 to 0.9% per one-lane ms.

1. **Run more tail rounds on the host: raise `HL_METAL_BATCH_TAIL_US` from 25 to 250 (a setting; `metal.rs:4431-4437`; "which side computes a round changes no byte", M4k).** At 8B solo it removed 7.1 ms of device time a block (tick 17, knob probe: 63.3 to 56.2 ms over 12 slots); tick 16 found the move flat on a two-lane stream. At six lanes a device ms is worth 2 to 5 ms of period while the host rounds cost at most their own time on the request thread, so the sign may differ. Expected: -1% to +3.8%; the host cost per moved round is not measured. **Test:** six lanes x 8 threads, untraced, A,B,B,A (default, 250, 250, default), receipts checked; pass: both pairs at +1.5% or more; kill: either under 0. No run needed first except the guard.
2. **Transcript step and per-round latency (tick 17's R1, test K9).** The 12 main slots hold 141 rounds a block; the equal-round gap of tick 17 is 11.3 ms of one-lane time at 8B (0.06 to 0.145 ms a round). New evidence, consistent with but not proof of a latency cost: slot 0 (25 MB) takes x4.43 and the small-table slots x2.89 against x1.37 for the byte-heavy commits. Recovering half, 5.6 ms, is 1.7 to 5% of rate. **Test:** K9 as tick 17 specified (5 s of GPU, `k_sc_fs_step` at count 4,096 and degree 5); pass for a kernel project: at least 0.06 ms; kill: 0.02 ms or less, then the equal-round gap is a fixed batch cost.
3. **The spfold kernel is 2.4 to 4.9 times its floors.** One lane: 4.18 + 1.85 = 6.0 ms (A and H shapes). Floors at the K0 copy roofline (700 GB/s) and K4 `gl_mul` rate (220 G/s): 0.84 ms (bytes incl. partials) and 0.86 ms (products), so 1.7 ms if they add. Reading: the partial kernel keeps 37 vectors of accumulators in threadgroup memory (about 19 KB, which limits resident groups) and loops rows serially per column. Recovering half of 6.0 ms is 3 ms: 0.8 to 2.4% of rate. **Test:** the kernel alone on captured A-shape buffers (guard, class gpu, seconds): pass at 2.1 ms or less with byte-identical output; kill at 3.5 ms or more.

Smaller and already bounded: the padded-pair skip in slot 18 (1.2 to 2.1 ms at 8B: 0.4 to 1.9% of rate; tick 28's 3.3 to 6.1% ceilings at the installed profile are of a different cadence and I did not reconcile them to ms); the traffic-floor NTT kernel (tick 23, at most 3 ms).

## 5. Honest expected effect

Committed words: 0 from this reading. Tokens per second: no change from the reading; it prices what a one-lane device ms is worth at six lanes (about 3 ms of period, 0.3 to 0.9% of rate) and ranks three cuts that together might reach +4% to +10% if all work and R holds, which is not a promise: R was fitted at one operating point, E1's demand cut spans a factor of two, and cut 1's host cost is unmeasured.

## 6. Risks and what was not verified

One traced run of each leg (trace overhead; traced and untraced rates not compared except in direction). The one-lane leg has 200 blocks and no other lane's contention. I did not read `k_fold_sparse_partial` for register or occupancy use; the floors are arithmetic with K0 and K4 figures from the Metal bench, not a measurement of this kernel. E1's low cut mixes a solo harness with a trace. The block-wall share (0.82) comes from one traced pair. The slot "what it is" labels come from the trace's own detail strings; element counts use `log_cap` and k + m from them, as tick 14 did (a table at 16 B). The sealing products and the A36 job's buffers are outside the table.
