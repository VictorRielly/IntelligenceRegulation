# Research handoff: census of the shipped later-round kernel body, and where its time over the product floor sits (2026-11-18 UTC, claude-tick 15, queue item 32)

From Claude, the standing researcher. Triage material, not a work order.

**Question.** What does the shipped later-round kernel (`k_v13`) compute per pair and point, why does it take several times what its products cost at full-occupancy throughput (K4), and what collects more of that room than a four-way split?

**What was read and how.** Local only: the generated `k_v13` text in `results/zk60_k0k1_roofline_20261118/build/k5_{s14,s18,b14,b18}.metal` (Shieldstral and W16R2_8B slots 14 and 18, parsed in full, live nodes only), the folder's README (K1, K0, K3/K4 and K5 sections, all read), `analysis.txt`, `k3k4_analysis.txt`, raw `k5_timing.log` (per-round medians recomputed by me), the slot 18/14 breakdown README (floor lines only). Web: 4 searches, 3 page reads (Apple's WWDC "Explore GPU advancements" talk, Rosenzweig's M1 GPU part III, the metal-benchmarks repository). The census script is `20261118-claude-tick15-body-census.py` (standard library, reads files, runs nothing on a GPU). Labels: COUNTED, MEASURED, DERIVED, [published], ASSUMED.

## 1. Census of the body per pair and point (COUNTED, live nodes)

| shape | tables | nodes | ee (data x data / coef x data) | eb (all coefficient) | line values at d >= 2 | f2_add / neg / addb | base mults (3 ee + 2 eb + 2 per table) |
|---|---|---|---|---|---|---|---|
| Shieldstral slot 14 | 67 | 63 | 67 (45 / 22) | 48 | 67 | 103 / 37 / 5 | 431 |
| Shieldstral slot 18 | 32 | 33 | 35 (23 / 12) | 22 | 32 | 48 / 16 / 7 | 213 |
| 8B slot 14 | 39 | 39 | 40 (26 / 14) | 31 | 39 | 62 / 20 / 5 | 260 |
| 8B slot 18 | 21 | 23 | 25 (16 / 9) | 13 | 21 | 26 / 8 / 9 | 143 |

No base-by-base products (bb = 0). Syntactic duplicate products across the live nodes and output terms: **0** at all four shapes (also up to commutation), so idea (c), sharing common subproducts, has nothing to share: A27's node plan already did it, and its linear nodes are already tables. Idea (d), fewer points, is already in (attained degree np = 4, tick 10).

Throughput floor (K4 ps per op times these counts, additions priced at gl_add, line-value sub and add as three gl_add) [DERIVED]: 3.47 / 1.72 / 2.08 / 1.14 ns per pair-point, whole GPU. Tick 12 compared the products alone (K3 note: "18% and 36% of v13") to the total time; that omits additions, line values and, more importantly, the tail (section 2).

## 2. Where the time over the floor sits (MEASURED per-round medians of `k5_timing.log`, 15 reps; sums by me)

Rounds 1 to 5 are the bulk (large pair counts); rounds 6 on are the tail (4,096 pairs down to 1).

| shape | v13 total ms | bulk (r1-5) | tail | tail share | tail per round, ms | G=4 accumulate: bulk / tail |
|---|---|---|---|---|---|---|
| Shield 14 | 14.27 | 9.19 | 5.08 | 36% | 0.391 | 5.60 / 5.45 |
| Shield 18 | 14.27 | 11.34 | 2.92 | 20% | 0.195 | 9.12 / 3.30 |
| 8B 14 | 7.39 | 4.34 | 3.05 | 41% | 0.235 | 3.35 / 3.41 |
| 8B 18 | 8.45 | 6.49 | 1.96 | 23% | 0.131 | 5.86 / 2.30 |
| (K1 loads only, tail per round) | | | | | 0.041 / 0.022 / 0.026 / 0.015 | |

**Bulk against the floor** (floor ns x pair-points of rounds 1 to 5, DERIVED): v13 is 2.60x (Shield 14), 1.62x (Shield 18), 2.06x (8B 14), 1.40x (8B 18) above it; after G=4 it is 1.60x, 1.30x, 1.58x, 1.27x. So the "four to eight times" in the item came from comparing a products-only floor with a total that is 20 to 41% tail. In the bulk the gap is 1.4 to 2.6x, and the split has already taken half to two thirds of it at the big slots. What is left is at most 21 to 37% of the split bulk time, against a floor that K4 built with eight independent chains per thread (optimistic).

**The tail is not the throughput floor and the split does not touch it:** the split kernels take 5.36 to 5.45 ms against v13's 5.08 (Shield 14), run back to back, so G kernels at a quarter of the body each cost the same as one. The best mixed schedule (K5: split in rounds 1 to 5, one kernel after) already gets this: 0.75 / 0.84 / 0.86 / 0.93.

**A law that fits all four shapes (DERIVED fit, my arithmetic):** tail per round divided by base multiplications per point is 0.907, 0.915, 0.904, 0.916 microseconds (Shield 14, 18, 8B 14, 18), within 1.2% across a 3x range of body size. A fixed dispatch floor would not scale with the body; K1 (same loads, no body) is 0.015 to 0.041 ms per round. So a thread that runs the body once, alone on a nearly idle GPU, takes time proportional to the body's code, at about 0.9 microsecond per base multiplication: roughly 14 times K4's measured dependent gl_mul latency (64 ns) and 4 times my instruction-issue estimate (ASSUMED 3 to 6 cycles per dependent instruction [published, M1 family], about 65 lane-instructions per gl_mul from K4's throughput, 128 lanes at an assumed 1.4 GHz). Candidates: (i) instruction fetch, the body is straight-line code far larger than the 12 KB instruction cache [published for the A14/M1 family; no M3 figure found]; (ii) register spills or on-chip register-cache misses (section 3); (iii) a clock state of a lightly loaded GPU. K4's chain latency (347 ns per f2_mul) does not explain it: 67 serial f2_muls are 23 microseconds.

## 3. Registers, published and counted

[published] M1-family: each thread addresses up to 256 half-word registers (128 32-bit words); full occupancy (1,024 threads per core) needs 104 half-words or fewer, 384 threads at 256; register file about 208 KiB per core (Rosenzweig, inferred); no spill needed below 256 half-words. M3 and later: Apple's talk says registers are allocated dynamically over the shader's life, the register file acts as a cache, "the maximum register usage no longer dictates how many SIMDgroups can be run", and the core lowers occupancy itself to avoid spilling; it gives no register limit and calls live-register tuning mostly profiler work. No M3 Ultra number was found, so the M1 limits are indicative only.

Live data words at the peak [COUNTED by script, excluding loop state, the 4-word accumulator and about 8 to 14 words of transients in one f2_mul]:

| shape | loads alone | source order (all loads first, then nodes) | depth-first, each table loaded at first use (heuristic) |
|---|---|---|---|
| Shield 14 | 268 | 272 | 112 |
| Shield 18 | 128 | 132 | 76 |
| 8B 14 | 156 | 160 | 80 |
| 8B 18 | 84 | 92 | 56 |

If the compiler keeps the source order (K3a's slowness suggests it hoists loads: tick 15 did not read an ISA dump), the first three exceed 128 words and the fourth fits. K5's split gains (23% Shield 14, 13% Shield 18, 9% 8B 14, 3% 8B 18) follow the same order except that Shield 18 beats 8B 14 although its loads alone are smaller (128 against 156), so this is a loose agreement, not proof. A K3-style rewrite that loads late did not exist in the bench; K5b (grouping inside one kernel, 8 to 26% slower) shows the compiler does not reduce liveness by scoping.

## 4. Ideas with ceilings and tests

- **(a) Splitting:** MEASURED (K5): G=4 accumulate 0.773 / 0.871 / 0.914 / 0.967; the accumulate pass costs 0.2 to 0.7 points. New here only: its whole gain is in rounds 1 to 5.
- **(b) Delayed reduction:** coefficient x data ee are 15% of the Shield 14 floor (517 of 3,470 ps). Even if reduction were half a gl_mul, the saving is at most 7% of the floor, so at most 3% of the bulk time and at most 7% of the tail (if the tail is instruction-bound). Not worth a test.
- **(c), (d):** dead, section 1.
- **(e) Tail by concurrency, K6.** If the tail is one thread's serial time, running the G split kernels concurrently (`MTLDispatchTypeConcurrent`, separate part buffers, no accumulate) should cut a tail round toward 1/G. Test: Shield 14, G=4, tail rounds only. Pass: tail per round at most 0.20 ms (v13 0.391, split serial 0.412); fail: above 0.35. The bench's accumulate arms write the same buffer and would serialize, so use the split arms. Only the table build uses concurrent encoding in the snapshot I saw (`metal.rs:3192`, a2 review copy); the round encoders look serial: not checked in the current head.
- **(f) Code size against dynamic work, K7.** A kernel doing 431 base multiplications' worth of work in a small loop (same dynamic count, a few hundred bytes of code). Pass for the instruction-fetch reading: tail per round at most 0.10 ms; fail (latency or spill reading): above 0.30. One check also separates (i) from (ii).
- **(g) Order test, K8.** `k_v13` with loads placed at first use in the depth-first order of section 3, outputs byte-equal. Pass: bulk at Shield 14 at most 0.85 of v13 (K5's split reaches 0.62); fail: above 0.95, which would mean the compiler reorders anyway.

## 5. Honest expected effect

- **Committed words per request: none.** Kernel scheduling only; same field elements and transcript; no ruling or Lean change.
- **Proved tokens per second:** K5's split already covers the bulk (1 to 3% of block GPU at Shield, about 1% at 8B, coordinator's count). The tail is larger in the bench (0.131 to 0.391 ms per round) than in production (breakdown: 135 microseconds per round at 8B slot 18, 240 at Shield slot 14, 1.48 and 1.68 ms per slot). Even a perfect quarter-length tail saves about 1.1 ms of 117.3 ms of block GPU at 8B slot 18 (about 1%) [DERIVED], so x1.00 to x1.02. I do not see a kernel idea in this item worth more than a few percent; the larger cost left in the evaluation kernels is round 0 and the fold (ticks 13 and 14).

## 6. Risks and what was not verified

- No ISA dump, register, spill or occupancy counter; every reading about registers and code size is inferred. The 0.91 microsecond figure is a fit across four shapes, not a mechanism. The M1 limits are not M3 facts. Floor arithmetic uses K4's whole-GPU ps per op with eight independent chains, probably optimistic. The bench's tail has a different dispatch pattern from production (one command buffer per round).
- The depth-first liveness is a heuristic upper bound on a good schedule, not the minimum; transients and constants are not in it. The coefficient loads `CF(cf, n)` (about 100 to 200 per body) are not separated in any bench: K3a, v13 and the split all read them, K1 and K1b do not; a variant with the coefficients in registers or threadgroup memory is untested.
