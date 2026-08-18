# U-PERF2 lane O — the claim layer, round 2 (table pool + the ixf tables built on the device), the GEMM's u32-limb MAC, leftovers

Branch `uperf2-o` (worktree /home/victor/wt-uperf2-o), opened at 50aea3e on
2026-08-17. Ledger: PROGRESS_UPERF2.md "Round 8 ... Lane O" + "Agent O
status". This continues lane D's packed ixf prover (U_PERF2_CLAIMCOMMIT_
REPORT.md), lane L's device ixf chain (U_PERF2_GPU2_REPORT.md Section 5,
items 3-4) and lane K's GEMM kernel (U_PERF2_GPU_REPORT.md Section 5).

**Hardware (this box) [MEASURED]:** NVIDIA GeForce RTX 4070 Laptop GPU
(8,188 MiB, sm_89, 36 SMs, 55-70 W mobile part) behind WSL2 (pinned H2D
5-9 GB/s per lane L); host Intel Core Ultra 9 185H (22 threads), 15 GB.
Nothing here is a claim about the TARGET_CONTRACT's desktop board. Every
wall-clock number is `[WSL-BOX NT NOISY-SHARED]` unless marked QUIET —
lane N builds and runs concurrently; the rigs are serialized through
`/tmp/zk-heavy.lock`.

Status: IN PROGRESS (skeleton).

## 0. One paragraph

(to be written at close)

## 1. What landed (files)

- (skeleton)

## 2. Method (why the values are identical)

### 2.1 The table pool

(allocation plumbing only — no value changes)

### 2.2 The device-built ixf tables and the device-resident chain

(the eq-fold identity, the per-slot shift broadcast, the canonical node
sums)

### 2.3 The GEMM's u32-limb MAC

(the same 128-bit split-halves integers)

## 3. Differential evidence

| gate | result |
|---|---|
| (to be filled) | |

## 4. Measurements

### 4.1 Baselines (the 50aea3e binaries, this box)

(to be filled)

### 4.2 Per item before / after

(to be filled)

### 4.3 The rigs (`uperf-pc full-profile`, ZK_THREADS 8, `ZK_GPU=1`, wsl export, flock) [WSL-BOX 8T NOISY-SHARED unless noted]

| rig | binary | commit / prove / verify / wall | claim layer (cl-tables / rounds / folds) | peak RSS | digests |
|---|---|---|---|---:|---|
| 12x512 | 50aea3e baseline (the ledger's round-7 row) | 4.9 / 50.9 / 2.6 / **60.2 s** | 15.5 (4.9 / 5.3 / 5.2) | 11.2 GB | 2f8a92f8.. / 4c259008.. / 1,509,911 B |
| 12x512 | 41eb013 (pool + device zc tables) | 4.7 / 37.5 / 2.6 / **46.6 s** | **1.98** (0.30 / 1.13 / 0.01; opens 0.49 inside) | **9.30 GB** | identical, accept |
| 12x128 | 50aea3e baseline (this session) | 2.5 / 20.3 / 2.0 / 25.5 s | 2.61 (1.13 / 1.26 / 0.21) | 4,084 MiB at claim-layer end | 4a3af8c3.. / 742d88e1.. / 1,372,775 B |
| 12x128 | 41eb013 | 2.5 / 14.6 / 1.4 / 19.1 s | **0.73** (0.20 / 0.35 / 0.01) | 3,062 MiB at claim-layer end | identical, accept |
| 3x16 | 41eb013 | 0.8 / 2.8 / 0.5 / 4.3 s | 0.16 | — | 93a98700.. / 0ae9cdae.. / 985,142 B, accept |

12x512 attribution at 41eb013 (8T+GPU): descents 22.9 (bk.descent-gkr
16.7 = a.round-g 12.1 + a.tree-step 8.6 inside; trees 6.2 — lane N's),
prove-group 12.4 (level-h 4.6, psi0-factored 2.7, fold 1.9, kernel-rows
1.8, matvec-chunks 1.4), commit 4.7 (precommit-u0 3.2, chain-derive 1.4,
digit-witness 1.2), CRS 2.6 (m.crs-blocks 1.8), verify-group 2.4,
claim layer 2.0, transport 1.9. The claim layer's device chain: 79 device
rounds (had round 0 at 2^23 pairs 103 ms = 12 ns per pair; rq 85 ms; the
rounds then halve; the folds 3 x ~9 ms at 2^23 elements, bandwidth-bound),
opens 247 ms (the first: 4 GB of cudaMalloc) / ~70 ms (the next: 3 x 100
MB of i64 layers uploaded through pinned staging + the builds) / 29 ms;
VRAM held 4.06 GB during the claim layer, released at its end.

## 5. What is left / honest state

(to be filled)
