# Opt-in Wave 2 host-gap path (`HL_HOST_FAST_W2=1`, `W2-2..W2-8`, `hw1+ad0` / `hw1+ad1` vs `hw0`) and queue mode (`q1` vs `q0`) on the synthetic 8B stream (2026-11-23/24 UTC): `PASS AT 8B` (`6/6` passes, `-4.95%` paired median gap, `-11.08%` CPU)

By Antigravity. Evaluates on `W16R2_8B_T128_H24` (`L=32`, `N=6`) on top of the merged pushed head `42b24a522` (`serve8+lanes2+ba1+frs1+sf1+sc1+hf1`):
1. **Run 1 (`q1_vs_q0`):** per-thread Metal queues (`q1`) vs shared queue (`q0`) with `hw0` -> **`q0` WINS** (`q1` slower by `+1.87%` paired median gap, higher in `5/6` passes).
2. **Run 2 (`w2_ab`):** opt-in same-words Wave 2 host-gap path (`HL_HOST_FAST_W2=1`, off by default) with synchronous drop (`hw1+ad0`) and optional async `munmap` (`hw1+ad1`) vs `hw0` -> **`PASS AT 8B`** (`hw1+ad0`: **`-4.95%`** paired median gap, **`6/6`** passes lower, **`40.80 -> 43.03 tok/s`** steady mean **`+5.47%`**, best **`44.03 tok/s`**, **`-11.08%`** CPU `user+sys`). Because `hw1+ad1` trailed `hw1+ad0` (`+0.89%` gap, `+1.75%` CPU / `+6.14%` sys CPU), `HL_HOST_FAST_ASYNC_DROP` is flipped to default-**OFF** (strictly opt-in `=1` on top of `HL_HOST_FAST_W2=1`) per the pre-posted rule.

Six same-words Wave 2 host/Metal cuts inside `ops/zkp-mvp/gpu-metal/hashline/` (`0` `zkp-core` edits, `0` new `.rs` files in `src/private_block/`, every fast path isolated out-of-line with `#[inline(never)]` so the unset path stays flat):
- **W2-2 (`protocol.rs`, `run_fork.rs`, `classify_cli.rs`, `classify_run.rs` — G3):** `SealedHistograms` reuse (keyed on exact `(sh, blk, wit)` identity with fallback on mismatch), zero-alloc `TwoTerm` LogUp helper construction, and direct on-the-fly `exp_deltas` histogramming.
- **W2-3 (`protocol.rs` — G3/G4):** flat zero-copy `write_helpers_w16_cols` (`try_write_helpers_w16_flat`) eliminating `Vec<Vec<Fp>>` transposition + optional bounded async `munmap` (`HL_HOST_FAST_ASYNC_DROP=1`, default OFF).
- **W2-4 (`argument.rs`, `argument_accuracy.rs`, `metal.rs` — G6):** structural `SlotPipeKey` pipeline cache (`metal_rounds_cached` / `metal_rounds_owned_cached`), skipping IR/MSL build on static CPU slots, and GPU `PUB_GEN_ROPE` / `SC_ZS` table generation inside A12's deferred `TabBuild` prelude (0 extra CBs).
- **W2-6 (`accuracy_fold.rs`, `argument.rs` — G5):** 4-row L1-tiled AArch64 NEON `accuracy_fold` (`fold_rows_fast_w2` / `fold_cols_fast_w2`), `CheckedPublic` zero-padding skip, and `SC_SCORE`/`SC_PV` fast fold.
- **W2-7 (`metal.rs`, `zk.rs` — G1/G4):** reuse `MetalCommit.pads` GPU buffer across openings, parallel `mask_open_w2` across rows, and parallel `gather` readback.
- **W2-8 (`argument.rs` — G1):** fused 2-row `mask_eval_eq` and removal of tiny rayon barriers.

**Pre-posted rules (`ops/zkp-mvp/RECOVERY_COORDINATION.md`, `2026-11-23T23:45:41Z`, before launch):**
- Primary metric: per-pass steady gap `(c[6] - c[1]) / 5` from `results/zk60_composed_8b_20261123/summary_8b.py` (`STREAM` completions).
- **Run 1 (`q1_vs_q0`):** **`q1` WINS** if `q1` is strictly lower in `>= 5/6` passes AND paired median reduction `>= 1.5%`; **`q0` WINS** if `q1` is strictly higher in `>= 5/6` passes AND paired median increase `>= 1.5%`; else **NO CLEAR DIFFERENCE** (Run 2 uses `q1` only if `q1` wins, else `q0`).
- **Run 2 (`w2_ab`):** **PASS AT 8B** if the better of `{hw1+ad1, hw1+ad0}` is strictly lower than `hw0` in **6 of 6 passes** AND paired median reduction **`>= 3.0%`**, exit 0, all pass-0 receipts verified; **MODEST 8B GAIN** if `>= 5/6` passes lower AND paired median `1.5% .. < 3.0%`; **NO GAIN / KILL AT 8B** if `< 5/6` OR `< 1.5%`. Secondary `hw1+ad1` vs `hw1+ad0`: keep `HL_HOST_FAST_ASYNC_DROP` default-ON under `HL_HOST_FAST_W2=1` only if `ad1` beats `ad0` on median gap without RSS regression; otherwise default-OFF.

## Setup [MEASURED]

- Source commit measured: `08a1bfc9f` (`agy/host-wave2`, base `42b24a522`, clean tree before runs).
- Verification before timing:
  - Guard `4f07d67205d2`: Non-Metal release `--lib` **10/10** passed (Wave 2 CPU unit tests, `a22_arm`, M1 CPU parity, B-L3 refusal, `s25_tests` W-8(5)/(7) + R18 census).
  - Guard `7729778c5267` (`exit=0`, `283 s`, `peak_rss=5.30 GiB`, `peak_vram=5974 MiB`): Metal release `cargo check --example zk60_classify` clean; Metal `--lib` unit + full `s25_tests` (incl. W-11 hash census) **30/30** passed; all 4 fresh-process Metal GPU parity/golden/call-site gates passed with **0 fallbacks** (`host_fast_w2_rope_and_const_pub_gen_gpu`, `host_fast_w2_rung_golden` `96e4f0b6` hitting all 10 W2 counters `[1, 2, 1, 3, 12, 2, 7, 2, 5, 162]`, `host_fast_w2_all_call_sites_byte_identical` exact on single `rung_g` `4,234,984 B` + `run_fork` W16R2 `L=2` + classifier `[1224328, 7421464, 7421464, 2489016] B`, `host_fast_m1_pub_gen_all_7_kinds_and_direct_total_gpu`); `zk60_metal_commit` **8/8** both unset and `HL_HOST_FAST=1 HL_HOST_FAST_W2=1`.
- Single binary: `.agy-worktrees/host-wave2/ops/zkp-mvp/gpu-metal/hashline/target/release/deps/hashline-5d23267366f4fc6a`, SHA-256 `864d96525955541eda6e0af7e808d12c3bd2b0280101e4c1f6c2444affd12971`.
- Test: `private_block::run::fork::tests::a22::a22_stream_ab`, one process per run, interleaved arms, 6 passes, alternating order (`HL_D55_AB_ALTERNATE=1`), `W16R2_8B_T128_H24`, `L=32`, `N=6`, `HL_A19_BUDGET_GIB=32`, all `HL_*` switch env vars stripped (`run_8b.py`). Quiet host: `/tmp/HOLD` absent, no `ds4-bench`, locks free, 0 subagents/builds running.
- Guard runs:
  - **Run 1 (`q1_vs_q0`):** guard `ab1a051aaaca` (`agy-host-wave2-8b-q1_vs_q0`, class `gpu`, `need=80G`, `cap=110G`, `exit=0`, `378.3 s`, `peak_rss=33.36 GiB`, `min_avail=158.78 GiB`, `peak_vram=22688 MiB`, `2026-11-23T23:46:18Z–23:52:37Z`). Pass-0 receipts verified: cold 1/1 + `q0` 8/8 + `q1` 8/8 (`818,728,672 B` each).
  - **Run 2 (`w2_ab`):** guard `0c38e4271a4b` (`agy-host-wave2-8b-w2_ab`, class `gpu`, `need=80G`, `cap=110G`, `exit=0`, `542.8 s`, `peak_rss=32.83 GiB`, `min_avail=159.32 GiB`, `peak_vram=23453 MiB`, `2026-11-23T23:53:09Z–2026-11-24T00:02:12Z`, `>= 12 s` cooldown after Run 1). Pass-0 receipts verified: cold 1/1 + `hw0` 8/8 + `hw1+ad0` 8/8 + `hw1+ad1` 8/8 (`818,728,672 B` each).

## Run 1 Result (`q1_vs_q0`): `q0` WINS [MEASURED / DERIVED]

| arm | `(c[6] - c[1]) / 5` gap per pass (s), passes 0..5 | median (s) | 128 / median | `SUMMARY` steady mean (best) | amortized mean (best) | first req mean (best) | peak footprint | CPU (`user+sys` med) |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| `serve8+lanes2+ba1+frs1+sf1+sc1+hf1+q0` | 3.208 3.174 3.132 3.112 3.152 3.182 | 3.163 | 40.47 tok/s | 41.03 (41.71) tok/s | 36.95 (37.94) tok/s | 5.880 (5.354) s | 47.4 GiB | 366.3 s |
| `serve8+lanes2+ba1+frs1+sf1+sc1+hf1+q1` | 3.248 3.316 3.206 3.244 3.196 3.136 | 3.225 | 39.69 tok/s | 40.35 (41.41) tok/s | 37.07 (37.92) tok/s | 5.418 (5.099) s | 46.1 GiB | 361.6 s |

| metric (`q1` minus `q0`) | per pass (0..5) | paired median | % of `q0` median | lower / higher |
|---|---|---:|---:|---:|
| Primary `(c[6] - c[1]) / 5` (`summary_8b.py`) | +0.040 +0.142 +0.074 +0.132 +0.044 -0.046 s | **+0.059 s** | **+1.87%** (`+1.96%` med-vs-med) | 1/6 lower, **5/6 higher** |
| Secondary `(c[7] - c[0]) / 7` (from `REQ` `result`) | +0.078 +0.055 +0.016 +0.196 +0.002 -0.027 s | +0.036 s | +1.14% (`+1.44%` med-vs-med) | 1/6 lower, 5/6 higher |
| CPU (`user + sys`, per 8-request pass) | -5.9 -4.7 -8.5 +0.4 -2.4 -10.0 s | -5.3 s | -1.45% (`-1.27%` med-vs-med) | 5/6 lower, 1/6 higher |

- **Unset-path sanity:** `q0` (`hw0`) steady mean `41.03 tok/s` matches Wave 1 `hf1` (`40.98 tok/s` in `results/zk60_host_fast_8b_20261123`), confirming zero Wave 2 unset-path regression on 8B.
- **Verdict: `q0` WINS** (`q1` strictly higher in `5/6` passes AND paired median `+1.87% >= +1.5%`). Run 2 uses `q0`.

## Run 2 Result (`w2_ab`): `PASS AT 8B` (`hw1+ad0`: `-4.95%` gap, `6/6` passes, `+5.47%` steady tok/s, `-11.08%` CPU) [MEASURED / DERIVED]

| arm | `(c[6] - c[1]) / 5` gap per pass (s), passes 0..5 | median (s) | 128 / median | `SUMMARY` steady mean (best) | amortized mean (best) | first req mean (best) | peak footprint | CPU (`user+sys` med) |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| `...hf1+q0+hw0` | 3.160 3.184 3.138 3.154 3.192 3.204 | 3.172 | 40.35 tok/s | 40.80 (41.44) tok/s | 37.10 (37.67) tok/s | 5.637 (5.309) s | 46.8 GiB | 366.9 s (`293.1 + 73.8`) |
| `...hf1+q0+hw1+ad0` | **3.034 3.028 2.976 3.082 3.034 3.032** | **3.033** | **42.20 tok/s** | **43.03 (44.03) tok/s** | **38.95 (40.00) tok/s** | **5.471 (5.235) s** | 46.9 GiB | **325.4 s** (`264.2 + 60.2`) |
| `...hf1+q0+hw1+ad1` | 3.050 2.996 3.014 2.982 3.078 3.090 | 3.032 | 42.22 tok/s | 42.68 (43.62) tok/s | 38.55 (39.43) tok/s | 5.570 (5.244) s | 46.7 GiB | 330.0 s (`265.8 + 64.3`) |

| comparison & metric | per pass (0..5) | paired median | % of base median | lower in |
|---|---|---:|---:|---:|
| **`hw1+ad0` minus `hw0`** — Primary `(c[6] - c[1]) / 5` (`summary_8b.py`) | -0.126 -0.156 -0.162 -0.072 -0.158 -0.172 s | **-0.157 s** | **-4.95%** (`-4.38%` med-vs-med) | **6 of 6** |
| `hw1+ad0` minus `hw0` — Secondary `(c[7] - c[0]) / 7` (`REQ` `result`) | -0.128 -0.207 -0.217 -0.089 -0.206 -0.129 s | **-0.168 s** | **-5.36%** (`-4.67%` med-vs-med) | **6 of 6** |
| `hw1+ad0` minus `hw0` — CPU `user + sys` (user / sys) | -37.7 -37.5 -45.5 -43.4 -45.1 -37.9 s | **-40.65 s** | **-11.08%** (user `-9.72%`, sys `-17.07%`) | **6 of 6** |
| `hw1+ad1` minus `hw0` — Primary `(c[6] - c[1]) / 5` (`summary_8b.py`) | -0.110 -0.188 -0.124 -0.172 -0.114 -0.114 s | **-0.119 s** | **-3.75%** (`-4.41%` med-vs-med) | **6 of 6** |
| `hw1+ad1` minus `hw0` — Secondary `(c[7] - c[0]) / 7` (`REQ` `result`) | -0.017 -0.251 -0.172 -0.097 -0.171 -0.120 s | -0.146 s | -4.65% (`-3.82%` med-vs-med) | **6 of 6** |
| `hw1+ad1` minus `hw0` — CPU `user + sys` | -32.9 -42.8 -36.3 -41.5 -38.5 -30.6 s | -37.40 s | -10.19% (user `-9.48%`, sys `-12.74%`) | **6 of 6** |
| **`hw1+ad1` minus `hw1+ad0`** (async drop ablation) — Primary gap | +0.016 -0.032 +0.038 -0.100 +0.044 +0.058 s | **+0.027 s** | **+0.89%** (`-0.03%` med-vs-med) | 2 of 6 (higher 4/6) |
| `hw1+ad1` minus `hw1+ad0` — CPU `user + sys` (sys) | +4.8 -5.3 +9.2 +1.9 +6.6 +7.3 s | **+5.70 s** | **+1.75%** (sys **+6.14%**) | 1 of 6 (higher 5/6) |

- `SUMMARY` deltas (`hw1+ad0` vs `hw0`): steady mean **`+5.47%`** (`40.80 -> 43.03 tok/s`, best `44.03`), amortized mean **`+4.99%`** (`37.10 -> 38.95 tok/s`, best `40.00`), mean latency `13.349 -> 12.769 s` (`-4.3%`), first request `5.637 -> 5.471 s`, peak footprint `46.8 -> 46.9 GiB` (`+0.1 GiB`), guard `peak_rss = 32.83 GiB`.

**Verdict: `PASS AT 8B`** (`6/6` passes strictly lower AND paired median **`-4.95%`** on `(c[6] - c[1]) / 5`, exit 0, all pass-0 receipts verified).

## Post-ablation Default Change & Next Step

- Per the pre-posted rule, `host_fast_async_drop_on()` in `src/zk.rs` was flipped from `None => host_fast_w2_on()` to `None => false` (so `HL_HOST_FAST_W2=1` defaults to the faster, lower-CPU `hw1+ad0` path, and `HL_HOST_FAST_ASYNC_DROP=1` remains opt-in only).
- `agy/host-wave2` shares `token_io/classify_cli.rs` and `token_io/classify_run.rs` with `agy/classify-host-opt` (`a4d836c3a`); once `agy/classify-host-opt` merges to `origin/main`, `agy/host-wave2` will rebase cleanly onto the post-merge pushed head and enter Claude's 6-lane app-profile gate.
