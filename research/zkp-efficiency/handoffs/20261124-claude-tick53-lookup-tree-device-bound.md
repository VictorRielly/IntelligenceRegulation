# Research handoff: device time of a masked LogUp-GKR lookup tree on Metal, bounded from kernels already measured (2026-11-24 UTC, claude tick 53, queue item 87, H136b)

From Claude, the background researcher. One bounded cycle: local reading and arithmetic only, 0 searches, 0 fetches. No run, no build, no Git. Clock at writing 2026-11-24T07:55Z. **Triage material, not a work order.** Any change to what is committed alters proof bytes and the verifier and needs the owner's ruling, a new profile string (D17) and re-proved Lean (D63). Proof-size work is shelved (2026-11-09); this concerns prover time under D80.

**The question.** Tick 52 found that candidate A (lookups with no committed helpers) reaches the stream only through the commits, at most 9.8 to 10.3% of the 3.7455 s cadence, and that the deciding unknown is what the tree itself costs on Metal (cycle 6a's ESTIMATE 0.040 to 0.105 s a block). Item 87 asks for layers, evaluations, and a low and a high bound from kernels that exist, with a pass line (high under half the saving), a kill line (low above the saving) and a "between" reading.

**Read, and how.** In full: the 2026-11-01 prototype's `README.md`, `projection.py`, `projection.json`, `ZK_DESIGN_NOTE.md` (sections 2 and 4); `results/zk60_k0k1_roofline_20261118/README.md`, `k5_analysis.txt`, the raw `k5_timing.log` (per-round medians, parsed by the script) and `build/k5_b14.json`, `k5_b18.json`; `results/zk60_k9_sc_chain_20261123/README.md`; tick 40 section 1 (slot times at the app profile), tick 52 sections 0 and 4. Code in the tree that runs (`ops/zkp-mvp/gpu-metal/hashline/src/gpu/metal.rs`): `TAIL_ROUND_BUDGET_S` 4618, the host-tail switch 4750-4775 (a round runs on the host when pairs x points x one host evaluation is under 250 microseconds). Not read: `metal_kernels.metal` round kernels beyond what the K5 builds quote. Script `20261124-claude-tick53-lookup-tree-device-bound.py` (standard library), output `.out.txt` beside it.

Labels: **MEASURED** (record), **COUNTED** (file), **DERIVED** (script), **ASSUMED**, **[prototype]** carried.

## 1. The tree (COUNTED from the prototype, DERIVED here)

One tree of 2^25 leaves per block (32,276,480 lookups, table entries, pads, two blinding leaves). Sumcheck layers k = 24 down to 1, k rounds each: **300 rounds** [prototype]. In layer k the tables are p(x,0), p(x,1), q(x,0), q(x,1), all Fp2 except the leaf layer, where p is 1 and the leaves are base words in the first two rounds. Round j has 2^(k-1-j) pairs, three evaluation points (degree 3; s(1) recovered), each q1 (p0 + lambda q0) + p1 q0 times a split eq: 3 extension products a point, 9 a pair, plus 4 for the fold of four tables: **13 per pair** (DERIVED; 6.5 ASSUMED for the leaf layer). Layers 24 and 23 hold 218 M of the 327 M top-down extension products (67%); the bottom-up build adds 3 per stored node. Structural total 428 M against the prototype's COUNTED 349 M (10.4 per leaf); the low bound uses 349 M. Bytes: 180 B per pair, 6.0 GB, [prototype] COUNTED.

Rounds on the device: the host-tail line moves a round to the host when its host cost is under 250 microseconds; for a 4-table polynomial (about 0.15 microsecond per evaluation, ASSUMED) the line sits between 2^10 and 2^13 pairs, so **66 device rounds (2^13 line, the prototype's count) to 105 (2^10 line)**, 195 to 234 host rounds, and 24 layer hand-offs, one device-to-host chain break per layer because layer k's claim comes from layer k-1.

Masked rounds (ZK_DESIGN_NOTE section 2): each layer's rounds carry a CFS mask `g_k` of k variables, whose partial sums cost O(1) a round inside the transcript step, and one last round of degree 7 (8 points on 2 pairs). No extra bulk work; the cost is the transcript step per round (below) and +48 to +144 M rows, committed early and off the critical path [prototype ESTIMATE 8.6 to 25.9 ms, not in the bounds].

## 2. Rates (MEASURED)

- **Round kernel (v13, W16R2_8B shapes, K5, per-round medians):** slot 18 (21 live tables, 25 + 13 products a point): 29.1 ps per extension-product-equivalent at 2^20 pairs, 42 to 53 ps from 2^19 to 2^14, a floor of 0.118 ms a round from 2^13 down. Slot 14 (39 tables, 40 + 31): 61.5 to 77.5 ps from 2^17 to 2^14, floor 0.21 ms. (Equivalent = f2_mul, f2_mulb at 0.395 [K4], line values counted per loaded table.)
- **K0:** fold and copy at 692 to 704 GB/s. **K4:** an independent extension product costs 23.49 ps; nothing measured reaches it (K3a runs 1.25 to 1.5 times slower than v13 on the same products).
- **Transcript step:** 123 microseconds a round alone (103 at one partial); the merged fast step 85 to 57 (K9 v3). A whole 12-slot, 141-round block chain is 52.5 ms solo, 0.37 ms a round (K9, synthetic slots).

## 3. Bounds (DERIVED, device ms per block)

| | low | absolute floor | high |
|---|---:|---:|---:|
| rate | best measured shape (slot 18) | K4 23.5 ps flat, loads hidden | worst measured shape (slot 14), no overlap with loads, +14% line values (K1b) |
| round floor | 0.10 ms, 66 rounds | 0.057 / 0.10 / 0.123 ms | 0.35 ms, 105 rounds |
| bulk rounds (pairs 2^15 up) | 11.8 | | 38.0 |
| mid and small device rounds | 2.1 | | 21.0 |
| build (23 layers) | 1.9 | | 8.0 |
| layer hand-offs (ASSUMED 0.05 / 0.40 ms) | 1.2 | 0 | 9.6 |
| host tail ([prototype] ESTIMATE 5 / 16 ms) | 5.0 | 0 | 16.0 |
| **total** | **21.9** (15.7 without the two ASSUMED lines) | **12.1 / 14.6 / 16.0** | **92.6** |

The high bound is stacked on purpose (a 39-table kernel's rate on a 4-table kernel, no overlap) and is about the whole block GPU (91.5 ms); it is a limit, not a forecast. A 4-table kernel should beat v13's rates (K5: fewer live tables ran 0.77 to 0.9 of v13), which is why the low bound exists; no GKR kernel has been timed on Metal.

## 4. The saving to set against it (DERIVED)

- **Tick 52's basis:** 9.8 to 10.3% of 3,745.5 ms at the rule of tick 22 (x ms a block is at most x x 32 / 3745.5 of cadence) is **11.47 to 12.06 ms a block**. Cross-check from tick 40's app-profile times: the H commit (12.68 ms, 2,606 rows) falls to 6 rows, the A commit (12.21 ms, 2,504 rows) grows by 0 to 124 rows: net **12.05 to 12.65 ms**. The two agree.
- **Pass line** (high under half): 5.74 ms. **Not passed** (92.6).
- **Kill line** (low above the saving): 12.06 ms. **Fires: low 21.9 ms, and 15.7 ms with the two ASSUMED terms removed.** The absolute floor is 14.6 ms at 0.10 ms a round, 16.0 at the shipped step's 0.123, and 12.1 only with the fast step alone as the round cost and a perfect-rate kernel (K4 rate, loads hidden, nothing else a round costs): equal to the kill line, so the verdict rests on the low bound and not on the floor.

## 5. A flaw in the saving basis (new; for the coordinator)

Tick 52 wrote that volume reaches the stream "only through" the commits. Candidate A also removes the helper tables from the five domain zero-checks (24 of 105 live tables: D 10 of 37, Q 3 of 15, Kv 3 of 15, S 4 of 19, F 4 of 19; DESIGN_NOTE section 3), the table-helper slot 19 (4.03 ms) and H's opening fold (about 4.35 ms by rows from spfold's 4.18 ms at 2,504). From tick 40's slot times (slots 14 to 18: 54.09 ms a block, one lane): **1.4 to 2.4 ms** if only the loads go (K1 load share 0.11 to 0.19 times 24/105), **12.3 ms** if time follows table count (upper), so the left-out terms are **1.4 to 20.7 ms** and the gross saving is **13.4 to 33.3 ms**, not 11.5 to 12.1. Against that, the low-bound tree plus the prototype's leaf-claim terms (9.4 ms, ESTIMATE carried, +1 table-equivalent a domain) is 31.3 ms: **net -17.9 to +2.0 ms a block**, best case 1.7% of cadence at full pass-through. The high bound is far beyond. So the extended basis moves the reading from "killed" to "not above +1.7% in the best case and probably negative", with the helper-table term as the one unmeasured quantity that decides the upper end.

Also: the 2026-11-01 helper-path figure of 0.110 s a block (6a, projection.json) is stale. It was taken against a 0.47 s block; today's helper path (commit 12.65, opening 4.35, zero-check 1.4 to 12.3, slot 19 up to 4.0) is **18 to 33 ms**. Every net figure in 6a (x1.07 to x1.25) rested on it.

## 6. Test that would move the reading

**T-GKR (one-day device prototype, not scheduled).** One kernel for a layer-23-shaped round (4 Fp2 tables, 2^22 pairs, three points, split eq) timed alone with GPU timestamps, plus the fused fold. **Go** only if the full-size bulk rounds (layers 24 and 23, 218 M products) take under 6 ms together (about 28 ps a product with loads) and a layer's small-round chain under 0.06 ms a round; the bounds above then reach about 12 to 14 ms. **Stop** above 8 ms for those two layers. And **T-H** (counting, CPU): remove the 24 helper tables from slots 14 to 18 in the A27 shader dump and time the K5 harness with them dropped (a live-table ladder, 39 to 29 at slot 14), which prices the one unmeasured saving.

## 7. Honest expected effect

Committed words per request: unchanged by this tick (A stays at 0.49 to 0.52 of today's block). Proved tokens per second: **no supported gain from A**; best case +1.7% of cadence at full pass-through under the extended saving, negative at the low tree bound with any smaller helper-term saving. Candidate B's value beside A (tick 52) is therefore not a speed argument.

## 8. Risks and what was not verified

- No GKR kernel exists on Metal; every rate is a v13 zero-check rate or K4. The 4-table kernel's rate could be lower than any figure used here (registers, occupancy), the reason the floor row exists.
- The host tail (5 to 16 ms), hand-offs (0.05 to 0.40 ms a layer) and the leaf-claim terms (9.4 ms) are carried or ASSUMED, not measured. The device-versus-host line for a 4-table polynomial is an ASSUMED host speed.
- The helper-table saving (section 5) assumes the K5 shapes' tables are those of the production slots at W16R2_8B and that tick 40's slot times (the app profile) apply to the 8B block within 2 ms (tick 28).
- Pass-through at full is a ceiling (rule of tick 22); because 29 to 32% of a prove call has no prover buffer executing (tick 22), a smaller share would reach the stream.
- Masked-round cost beyond the transcript step, and the M rows' time, are not in the bounds.

## 9. Status

New proofs, passes, proved positions: **0 / 0 / 0.** The complete private 8B at >= 50 proved tokens/s remains **unachieved**. H136b answered (kill line fires on tick 52's basis; extended basis not above +1.7%); H136c (price the helper tables in slots 14 to 18, T-H) added.
