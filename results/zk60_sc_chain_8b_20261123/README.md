# K9 fast sumcheck chain (`HL_METAL_SC_CHAIN_FAST=1`, `sc1` vs `sc0`) on the synthetic 8B stream (2026-11-23 UTC): MODEST 8B GAIN (5/6 passes, -2.22% paired median)

By Antigravity. Evaluates the opt-in K9 fast sumcheck dependent chain (`HL_METAL_SC_CHAIN_FAST=1`, arm word `sc1`, off by default: SIMD-in-`k_sc_round` SoA partials eliminating all `k_sc_part_reduce`, `k_sc_fs_step_v3` with scalar-register BLAKE3 + SIMD-parallel mask/interp, and fused `k_fold_tables_dev3_xy` skipping the dead `j == nd` `xtabs` fold) on top of the merged pushed baseline (`serve8+lanes2+ba1+frs1+sf1`) at `W16R2_8B_T128_H24`.

**Pre-posted rule (`ops/zkp-mvp/RECOVERY_COORDINATION.md`, `2026-11-23T13:16:10Z`, before launch):** decision pair `serve8+lanes2+ba1+frs1+sf1+sc1` against `serve8+lanes2+ba1+frs1+sf1+sc0`; primary metric = per-pass steady gap `(c[6] - c[1]) / 5` (`results/zk60_composed_8b_20261123/summary_8b.py`). **PASS AT 8B** if 6/6 passes lower AND paired median `<= -3.0%`; **MODEST 8B GAIN** (still check 6-lane app transfer since `K9d-v3` showed `-25.4%` under 6-queue dispatch contention) if `>= 5` of `6` passes lower AND paired median in `-1.5% .. > -3.0%`; **NO GAIN / KILL** if `< 5/6` OR `> -1.5%`.

## Setup [MEASURED]

- Source commit: `6fd27ebfe` (`agy/sc-chain-opt`, branched from `7ed1278b4`, clean tree).
- Single binary: `.agy-worktrees/sc-chain-opt/ops/zkp-mvp/gpu-metal/hashline/target/release/deps/hashline-62da740d7237a892`, SHA-256 `e6c8a535430446801a600835138eb26a7071acfbad1faf8b9df27094c1544354`.
- Test: `private_block::run::fork::tests::a22::a22_stream_ab`, one process, 2 arms interleaved, 6 passes, alternating order (`HL_D55_AB_ALTERNATE=1`), `W16R2_8B_T128_H24`, `L=32`, `N=6`, `HL_A19_BUDGET_GIB=32`, all switch env vars stripped.
- Guard run: `a6ea7f50165f` (`agy-sc-chain-8b-sc1_vs_sc0`, class `gpu`, `need=80G`, `cap=110G`, `exit=0`, `388.0 s`, `peak_rss=37.95 GiB`, `min_avail=155.52 GiB`, `peak_vram=23414 MiB`, `2026-11-23T13:16:41Z–13:23:10Z`). Quiet host: `/tmp/HOLD` absent, no `ds4-bench`, locks free, 0 subagents running.
- Pass-0 receipts verified: cold 1/1 + pass 0 `sc0` 8/8 + pass 0 `sc1` 8/8 (`818,728,672 B` each).

## Result [MEASURED]

| arm | `(c[6] - c[1]) / 5` gap per pass (s), passes 0..5 | median (s) | 128 / median | `SUMMARY` steady mean (best) | amortized mean (best) | peak footprint (warm max) | CPU (`user+sys` med) |
|---|---|---:|---:|---:|---:|---:|---:|
| `serve8+lanes2+ba1+frs1+sf1+sc0` | 3.246 3.296 3.288 3.284 3.264 3.300 | 3.286 | 38.95 tok/s | 39.52 (39.99) tok/s | 36.10 (36.50) tok/s | 47.5 GiB (47.5) | 397.4 s |
| `serve8+lanes2+ba1+frs1+sf1+sc1` | 3.160 3.254 3.198 3.202 3.272 3.236 | 3.219 | 39.76 tok/s | 40.33 (40.90) tok/s | 35.64 (36.65) tok/s | 50.5 GiB* (47.3) | 393.6 s |

*\*Pass 0 request 0 of `sc1` compiled the 12 `SC_SIMD_SOA` slot libraries cold (`first request 6.608 s` vs `5.693 s`, transient pass-0 footprint `50.5 GiB`) because the `serve1 (cold)` prelude ran with `sc0`. Across all 5 warm passes (passes 1–5), `sc1` had strictly lower peak footprint than `sc0` in 5/5 passes (`45.9, 46.6, 46.2, 47.3, 47.2` vs `46.7, 46.8, 46.7, 47.4, 47.5 GiB`).*

| metric (`sc1` minus `sc0`) | per pass (s) | paired median (s) | % of off median | lower in |
|---|---|---:|---:|---:|
| Primary `(c[6] - c[1]) / 5` (`summary_8b.py`) | -0.086 -0.042 -0.090 -0.082 +0.008 -0.064 | **-0.073** | **-2.22%** (`-2.04%` med-vs-med) | **5 of 6** |
| Secondary `(c[7] - c[0]) / 7` (3-dec `REQ`) | -0.064 -0.046 -0.127 -0.099 +0.014 -0.064 | **-0.064** | **-1.98%** (`SUMMARY` steady `+2.05%`) | **5 of 6** |

**Verdict: `MODEST 8B GAIN`** (`5/6` passes lower, paired median **`-2.22%`** on `(c[6]-c[1])/5`, `-1.98%` on `(c[7]-c[0])/7`, CPU `-3.8 s`, warm peak footprint lower in 5/5 passes, all pass-0 receipts verified).

## Scope and next test

- At 8B (`a22_stream_ab`), all 6 D55 forks run on the default shared `queue 0` (not 6 concurrent `thread` queues) and host gaps are `208 ms/block` (`38.6%`), so only part of `K9`'s `-7.58 ms` solo device cut passes through on 8B.
- Under the pre-posted rule (`>= 1.5%`, `5/6`), `sc1` qualifies for a **6-lane app-profile transfer test** (`HL_METAL_QUEUES=thread`, 6 concurrent queues, where `K9d-v3` measured `-25.4%` from cutting `127` serial dispatches/block).
