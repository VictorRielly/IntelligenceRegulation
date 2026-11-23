# Research handoff: thread-group memory of the device kernels behind tick 40's top ten, and two allocation-ladder tests (2026-11-23 UTC, claude-tick 46, queue item 75)

From Claude, the background researcher. One bounded cycle: local source reading and arithmetic, one web search (summary only, no page fetched). No run, no build, no Git. **Triage material, not a work order.** Every test below keeps the committed words and the output bytes; any kernel change that follows is a speed-lane decision, not a protocol one.

**Read, and how.** In full: the queue item; tick 40's handoff; tick 41's section 4 (T-occ); the coordination entries of 07:19:57Z and 07:33:43Z. Code, by line: `metal_kernels.metal` (all `threadgroup` lines; `k_ntt_head_t` 266-366, `k_ntt_tail` 381-465, `k_inv_fwd_fused_t` 606-822, `k_fold_sparse_partial` 938-990, `k_sc_fs_step` 1433-1475, `k_sc_part_reduce` 1572-1590); `metal.rs` (`encode_ntt` 440-475, spfold 1829-1960, round dispatch 4100-4125, transcript-step dispatch 4566-4643, `HL_METAL_SC_TG` 3261, wprod 4818-4984); `private_block/metal_slot.rs:355-478` (the generated round kernels). Script `20261123-claude-tick46-tg-memory.py` (standard library, `-I -B`) prints every figure. Labels: COUNTED (file:line), MEASURED (record cited), DERIVED (script), ASSUMED, [search summary].

## 1. Result of the reading

**The zero-check slots hold no thread-group memory at all.** The generated kernels `k_sc_round0` and `k_sc_round` take only `thread_position_in_grid` and device buffers (`metal_slot.rs:364, 446`); no `threadgroup` array, no dynamic `threadgroup(0)` argument, no barrier (COUNTED). They run in groups of `min(pipeline max, HL_METAL_SC_TG = 64, grid)` threads (`metal.rs:3261, 4123`). So slots 14 to 18, 54% of demand in tick 40's table, cannot be limited by the *thread-group allocation* as the sparse fold was; what they hold per thread is registers (up to 41 tables as `fp2` locals plus the body's temporaries, `metal_slot.rs:458-466`). Tick 12's K3 and tick 15's K3b/K5 already pointed there ("register pressure and occupancy"); no register, spill or occupancy counter has been read for them (k0k1 README, "Not verified").

**Table (COUNTED; script).** Bytes of thread-group memory one group holds, threads per group, bytes per thread:

| kernel (tick 40 / 42 role) | B per group | threads | B per thread | barriers per launch (COUNTED) |
|---|---:|---:|---:|---|
| `k_fold_sparse_partial` A, k = 37 (spfold 2504; 4.18 ms) | 18,944 (dynamic, `k*32*16`, `metal.rs:1829`) | 32 | 592 | 0 |
| same, H, k = 10 (1.85 ms) | 5,120 | 32 | 160 | 0 |
| `k_inv_fwd_fused_t` (the production commit NTT, `frs=1`) | 16,384 (static `sh[TILE]`, line 626) | 512 | 32 | 18 at rate 2, 30 at rate 4 |
| `k_ntt_head_t` (non-fused path) | 16,384 (line 281) | 512 | 32 | 7 (6 pruned) |
| `k_ntt_tail` | 16,384 (line 391) | 512 | 32 | 2 to 3 for G = 1 to 4 |
| `k_sc_fs_step` (transcript step) | 4,224 (`red[512]` + `tot[16]`, lines 1440-1441) | 256, ONE group | 16.5 | 10 per point: 40, 50, 60 per round at d1 = 4, 5, 6 |
| `k_sc_round0` / `k_sc_round` (slots 18, 14, 17, 15, 16, 0, 19) | 0 | 64 | 0 | 0 |
| `k_sc_part_reduce`, `k_fold_tables_dev3`, `k_hash_cols`, `k_gather_cols` | 0 | grid-wide | 0 | 0 |
| sealing products (`k_wprod_sg_*` / `k_wprod_int`; outside tick 40's list) | 26,624 / 16,384 | 256 (scratch size implies 8 SIMD groups; `WP_THREADS` value not printed) | 104 / 64 | not read |

Fused barriers: 7 before the sub-tiles plus 5 per sub-tile and one between (lines 638, 667, 683, 699, 778, 805, 819); the step-2 loop bound is taken as four passes from the comment, not read. `k_sc_fs_step` barriers: one after the per-thread sum, eight for the 256-wide tree, one after the total, per point, points serial (COUNTED; this is the barrier part of item 35 only; its loads, BLAKE3 compressions and part-reduce counts are not done, so item 35 stays).

**Rank by bytes per group against device time.** (1) The sparse fold, already decided by T-occ (MEASURED, coordination 07:19:57Z: 6.057 ms at 18,944 B against 1.861 ms at 5,120 B; ratio 3.255 for an allocation ratio 3.700, **elasticity 0.90**, DERIVED). It is 4.2% of D1 (98.5 ms). (2) The NTT kernels: 16 KB per 512-thread group, about 22.3 ms of a block (forward 14.0 + inverse 8.3, tick 21's diag split) = **22.6% of D1**, and 16 KB is within the 18.9 KB that slowed the fold. Per thread they are 18 times lighter than the fold's A group (32 against 592 B), so whether they are limited depends on whether residency counts groups or bytes: **not known**. (3) The transcript step holds 4.2 KB in one group on a GPU of many cores; residency is irrelevant for it and tick 17's latency reading (0.138 to 0.145 ms per round, 40 to 60 barriers) is the topic. (4) Everything else holds none.

## 2. What is not known

- The GPU's resident-group limit and the size of the pool a group draws from. The code clamps dynamic memory to `min(max_threadgroup_memory_length, 32 KiB)` (`metal.rs:1829-1832`), which suggests 32 KiB per group; the per-core pool is not stated anywhere I read.
- [search summary] Apple's description of the M3 family's Dynamic Caching is that registers, thread-group memory and cache share one on-chip store with occupancy lowered automatically when it is exceeded; I read only a search summary of Apple's tech talks and an AppleInsider piece, not the pages, and found no Metal call that reads occupancy. If true, an unused allocation costs the pool the kernel's registers also need, which fits T-occ (an unused allocation slowed H 3.25 times) and means the zero-check kernels' registers and an NTT group's 16 KB compete for the same store. ASSUMED until measured.
- Retained logs print "max threads/group 1024 / 1024" 3,714 times (the diag line, `metal.rs:4217-4226`); I could not find the files within the time I allowed, so I cannot say which slots they belong to. It is a driver cap, not an occupancy reading.

## 3. Test N-occ (the NTT group), for Antigravity's speed lane

Same kernel, one extra unused dynamic argument, unchanged output. In a bench copy of `k_inv_fwd_fused_t` (instance `k_inv_fwd_fused_r1`, rate 2, the production A and H shape: 2^14 data words, q = 280, rows 2,504) add `threadgroup ulong *pad [[threadgroup(0)]]` and call `set_threadgroup_memory_length(0, L)` with L = 0, 4,096, 8,192, 16,384 (total 16 to 32 KiB, the 32 KiB limit). The capture is the A commit's input (`FOLD_CAPTURE`-style, or kbench). Time = buffer `gpu_end - gpu_start`, median of 20, alone on the GPU, class gpu through the guard, seconds. Output hash must equal L = 0 for every L. r(L) = t(L)/t(0).

Lines, written before any count:
- **Allocation sets the NTT time (go): r(16,384) >= 1.30.** Then halving the group's memory could save up to 22.3 x (1 - 1/r) = 5.1 ms at r = 1.30 (5.2% of D1, 7.4 ms at r = 1.50; DERIVED, ASSUMED symmetric), the line where the 5% rule is met; the next step is a smaller-tile variant, specified then.
- **Not limited (stop): r(16,384) <= 1.15.** Ceiling 2.9 ms (3.0% of D1) or less; no NTT occupancy project.
- Between: add the 4,096 and 8,192 points, report the slope; no project below 1.30.

## 4. Test Z-occ (the zero-check round kernels), same kind, a different dial

The kernel has no allocation to shrink, so the ladder measures how many resident groups it needs: the same unused `pad` argument on `k_sc_round` (bench copy in the k0k1 harness, `results/zk60_k0k1_roofline_20261118/`, v13 and its exactness check `check_v13_same.py`), slots 14 and 18 at the 8B shapes, later rounds as K1 timed them, L = 0, 2,048, 4,096, 8,192, 16,384, 32,768 B per 64-thread group (= 0, 32, 64, 128, 256, 512 B per thread, overlapping the fold's measured 160 to 592). Output words equal to L = 0 for every L; median of 20 per round; r(L) as above.

Lines, written before any count:
- **Resident-group limited (the occupancy half of "body and occupancy" is confirmed): r(16,384) >= 1.25** at either slot. Record the knee L* (smallest L with r >= 1.10). The reading is then that the pool binds the kernel and the lever is its live-register footprint, which the four-way split (H162, measured 0.91 and 0.97 of v13 at the 8B shapes) already pulled; the test adds a mechanism and a bound, not a new gain, and I do not propose a rewrite.
- **Not group-count limited: r(32,768) <= 1.05** at both slots. Then the occupancy half of tick 12 and 15's reading loses its support for these kernels at these shapes; what is left is dependent-chain latency inside a thread (tick 15 measured 347 ns per extension multiply), the K9 and item 35 topic.
- Between: report the knee only.
- Upper bound for orientation: slots 18, 14, 17, 15, 16, 0, 19 are 60.0 ms of D1 (60.9%, one lane, DERIVED from tick 40's table); a ladder ratio of 1.10 at 32 KiB would put at most 5.5 ms there if all of it were removable. It is a bound on what a pool-pressure story could explain, not an estimate of a gain.

Both tests are cheap, byte-identical by construction (an argument the kernel never touches) and answer one question each. The caveat shared by both: T-occ's unused allocation slowing H shows the effect exists for that kernel; it does not show that lowering an allocation speeds a kernel up, which is why N-occ's go line is stated on the raising slope with an ASSUMED symmetry.

## 5. Honest expected effect

Committed words: none. Tokens per second: no change from reading. Everything above is a ceiling or a pre-registered test. At the exchange rate of tick 40 (0.3 to 0.9% of rate per one-lane device ms), the NTT go line (5 ms) is 1.5 to 4.5% of rate at best, and it needs a smaller-tile NTT that does not exist and must keep the same words.

## 6. Risks and what was not verified

Source reading only: no pipeline's registers, spills, `static_threadgroup_memory_length` or residency were read from the device. The NTT figure uses tick 21's 8B diag split against tick 40's one-lane D1 (a different harness; ratio 22.6%). The wprod row is by the declarations, not read for use. The barrier counts for the fused kernel rest on the comment for the loop bound. The M3 dynamic-caching statement is from a search summary. Item 35 is not covered beyond the barrier count. The queue's closing request, "do not propose a kernel rewrite before a test has confirmed the limit for that kernel", is kept: none is proposed.

Sources: [Apple tech talk 111375](https://developer.apple.com/videos/play/tech-talks/111375/), [AppleInsider summary](https://appleinsider.com/articles/23/11/10/what-apples-three-gpu-enhancements-in-a17-pro-and-m3-actually-do) (search results only, not fetched).
