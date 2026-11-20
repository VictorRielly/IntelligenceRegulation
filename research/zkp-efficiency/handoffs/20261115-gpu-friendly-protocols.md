# Direction of Inquiry: GPU-Friendly ("Op-Wasteful, Hardware-Aligned") ZKP Protocols & Computation Organization

**Date:** `2026-11-15`  
**Owner:** Coordinator (Inquiry Lead) + SOL (Metal / RTX 5090 Kernel Implementation)  
**Status:** Active Track -- Analytical Roofline `[MODEL]` + Empirical M3 Ultra Microbench (`microbench_gpu_friendly.py`)

## 1. Why Operation-Minimal ZKPs Lose on Modern GPUs

1. **Tensor/Matrix Units vs Scalar 64-bit Field ALUs (`>40x-190x` Compute Roof Gap):** On RTX 5090 (`sm_120`), dense INT8 Tensor Cores sustain `~1,500 TOPS` vs `~0.85 TOPS` scalar 64-bit Goldilocks modular mul. Inflating arithmetic ops by **`9x` (24-bit 3-limb slabs)** or **`36x` (64-bit Karatsuba 8-bit slabs)** to run on Tensor Cores raises the compute roof by **`49.0x` to `196.1x`** `[MODEL]`.
2. **Coalesced Streaming vs Random Gather/Scatter (`12x-15x` Bandwidth Gap):** An $O(N \log N)$ radix-16 coalesced NTT (`19.2x` more ops than $O(N)$ sparse RAA) finishes in `1.13 ms` vs `3.5 ms` on RTX 5090 (`3.4x` faster wall-clock despite `17.5x` more ops!) `[MODEL]`.
3. **Power-of-2 Padded Domains Beat Ragged Compaction (Already Measured in ZK60 `B3`):** Shrinking FFN width `16,384 -> 14,336` cut `14.29%` wasted lanes (`-424 KB` receipt) yet ran **`2.18%` SLOWER** on M3 Ultra Metal `[MEASURED]` (`MVP_STATUS.md:326`) due to ragged dispatch and piece-boundary branch masks.

## 2. Five Concrete Tracks (`G1-G5`)

- **G1 (Drop-In, Zero Verifier Change): INT8-Slab Tensor-Core / `simdgroup_matrix` Round-0/1 Sumcheck & Gram Folding** (`+9x` to `+36x` MACs, `0` inner-loop modular reductions, bit-identical Goldilocks transcript!).
- **G2 (Drop-In, Zero Verifier Change): Power-of-2 / 256-Tile Padded Dense Slabs** (formally keep `16,384` over `14,336` and pad ragged multi-plane batches to full warp tiles).
- **G3 (`W16R4` PCS Track): Tensor-Code / GEMM Reed-Solomon PCS (Brakedown / WHIR) + `B6b` Wide Rows (`2^18-2^20`)** (`>100x` more MACs on Tensor Cores, `2x-4x` faster GPU encode + shrinks 32L receipt `819 MB -> ~45 MB`).
- **G4 (`W16R4` Lookup Track): Coalesced Binary-Tree Fractional LogUp-GKR vs Atomic Table Scatter** (`+2x-3x` muls, `0` random scatter contention, eliminates `~45-52%` of committed PCS rows).

See `results/zk60_gpu_friendly_protocols_20261115/` for scripts and JSON benchmarks.
