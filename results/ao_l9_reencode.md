# Lever L9 — the opening's re-encode, attributed (lane AO, round 16)

Status: LIVE. WSL box (Core Ultra 9 185H, 15 GB) + RTX 4070 Laptop GPU
(8,188 MB, sm_89), `flock /tmp/zk-heavy.lock`, lane AN on the CPU in a
sibling worktree. Every number below is [MEASURED] unless labelled
otherwise.

**The unit of measurement is NOT the 8B pass.** This box has an 8 GB card
that spills at 8,585 MB on the 8B pass and froze three times on
2026-09-04; the round-16 brief forbids a headline from it. So the lane
measures the re-encode ALONE, in a harness that reproduces the 8B pass's
exact PCS shape — `log_cols` 14 -> `log_nn` 16 (`inv_rate` 4), 256 opened
columns, chunk 128 rows, 512 threads/block — at row counts from 1,024 up
to **10,752, which IS the 8B pass's W row count** (three Mistral FFN
matrices, 14336 x 4096 each, flattened into rows of 2^14: 3 x 3,584).
Peak VRAM of the largest arm is ~1.5 GB, an eighth of the card.

The harness: `HL_GPU_BENCH_REENC=1 hashline gpu-probe`, added in
`gpu/cuda.rs` as `reenc_bench` (the shape of lane AJ's `HL_GPU_BENCH_H2D`
hook). It times `columns_chunked` — the function the opening actually
calls — and then each of its kernels separately over the same chunk plan,
best of N. Nothing in it runs on a proof path.

## 1. THE BRIEF'S THREE PREMISES, AND WHAT THE COUNTERS SAY

The round-16 brief (from lane AJ's §7, which labelled its own numbers
[COUNTED], not measured) says the re-encode "runs at 1.6e10 Goldilocks
mul/s against a ~4.6e11 ALU ceiling and moves 66 of 256 GB/s — so it is a
LATENCY AND LAUNCH-STRUCTURE problem, not a bandwidth one, and the fix is
launch shape rather than a better inner loop."

At the 8B pass's own W shape (10,752 rows), measured:

| the brief | what the counters say [MEASURED] |
|---|---|
| 1.6e10 butterfly/s | the four kernels do 6.870e9 butterflies in **0.1715 s = 4.00e10 butterfly/s**, 2.5x the briefed rate. The 1.6e10 comes from dividing W's butterfly count by `secs_reenc`, which also contains the d2h, the pool allocations, the host assembly of the 256 output columns, and the A and H openings |
| 66 of 256 GB/s | per kernel: `k_dif_pa` **197.6 GB/s**, `k_ntt_p2` (dense) **200.5**, `k_ntt_p2_gather` **141.1**, `k_dif_pb` **100.2**, `k_dit_p1_pad` **79.1**. Two of the four tile kernels are at **77-78% of the 256 GB/s roof** — they are bandwidth-bound and have nothing left to give |
| a LAUNCH-STRUCTURE problem | the launch residue is **0.9% at 1,024 rows**. It rises to 17.3% at 10,752 rows, but that residue is not launch gaps: it is the pool allocation of a 22 MB output buffer, the `sel`/`idx` uploads, and the HOST loop that copies 2.75 M `Fp` out of the downloaded block into 256 `Vec<Fp>` |

So L9 is not one item. It is **one latency item (`k_dit_p1_pad`), one
bandwidth item (`k_ntt_p2_gather`), two kernels already at the roof, and a
host tail**.

## 2. THE ATTRIBUTION [MEASURED]

`columns_chunked`, best of 7, `log_n` 14 -> `log_nn` 16, q = 256 (254
distinct), chunk 128 rows, 512 threads/block:

| rows | `columns_chunked` | four kernels | d2h | residue | butterfly/s over the whole call |
|---:|---:|---:|---:|---:|---:|
| 1,024 | 0.02663 s | 0.02588 (97.2%) | 0.00050 | 0.00025 (0.9%) | 24.6e9 |
| 3,584 | 0.09148 s | 0.08199 (89.6%) | 0.00133 | 0.00815 (8.9%) | 25.0e9 |
| **10,752 (the 8B W shape)** | **0.22231 s** | **0.17153 (77.2%)** | 0.01241 (5.6%) | 0.03836 (**17.3%**) | 30.9e9 |

Kernel by kernel at 10,752 rows:

| kernel | s | share of the four | butterfly/s | GB/s | verdict |
|---|---:|---:|---:|---:|---|
| **`k_dit_p1_pad`** (forward DIT, stages 1-12) | **0.08904** | **51.9%** | 47.5e9 | 79.1 | **the elephant.** 10% of the ALU roof and 31% of the bandwidth roof — the ONE kernel that is neither |
| `k_ntt_p2_gather` (forward, stages 13-16, fused gather) | 0.04010 | 23.4% | 35.2e9 | **141.1** | 55% of the bandwidth roof; the lever is fewer LOADS, not a better loop |
| `k_dif_pb` (inverse DIF, stages 12-1) | 0.02813 | 16.4% | 37.6e9 | 100.2 | same family as `p1_pad`, a quarter the size |
| `k_dif_pa` (inverse DIF, stages 14-13) | 0.01426 | 8.3% | 12.4e9 | **197.6** | **77% of the roof — closed.** Nothing to win here |
| *(reference)* `k_ntt_p2` (dense, the COMMIT's last group) | 0.05622 | — | 25.1e9 | **200.5** | **78% of the roof — closed** |
| *(reference)* `k_gather_cols_off` | 0.00111 | 0.6% | — | — | AJ's parity result reconfirmed |

The rate RISES with the row count (24.6 -> 30.9e9 butterfly/s over the
whole call), so the small shapes understate the device: at 1,024 rows the
grid is too small to fill 36 SMs and the kernels are launch-latency bound;
at 10,752 they are not.

## 3. WHERE THE WORK IS, COUNTED

Butterflies per row at this shape (`n` = 2^14, `nn` = 2^16, `NTT_LOG_BLK`
= 12) [COUNTED]:

| pass | stages | butterflies/row | share |
|---|---|---:|---:|
| `k_dif_pa` | 14, 13 | 16,384 | 2.6% |
| `k_dif_pb` | 12 .. 1 | 98,304 | 15.4% |
| `k_dit_p1_pad` | 1 .. 12 | 393,216 | **61.5%** |
| `k_ntt_p2(_gather)` | 13 .. 16 | 131,072 | 20.5% |
| total | | 638,976 | |

x 10,752 rows = 6.870e9 butterflies, which is exactly AJ's counted number.
`k_dit_p1_pad` is 61.5% of the arithmetic and 51.9% of the time, so the
four kernels are within a factor of 1.2 of each other in efficiency —
there is no single broken kernel, and no free 2x sitting in an inner loop.
