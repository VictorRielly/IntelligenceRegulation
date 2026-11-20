# Research handoff: what to time for the line-value and delayed-reduction ideas, and what A27 had already timed (2026-11-18 UTC, claude-tick 12, queue item 25, H158 / H159)

From Claude, the standing researcher. Triage material, not a work order.

**Scope.** Local reading only: `results/zk60_a27_app_20261107/README.md`, `kb1.log`, `kb1.sh`, `kbench/main.rs`, `kbench/gen.py`, the slot 18/14 breakdown README (`results/zk60_slot18_14_breakdown_20261117/`, Antigravity, read as written; I did not check its raw traces), `metal.rs:2225-2260`, `metal_kernels.metal:15-64`. I ran `gen.py` on the two A26 dumps (counts only, no GPU) and one standard-library script (`20261118-claude-tick12-kbench-spec.py`). 0 searches, 0 fetches. No build, proof, GPU run or Git. A kernel-only change that computes the same field elements needs no ruling. Labels: COUNTED, MEASURED, DERIVED, ASSUMED.

## 0. Answer

**Correction to tick 10, and it changes the verdict on H158.** Tick 10 listed "line values by additions" as the largest share left (12 to 21% of the later-round kernel) and wrote that the kbench dumps were A26 so the test was open. A27 had already timed exactly that variant, `gen.py` kernel `k_v2` (`ln_ext_s`, an add chain for `lo + d (hi - lo)`), in `kb1.log`, and its README says so in one sentence: "line values by additions ... help the old kernels but add nothing on top of the materialization" (`README.md:167-169`). I did not read that sentence in tick 10. The tick 10 numbers for H158 (12 to 21% after A27) are **withdrawn**; the measured number after A27 is about 0.

**MEASURED, `kb1.log`** (R13 Shieldstral slots, random extension tables, GPU timestamps, best of 3, all later rounds from cap/4; timing only, sums not compared). `v3` is A27's materialization of the linear nodes (the same four extra tables the real slots keep, README section 2.1), `v13` adds the attained degree (np 4), `v123` adds the add chain on top:

| slot | v0 old | v1 (np 4) | v2 (add chain only) | v3 | v13 (= A27 as shipped) | v123 | v123 against v13 |
|---|---:|---:|---:|---:|---:|---:|---:|
| 14 (64 tables, 2^19) | 43.2 ms | 34.7 | 30.1 (-30%) | 16.1 | 14.1 | 14.0 | +0.7% |
| 18 (29 tables, 2^21) | 30.6 ms | 25.2 | 26.3 (-14%) | 17.2 | 14.3 | 14.4 | -0.7% |

**So the add chain gave 14 to 30% on the old kernel and 0 on the kernel that shipped.** The 16 and 17 ms that the A27 code comment records for the real slots (tick 10 cites `metal_slot.rs:159-161`) equal `v3` (16.1, 17.2); `v13` adds the attained-degree saving (14.1, 14.3).

## 1. Why it did nothing: the kernel is no longer limited by multiplications

- COUNTED (`gen.py`, A26 dumps): slot 14 body 502 products per point and 64 line-value tables in v0; 297 and 67 in v3. Slot 18: 222 and 29; 149 and 32.
- DERIVED (script part 2): the line values are 13% of multiplications in the old kernel and 18% in v13 (np 4, d >= 2 only, two products per extension table). The add chain removes at most those, so a 0.7% change in v13 cannot be a multiplication saving: the product count is not what the kernel waits on.
- DERIVED (script part 3): in the first later round of v123 the logical loads are 856 MB (slot 14, 204 GB/s) and 1.66 GB (slot 18, 291 GB/s), against 285 MB and 554 MB of distinct data (68 and 97 GB/s). Both are well under the machine's peak, so this is not simply a bandwidth ceiling either; what is left is load latency, cache behaviour and the occupancy of a kernel holding up to 68 extension tables per thread. The breakdown README says rounds 0 to 3 run "at 100% 40-core DRAM saturation" (section 4); that is its inference, with no counter reading in the file, and the numbers above do not support saturation. **I do not resolve this: it is the open question, and it has a cheap test (section 3, test K1).**
- Unexplained and flagged: in the old kernel the add chain saved more than its multiplications explain on slot 14 (30% for 13% of the products; ratio 2.3 to the average body product) and about what they explain on slot 18 (14% for 14%, ratio 1.0). A kernel with 64 live extension values may be register-bound there. Treat the apparent gl_mul cost as unknown.

## 2. Consequences for H158, H159 and the tick 10 estimate

- **H158 (add-chain line values): dead on the shipped kernels** at this shape, by A27's own measurement. Not worth a lane. Remaining exposure: round 0 (base tables, `k_sc_round0`) and the 8B shape (36 tables, base-heavy, np 4), neither timed with a v2 variant. Round 0 is 30% of slot 18 (6.4 ms of 18.6 ms, breakdown README Arm B), so a v2-style variant for round 0 is the one unmeasured place the idea could still show; I rate it low, because the same reasoning applies.
- **H159 (delayed reduction): no evidence, and the same warning.** It reduces ALU work. v13 against v123 says removing a quarter of the multiplications (in a kernel whose line values were 18%) did nothing, so removing reductions from the body should not be expected to pay either, unless the effect is on register pressure. tessera's 20 to 31% was a CPU result. Downgrade my guess of 5 to 15% to **about 0 to a few %**, ASSUMED from this analogy; not a measurement.
- **Tick 10's central 15 to 25% and x1.08 on P for the two ideas together: withdrawn.** They were derived from a multiplication model that this record contradicts. Candidate B and the kernel traffic ideas (Antigravity's H133, H134, H135b, which cut loads and writes rather than arithmetic) are untouched; the evidence above favours them over arithmetic ideas.

## 3. What an owner or Sol lane should time instead (specification, nothing run)

All on the existing `kbench/` (one guarded gpu-class job, quiesced box, under a minute each; `main.rs` already times per round with GPU timestamps and takes a kernel name and point count). The A27 dumps are A26-era but the A27 kernel is reproduced by `v13`, so no new dump is needed for K1 to K3.

- **K1, roofline of v13 (the discriminating test).** Add one kernel to `gen.py` with the same loads (all `ln_ext` for the same tables and points) and a trivial body (xor the loaded words into `out`). Time it with the same arguments. **If it is within about 20% of v13:** the later rounds are load-bound, every arithmetic idea is dead, and only traffic changes count (H133 and the fused fold). **If it is under about half of v13:** the body still costs and a delayed-reduction or product-count change can win up to the difference (the ceiling is the gap, stated before trying anything).
- **K2, loads once.** The same body in a kernel that loads each pair's lo and hi once per thread group and loops the points (np 4 in one thread, or SIMD-group shuffles). Pass: at least 15% below v13 on slot 14 and 18 with bit-identical `part` buffers (the host's replay already refuses any difference). This is H133 in its smallest form, and it separates load re-reads from the first touch.
- **K3, occupancy.** Time v13 with the registers per thread limited (Metal function constant or a smaller threadgroup size; `main.rs` already caps the threadgroup at 64). A large change names register pressure as the limiter.
- **K4, gl_mul against gl_add (only to settle the assumed ratio).** A kernel with eight independent accumulator chains per thread, one op each (`gl_add` of two loaded words; `gl_mul`; `f2_mul`), 2^20 threads, 64 ops per thread repeated 16 times, results written so the compiler keeps them; report ns per operation at full occupancy and a dependent-chain latency run. `mul_64x64` is four 32-bit multiplies plus a reduction of about a dozen 64-bit steps (`metal_kernels.metal:36-64`); 64-bit integer operations are emulated on this GPU, so `gl_add` is not free either. Pass: a ratio for the planner; the number matters only if K1 says arithmetic still counts. **Skip K4 if K1 passes the first branch.**
- **Order K1, K2, K3, K4.** K1 is a one-kernel change to `gen.py` and decides whether K4 and H159 are worth a tick at all.

## 4. Falsifiable test in this project's terms

H158/H159 on the shipped kernel: **K1 first branch (roofline within 20% of v13) kills both.** Their pass condition (tick 10: 10% on slot 14 with identical `part` buffers) cannot be met if K1 shows the body is not the cost. The older kill condition (under 5%) is already met for H158 by `kb1.log` (+0.7% and -0.7%).

## 5. Honest expected effect

- **Committed words per request: none.** No proof byte, verifier, profile or Lean statement changes for any item here.
- **Proved tokens per second.** H158 and H159: about **x1.00** on the shipped kernels (was x1.04 to x1.14 in tick 10, withdrawn). Slots 14 to 18 remain 49.5% of the prover GPU union (STREAM_GPU_PHASES.md section 4), so a kernel-load change (K2) that cut a quarter of those slots would be about x1.07 on P if GPU-bound; that estimate is Antigravity's H133 territory, DERIVED, not measured.

## 6. Risks and what was not verified

- `kb1.log` used random tables at the R13 Shieldstral shape (A26 dumps; v3 reproduces A27's four materialized tables, matching "slot 14 keeps 4 ... slot 18 4" in the A27 README). The 8B shape (36 and 19 tables, mostly base-field) was not benched. The log says timing only: sums were not compared.
- The v2 variant used an add chain, not a table of `d` multiples or a shifted representation; other implementations of cheaper line values were not tried.
- I did not verify the A27 README's statement against the code path of `ln_ext_s` beyond reading `gen.py`'s prelude (`gen.py:199-208`), nor that the shipped slot kernels still use `ln_ext` with `dd` (`metal.rs:2247-2260` do).
- The bandwidth figures count only table loads, all as 16-byte words (real base-field tables are 8 bytes), and take the round-1 shape; they are arithmetic on the log's own times.
