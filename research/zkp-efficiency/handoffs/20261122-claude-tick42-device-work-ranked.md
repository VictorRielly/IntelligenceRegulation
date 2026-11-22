# Research handoff: which device work per request could come off the device, ranked (2026-11-22 UTC, claude-tick 42, queue item 58)

From Claude, the background researcher. One bounded cycle; local reading and arithmetic only (no web, no run, no build, no Git). **Triage material, not a work order.** Every candidate below keeps the committed words; a change to what the prover commits or draws would need the owner's ruling, a new profile version and re-proving in Lean.

**Read, and how.** In full: `results/zk60_lanes_trace_20261121/README.md` and `raw/trace_summary.txt`; the traces of leg 1 (1 lane x 5 threads, 6 timed requests, 156 block-equivalents) and leg 2 (6 x 5, 48 timed requests, 1,248) by script; `results/zk60_effplan_20261105/a4/README.md` (A4); tick 40's handoff; tick 34's level table (section 3). In part: `results/zk60_a26_app_20261107/README.md` (the CPU profile, section 6; the levers, section 7). Code (lines): `private_block/witness.rs:852-881` (`on_device_split`), `891-1010` (`matmul`, `matmul_in_out`, the CPU paths), `1179-1181, 1352, 1425-1443` (the seven products). Script `20261122-claude-tick42-device-work-ranked.py` (standard library, `-I -B`, takes the `raw` directory) prints every number. Labels: MEASURED (trace or record), COUNTED (code line), DERIVED (arithmetic, in the script), ASSUMED.

## 0. Headline

- **No product can go back to the CPU at a profit.** The seven sealing products cost 17.28 ms of device a block at one lane (13.55 at six; 15.1% of the request) and 2,392 thread-ms on the CPU at A4's own speed: 62 thread-s a request, 67% of the machine's 93 core-s per request at the six-lane rate. The smallest pair (K, V) is about at break-even.
- **The 15% sealing share is a one-lane figure that overstates the six-lane cost.** The heaviest sealing buffer (gate/up) runs in one of two modes at one lane, about 3.4 ms (44%) or 5.8 ms (56%); at six lanes 95% are in the fast mode (median 2.63 ms). The cause is not shown (section 3); at the operating point sealing is 6.2% of device execution, not 15.1%.
- **The device work is 59% zero-check slots, 26% the two big commitments, 15% sealing, 0.5% everything else.** What can come off is kernel time (same device, fewer ms), not relocation; each such item is at most 1 to 5% of rate, under the 5% rule.

## 1. (a) Table of keys (MEASURED; ms per request at one lane is ms per block x 26; request = 2.9676 s, README 2.968)

| key (per block) | n | ms/req, 1 lane | share | ms/block at 6 lanes | x6/x1 |
|---|---:|---:|---:|---:|---:|
| slot 18 (F zero-check) | 1 | 558.3 | 18.8% | 47.9 | 2.23 |
| slot 14 (D zero-check) | 1 | 424.9 | 14.3% | 33.0 | 2.02 |
| commit rows 2606 (H) | 1 | 386.0 | 13.0% | 21.4 | 1.44 |
| commit rows 2504 (A) | 1 | 371.9 | 12.5% | 23.6 | 1.65 |
| wprod 4096 -> 16384 (gate, up) | 2 | 245.6 | 8.3% | 5.58 | 0.59 |
| slot 17 (softmax) | 1 | 198.4 | 6.7% | 16.9 | 2.22 |
| slot 15 (Q) | 1 | 149.1 | 5.0% | 11.8 | 2.06 |
| slot 19 (table helpers) | 1 | 104.1 | 3.5% | 11.6 | 2.90 |
| wprod 9216 -> 4096 (down, two int16 halves) | 2 | 103.1 | 3.5% | 3.82 | 0.96 |
| slot 16 (KV) | 1 | 78.9 | 2.7% | 6.5 | 2.14 |
| wprod 4096 -> 4096 (Q, AO) | 2 | 54.3 | 1.8% | 2.12 | 1.02 |
| slots 0, 1, 4, 3, 21, 22 | 1 each | 231.4 | 7.8% | 27.6 | 2.7 to 4.1 |
| wprod 4096 -> 1024 (K, V) | 2 | 46.4 | 1.6% | 2.02 | 1.13 |
| commits of 38, 76, 41, 6 rows; all gathers; slots 12, 20 | | 15.4 | 0.5% | 3.3 | |

Top eight keys: 82.2%. By group at one lane: zero-check slots 58.8% (67.1 ms a block), commits A and H 25.5% (29.15), sealing products 15.1% (17.28), other commits 0.3%, gathers 0.2%. At six lanes: 71.7 / 20.7 / 6.2 / 0.8 / 0.6% of 217.6 ms. The mapping of the four wprod keys to the seven products is INFERRED from the shapes and from COUNTED `on_device_split`: the 9216-wide key is the FFN down projection, whose 24-bit input is outside int16 and so runs as two halves (`witness.rs:852-881`), which is why each key shows two buffers.

## 2. (b) The sealing products: CPU against device

A4 measured, at W16R2 8B T128, the seven products alone on the CPU at 85 ms (32 threads, best of 5) against 14.1 ms on the device [A4, MEASURED]; the stream went from 15.98 to 20.73 tok/s when they moved. The same shapes give 27.4 to 31.1 G multiply-adds (DERIVED; the 8B down projection's inner width is not in my records, so a range), so the CPU runs about 10 to 11.4 G MAC/s per thread. I use 11.4, the faster, which favours the CPU.

| product | G MAC | device ms, 1 lane / 6 lanes | CPU thread-ms | CPU wall at 5 threads | CPU wall / device (1 lane) |
|---|---:|---:|---:|---:|---:|
| gate, up (each) | 8.59 | 4.72 / 2.85 | 750 | 150 | 32 |
| down (one product, two halves) | 4.83 | 3.96 / 3.89 | 422 | 84 | 21 |
| Q, AO (each) | 2.15 | 1.04 / 1.08 | 188 | 38 | 36 |
| K, V (each) | 0.54 | 0.89 / 1.03 | 47 | 9.4 | 11 |

- **Break-even** (DERIVED from tick 40 and tick 37): a device ms freed is worth about 3.4 ms of period (tick 40, E2), a net host ms 0.33 (tick 37); so CPU wall on the lane may be at most 3.4 / 0.33 = 10.2 times the device ms freed, or 3.4 times if the sealing-side host ms passes in full. Every product is above 10.2; K, V is just above (11 against the one-lane device ms, 9 against the six-lane ms), so at break-even.
- **K and V alone:** 18.8 ms of lane wall a block, 0.49 s a request (2.8% of the 17.4 s six-lane lane period at full pass-through, 0.9% at one third), against a rate gain of +0.75% (R 3.4) to +1.1% (R 5.12). Net -2.1% to -0.2% on those two; +0.2% at the most favourable pair. Not worth a lane.
- **Down on the CPU is the worst:** out of int16 it takes the generic i64 path. A26's R13 profile measured it at 37% of the prover's CPU, 1.99 CPU-s a block, 4.3 G MAC/s per thread (DERIVED from 0.37 x 139.5 CPU-s / 26); at the app's 4.83 G MAC that is 1.1 thread-s a block against 4.0 ms on the device.
- **Spare cores do not change it.** Tick 30 had 14.1 of 32 cores busy, about 52 core-s a request spare; all seven products need 62.

## 3. The one-lane sealing unit is bimodal (new, MEASURED)

Gate/up buffers at one lane in the timed window (n = 312): median 5.00 ms, mean 4.72; 44% at or below 4.5 ms (median 3.36), 56% above (median 5.77). At six lanes (n = 2,448): median 2.66, 95% fast. Over the seven one-lane sealing passes the slow share is 0.31 to 0.75 a pass, and by block position within a pass it is 0.29 to 0.86 (no position always slow or always fast, 0 of 26), so it is **not a property of the layer's weights**. Fast runs are mostly 8 to 15 buffers; slow runs 2 to 35. A busier previous 200 ms goes with the slow mode (median 6.05 ms against 3.74), the opposite of a clock ramp-up. Tick 34 saw the same at six lanes (sealing at 0.6 to 0.9 of solo) and called it unexamined; here it is shown to be a state, not a data effect. If every one-lane gate/up buffer ran fast, a block saves 2.65 ms (2.3% of the one-lane request). At six lanes it is already fast, so there is **no six-lane gain from it**; the consequence is that item 58's 2.968 s is a one-lane unit that overstates the stream's sealing device work by about a fifth (13.55 against 17.28 ms).

## 4. (c) The commitments and the gathers

- **The trace does not separate transform from hash:** one buffer per commit (`commit rows=2606 log_n=14 ...`). From tick 21's diag split at W16R2_8B (inverse 8.3, forward 14.0, hash 3.4 ms; f = 0.868; tick 28: the installed block equals it within 0.1 ms) scaled to this trace's 29.15 ms for A + H (the coordinator's installed block 28.95): **forward NTT 15.9 ms (13.9% of the request), inverse NTT 9.4 (8.2%), hash 3.9 (3.4%)** (DERIVED; the fused encoder was off in this trace).
- **The two large gathers are not device work:** 2.17 ms each a request (0.07%; 0.185 ms a block over all). They matter for host gaps (tick 37), not for the device.

## 5. (d) Rate change of each candidate, two assumptions

Rate % = ms of one-lane demand a block x R x 26 ms / 16.4 s = 0.16% per unit R per ms (tick 40). "One for one" is R = 5.12 (tick 40's structural ceiling: the device the only constraint). "Freed time only becomes empty time" is R = 0, a floor that tick 40's three estimates (2.0 to 5.6) and the fused encoder's measured +2.95% do not support, so I add the central R = 3.4. The ms for wprod candidates are the six-lane ms (one-lane ms x 0.78).

| candidate (all keep the words) | ms a block | R = 5.12 | R = 3.4 | R = 0 | note |
|---|---:|---:|---:|---:|---|
| all seven products to the CPU | 13.5 | +10.9% | +7.3% | 0 | costs 62 thread-s a request; infeasible |
| gate, up to the CPU | 7.4 | +6.0% | +4.0% | 0 | 750 thread-ms a block each; infeasible |
| K, V to the CPU | 1.4 | +1.1% | +0.75% | 0 | host cost -0.2% to -2.1%: net about 0 |
| NTT traffic-floor kernel (tick 23, at most 3 ms) | 3.0 | +2.4% | +1.6% | 0 | same device |
| commit hash, half cut (ASSUMED) | 1.9 | +1.6% | +1.0% | 0 | no kernel idea listed |
| wprod K, V and Q, AO at 6 T fp32 (ASSUMED; they run at 1.1 and 4.1 T at six lanes, gate/up at 6.5) | 2.4 | +1.9% | +1.3% | 0 | launch-bound small products |
| fused encoder (landed, E1) | 4.1 to 7.9 | | +2.95% measured | | already in |

**Rank, by what could come off the device at a net gain:** (1) commit NTT kernel time, up to 3 ms and +1.6% at central R; (2) the small sealing products' kernel time, about 2.4 ms and +1.3%; (3) the commit hash. All are below 5% and not scheduled. Relocating device work to the host loses on every product. The opposite direction (host to device) is the one that has won: A4 (x1.30), A35, and the composed bundle; tick 25's remaining host pool for the sealing pass is 0.667 s (histograms, limb planes), whose device cost I have not priced.

## 6. Falsifiable tests (not scheduled)

- **T-mode (no run, a script on retained traces, or one traced one-lane leg):** if the slow mode follows the GPU's performance state, then in the six-lane leg-2 trace the slow share of gate/up should rise with idle time before the buffer; pass at 3 times the fast share for gaps over 50 ms, kill at equal. Gives the cause before anyone writes a kernel.
- **T-wp (kernel alone, guard class gpu, one minute):** the four wprod shapes, 100 reps each, warm; pass for a kernel project: K, V at or below 0.4 ms a buffer with byte-identical output (now 1.0 at six lanes), kill at 0.8 or more.
- **T-cpu (nothing to run):** K, V on the CPU is rejected by section 2's arithmetic unless the lane gets more than five threads in the sealing pass; test it only if tick 30's spare cores are claimed elsewhere.

## 7. Honest expected effect, risks, not verified

Committed words: 0 from this reading. Proved tokens per second: no change; the ranking prices candidates at +0.75% to +2.4% each at R = 5.12, none above the 5% rule. Risks: R is fitted at one operating point and for prover ms (tick 40's own limit); the CPU rate comes from A4's 8B shapes, 85 ms, at 32 threads with perfect scaling assumed, and the 8B down width is unknown; the six-lane wprod figures are one leg and mix in the 5% slow buffers; the 6 T fp32 target for the small products is an assumption (A4 reached 5.6 T on the whole witness, 6.5 T on gate/up here); the wprod-to-product mapping is inferred from shapes; `wprod` start-up buffers (`t=65`) are in the one-lane table (0.00%); this trace has the fused encoder off, so the commit lines are the pre-E1 ones. Not verified: why the slow mode appears, whether it exists on the 5090, and whether the sealing pass can use more than five threads.
