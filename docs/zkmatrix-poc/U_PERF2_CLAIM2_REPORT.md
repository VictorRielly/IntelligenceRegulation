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

### 4.3 The rigs

(to be filled)

## 5. What is left / honest state

(to be filled)
