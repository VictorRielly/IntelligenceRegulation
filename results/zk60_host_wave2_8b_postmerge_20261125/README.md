# Post-merge Wave 2 host-gap (`HL_HOST_FAST_W2=1`) synthetic 8B re-run on `9fbc85292` (2026-11-25 UTC)

By Antigravity (Gemini Carbon). Post-merge confirmation of the merged Wave 2 host-gap path (`9fbc85292`, verified `0` diff under `ops/zkp-mvp/gpu-metal/` vs `9291bb085`) against the exact pre-Wave-2 pushed head `acceeb94c` (`9fbc85292^1`) on `W16R2_8B_T128_H24` (`L=32`, `N=6`, `HL_A19_BUDGET_GIB=32`, `HL_GPU=1`, `HL_GPU_REQUIRED=1`, `HL_PB_ORACLE=0`, `HL_METAL_TIMING=0`).

## Summary of Verdicts (strictly per pre-posted `2026-11-25T18:48:45Z` rules) [MEASURED / DERIVED]

1. **Set 1 (`071dacb028d7`, two-binary fresh-process `A0_leadin, A1, B1, C1, C2, B2, A2`, overlap `[]`):**
   - **Default path (`B` vs `A`):** `r = mean_B_rate / mean_A_rate - 1 = -0.64%` (`>= -1.5%`, pairs `-3.46%` / `+2.31%`, mean gap `3.222 s` vs `3.203 s`, mean CPU `367.65 s` vs `368.30 s`) -> **`DEFAULT PATH INTACT ON 8B`**.
   - **Wave-2 ON vs pre-Wave-2 binary (`C` vs `A`):** Pair 1 (`C1` vs `A1`) gap reduction **`+1.41%`** (rate `+1.43%`), Pair 2 (`C2` vs `A2`) **`+8.18%`** (rate `+8.90%`), mean rate **`+5.08%`** (mean gap `-4.87%`, mean CPU `-10.67%`; within-binary `C` vs `B` `-4.81%` / `-6.05%`). **Strict pre-posted pair-rule verdict: `NO GAIN / INCONCLUSIVE vs B0`** because Pair 1 (`+1.41%`) fell `0.09 pp` below the `1.5%` per-pair floor due to cross-process variance between the two `A` legs (`A1 = 3.128 s` vs `A2 = 3.278 s`, a `4.8%` gap spread).
2. **Set 2 (`594c034de8ae`, single-process 6-pass alternating `B1` `hw0` vs `hw1+ad0`, overlap `[]`):**
   - `hw0` median **`3.192 s`** (`40.10 tok/s`, CPU median `368.25 s`, `SUMMARY` steady mean `40.76 tok/s`) vs `hw1+ad0` median **`3.052 s`** (`41.94 tok/s`, CPU median `327.30 s`, `SUMMARY` steady mean `42.73 tok/s`, `+4.83%`).
   - Paired `hw1+ad0 - hw0` gap: **`-0.147 s`** (**`-4.61%`** of `hw0` median), strictly lower in **`6 of 6`** passes; paired CPU **`-41.95 s`** (**`-11.39%`**), strictly lower in **`6 of 6`** passes -> **`PASS AT 8B`** (matches pre-merge Nov 23 Run 2: `-4.95%` gap, `6/6`, `-11.08%` CPU).

## Setup & Provenance [MEASURED]

- **Build job:** `agy-w2-8b-postmerge-build` (guard run `dc46ecc18b8e`, class `build`, `exit=0`, `401 s`, `peak_rss=4.80 GiB`), both binaries built `--release --features gpu-metal --lib --tests --no-run --offline --locked -j 4`:
  - **B0 (`acceeb94c` = `9fbc85292^1`, detached worktree `.agy-worktrees/w2-8b-base`, removed after run):** `hashline-99331253074f9a28`, SHA-256 `1fd3e12f827d30be0e0c48abf2d74f3d272db35e4bbca5e093da7b42d1180c4a`.
  - **B1 (`9291bb085`, `0` diff vs `9fbc85292` under `ops/zkp-mvp/gpu-metal/`, worktree `.agy-worktrees/wave2-8b-postmerge`):** `hashline-47108cbd7bf5814a`, SHA-256 `d4fb1ca9c14a3019350c4ac2a557178f612d5fb2923a626096ef2ea69efaf71b`.
- **Guard runs (quiet host, zero overlapping guarded jobs in `results/zk60_resource_guard/history.jsonl`):**
  - **Set 1:** guard `071dacb028d7` (`agy-w2-8b-pm-set1`, class `gpu`, `need=80G`, `cap=110G`, `exit=0`, `417.2 s`, `peak_rss=34.57 GiB`, `min_avail=151.98 GiB`, `peak_vram=22774 MiB`, `ts_end=2026-11-25T18:56:14Z`, overlap `[]`). Pre-run status (`raw/set1.status_pre.txt`): `RAM 200.35 GiB avail`, `GPU 526 MiB used`, locks free, `loadavg 5.31 5.34 5.41`.
  - **Set 2:** guard `594c034de8ae` (`agy-w2-8b-pm-set2`, class `gpu`, `need=80G`, `cap=110G`, `exit=0`, `371.4 s`, `peak_rss=33.17 GiB`, `min_avail=153.51 GiB`, `peak_vram=23362 MiB`, `ts_end=2026-11-25T19:04:05Z`, overlap `[]`). Pre-run status (`raw/set2.status_pre.txt`): `RAM 200.4 GiB avail`, `GPU 522 MiB used`, locks free, `>= 99 s` cooldown after Set 1.
- **Receipts verified (`818,728,672 B` each, from run directories):**
  - Set 1: all 7 legs (`A0_leadin, A1, B1, C1, C2, B2, A2`) verified cold `1/1` + pass-0 `8/8` (`63/63` total), `test result: ok. 1 passed; 0 failed`.
  - Set 2: verified cold `1/1` + pass-0 `hw0` `8/8` + pass-0 `hw1+ad0` `8/8` (`17/17` total), `test result: ok. 1 passed; 0 failed`.

## Set 1 Result (Two-binary fresh-process `A0_leadin, A1, B1, C1, C2, B2, A2`) [MEASURED / DERIVED]

| Leg | Binary | Arm | `(c[6]-c[1])/5` gap (s) | Rate `128/gap` (tok/s) | CPU `user+sys` (s) | Peak footprint (GiB) | Exit / Receipts |
|---|---|---|---:|---:|---:|---:|---|
| `A0_leadin` *(discarded)* | B0 (`acceeb94c`) | `serve8+lanes2+ba1+frs1+sf1+sc1+hf1` | 3.162 | 40.48 | 365.8 | 44.6 | 0 / 1+8 verified |
| `A1` | B0 (`acceeb94c`) | `serve8+lanes2+ba1+frs1+sf1+sc1+hf1` | 3.128 | 40.92 | 366.2 | 44.4 | 0 / 1+8 verified |
| `B1` | B1 (`9291bb085`) | `serve8+lanes2+ba1+frs1+sf1+sc1+hf1` *(W2 off)* | 3.240 | 39.51 | 369.8 | 47.6 | 0 / 1+8 verified |
| `C1` | B1 (`9291bb085`) | `serve8+lanes2+ba1+frs1+sf1+sc1+hf1+hw1+ad0` | 3.084 | 41.50 | 325.9 | 44.5 | 0 / 1+8 verified |
| `C2` | B1 (`9291bb085`) | `serve8+lanes2+ba1+frs1+sf1+sc1+hf1+hw1+ad0` | 3.010 | 42.52 | 332.1 | 44.3 | 0 / 1+8 verified |
| `B2` | B1 (`9291bb085`) | `serve8+lanes2+ba1+frs1+sf1+sc1+hf1` *(W2 off)* | 3.204 | 39.95 | 365.5 | 45.5 | 0 / 1+8 verified |
| `A2` | B0 (`acceeb94c`) | `serve8+lanes2+ba1+frs1+sf1+sc1+hf1` | 3.278 | 39.05 | 370.4 | 44.3 | 0 / 1+8 verified |

- **Means (pairs 1 & 2):** `A` = `3.203 s` (`39.98 tok/s`, CPU `368.3 s`), `B` = `3.222 s` (`39.73 tok/s`, CPU `367.65 s`), `C` = `3.047 s` (`42.01 tok/s`, CPU `329.0 s`).
- **`B vs A` (default path):** pair1 rate `-3.46%`, pair2 rate `+2.31%`, **`r = mean_B_rate / mean_A_rate - 1 = -0.64%`** (`>= -1.5%`) -> **`DEFAULT PATH INTACT ON 8B`**.
- **`C vs A` (Wave-2 ON vs B0):** pair1 gap reduction **`+1.41%`** (rate `+1.43%`), pair2 **`+8.18%`** (rate `+8.90%`), mean gap `-4.87%`, mean rate `+5.08%`, mean CPU `-10.67%`. Within-binary `C vs B` is `-4.81%` (pair1) and `-6.05%` (pair2). **Strict pair-rule verdict: `NO GAIN / INCONCLUSIVE vs B0`** (Pair 1 `+1.41% < 1.5%`, cross-process `A1`/`A2` spread `4.8%`).

## Set 2 Result (Single-process 6-pass alternating `B1`: `hw0` vs `hw1+ad0`) [MEASURED / DERIVED]

Parsed both with `summarize_8b.py` and the official `results/zk60_composed_8b_20261123/summary_8b.py`:

| Arm | `(c[6]-c[1])/5` gap per pass (s), passes 0..5 | Median (s) | `128/med` | `SUMMARY` steady mean (best) | Amortized mean (best) | Mean latency | Peak footprint | CPU `user+sys` med |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| `...hf1+q0+hw0` | `3.212 3.176 3.222 3.186 3.176 3.198` | `3.192` | `40.10 tok/s` | `40.76 (41.15) tok/s` | `36.95 (37.40) tok/s` | `13.401 s` | `47.1 GiB` | `368.25 s` |
| `...hf1+q0+hw1+ad0` | **`3.044 3.020 3.120 3.096 3.014 3.060`** | **`3.052`** | **`41.94 tok/s`** | **`42.73 (43.38) tok/s`** | **`38.62 (39.52) tok/s`** | **`12.868 s`** | `47.0 GiB` | **`327.30 s`** |

| Metric (`hw1+ad0` minus `hw0`) | Per pass (0..5) | Paired median | % of `hw0` median | Lower in |
|---|---|---:|---:|---:|
| Primary `(c[6]-c[1])/5` gap | `-0.168 -0.156 -0.102 -0.090 -0.162 -0.138 s` (`-5.23% -4.91% -3.17% -2.82% -5.10% -4.32%`) | **`-0.147 s`** | **`-4.61%`** | **`6 of 6`** |
| CPU `user + sys` (8-req pass) | `-34.2 -46.9 -41.9 -43.0 -42.0 -33.6 s` | **`-41.95 s`** | **`-11.39%`** | **`6 of 6`** |

- **Strict Set 2 verdict:** **`PASS AT 8B`** (`6 of 6` strictly lower AND paired median `-4.61% >= 3.0%`, exit `0`, all pass-0 receipts verified, `0` guard overlaps).

## Not Claimed

- Synthetic diagonal 8B test weights (`W16R2_8B_T128_H24`, `L=32`, `N=6`) only; nothing about trained weights, classifier 6x8 throughput, or verifier speed.
