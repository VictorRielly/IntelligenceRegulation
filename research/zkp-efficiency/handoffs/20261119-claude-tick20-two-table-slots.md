# Research handoff: which device sumcheck slots are plain two-table sums, and what G1 can touch (2026-11-19 UTC, claude-tick 20, queue item 36)

From Claude, the standing researcher. Triage material, not a work order.

**Question.** Tick 19 left G1 (INT8 tensor-core slabs for round-0/1 sumcheck and Gram folds) with one open target: the plain two-table degree-2 sums among the 12 device slots. How many GPU ms do they hold, at W16R2_8B and at the Shieldstral profile (R13_SHIELD)? Rule set by the queue: under 5% of block GPU, drop G1; over 15%, tick 19's bench T1 is worth a GPU slot.

**What was read and how.** Local only, no web. Full: `results/zk60_slot18_14_breakdown_20261117/README.md` (sections 1 to 2) and `summary.json` (the per-slot batched and unbatched medians, and the `census` block); the raw logs `raw/w16r2_8b_armA_prod_batched.log` and `raw/r13_shield_armA_prod_batched.log` (the `PB-SLOTSTEP` host lines); `private_block/layout.rs` (slot constants, `SLOT_KINDS`, `HOSTS`); `private_block/timing.rs` (slot classification); `slot_ir.rs` (grep of the hosted terms only). Script: `20261119-claude-tick20-two-table-slots.py` (standard library; reads `summary.json` and the two logs; every number below that is DERIVED comes from it). Labels: COUNTED (file), MEASURED (record), DERIVED (script).

## 0. Headline

1. **G1 has no target among the sumcheck slots.** The plain two-table degree-2 slots on the device are only 21 and 22 (the two endpoint equalities), plus 20 (zero-sum row) at the Shieldstral profile. Their share of block GPU is **1.93% batched / 0.68% unbatched at W16R2_8B** and **1.12% / 0.33% at Shieldstral** (DERIVED). Far under the 5% line: **drop G1 as a sumcheck-kernel project.**
2. **The matmul claims, which one would expect to be the f g inner products, are not on the device at all.** The nine private matmul slots (5 to 13) have cubes of 2^10 to 2^14 and run on the host: 0.001 s or less each, 0.012 to 0.015 s together per block in the logs (MEASURED, rounded to 1 ms per phase; one outlier pass 0.038 s at Shieldstral). Zero GPU ms.
3. **Even the generous reading stays under the line:** counting every device slot with at most four tables and degree at most 3 (slots 0, 1, 4 with the endpoints) gives 5.93% batched / 1.85% unbatched at 8B and 3.26% / 0.98% at Shieldstral (DERIVED). Those slots are products with an eq wrapper (degree 3), not inner products, and tick 19 showed the paper does not tensorize degree 3.

## 1. The slot table (MEASURED medians; ms per block)

Block GPU: 117.285 ms (8B), 248.899 ms (Shieldstral) [README section 2.1]. "A" is the production batched arm, "B" the unbatched arm with tables synced (useful kernel work, no batch barrier gap).

| Class | Slots (tables, degree) | 8B A / B ms | 8B share A / B | Shield A / B ms | Shield share A / B |
|---|---|---|---|---|---|
| Plain two-table degree 2 (P2) | 21, 22 (3 tables with one linear node = eq times a difference, degree 2); Shield also 20 (2 tables) | 2.259 / 0.796 | 1.93% / 0.68% | 2.790 / 0.818 (slot 20 has no arm B figure; 0.510 batched only) | 1.12% / 0.33% |
| Degree 3, 2 to 4 tables (P3) | 0, 1 (2 tables, eq wrapper), 4 (4 tables) | 4.691 / 1.368 | 4.00% / 1.17% | 5.336 / 1.620 | 2.14% / 0.65% |
| Four-table degree 4 | 3 (limb zero-check, cube 2^14) | 1.209 / 0.239 | 1.03% / 0.20% | 1.171 / 0.237 | 0.47% / 0.10% |
| The big zero-check slots | 14, 15, 16, 17, 18 (and 19 at 8B) | 55.270 / 42.484 | 47.12% / 36.22% | 88.656 / 76.054 | 35.62% / 30.56% |

Notes. (a) The census block in `summary.json` is for profile R13_8B, whose big-slot table counts (63, 27, 27, 28, 29) differ from the timed W16R2_8B slots (36, 15, 15, 19, 19, from the slot labels); I took table counts and degrees from the timed labels and used the census only for the small slots, whose shapes agree (COUNTED). (b) The matmul slots appear in the census with cube 12 and two tables, degree 2 (slots 5, 6, 7, 10, 11, 12, 13 at 2^12 or 2^14) or three tables, degree 3 (the bilinear score and PV slots at 2^10); the device list has no slot between 4 and 14 (README 2.2, `summary.json` slot lists). (c) Slot 2 (norm squares, cube 2^7) is also host-side.

## 2. Why the P2 slots are not a tensor-core target either (DERIVED)

- Slot 21 at 8B: round 0 takes 0.043 ms (MEASURED, arm B). Its first read is 3 tables x 2^19 x 16 B = 25.2 MB, which at the measured copy roofline of about 700 GB/s (K0) is 0.036 ms: round 0 is already at the roofline (the 16 B stride overstates it, because 2 of the 3 tables are base-typed).
- Rounds 5 onward take 0.021 to 0.025 ms each, the dispatch floor the README reports (rounds 5 to 13 "hitting a ~135 us per round dispatch floor" at batch level). That is latency, not arithmetic, so tensor cores cannot reduce it.
- The whole slot is 0.29 to 0.41 ms unbatched; the batched figure (1.12 to 1.14 ms) is mostly the M6 barrier gap that tick 17 sized (about 0.7 ms of extra device rounds plus transcript steps per slot at degree 2, 0.06 to 0.07 ms per round). Neither part is a matrix-multiply shape.

## 3. Effect and a test

- **Committed words per request:** 0 (no protocol change was proposed).
- **Proved tokens per second:** none. An infinitely fast tensor-core implementation of the P2 slots removes at most 0.796 ms of 117.285 (0.68%) at 8B, and at most 2.259 ms (1.93%) if the batch barrier were also removed by it, which a tensor kernel would not do (DERIVED). The stream is paced by the zero-check bodies (tick 15), which G1 does not address.
- **Decision for the coordinator:** G1 as written (round-0/1 sumcheck slabs) and tick 19's test T1 should not be scheduled. A narrower tensor-core question remains outside the sumcheck slots: whether the witness pass (integer matmuls producing the cells) can run on integer matrix hardware (queue item 5), which this count does not touch.
- **Falsifiable check on this conclusion (local, cheap).** If a profile ever puts the matmul claims on a larger cube (a bigger model, or a layout that proves the matmuls as one 2^24-term sum instead of a 2^12-term sum after binding rows and columns), recount: the P2 share would be reproduced by `20261119-claude-tick20-two-table-slots.py` on the new `summary.json`, and G1 reopens if it exceeds 15%. For the shipped profiles nothing needs to be run.

## 4. Risks and what was not verified

- The classification of slots 21 and 22 as "eq times a difference" is from table counts and one node in the census (3 tables, 2 base, 1 node, degree 2), not from reading the generated kernel; if the engine treats eq as a factor the shape is still a two-factor sum. I did not read `slot_ir.rs` past the hosted-term lines.
- Slot 20 has no unbatched figure at Shieldstral, so the Shieldstral B share of P2 excludes it (0.51 ms batched; adding it as 0.4 ms would make 1.2 ms, 0.5%).
- Host-side matmul time is rounded to 1 ms per phase in the logs: 0.012 to 0.015 s per block is a bound of roughly plus or minus 0.014 s on 27 phases. Whether those 14 ms per block (0.45 s per request over 32 blocks, DERIVED) lie on the stream's critical path was not checked; the stream is GPU-paced per the A33 record, so I take them as hidden.
- The census profile mismatch (R13_8B against W16R2_8B) means table counts for the big slots in `summary.json` should not be quoted for W16R2_8B.
- Any kernel change would need an exact-equality gate and a new profile version; none is proposed. The 2026-11-09 shelving of size work stands.
