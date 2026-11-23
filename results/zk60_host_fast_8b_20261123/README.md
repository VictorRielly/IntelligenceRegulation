# Opt-in host-gap path (`HL_HOST_FAST=1`, `H1–H6`, `hf1` vs `hf0`) on the synthetic 8B stream (2026-11-23 UTC): PASS AT 8B (6/6 passes, -3.04% paired median)

By Antigravity. Evaluates the opt-in same-words host-gap path (`HL_HOST_FAST=1`, arm word `hf1`, off by default) on top of the merged pushed head `a7faf0ddb` (`serve8+lanes2+ba1+frs1+sf1+sc1`) at `W16R2_8B_T128_H24`.

Six same-words host cuts inside `ops/zkp-mvp/gpu-metal/hashline/` (`0` `zkp-core` edits, `0` new `.rs` files in `src/private_block/`):
- **H1 (`protocol.rs`, `accuracy_act.rs` — G4):** table-lookup `exp` (256 invs) + `act` (`<=16K` invs, shared with `gexp`/`gact`), skipping ~2.62M redundant `Fp2` inversions and 42 MB/block alloc when `missed == 0` (exact fallback on miss or zero table denominator).
- **H2 (`zk.rs` — G4):** parallel `mask_commit_tagged` across independent row inverse-NTT + coset RS encodings with exact sequential RNG draw order preserved.
- **H3 (`range16.rs` — G4):** parallel 2048-chunk Montgomery batch inversion in `denominator_inverses`.
- **H4 (`accuracy_fold.rs` — G5):** single-pass AArch64 NEON `SMLAL`/`vminq_s8` fused `accuracy_fold::fold` with exact signed 32-bit limbs, zero-weighted row/col skip, and exact `i8::MIN` refusal parity across active and zero-padded positions.
- **H5 (`argument.rs` — G5):** L1-tiled row-major `priv_table_fill` (eliminating 128 KiB L1 set-aliasing thrash across all 7 matmuls) + per-block `FoldCache` deduping `A_Y` (3x -> 1x) and `A_YM` (2x -> 1x).
- **H6 (`argument.rs`, `argument_accuracy.rs`, `metal.rs` — G6):** sparse `SlotDef::pub_gens` + `k_tab_pub_gen` inside A12's existing deferred `TabBuild` prelude (0 extra CBs) for `group_column`, `BoxSupp`/`HeadSupp`, `CausalMask`, `GammaRepeat` (`gamma_a`/`gamma_m`/`dd_e`) + base-field `direct_total` enabling A12 `direct` on `SC_SS`/`SC_SSM`/`SC_RS` (`enum Tab` and `Side::Verify` untouched).

**Pre-posted rule (`ops/zkp-mvp/RECOVERY_COORDINATION.md`, `2026-11-23T15:45:15Z`, before launch):** decision pair `serve8+lanes2+ba1+frs1+sf1+sc1+hf1` against `serve8+lanes2+ba1+frs1+sf1+sc1+hf0`; primary metric = per-pass steady gap `(c[6] - c[1]) / 5` (`results/zk60_composed_8b_20261123/summary_8b.py`). **PASS AT 8B (enter Claude's read & 6-lane app gate)** if `hf1` is strictly lower than `hf0` in **6 of 6 passes** AND paired median reduction **`>= 3.0%`**, exit 0, all pass-0 receipts verified; **MODEST 8B GAIN** if `>= 5` of `6` passes lower AND paired median `1.5% .. < 3.0%`; **NO GAIN / KILL** if `< 5/6` OR `< 1.5%`.

## Setup [MEASURED]

- Source commit: `67facf460` (`agy/host-g5g4g6`, cleanly rebased onto pushed head `a7faf0ddb`, clean tree).
- Verification before timing: guard `529f64fce6b4` (`agy-host-fast-verify`, `exit=0`, `263 s`, `peak_rss=5.48 GiB`, `peak_vram=4780 MiB`): non-Metal `cargo check --lib` + Metal `--example zk60_classify` (`ee6b638a8004`), `accuracy_fold::tests` (7/7), `accuracy_act::tests` (8/8), `range16::tests` (3/3), `a22_arm_parses_frs0_and_frs1`, `host_fast_w16r2_rung_golden` (`96e4f0b6` across CPU `hf1` + Metal `hf0`/`hf1`/`frs1+sf1+hf1` x `shared`/`thread`, `hits=[0;6]` on `hf0` and `[2, 1, 4, 7, 8, 11]` on `hf1`), `host_fast_all_call_sites_byte_identical` (single-block `rung_g` `4,234,984 B`, `L=2` `run_fork` W16R2 live verified `hits=[4, 2, 8, 14, 16, 22]`, classifier `stage_in_c + blocks + stage_out_c` `[1224328, 7421464, 7421464, 2489016] B` byte-identical + verified), `sc_chain_fast_w16r2_rung_golden` (6/6), `w16r2_the_lemmas_load_bearing_invariants_are_pinned` (1/1), `--test zk60_metal_commit` (8/8).
- Single binary: `.agy-worktrees/host-g5g4g6/ops/zkp-mvp/gpu-metal/hashline/target/release/deps/hashline-b4a81241762e0a9f`, SHA-256 `70f6669a4e9c9a6d857f5f22d15ce152e65e4af944ca31bb40456b483a42d404`.
- Test: `private_block::run::fork::tests::a22::a22_stream_ab`, one process, 2 arms interleaved, 6 passes, alternating order (`HL_D55_AB_ALTERNATE=1`), `W16R2_8B_T128_H24`, `L=32`, `N=6`, `HL_A19_BUDGET_GIB=32`, all switch env vars stripped.
- Guard run: `8bf1279718c3` (`agy-host-fast-8b-hf1_vs_hf0`, class `gpu`, `need=80G`, `cap=110G`, `exit=0`, `382.0 s`, `peak_rss=33.24 GiB`, `min_avail=159.67 GiB`, `peak_vram=22726 MiB`, `2026-11-23T15:45:36Z–15:51:58Z`). Quiet host: `/tmp/HOLD` absent, no `ds4-bench`, locks free, 0 subagents running.
- Pass-0 receipts verified: cold 1/1 + pass 0 `hf0` 8/8 + pass 0 `hf1` 8/8 (`818,728,672 B` each).

## Result [MEASURED]

| arm | `(c[6] - c[1]) / 5` gap per pass (s), passes 0..5 | median (s) | 128 / median | `SUMMARY` steady mean (best) | amortized mean (best) | first req mean (best) | peak footprint | CPU (`user+sys` med) |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| `serve8+lanes2+ba1+frs1+sf1+sc1+hf0` | 3.298 3.298 3.242 3.222 3.226 3.270 | 3.256 | 39.31 tok/s | 39.88 (40.48) tok/s | 35.77 (36.58) tok/s | 6.173 (5.500) s | 47.3 GiB | 399.3 s |
| `serve8+lanes2+ba1+frs1+sf1+sc1+hf1` | 3.194 3.178 3.144 3.122 3.174 3.214 | 3.176 | 40.30 tok/s | 40.98 (41.64) tok/s | 37.30 (37.88) tok/s | 5.587 (5.333) s | 46.5 GiB | 367.0 s |

| metric (`hf1` minus `hf0`) | per pass (0..5) | paired median | % of off median | lower in |
|---|---|---:|---:|---:|
| Primary `(c[6] - c[1]) / 5` (`summary_8b.py`) | -0.104 -0.120 -0.098 -0.100 -0.052 -0.056 s | **-0.099 s** | **-3.04%** (`-2.46%` med-vs-med) | **6 of 6** |
| Secondary `(c[7] - c[0]) / 7` (from `STREAM` completions) | -0.123 -0.027 -0.066 -0.117 -0.093 -0.086 s | **-0.089 s** | **-2.78%** (`-3.02%` med-vs-med; `+3.12%` tok/s) | **6 of 6** |
| CPU (`user + sys`, per 8-request pass) | -38.1 -28.4 -28.9 -38.6 -36.9 -32.5 s | **-34.7 s** | **-8.69%** (`-8.09%` med-vs-med) | **6 of 6** |

- `SUMMARY` deltas: steady mean **`+2.76%`** (`39.88 -> 40.98 tok/s`), amortized mean **`+4.28%`** (`35.77 -> 37.30 tok/s`), mean latency `13.953 -> 13.286 s` (first request `6.173 -> 5.587 s`, `-9.5%`), peak footprint `47.3 -> 46.5 GiB` (`-0.8 GiB`), guard `peak_rss = 33.24 GiB`.

**Verdict: `PASS AT 8B`** (`6/6` passes strictly lower AND paired median **`-3.04%`** on `(c[6] - c[1]) / 5`, exit 0, all pass-0 receipts verified).

## Scope and next test

- `agy/host-g5g4g6` (`67facf460` + this record commit) is submitted for Claude's Opus code read and official 6-lane app-profile transfer gate (`zk60_classify serve --lanes 6`, where host gaps are `241.6 ms/block` = `46.3%` of block wall per Tick 47, and `a7faf0ddb` + `sc1` sits at `48.48–49.64 tok/s`).
